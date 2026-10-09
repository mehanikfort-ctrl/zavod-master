import 'package:flutter/material.dart';

class MeterDetailScreen extends StatefulWidget {
  final Map<String, dynamic> meter;
  final Future<void> Function() onChanged;
  final Future<void> Function() onDelete;

  const MeterDetailScreen({
    super.key,
    required this.meter,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends State<MeterDetailScreen> {
  late List<Map<String, dynamic>> readings;

  @override
  void initState() {
    super.initState();
    readings = (widget.meter['readings'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _sort();
  }

  void _sort() {
    readings.sort(
      (a, b) =>
          (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()),
    );
  }

  Future<void> _addReading() async {
    final valueCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Новое показание'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: valueCtrl,
                    decoration: InputDecoration(
                      labelText: 'Показание (${widget.meter['unit']})',
                      hintText: '12345.67',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}.'
                      '${selectedDate.month.toString().padLeft(2, '0')}.'
                      '${selectedDate.year}',
                    ),
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
                    final val = double.tryParse(
                      valueCtrl.text.trim().replaceAll(',', '.'),
                    );
                    if (val == null) return;
                    readings.add({
                      'date': selectedDate.toIso8601String(),
                      'value': val,
                    });
                    _sort();
                    widget.meter['readings'] = readings;
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
      },
    );
  }

  Future<void> _deleteReading(int index) async {
    setState(() {
      readings.removeAt(index);
      widget.meter['readings'] = readings;
    });
    await widget.onChanged();
  }

  Future<void> _deleteMeter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить счётчик?'),
        content: Text(
          '«${widget.meter['name']}» и вся история показаний будут удалены.',
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
    final m = widget.meter;

    return Scaffold(
      appBar: AppBar(
        title: Text(m['name'] ?? 'Счётчик'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Удалить счётчик',
            onPressed: _deleteMeter,
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
                  _row('Тип', m['type'] ?? '—'),
                  const SizedBox(height: 6),
                  _row('Единица', m['unit'] ?? '—'),
                  const SizedBox(height: 6),
                  _row(
                    'Расположение',
                    (m['location'] ?? '').toString().isEmpty
                        ? '—'
                        : m['location'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'История показаний',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _addReading,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (readings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Показаний ещё нет.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...readings.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final d = DateTime.tryParse((r['date'] ?? '').toString());
              final prev = i + 1 < readings.length ? readings[i + 1] : null;

              // Считаем расход между показаниями
              String? consumption;
              if (prev != null) {
                final diff = ((r['value'] ?? 0) - (prev['value'] ?? 0))
                    .toDouble();
                consumption = 'Расход: ${diff.toStringAsFixed(2)} ${m['unit']}';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.speed),
                  title: Text(
                    '${r['value']} ${m['unit']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d == null
                            ? '—'
                            : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
                      ),
                      if (consumption != null)
                        Text(
                          consumption,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _deleteReading(i),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
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
