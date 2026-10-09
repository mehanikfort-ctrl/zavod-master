import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    descriptionCtrl = TextEditingController(
      text: widget.equipment['description'] ?? '',
    );
    spareParts = (widget.equipment['spareParts'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
        content: Text(
          '«${widget.equipment['name']}» будет удалено безвозвратно.',
        ),
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
      await widget.onDelete();
      if (mounted) Navigator.pop(context);
    }
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
          // Информация об объекте
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

          // Описание
          const Text(
            'Описание',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Назначение, особенности, дата ввода в эксплуатацию...',
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
          const SizedBox(height: 24),

          // Запчасти
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Запасные части',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _addSparePart,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (spareParts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Запчастей пока нет. Нажми «Добавить».',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...spareParts.asMap().entries.map((entry) {
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
