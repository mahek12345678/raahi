import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// Geospatial helper stubs for ride matching.
/// This file contains example pseudocode and helper functions demonstrating
/// how geospatial querying against Firestore could be structured.
class GeospatialService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Example: find nearby rides within `radiusKm` of the given lat/lng.
  /// In a production app use `geoflutterfire` or store geohashes to run efficient queries.
  static Future<List<Map<String, dynamic>>> findNearbyRides(double lat, double lng, {double radiusKm = 10}) async {
    // NOTE: Firestore doesn't support native geo queries; use a library like geoflutterfire
    // to create bounding boxes with geohashes. Here we show a simple approach of
    // querying by an indexed field `approxCity` or similar, then filtering client-side.

    final candidates = await _db.collection('rides').where('status', isEqualTo: 'open').limit(50).get();
    // naively filter by distance on client — replace with geohash-based query for scale.
    final results = <Map<String, dynamic>>[];
    for (final doc in candidates.docs) {
      final data = doc.data();
      if (data['pickupLocation'] is Map) {
        final loc = data['pickupLocation'] as Map<String, dynamic>;
        final double plat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
        final double plng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
        final d = _haversineDistanceKm(lat, lng, plat, plng);
        if (d <= radiusKm) {
          results.add({'id': doc.id, ...data, 'distanceKm': d});
        }
      }
    }
    results.sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
    return results;
  }

  static double _haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (3.141592653589793 / 180.0);
}
