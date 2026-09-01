import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StorageService {
  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
        '${base.path}${Platform.pathSeparator}sales_recon');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<File> _file(String name) async {
    final dir = await _ensureDir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  Future<Map<String, dynamic>?> readJson(String name) async {
    final file = await _file(name);
    if (!file.existsSync()) return null;
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(
      String name, Map<String, dynamic> data) async {
    final file = await _file(name);
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data));
  }
}