import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class Geozone {
  final String id;
  final String name;
  final LatLng center;
  final double radius;
  final String groupId;
  final String createdBy;

  Geozone({
    required this.id,
    required this.name,
    required this.center,
    required this.radius,
    required this.groupId,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'radius': radius,
        'groupId': groupId,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory Geozone.fromMap(String id, Map<String, dynamic> map) => Geozone(
        id: id,
        name: map['name'] ?? 'Зона',
        center: LatLng(map['latitude'], map['longitude']),
        radius: (map['radius'] as num).toDouble(),
        groupId: map['groupId'] ?? '',
        createdBy: map['createdBy'] ?? '',
      );
}

class GeozoneService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, bool> _userZoneStatus = {};

  static Future<void> createGeozone(Geozone zone) async {
    await _firestore.collection('geozones').add(zone.toMap());
  }

  static Stream<List<Geozone>> getGroupGeozones(String groupId) {
    return _firestore
        .collection('geozones')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Geozone.fromMap(doc.id, doc.data()))
            .toList());
  }

  static Future<void> deleteGeozone(String id) async {
    await _firestore.collection('geozones').doc(id).delete();
  }

  static Future<void> checkGeozones({
    required String userId,
    required String userName,
    required double lat,
    required double lng,
    required List<Geozone> zones,
  }) async {
    for (final zone in zones) {
      final distance = _calculateDistance(
        lat, lng,
        zone.center.latitude, zone.center.longitude,
      );

      final isInside = distance <= zone.radius;
      final key = '${userId}_${zone.id}';
      final wasInside = _userZoneStatus[key];

      if (wasInside == null) {
        _userZoneStatus[key] = isInside;
        continue;
      }

      if (!wasInside && isInside) {
        _userZoneStatus[key] = true;
        // TODO: уведомления когда войдёт в зону
      } else if (wasInside && !isInside) {
        _userZoneStatus[key] = false;
        // TODO: уведомления когда выйдет из зоны
      }
    }
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}