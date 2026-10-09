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

  // Фильтры
  String searchQuery = '';
  String? priorityFilter;
  String? categoryFilter;
  String? equipmentFilter;
  bool showOnlyCompleted = false; // показать выполненные

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
      // На всякий случай проставим completed=false там, где поля нет
      for (final t in tasks) {
        t.putIfAbsent('completed', () => false);
      }
    } else {
      tasks = [
        {
          'title': 'Заменить прокладку на насосе №3',
          'category': '💧 Вода',
          'priority': '🔴 Срочно',
          'time': 'Сегодня, 10:00',
          'equipmentId': null,
          'completed': false,
        },
        {
          'title': 'Обход трансформаторной подстанции',
          'category': '⚡ Электрика',
          'priority': '🟡 Средний',
          'time': 'Сегодня, 14:00',
          'equipmentId': null,
          'completed': false,
        },
        {
          'title': 'Передать показания счетчиков',
          'category': '📊 Счётчики',
          'priority': '🟢 Плановое',
          'time': '25 число, 08:00',
          'equipmentId': null,
          'completed': false,
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

  int get _activeFiltersCount {
    int count = 0;
    if (priorityFilter != null) count++;
    if (categoryFilter != null) count++;
    if (equipmentFilter != null) count++;
    return count;
  }

  List<Map<String, dynamic>> get _filteredTasks {
    return tasks.where((t) {
      final completed = t['completed'] == true;
      if (showOnlyCompleted != completed) return false;

      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final title = (t['title'] ?? '').toString().toLowerCase();
        if (!title.contains(q)) return false;
      }
      if (priorityFilter != null && t['priority'] != priorityFilter) {
        return false;
      }
      if (categoryFilter != null && t['category'] != categoryFilter) {
        return false;
      }
      if (equipmentFilter != null) {
        if (equipmentFilter == '_none_') {
          if (t['equipmentId'] != null) return false;
        } else {
          if (t['equipmentId'] != equipmentFilter) return false;
        }
      }
      return true;
    }).toList();
  }

  int get _activeCount => tasks.where((t) => t['completed'] != true).length;
  int get _doneCount => tasks.where((t) => t['completed'] == true).length;

  void _resetFilters() {
    setState(() {
      searchQuery = '';
      priorityFilter = null;
      categoryFilter = null;
      equipmentFilter = null;
    });
  }

  Future<void> _openExtraFilters() async {
    String? tempCategory = categoryFilter;
    String? tempEquipment = equipmentFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Дополнительные фильтры',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Категория',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Все'),
                        selected: tempCategory == null,
                        onSelected: (_) =>
                            setSheetState(() => tempCategory = null),
                      ),
                      ...categories.map((c) {
                        return ChoiceChip(
                          label: Text(c),
                          selected: tempCategory == c,
                          onSelected: (_) =>
                              setSheetState(() => tempCategory = c),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (equipmentList.isNotEmpty) ...[
                    const Text(
                      'Оборудование',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Все'),
                          selected: tempEquipment == null,
                          onSelected: (_) =>
                              setSheetState(() => tempEquipment = null),
                        ),
                        ChoiceChip(
                          label: const Text('Без привязки'),
                          selected: tempEquipment == '_none_',
                          onSelected: (_) =>
                              setSheetState(() => tempEquipment = '_none_'),
                        ),
                        ...equipmentList.map((e) {
                          return ChoiceChip(
                            label: Text(
                              e['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: tempEquipment == e['id'],
                            onSelected: (_) =>
                                setSheetState(() => tempEquipment = e['id']),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              tempCategory = null;
                              tempEquipment = null;
                            });
                          },
                          child: const Text('Сбросить'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              categoryFilter = tempCategory;
                              equipmentFilter = tempEquipment;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Применить'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Диалог создания/редактирования задачи
  Future<void> _showTaskDialog({int? editIndex}) async {
    final bool isEdit = editIndex != null;
    final existing = isEdit ? tasks[editIndex] : null;

    final TextEditingController titleController = TextEditingController(
      text: existing?['title'] ?? '',
    );
    String selectedCategory = existing?['category'] ?? '🔧 Механика';
    String selectedPriority = existing?['priority'] ?? '🟡 Средний';
    String? selectedEquipmentId = existing?['equipmentId'];
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    // Для редактирования попробуем распарсить дату из существующего текста
    // (простой разбор: если в time есть ДД.ММ.ГГГГ — извлекаем)
    if (isEdit && existing?['time'] != null) {
      final timeStr = existing!['time'].toString();
      final match = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(timeStr);
      if (match != null) {
        selectedDate = DateTime(
          int.parse(match.group(3)!),
          int.parse(match.group(2)!),
          int.parse(match.group(1)!),
        );
      }
      final timeMatch = RegExp(r'(\d{2}):(\d{2})').firstMatch(timeStr);
      if (timeMatch != null) {
        selectedTime = TimeOfDay(
          hour: int.parse(timeMatch.group(1)!),
          minute: int.parse(timeMatch.group(2)!),
        );
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            String formatDate(DateTime d) =>
                '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
            String formatTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: Text(isEdit ? 'Редактировать задачу' : 'Новая задача'),
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
                      onChanged: (v) =>
                          setStateDialog(() => selectedEquipmentId = v),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
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
                      if (isEdit) {
                        tasks[editIndex]['title'] = titleController.text.trim();
                        tasks[editIndex]['category'] = selectedCategory;
                        tasks[editIndex]['priority'] = selectedPriority;
                        tasks[editIndex]['time'] = timeLabel;
                        tasks[editIndex]['equipmentId'] = selectedEquipmentId;
                      } else {
                        tasks.add({
                          'title': titleController.text.trim(),
                          'category': selectedCategory,
                          'priority': selectedPriority,
                          'time': timeLabel,
                          'equipmentId': selectedEquipmentId,
                          'completed': false,
                        });
                      }
                    });
                    await _saveTasks();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(isEdit ? 'Сохранить' : 'Добавить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleCompleted(int index) async {
    setState(() {
      tasks[index]['completed'] = !(tasks[index]['completed'] == true);
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(int index) async {
    final realIndex = tasks.indexOf(_filteredTasks[index]);
    if (realIndex >= 0) {
      setState(() => tasks.removeAt(realIndex));
      await _saveTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filteredTasks;

    return Scaffold(
      body: Column(
        children: [
          // Переключатель: Активные / Выполненные
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text('Активные ($_activeCount)'),
                        icon: const Icon(Icons.pending_actions, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Готово ($_doneCount)'),
                        icon: const Icon(Icons.check_circle, size: 16),
                      ),
                    ],
                    selected: {showOnlyCompleted},
                    onSelectionChanged: (s) =>
                        setState(() => showOnlyCompleted = s.first),
                    style: ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ),
          ),

          // Поиск + кнопка "Ещё"
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Поиск по названию',
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
                Stack(
                  children: [
                    IconButton.filled(
                      onPressed: _openExtraFilters,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.tune),
                    ),
                    if (_activeFiltersCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_activeFiltersCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Чипы приоритета
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: const Text('Все'),
                  selected: priorityFilter == null,
                  onSelected: (_) => setState(() => priorityFilter = null),
                ),
                const SizedBox(width: 8),
                ...priorities.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p),
                      selected: priorityFilter == p,
                      onSelected: (_) => setState(() => priorityFilter = p),
                    ),
                  );
                }),
                if (_activeFiltersCount > 0 || searchQuery.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.close, size: 16),
                    label: const Text('Сбросить'),
                    onPressed: _resetFilters,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          if (filtered.length !=
              (showOnlyCompleted ? _doneCount : _activeCount))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Найдено: ${filtered.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),

          const SizedBox(height: 4),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      showOnlyCompleted
                          ? 'Выполненных задач пока нет.\nОтмечай их галочкой!'
                          : 'Активных задач нет.\nНажми «+», чтобы добавить.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final task = filtered[index];
                      final eqName = _equipmentName(task['equipmentId']);
                      final realIndex = tasks.indexOf(task);
                      final isDone = task['completed'] == true;

                      return Dismissible(
                        key: ValueKey(
                          '${task['title']}_${task['time']}_$index',
                        ),
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
                          elevation: isDone ? 0 : 2,
                          color: isDone ? Colors.grey.shade100 : null,
                          child: ListTile(
                            leading: IconButton(
                              icon: Icon(
                                isDone
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isDone
                                    ? const Color(0xFF1B5E20)
                                    : Colors.grey,
                              ),
                              onPressed: () => _toggleCompleted(realIndex),
                            ),
                            title: Text(
                              task['title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDone ? Colors.grey : null,
                              ),
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
                                  Text(
                                    '${task['category']}  •  ${task['priority']}',
                                  ),
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
                            onTap: () => _showTaskDialog(editIndex: realIndex),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
