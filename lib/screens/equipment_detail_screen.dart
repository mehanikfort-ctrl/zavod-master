import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../category_style.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> equipment;
  final Future<void> Function() onChanged;
  final Future<void> Function() onDelete;

  const EquipmentDetailScreen({
    super.key,
    required this.equipment,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  late TextEditingController descriptionCtrl;
  late List<Map<String, dynamic>> spareParts;
  late List<Map<String, dynamic>> files;
  List<Map<String, dynamic>> relatedTasks = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> warehouse = [];

  bool _docsExpanded = true;
  bool _historyExpanded = true;
  bool _partsExpanded = true;
  Set<String> _expandedCategories = {}; // Храним ID РАСКРЫТЫХ категорий

  static const String _tasksKey = 'tasks';
  static const String _categoriesKey = 'warehouse_categories';
  static const String _locationsKey = 'equipment_locations';
  static const String _warehouseKey = 'warehouse';

  @override
  void initState() {
    super.initState();
    descriptionCtrl = TextEditingController(
      text: widget.equipment['description'] ?? '',
    );
    spareParts = (widget.equipment['spareParts'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    files = (widget.equipment['files'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _loadRelatedTasks();
    _loadCategories();
    _loadLocations();
    _loadWarehouse();
  }

  Future<void> _loadWarehouse() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_warehouseKey);
    if (raw != null && raw.isNotEmpty) {
      setState(() {
        warehouse = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesKey);
    if (raw != null && raw.isNotEmpty) {
      setState(() {
        categories = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        for (final c in categories) {
          c.putIfAbsent('subcategories', () => <Map<String, dynamic>>[]);
          c.putIfAbsent('icon', () => 'category');
          c.putIfAbsent('color', () => 'green');
        }
      });
    }
  }

  Future<void> _loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_locationsKey);
    if (raw != null && raw.isNotEmpty) {
      setState(() {
        locations = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  Future<void> _loadRelatedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw);
      final allTasks = decoded
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        relatedTasks = allTasks
            .where((t) => t['equipmentId'] == widget.equipment['id'])
            .toList();
      });
    }
  }

  Map<String, dynamic>? _findCategory(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  String? _locationName(String? id) {
    if (id == null) return null;
    final loc = locations.firstWhere((l) => l['id'] == id, orElse: () => {});
    return loc['name'] as String?;
  }

  @override
  void dispose() {
    descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDescription() async {
    widget.equipment['description'] = descriptionCtrl.text.trim();
    await widget.onChanged();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Описание сохранено')));
    }
  }

  Future<void> _changeLocation() async {
    String? selected = widget.equipment['locationId']?.toString();
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Место расположения'),
              content: DropdownButtonFormField<String?>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Выберите место'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Без привязки —'),
                  ),
                  ...locations.map(
                    (l) => DropdownMenuItem<String?>(
                      value: l['id'].toString(),
                      child: Text(l['name'] ?? ''),
                    ),
                  ),
                ],
                onChanged: (v) => setDialogState(() => selected = v),
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
                    setState(() => widget.equipment['locationId'] = selected);
                    await widget.onChanged();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============ ФАЙЛЫ ============

  Future<Directory> _getFilesDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final filesDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}files',
    );
    if (!await filesDir.exists()) await filesDir.create(recursive: true);
    return filesDir;
  }

  Future<String?> _copyFileToApp(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final dir = await _getFilesDir();
      final parts = sourcePath.split(RegExp(r'[\\/]'));
      final originalName = parts.last;
      final fileName = '${DateTime.now().microsecondsSinceEpoch}_$originalName';
      final newPath = '${dir.path}${Platform.pathSeparator}$fileName';
      await src.copy(newPath);
      return newPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteFileFromDisk(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _pickFiles() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Документы',
        extensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'jpg',
          'jpeg',
          'png',
          'txt',
        ],
      );
      final List<XFile> picked = await openFiles(
        acceptedTypeGroups: [typeGroup],
      );
      if (picked.isEmpty) return;

      for (final f in picked) {
        final savedPath = await _copyFileToApp(f.path);
        if (savedPath != null) {
          final parts = savedPath.split(RegExp(r'[\\/]'));
          String originalName = parts.last;
          final underscoreIdx = originalName.indexOf('_');
          if (underscoreIdx > 0)
            originalName = originalName.substring(underscoreIdx + 1);
          files.add({
            'name': originalName,
            'path': savedPath,
            'addedAt': DateTime.now().toIso8601String(),
          });
        }
      }
      widget.equipment['files'] = files;
      await widget.onChanged();
      setState(() {});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка выбора файлов: $e')));
    }
  }

  Future<void> _deleteFile(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text('«${files[index]['name']}» будет удалён.'),
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
    if (confirmed != true) return;

    await _deleteFileFromDisk(files[index]['path'] as String);
    setState(() => files.removeAt(index));
    widget.equipment['files'] = files;
    await widget.onChanged();
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final path = file['path'] as String;
    if (!File(path).existsSync()) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не найден на диске')),
        );
      return;
    }
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx'))
      return Icons.description;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx'))
      return Icons.table_chart;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png'))
      return Icons.image;
    if (lower.endsWith('.txt')) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  Color _fileColor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Colors.red;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Colors.blue;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Colors.green;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png'))
      return Colors.purple;
    return Colors.grey;
  }

  String _fileSize(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes Б';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
    } catch (_) {
      return '';
    }
  }

  // ============ ЗАПЧАСТИ (Умный поиск со склада) ============

  Future<void> _showWarehouseSearchDialog() async {
    String search = '';
    List<Map<String, dynamic>> selectedItems = [];
    final TextEditingController searchCtrl = TextEditingController();

    // Загружаем актуальный склад
    final prefs = await SharedPreferences.getInstance();
    final rawWh = prefs.getString(_warehouseKey);
    if (rawWh != null && rawWh.isNotEmpty) {
      warehouse = (jsonDecode(rawWh) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Фильтруем по поиску, исключая уже добавленные
            final filtered = warehouse.where((w) {
              if ((spareParts).any((sp) => sp['warehouseId'] == w['id']))
                return false;
              if (search.isEmpty) return true;
              final q = search.toLowerCase();
              return (w['name'] ?? '').toString().toLowerCase().contains(q) ||
                  (w['article'] ?? '').toString().toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              title: const Text('Добавить запчасти со склада'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Начните вводить название или артикул...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setDialogState(() => search = v),
                    ),
                    const SizedBox(height: 10),
                    if (selectedItems.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        children: selectedItems
                            .map(
                              (item) => Chip(
                                label: Text(item['name'] ?? ''),
                                onDeleted: () => setDialogState(
                                  () => selectedItems.remove(item),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Ничего не найдено',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final w = filtered[i];
                                final isSelected = selectedItems.any(
                                  (e) => e['id'] == w['id'],
                                );
                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(w['name'] ?? ''),
                                  subtitle: Text(
                                    w['article'] ?? '',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onChanged: (v) {
                                    setDialogState(() {
                                      if (v == true)
                                        selectedItems.add(w);
                                      else
                                        selectedItems.remove(w);
                                    });
                                  },
                                );
                              },
                            ),
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
                    for (final item in selectedItems) {
                      spareParts.add({
                        'warehouseId': item['id'],
                        'name': item['name'],
                        'article': item['article'],
                        'quantity': 1,
                        'categoryId': item['categoryId'],
                      });
                      // Добавляем ID этого оборудования в список привязки запчасти
                      final linked = (item['linkedEquipmentIds'] as List? ?? [])
                          .map((e) => e.toString())
                          .toList();
                      if (!linked.contains(widget.equipment['id'].toString())) {
                        linked.add(widget.equipment['id'].toString());
                        item['linkedEquipmentIds'] = linked;
                      }
                    }
                    // Сохраняем склад
                    await prefs.setString(_warehouseKey, jsonEncode(warehouse));
                    // Сохраняем оборудование
                    setState(() => widget.equipment['spareParts'] = spareParts);
                    await widget.onChanged();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text('Добавить (${selectedItems.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeSpareQuantity(int index, int delta) async {
    setState(() {
      final current = (spareParts[index]['quantity'] as num?)?.toInt() ?? 0;
      spareParts[index]['quantity'] = (current + delta).clamp(0, 9999);
      widget.equipment['spareParts'] = spareParts;
    });
    await widget.onChanged();
  }

  Future<void> _deleteSparePart(int index) async {
    // Отвязываем на складе
    final prefs = await SharedPreferences.getInstance();
    final rawWh = prefs.getString(_warehouseKey);
    if (rawWh != null && rawWh.isNotEmpty) {
      final wh = (jsonDecode(rawWh) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final whId = spareParts[index]['warehouseId'];
      if (whId != null) {
        final idx = wh.indexWhere((w) => w['id'] == whId);
        if (idx >= 0) {
          final linked = (wh[idx]['linkedEquipmentIds'] as List? ?? [])
              .map((e) => e.toString())
              .toList();
          linked.remove(widget.equipment['id'].toString());
          wh[idx]['linkedEquipmentIds'] = linked;
          await prefs.setString(_warehouseKey, jsonEncode(wh));
        }
      }
    }

    setState(() {
      spareParts.removeAt(index);
      widget.equipment['spareParts'] = spareParts;
    });
    await widget.onChanged();
  }

  Future<void> _deleteEquipment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить оборудование?'),
        content: Text('«${widget.equipment['name']}» будет удалено.'),
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
    if (confirmed == true) {
      for (final f in files) {
        await _deleteFileFromDisk(f['path'] as String);
      }
      await widget.onDelete();
      if (mounted) Navigator.pop(context);
    }
  }

  // ============ СЕКЦИИ ============

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? actionButton,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? const Color(0xFF1B5E20);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : color.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              if (actionButton != null && expanded) actionButton,
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionBody({required bool expanded, required Widget child}) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      child: expanded
          ? Padding(padding: const EdgeInsets.only(top: 10), child: child)
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = widget.equipment;
    final locName = _locationName(eq['locationId']?.toString());

    return Scaffold(
      appBar: AppBar(
        title: Text(eq['name'] ?? 'Оборудование'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Удалить',
            onPressed: _deleteEquipment,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _changeLocation,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 20,
                      color: Color(0xFF1B5E20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Место расположения',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locName ?? '— Не указано —',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: locName != null
                                  ? null
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Описание',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Назначение, особенности, дата ввода...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saveDescription,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ДОКУМЕНТЫ
          _sectionHeader(
            icon: Icons.attach_file,
            title: 'Документы',
            count: files.length,
            expanded: _docsExpanded,
            onTap: () => setState(() => _docsExpanded = !_docsExpanded),
            actionButton: TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Добавить'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          _sectionBody(
            expanded: _docsExpanded,
            child: files.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Паспорта, схемы, инструкции — прикрепи сюда.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : Column(
                    children: files.asMap().entries.map((entry) {
                      final i = entry.key;
                      final f = entry.value;
                      final name = f['name']?.toString() ?? '';
                      final path = f['path']?.toString() ?? '';
                      final exists = File(path).existsSync();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _fileColor(name).withOpacity(0.15),
                            child: Icon(
                              _fileIcon(name),
                              color: _fileColor(name),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            exists ? _fileSize(path) : 'Файл не найден',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 20),
                                onPressed: exists ? () => _openFile(f) : null,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteFile(i),
                              ),
                            ],
                          ),
                          onTap: exists ? () => _openFile(f) : null,
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),

          // ИСТОРИЯ РАБОТ
          _sectionHeader(
            icon: Icons.history,
            title: 'История работ',
            count: relatedTasks.length,
            expanded: _historyExpanded,
            onTap: () => setState(() => _historyExpanded = !_historyExpanded),
          ),
          _sectionBody(
            expanded: _historyExpanded,
            child: relatedTasks.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Задач по этому оборудованию пока нет.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : Column(
                    children: relatedTasks
                        .map(
                          (t) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(t['title'] ?? ''),
                              subtitle: Text(
                                '${t['category']}  •  ${t['priority']}  •  ${t['time']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),

          // ЗАПЧАСТИ
          _sectionHeader(
            icon: Icons.settings,
            title: 'Запасные части',
            count: spareParts.length,
            expanded: _partsExpanded,
            onTap: () => setState(() => _partsExpanded = !_partsExpanded),
            actionButton: TextButton.icon(
              onPressed: _showWarehouseSearchDialog,
              icon: const Icon(Icons.inventory_2, size: 16),
              label: const Text('Со склада'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          _sectionBody(
            expanded: _partsExpanded,
            child: spareParts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Запчастей пока нет.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      // 1. Группируем запчасти по категориям
                      final Map<String, List<Map<String, dynamic>>> grouped =
                          {};
                      for (final sp in spareParts) {
                        final catId = sp['categoryId']?.toString() ?? 'none';
                        grouped.putIfAbsent(catId, () => []).add(sp);
                      }

                      // 2. Сортируем категории по алфавиту
                      final sortedCatIds = grouped.keys.toList()
                        ..sort((a, b) {
                          final catA = _findCategory(a);
                          final catB = _findCategory(b);
                          final nameA = (catA?['name'] ?? 'Яяя')
                              .toString()
                              .toLowerCase();
                          final nameB = (catB?['name'] ?? 'Яяя')
                              .toString()
                              .toLowerCase();
                          return nameA.compareTo(nameB);
                        });

                      // 3. Формируем виджеты
                      final List<Widget> widgets = [];
                      for (final catId in sortedCatIds) {
                        final parts = grouped[catId]!;
                        final cat = _findCategory(catId);
                        final catName = cat != null
                            ? cat['name']
                            : 'Без категории';
                        final color = cat != null
                            ? getCategoryColor(cat['color']?.toString())
                            : Colors.grey;
                        final isExpanded = _expandedCategories.contains(catId);

                        // Заголовок (плашка)
                        widgets.add(
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedCategories.remove(catId);
                                } else {
                                  _expandedCategories.add(catId);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    getCategoryIcon(cat?['icon']?.toString()),
                                    size: 16,
                                    color: color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    catName.toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${parts.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 20,
                                    color: color,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                        // Список запчастей (если раскрыто)
                        if (isExpanded) {
                          parts.sort(
                            (a, b) => (a['name'] ?? '')
                                .toString()
                                .toLowerCase()
                                .compareTo(
                                  (b['name'] ?? '').toString().toLowerCase(),
                                ),
                          );

                          for (final sp in parts) {
                            final i = spareParts.indexOf(sp);
                            final qty = (sp['quantity'] as num?)?.toInt() ?? 0;
                            widgets.add(
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: cat != null
                                      ? CircleAvatar(
                                          backgroundColor: color.withOpacity(
                                            0.15,
                                          ),
                                          child: Icon(
                                            getCategoryIcon(
                                              cat['icon']?.toString(),
                                            ),
                                            color: color,
                                            size: 20,
                                          ),
                                        )
                                      : const Icon(Icons.settings),
                                  title: Text(sp['name'] ?? ''),
                                  subtitle: Text(
                                    'Артикул: ${(sp['article'] ?? '').toString().isEmpty ? '—' : sp['article']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 20,
                                        ),
                                        onPressed: qty > 0
                                            ? () => _changeSpareQuantity(i, -1)
                                            : null,
                                      ),
                                      Text(
                                        '$qty',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _changeSpareQuantity(i, 1),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () => _deleteSparePart(i),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      }
                      return Column(children: widgets);
                    },
                  ), // Builder
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
