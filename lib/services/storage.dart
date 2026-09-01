import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'store_directory.dart';

/// Локальное хранилище: кэш справочника + ручные привязки. Никакой сети.
class LocalStore {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/store_links.json');
  }

  static Future<({StoreDirectory? directory, Map<String, String> aliases})> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return (directory: null, aliases: <String, String>{});
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final dir = j['directory'] == null
          ? null
          : StoreDirectory.fromJson(j['directory'] as List<dynamic>);
      final aliases = Map<String, String>.from(
          (j['aliases'] as Map?)?.cast<String, String>() ?? {});
      return (directory: dir, aliases: aliases);
    } catch (_) {
      return (directory: null, aliases: <String, String>{});
    }
  }

  static Future<void> save({
    StoreDirectory? directory,
    required Map<String, String> aliases,
  }) async {
    final f = await _file();
    await f.writeAsString(jsonEncode({
      'directory': directory?.toJson(),
      'aliases': aliases,
    }));
  }

  static Future<String> location() async => (await _file()).path;
}