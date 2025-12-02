import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../main.dart';
import '../services/llm_service.dart';
import '../services/sos_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_ride_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late stt.SpeechToText _speech;
  bool _listening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final womenOnly = ref.watch(womenOnlyProvider);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Raahi'),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () => _showNotifications(context),
            ),
            IconButton(
              icon: const Icon(Icons.sos),
              onPressed: () => _showSOS(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Go-To Places', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Row(children: [
                    const Text('Women-only'),
                    Switch(value: womenOnly, onChanged: (v) => ref.read(womenOnlyProvider.notifier).state = v),
                  ])
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Hostel → Lecture Hall'),
                  trailing: ElevatedButton(onPressed: () {}, child: const Text('Join Trip')),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_road),
                  title: const Text('Create a Trip'),
                  trailing: ElevatedButton(onPressed: () {}, child: const Text('Create')),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                  label: Text(_listening ? 'Listening...' : 'Namaste Raahi (Voice)'),
                  onPressed: _toggleListening,
                ),
              ),
              if (_lastWords.isNotEmpty) Padding(padding: const EdgeInsets.only(top:12.0), child: Text('Heard: "$_lastWords"'))
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) {
      return ListView(
        shrinkWrap: true,
        children: const [
          ListTile(title: Text('Ride reminder: Your trip at 9 AM')), 
          ListTile(title: Text('You earned 5 Raahi Coins')),
        ],
      );
    });
  }

  void _showSOS(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.call), title: const Text('Call Family'), onTap: () async {
          try {
            await SosService.callEmergencyNumber('+911234567890');
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot place call on this device')));
          }
        }),
        ListTile(leading: const Icon(Icons.security), title: const Text('Call Campus Security'), onTap: () async {
          try {
            await SosService.callEmergencyNumber('+911112223334');
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot place call on this device')));
          }
        }),
        ListTile(leading: const Icon(Icons.share_location), title: const Text('Share Live Location'), onTap: () async {
          // Placeholder: in production, capture location and send to emergency contacts
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared live location (stub)')));
        }),
        ListTile(leading: const Icon(Icons.notification_important), title: const Text('Send Distress Notification'), onTap: () async {
          try {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
            await SosService.broadcastSos(uid: uid, message: 'I need help. Please check my live location.');
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Distress notification sent (stub)')));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send distress notification')));
          }
        }),
      ]);
    });
  }

  

  void _toggleListening() async {
    if (!_listening) {
      final available = await _speech.initialize();
      if (!available) return;
      setState(() {
        _listening = true;
        _lastWords = '';
      });
      _speech.listen(onResult: (result) async {
        setState(() {
          _lastWords = result.recognizedWords;
        });
        if (result.finalResult) {
          setState(() => _listening = false);
          final cmd = _lastWords;
          if (cmd.trim().isEmpty) return;
          final llm = LlmService();
          final structured = await llm.sendStructuredExtraction(cmd);
          Map<String, dynamic>? parse = structured;
          parse ??= llm.parseBookingCommand(cmd);
          if (parse != null) {
            final pickup = parse['pickup'] as String?;
            final drop = parse['drop'] as String?;
            final dtIso = parse['datetime'] as String?;
            DateTime? dt;
            if (dtIso != null) dt = DateTime.tryParse(dtIso);
              final vehicle = parse['vehicle'] as String?;
              if (context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateRideScreen(initialPickup: pickup, initialDrop: drop, initialDateTime: dt, initialVehicle: vehicle, autoConfirm: true)));
              }
          } else {
            final resp = await llm.sendPrompt(cmd);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp)));
          }
        }
      });
    } else {
      _speech.stop();
      setState(() => _listening = false);
    }
  }
}
