import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '📄 Здесь будут отчёты в PDF',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}
