import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meter_detail_screen.dart';

const List<Map<String, String>> meterTypes = [
  {'type': '⚡ Электрика', 'unit': 'кВт·ч'},
  {'type': '💧 Вода', 'unit': 'м³'},
  {'type': '🔥 Газ', 'unit': 'м³'},
  {'type': '🌡️ Тепло', 'unit': 'Гкал'},
];

class MetersScreen extends StatefulWidget {
  const MetersScreen({super.key});

  @override
  State<MetersScreen> createState() => _MetersScreenState();
}

class _MetersScreenState extends State<MetersScreen> {
  List<Map<String, dynamic>> meters = [];
  bool isLoading = true;
  static const String _storageKey = 'meters';

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
      meters = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      // Стартовый набор — твои 6 счётчиков
      meters = [
        {
          'id': '1',
          'name': 'Счётчик электроэнергии №1 (главный)',
          'type': '⚡ Электрика',
          'unit': 'кВт·ч',
          'location': 'ТП-1',
          'readings': <Map<String, dynamic>>[],
        },
        {
          'id': '2',
          'name': 'Счётчик электроэнергии №2',
          'type': '⚡ Электрика',
          'unit': 'кВт·ч',
          'location': 'Цех №1',
          'readings': <Map<String, dynamic>>[],
        },
        {
          'id': '3',
          'name': 'Счётчик электроэнергии №3',
          'type': '⚡ Электрика',
          'unit': 'кВт·ч',
          'location': 'Цех №2',
          'readings': <Map<String, dynamic>>[],
        },
        {
          'id': '4',
          'name': 'Счётчик газа',
          'type': '🔥 Газ',
          'unit': 'м³',
          'location': 'Котельная',
          'readings': <Map<String, dynamic>>[],
        },
        {
          'id': '5',
          'name': 'Счётчик воды №1',
          'type': '💧 Вода',
          'unit': 'м³',
          'location': 'Ввод в цех',
          'readings': <Map<String, dynamic>>[],
        },
        {
          'id': '6',
          'name': 'Счётчик воды №2',
          'type': '💧 Вода',
          'unit': 'м³',
          'location': 'Бытовые помещения',
          'readings': <Map<String, dynamic>>[],
        },
      ];
      await _save();
    }
    setState(() => isLoading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(meters));
  }

  // Есть ли показание за текущий месяц?
  bool _hasThisMonthReading(Map<String, dynamic> meter) {
    final readings = (meter['readings'] as List?) ?? [];
    final now = DateTime.now();
    return readings.any((r) {
      final d = DateTime.tryParse((r['date'] ?? '').toString());
      return d != null && d.year == now.year && d.month == now.month;
    });
  }

  // Сортировка показаний от новых к старым
  Map<String, dynamic>? _lastReading(Map<String, dynamic> meter) {
    final readings = (meter['readings'] as List?) ?? [];
    if (readings.isEmpty) return null;
    final sorted = readings.toList()
      ..sort(
        (a, b) => (b['date'] ?? '').toString().compareTo(
          (a['date'] ?? '').toString(),
        ),
      );
    return Map<String, dynamic>.from(sorted.first);
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String selectedType = meterTypes.first['type']!;
    String selectedUnit = meterTypes.first['unit']!;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Новый счётчик'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Счётчик воды №3',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Тип'),
                      items: meterTypes.map((t) {
                        return DropdownMenuItem(
                          value: t['type']!,
                          child: Text(t['type']!),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedType = v!;
                          selectedUnit = meterTypes.firstWhere(
                            (t) => t['type'] == v,
                          )['unit']!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Расположение',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Единица: $selectedUnit',
                      style: const TextStyle(color: Colors.grey),
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
                      meters.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'name': nameCtrl.text.trim(),
                        'type': selectedType,
                        'unit': selectedUnit,
                        'location': locationCtrl.text.trim(),
                        'readings': <Map<String, dynamic>>[],
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

  Future<void> _openDetail(Map<String, dynamic> meter) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeterDetailScreen(
          meter: meter,
          onChanged: _save,
          onDelete: () async {
            setState(() => meters.remove(meter));
            await _save();
          },
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _deleteMeter(Map<String, dynamic> meter) async {
    setState(() => meters.remove(meter));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Считаем, сколько счётчиков без показаний за этот месяц
    final now = DateTime.now();
    final needReading = meters.where((m) => !_hasThisMonthReading(m)).toList();

    return Scaffold(
      body: Column(
        children: [
          // Напоминание про 25-е число
          if (needReading.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Показаний за ${now.month < 10 ? '0${now.month}' : now.month}.${now.year} нет у ${needReading.length} счётч. Напоминание: до 25-го числа!',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: meters.isEmpty
                ? const Center(
                    child: Text(
                      'Счётчиков пока нет.\nНажми «+», чтобы добавить.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: meters.length,
                    itemBuilder: (context, index) {
                      final m = meters[index];
                      final last = _lastReading(m);
                      final hasThisMonth = _hasThisMonthReading(m);

                      return Dismissible(
                        key: ValueKey(m['id'] ?? index.toString()),
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
                        onDismissed: (_) => _deleteMeter(m),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: hasThisMonth
                                ? BorderSide.none
                                : BorderSide(
                                    color: Colors.orange.shade300,
                                    width: 1.5,
                                  ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1B5E20),
                              child: Text(
                                m['type'].toString().substring(0, 2),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Text(
                              m['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((m['location'] ?? '').toString().isNotEmpty)
                                  Text(m['location']),
                                if (last != null)
                                  Text(
                                    'Последнее: ${last['value']} ${m['unit']}  (${_formatDate(DateTime.tryParse(last['date'] ?? ''))})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  )
                                else
                                  Text(
                                    'Показаний ещё не было',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openDetail(m),
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

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}
