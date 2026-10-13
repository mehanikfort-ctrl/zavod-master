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

  // Состояние сворачивания
  bool _chartExpanded = true;
  bool _historyExpanded = true;

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

  // ============ ГРАФИК РАСХОДА ============
  // Собираем: месяц → последнее показание в этом месяце.
  // Затем считаем расход между соседними месяцами.
  List<Map<String, dynamic>> get _monthlyConsumption {
    // Группируем по (год, месяц) → последнее показание
    final Map<String, Map<String, dynamic>> byMonth = {};
    for (final r in readings) {
      final d = DateTime.tryParse((r['date'] ?? '').toString());
      if (d == null) continue;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final existing = byMonth[key];
      if (existing == null ||
          DateTime.parse(existing['date'].toString()).isBefore(d)) {
        byMonth[key] = Map<String, dynamic>.from(r);
      }
    }

    if (byMonth.length < 2) return [];

    // Сортируем месяцы от старых к новым
    final keys = byMonth.keys.toList()..sort();
    final result = <Map<String, dynamic>>[];

    for (int i = 1; i < keys.length; i++) {
      final prev = byMonth[keys[i - 1]]!;
      final curr = byMonth[keys[i]]!;
      final prevVal = (prev['value'] as num).toDouble();
      final currVal = (curr['value'] as num).toDouble();
      final consumption = currVal - prevVal;
      if (consumption < 0) continue; // счётчик сбросился — пропускаем

      final d = DateTime.parse(curr['date'].toString());
      result.add({
        'year': d.year,
        'month': d.month,
        'consumption': consumption,
      });
    }

    return result;
  }

  String _shortMonth(int m) {
    const names = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return names[m - 1];
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
    final m = widget.meter;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monthly = _monthlyConsumption;

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
          // Информация о счётчике
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

          // ===== ГРАФИК РАСХОДА =====
          _sectionHeader(
            icon: Icons.bar_chart,
            title: 'Расход по месяцам',
            count: monthly.length,
            expanded: _chartExpanded,
            onTap: () => setState(() => _chartExpanded = !_chartExpanded),
            iconColor: Colors.blue,
          ),
          _sectionBody(
            expanded: _chartExpanded,
            child: monthly.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Для графика нужно минимум 2 показания в разных месяцах.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : _buildChart(monthly, isDark),
          ),
          const SizedBox(height: 12),

          // ===== ИСТОРИЯ ПОКАЗАНИЙ =====
          _sectionHeader(
            icon: Icons.history,
            title: 'История показаний',
            count: readings.length,
            expanded: _historyExpanded,
            onTap: () => setState(() => _historyExpanded = !_historyExpanded),
            actionButton: ElevatedButton.icon(
              onPressed: _addReading,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Добавить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          _sectionBody(
            expanded: _historyExpanded,
            child: readings.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Показаний ещё нет.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : Column(
                    children: readings.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      final d = DateTime.tryParse((r['date'] ?? '').toString());
                      final prev = i + 1 < readings.length
                          ? readings[i + 1]
                          : null;

                      String? consumption;
                      if (prev != null) {
                        final diff = ((r['value'] ?? 0) - (prev['value'] ?? 0))
                            .toDouble();
                        consumption =
                            'Расход: ${diff.toStringAsFixed(2)} ${m['unit']}';
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
                                    : '${d.day.toString().padLeft(2, '0')}.'
                                          '${d.month.toString().padLeft(2, '0')}.'
                                          '${d.year}',
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
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============ СТОЛБИКОВЫЙ ГРАФИК ============

  Widget _buildChart(List<Map<String, dynamic>> data, bool isDark) {
    // Берём последние 12 месяцев максимум
    final visible = data.length > 12 ? data.sublist(data.length - 12) : data;
    final maxValue = visible
        .map((e) => (e['consumption'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    const chartHeight = 160.0;
    final unit = widget.meter['unit'] ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок графика
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'Расход, $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Столбики
          SizedBox(
            height: chartHeight + 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visible.asMap().entries.map((entry) {
                final item = entry.value;
                final value = (item['consumption'] as num).toDouble();
                final ratio = maxValue > 0 ? value / maxValue : 0.0;
                final barHeight = (chartHeight * ratio).clamp(4.0, chartHeight);
                final month = item['month'] as int;
                final year = item['year'] as int;
                final isCurrentYear = year == DateTime.now().year;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Значение над столбиком
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(1)}к'
                                : value.toStringAsFixed(value >= 100 ? 0 : 1),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Столбик
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.blue.shade700,
                                Colors.blue.shade300,
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Название месяца
                        Text(
                          _shortMonth(month),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                        // Год (только если не текущий)
                        if (!isCurrentYear)
                          Text(
                            '${year % 100}',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Сводка
          Row(
            children: [
              Expanded(
                child: _chartStat(
                  label: 'Средний',
                  value: _average(visible).toStringAsFixed(1),
                  unit: unit,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _chartStat(
                  label: 'Максимум',
                  value: maxValue.toStringAsFixed(1),
                  unit: unit,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _chartStat(
                  label: 'Минимум',
                  value: _min(visible).toStringAsFixed(1),
                  unit: unit,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _average(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 0;
    final sum = data
        .map((e) => (e['consumption'] as num).toDouble())
        .reduce((a, b) => a + b);
    return sum / data.length;
  }

  double _min(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 0;
    return data
        .map((e) => (e['consumption'] as num).toDouble())
        .reduce((a, b) => a < b ? a : b);
  }

  Widget _chartStat({
    required String label,
    required String value,
    required String unit,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
      ],
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
