import '../pdf_service.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'warehouse_categories_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortMode = 'name';
  String? categoryFilter; // categoryId
  String? subcategoryFilter; // subcategoryId

  static const String _itemsKey = 'warehouse';
  static const String _categoriesKey = 'warehouse_categories';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Категории
    final rawCats = prefs.getString(_categoriesKey);
    if (rawCats != null && rawCats.isNotEmpty) {
      categories = (jsonDecode(rawCats) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final c in categories) {
        c.putIfAbsent('subcategories', () => <Map<String, dynamic>>[]);
      }
    } else {
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
      await prefs.setString(_categoriesKey, jsonEncode(categories));
    }

    // Запчасти + миграция старых
    final rawItems = prefs.getString(_itemsKey);
    if (rawItems != null && rawItems.isNotEmpty) {
      items = (jsonDecode(rawItems) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      bool migrated = false;
      for (final item in items) {
        // Если уже есть categoryId — пропускаем
        if (item['categoryId'] != null) continue;

        // Старое поле 'category' (строка вида "🔧 Механика") → ищем категорию по имени
        final oldName = item['category']?.toString();
        if (oldName != null && oldName.isNotEmpty) {
          final cleanName = oldName
              .replaceAll(RegExp(r'[^\wА-Яа-яёЁ]'), '')
              .trim();
          final found = categories.firstWhere((c) {
            final cn = c['name']
                .toString()
                .replaceAll(RegExp(r'[^\wА-Яа-яёЁ]'), '')
                .trim();
            return cn.toLowerCase() == cleanName.toLowerCase();
          }, orElse: () => <String, dynamic>{});
          if (found.isNotEmpty) {
            item['categoryId'] = found['id'];
          }
        }

        // Если всё ещё нет — в «Прочее»
        if (item['categoryId'] == null) {
          final other = categories.firstWhere(
            (c) => c['name'] == 'Прочее' || c['id'] == 'cat_other',
            orElse: () =>
                categories.isNotEmpty ? categories.first : <String, dynamic>{},
          );
          if (other.isNotEmpty) {
            item['categoryId'] = other['id'];
          }
        }
        item.remove('category'); // старое поле больше не нужно
        migrated = true;
      }
      if (migrated) await _saveItems();
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_itemsKey, jsonEncode(items));
  }

  Future<void> _reloadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCats = prefs.getString(_categoriesKey);
    if (rawCats != null && rawCats.isNotEmpty) {
      setState(() {
        categories = (jsonDecode(rawCats) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        for (final c in categories) {
          c.putIfAbsent('subcategories', () => <Map<String, dynamic>>[]);
        }
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

  Map<String, dynamic>? _findSubcategory(String? catId, String? subId) {
    if (catId == null || subId == null) return null;
    final cat = _findCategory(catId);
    if (cat == null) return null;
    for (final s in (cat['subcategories'] as List)) {
      if (s['id'] == subId) return Map<String, dynamic>.from(s);
    }
    return null;
  }

  bool _isLow(Map<String, dynamic> item) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final min = (item['minQuantity'] as num?)?.toInt() ?? 0;
    return min > 0 && qty <= min;
  }

  bool _isOut(Map<String, dynamic> item) {
    return ((item['quantity'] as num?)?.toInt() ?? 0) <= 0;
  }

  int get _lowCount => items.where((e) => _isLow(e) || _isOut(e)).length;

  List<Map<String, dynamic>> get _filtered {
    var list = items.where((item) {
      if (categoryFilter != null && item['categoryId'] != categoryFilter) {
        return false;
      }
      if (subcategoryFilter != null &&
          item['subcategoryId'] != subcategoryFilter) {
        return false;
      }
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return (item['name'] ?? '').toString().toLowerCase().contains(q) ||
          (item['article'] ?? '').toString().toLowerCase().contains(q) ||
          (item['location'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    if (sortMode == 'name') {
      list.sort(
        (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
          (b['name'] ?? '').toString().toLowerCase(),
        ),
      );
    } else if (sortMode == 'quantity') {
      list.sort(
        (a, b) => ((b['quantity'] as num?) ?? 0).compareTo(
          (a['quantity'] as num?) ?? 0,
        ),
      );
    } else if (sortMode == 'low') {
      list.sort((a, b) {
        final aLow = _isOut(a) || _isLow(a);
        final bLow = _isOut(b) || _isLow(b);
        if (aLow == bLow) return 0;
        return aLow ? -1 : 1;
      });
    }
    return list;
  }
  // ============ ЗАЯВКА НА ЗАКУПКУ ============

  Future<void> _openPurchaseRequest() async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Склад пуст — нечего заказывать')),
      );
      return;
    }

    // Порядок: сначала дефицитные, потом остальные
    final sorted = items.toList()
      ..sort((a, b) {
        final aLow = _isOut(a) || _isLow(a);
        final bLow = _isOut(b) || _isLow(b);
        if (aLow == bLow) {
          return (a['name'] ?? '').toString().toLowerCase().compareTo(
            (b['name'] ?? '').toString().toLowerCase(),
          );
        }
        return aLow ? -1 : 1;
      });

    // Храним выбранные: id → orderQuantity
    final Map<String, int> selected = {};
    final Map<String, TextEditingController> qtyCtrls = {};

    for (final it in sorted) {
      final id = it['id'].toString();
      final qty = (it['quantity'] as num?)?.toInt() ?? 0;
      final min = (it['minQuantity'] as num?)?.toInt() ?? 0;
      final isOut = qty <= 0;
      final isLow = !isOut && min > 0 && qty <= min;

      // По умолчанию: дефицитные отмечаем
      // По умолчанию: дефицитные отмечаем
      // Целевой остаток = 2 × минимум. Заказ = (2 × минимум) − текущий остаток.
      if (isOut || isLow) {
        final target = min > 0 ? min * 2 : 2;
        final need = target - qty;
        selected[id] = need > 0 ? need : 1;
      }
      qtyCtrls[id] = TextEditingController(
        text: selected[id]?.toString() ?? '1',
      );
    }

    if (!mounted) return;

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
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    // Шапка
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Заявка на закупку',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Подсказка
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Отметь позиции для заказа. Дефицитные отмечены автоматически.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Список
                    Expanded(
                      child: ListView.builder(
                        itemCount: sorted.length,
                        itemBuilder: (context, i) {
                          final it = sorted[i];
                          final id = it['id'].toString();
                          final isSelected = selected.containsKey(id);
                          final qty = (it['quantity'] as num?)?.toInt() ?? 0;
                          final min = (it['minQuantity'] as num?)?.toInt() ?? 0;
                          final isOut = qty <= 0;
                          final isLow = !isOut && min > 0 && qty <= min;

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  final target = min > 0 ? min * 2 : 2;
                                  final need = target - qty;
                                  selected[id] = need > 0 ? need : 1;
                                  qtyCtrls[id]?.text = selected[id].toString();
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                            title: Text(
                              it['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((it['article'] ?? '').toString().isNotEmpty)
                                  Text(
                                    'Арт.: ${it['article']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                Text(
                                  'На складе: $qty  •  Минимум: $min',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOut
                                        ? Colors.red
                                        : isLow
                                        ? Colors.orange.shade800
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            secondary: isSelected
                                ? SizedBox(
                                    width: 70,
                                    child: TextField(
                                      controller: qtyCtrls[id],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Кол-во',
                                        labelStyle: TextStyle(fontSize: 10),
                                      ),
                                      onChanged: (v) {
                                        final n = int.tryParse(v.trim());
                                        if (n != null && n > 0) {
                                          selected[id] = n;
                                        }
                                      },
                                    ),
                                  )
                                : (isOut || isLow)
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isOut ? Colors.red : Colors.orange)
                                              .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isOut ? 'Нет' : 'Мало',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isOut
                                            ? Colors.red
                                            : Colors.orange.shade800,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),

                    // Кнопка «Сформировать»
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Выбрано: ${selected.length}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () async {
                                      // Собираем список для PDF
                                      final orderItems =
                                          <Map<String, dynamic>>[];
                                      for (final it in sorted) {
                                        final id = it['id'].toString();
                                        if (!selected.containsKey(id)) {
                                          continue;
                                        }
                                        orderItems.add({
                                          'name': it['name'],
                                          'article': it['article'],
                                          'orderQuantity': selected[id],
                                          'unit': it['unit'] ?? 'шт.',
                                        });
                                      }

                                      Navigator.pop(context);
                                      try {
                                        await PdfService.generatePurchaseRequest(
                                          items: orderItems,
                                        );
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Ошибка генерации: $e',
                                                  ),
                                                ),
                                              );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Сформировать заявку'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============ ДИАЛОГ ЗАПЧАСТИ ============

  Future<void> _showAddEditDialog({int? editIndex}) async {
    if (categories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала добавь категорию (иконка «папки» сверху)'),
          ),
        );
      }
      return;
    }

    final isEdit = editIndex != null;
    final existing = isEdit ? items[editIndex] : null;

    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final articleCtrl = TextEditingController(text: existing?['article'] ?? '');
    final qtyCtrl = TextEditingController(
      text: (existing?['quantity'] ?? 0).toString(),
    );
    final minCtrl = TextEditingController(
      text: (existing?['minQuantity'] ?? 0).toString(),
    );
    final locationCtrl = TextEditingController(
      text: existing?['location'] ?? '',
    );
    final notesCtrl = TextEditingController(text: existing?['notes'] ?? '');

    String categoryId =
        existing?['categoryId']?.toString() ??
        categories.first['id'].toString();
    String? subcategoryId = existing?['subcategoryId']?.toString();

    // Если запчасть без категории, или категории нет — присваиваем первую
    if (_findCategory(categoryId) == null) {
      categoryId = categories.first['id'].toString();
      subcategoryId = null;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cat = _findCategory(categoryId);
            final subs = (cat?['subcategories'] as List?) ?? [];

            return AlertDialog(
              title: Text(isEdit ? 'Редактировать запчасть' : 'Новая запчасть'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Название',
                          hintText: 'Ремень А-1000',
                        ),
                        autofocus: !isEdit,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                        ),
                        items: categories.map((c) {
                          return DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(c['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            categoryId = v!;
                            subcategoryId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        value: subcategoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Подкатегория',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Без подкатегории —'),
                          ),
                          ...subs.map((s) {
                            return DropdownMenuItem<String?>(
                              value: s['id'].toString(),
                              child: Text(s['name'] ?? ''),
                            );
                          }),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => subcategoryId = v),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: articleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Артикул',
                          hintText: 'PB-6205',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Количество',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Минимум',
                                hintText: '3',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Где хранится',
                          hintText: 'Склад, стеллаж А',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(labelText: 'Заметки'),
                        maxLines: 2,
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
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final item = {
                      'id':
                          existing?['id'] ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      'name': nameCtrl.text.trim(),
                      'categoryId': categoryId,
                      'subcategoryId': subcategoryId,
                      'article': articleCtrl.text.trim(),
                      'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
                      'minQuantity': int.tryParse(minCtrl.text.trim()) ?? 0,
                      'location': locationCtrl.text.trim(),
                      'notes': notesCtrl.text.trim(),
                      'updatedAt': DateTime.now().toIso8601String(),
                    };
                    setState(() {
                      if (isEdit) {
                        items[editIndex] = item;
                      } else {
                        items.add(item);
                      }
                    });
                    await _saveItems();
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

  Future<void> _changeQuantity(int index, int delta) async {
    setState(() {
      final current = (items[index]['quantity'] as num?)?.toInt() ?? 0;
      items[index]['quantity'] = (current + delta).clamp(0, 999999);
      items[index]['updatedAt'] = DateTime.now().toIso8601String();
    });
    await _saveItems();
  }

  Future<void> _deleteItem(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запчасть?'),
        content: Text('«${items[index]['name']}» будет удалена со склада.'),
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
      setState(() => items.removeAt(index));
      await _saveItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCat = _findCategory(categoryFilter);
    final currentSubs = (currentCat?['subcategories'] as List?) ?? const [];

    return Scaffold(
      body: Column(
        children: [
          if (_lowCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Мало на складе: $_lowCount позиц. Нужно заказать!',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Поиск + кнопка категорий
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Поиск',
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
                IconButton.filled(
                  tooltip: 'Заявка на закупку',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _openPurchaseRequest,
                  icon: const Icon(Icons.description_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Категории',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WarehouseCategoriesScreen(),
                      ),
                    );
                    await _reloadCategories();
                  },
                  icon: const Icon(Icons.folder_outlined),
                ),
              ],
            ),
          ),

          // Категории
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: const Text('Все'),
                  selected: categoryFilter == null,
                  onSelected: (_) => setState(() {
                    categoryFilter = null;
                    subcategoryFilter = null;
                  }),
                ),
                const SizedBox(width: 8),
                ...categories.map((c) {
                  final count = items
                      .where((i) => i['categoryId'] == c['id'])
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${c['name']} ($count)'),
                      selected: categoryFilter == c['id'],
                      onSelected: (_) => setState(() {
                        categoryFilter = c['id'].toString();
                        subcategoryFilter = null;
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Подкатегории (если выбрана категория)
          if (categoryFilter != null && currentSubs.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: const Text(
                      'Все подкатегории',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: subcategoryFilter == null,
                    onSelected: (_) => setState(() => subcategoryFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...currentSubs.map((s) {
                    final subId = s['id'].toString();
                    final count = items
                        .where(
                          (i) =>
                              i['categoryId'] == categoryFilter &&
                              i['subcategoryId'] == subId,
                        )
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '${s['name']} ($count)',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: subcategoryFilter == subId,
                        onSelected: (_) =>
                            setState(() => subcategoryFilter = subId),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Сортировка
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: const Text('По названию'),
                  selected: sortMode == 'name',
                  onSelected: (_) => setState(() => sortMode = 'name'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('По количеству'),
                  selected: sortMode == 'quantity',
                  onSelected: (_) => setState(() => sortMode = 'quantity'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Сначала дефицит'),
                  selected: sortMode == 'low',
                  onSelected: (_) => setState(() => sortMode = 'low'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      items.isEmpty
                          ? 'Склад пуст.\nНажми «+», чтобы добавить запчасть.'
                          : 'Ничего не найдено',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final realIndex = items.indexOf(item);
                      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                      final min = (item['minQuantity'] as num?)?.toInt() ?? 0;
                      final isOut = qty <= 0;
                      final isLow = !isOut && min > 0 && qty <= min;

                      final cat = _findCategory(item['categoryId']?.toString());
                      final sub = _findSubcategory(
                        item['categoryId']?.toString(),
                        item['subcategoryId']?.toString(),
                      );

                      return Dismissible(
                        key: ValueKey(item['id'] ?? index.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteItem(realIndex),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isOut
                                ? const BorderSide(
                                    color: Colors.red,
                                    width: 1.5,
                                  )
                                : isLow
                                ? BorderSide(
                                    color: Colors.orange.shade300,
                                    width: 1.2,
                                  )
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                _showAddEditDialog(editIndex: realIndex),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Color(0xFF1B5E20),
                                        ),
                                        iconSize: 24,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _changeQuantity(realIndex, 1),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOut
                                              ? Colors.red.withOpacity(0.15)
                                              : isLow
                                              ? Colors.orange.withOpacity(0.15)
                                              : const Color(0xFF1B5E20)
                                                    .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '$qty',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isOut
                                                ? Colors.red
                                                : isLow
                                                ? Colors.orange.shade800
                                                : const Color(0xFF1B5E20),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.remove_circle,
                                          color: qty > 0
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                        ),
                                        iconSize: 24,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: qty > 0
                                            ? () =>
                                                  _changeQuantity(realIndex, -1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (cat != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.folder_outlined,
                                                  size: 11,
                                                  color: Colors.blueGrey,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${cat['name']}${sub != null ? ' → ${sub['name']}' : ''}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if ((item['article'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              'Арт.: ${item['article']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        if ((item['location'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.place_outlined,
                                                  size: 12,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 3),
                                                Expanded(
                                                  child: Text(
                                                    item['location'],
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (isOut || isLow)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isOut
                                                    ? Colors.red.withOpacity(
                                                        0.15,
                                                      )
                                                    : Colors.orange.withOpacity(
                                                        0.15,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isOut
                                                    ? 'Нет в наличии'
                                                    : 'Мало (мин. $min)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isOut
                                                      ? Colors.red
                                                      : Colors.orange.shade800,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
