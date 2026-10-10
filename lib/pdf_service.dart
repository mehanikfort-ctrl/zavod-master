import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<pw.Font> _loadRegular() async {
    final data = await File('assets/fonts/Roboto-Regular.ttf').readAsBytes();
    return pw.Font.ttf(data.buffer.asByteData());
  }

  static Future<pw.Font> _loadBold() async {
    final data = await File('assets/fonts/Roboto-Bold.ttf').readAsBytes();
    return pw.Font.ttf(data.buffer.asByteData());
  }

  static DateTime? parseTaskDate(String? raw) {
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

  static Future<void> generateReport({
    required String title,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> equipment,
  }) async {
    final regular = await _loadRegular();
    final bold = await _loadBold();
    final dateFmt = DateFormat('dd.MM.yyyy');

    final inPeriod = tasks.where((t) {
      final d = parseTaskDate(t['time']?.toString());
      if (d == null) return false;
      return !d.isBefore(periodStart) && !d.isAfter(periodEnd);
    }).toList();

    inPeriod.sort((a, b) {
      final da = parseTaskDate(a['time']?.toString());
      final db = parseTaskDate(b['time']?.toString());
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });

    final total = inPeriod.length;
    final done = inPeriod.where((t) => t['completed'] == true).length;
    final active = total - done;

    String equipmentName(String? id) {
      if (id == null) return '—';
      final e = equipment.firstWhere((e) => e['id'] == id, orElse: () => {});
      return (e['name'] ?? '—').toString();
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 2, color: PdfColors.green900),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Завод-Механик',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.Text(
                  'Сформирован: ${dateFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Период: ${dateFmt.format(periodStart)} — ${dateFmt.format(periodEnd)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard('Всего задач', '$total'),
              pw.SizedBox(width: 8),
              _summaryCard('Выполнено', '$done', color: PdfColors.green700),
              pw.SizedBox(width: 8),
              _summaryCard('В работе', '$active', color: PdfColors.orange700),
            ],
          ),
          pw.SizedBox(height: 20),
          if (inPeriod.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 20),
              child: pw.Center(
                child: pw.Text(
                  'За выбранный период задач нет',
                  style: const pw.TextStyle(color: PdfColors.grey600),
                ),
              ),
            )
          else ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 22, child: _cell('№', bold: true)),
                  pw.SizedBox(width: 62, child: _cell('Дата', bold: true)),
                  pw.Expanded(flex: 3, child: _cell('Задача', bold: true)),
                  pw.Expanded(
                    flex: 2,
                    child: _cell('Оборудование', bold: true),
                  ),
                  pw.SizedBox(width: 62, child: _cell('Статус', bold: true)),
                ],
              ),
            ),
            ...inPeriod.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              final date = parseTaskDate(t['time']?.toString());
              final isDone = t['completed'] == true;
              final comments = (t['comments'] as List?) ?? [];

              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 8,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(width: 22, child: _cell('${i + 1}')),
                        pw.SizedBox(
                          width: 62,
                          child: _cell(
                            date == null ? '—' : dateFmt.format(date),
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: _cell(t['title']?.toString() ?? ''),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: _cell(
                            equipmentName(t['equipmentId'] as String?),
                          ),
                        ),
                        pw.SizedBox(
                          width: 62,
                          child: pw.Text(
                            isDone ? 'Готово' : 'В работе',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: isDone
                                  ? PdfColors.green700
                                  : PdfColors.orange700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 84, top: 2),
                      child: pw.Text(
                        '${t['category']}  •  ${t['priority']}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                    if (comments.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 84, top: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: comments.map<pw.Widget>((c) {
                            return pw.Text(
                              '• ${c['text']}',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey800,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Подпись механика: _______________________',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: '$title.pdf',
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  static pw.Widget _summaryCard(String label, String value, {PdfColor? color}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: color ?? PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
