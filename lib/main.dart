import 'package:flutter/material.dart';

import 'screens/tasks_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/meters_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/regulations_screen.dart';
import 'notification_service.dart';
import 'screens/dashboard_screen.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ZavodMechanikApp());
}

class ZavodMechanikApp extends StatefulWidget {
  const ZavodMechanikApp({super.key});

  @override
  State<ZavodMechanikApp> createState() => _ZavodMechanikAppState();
}

class _ZavodMechanikAppState extends State<ZavodMechanikApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode') ?? 'light';
    setState(() {
      _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _loaded = true;
    });
  }

  Future<void> _toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() => _themeMode = newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      newMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Завод-Механик',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: MainScreen(themeMode: _themeMode, onToggleTheme: _toggleTheme),
    );
  }
}

class MainScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const MainScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TasksScreen(),
    EquipmentScreen(),
    MetersScreen(),
    RegulationsScreen(),
    ReportsScreen(),
  ];

  final List<String> _titles = const [
    'Главная',
    'Мои задачи',
    'Оборудование',
    'Счётчики',
    'Регламенты',
    'Отчёты',
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _checkRegulations();
  }

  Future<void> _initNotifications() async {
    await NotificationService().init();
    await NotificationService().cancelAll(); // отменяем устаревшие
    await _scheduleUpcomingNotifications();
    await _scheduleRegulationNotifications();
  }

  Future<void> _scheduleUpcomingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTasks = prefs.getString('tasks');
    if (rawTasks == null || rawTasks.isEmpty) return;

    final List<dynamic> decoded = jsonDecode(rawTasks);
    final List<Map<String, dynamic>> tasks = decoded
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final now = DateTime.now();
    int id = 1000;

    for (final task in tasks) {
      if (task['completed'] == true) continue;

      final timeStr = task['time']?.toString() ?? '';
      final dateMatch = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})')
          .firstMatch(timeStr);
      if (dateMatch == null) continue;

      final timeMatch = RegExp(r'(\d{2}):(\d{2})').firstMatch(timeStr);
      final hour = timeMatch != null ? int.parse(timeMatch.group(1)!) : 9;
      final minute = timeMatch != null ? int.parse(timeMatch.group(2)!) : 0;

      final scheduledDate = DateTime(
        int.parse(dateMatch.group(3)!),
        int.parse(dateMatch.group(2)!),
        int.parse(dateMatch.group(1)!),
        hour,
        minute,
      );

      final notifyAt = scheduledDate.subtract(const Duration(days: 1));
      final notifyTime = DateTime(
        notifyAt.year,
        notifyAt.month,
        notifyAt.day,
        9,
        0,
      );

      if (notifyTime.isAfter(now)) {
        await NotificationService().scheduleAt(
          id: id++,
          title: 'Напоминание о задаче',
          body: task['title'] ?? '',
          dateTime: notifyTime,
        );
      }
    }
  }

  /// Планирует уведомления для всех активных регламентов на месяц вперёд.
  Future<void> _scheduleRegulationNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRegs = prefs.getString('regulations');
    if (rawRegs == null || rawRegs.isEmpty) return;

    final List<dynamic> decoded = jsonDecode(rawRegs);
    final List<Map<String, dynamic>> regs = decoded
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int id = 5000;

    for (final reg in regs) {
      if (reg['enabled'] != true) continue;

      final title = reg['title']?.toString() ?? 'Регламент';
      final type = reg['type'];
      final upcoming = <DateTime>[];

      if (type == 'daily') {
        // Каждый день на 30 дней вперёд
        for (int i = 1; i <= 30; i++) {
          upcoming.add(today.add(Duration(days: i)));
        }
      } else if (type == 'weekly') {
        final wd = reg['weekday'] as int?;
        if (wd != null) {
          for (int i = 1; i < 70 && upcoming.length < 10; i++) {
            final d = today.add(Duration(days: i));
            if (d.weekday == wd) upcoming.add(d);
          }
        }
      } else if (type == 'monthly') {
        final day = reg['dayOfMonth'] as int?;
        if (day != null) {
          for (int i = 0; i < 6; i++) {
            final month = DateTime(now.year, now.month + i, day);
            if (month.isAfter(today)) upcoming.add(month);
          }
        }
      }

      for (final d in upcoming) {
        // Напоминаем за день до события, в 9:00
        final notifyDay = d.subtract(const Duration(days: 1));
        final notifyTime = DateTime(
          notifyDay.year,
          notifyDay.month,
          notifyDay.day,
          9,
          0,
        );

        if (notifyTime.isAfter(now)) {
          await NotificationService().scheduleAt(
            id: id++,
            title: 'Напоминание: $title',
            body: 'Завтра нужно: $title',
            dateTime: notifyTime,
          );
        }
      }
    }
  }

  Future<void> _checkRegulations() async {
    final prefs = await SharedPreferences.getInstance();

    final rawRegs = prefs.getString('regulations');
    if (rawRegs == null || rawRegs.isEmpty) return;

    final List<dynamic> regsDecoded = jsonDecode(rawRegs);
    final List<Map<String, dynamic>> regs = regsDecoded
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final rawTasks = prefs.getString('tasks');
    final List<Map<String, dynamic>> tasks =
        (rawTasks != null && rawTasks.isNotEmpty)
        ? (jsonDecode(rawTasks) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final now = DateTime.now();
    bool changed = false;

    for (final reg in regs) {
      if (reg['enabled'] != true) continue;

      final DateTime? lastRun = reg['lastRun'] != null
          ? DateTime.tryParse(reg['lastRun'].toString())
          : null;

      bool shouldRun = false;

      if (reg['type'] == 'daily') {
        if (lastRun == null ||
            lastRun.year != now.year ||
            lastRun.month != now.month ||
            lastRun.day != now.day) {
          shouldRun = true;
        }
      } else if (reg['type'] == 'weekly') {
        final wd = reg['weekday'] as int?;
        if (wd != null && now.weekday == wd) {
          if (lastRun == null || now.difference(lastRun).inDays >= 6) {
            shouldRun = true;
          }
        }
      } else if (reg['type'] == 'monthly') {
        final d = reg['dayOfMonth'] as int?;
        if (d != null && now.day >= d) {
          if (lastRun == null ||
              lastRun.year != now.year ||
              lastRun.month != now.month) {
            shouldRun = true;
          }
        }
      }

      if (shouldRun) {
        tasks.add({
          'title': reg['title'],
          'category': reg['category'],
          'priority': reg['priority'],
          'time':
              '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
          'equipmentId': reg['equipmentId'],
          'fromRegulation': reg['id'],
          'completed': false,
          'comments': <Map<String, dynamic>>[],
          'photos': <String>[],
        });
        reg['lastRun'] = now.toIso8601String();
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString('tasks', jsonEncode(tasks));
      await prefs.setString('regulations', jsonEncode(regs));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : const Color(0xFF1B5E20),
        foregroundColor: isDark ? null : Colors.white,
        actions: [
          IconButton(
            tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Задачи',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Оборудование',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Счётчики',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_outlined),
            selectedIcon: Icon(Icons.repeat),
            label: 'Регламенты',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Отчёты',
          ),
        ],
      ),
    );
  }
}
