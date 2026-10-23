import 'dart:convert';
import 'doc_store.dart';
import 'players.dart';
import 'quiz_model.dart';

/// Mistakes notebook: quiz questions the child got wrong, kept per child until answered right.
/// Kept in memory (call [load] once for the active child), saved on every change.
class Mistakes {
  static const int _max = 100;
  static String _pid = '';
  static List<({String setId, QuizQuestion q})> _items = <({String setId, QuizQuestion q})>[];

  static String get _key => 'mistakes_${PlayerStore.active.id}';

  /// Mistakes of the active child (empty until [load] has run for this child).
  static List<({String setId, QuizQuestion q})> get items => _pid == PlayerStore.active.id ? _items : <({String setId, QuizQuestion q})>[];

  static int get count => items.length;

  static Future<void> load() async {
    final pid = PlayerStore.active.id;
    final kv = await AppKV.open();
    final raw = kv.getString('mistakes_$pid');
    final out = <({String setId, QuizQuestion q})>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = json.decode(raw);
        if (data is List) {
          for (final e in data) {
            if (e is Map && e['q'] is Map) {
              out.add((setId: (e['set'] ?? '').toString(), q: QuizQuestion.fromJson(Map<String, dynamic>.from(e['q'] as Map))));
            }
          }
        }
      } catch (_) {}
    }
    _items = out;
    _pid = pid;
  }

  static Future<void> _save() async {
    final kv = await AppKV.open();
    await kv.setString(_key, json.encode(<Map<String, dynamic>>[for (final i in _items) <String, dynamic>{'set': i.setId, 'q': i.q.toJson()}]));
  }

  static Future<void> add(String setId, QuizQuestion q) async {
    if (_pid != PlayerStore.active.id) await load();
    if (_items.any((i) => i.q.question == q.question)) return;
    _items.add((setId: setId, q: q));
    if (_items.length > _max) _items = _items.sublist(_items.length - _max);
    await _save();
  }

  static Future<void> remove(QuizQuestion q) async {
    if (_pid != PlayerStore.active.id) await load();
    final before = _items.length;
    _items.removeWhere((i) => i.q.question == q.question);
    if (_items.length != before) await _save();
  }
}
