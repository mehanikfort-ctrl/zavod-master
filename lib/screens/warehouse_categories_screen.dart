import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WarehouseCategoriesScreen extends StatefulWidget {
  const WarehouseCategoriesScreen({super.key});

  @override
  State<WarehouseCategoriesScreen> createState() =>
      _WarehouseCategoriesScreenState();
}

class _WarehouseCategoriesScreenState extends State<WarehouseCategoriesScreen> {
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;

  static const String _categoriesKey = 'warehouse_categories';
  static const String _itemsKey = 'warehouse';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final rawCats = prefs.getString(_categoriesKey);
    if (rawCats != null && rawCats.isNotEmpty) {
      categories = (jsonDecode(rawCats) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final c in categories) {
        c.putIfAbsent('subcategories', () => <Map<String, dynamic>>[]);
      }
    } else {
      // Дефолтные категории
      categories = [
        {
          'id': 'cat_mech',
          'name': 'Механика',
          'subcategories': <Map<String, dynamic>>[],
        },
        {
          'id': 'cat_el',
          'name': 'Электрика',
          'subcategories': <Map<String, dynamic>>[],
        },
        {
          'id': 'cat_water',
          'name': 'Сантехника',
          'subcategories': <Map<String, dynamic>>[],
        },
        {
          'id': 'cat_gas',
          'name': 'Газ',
          'subcategories': <Map<String, dynamic>>[],
        },
        {
          'id': 'cat_cons',
          'name': 'Расходники',
          'subcategories': <Map<String, dynamic>>[],
        },
        {
          'id': 'cat_fast',
          'name': 'Крепёж',
          'subcategories': <Map<String, dynamic>>[],
        },
        {
          'id': 'cat_other',
          'name': 'Прочее',
          'subcategories': <Map<String, dynamic>>[],
        },
      ];
      await _saveCategories();
    }

    final rawItems = prefs.getString(_itemsKey);
    if (rawItems != null && rawItems.isNotEmpty) {
      items = (jsonDecode(rawItems) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, jsonEncode(categories));
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_itemsKey, jsonEncode(items));
  }

  int _countInCategory(String catId) {
    return items.where((i) => i['categoryId'] == catId).length;
  }

  int _countInSubcategory(String catId, String subId) {
    return items
        .where((i) => i['categoryId'] == catId && i['subcategoryId'] == subId)
        .length;
  }

  Future<String?> _askName({required String title, String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Название'),
          autofocus: true,
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
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    final name = await _askName(title: 'Новая категория');
    if (name == null) return;
    setState(() {
      categories.add({
        'id': 'cat_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'subcategories': <Map<String, dynamic>>[],
      });
    });
    await _saveCategories();
  }

  Future<void> _renameCategory(int index) async {
    final name = await _askName(
      title: 'Переименовать категорию',
      initial: categories[index]['name']?.toString(),
    );
    if (name == null) return;
    setState(() => categories[index]['name'] = name);
    await _saveCategories();
  }

  Future<void> _deleteCategory(int index) async {
    final catId = categories[index]['id'].toString();
    final count = _countInCategory(catId);

    String msg = 'Удалить категорию «${categories[index]['name']}»?';
    if (count > 0) {
      msg += '\n\nВ ней $count запчастей — они останутся без категории.';
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

    // Отвязываем запчасти
    for (final it in items) {
      if (it['categoryId'] == catId) {
        it.remove('categoryId');
        it.remove('subcategoryId');
      }
    }
    setState(() => categories.removeAt(index));
    await _saveCategories();
    await _saveItems();
  }

  Future<void> _addSubcategory(int catIndex) async {
    final name = await _askName(title: 'Новая подкатегория');
    if (name == null) return;
    setState(() {
      final subs = (categories[catIndex]['subcategories'] as List);
      subs.add({
        'id': 'sub_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
      });
    });
    await _saveCategories();
  }

  Future<void> _renameSubcategory(int catIndex, int subIndex) async {
    final subs = (categories[catIndex]['subcategories'] as List);
    final name = await _askName(
      title: 'Переименовать подкатегорию',
      initial: subs[subIndex]['name']?.toString(),
    );
    if (name == null) return;
    setState(() => subs[subIndex]['name'] = name);
    await _saveCategories();
  }

  Future<void> _deleteSubcategory(int catIndex, int subIndex) async {
    final subs = (categories[catIndex]['subcategories'] as List);
    final catId = categories[catIndex]['id'].toString();
    final subId = subs[subIndex]['id'].toString();
    final count = _countInSubcategory(catId, subId);

    String msg = 'Удалить подкатегорию «${subs[subIndex]['name']}»?';
    if (count > 0) {
      msg +=
          '\n\nВ ней $count запчастей — они останутся в категории, но без подкатегории.';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить подкатегорию?'),
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

    for (final it in items) {
      if (it['subcategoryId'] == subId) {
        it.remove('subcategoryId');
      }
    }
    setState(() => subs.removeAt(subIndex));
    await _saveCategories();
    await _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории склада'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
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
                final subs = (cat['subcategories'] as List)
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
                final count = _countInCategory(cat['id'].toString());

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    leading: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF1B5E20),
                    ),
                    title: Text(
                      cat['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Подкатегорий: ${subs.length}  •  Запчастей: $count',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: PopupMenuButton<String>(
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
                              Text('Переименовать'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
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
                    children: [
                      ...subs.asMap().entries.map((entry) {
                        final si = entry.key;
                        final sub = entry.value;
                        final subCount = _countInSubcategory(
                          cat['id'].toString(),
                          sub['id'].toString(),
                        );
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: 40,
                            right: 8,
                          ),
                          leading: const Icon(
                            Icons.subdirectory_arrow_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                          title: Text(
                            sub['name'] ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '$subCount запчастей',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'rename') {
                                _renameSubcategory(i, si);
                              }
                              if (v == 'delete') {
                                _deleteSubcategory(i, si);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Переименовать'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Удалить',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 40,
                          right: 12,
                          top: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _addSubcategory(i),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Добавить подкатегорию',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
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
