import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? currentUid() => _auth.currentUser?.uid;

  static Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Start phone verification and return the verificationId when code is sent.
  /// Completes with null if verification failed before code sent.
  static Future<String?> verifyPhoneNumber(String phoneNumber, {Duration timeout = const Duration(seconds: 60)}) async {
    final Completer<String?> completer = Completer();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-sign-in on some devices
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete(null);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      timeout: timeout,
    );

    return completer.future;
  }

  static Future<UserCredential> signInWithSmsCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    return await _auth.signInWithCredential(credential);
  }
}
