import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_location.dart';

/// Every game saves its data as plain JSON files in the folder chosen in
/// Settings > Storage location (default: Documents/KidsSuperApp on the TV):
///   data/app_kv.json         settings + spelling cards
///   quizzes/<id>.json        one file per quiz set
///   quiz/progress.json       best scores
///   math/profiles.json       children
///   math/progress.json       maths report card
///   photos/                  spelling card photos
class DocStore {
  DocStore._();
  static Directory? _root;

  static Future<Directory> root() async {
    final cached = _root;
    if (cached != null) return cached;
    final d = await StorageLocation.rootDir(); // Documents/KidsSuperApp by default
    _root = d;
    return d;
  }

  static Future<Directory> folder(String name) async {
    final r = await root();
    final d = Directory('${r.path}/$name');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<dynamic> readJson(String folderName, String fileName) async {
    try {
      final d = await folder(folderName);
      final f = File('${d.path}/$fileName');
      if (!await f.exists()) return null;
      return json.decode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Writes to a temp file first, then renames, so a power-cut can't corrupt the data.
  static Future<void> writeJson(String folderName, String fileName, Object data) async {
    final d = await folder(folderName);
    final tmp = File('${d.path}/$fileName.tmp');
    await tmp.writeAsString(json.encode(data), flush: true);
    await tmp.rename('${d.path}/$fileName');
  }

  static Future<void> deleteFile(String folderName, String fileName) async {
    try {
      final d = await folder(folderName);
      final f = File('${d.path}/$fileName');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<List<File>> listJsonFiles(String folderName) async {
    final d = await folder(folderName);
    final out = <File>[];
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith('.json')) out.add(e);
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }
}

/// Drop-in replacement for SharedPreferences that keeps everything in
/// <Documents>/KidsSuperApp/data/app_kv.json. On the first run it copies
/// your old SharedPreferences data (spelling cards, settings) across.
class AppKV {
  AppKV._(this._data);
  final Map<String, dynamic> _data;
  static AppKV? _inst;
  static Future<AppKV>? _opening;
  Future<void> _saving = Future<void>.value();

  static Future<AppKV> open() {
    final existing = _inst;
    if (existing != null) return Future<AppKV>.value(existing);
    final pending = _opening;
    if (pending != null) return pending;
    final created = _load();
    _opening = created;
    return created;
  }

  static Future<AppKV> _load() async {
    final raw = await DocStore.readJson('data', 'app_kv.json');
    Map<String, dynamic> data = <String, dynamic>{};
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else {
      try {
        final p = await SharedPreferences.getInstance();
        for (final k in p.getKeys()) {
          final v = p.get(k);
          if (v is String || v is bool || v is int || v is double) {
            data[k] = v;
          } else if (v is List) {
            data[k] = v.map((e) => e.toString()).toList();
          }
        }
      } catch (_) {}
      try {
        await DocStore.writeJson('data', 'app_kv.json', data);
      } catch (_) {}
    }
    final kv = AppKV._(data);
    _inst = kv;
    return kv;
  }

  bool containsKey(String key) => _data.containsKey(key);

  bool? getBool(String key) {
    final v = _data[key];
    return v is bool ? v : null;
  }

  String? getString(String key) {
    final v = _data[key];
    return v is String ? v : null;
  }

  List<String>? getStringList(String key) {
    final v = _data[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    return null;
  }

  Future<void> setBool(String key, bool v) => _set(key, v);
  Future<void> setString(String key, String v) => _set(key, v);
  Future<void> setStringList(String key, List<String> v) => _set(key, List<String>.from(v));

  Future<void> remove(String key) async {
    _data.remove(key);
    await _save();
  }

  Future<void> _set(String key, Object v) async {
    _data[key] = v;
    await _save();
  }

  Future<void> _save() {
    _saving = _saving.then((_) => DocStore.writeJson('data', 'app_kv.json', _data)).catchError((Object e) {});
    return _saving;
  }
}
