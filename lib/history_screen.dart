import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'encryption_service.dart';
import 'location_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final MapController _mapController = MapController();
  List<LatLng> _historyPoints = [];
  bool _isLoading = true;
  String? _groupKey;
  String _selectedPeriod = '24h';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    _groupKey = await LocationService.getGroupKey();
    final user = _auth.currentUser;
    if (user == null || _groupKey == null) {
      setState(() => _isLoading = false);
      return;
    }

    final hours = _selectedPeriod == '1h'
        ? 1
        : _selectedPeriod == '6h'
            ? 6
            : 24;

    final since = DateTime.now().subtract(Duration(hours: hours));

    final snapshot = await _firestore
        .collection('location_history')
        .where('uid', isEqualTo: user.uid)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: false)
        .get();

    final points = <LatLng>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final latData = data['lat_data'] as String?;
      final latIv = data['lat_iv'] as String?;
      final lngData = data['lng_data'] as String?;
      final lngIv = data['lng_iv'] as String?;

      if (latData != null && latIv != null && lngData != null && lngIv != null) {
        final lat = EncryptionService.decryptCoordinate(latData, latIv, _groupKey!);
        final lng = EncryptionService.decryptCoordinate(lngData, lngIv, _groupKey!);
        if (lat != 0.0 && lng != 0.0) {
          points.add(LatLng(lat, lng));
        }
      }
    }

    setState(() {
      _historyPoints = points;
      _isLoading = false;
    });

    if (points.isNotEmpty) {
      _mapController.move(points.last, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('История перемещений'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Фильтр периода
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Период: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _buildPeriodButton('1h', '1 час'),
                const SizedBox(width: 8),
                _buildPeriodButton('6h', '6 часов'),
                const SizedBox(width: 8),
                _buildPeriodButton('24h', '24 часа'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF)))
                : _historyPoints.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Нет данных за выбранный период',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Включите геолокацию чтобы\nначать записывать историю',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _historyPoints.isNotEmpty
                                  ? _historyPoints.last
                                  : const LatLng(55.7558, 37.6173),
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.example.geotrack',
                              ),
                              // Линия маршрута
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _historyPoints,
                                    color: const Color(0xFF6C63FF),
                                    strokeWidth: 4,
                                  ),
                                ],
                              ),
                              // Начальная точка
                              MarkerLayer(
                                markers: [
                                  if (_historyPoints.isNotEmpty)
                                    Marker(
                                      point: _historyPoints.first,
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF43AA8B),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                  // Конечная точка
                                  if (_historyPoints.length > 1)
                                    Marker(
                                      point: _historyPoints.last,
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE76F51),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.stop,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          // Инфо панель
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStat('📍', 'Точек',
                                      '${_historyPoints.length}'),
                                  _buildStat('🟢', 'Начало', 'старт'),
                                  _buildStat('🔴', 'Конец', 'финиш'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = period);
        _loadHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 13,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}