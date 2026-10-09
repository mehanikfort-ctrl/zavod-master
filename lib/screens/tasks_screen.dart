import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> equipmentList = [];
  bool isLoading = true;
  static const String _storageKey = 'tasks';
  static const String _equipmentKey = 'equipment';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    final String? rawTasks = prefs.getString(_storageKey);
    if (rawTasks != null && rawTasks.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(rawTasks);
      tasks = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      tasks = [
        {
          'title': 'Заменить прокладку на насосе №3',
          'category': '💧 Вода',
          'priority': '🔴 Срочно',
          'time': 'Сегодня, 10:00',
          'equipmentId': null,
        },
        {
          'title': 'Обход трансформаторной подстанции',
          'category': '⚡ Электрика',
          'priority': '🟡 Средний',
          'time': 'Сегодня, 14:00',
          'equipmentId': null,
        },
        {
          'title': 'Передать показания счетчиков',
          'category': '📊 Счётчики',
          'priority': '🟢 Плановое',
          'time': '25 число, 08:00',
          'equipmentId': null,
        },
      ];
      await _saveTasks();
    }

    final String? rawEq = prefs.getString(_equipmentKey);
    if (rawEq != null && rawEq.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(rawEq);
      equipmentList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(tasks));
  }

  String? _equipmentName(String? id) {
    if (id == null) return null;
    final eq = equipmentList.firstWhere((e) => e['id'] == id, orElse: () => {});
    return eq['name'] as String?;
  }

  void _addTask() {
    final TextEditingController titleController = TextEditingController();
    String selectedCategory = '🔧 Механика';
    String selectedPriority = '🟡 Средний';
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String? selectedEquipmentId;

    final List<String> categories = [
      '💧 Вода',
      '⚡ Электрика',
      '🔥 Газ',
      '🏗️ Кран',
      '🔧 Механика',
      '💻 Электроника',
      '📊 Счётчики',
    ];

    final List<String> priorities = ['🔴 Срочно', '🟡 Средний', '🟢 Плановое'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            String formatDate(DateTime d) =>
                '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
            String formatTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text('Новая задача'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: 'Например: Заменить лампу',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: selectedEquipmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Оборудование',
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
                      onChanged: (v) {
                        setStateDialog(() => selectedEquipmentId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedCategory = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: const InputDecoration(labelText: 'Приоритет'),
                      items: priorities
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedPriority = v!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setStateDialog(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              selectedDate == null
                                  ? 'Дата'
                                  : formatDate(selectedDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setStateDialog(() => selectedTime = picked);
                              }
                            },
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              selectedTime == null
                                  ? 'Время'
                                  : formatTime(selectedTime!),
                            ),
                          ),
                        ),
                      ],
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
                    if (titleController.text.trim().isEmpty) return;

                    String timeLabel = 'Сегодня';
                    if (selectedDate != null) {
                      timeLabel = formatDate(selectedDate!);
                      if (selectedTime != null) {
                        timeLabel += ', ${formatTime(selectedTime!)}';
                      }
                    } else if (selectedTime != null) {
                      timeLabel = 'Сегодня, ${formatTime(selectedTime!)}';
                    }

                    setState(() {
                      tasks.add({
                        'title': titleController.text.trim(),
                        'category': selectedCategory,
                        'priority': selectedPriority,
                        'time': timeLabel,
                        'equipmentId': selectedEquipmentId,
                      });
                    });
                    await _saveTasks();
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

  Future<void> _deleteTask(int index) async {
    setState(() => tasks.removeAt(index));
    await _saveTasks();
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: tasks.isEmpty
          ? const Center(
              child: Text(
                'Задач пока нет.\nНажми «+», чтобы добавить.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final eqName = _equipmentName(task['equipmentId']);

                return Dismissible(
                  key: ValueKey('${task['title']}_$index'),
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
                  onDismissed: (_) => _deleteTask(index),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        task['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eqName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.build,
                                      size: 14,
                                      color: Color(0xFF1B5E20),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        eqName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1B5E20),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text('${task['category']}  •  ${task['priority']}'),
                          ],
                        ),
                      ),
                      trailing: Text(
                        task['time'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
