import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models.dart';
import '../utils/number_parse.dart';
import 'dart:convert';

class TaxcomParseResult {
  TaxcomParseResult({
    required this.entries,
    required this.sheetName,
    required this.storeColumn,
    required this.amountColumn,
    required this.amountColumnTitle,
    required this.skipped,
  });

  final List<SourceEntry> entries;
  final String sheetName;
  final int storeColumn;
  final int amountColumn;
  final String amountColumnTitle;
  final List<String> skipped;

  double get total => entries.fold(0.0, (s, e) => s + e.amount);

  String get columnsHint =>
      'Лист «$sheetName», магазин — столбец ${_letter(storeColumn)}, '
      'сумма — столбец ${_letter(amountColumn)} ($amountColumnTitle)';

  static String _letter(int index) {
    var i = index;
    var out = '';
    do {
      out = String.fromCharCode(65 + (i % 26)) + out;
      i = i ~/ 26 - 1;
    } while (i >= 0);
    return out;
  }
}

class TaxcomParser {
  static const _storeHeaders = ['торговая точка', 'подразделение'];

  TaxcomParseResult parse(String path) {
    final bytes = File(path).readAsBytesSync();
    print('📁 Файл загружен: ${bytes.length} байт');

    final Map<String, List<int>> files = {};
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive) {
        if (!f.isFile) continue;
        final content = f.content;
        if (content == null) continue;
        files[f.name] = content is List<int>
            ? content
            : List<int>.from(content as List);
      }
      print('📦 Распакован xlsx: ${files.length} файлов внутри');
      print('   Файлы: ${files.keys.toList()}');
    } catch (e) {
      print('❌ Ошибка при распаковке: $e');
      throw const FormatException(
        'Файл не удалось прочитать как xlsx (архив повреждён или это старый .xls). '
        'Пересохраните в .xlsx.',
      );
    }

    final sharedStrings = _readSharedStrings(files['xl/sharedStrings.xml']);
    print('📝 Общие строки (shared strings): ${sharedStrings.length} элементов');
    print('   Первые 5: ${sharedStrings.take(5).toList()}');

    final sheetPaths = files.keys
        .where((k) => k.startsWith('xl/worksheets/') && k.endsWith('.xml'))
        .toList()
      ..sort(_naturalOrder);
    print('📄 Листы найдены: $sheetPaths');

    if (sheetPaths.isEmpty) {
      throw const FormatException('В файле не найден ни один лист с данными');
    }

    final namesByPath = _sheetNames(files);
    print('📋 Названия листов: $namesByPath');

    for (final sf in sheetPaths) {
      print('\n🔍 Проверяю лист: $sf');
      final data = files[sf];
      if (data == null) {
        print('   ⚠️ Данные листа == null, пропускаю');
        continue;
      }
      
      final rows = _readRows(data, sharedStrings);
      print('   ✓ Прочитано строк: ${rows.length}');
      if (rows.isNotEmpty) {
        print('   Первая строка (0): ${rows[0].take(5).toList()}...');
      }

      final header = _findHeader(rows);
      if (header == null) {
        print('   ⚠️ Шапка не найдена на этом листе, пропускаю');
        continue;
      }
      print('   ✅ Шапка найдена на строке ${header.row}');
      print('   Содержимое шапки: ${header.cells}');

      final storeCol = _columnByHeaders(header.cells, _storeHeaders);
      final amountCol = _amountColumn(header.cells, 'выручка');
      print('   Колонка магазина: $storeCol (${storeCol != null ? header.cells[storeCol] : 'не найдена'})');
      print('   Колонка выручки: $amountCol (${amountCol != null ? header.cells[amountCol] : 'не найдена'})');

      if (storeCol == null || amountCol == null) {
        print('   ⚠️ Колонки не найдены, пропускаю этот лист');
        continue;
      }

      final entries = <SourceEntry>[];
      final skipped = <String>[];

      for (var i = header.row + 1; i < rows.length; i++) {
        final row = rows[i];
        final label = storeCol < row.length ? row[storeCol] : '';
        if (label.isEmpty) continue;
        if (label.toLowerCase().startsWith('итог')) {
          print('   ⏭️ Строка $i — «$label» (пропускаю итог)');
          continue;
        }

        final amountText = amountCol < row.length ? row[amountCol] : '';
        final amount = parseAmount(amountText);
        if (amount == null) {
          skipped.add('$label — сумма «$amountText» не распознана');
          print('   ⚠️ Строка $i — «$label» × «$amountText» — не парсится');
          continue;
        }
        entries.add(SourceEntry(label: label, amount: amount));
        print('   ✓ Строка $i — «$label»: $amount ₽');
      }

      print('\n📊 Итого найдено: ${entries.length} магазинов, ${skipped.length} ошибок');

      if (entries.isEmpty) {
        throw const FormatException('После шапки не нашлось ни одной строки с выручкой');
      }

      return TaxcomParseResult(
        entries: entries,
        sheetName: namesByPath[sf] ?? sf,
        storeColumn: storeCol,
        amountColumn: amountCol,
        amountColumnTitle: header.cells[amountCol],
        skipped: skipped,
      );
    }

    throw const FormatException('Не нашёл лист со столбцами «Торговая точка» и «Выручка»');
  }

  static int _naturalOrder(String a, String b) {
    final ma = RegExp(r'sheet(\d+)', caseSensitive: false).firstMatch(a);
    final mb = RegExp(r'sheet(\d+)', caseSensitive: false).firstMatch(b);
    final ia = ma == null ? 0 : int.tryParse(ma.group(1)!) ?? 0;
    final ib = mb == null ? 0 : int.tryParse(mb.group(1)!) ?? 0;
    return ia.compareTo(ib);
  }

      static Map<String, String> _sheetNames(Map<String, List<int>> files) {
        final out = <String, String>{};
        final wb = files['xl/workbook.xml'];
        if (wb == null) return out;

        final rels = files['xl/_rels/workbook.xml.rels'];
        final relMap = <String, String>{};
        if (rels != null) {
          try {
            for (final r in XmlDocument.parse(
                    utf8.decode(rels, allowMalformed: true))
                .findAllElements('Relationship', namespace: '*')) {
              final id = r.getAttribute('Id');
              var target = r.getAttribute('Target') ?? '';
              if (id == null) continue;
              target = target.replaceFirst(RegExp(r'^/?xl/'), '');
              relMap[id] = 'xl/$target';
            }
          } catch (e) {
            print('❌ rels: $e');
          }
        }

        try {
          var idx = 1;
          for (final s in XmlDocument.parse(utf8.decode(wb, allowMalformed: true))
              .findAllElements('sheet', namespace: '*')) {
            final name = s.getAttribute('name') ?? 'Лист$idx';
            final rid = s.getAttribute('r:id') ?? s.getAttribute('id');
            final path = relMap[rid] ?? 'xl/worksheets/sheet$idx.xml';
            out[path] = name;
            idx++;
          }
        } catch (e) {
          print('❌ workbook: $e');
        }
        return out;
      }

      static List<String> _readSharedStrings(List<int>? data) {
        if (data == null) return const [];
        try {
          final doc = XmlDocument.parse(utf8.decode(data, allowMalformed: true));
          return doc
              .findAllElements('si', namespace: '*')
              .map((si) => si
                  .findAllElements('t', namespace: '*')
                  .map((t) => t.innerText)
                  .join())
              .toList();
        } catch (e) {
          print('❌ sharedStrings: $e');
          return const [];
        }
      }
      static List<List<String>> _readRows(List<int> data, List<String> shared) {
        try {
          final doc = XmlDocument.parse(utf8.decode(data, allowMalformed: true));
          final rows = <List<String>>[];

          for (final row in doc.findAllElements('row', namespace: '*')) {
            final cells = <int, String>{};
            var maxCol = -1;

            for (final c in row.findAllElements('c', namespace: '*')) {
              final col = _colIdx(c.getAttribute('r') ?? '');
              if (col < 0) continue;

              final type = c.getAttribute('t');
              String val;
              if (type == 'inlineStr') {
                val = c
                    .findAllElements('t', namespace: '*')
                    .map((t) => t.innerText)
                    .join();
              } else {
                final v = c.getElement('v', namespace: '*')?.innerText ?? '';
                if (type == 's') {
                  final i = int.tryParse(v);
                  val = (i != null && i < shared.length) ? shared[i] : '';
                } else {
                  val = v;
                }
              }

              cells[col] = val.trim();
              if (col > maxCol) maxCol = col;
            }

            rows.add(List.generate(maxCol + 1, (i) => cells[i] ?? ''));
          }
          return rows;
        } catch (e) {
          print('❌ Лист: $e');
          return [];
        }
      }

  static int _colIdx(String ref) {
    var n = 0;
    for (var i = 0; i < ref.length; i++) {
      final ch = ref.codeUnitAt(i);
      if (ch >= 65 && ch <= 90) {
        n = n * 26 + (ch - 64);
      } else if (ch >= 97 && ch <= 122) {
        n = n * 26 + (ch - 96);
      } else {
        break;
      }
    }
    return n - 1;
  }

  static _HeaderRow? _findHeader(List<List<String>> rows) {
    for (var i = 0; i < rows.length && i < 60; i++) {
      final texts = rows[i].map((c) => c.toLowerCase()).toList();
      final hasStore = texts.any((t) => _storeHeaders.contains(t));
      final hasAmount = texts.any((t) => t == 'выручка');
      if (hasStore && hasAmount) return _HeaderRow(i, rows[i]);
    }
    return null;
  }

  static int? _columnByHeaders(List<String> cells, List<String> candidates) {
    for (final candidate in candidates) {
      for (var i = 0; i < cells.length; i++) {
        if (cells[i].toLowerCase() == candidate) return i;
      }
    }
    return null;
  }

  static int? _amountColumn(List<String> cells, String header) {
    final needle = header.toLowerCase().trim();
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].toLowerCase() == needle) return i;
    }
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].toLowerCase().startsWith(needle)) return i;
    }
    return null;
  }
}

class _HeaderRow {
  _HeaderRow(this.row, this.cells);
  final int row;
  final List<String> cells;
}