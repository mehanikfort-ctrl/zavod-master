import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortMode = 'name'; // name | quantity | low

  static const String _storageKey = 'warehouse';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      items = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    setState(() => isLoading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(items));
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

  Future<void> _showAddEditDialog({int? editIndex}) async {
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

    await showDialog(
      context: context,
      builder: (context) {
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
                      hintText: 'Подшипник 6205',
                    ),
                    autofocus: !isEdit,
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
                      hintText: 'Склад, стеллаж А, полка 2',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Заметки',
                      hintText: 'Используется в насосах ЦНС',
                    ),
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
                await _save();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
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
    await _save();
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
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Сводка "мало на складе"
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

          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск по названию, артикулу, месту',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),

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
                                  // Количество с +/- кнопками
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

                                  // Информация о запчасти
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
