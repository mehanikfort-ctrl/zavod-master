import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> equipment = [];
  List<Map<String, dynamic>> meters = [];
  bool isLoading = true;

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

    final rawMeters = prefs.getString('meters');
    if (rawMeters != null && rawMeters.isNotEmpty) {
      meters = (jsonDecode(rawMeters) as List)
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

  // Задачи на сегодня
  List<Map<String, dynamic>> get _todayTasks {
    final now = DateTime.now();
    return tasks.where((t) {
      if (t['completed'] == true) return false;
      final d = _parseDate(t['time']?.toString());
      if (d == null) return false;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  // Просроченные задачи (дата раньше сегодня, ещё не выполнены)
  List<Map<String, dynamic>> get _overdueTasks {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return tasks.where((t) {
      if (t['completed'] == true) return false;
      final d = _parseDate(t['time']?.toString());
      if (d == null) return false;
      return d.isBefore(todayStart);
    }).toList()..sort((a, b) {
      final da = _parseDate(a['time']?.toString());
      final db = _parseDate(b['time']?.toString());
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
  }

  int get _activeCount => tasks.where((t) => t['completed'] != true).length;
  int get _doneCount => tasks.where((t) => t['completed'] == true).length;

  // Последние показания каждого счётчика
  List<Map<String, dynamic>> get _recentReadings {
    final result = <Map<String, dynamic>>[];
    for (final m in meters) {
      final readings = (m['readings'] as List?) ?? [];
      if (readings.isEmpty) continue;
      final sorted = readings.toList()
        ..sort(
          (a, b) => (b['date'] ?? '').toString().compareTo(
            (a['date'] ?? '').toString(),
          ),
        );
      final last = Map<String, dynamic>.from(sorted.first);
      result.add({
        'meterName': m['name'],
        'unit': m['unit'],
        'value': last['value'],
        'date': last['date'],
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Приветствие по времени суток
          Text(
            _greeting(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Сводка на сегодня',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),

          // 4 карточки-счётчика
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.pending_actions,
                  label: 'В работе',
                  value: '$_activeCount',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  icon: Icons.today,
                  label: 'На сегодня',
                  value: '${_todayTasks.length}',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.warning_amber,
                  label: 'Просрочено',
                  value: '${_overdueTasks.length}',
                  color: _overdueTasks.isEmpty ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  icon: Icons.check_circle,
                  label: 'Выполнено',
                  value: '$_doneCount',
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Просроченные задачи
          if (_overdueTasks.isNotEmpty) ...[
            _sectionTitle(
              context,
              icon: Icons.warning_amber,
              iconColor: Colors.red,
              title: 'Просроченные задачи',
              count: _overdueTasks.length,
            ),
            const SizedBox(height: 8),
            ..._overdueTasks.take(5).map((t) {
              final d = _parseDate(t['time']?.toString());
              final daysLate = d == null
                  ? 0
                  : DateTime.now().difference(d).inDays;
              return _taskTile(
                context,
                title: t['title'] ?? '',
                subtitle: '${t['category']}  •  ${t['priority']}',
                trailing: daysLate > 0 ? '$daysLate дн.' : 'сегодня',
                trailingColor: Colors.red,
              );
            }),
            if (_overdueTasks.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '...и ещё ${_overdueTasks.length - 5}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 22),
          ],

          // Задачи на сегодня
          _sectionTitle(
            context,
            icon: Icons.today,
            iconColor: Colors.orange,
            title: 'На сегодня',
            count: _todayTasks.length,
          ),
          const SizedBox(height: 8),
          if (_todayTasks.isEmpty)
            _emptyHint('На сегодня задач нет — отдыхай 😌')
          else
            ..._todayTasks.map((t) {
              return _taskTile(
                context,
                title: t['title'] ?? '',
                subtitle: '${t['category']}  •  ${t['priority']}',
                trailing: _timeOnly(t['time']?.toString()),
                trailingColor: Colors.grey,
              );
            }),
          const SizedBox(height: 22),

          // Последние показания счётчиков
          if (_recentReadings.isNotEmpty) ...[
            _sectionTitle(
              context,
              icon: Icons.speed,
              iconColor: Colors.blue,
              title: 'Последние показания',
              count: _recentReadings.length,
            ),
            const SizedBox(height: 8),
            ..._recentReadings.map((r) {
              return _taskTile(
                context,
                title: r['meterName'] ?? '',
                subtitle: 'Ед.: ${r['unit']}',
                trailing: '${r['value']}',
                trailingColor: const Color(0xFF1B5E20),
              );
            }),
            const SizedBox(height: 22),
          ],

          // Оборудование
          _sectionTitle(
            context,
            icon: Icons.build,
            iconColor: const Color(0xFF1B5E20),
            title: 'Оборудование',
            count: equipment.length,
          ),
          const SizedBox(height: 8),
          if (equipment.isEmpty)
            _emptyHint('Список оборудования пуст')
          else
            _taskTile(
              context,
              title: 'Всего единиц в системе',
              subtitle: 'Смотри вкладку «Оборудование»',
              trailing: '${equipment.length}',
              trailingColor: const Color(0xFF1B5E20),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Доброй ночи!';
    if (h < 12) return 'Доброе утро!';
    if (h < 18) return 'Добрый день!';
    return 'Добрый вечер!';
  }

  String _timeOnly(String? raw) {
    if (raw == null) return '';
    final m = RegExp(r'(\d{2}):(\d{2})').firstMatch(raw);
    return m != null ? '${m.group(1)}:${m.group(2)}' : '';
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
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

  Widget _sectionTitle(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _taskTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String trailing,
    required Color trailingColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: trailingColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }
}
