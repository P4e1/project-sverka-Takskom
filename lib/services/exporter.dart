import 'dart:convert';
import 'dart:io';

import '../models.dart';

class ExportService {
  Future<void> saveXlsx({
    required String path,
    required ReconSummary summary,
    required double tolerance,
    String? taxcomFileName,
  }) async {
    final buf = StringBuffer();
    buf.writeln('Сверка розничных продаж');
    buf.writeln(
        'Дата;${DateTime.now().toString().substring(0, 19)}');
    buf.writeln('Источник;${taxcomFileName ?? "—"}');
    buf.writeln('Допуск ₽;$tolerance');
    buf.writeln();
    buf.writeln(
        'Магазин;Таксском;1С;Расхождение;Статус;Сопоставление');

    for (final row in summary.rows) {
      buf.writeln([
        _esc(row.storeName),
        row.taxcomAmount?.toStringAsFixed(2) ?? '',
        row.onecAmount?.toStringAsFixed(2) ?? '',
        row.diff.toStringAsFixed(2),
        row.status.title,
        row.matchKind.title,
      ].join(';'));
    }

    buf.writeln();
    buf.writeln(
        'Итого;${summary.taxcomTotal.toStringAsFixed(2)};'
        '${summary.onecTotal.toStringAsFixed(2)};'
        '${summary.totalDiff.toStringAsFixed(2)}');

    final target =
        path.endsWith('.csv') ? path : '$path.csv';
    final bytes = [
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(buf.toString())
    ];
    await File(target).writeAsBytes(bytes);
  }

  String _esc(String s) =>
      '"${s.replaceAll('"', '""')}"';
}