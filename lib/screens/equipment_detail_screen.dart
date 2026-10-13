import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

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

  // Состояния сворачивания секций
  bool _docsExpanded = true;
  bool _historyExpanded = true;
  bool _partsExpanded = true;

  static const String _tasksKey = 'tasks';

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

  // ============ ФАЙЛЫ ============

  Future<Directory> _getFilesDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final filesDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}files',
    );
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }
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
      if (await f.exists()) {
        await f.delete();
      }
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
          if (underscoreIdx > 0) {
            originalName = originalName.substring(underscoreIdx + 1);
          }
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка выбора файлов: $e')));
      }
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

    final path = files[index]['path'] as String;
    await _deleteFileFromDisk(path);
    setState(() => files.removeAt(index));
    widget.equipment['files'] = files;
    await widget.onChanged();
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final path = file['path'] as String;
    if (!File(path).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не найден на диске')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return Icons.image;
    }
    if (lower.endsWith('.txt')) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  Color _fileColor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Colors.red;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Colors.blue;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Colors.green;
    }
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return Colors.purple;
    }
    return Colors.grey;
  }

  String _fileSize(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes Б';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} КБ';
      }
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
    } catch (_) {
      return '';
    }
  }

  // ============ ЗАПЧАСТИ ============

  Future<void> _addSparePart() async {
    final nameCtrl = TextEditingController();
    final articleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новая запчасть'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Подшипник 6205',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: articleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Артикул',
                  hintText: 'PB-6205',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Количество'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                spareParts.add({
                  'name': nameCtrl.text.trim(),
                  'article': articleCtrl.text.trim(),
                  'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 1,
                });
                widget.equipment['spareParts'] = spareParts;
                await widget.onChanged();
                if (context.mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSparePart(int index) async {
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

  // ============ СВОРАЧИВАЕМЫЙ ЗАГОЛОВОК ============

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
      child: Column(
        children: [
          InkWell(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
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
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(),
            ),
        ],
      ),
    );
  }

  // Обёртка содержимого секции (появляется, если expanded)
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Категория', eq['category'] ?? '—'),
                  const SizedBox(height: 6),
                  _infoRow(
                    'Расположение',
                    (eq['location'] ?? '').toString().isEmpty
                        ? '—'
                        : eq['location'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ===== ОПИСАНИЕ =====
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

          // ===== ДОКУМЕНТЫ =====
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
                                tooltip: 'Открыть',
                                onPressed: exists ? () => _openFile(f) : null,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                tooltip: 'Удалить',
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

          // ===== ИСТОРИЯ РАБОТ =====
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
                    children: relatedTasks.map((t) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(t['title'] ?? ''),
                          subtitle: Text(
                            '${t['category']}  •  ${t['priority']}  •  ${t['time']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),

          // ===== ЗАПЧАСТИ =====
          _sectionHeader(
            icon: Icons.settings,
            title: 'Запасные части',
            count: spareParts.length,
            expanded: _partsExpanded,
            onTap: () => setState(() => _partsExpanded = !_partsExpanded),
            actionButton: TextButton.icon(
              onPressed: _addSparePart,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Добавить'),
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
                : Column(
                    children: spareParts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final sp = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.settings),
                          title: Text(sp['name'] ?? ''),
                          subtitle: Text(
                            'Артикул: ${(sp['article'] ?? '').toString().isEmpty ? '—' : sp['article']}  •  Кол-во: ${sp['quantity']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _deleteSparePart(i),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
