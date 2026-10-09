import 'package:flutter/material.dart';

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '🔧 Здесь будет список оборудования',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}
