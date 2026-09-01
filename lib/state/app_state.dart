import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/exporter.dart';
import '../services/onec_paste_parser.dart';
import '../services/reconciliation_service.dart';
import '../services/storage_service.dart';
import '../services/store_directory.dart';
import '../services/taxcom_parser.dart';
import '../utils/normalize.dart';

class AppState extends ChangeNotifier {
  final _storage = StorageService();
  final _taxcomParser = TaxcomParser();
  final _pasteParser = OnecPasteParser();
  final _recon = ReconciliationService();
  final _export = ExportService();

  String _namesText = '';
  String _amountsText = '';

  List<Store> _stores = [];
  final Map<String, String> _aliases = {};
  String? _directoryPath;

  List<SourceEntry> _taxcom = [];
  String? _taxcomPath;
  String? _taxcomHint;
  List<String> _taxcomWarnings = [];

  List<SourceEntry> _onec = [];
  String _pasteText = '';
  PasteMode _pasteMode = PasteMode.pairs;
  List<String> _pasteProblems = [];

  double _tolerance = 0.01;
  ReconSummary _summary = ReconSummary.empty();
  String? _error;
  bool _busy = false;

  List<Store> get stores => _stores;
  Map<String, String> get aliases => Map.unmodifiable(_aliases);
  String? get directoryPath => _directoryPath;
  List<SourceEntry> get taxcom => _taxcom;
  String? get taxcomPath => _taxcomPath;
  String? get taxcomHint => _taxcomHint;
  List<String> get taxcomWarnings => _taxcomWarnings;
  List<SourceEntry> get onec => _onec;
  String get pasteText => _pasteText;
  PasteMode get pasteMode => _pasteMode;
  List<String> get pasteProblems => _pasteProblems;
  double get tolerance => _tolerance;
  ReconSummary get summary => _summary;
  String? get error => _error;
  bool get busy => _busy;

  bool get directoryReady => _stores.isNotEmpty;
  bool get taxcomReady => _taxcom.isNotEmpty;
  bool get onecReady => _onec.isNotEmpty;
  bool get canReconcile => directoryReady && taxcomReady && onecReady;

  double get taxcomTotal => _taxcom.fold(0.0, (s, e) => s + e.amount);
  double get onecTotal => _onec.fold(0.0, (s, e) => s + e.amount);

  StoreDirectory get _directory => StoreDirectory(_stores);

  Future<void> restore() async {
    final dir = await _storage.readJson('directory.json');
    if (dir != null) {
      _directoryPath = dir['path'] as String?;
      _stores = (dir['stores'] as List? ?? [])
          .map((e) => Store.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final al = await _storage.readJson('aliases.json');
    if (al != null) {
      for (final e in (al['items'] as Map? ?? {}).entries) {
        _aliases[e.key as String] = e.value as String;
      }
    }
        print('📚 Справочник: ${_stores.length} записей');
    for (final s in _stores.take(8)) {
      print('   name=«${s.name}»');
      print('   addr=«${s.address}»');
      print('   nameKey=«${s.nameKey}» | addressKey=«${s.addressKey}»');
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadDirectory(String path) => _guard(() async {
        final dir = StoreDirectory.fromXlsx(path);
        
        _stores = dir.links;
                print('📚 Справочник: ${_stores.length} записей');
        for (final s in _stores.take(5)) {
          print('   «${s.name}» | «${s.address}»');
          print('     nameKey=«${s.nameKey}» addressKey=«${s.addressKey}»');
        }
        _directoryPath = path;
        await _storage.writeJson('directory.json', {
          'path': path,
          'stores': _stores.map((s) => s.toJson()).toList(),
        });
        _recompute();
      });

  Future<void> loadTaxcom(String path) => _guard(() async {
        final result = _taxcomParser.parse(path);
        _taxcom = result.entries;
        _taxcomPath = path;
        _taxcomHint = result.columnsHint;
        _taxcomWarnings = result.skipped;
        _recompute();
      });

  void setPasteMode(PasteMode mode) {
    _pasteMode = mode;
    applyPaste(_pasteText);
  }

  void applyPaste(String text) {
    _pasteText = text;
    if (text.trim().isEmpty) {
      _onec = [];
      _pasteProblems = [];
      _recompute();
      return;
    }
    final result = _pasteParser.parse(text, _pasteMode);
    _pasteProblems = result.problems;
    _onec = _pasteMode == PasteMode.pairs
        ? result.entries
        : _recon.pairByOrder(_taxcom, result.amounts);
    _recompute();
  }

  void setTolerance(double value) {
    _tolerance = value < 0 ? 0 : value;
    _recompute();
  }

  Future<void> addAlias(String label, String storeName) => _guard(() async {
        _aliases[aliasKeyFor(label)] = storeName;
        await _storage.writeJson('aliases.json', {'items': _aliases});
        _recompute();
      });

  Future<void> exportCsv(String path) => _guard(() async {
        await _export.saveXlsx(
          path: path,
          summary: _summary,
          tolerance: _tolerance,
          taxcomFileName: _taxcomPath,
        );
      });

    void applyTwoColumn(String names, String amounts) {
    _namesText = names;
    _amountsText = amounts;

    if (names.trim().isEmpty && amounts.trim().isEmpty) {
      _onec = [];
      _pasteProblems = [];
      _recompute();
      return;
    }

    final result = _pasteParser.parseTwoColumns(names, amounts);
    _pasteProblems = result.problems;
    _onec = result.entries;
    _recompute();
  }

  String get namesText => _namesText;
  String get amountsText => _amountsText;

  void _recompute() {
    if (!canReconcile) {
      _summary = ReconSummary.empty();
      notifyListeners();
      return;
    }
        print('═══ СПРАВОЧНИК (${_stores.length}) ═══');
    for (final s in _stores) {
      print('   «${s.name}» → nameKey=«${s.nameKey}»');
    }
    print('═══ 1С (${_onec.length}) ═══');
    final dirKeys = {for (final s in _stores) s.nameKey: s.name};
    for (final e in _onec) {
      final k = keyOf(stripStoreWord(e.label));
      final hit = dirKeys[k];
      print('   «${e.label}» → «$k» ${hit == null ? "✗ МИМО" : "✓ $hit"}');
    }
    _summary = _recon.run(
      taxcom: _taxcom,
      onec: _onec,
      directory: _directory,
      aliases: _aliases,
      tolerance: _tolerance,
    );
    notifyListeners();
  }

  Future<void> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      _error = e is FormatException ? e.message : e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}