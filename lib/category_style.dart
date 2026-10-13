import 'package:flutter/material.dart';

/// Доступные иконки для категорий склада.
/// Ключ хранится в JSON, значение — сам IconData.
const Map<String, IconData> categoryIcons = {
  'mechanic': Icons.build,
  'electric': Icons.electric_bolt,
  'water': Icons.water_drop,
  'gas': Icons.local_fire_department,
  'consumable': Icons.shopping_bag,
  'fastener': Icons.hardware,
  'box': Icons.inventory_2,
  'tools': Icons.handyman,
  'pipe': Icons.plumbing,
  'cable': Icons.cable,
  'paint': Icons.format_paint,
  'safety': Icons.health_and_safety,
  'settings': Icons.settings,
  'category': Icons.category,
};

/// Доступные цвета для категорий.
/// Ключ хранится в JSON, значение — сам Color.
const Map<String, Color> categoryColors = {
  'green': Color(0xFF1B5E20),
  'red': Color(0xFFC62828),
  'blue': Color(0xFF1565C0),
  'orange': Color(0xFFEF6C00),
  'purple': Color(0xFF6A1B9A),
  'teal': Color(0xFF00695C),
  'brown': Color(0xFF5D4037),
  'indigo': Color(0xFF283593),
  'pink': Color(0xFFAD1457),
  'grey': Color(0xFF424242),
};

/// Получить иконку по ключу. Если ключа нет — вернуть дефолтную.
IconData getCategoryIcon(String? key) {
  return categoryIcons[key] ?? Icons.category;
}

/// Получить цвет по ключу. Если ключа нет — вернуть дефолтный.
Color getCategoryColor(String? key) {
  return categoryColors[key] ?? const Color(0xFF1B5E20);
}

/// Понятные подписи для иконок (в диалоге выбора).
const Map<String, String> categoryIconLabels = {
  'mechanic': 'Механика',
  'electric': 'Электрика',
  'water': 'Вода',
  'gas': 'Газ',
  'consumable': 'Расходник',
  'fastener': 'Крепёж',
  'box': 'Коробка',
  'tools': 'Инструмент',
  'pipe': 'Труба',
  'cable': 'Кабель',
  'paint': 'Краска',
  'safety': 'Безопасность',
  'settings': 'Шестерёнка',
  'category': 'Категория',
};

/// Понятные подписи для цветов (в диалоге выбора).
const Map<String, String> categoryColorLabels = {
  'green': 'Зелёный',
  'red': 'Красный',
  'blue': 'Синий',
  'orange': 'Оранжевый',
  'purple': 'Фиолетовый',
  'teal': 'Бирюзовый',
  'brown': 'Коричневый',
  'indigo': 'Индиго',
  'pink': 'Розовый',
  'grey': 'Серый',
};
