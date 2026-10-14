import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> equipment = [];
  bool isLoading = true;

  static const String _locationsKey = 'equipment_locations';
  static const String _equipmentKey = 'equipment';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final rawLoc = prefs.getString(_locationsKey);
    if (rawLoc != null && rawLoc.isNotEmpty) {
      locations = (jsonDecode(rawLoc) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      locations = [
        {'id': 'loc_1', 'name': 'Цех №1'},
        {'id': 'loc_2', 'name': 'Цех №2'},
        {'id': 'loc_3', 'name': 'Котельная'},
        {'id': 'loc_4', 'name': 'Буфер'},
        {'id': 'loc_5', 'name': 'Склад'},
      ];
      await _saveLocations();
    }

    final rawEq = prefs.getString(_equipmentKey);
    if (rawEq != null && rawEq.isNotEmpty) {
      equipment = (jsonDecode(rawEq) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationsKey, jsonEncode(locations));
  }

  Future<void> _saveEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_equipmentKey, jsonEncode(equipment));
  }

  int _countEquipment(String locId) {
    return equipment.where((e) => e['locationId'] == locId).length;
  }

  Future<String?> _askName({required String title, String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Название'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addLocation() async {
    final name = await _askName(title: 'Новое место');
    if (name == null) return;
    setState(() {
      locations.add({
        'id': 'loc_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
      });
    });
    await _saveLocations();
  }

  Future<void> _renameLocation(int index) async {
    final name = await _askName(
      title: 'Переименовать место',
      initial: locations[index]['name']?.toString(),
    );
    if (name == null) return;
    setState(() => locations[index]['name'] = name);
    await _saveLocations();
  }

  Future<void> _deleteLocation(int index) async {
    final locId = locations[index]['id'].toString();
    final count = _countEquipment(locId);

    String msg = 'Удалить место «${locations[index]['name']}»?';
    if (count > 0) {
      msg +=
          '\n\nК нему привязано $count ед. оборудования — они останутся без места.';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить место?'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    for (final eq in equipment) {
      if (eq['locationId'] == locId) {
        eq.remove('locationId');
      }
    }
    setState(() => locations.removeAt(index));
    await _saveLocations();
    await _saveEquipment();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Места расположения'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: locations.isEmpty
          ? const Center(
              child: Text(
                'Список мест пуст.\nНажми «+», чтобы добавить.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: locations.length,
              itemBuilder: (context, i) {
                final loc = locations[i];
                final count = _countEquipment(loc['id'].toString());
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1F1B5E20),
                      child: Icon(
                        Icons.place,
                        color: Color(0xFF1B5E20),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      loc['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$count ед. оборудования',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _renameLocation(i);
                        if (v == 'delete') _deleteLocation(i);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Переименовать'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
