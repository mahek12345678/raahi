import 'package:url_launcher/url_launcher.dart';

/// SOS helper service.
/// Currently contains local stubs: phone call launcher and message composer.
class SosService {
  /// Launch a phone call to the given `phoneNumber`.
  /// On mobile this will open the dialer. This is a best-effort helper.
  static Future<void> callEmergencyNumber(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Cannot launch phone dialer for $phoneNumber');
    }
  }

  /// Compose an SMS to `phoneNumber` with `message` body.
  /// Note: Some platforms may require prefixing with sms: or using platform channels for full support.
  static Future<void> sendSms(String phoneNumber, String message) async {
    final uri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Cannot compose SMS to $phoneNumber');
    }
  }

  /// Compose an SOS message for nearby helpers — placeholder for FCM / Twilio integration.
  static Future<void> broadcastSos({required String uid, required String message}) async {
    // TODO: integrate with FCM topic or Twilio programmable SMS / emergency gateway.
    // For now write to console and rely on server-side integration later.
    // ignore: avoid_print
    print('SOS broadcast from $uid: $message');
  }
}
