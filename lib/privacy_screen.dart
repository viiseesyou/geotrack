import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_service.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isVisible = true;
  bool _isTracking = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        _isVisible = doc.data()?['isVisible'] ?? true;
        _isTracking = doc.data()?['isOnline'] ?? false;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Конфиденциальность'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Управление геолокацией',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildToggleCard(
                    icon: Icons.location_on,
                    title: 'Делиться геолокацией',
                    subtitle: 'Участники ваших групп видят вас на карте',
                    color: const Color(0xFF6C63FF),
                    value: _isTracking,
                    onChanged: (value) async {
                      setState(() => _isTracking = value);
                      if (value) {
                        await LocationService.startTracking();
                      } else {
                        await LocationService.stopTracking();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildToggleCard(
                    icon: Icons.visibility,
                    title: 'Видимость на карте',
                    subtitle: 'Показывать ваш маркер другим пользователям',
                    color: const Color(0xFF43AA8B),
                    value: _isVisible,
                    onChanged: (value) async {
                      setState(() => _isVisible = value);
                      await LocationService.setVisibility(value);
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Информация о данных',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.shield,
                    title: 'Шифрование данных',
                    subtitle:
                        'Все данные передаются по защищённому каналу HTTPS и хранятся в зашифрованном виде',
                    color: const Color(0xFFE76F51),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.group,
                    title: 'Доступ только для группы',
                    subtitle:
                        'Ваша геолокация видна только участникам ваших групп — никому другому',
                    color: const Color(0xFF6C63FF),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.delete,
                    title: 'Удаление данных',
                    subtitle:
                        'Вы можете в любой момент остановить отслеживание — данные перестанут обновляться',
                    color: const Color(0xFFE9C46A),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Опасная зона',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить данные'),
                            content: const Text(
                                'Все ваши данные геолокации будут удалены. Продолжить?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final user = _auth.currentUser;
                          if (user != null) {
                            await _firestore
                                .collection('users')
                                .doc(user.uid)
                                .update({
                              'latitude': FieldValue.delete(),
                              'longitude': FieldValue.delete(),
                              'isOnline': false,
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Данные геолокации удалены')),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Удалить мои данные геолокации',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}