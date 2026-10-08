import 'package:flutter/material.dart';

void main() {
  runApp(const ZavodMasterApp());
}

class ZavodMasterApp extends StatelessWidget {
  const ZavodMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Завод-Мастер',
      debugShowCheckedModeBanner: false, // Убираем красную ленточку "DEBUG"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20), // Темно-зеленый, "заводской" цвет
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Список задач теперь хранится в состоянии
  final List<Map<String, dynamic>> tasks = [
    {
      'title': 'Заменить прокладку на насосе №3',
      'category': '💧 Вода',
      'priority': '🔴 Срочно',
      'time': 'Сегодня, 10:00',
    },
    {
      'title': 'Обход трансформаторной подстанции',
      'category': '⚡ Электрика',
      'priority': '🟡 Средний',
      'time': 'Сегодня, 14:00',
    },
    {
      'title': 'Передать показания счетчиков',
      'category': '📊 Счётчики',
      'priority': '🟢 Плановое',
      'time': '25 число, 08:00',
    },
  ];

  // Метод для добавления задачи
  void _addTask() {
    final TextEditingController titleController = TextEditingController();
    String selectedCategory = '🔧 Механика';
    String selectedPriority = '🟡 Средний';

    final List<String> categories = [
      '💧 Вода',
      '⚡ Электрика',
      '🔥 Газ',
      '🏗️ Кран',
      '🔧 Механика',
      '💻 Электроника',
      '📊 Счётчики',
    ];

    final List<String> priorities = ['🔴 Срочно', '🟡 Средний', '🟢 Плановое'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Новая задача'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: 'Например: Заменить лампу в цехе №2',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Категория'),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration: const InputDecoration(labelText: 'Приоритет'),
                    items: priorities.map((pr) {
                      return DropdownMenuItem(value: pr, child: Text(pr));
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedPriority = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      setState(() {
                        tasks.add({
                          'title': titleController.text.trim(),
                          'category': selectedCategory,
                          'priority': selectedPriority,
                          'time': 'Сегодня',
                        });
                      });
                      Navigator.pop(context);
                    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Завод-Мастер'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              title: Text(
                task['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${task['category']}  •  ${task['priority']}'),
              ),
              trailing: Text(
                task['time'],
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask, // Теперь при нажатии вызывается диалог
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
