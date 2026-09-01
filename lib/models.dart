import '../utils/normalize.dart';

class Store {
  Store({required this.name, required this.address})
      : nameTokens = tokenize(stripStoreWord(name)),
        addressTokens = tokenize(address),
        nameKey = keyOf(stripStoreWord(name)),
        addressKey = keyOf(address);

  final String name;
  final String address;
  final List<String> nameTokens;
  final List<String> addressTokens;
  final String nameKey;
  final String addressKey;

  Map<String, dynamic> toJson() => {'name': name, 'address': address};

  factory Store.fromJson(Map<String, dynamic> json) =>
      Store(name: json['name'] as String, address: json['address'] as String? ?? '');
}

class SourceEntry {
  SourceEntry({required this.label, required this.amount, this.extra});
  final String label;
  final double amount;
  final String? extra;
}

enum ReconStatus { ok, mismatch, missingInOnec, missingInTaxcom, unresolved }

extension ReconStatusInfo on ReconStatus {
  String get title => switch (this) {
        ReconStatus.ok => 'Совпадает',
        ReconStatus.mismatch => 'Расхождение',
        ReconStatus.missingInOnec => 'Нет в 1С',
        ReconStatus.missingInTaxcom => 'Нет в Такском',
        ReconStatus.unresolved => 'Не сопоставлено',
      };
}

enum MatchKind { alias, exact, auto, ambiguous, none }

extension MatchKindInfo on MatchKind {
  String get title => switch (this) {
        MatchKind.alias => 'связка сохранена',
        MatchKind.exact => 'точное совпадение',
        MatchKind.auto => 'подобрано автоматически',
        MatchKind.ambiguous => 'несколько вариантов',
        MatchKind.none => 'не найдено',
      };
}

class MatchCandidate {
  MatchCandidate(this.store, this.score);
  final Store store;
  final double score;
}

class ReconRow {
  ReconRow({
    required this.storeName,
    required this.status,
    required this.taxcomAmount,
    required this.onecAmount,
    required this.taxcomLabels,
    required this.onecLabels,
    this.matchKind = MatchKind.exact,
    this.candidates = const [],
    this.unresolvedLabel,
  });

  final String storeName;
  final ReconStatus status;
  final double? taxcomAmount;
  final double? onecAmount;
  final List<String> taxcomLabels;
  final List<String> onecLabels;
  final MatchKind matchKind;
  final List<MatchCandidate> candidates;
  final String? unresolvedLabel;

  double get diff => (taxcomAmount ?? 0) - (onecAmount ?? 0);
}

class ReconSummary {
  ReconSummary({
    required this.rows,
    required this.taxcomTotal,
    required this.onecTotal,
    required this.okCount,
    required this.mismatchCount,
    required this.missingCount,
    required this.unresolvedCount,
  });

  final List<ReconRow> rows;
  final double taxcomTotal;
  final double onecTotal;
  final int okCount;
  final int mismatchCount;
  final int missingCount;
  final int unresolvedCount;

  double get totalDiff => taxcomTotal - onecTotal;

  static ReconSummary empty() => ReconSummary(
        rows: const [],
        taxcomTotal: 0,
        onecTotal: 0,
        okCount: 0,
        mismatchCount: 0,
        missingCount: 0,
        unresolvedCount: 0,
      );
}