import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'encryption_service.dart';

class LocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<Position>? _positionStream;
  static String? _groupKey;

  // Получить ключ группы для текущего пользователя
  static Future<String?> getGroupKey() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final groups = await _firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .get();

    if (groups.docs.isEmpty) return null;

    final groupData = groups.docs.first.data();
    final keys = groupData['keys'] as Map<String, dynamic>?;
    if (keys == null || !keys.containsKey(user.uid)) return null;

    final encryptedKey = keys[user.uid] as String;
    return EncryptionService.decryptKeyForUser(encryptedKey, user.uid);
  }

  static Future<void> startTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Получаем ключ группы
    _groupKey = await getGroupKey();

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
      if (_groupKey != null) {
        // Шифруем с уникальным IV для каждого обновления
        final encLat = EncryptionService.encryptCoordinate(
            position.latitude, _groupKey!);
        final encLng = EncryptionService.encryptCoordinate(
            position.longitude, _groupKey!);

        await _firestore.collection('users').doc(user.uid).update({
          'lat_data': encLat['data'],
          'lat_iv': encLat['iv'],
          'lng_data': encLng['data'],
          'lng_iv': encLng['iv'],
          'latitude': null,
          'longitude': null,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
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
    _groupKey = null;
  }

  static Future<void> setVisibility(bool visible) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isVisible': visible,
      });
    }
  }

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