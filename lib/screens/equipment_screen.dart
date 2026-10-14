import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'equipment_detail_screen.dart';
import 'locations_screen.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  List<Map<String, dynamic>> equipmentList = [];
  List<Map<String, dynamic>> locations = [];
  bool isLoading = true;
  String searchQuery = '';
  String? locationFilter;
  static const String _storageKey = 'equipment';
  static const String _locationsKey = 'equipment_locations';

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
      await prefs.setString(_locationsKey, jsonEncode(locations));
    }

    final String? raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw);
      equipmentList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      bool migrated = false;
      for (final e in equipmentList) {
        e.remove('category');

        final oldLoc = e['location']?.toString();
        if (oldLoc != null && oldLoc.isNotEmpty && e['locationId'] == null) {
          final found = locations.firstWhere(
            (l) => l['name'].toString().toLowerCase() == oldLoc.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (found.isNotEmpty) {
            e['locationId'] = found['id'];
          } else {
            final newLoc = {
              'id':
                  'loc_${DateTime.now().millisecondsSinceEpoch}_${e.hashCode}',
              'name': oldLoc,
            };
            locations.add(newLoc);
            e['locationId'] = newLoc['id'];
          }
          migrated = true;
        }
        e.remove('location');
      }
      if (migrated) {
        await _save();
        await _saveLocations();
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(equipmentList));
  }

  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationsKey, jsonEncode(locations));
  }

  Future<void> _reloadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLoc = prefs.getString(_locationsKey);
    if (rawLoc != null && rawLoc.isNotEmpty) {
      setState(() {
        locations = (jsonDecode(rawLoc) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  String? _locationName(String? id) {
    if (id == null) return null;
    final loc = locations.firstWhere((l) => l['id'] == id, orElse: () => {});
    return loc['name'] as String?;
  }

  int _countInLocation(String locId) {
    return equipmentList.where((e) => e['locationId'] == locId).length;
  }

  List<Map<String, dynamic>> get _filtered {
    return equipmentList.where((e) {
      if (locationFilter != null && e['locationId'] != locationFilter) {
        return false;
      }
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final name = (e['name'] ?? '').toString().toLowerCase();
      final locName = (_locationName(e['locationId']?.toString()) ?? '')
          .toLowerCase();
      return name.contains(q) || locName.contains(q);
    }).toList();
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? locationId = locations.isNotEmpty
        ? locations.first['id'] as String
        : null;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Новое оборудование'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Станок токарный 1К62',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: locationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Место расположения',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— Без привязки —'),
                        ),
                        ...locations.map((l) {
                          return DropdownMenuItem<String?>(
                            value: l['id'].toString(),
                            child: Text(l['name'] ?? ''),
                          );
                        }),
                      ],
                      onChanged: (v) => setDialogState(() => locationId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Описание',
                        hintText: 'Краткое описание / назначение',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
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
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      equipmentList.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'name': nameCtrl.text.trim(),
                        'locationId': locationId,
                        'description': descCtrl.text.trim(),
                        'spareParts': <Map<String, dynamic>>[],
                        'files': <Map<String, dynamic>>[],
                      });
                    });
                    await _save();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openDetail(Map<String, dynamic> equipment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquipmentDetailScreen(
          equipment: equipment,
          onChanged: _save,
          onDelete: () async {
            setState(() => equipmentList.remove(equipment));
            await _save();
          },
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _deleteEquipment(Map<String, dynamic> equipment) async {
    setState(() => equipmentList.remove(equipment));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Поиск',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Места расположения',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocationsScreen(),
                      ),
                    );
                    await _reloadLocations();
                  },
                  icon: const Icon(Icons.place_outlined),
                ),
              ],
            ),
          ),

          if (locations.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: Text('Все (${equipmentList.length})'),
                    selected: locationFilter == null,
                    onSelected: (_) => setState(() => locationFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...locations.map((l) {
                    final count = _countInLocation(l['id'].toString());
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.place, size: 16),
                        label: Text('${l['name']} ($count)'),
                        selected: locationFilter == l['id'],
                        onSelected: (_) =>
                            setState(() => locationFilter = l['id'].toString()),
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      equipmentList.isEmpty
                          ? 'Оборудования пока нет.\nНажми «+», чтобы добавить.'
                          : 'Ничего не найдено',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final eq = filtered[index];
                      final parts = (eq['spareParts'] as List?)?.length ?? 0;
                      final files = (eq['files'] as List?)?.length ?? 0;
                      final locName = _locationName(
                        eq['locationId']?.toString(),
                      );

                      return Dismissible(
                        key: ValueKey(eq['id'] ?? index.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteEquipment(eq),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              eq['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (locName != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.place,
                                          size: 12,
                                          color: Color(0xFF1B5E20),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          locName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1B5E20),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.settings,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$parts запч.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.attach_file,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$files док.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openDetail(eq),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
