import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'geozone_service.dart';

class GeozonesScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GeozonesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GeozonesScreen> createState() => _GeozonesScreenState();
}

class _GeozonesScreenState extends State<GeozonesScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  double _radius = 200;

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() => _selectedPoint = point);
  }

  Future<void> _createZone() async {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нажмите на карту чтобы выбрать место')),
      );
      return;
    }

    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Создать геозону'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название зоны',
                  hintText: 'Например: Школа, Дом',
                ),
              ),
              const SizedBox(height: 16),
              Text('Радиус: ${_radius.toInt()} м'),
              Slider(
                value: _radius,
                min: 50,
                max: 1000,
                divisions: 19,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (value) {
                  setDialogState(() => _radius = value);
                  setState(() => _radius = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final user = FirebaseAuth.instance.currentUser!;
                final zone = Geozone(
                  id: '',
                  name: nameController.text.trim(),
                  center: _selectedPoint!,
                  radius: _radius,
                  groupId: widget.groupId,
                  createdBy: user.uid,
                );
                await GeozoneService.createGeozone(zone);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() => _selectedPoint = null);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Геозоны — ${widget.groupName}'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location),
            onPressed: _createZone,
            tooltip: 'Добавить геозону',
          ),
        ],
      ),
      body: StreamBuilder<List<Geozone>>(
        stream: GeozoneService.getGroupGeozones(widget.groupId),
        builder: (context, snapshot) {
          final zones = snapshot.data ?? [];

          final circles = zones.map((zone) => CircleMarker(
                point: zone.center,
                radius: zone.radius,
                useRadiusInMeter: true,
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderColor: const Color(0xFF6C63FF),
                borderStrokeWidth: 2,
              )).toList();

          final markers = <Marker>[];

          // Добавляем метки зон
          for (final zone in zones) {
            markers.add(Marker(
              point: zone.center,
              width: 120,
              height: 40,
              child: GestureDetector(
                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Удалить "${zone.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await GeozoneService.deleteGeozone(zone.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '📍 ${zone.name}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ));
          }

          // Метка выбранной точки
          if (_selectedPoint != null) {
            markers.add(Marker(
              point: _selectedPoint!,
              width: 40,
              height: 40,
              child: const Icon(Icons.add_location,
                  color: Color(0xFFE76F51), size: 40),
            ));
          }

          return Column(
            children: [
              if (zones.isEmpty && _selectedPoint == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFEEF0FF),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF6C63FF)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Нажмите на карту чтобы выбрать место, затем нажмите + чтобы создать геозону',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6C63FF)),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(55.7558, 37.6173),
                    initialZoom: 13,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.geotrack',
                    ),
                    CircleLayer(circles: circles),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              if (zones.isNotEmpty)
                Container(
                  height: 120,
                  color: Colors.white,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    scrollDirection: Axis.horizontal,
                    itemCount: zones.length,
                    itemBuilder: (context, i) {
                      final zone = zones[i];
                      return GestureDetector(
                        onTap: () => _mapController.move(zone.center, 15),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF0FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF6C63FF), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(zone.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6C63FF))),
                              const SizedBox(height: 4),
                              Text('Радиус: ${zone.radius.toInt()} м',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              const Text('Удержите для удаления',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}