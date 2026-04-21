import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_service.dart';
import 'encryption_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _isTracking = false;
  String _errorMessage = '';
  List<Marker> _userMarkers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToUsers();
  }

  @override
  void dispose() {
    LocationService.stopTracking();
    super.dispose();
  }

  void _listenToUsers() {
    LocationService.getUsersStream().listen((snapshot) {
      final markers = <Marker>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final latRaw = data['latitude'];
        final lngRaw = data['longitude'];
        final lat = latRaw is String
            ? EncryptionService.decryptCoordinate(latRaw)
            : (latRaw as num?)?.toDouble();
        final lng = lngRaw is String
            ? EncryptionService.decryptCoordinate(lngRaw)
            : (lngRaw as num?)?.toDouble();
        final name = data['name'] ?? 'Пользователь';
        if (lat != null && lng != null) {
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.location_pin,
                      color: Color(0xFF6C63FF), size: 36),
                ],
              ),
            ),
          );
        }
      }
      setState(() => _userMarkers = markers);
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Доступ к геолокации запрещён';
            _isLoading = false;
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка получения геолокации: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await LocationService.stopTracking();
      setState(() => _isTracking = false);
    } else {
      await LocationService.startTracking();
      setState(() => _isTracking = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.location_on : Icons.location_off),
            tooltip: _isTracking ? 'Остановить' : 'Поделиться локацией',
            onPressed: _toggleTracking,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  SizedBox(height: 16),
                  Text('Определяем местоположение...'),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentPosition!,
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.geotrack',
                        ),
                        MarkerLayer(markers: _userMarkers),
                      ],
                    ),
                    if (_isTracking)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.greenAccent, size: 10),
                                SizedBox(width: 8),
                                Text('Геолокация активна',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: _currentPosition != null
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF6C63FF),
              onPressed: () => _mapController.move(_currentPosition!, 15),
              child: const Icon(Icons.my_location, color: Colors.white),
            )
          : null,
    );
  }
}