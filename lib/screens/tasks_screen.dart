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
  bool isLoading = true;

  static const String _storageKey = 'tasks';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw);
      tasks = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      tasks = [
        {
          'title': 'Заменить прокладку на насосе №3',
          'category': '💧 Вода',
          'priority': '🔴 Срочно',
          'time': 'Сегодня, 10:00',
        },
        {
          'title': 'Обход трансформаторной подстанции',
          'category': '⚡ Электрика',
          'priority': '🟡 Средний',
          'time': 'Сегодня, 14:00',
        },
        {
          'title': 'Передать показания счетчиков',
          'category': '📊 Счётчики',
          'priority': '🟢 Плановое',
          'time': '25 число, 08:00',
        },
      ];
      await _saveTasks();
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(tasks));
  }

  void _addTask() {
    final TextEditingController titleController = TextEditingController();
    String selectedCategory = '🔧 Механика';
    String selectedPriority = '🟡 Средний';
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

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
            String formatDate(DateTime date) {
              return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
            }

            String formatTime(TimeOfDay time) {
              return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            }

            return AlertDialog(
              title: const Text('Новая задача'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: 'Например: Заменить лампу в цехе №2',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items: categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() => selectedCategory = value!);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: const InputDecoration(labelText: 'Приоритет'),
                      items: priorities.map((pr) {
                        return DropdownMenuItem(value: pr, child: Text(pr));
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() => selectedPriority = value!);
                      },
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
                    if (titleController.text.trim().isNotEmpty) {
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
                        });
                      });
                      await _saveTasks();
                      if (context.mounted) Navigator.pop(context);
                    }
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
    setState(() {
      tasks.removeAt(index);
    });
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'Задач пока нет.\nНажми «+», чтобы добавить.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
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
                child: Text('${task['category']}  •  ${task['priority']}'),
              ),
              trailing: Text(
                task['time'],
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }
}
