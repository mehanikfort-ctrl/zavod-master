import 'package:flutter/material.dart';

class MetersScreen extends StatelessWidget {
  const MetersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '📊 Здесь будут показания счётчиков',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}
