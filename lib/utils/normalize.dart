const _noise = <String>{
  'г', 'гор', 'город', 'обл', 'область', 'респ', 'республика', 'край',
  'р', 'он', 'рн', 'район', 'районе', 'мр', 'мо', 'го', 'мкр', 'микрорайон',
  'ул', 'улица', 'пер', 'переулок', 'пл', 'площадь', 'ш', 'шоссе', 'пр',
  'проспект', 'просп', 'б', 'бр', 'бульвар', 'наб', 'проезд', 'тракт',
  'д', 'дом', 'дома', 'зд', 'здание', 'стр', 'строение', 'корп', 'к',
  'литер', 'лит', 'пом', 'помещ', 'помещение', 'оф', 'офис',
  'з', 'у', 'зу', 'уч', 'участок',
  'с', 'село', 'п', 'пос', 'посёлок', 'поселок', 'рп', 'пгт', 'ст', 'сл',
  'вн', 'тер', 'внтерг', 'муниципальный', 'округ', 'федерального', 'значения',
  'в', 'на', 'при', 'номер', 'no',
};

String _clean(String input) {
  var s = input.toLowerCase().replaceAll('ё', 'е');
  s = s.replaceAll(RegExp(r'[«»"""\(\)\[\]]'), ' ');
  s = s.replaceAll(RegExp(r'[.,;:/\\|№#]'), ' ');
  s = s.replaceAll('-', ' ');
  s = s.replaceAll(RegExp(r'[\s\u00A0\u202F]+'), ' ');
  return s.trim();
}

String stripStoreWord(String name) =>
    name.replaceAll(RegExp(r'^\s*магазин\s*', caseSensitive: false), '').trim();

List<String> tokenize(String input) {
  final out = <String>[];
  for (final raw in _clean(input).split(' ')) {
    if (raw.isEmpty) continue;
    if (_noise.contains(raw)) continue;
    if (RegExp(r'^\d{6}$').hasMatch(raw)) continue;
    out.add(raw);
  }
  return out;
}

String keyOf(String input) => tokenize(input).join(' ');

bool _isNumeric(String t) => RegExp(r'\d').hasMatch(t);

double similarity(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;

  final sa = a.toSet();
  final sb = b.toSet();
  final inter = sa.intersection(sb);
  final minSize = sa.length < sb.length ? sa.length : sb.length;

  final coverage = inter.length / minSize;

  final na = sa.where(_isNumeric).toSet();
  final nb = sb.where(_isNumeric).toSet();
  double numbers;
  if (na.isEmpty && nb.isEmpty) {
    numbers = 0.6;
  } else if (na.isEmpty || nb.isEmpty) {
    numbers = 0.3;
  } else {
    final ni = na.intersection(nb);
    final minNum = na.length < nb.length ? na.length : nb.length;
    numbers = ni.isEmpty ? 0.0 : ni.length / minNum;
  }

  return 0.55 * coverage + 0.45 * numbers;
}