import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models.dart';
import '../utils/normalize.dart';
import 'dart:convert';

class StoreDirectory {
  final List<Store> links;
  final Map<String, Store> _byAddressKey = {};
  final Map<String, Store> _byNameKey = {};

  StoreDirectory(this.links) {
    for (final s in links) {
      _byAddressKey.putIfAbsent(s.addressKey, () => s);
      _byNameKey.putIfAbsent(s.nameKey, () => s);
    }
  }

  bool get isEmpty => links.isEmpty;

  Store? byAddress(String address) =>
      _byAddressKey[keyOf(address)];

  Store? byName(String name) =>
      _byNameKey[keyOf(stripStoreWord(name))];

  List<Map<String, dynamic>> toJson() =>
      links.map((s) => s.toJson()).toList();

  static StoreDirectory fromJson(List<dynamic> raw) => StoreDirectory(
        raw
            .map((e) =>
                Store.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static StoreDirectory fromXlsx(String path) {
    final bytes = File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, List<int>>{};
    for (final f in archive) {
      if (f.isFile) files[f.name] = f.content as List<int>;
    }

    final shared = _sharedStrings(files['xl/sharedStrings.xml']);
    final sheetMap = _workbook(files);
    if (sheetMap.isEmpty) throw const FormatException('В файле нет листов');

    final sheetPath = sheetMap.values.first;
    final sheetData = files[sheetPath];
    if (sheetData == null) {
      throw const FormatException('Не удалось прочитать лист');
    }

    final rows = _sheet(sheetData, shared);
    final out = <Store>[];
    for (final row in rows) {
      final name = row.isNotEmpty ? row[0].trim() : '';
      final address = row.length > 1 ? row[1].trim() : '';
      if (name.isEmpty || address.isEmpty) continue;
      final nl = name.toLowerCase();
      if (nl == 'магазин' || nl == 'наименование') continue;
      out.add(Store(name: name, address: address));
    }
    if (out.isEmpty) throw const FormatException('Справочник пуст');
    out.sort((a, b) => a.name.compareTo(b.name));
    return StoreDirectory(out);
  }

  static List<String> _sharedStrings(List<int>? data) {
    if (data == null) return const [];
    try {
      return XmlDocument.parse(utf8.decode(data, allowMalformed: true))
          .findAllElements('si', namespace: '*')
          .map((si) =>
              si.findAllElements('t', namespace: '*').map((t) => t.innerText).join())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, String> _workbook(Map<String, List<int>> files) {
    final wb = files['xl/workbook.xml'];
    final rels = files['xl/_rels/workbook.xml.rels'];
    final out = <String, String>{};
    if (wb == null) return out;
    final relMap = <String, String>{};
    if (rels != null) {
      try {
        for (final r in XmlDocument.parse(utf8.decode(rels, allowMalformed: true))
            .findAllElements('Relationship', namespace: '*')) {
          final id = r.getAttribute('Id');
          var target = r.getAttribute('Target') ?? '';
          if (id == null) continue;
          target = target.replaceFirst(RegExp(r'^/?xl/'), '');
          relMap[id] = 'xl/$target';
        }
      } catch (_) {}
    }
    try {
      var idx = 1;
      for (final s in XmlDocument.parse(utf8.decode(wb, allowMalformed: true))
          .findAllElements('sheet', namespace: '*')) {
        final name = s.getAttribute('name') ?? 'Лист$idx';
        final rid = s.getAttribute('r:id') ?? s.getAttribute('id');
        out[name] = relMap[rid] ?? 'xl/worksheets/sheet$idx.xml';
        idx++;
      }
    } catch (_) {}
    return out;
  }

  static List<List<String>> _sheet(
      List<int> data, List<String> shared) {
    try {
      final rows = <List<String>>[];
      for (final row in XmlDocument.parse(utf8.decode(data, allowMalformed: true))
          .findAllElements('row', namespace: '*')) {
        final cells = <int, String>{};
        var maxCol = -1;
        for (final c in row.findAllElements('c', namespace: '*')) {
          final col = _colIdx(c.getAttribute('r') ?? '');
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
        rows.add(
            List.generate(maxCol + 1, (i) => cells[i] ?? ''));
      }
      return rows;
    } catch (_) {
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
}