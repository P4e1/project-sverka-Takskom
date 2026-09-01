import '../models.dart';
import '../utils/number_parse.dart';

enum PasteMode { pairs, amountsOnly }

class PasteParseResult {
  PasteParseResult({
    required this.entries,
    required this.amounts,
    required this.problems,
  });
  final List<SourceEntry> entries;
  final List<double> amounts;
  final List<String> problems;
}

class OnecPasteParser {
  PasteParseResult parse(String raw, PasteMode mode) {
    final entries = <SourceEntry>[];
    final amounts = <double>[];
    final problems = <String>[];

    final lines = raw.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (mode == PasteMode.amountsOnly) {
        final amount = parseAmount(line);
        if (amount == null) {
          problems.add('Строка ${i + 1}: «$line» — не число');
          continue;
        }
        amounts.add(amount);
        continue;
      }

      final cells = _split(line);
      double? amount;
      var amountIdx = -1;
      for (var j = cells.length - 1; j >= 0; j--) {
        final v = parseAmount(cells[j]);
        if (v != null) {
          amount = v;
          amountIdx = j;
          break;
        }
      }
      if (amount == null) {
        problems.add('Строка ${i + 1}: не нашёл сумму');
        continue;
      }

      final name = cells
          .sublist(0, amountIdx)
          .where((c) => c.trim().isNotEmpty)
          .join(' ')
          .trim();
      if (name.isEmpty) {
        problems.add('Строка ${i + 1}: сумма без названия');
        continue;
      }
      final low = name.toLowerCase();
      if (low.startsWith('итог') || low.startsWith('всего')) continue;

      entries.add(SourceEntry(label: name, amount: amount));
    }

    return PasteParseResult(
      entries: entries,
      amounts: amounts,
      problems: problems,
    );
  }

  List<String> _split(String line) {
    if (line.contains('\t')) return line.split('\t');
    if (line.contains(';')) return line.split(';');
    if (RegExp(r'\s{2,}').hasMatch(line)) {
      return line.split(RegExp(r'\s{2,}'));
    }
    final m = RegExp(r'^(.*?)([\d\s\u00A0.,]+)$').firstMatch(line);
    if (m != null) {
      final name = m.group(1)!.trim();
      final tail = m.group(2)!.trim();
      if (name.isNotEmpty && parseAmount(tail) != null) {
        return [name, tail];
      }
    }
    return [line];
  }
    PasteParseResult parseTwoColumns(String names, String amounts) {
    final nameLines = names
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final amountLines = amounts
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final entries = <SourceEntry>[];
    final problems = <String>[];
    final count = nameLines.length < amountLines.length
        ? nameLines.length
        : amountLines.length;

    for (var i = 0; i < count; i++) {
      final name = nameLines[i];
      final low = name.toLowerCase();
      if (low.startsWith('итог') || low.startsWith('всего')) continue;

      final amount = parseAmount(amountLines[i]);
      if (amount == null) {
        problems.add('Строка ${i + 1}: «${amountLines[i]}» — не число');
        continue;
      }
      entries.add(SourceEntry(label: name, amount: amount));
    }

    if (nameLines.length != amountLines.length) {
      problems.insert(
        0,
        'Названий: ${nameLines.length}, сумм: ${amountLines.length} — строки не совпадают',
      );
    }

    return PasteParseResult(entries: entries, amounts: [], problems: problems);
  }
}