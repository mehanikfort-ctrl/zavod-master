import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Большой набор эмодзи, сгруппированный по темам.
const Map<String, List<String>> _emojiGroups = {
  '⚙️ Техника': [
    '⚙️',
    '🔧',
    '🔨',
    '🛠️',
    '🔩',
    '🧰',
    '🧲',
    '🪛',
    '🪚',
    '🪓',
    '⛏️',
    '🔗',
    '🧱',
    '⚒️',
    '🛞',
    '🛻',
    '🚧',
    '🏗️',
    '🏭',
    '🗜️',
    '📐',
    '📏',
    '🔬',
    '🔭',
    '🧪',
    '🧫',
    '🧬',
    '🖥️',
    '💻',
    '⌨️',
    '🖱️',
    '🖨️',
    '📱',
    '☎️',
    '📞',
    '📟',
    '📠',
    '📺',
    '📻',
    '📡',
  ],
  '⚡ Электрика': [
    '⚡',
    '🔌',
    '🔋',
    '💡',
    '🔦',
    '🕯️',
    '🪔',
    '💥',
    '💫',
    '✨',
    '🌟',
    '⭐',
    '🌠',
    '☀️',
    '🌤️',
    '🌥️',
    '⚡',
    '🔆',
    '🔅',
    '🌡️',
    '❄️',
    '💨',
    '🌪️',
    '🌊',
    '🛰️',
    '📶',
    '📳',
    '📴',
    '🔇',
    '🔊',
    '📢',
    '📣',
    '🔔',
    '🔕',
    '💤',
    '💥',
    '🔥',
    '💯',
    '🚦',
    '🚥',
  ],
  '💧 Вода': [
    '💧',
    '💦',
    '🌊',
    '🚰',
    '🚿',
    '🛁',
    '🛀',
    '🚽',
    '🧻',
    '🧼',
    '🧴',
    '🧽',
    '🪣',
    '☔',
    '🌧️',
    '⛈️',
    '🌨️',
    '❄️',
    '🌫️',
    '🌁',
    '🐟',
    '🐠',
    '🐡',
    '🦈',
    '🐙',
    '🦑',
    '🐚',
    '🦀',
    '🦞',
    '🦐',
    '🐳',
    '🐋',
    '🚤',
    '⛵',
    '🛶',
    '🚢',
    '⚓',
    '🧭',
    '🗺️',
    '🌊',
  ],
  '🔥 Газ/Огонь': [
    '🔥',
    '💥',
    '🧨',
    '🎇',
    '🎆',
    '🚒',
    '🧯',
    '⛽',
    '🛢️',
    '⛽',
    '🚨',
    '⚠️',
    '☢️',
    '☣️',
    '🆘',
    '🛑',
    '🚫',
    '❌',
    '❗',
    '‼️',
    '🌋',
    '💨',
    '💨',
    '♨️',
    '🍳',
    '🥘',
    '🍲',
    '🍜',
    '🍢',
    '🥩',
  ],
  '🛠️ Инструмент': [
    '🛠️',
    '🔧',
    '🔨',
    '⚒️',
    '⛏️',
    '🪓',
    '🪚',
    '🪛',
    '🧰',
    '🧲',
    '🔗',
    '⛓️',
    '🪝',
    '🗜️',
    '⚙️',
    '🔩',
    '🔑',
    '🗝️',
    '🔐',
    '🔒',
    '🔓',
    '🪤',
    '🧯',
    '🪜',
    '🪑',
    '🛋️',
    '🚪',
    '🪟',
    '🧱',
    '🏗️',
  ],
  '🚚 Транспорт': [
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '🚎',
    '🏎️',
    '🚓',
    '🚑',
    '🚒',
    '🚐',
    '🛻',
    '🚚',
    '🚛',
    '🚜',
    '🏍️',
    '🛵',
    '🚲',
    '🛴',
    '🛹',
    '🛺',
    '🚂',
    '🚆',
    '🚇',
    '🚈',
    '🚉',
    '🚊',
    '🚝',
    '🚞',
    '🚋',
    '🚌',
    '✈️',
    '🛫',
    '🛬',
    '🛩️',
    '🚁',
    '🚀',
    '🛸',
    '⛵',
    '🚤',
    '🚢',
  ],
  '📋 Офис': [
    '📋',
    '📄',
    '📃',
    '📑',
    '📊',
    '📈',
    '📉',
    '🗂️',
    '📁',
    '📂',
    '🗄️',
    '🗃️',
    '📦',
    '📫',
    '📪',
    '📬',
    '📭',
    '📮',
    '📯',
    '📜',
    '📝',
    '✏️',
    '✒️',
    '🖊️',
    '🖋️',
    '🖍️',
    '🖌️',
    '📌',
    '📍',
    '📎',
    '🖇️',
    '🔖',
    '🔗',
    '📅',
    '📆',
    '🗓️',
    '📇',
    '🗒️',
    '🗓️',
    '📔',
    '📕',
    '📗',
    '📘',
    '📙',
    '📚',
    '📖',
    '🔍',
    '🔎',
    '🔏',
    '🔐',
  ],
  '🛡️ Безопасность': [
    '🛡️',
    '⛑️',
    '🦺',
    '🧯',
    '🚨',
    '⚠️',
    '☢️',
    '☣️',
    '🆘',
    '🛑',
    '🚫',
    '❌',
    '❗',
    '‼️',
    '⁉️',
    '❓',
    '❔',
    '💯',
    '🔒',
    '🔓',
    '🔑',
    '🗝️',
    '👁️',
    '👀',
    '🕵️',
    '👮',
    '🚔',
    '🚓',
    '👨‍🚒',
    '👩‍🚒',
    '🔦',
    '🕶️',
    '🥽',
    '🧤',
    '🥼',
    '⛑️',
    '🪖',
    '🎖️',
    '🏅',
    '🏆',
  ],
  '🏭 Производство': [
    '🏭',
    '🏗️',
    '🚧',
    '🏢',
    '🏬',
    '🏪',
    '🏫',
    '🏛️',
    '🏚️',
    '🏠',
    '🏡',
    '🏘️',
    '🏗️',
    '🧱',
    '🪵',
    '🪨',
    '🗿',
    '⛰️',
    '🏔️',
    '🌋',
    '📦',
    '📫',
    '🛒',
    '🛍️',
    '🎁',
    '🎀',
    '🎈',
    '🎉',
    '🎊',
    '🎯',
    '🥇',
    '🥈',
    '🥉',
    '🏅',
    '🎖️',
    '🏆',
    '🏵️',
    '🎗️',
    '👑',
    '💎',
  ],
  '🌡️ Погода': [
    '☀️',
    '🌤️',
    '⛅',
    '🌥️',
    '☁️',
    '🌦️',
    '🌧️',
    '⛈️',
    '🌩️',
    '🌨️',
    '❄️',
    '☃️',
    '⛄',
    '🌬️',
    '💨',
    '🌪️',
    '🌫️',
    '🌈',
    '☔',
    '☂️',
    '🌡️',
    '🔥',
    '💧',
    '💦',
    '🌊',
    '⭐',
    '🌟',
    '✨',
    '🌙',
    '🌛',
  ],
  '🔷 Символы': [
    '✅',
    '☑️',
    '✔️',
    '❌',
    '❎',
    '➕',
    '➖',
    '➗',
    '✖️',
    '🟰',
    '⭕',
    '🔴',
    '🟠',
    '🟡',
    '🟢',
    '🔵',
    '🟣',
    '⚫',
    '⚪',
    '🟤',
    '🔺',
    '🔻',
    '🔸',
    '🔹',
    '🔶',
    '🔷',
    '🔳',
    '🔲',
    '▪️',
    '▫️',
    '⬛',
    '⬜',
    '🟥',
    '🟧',
    '🟨',
    '🟩',
    '🟦',
    '🟪',
    '⬆️',
    '⬇️',
    '⬅️',
    '➡️',
    '↗️',
    '↘️',
    '↙️',
    '↖️',
    '↕️',
    '↔️',
    '🔄',
    '🔃',
    '▶️',
    '⏸️',
    '⏹️',
    '⏺️',
    '⏭️',
    '⏮️',
    '⏩',
    '⏪',
    '🔼',
    '🔽',
  ],
  '🧪 Разное': [
    '📊',
    '📈',
    '📉',
    '🎯',
    '🎲',
    '🎰',
    '🧩',
    '🎨',
    '🖼️',
    '🖌️',
    '🎭',
    '🎪',
    '🎢',
    '🎡',
    '🎠',
    '🎬',
    '📸',
    '📷',
    '📹',
    '🎥',
    '🎤',
    '🎧',
    '🎼',
    '🎵',
    '🎶',
    '🎷',
    '🎸',
    '🎹',
    '🥁',
    '🎺',
    '🍎',
    '🍌',
    '🍇',
    '🍓',
    '🍒',
    '🍑',
    '🍍',
    '🥥',
    '🥝',
    '🍅',
    '🍔',
    '🍕',
    '🌮',
    '🌯',
    '🥪',
    '🍣',
    '🍱',
    '🍜',
    '🍲',
    '🍛',
    '☕',
    '🍵',
    '🥤',
    '🧃',
    '🥛',
    '🍺',
    '🍻',
    '🥂',
    '🍷',
    '🍸',
  ],
};

class TaskCategoriesScreen extends StatefulWidget {
  const TaskCategoriesScreen({super.key});

  @override
  State<TaskCategoriesScreen> createState() => _TaskCategoriesScreenState();
}

class _TaskCategoriesScreenState extends State<TaskCategoriesScreen> {
  List<String> categories = [];
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  static const String _categoriesKey = 'task_categories';
  static const String _tasksKey = 'tasks';

  static const List<String> _defaults = [
    '💧 Вода',
    '⚡ Электрика',
    '🔥 Газ',
    '🏗️ Кран',
    '🔧 Механика',
    '💻 Электроника',
    '📊 Счётчики',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_categoriesKey);
    if (raw != null && raw.isNotEmpty) {
      categories = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } else {
      categories = List<String>.from(_defaults);
      await _save();
    }

    final rawTasks = prefs.getString(_tasksKey);
    if (rawTasks != null && rawTasks.isNotEmpty) {
      tasks = (jsonDecode(rawTasks) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    setState(() => isLoading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, jsonEncode(categories));
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksKey, jsonEncode(tasks));
  }

  int _countTasks(String cat) {
    return tasks.where((t) => t['category'] == cat).length;
  }

  Map<String, String> _splitEmoji(String input) {
    if (input.isEmpty) return {'emoji': '', 'name': ''};
    try {
      final chars = input.characters;
      if (chars.isEmpty) return {'emoji': '', 'name': input};
      final first = chars.first.toString();
      final rune = first.runes.first;
      if (rune >= 0x2000) {
        final rest = input.substring(first.length).trim();
        return {'emoji': first, 'name': rest};
      }
    } catch (_) {}
    return {'emoji': '', 'name': input};
  }

  Future<Map<String, String>?> _showCategoryDialog({
    required String title,
    String? initial,
  }) async {
    final parts = _splitEmoji(initial ?? '');
    String emoji = parts['emoji']!.isEmpty ? '📋' : parts['emoji']!;
    final nameCtrl = TextEditingController(text: parts['name'] ?? '');
    String activeGroup = _emojiGroups.keys.first;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final emojis = _emojiGroups[activeGroup] ?? [];

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Превью
                      Center(
                        child: Container(
                          width: 70,
                          height: 70,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF1B5E20).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '$emoji ${nameCtrl.text}'.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Название (без эмодзи)',
                          hintText: 'Пневматика',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        autofocus: true,
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Выбери иконку',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Вкладки-группы
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _emojiGroups.keys.map((g) {
                            final isSel = activeGroup == g;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  g,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: isSel,
                                onSelected: (_) =>
                                    setDialogState(() => activeGroup = g),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Сетка эмодзи
                      SizedBox(
                        height: 240,
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: emojis.map((e) {
                              final isSel = emoji == e;
                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setDialogState(() => emoji = e),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? const Color(0xFF1B5E20)
                                              .withOpacity(0.15)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSel
                                        ? Border.all(
                                            color: const Color(0xFF1B5E20),
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context, {'emoji': emoji, 'name': name});
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addCategory() async {
    final result = await _showCategoryDialog(title: 'Новая категория');
    if (result == null) return;

    final full = '${result['emoji']} ${result['name']}'.trim();
    if (categories.contains(full)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Такая категория уже есть')),
        );
      }
      return;
    }
    setState(() => categories.add(full));
    await _save();
  }

  Future<void> _renameCategory(int index) async {
    final old = categories[index];
    final result = await _showCategoryDialog(
      title: 'Редактировать категорию',
      initial: old,
    );
    if (result == null) return;

    final full = '${result['emoji']} ${result['name']}'.trim();
    if (full == old) return;

    for (final t in tasks) {
      if (t['category'] == old) {
        t['category'] = full;
      }
    }
    setState(() => categories[index] = full);
    await _save();
    await _saveTasks();
  }

  Future<void> _deleteCategory(int index) async {
    final cat = categories[index];
    final count = _countTasks(cat);

    String msg = 'Удалить категорию «$cat»?';
    if (count > 0) {
      msg +=
          '\n\nУ $count задач эта категория — они останутся с прежней меткой.';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(msg),
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
    if (ok != true) return;

    setState(() => categories.removeAt(index));
    await _save();
  }

  Future<void> _moveUp(int index) async {
    if (index == 0) return;
    setState(() {
      final item = categories.removeAt(index);
      categories.insert(index - 1, item);
    });
    await _save();
  }

  Future<void> _moveDown(int index) async {
    if (index >= categories.length - 1) return;
    setState(() {
      final item = categories.removeAt(index);
      categories.insert(index + 1, item);
    });
    await _save();
  }

  Future<void> _resetToDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить к стандартным?'),
        content: const Text(
          'Текущий список категорий будет заменён стандартным набором.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => categories = List<String>.from(_defaults));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории задач'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Сбросить к стандартным',
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: categories.isEmpty
          ? const Center(
              child: Text(
                'Категорий пока нет.\nНажми «+», чтобы создать.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final cat = categories[i];
                final count = _countTasks(cat);
                final parts = _splitEmoji(cat);
                final emoji = parts['emoji']!;
                final name = parts['name']!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        emoji.isEmpty ? '📋' : emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      name.isEmpty ? cat : name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '$count задач',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 20),
                          tooltip: 'Выше',
                          onPressed: i == 0 ? null : () => _moveUp(i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 20),
                          tooltip: 'Ниже',
                          onPressed: i == categories.length - 1
                              ? null
                              : () => _moveDown(i),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'rename') _renameCategory(i);
                            if (v == 'delete') _deleteCategory(i);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Редактировать'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Удалить',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
