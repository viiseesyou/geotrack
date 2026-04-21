import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'encryption_service.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _selectedChild;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final groups = await _firestore
        .collection('groups')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    final memberIds = <String>{};
    for (final group in groups.docs) {
      final members = List<String>.from(group['members']);
      memberIds.addAll(members);
    }
    memberIds.remove(user.uid);

    final children = <Map<String, dynamic>>[];
    for (final id in memberIds) {
      final doc = await _firestore.collection('users').doc(id).get();
      if (doc.exists) {
        children.add({...doc.data()!, 'uid': id});
      }
    }
    setState(() => _children = children);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Режим родителя'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildren,
          ),
        ],
      ),
      body: _children.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.child_care, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет участников в ваших группах',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Создайте группу и пригласите\nсвоих близких',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadChildren,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Обновить'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Список участников
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    itemCount: _children.length,
                    itemBuilder: (context, index) {
                      final child = _children[index];
                      final isSelected = _selectedChild?['uid'] == child['uid'];
                      final isOnline = child['isOnline'] ?? false;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedChild = child);
                          if (child['latitude'] != null &&
                              child['longitude'] != null) {
                            final lat = child['latitude'] is String
                                ? EncryptionService.decryptCoordinate(
                                    child['latitude'],
                                  )
                                : (child['latitude'] as num).toDouble();
                            final lng = child['longitude'] is String
                                ? EncryptionService.decryptCoordinate(
                                    child['longitude'],
                                  )
                                : (child['longitude'] as num).toDouble();
                            _mapController.move(LatLng(lat, lng), 16);
                          }
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6C63FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected
                                        ? Colors.white.withOpacity(0.3)
                                        : const Color(0xFF6C63FF)
                                            .withOpacity(0.15),
                                    child: Icon(
                                      Icons.person,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF6C63FF),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                child['name'] ?? 'Участник',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isOnline ? 'онлайн' : 'офлайн',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Карта
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .where('isOnline', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final markers = <Marker>[];
                      if (snapshot.hasData) {
                        for (final doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final latRaw = data['latitude'];
                          final lngRaw = data['longitude'];
                          final lat = latRaw is String
                              ? EncryptionService.decryptCoordinate(latRaw)
                              : (latRaw as num?)?.toDouble();
                          final lng = lngRaw is String
                              ? EncryptionService.decryptCoordinate(lngRaw)
                              : (lngRaw as num?)?.toDouble();
                          final name = data['name'] ?? 'Участник';
                          final isChild = _children
                              .any((c) => c['uid'] == doc.id);
                          if (lat != null && lng != null && isChild) {
                            markers.add(
                              Marker(
                                point: LatLng(lat, lng),
                                width: 80,
                                height: 70,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE9C46A),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.location_pin,
                                        color: Color(0xFFE9C46A), size: 36),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                      }
                      return FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: LatLng(55.7558, 37.6173),
                          initialZoom: 10,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.geotrack',
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      );
                    },
                  ),
                ),
                // Инфо о выбранном участнике
                if (_selectedChild != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF6C63FF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedChild!['name'] ?? 'Участник',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _selectedChild!['latitude'] != null
                                    ? 'Координаты: ${(_selectedChild!['latitude'] as double).toStringAsFixed(4)}, ${(_selectedChild!['longitude'] as double).toStringAsFixed(4)}'
                                    : 'Геолокация недоступна',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}