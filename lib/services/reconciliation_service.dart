import '../models.dart';
import '../utils/normalize.dart';
import 'store_directory.dart';

String aliasKeyFor(String label) => keyOf(label);

class ReconciliationService {
  ReconSummary run({
    required List<SourceEntry> taxcom,
    required List<SourceEntry> onec,
    required StoreDirectory directory,
    required Map<String, String> aliases,
    required double tolerance,
  }) {
    final taxcomByStore = <String, _Bucket>{};
    final onecByStore = <String, _Bucket>{};
    final unresolved = <ReconRow>[];

    void collect(
        List<SourceEntry> entries, Map<String, _Bucket> target, bool isTaxcom) {
      for (final entry in entries) {
        final res = _resolve(entry.label, directory, aliases);
        if (res.store == null) {
          unresolved.add(ReconRow(
            storeName: entry.label,
            status: ReconStatus.unresolved,
            taxcomAmount: isTaxcom ? entry.amount : null,
            onecAmount: isTaxcom ? null : entry.amount,
            taxcomLabels: isTaxcom ? [entry.label] : const [],
            onecLabels: isTaxcom ? const [] : [entry.label],
            matchKind: res.kind,
            candidates: res.candidates,
            unresolvedLabel: entry.label,
          ));
          continue;
        }
        final bucket =
            target.putIfAbsent(res.store!.name, () => _Bucket());
        bucket.amount += entry.amount;
        bucket.labels.add(entry.label);
        if (_kindOrder(res.kind) > _kindOrder(bucket.kind)) {
          bucket.kind = res.kind;
        }
      }
    }

    collect(taxcom, taxcomByStore, true);
    collect(onec, onecByStore, false);

    final names = <String>{...taxcomByStore.keys, ...onecByStore.keys}.toList()
      ..sort();
    final rows = <ReconRow>[];

    for (final name in names) {
      final t = taxcomByStore[name];
      final o = onecByStore[name];
      final ReconStatus status;
      if (t == null) {
        status = ReconStatus.missingInTaxcom;
      } else if (o == null) {
        status = ReconStatus.missingInOnec;
      } else if ((t.amount - o.amount).abs() <= tolerance) {
        status = ReconStatus.ok;
      } else {
        status = ReconStatus.mismatch;
      }
      rows.add(ReconRow(
        storeName: name,
        status: status,
        taxcomAmount: t?.amount,
        onecAmount: o?.amount,
        taxcomLabels: t?.labels.toList() ?? const [],
        onecLabels: o?.labels.toList() ?? const [],
        matchKind: _weakest(
            t?.kind ?? MatchKind.exact, o?.kind ?? MatchKind.exact),
      ));
    }

    rows.sort((a, b) {
      int rank(ReconRow r) => switch (r.status) {
            ReconStatus.mismatch => 0,
            ReconStatus.unresolved => 1,
            ReconStatus.missingInOnec => 2,
            ReconStatus.missingInTaxcom => 3,
            ReconStatus.ok => 4,
          };
      return rank(a).compareTo(rank(b));
    });

    final all = [...rows, ...unresolved];
    return ReconSummary(
      rows: all,
      taxcomTotal: taxcom.fold(0.0, (s, e) => s + e.amount),
      onecTotal: onec.fold(0.0, (s, e) => s + e.amount),
      okCount: all.where((r) => r.status == ReconStatus.ok).length,
      mismatchCount:
          all.where((r) => r.status == ReconStatus.mismatch).length,
      missingCount: all
          .where((r) =>
              r.status == ReconStatus.missingInOnec ||
              r.status == ReconStatus.missingInTaxcom)
          .length,
      unresolvedCount:
          all.where((r) => r.status == ReconStatus.unresolved).length,
    );
  }

  List<SourceEntry> pairByOrder(
      List<SourceEntry> taxcom, List<double> amounts) {
    final result = <SourceEntry>[];
    for (var i = 0; i < amounts.length && i < taxcom.length; i++) {
      result.add(SourceEntry(label: taxcom[i].label, amount: amounts[i]));
    }
    return result;
  }

    _Resolution _resolve(
      String label, StoreDirectory dir, Map<String, String> aliases) {
    final key = keyOf(label);

    final aliasTarget = aliases[key];
    if (aliasTarget != null) {
      final store = dir.links.where((s) => s.name == aliasTarget).firstOrNull;
      if (store != null) {
        return _Resolution(kind: MatchKind.alias, store: store);
      }
    }

    final byAddr = dir.byAddress(label);
    if (byAddr != null) {
      return _Resolution(kind: MatchKind.exact, store: byAddr);
    }
    final byName = dir.byName(label);
    if (byName != null) {
      return _Resolution(kind: MatchKind.exact, store: byName);
    }

    final tokens = tokenize(label);
    final scored = <MatchCandidate>[];
    for (final s in dir.links) {
      final score = [
        similarity(tokens, s.addressTokens),
        similarity(tokens, s.nameTokens),
      ].reduce((a, b) => a > b ? a : b);
      if (score >= 0.45) scored.add(MatchCandidate(s, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(6).toList();

    print('🔎 «$label»');
    print('   ключ=«$key» токены=$tokens');
    if (top.isEmpty) {
      print('   нет кандидатов выше 0.45');
    } else {
      for (final c in top.take(3)) {
        print('   ${c.score.toStringAsFixed(3)} → «${c.store.name}»');
      }
    }

    if (top.isEmpty) return _Resolution(kind: MatchKind.none);
    final best = top.first;
    final gap = top.length > 1 ? best.score - top[1].score : 1.0;
    if (best.score >= 0.75 && gap >= 0.08) {
      return _Resolution(
          kind: MatchKind.auto, store: best.store, candidates: top);
    }
    return _Resolution(kind: MatchKind.ambiguous, candidates: top);
  }

  int _kindOrder(MatchKind k) => [
        MatchKind.exact,
        MatchKind.alias,
        MatchKind.auto,
        MatchKind.ambiguous,
        MatchKind.none
      ].indexOf(k);

  MatchKind _weakest(MatchKind a, MatchKind b) =>
      _kindOrder(a) >= _kindOrder(b) ? a : b;
}

class _Bucket {
  double amount = 0;
  final Set<String> labels = {};
  MatchKind kind = MatchKind.exact;
}

class _Resolution {
  _Resolution(
      {required this.kind,
      this.store,
      this.candidates = const []});
  final MatchKind kind;
  final Store? store;
  final List<MatchCandidate> candidates;
}