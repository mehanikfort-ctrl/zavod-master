import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> equipment = [];
  bool isLoading = true;
  bool isGenerating = false;

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

  Future<void> _generate({
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    setState(() => isGenerating = true);
    try {
      await PdfService.generateReport(
        title: title,
        periodStart: start,
        periodEnd: end,
        tasks: tasks,
        equipment: equipment,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка генерации PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => isGenerating = false);
    }
  }

  Future<void> _generateToday() async {
    final now = DateTime.now();
    await _generate(
      title: 'Ежедневный отчёт',
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<void> _generateWeek() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final start = startOfDay.subtract(const Duration(days: 6));
    await _generate(
      title: 'Отчёт за неделю',
      start: start,
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<void> _generateMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    await _generate(title: 'Отчёт за месяц', start: start, end: end);
  }

  Future<void> _generateMeterReport() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Выберите месяц для ведомости',
    );
    if (picked == null) return;

    final prefs = await SharedPreferences.getInstance();
    final rawMeters = prefs.getString('meters');
    if (rawMeters == null || rawMeters.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Счётчики не добавлены')));
      }
      return;
    }
    final meters = (jsonDecode(rawMeters) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    setState(() => isGenerating = true);
    try {
      await PdfService.generateMeterReport(period: picked, meters: meters);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка генерации: $e')));
      }
    } finally {
      if (mounted) setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Отчёты по задачам',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Всего задач в системе: ${tasks.length}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),

        _reportCard(
          icon: Icons.today,
          title: 'Ежедневный отчёт',
          subtitle:
              '${now.day.toString().padLeft(2, '0')}.'
              '${now.month.toString().padLeft(2, '0')}.${now.year}',
          onTap: _generateToday,
        ),
        const SizedBox(height: 12),
        _reportCard(
          icon: Icons.date_range,
          title: 'Отчёт за неделю',
          subtitle:
              'Последние 7 дней (по ${now.day.toString().padLeft(2, '0')}.'
              '${now.month.toString().padLeft(2, '0')}.${now.year})',
          onTap: _generateWeek,
        ),
        const SizedBox(height: 12),
        _reportCard(
          icon: Icons.calendar_month,
          title: 'Отчёт за месяц',
          subtitle: '${now.month.toString().padLeft(2, '0')}.${now.year}',
          onTap: _generateMonth,
        ),

        const SizedBox(height: 12),
        _reportCard(
          icon: Icons.speed,
          title: 'Ведомость показаний счётчиков',
          subtitle: 'Выбрать месяц — расход по каждому счётчику',
          onTap: _generateMeterReport,
        ),

        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade800),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Отчёт формируется в PDF. После генерации откроется окно с превью, '
                  'где можно сохранить файл или распечатать.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        if (isGenerating)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Формируем PDF...'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _reportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isGenerating ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF1B5E20), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
