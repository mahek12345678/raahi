import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Small helper to initialize Firebase and provide basic Firestore helpers.
class FirebaseService {
  static FirebaseApp? _app;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Initialize Firebase. If google-services files are missing this will throw.
  static Future<void> initialize() async {
    if (_app != null) return;
    _app = await Firebase.initializeApp();
  }

  /// Create a ride document in `rides` collection.
  /// Returns the created document id.
  static Future<String> createRide(Map<String, dynamic> rideData) async {
    final ref = await _db.collection('rides').add(rideData);
    return ref.id;
  }

  /// Fetch rides for a given user id.
  static Future<List<Map<String, dynamic>>> getRidesForUser(String uid) async {
    final snap = await _db.collection('rides').where('ownerId', isEqualTo: uid).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Update user's coins and streak atomically using transaction.
  static Future<void> updateUserCoinsAndStreak(String uid, int deltaCoins, {bool incrementStreak = false}) async {
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final currentCoins = (data['coins'] as int?) ?? 0;
      final currentStreak = (data['streak'] as int?) ?? 0;
      tx.set(ref, {
        'coins': currentCoins + deltaCoins,
        'streak': incrementStreak ? (currentStreak + 1) : currentStreak,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Simple helper to write or update a profile document.
  static Future<void> setUserProfile(String uid, Map<String, dynamic> profile) async {
    await _db.collection('users').doc(uid).set(profile, SetOptions(merge: true));
  }
}
