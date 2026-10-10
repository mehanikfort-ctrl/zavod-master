import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/tasks_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/meters_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/regulations_screen.dart';

void main() {
  runApp(const ZavodMasterApp());
}

class ZavodMasterApp extends StatelessWidget {
  const ZavodMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TasksScreen(),
    EquipmentScreen(),
    MetersScreen(),
    RegulationsScreen(),
    ReportsScreen(),
  ];

  final List<String> _titles = const [
    'Мои задачи',
    'Оборудование',
    'Счётчики',
    'Регламенты',
    'Отчёты',
  ];

  @override
  void initState() {
    super.initState();
    _checkRegulations();
  }

  /// Проверяет все регламенты и создаёт задачи, если пришло время
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
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
