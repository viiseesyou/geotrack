import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'encryption_service.dart';

class LocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<Position>? _positionStream;

  static Future<void> startTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': user.displayName ?? user.email ?? 'Пользователь',
      'email': user.email,
      'isOnline': true,
      'isVisible': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      await _firestore.collection('users').doc(user.uid).update({
        'latitude': EncryptionService.encryptCoordinate(position.latitude),
        'longitude': EncryptionService.encryptCoordinate(position.longitude),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> stopTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    _positionStream?.cancel();
    _positionStream = null;
  }

  static Future<void> setVisibility(bool visible) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isVisible': visible,
      });
    }
  }

  // Получить участников групп пользователя
  static Future<List<String>> getGroupMemberIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final groups = await _firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .get();

    final memberIds = <String>{user.uid};
    for (final group in groups.docs) {
      final members = List<String>.from(group['members']);
      memberIds.addAll(members);
    }
    return memberIds.toList();
  }

  static Stream<QuerySnapshot> getUsersStream() {
    return _firestore
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .where('isVisible', isEqualTo: true)
        .snapshots();
  }
}