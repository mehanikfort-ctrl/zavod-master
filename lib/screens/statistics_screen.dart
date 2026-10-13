import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> equipment = [];
  bool isLoading = true;
  DateTime selectedMonth = DateTime.now();

  final List<String> monthNames = const [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTasks = prefs.getString('tasks');
    if (rawTasks != null && rawTasks.isNotEmpty) {
      tasks = (jsonDecode(rawTasks) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final rawEq = prefs.getString('equipment');
    if (rawEq != null && rawEq.isNotEmpty) {
      equipment = (jsonDecode(rawEq) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    setState(() => isLoading = false);
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(raw);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
    } catch (_) {
      return null;
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + delta);
    });
  }

  // Все задачи за выбранный месяц
  List<Map<String, dynamic>> get _monthTasks {
    return tasks.where((t) {
      final d = _parseDate(t['time']?.toString());
      if (d == null) return false;
      return d.year == selectedMonth.year && d.month == selectedMonth.month;
    }).toList();
  }

  int get _totalCount => _monthTasks.length;
  int get _doneCount => _monthTasks.where((t) => t['completed'] == true).length;
  int get _activeCount => _monthTasks
      .where((t) => t['completed'] != true && t['archived'] != true)
      .length;
  int get _archivedCount =>
      _monthTasks.where((t) => t['archived'] == true).length;

  // Просроченные (не выполнены + дата раньше сегодня)
  int get _overdueCount {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _monthTasks.where((t) {
      if (t['completed'] == true) return false;
      final d = _parseDate(t['time']?.toString());
      if (d == null) return false;
      return d.isBefore(todayStart);
    }).length;
  }

  // Разбивка по категориям
  Map<String, int> get _byCategory {
    final map = <String, int>{};
    for (final t in _monthTasks) {
      final cat = t['category']?.toString() ?? 'Другое';
      map[cat] = (map[cat] ?? 0) + 1;
    }
    return map;
  }

  // Разбивка по приоритетам
  Map<String, int> get _byPriority {
    final map = <String, int>{};
    for (final t in _monthTasks) {
      final pr = t['priority']?.toString() ?? 'Без приоритета';
      map[pr] = (map[pr] ?? 0) + 1;
    }
    return map;
  }

  // Топ-5 оборудования
  List<MapEntry<String, int>> get _topEquipment {
    final map = <String, int>{};
    for (final t in _monthTasks) {
      final eqId = t['equipmentId']?.toString();
      if (eqId == null) continue;
      final eq = equipment.firstWhere(
        (e) => e['id'] == eqId,
        orElse: () => <String, dynamic>{},
      );
      final name = eq['name']?.toString() ?? 'Неизвестно';
      map[name] = (map[name] ?? 0) + 1;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(5).toList();
  }

  // Задачи по дням месяца (для графика)
  Map<int, int> get _byDay {
    final map = <int, int>{};
    for (final t in _monthTasks) {
      final d = _parseDate(t['time']?.toString());
      if (d == null) continue;
      map[d.day] = (map[d.day] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Переключатель месяца
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                  color: const Color(0xFF1B5E20),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      selectedMonth.year == DateTime.now().year &&
                          selectedMonth.month == DateTime.now().month
                      ? null
                      : () => _changeMonth(1),
                  color: const Color(0xFF1B5E20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Основные карточки
          Row(
            children: [
              Expanded(
                child: _statBigCard(
                  label: 'Всего',
                  value: '$_totalCount',
                  icon: Icons.assignment,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBigCard(
                  label: 'Выполнено',
                  value: '$_doneCount',
                  icon: Icons.check_circle,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statBigCard(
                  label: 'В работе',
                  value: '$_activeCount',
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBigCard(
                  label: 'Просрочено',
                  value: '$_overdueCount',
                  icon: Icons.warning_amber,
                  color: _overdueCount > 0 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),

          // Процент выполнения
          if (_totalCount > 0) ...[
            const SizedBox(height: 20),
            _sectionTitle('Процент выполнения', isDark),
            const SizedBox(height: 8),
            _progressBar(
              'Выполнено',
              _doneCount,
              _totalCount,
              const Color(0xFF1B5E20),
            ),
            const SizedBox(height: 6),
            _progressBar('В работе', _activeCount, _totalCount, Colors.orange),
            const SizedBox(height: 6),
            _progressBar('Архив', _archivedCount, _totalCount, Colors.grey),
          ],

          // График по дням
          if (_byDay.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Задачи по дням', isDark),
            const SizedBox(height: 8),
            _dayChart(_byDay, isDark),
          ],

          // Категории
          if (_byCategory.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('По категориям', isDark),
            const SizedBox(height: 8),
            ..._categoryRows(_byCategory, isDark),
          ],

          // Приоритеты
          if (_byPriority.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('По приоритетам', isDark),
            const SizedBox(height: 8),
            ..._categoryRows(_byPriority, isDark),
          ],

          // Топ оборудования
          if (_topEquipment.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Топ-5 оборудования', isDark),
            const SizedBox(height: 8),
            ..._topEquipment.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                elevation: 0,
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF1B5E20).withOpacity(0.15),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                  title: Text(
                    item.key,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${item.value} задач',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              );
            }),
          ],

          if (_totalCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'За ${monthNames[selectedMonth.month - 1].toLowerCase()} '
                  '${selectedMonth.year} задач нет',
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _statBigCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _progressBar(String label, int value, int total, Color color) {
    final ratio = total > 0 ? value / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 14,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            '${(ratio * 100).toStringAsFixed(0)}% ($value)',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _dayChart(Map<int, int> byDay, bool isDark) {
    final maxVal = byDay.values.reduce((a, b) => a > b ? a : b);
    final daysInMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(daysInMonth, (i) {
            final day = i + 1;
            final count = byDay[day] ?? 0;
            final ratio = maxVal > 0 ? count / maxVal : 0.0;
            final h = 80 * ratio;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (count > 0)
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    Container(
                      height: h.clamp(2.0, 80.0),
                      decoration: BoxDecoration(
                        color: count > 0
                            ? const Color(0xFF1B5E20)
                            : Colors.grey.shade300,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (day % 5 == 1 || day == daysInMonth)
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 8,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<Widget> _categoryRows(Map<String, int> data, bool isDark) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isEmpty ? 1 : sorted.first.value;

    return sorted.map((entry) {
      final ratio = entry.value / maxVal;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 14,
                  backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF1B5E20)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text(
                '${entry.value}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
