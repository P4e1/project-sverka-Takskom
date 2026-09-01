import 'package:intl/intl.dart';

final _fmt = NumberFormat('#,##0.00', 'ru_RU');

String formatMoney(double? value) => value == null ? '—' : _fmt.format(value);

double? parseAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
  s = s.replaceAll(RegExp(r'(₽|руб\.?|р\.)$', caseSensitive: false), '');
  final negative = s.startsWith('-') || (s.startsWith('(') && s.endsWith(')'));
  s = s.replaceAll(RegExp(r'[()+\-]'), '');
  if (s.isEmpty) return null;
  final hasComma = s.contains(',');
  final hasDot = s.contains('.');
  if (hasComma && hasDot) {
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (hasComma) {
    s = s.replaceAll(',', '.');
  }
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;
  final value = double.tryParse(s);
  if (value == null) return null;
  return negative ? -value : value;
}

bool looksLikeAmount(String raw) => parseAmount(raw) != null;