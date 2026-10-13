import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

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

  String searchQuery = '';
  String? priorityFilter;
  String? categoryFilter;
  String? equipmentFilter;

  // 0 = Активные, 1 = Готово, 2 = Архив
  int _viewMode = 0;

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
      for (final t in tasks) {
        t.putIfAbsent('completed', () => false);
        t.putIfAbsent('archived', () => false);
        t.putIfAbsent('comments', () => <Map<String, dynamic>>[]);
        t.putIfAbsent('photos', () => <String>[]);
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
          'archived': false,
          'comments': <Map<String, dynamic>>[],
          'photos': <String>[],
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

  Future<Directory> _getPhotosDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final photosDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}photos',
    );
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  Future<String?> _copyPhotoToApp(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final dir = await _getPhotosDir();
      final parts = sourcePath.split('.');
      final ext = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
      final fileName =
          '${DateTime.now().microsecondsSinceEpoch}_${sourcePath.hashCode}.$ext';
      final newPath = '${dir.path}${Platform.pathSeparator}$fileName';
      await src.copy(newPath);
      return newPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deletePhotoFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  void _openPhoto(String path) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: File(path).existsSync()
                      ? Image.file(File(path), fit: BoxFit.contain)
                      : const Center(
                          child: Text(
                            'Файл не найден',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      final archived = t['archived'] == true;
      final completed = t['completed'] == true;

      if (_viewMode == 2) {
        // Архив: только archived
        if (!archived) return false;
      } else if (_viewMode == 1) {
        // Готово: completed и НЕ archived
        if (!completed || archived) return false;
      } else {
        // Активные: НЕ completed и НЕ archived
        if (completed || archived) return false;
      }

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

  int get _activeCount => tasks
      .where((t) => t['completed'] != true && t['archived'] != true)
      .length;
  int get _doneCount => tasks
      .where((t) => t['completed'] == true && t['archived'] != true)
      .length;
  int get _archivedCount => tasks.where((t) => t['archived'] == true).length;

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
                  const Text('Категория', style: TextStyle(color: Colors.grey)),
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
                  if (equipmentList.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Оборудование',
                      style: TextStyle(color: Colors.grey),
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
                  ],
                  const SizedBox(height: 20),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTaskDialog({int? editIndex}) async {
    final bool isEdit = editIndex != null;
    final existing = isEdit ? tasks[editIndex] : null;

    final TextEditingController titleController = TextEditingController(
      text: existing?['title'] ?? '',
    );
    final TextEditingController commentController = TextEditingController();

    String selectedCategory = existing?['category'] ?? '🔧 Механика';
    String selectedPriority = existing?['priority'] ?? '🟡 Средний';
    String? selectedEquipmentId = existing?['equipmentId'];
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    List<Map<String, dynamic>> comments = isEdit
        ? ((existing?['comments'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : [];

    List<String> photos = isEdit
        ? ((existing?['photos'] as List?) ?? [])
              .map((e) => e.toString())
              .toList()
        : [];

    final List<String> newlyAddedPhotos = [];

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
            String formatDateTime(DateTime d) =>
                '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

            Future<void> addComment() async {
              final text = commentController.text.trim();
              if (text.isEmpty) return;
              setStateDialog(() {
                comments.add({
                  'text': text,
                  'author': 'Механик',
                  'createdAt': DateTime.now().toIso8601String(),
                });
                commentController.clear();
              });
            }

            Future<void> pickPhotos() async {
              try {
                const typeGroup = XTypeGroup(
                  label: 'Изображения',
                  extensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
                );
                final List<XFile> files = await openFiles(
                  acceptedTypeGroups: [typeGroup],
                );
                if (files.isEmpty) return;

                for (final f in files) {
                  final savedPath = await _copyPhotoToApp(f.path);
                  if (savedPath != null) {
                    newlyAddedPhotos.add(savedPath);
                    photos.add(savedPath);
                  }
                }
                setStateDialog(() {});
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка выбора фото: $e')),
                  );
                }
              }
            }

            Future<void> removePhoto(int index) async {
              final path = photos[index];
              setStateDialog(() => photos.removeAt(index));
              newlyAddedPhotos.remove(path);
              await _deletePhotoFile(path);
            }

            final isArchived = isEdit && existing?['archived'] == true;

            return AlertDialog(
              title: Text(isEdit ? 'Задача' : 'Новая задача'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Название',
                          hintText: 'Например: Заменить лампу',
                        ),
                        autofocus: !isEdit,
                      ),
                      const SizedBox(height: 12),
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
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Приоритет',
                        ),
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

                      // Кнопка "В архив" / "Вернуть из архива"
                      if (isEdit) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              setState(() {
                                tasks[editIndex]['archived'] =
                                    !(tasks[editIndex]['archived'] == true);
                              });
                              await _saveTasks();
                              if (context.mounted) Navigator.pop(context);
                              setState(() {});
                            },
                            icon: Icon(
                              isArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              size: 18,
                            ),
                            label: Text(
                              isArchived
                                  ? 'Вернуть из архива'
                                  : 'Отправить в архив',
                            ),
                          ),
                        ),
                      ],

                      // ====== ФОТО ======
                      if (isEdit) ...[
                        const Divider(height: 32),
                        Row(
                          children: [
                            const Icon(
                              Icons.photo_camera,
                              size: 20,
                              color: Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Фотографии',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (photos.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${photos.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: pickPhotos,
                              icon: const Icon(Icons.add_a_photo, size: 16),
                              label: const Text('Добавить'),
                            ),
                          ],
                        ),
                        if (photos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final path = photos[i];
                                final exists = File(path).existsSync();
                                return Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _openPhoto(path),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 90,
                                          height: 90,
                                          color: Colors.grey.shade200,
                                          child: exists
                                              ? Image.file(
                                                  File(path),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: InkWell(
                                        onTap: () => removePhoto(i),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ],

                      // ====== КОММЕНТАРИИ ======
                      if (isEdit) ...[
                        const Divider(height: 32),
                        Row(
                          children: [
                            const Icon(
                              Icons.comment,
                              size: 20,
                              color: Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Комментарии',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (comments.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${comments.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Комментариев пока нет.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ...comments.asMap().entries.map((entry) {
                            final i = entry.key;
                            final c = entry.value;
                            final dt = DateTime.tryParse(
                              (c['createdAt'] ?? '').toString(),
                            );
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        c['author'] ?? 'Механик',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (dt != null)
                                        Text(
                                          formatDateTime(dt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      const Spacer(),
                                      InkWell(
                                        onTap: () {
                                          setStateDialog(() {
                                            comments.removeAt(i);
                                          });
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c['text'] ?? ''),
                                ],
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                decoration: InputDecoration(
                                  hintText: 'Написать комментарий...',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                maxLines: 2,
                                minLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: addComment,
                              icon: const Icon(Icons.send, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    for (final p in newlyAddedPhotos) {
                      await _deletePhotoFile(p);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;

                    final toDelete = newlyAddedPhotos
                        .where((p) => !photos.contains(p))
                        .toList();
                    for (final p in toDelete) {
                      await _deletePhotoFile(p);
                    }

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
                        tasks[editIndex]['comments'] = comments;
                        tasks[editIndex]['photos'] = photos;
                      } else {
                        tasks.add({
                          'title': titleController.text.trim(),
                          'category': selectedCategory,
                          'priority': selectedPriority,
                          'time': timeLabel,
                          'equipmentId': selectedEquipmentId,
                          'completed': false,
                          'archived': false,
                          'comments': <Map<String, dynamic>>[],
                          'photos': <String>[],
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

  Future<void> _archiveTask(int index) async {
    setState(() {
      tasks[index]['archived'] = true;
      tasks[index]['completed'] = true;
    });
    await _saveTasks();
  }

  Future<void> _unarchiveTask(int index) async {
    setState(() {
      tasks[index]['archived'] = false;
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(int index) async {
    final realIndex = tasks.indexOf(_filteredTasks[index]);
    if (realIndex < 0) return;

    final task = tasks[realIndex];
    final photosList = (task['photos'] as List?) ?? [];
    for (final p in photosList) {
      await _deletePhotoFile(p.toString());
    }

    setState(() => tasks.removeAt(realIndex));
    await _saveTasks();
  }

  Future<void> _confirmArchive(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отправить в архив?'),
        content: const Text(
          'Задача переместится в архив. Её можно будет вернуть оттуда.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('В архив'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _archiveTask(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filteredTasks;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Переключатель: Активные / Готово / Архив
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: Text(
                          'Активные ($_activeCount)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text(
                          'Готово ($_doneCount)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text(
                          'Архив ($_archivedCount)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (s) =>
                        setState(() => _viewMode = s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStatePropertyAll(
                        const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Поиск + фильтры
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

          // Чипы приоритетов
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

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _viewMode == 2
                          ? 'Архив пуст.\nСюда попадают выполненные задачи старше 30 дней.'
                          : _viewMode == 1
                          ? 'Выполненных задач пока нет.'
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
                      final isArchived = task['archived'] == true;
                      final commentCount =
                          (task['comments'] as List?)?.length ?? 0;
                      final photoCount = (task['photos'] as List?)?.length ?? 0;

                      return Dismissible(
                        key: ValueKey(
                          '${task['title']}_${task['time']}_$index',
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          if (isArchived) {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Удалить навсегда?'),
                                content: Text(
                                  '«${task['title']}» будет удалена окончательно.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Отмена'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Удалить'),
                                  ),
                                ],
                              ),
                            );
                            return ok == true;
                          }
                          return true;
                        },
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
                          color: isDark
                              ? (isDone ? Colors.grey.shade900 : null)
                              : (isDone ? Colors.grey.shade100 : null),
                          child: ListTile(
                            leading: IconButton(
                              icon: Icon(
                                isArchived
                                    ? Icons.archive
                                    : (isDone
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked),
                                color: isArchived
                                    ? Colors.grey
                                    : (isDone
                                          ? const Color(0xFF1B5E20)
                                          : Colors.grey),
                              ),
                              onPressed: isArchived
                                  ? () => _unarchiveTask(realIndex)
                                  : () => _toggleCompleted(realIndex),
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${task['category']}  •  ${task['priority']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (commentCount > 0) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.comment,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$commentCount',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                      if (photoCount > 0) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.photo_camera,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$photoCount',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'archive') {
                                  _confirmArchive(realIndex);
                                } else if (value == 'unarchive') {
                                  _unarchiveTask(realIndex);
                                } else if (value == 'edit') {
                                  _showTaskDialog(editIndex: realIndex);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Редактировать'),
                                    ],
                                  ),
                                ),
                                if (!isArchived)
                                  PopupMenuItem(
                                    value: 'archive',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.archive_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('В архив'),
                                      ],
                                    ),
                                  ),
                                if (isArchived)
                                  PopupMenuItem(
                                    value: 'unarchive',
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.unarchive_outlined,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Вернуть из архива'),
                                      ],
                                    ),
                                  ),
                              ],
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
      floatingActionButton: _viewMode == 2
          ? null
          : FloatingActionButton(
              onPressed: () => _showTaskDialog(),
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
    );
  }
}
