import 'dart:io';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

// NOTE: This service supports two providers:
// - OpenAI (set OPENAI_API_KEY env var)
// - Perplexity (set PPLX_API_KEY env var)
// It will prefer OpenAI if both keys are present.

class LlmService {
  // Circuit breaker / rate-limit protection
  static int _failureCount = 0;
  static DateTime? _circuitOpenUntil;
  static const int _failureThreshold = 5;
  static const int _circuitOpenSeconds = 300; // 5 minutes

  // Log file path (app working dir). For mobile this may not be available;
  // logs will also be printed to console. Adjust path for production.
  static const String _logFile = 'llm_logs.txt';

  // Helpers for circuit breaker
  bool get _isCircuitOpen => _circuitOpenUntil != null && DateTime.now().isBefore(_circuitOpenUntil!);

  void _recordFailure() {
    _failureCount += 1;
    if (_failureCount >= _failureThreshold) {
      _circuitOpenUntil = DateTime.now().add(const Duration(seconds: _circuitOpenSeconds));
      _appendLog('SYSTEM', 'circuit_open', 'Circuit opened until $_circuitOpenUntil (failureCount=$_failureCount)');
    }
  }

  void _recordSuccess() {
    _failureCount = 0;
    _circuitOpenUntil = null;
  }

  String _maskSensitive(String s) {
    if (s.isEmpty) return s;
    // mask API keys that start with sk-
    var out = s.replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{8,}'), 'sk-*****');
    // mask emails
    out = out.replaceAllMapped(RegExp(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"), (m) => '<email>');
    // mask long digit sequences (phones, tokens)
    out = out.replaceAllMapped(RegExp(r'\d{6,}'), (m) => '*' * m.group(0)!.length);
    return out;
  }

  Future<void> _appendLog(String provider, String prompt, String response, {bool success = true, int attempt = 0}) async {
    final ts = DateTime.now().toIso8601String();
    final entry = '[$ts] provider=$provider attempt=$attempt success=$success prompt="${_maskSensitive(prompt)}" response="${_maskSensitive(response)}"\n';
    try {
      // print to console for immediate debugging
      print(entry);
      // append to file in working directory if possible
      final f = File(_logFile);
      await f.writeAsString(entry, mode: FileMode.append, flush: true);
    } catch (_) {
      // ignore file write errors (e.g., mobile sandboxing)
    }
  }

  // Metrics
  static int _totalCalls = 0;
  static int _totalSuccesses = 0;
  static int _totalFailures = 0;
  static int _totalLatencyMs = 0;

  Map<String, dynamic> getMetrics() {
    final avgLatency = _totalCalls > 0 ? (_totalLatencyMs / _totalCalls) : 0;
    return {
      'totalCalls': _totalCalls,
      'successes': _totalSuccesses,
      'failures': _totalFailures,
      'avgLatencyMs': avgLatency,
      'circuitOpen': _isCircuitOpen,
      'circuitOpenUntil': _circuitOpenUntil?.toIso8601String(),
      'failureCount': _failureCount,
    };
  }
  /// Sends a prompt to the configured LLM endpoint.
  ///
  /// This is a lightweight abstraction. By default, it attempts to read
  /// the environment variable `PPLX_API_KEY` (Perplexity). If not found,
  /// it returns a mocked response so the UI can be exercised offline.
  Future<String> sendPrompt(String prompt) async {
    final openaiKey = Platform.environment['OPENAI_API_KEY'];
    final pplxKey = Platform.environment['PPLX_API_KEY'];

    // Tunable retry/backoff parameters
    const int baseDelayMs = 200; // initial backoff
    const int maxAttemptsGlobal = 4; // attempts for sendPrompt
    const int maxDelayMs = 5000; // cap for backoff

    // Circuit breaker: if open, skip remote calls
    if (_isCircuitOpen) {
      final msg = 'LLM unavailable: circuit open until $_circuitOpenUntil';
      await _appendLog('SYSTEM', prompt, msg, success: false);
      return msg;
    }

    if ((openaiKey == null || openaiKey.isEmpty) && (pplxKey == null || pplxKey.isEmpty)) {
      // Mocked reply for offline/demo use
      await Future.delayed(const Duration(milliseconds: 400));
      const mock = 'Mock LLM response: I found 3 rides matching your request. (Set OPENAI_API_KEY or PPLX_API_KEY to enable real API)';
      await _appendLog('mock', prompt, mock, success: true);
      return mock;
    }

    // Attempt provider calls with simple backoff and logging
    final provider = (openaiKey != null && openaiKey.isNotEmpty) ? 'openai' : 'perplexity';
    final key = (provider == 'openai') ? openaiKey : pplxKey;

    const int maxAttempts = maxAttemptsGlobal;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final sw = Stopwatch()..start();
        if (provider == 'openai') {
          final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
          final body = jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {'role': 'system', 'content': 'You are Raahi assistant. Extract intents and answer concisely.'},
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 500,
          });
          final resp = await http.post(uri, headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json'
          }, body: body);
          final respText = resp.body;
          await _appendLog('openai', prompt, respText, success: resp.statusCode >= 200 && resp.statusCode < 300, attempt: attempt + 1);
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            final data = jsonDecode(resp.body);
            final content = data['choices']?[0]?['message']?['content'];
            _recordSuccess();
            sw.stop();
            _totalCalls += 1;
            _totalSuccesses += 1;
            _totalLatencyMs += sw.elapsedMilliseconds;
            return content?.toString() ?? resp.body;
          } else {
            _recordFailure();
            // backoff with cap and jitter
            final delay = min(maxDelayMs, baseDelayMs * (1 << attempt)) + (Random().nextInt(200));
            await Future.delayed(Duration(milliseconds: delay));
            continue;
          }
        } else {
          // Perplexity placeholder
          final uri = Uri.parse('https://api.perplexity.ai/v1/ask');
          final resp = await http.post(uri, headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json'
          }, body: jsonEncode({'question': prompt}));
          final respText = resp.body;
          await _appendLog('perplexity', prompt, respText, success: resp.statusCode >= 200 && resp.statusCode < 300, attempt: attempt + 1);
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            final data = jsonDecode(resp.body);
            _recordSuccess();
            sw.stop();
            _totalCalls += 1;
            _totalSuccesses += 1;
            _totalLatencyMs += sw.elapsedMilliseconds;
            return data['answer']?.toString() ?? data.toString();
          } else {
            _recordFailure();
            final delay = min(maxDelayMs, baseDelayMs * (1 << attempt)) + (Random().nextInt(200));
            await Future.delayed(Duration(milliseconds: delay));
            continue;
          }
        }
      } catch (e) {
        await _appendLog(provider, prompt, e.toString(), success: false, attempt: attempt + 1);
        _recordFailure();
        _totalCalls += 1;
        _totalFailures += 1;
        final delay = min(maxDelayMs, baseDelayMs * (1 << attempt)) + (Random().nextInt(200));
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    const failMsg = 'LLM request failed after retries';
    await _appendLog(provider, prompt, failMsg, success: false);
    _totalCalls += 1;
    _totalFailures += 1;
    return failMsg;
  }

  /// Simple intent parsing stub. Real implementation should call a robust NLP parser.
  Map<String, dynamic> parseIntent(String llmText) {
    // TODO: implement real intent parsing using the LLM
    if (llmText.toLowerCase().contains('create')) {
      return {'intent': 'create_ride'};
    }
    if (llmText.toLowerCase().contains('find')) {
      return {'intent': 'find_ride'};
    }
    return {'intent': 'unknown'};
  }

  /// Attempts to parse a natural language booking command.
  /// Example supported formats:
  /// "book a ride from greater noida to delhi at 10 am through cab"
  Map<String, dynamic>? parseBookingCommand(String text) {
    final s = text.toLowerCase();

    // Simple regex to capture 'from X to Y at TIME' and optional vehicle
    final reg = RegExp(r'from\s+(.+?)\s+to\s+(.+?)\s+at\s+(\d{1,2}(?::\d{2})?)\s*(am|pm)?(?:.*?(cab|car|bike))?');
    final m = reg.firstMatch(s);
    if (m != null) {
      final from = m.group(1)?.trim();
      final to = m.group(2)?.trim();
      final time = m.group(3)?.trim();
      final ampm = m.group(4)?.trim();
      final vehicle = m.group(5)?.trim() ?? 'cab';

      DateTime? dateTime;
      try {
        final parts = time!.split(':');
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (ampm != null && ampm.isNotEmpty) {
          if (ampm == 'pm' && hour < 12) hour += 12;
          if (ampm == 'am' && hour == 12) hour = 0;
        }
        final now = DateTime.now();
        dateTime = DateTime(now.year, now.month, now.day, hour, minute);
        // If time already passed today, schedule for tomorrow
        if (dateTime.isBefore(now)) {
          dateTime = dateTime.add(const Duration(days: 1));
        }
      } catch (_) {
        dateTime = null;
      }

      return {
        'pickup': from,
        'drop': to,
        'datetime': dateTime?.toIso8601String(),
        'vehicle': vehicle,
      };
    }

    return null;
  }

  /// Ask the LLM to extract booking information in strict JSON format.
  /// Returns a Map with keys: pickup, drop, datetime (ISO), vehicle
  Future<Map<String, dynamic>?> sendStructuredExtraction(String text) async {
    final openaiKey = Platform.environment['OPENAI_API_KEY'];

    // Helper to validate and sanitize the parsed booking map
    Map<String, dynamic>? sanitize(Map<String, dynamic>? raw) {
      if (raw == null) return null;
      final Map<String, dynamic> out = {};
      // pickup
      final pickup = raw['pickup'];
      out['pickup'] = (pickup is String && pickup.trim().isNotEmpty) ? pickup.trim() : null;
      // drop
      final drop = raw['drop'];
      out['drop'] = (drop is String && drop.trim().isNotEmpty) ? drop.trim() : null;
      // vehicle
      final vehicle = raw['vehicle'];
      out['vehicle'] = (vehicle is String && vehicle.trim().isNotEmpty) ? vehicle.trim() : null;
      // datetime: accept null or ISO-like string; try to parse and reformat
      final dt = raw['datetime'];
      if (dt == null) {
        out['datetime'] = null;
      } else if (dt is String) {
        try {
          final parsed = DateTime.parse(dt);
          out['datetime'] = parsed.toIso8601String();
        } catch (_) {
          // Try to not fail: leave as null
          out['datetime'] = null;
        }
      } else {
        out['datetime'] = null;
      }

      // if pickup and drop are both null, consider invalid
      if (out['pickup'] == null && out['drop'] == null) return null;
      return out;
    }

    // If OpenAI key available, try several extraction attempts with a strict prompt and retries
    if (openaiKey != null && openaiKey.isNotEmpty) {
      const system = '''You are Raahi assistant. MUST OUTPUT ONLY a single valid JSON object (no surrounding text or explanation).\n\nSchema: {"pickup": string|null, "drop": string|null, "datetime": string|null, "vehicle": string|null}\n\nRules:\n- Use null for missing fields.\n- Datetime must be ISO 8601 if present.\n- Output EXACTLY one JSON object and nothing else.\n\nExamples:\nInput: "book a ride from Greater Noida to Delhi at 10 am through cab"\nOutput: {"pickup": "Greater Noida", "drop": "Delhi", "datetime": "2025-12-02T10:00:00", "vehicle": "cab"}\n\nInput: "take me from hostel to lecture hall tomorrow morning"\nOutput: {"pickup": "hostel", "drop": "lecture hall", "datetime": null, "vehicle": null}\n\nInput: "cab from park to airport at 7:30 pm"\nOutput: {"pickup": "park", "drop": "airport", "datetime": "2025-12-02T19:30:00", "vehicle": "cab"}\n\nReturn only the JSON object.''';

      const maxTries = 3;
      final rand = Random();
      const int baseDelayMs = 200;
      const int maxDelayMs = 5000;
      for (var attempt = 0; attempt < maxTries; attempt++) {
        final sw = Stopwatch()..start();
        try {
          final body = jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': 'Input: "$text"'}
            ],
            'temperature': 0.0,
            'max_tokens': 300,
          });

          final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
          final resp = await http.post(uri, headers: {
            'Authorization': 'Bearer $openaiKey',
            'Content-Type': 'application/json'
          }, body: body);

          final respText = resp.body;
          await _appendLog('openai', text, respText, success: resp.statusCode >= 200 && resp.statusCode < 300, attempt: attempt + 1);

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            final data = jsonDecode(resp.body);
            final dynamicChoice = data['choices']?[0]?['message']?['content'];
            if (dynamicChoice == null) {
              _recordFailure();
              final delayMs = min(maxDelayMs, baseDelayMs * (1 << attempt)) + rand.nextInt(100);
              await Future.delayed(Duration(milliseconds: delayMs));
              continue;
            }

            final content = dynamicChoice.toString();
            // extract JSON substring
            final jsonStart = content.indexOf('{');
            final jsonEnd = content.lastIndexOf('}');
            if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
              final jsonText = content.substring(jsonStart, jsonEnd + 1);
              try {
                final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
                final sanitized = sanitize(parsed);
                if (sanitized != null) {
                  _recordSuccess();
                  sw.stop();
                  _totalCalls += 1;
                  _totalSuccesses += 1;
                  _totalLatencyMs += sw.elapsedMilliseconds;
                  return sanitized;
                }
                _recordFailure();
              } catch (e) {
                _recordFailure();
                await _appendLog('openai', text, 'JSON parse error: $e', success: false, attempt: attempt + 1);
              }
            } else {
              _recordFailure();
              await _appendLog('openai', text, 'No JSON object found in response', success: false, attempt: attempt + 1);
            }
            final delayMs = min(maxDelayMs, baseDelayMs * (1 << attempt)) + rand.nextInt(150);
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          } else {
            _recordFailure();
            final delayMs = min(maxDelayMs, baseDelayMs * (1 << attempt)) + rand.nextInt(150);
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
        } catch (e) {
          _recordFailure();
          await _appendLog('openai', text, 'Request error: $e', success: false, attempt: attempt + 1);
          final delayMs = min(maxDelayMs, baseDelayMs * (1 << attempt)) + rand.nextInt(150);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
        sw.stop();
        _totalCalls += 1;
        _totalFailures += 1;
      }
    }

    // If OpenAI not available or extraction failed, try a final fallback: try local regex parser
    final fallback = parseBookingCommand(text);
    return sanitize(fallback);
  }
}
