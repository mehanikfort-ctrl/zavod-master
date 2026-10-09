import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> regulationCategories = [
  '💧 Вода',
  '⚡ Электрика',
  '🔥 Газ',
  '🏗️ Кран',
  '🔧 Механика',
  '💻 Электроника',
  '📊 Счётчики',
];

const List<Map<String, dynamic>> regulationTypes = [
  {'key': 'daily', 'label': 'Ежедневно'},
  {'key': 'weekly', 'label': 'Еженедельно'},
  {'key': 'monthly', 'label': 'Ежемесячно'},
];

const List<String> weekDays = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

class RegulationsScreen extends StatefulWidget {
  const RegulationsScreen({super.key});

  @override
  State<RegulationsScreen> createState() => _RegulationsScreenState();
}

class _RegulationsScreenState extends State<RegulationsScreen> {
  List<Map<String, dynamic>> regulations = [];
  List<Map<String, dynamic>> equipmentList = [];
  bool isLoading = true;
  static const String _storageKey = 'regulations';
  static const String _equipmentKey = 'equipment';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final rawRegs = prefs.getString(_storageKey);
    if (rawRegs != null && rawRegs.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(rawRegs);
      regulations = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      // Стартовые регламенты — под твои реалии
      regulations = [
        {
          'id': 'reg_meters',
          'title': 'Передать показания счётчиков',
          'category': '📊 Счётчики',
          'priority': '🟢 Плановое',
          'equipmentId': null,
          'type': 'monthly',
          'dayOfMonth': 25,
          'weekday': null,
          'enabled': true,
          'lastRun': null,
        },
        {
          'id': 'reg_tp_walk',
          'title': 'Обход трансформаторной подстанции',
          'category': '⚡ Электрика',
          'priority': '🟡 Средний',
          'equipmentId': null,
          'type': 'weekly',
          'dayOfMonth': null,
          'weekday': 1,
          'enabled': true,
          'lastRun': null,
        },
        {
          'id': 'reg_gas_check',
          'title': 'Проверка газового оборудования',
          'category': '🔥 Газ',
          'priority': '🔴 Срочно',
          'equipmentId': null,
          'type': 'daily',
          'dayOfMonth': null,
          'weekday': null,
          'enabled': true,
          'lastRun': null,
        },
      ];
      await _save();
    }

    final rawEq = prefs.getString(_equipmentKey);
    if (rawEq != null && rawEq.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(rawEq);
      equipmentList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    setState(() => isLoading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(regulations));
  }

  String? _equipmentName(String? id) {
    if (id == null) return null;
    final eq = equipmentList.firstWhere((e) => e['id'] == id, orElse: () => {});
    return eq['name'] as String?;
  }

  String _describe(Map<String, dynamic> reg) {
    final type = reg['type'];
    if (type == 'daily') return 'Каждый день';
    if (type == 'weekly') {
      final wd = reg['weekday'] as int?;
      if (wd != null && wd >= 1 && wd <= 7) return 'Каждую ${weekDays[wd - 1]}';
      return 'Еженедельно';
    }
    if (type == 'monthly') {
      final d = reg['dayOfMonth'] ?? '?';
      return 'Каждое $d-е число';
    }
    return '';
  }

  Future<void> _toggleEnabled(int index) async {
    setState(() {
      regulations[index]['enabled'] = !(regulations[index]['enabled'] == true);
    });
    await _save();
  }

  Future<void> _deleteRegulation(int index) async {
    setState(() => regulations.removeAt(index));
    await _save();
  }

  Future<void> _showAddDialog() async {
    final titleCtrl = TextEditingController();
    String selectedCategory = regulationCategories.first;
    String selectedPriority = '🟡 Средний';
    String? selectedEquipmentId;
    String selectedType = 'monthly';
    int selectedDay = 25;
    int selectedWeekday = 1;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Новый регламент'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Проверить электрощит',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items: regulationCategories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedCategory = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: const InputDecoration(labelText: 'Приоритет'),
                      items: const [
                        DropdownMenuItem(
                          value: '🔴 Срочно',
                          child: Text('🔴 Срочно'),
                        ),
                        DropdownMenuItem(
                          value: '🟡 Средний',
                          child: Text('🟡 Средний'),
                        ),
                        DropdownMenuItem(
                          value: '🟢 Плановое',
                          child: Text('🟢 Плановое'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedPriority = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: selectedEquipmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Оборудование (опционально)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— Без привязки —'),
                        ),
                        ...equipmentList.map((e) {
                          return DropdownMenuItem<String?>(
                            value: e['id'] as String,
                            child: Text(
                              e['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedEquipmentId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Периодичность',
                      ),
                      items: regulationTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t['key'] as String,
                              child: Text(t['label'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedType = v!),
                    ),
                    if (selectedType == 'monthly') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: selectedDay,
                        decoration: const InputDecoration(
                          labelText: 'День месяца',
                        ),
                        items: List.generate(31, (i) => i + 1)
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text('$d-е'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedDay = v!),
                      ),
                    ],
                    if (selectedType == 'weekly') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: selectedWeekday,
                        decoration: const InputDecoration(
                          labelText: 'День недели',
                        ),
                        items: List.generate(
                          7,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(weekDays[i]),
                          ),
                        ).toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedWeekday = v!),
                      ),
                    ],
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
                    if (titleCtrl.text.trim().isEmpty) return;
                    setState(() {
                      regulations.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'title': titleCtrl.text.trim(),
                        'category': selectedCategory,
                        'priority': selectedPriority,
                        'equipmentId': selectedEquipmentId,
                        'type': selectedType,
                        'dayOfMonth': selectedType == 'monthly'
                            ? selectedDay
                            : null,
                        'weekday': selectedType == 'weekly'
                            ? selectedWeekday
                            : null,
                        'enabled': true,
                        'lastRun': null,
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (regulations.isEmpty) {
      return const Center(
        child: Text(
          'Регламентов пока нет.\nНажми «+», чтобы добавить.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: regulations.length,
        itemBuilder: (context, index) {
          final reg = regulations[index];
          final enabled = reg['enabled'] == true;
          final eqName = _equipmentName(reg['equipmentId']);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: enabled
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              leading: Switch(
                value: enabled,
                onChanged: (_) => _toggleEnabled(index),
                activeThumbColor: const Color(0xFF1B5E20),
              ),
              title: Text(
                reg['title'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.black : Colors.grey,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_describe(reg)}  •  ${reg['priority']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (eqName != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.build,
                            size: 12,
                            color: Color(0xFF1B5E20),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              eqName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1B5E20),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _deleteRegulation(index),
              ),
            ),
          );
        },
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
