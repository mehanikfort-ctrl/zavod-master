import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'equipment_detail_screen.dart';

const List<String> equipmentCategories = [
  '💧 Вода',
  '⚡ Электрика',
  '🔥 Газ',
  '🏗️ Кран',
  '🔧 Механика',
  '💻 Электроника',
  '📊 Счётчики',
];

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  List<Map<String, dynamic>> equipmentList = [];
  bool isLoading = true;
  String searchQuery = '';
  static const String _storageKey = 'equipment';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw);
      equipmentList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    setState(() => isLoading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(equipmentList));
  }

  List<Map<String, dynamic>> get _filtered {
    if (searchQuery.isEmpty) return equipmentList;
    final q = searchQuery.toLowerCase();
    return equipmentList.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final location = (e['location'] ?? '').toString().toLowerCase();
      return name.contains(q) || location.contains(q);
    }).toList();
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = equipmentCategories.first;

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
                        hintText: 'Насос центробежный №3',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items: equipmentCategories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (v) => setDialogState(() => category = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Расположение',
                        hintText: 'Цех №2, участок А',
                      ),
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
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      equipmentList.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'name': nameCtrl.text.trim(),
                        'category': category,
                        'location': locationCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'spareParts': <Map<String, dynamic>>[],
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
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск по названию или месту',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
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
                                if ((eq['location'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(eq['location']),
                                Text(
                                  '${eq['category']}  •  Запчастей: $parts',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
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
