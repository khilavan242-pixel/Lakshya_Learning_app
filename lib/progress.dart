import 'package:flutter/foundation.dart';
import 'doc_store.dart';

/// Stars, day streak and what the child did today (per player).
///   star   = one answer that was right at the first try without help
///   streak = days in a row with at least [dayGoal] answers
/// Saved in <Documents>/KidsSuperApp/players/progress_<id>.json
class Progress {
  Progress._();

  static const int dayGoal = 3; // answers that count a day for the streak
  static const int stepGoal = 5; // answers that complete one step of Today's Mission

  /// Changes whenever something is recorded (screens listen to refresh).
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  static String _pid = '';
  static int _stars = 0;
  static Map<String, Map<String, int>> _days = <String, Map<String, int>>{};
  static Future<void> _saving = Future<void>.value();

  static String _two(int n) => n < 10 ? '0$n' : '$n';
  static String _dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static Future<void> load(String playerId) async {
    _pid = playerId;
    _stars = 0;
    _days = <String, Map<String, int>>{};
    try {
      final raw = await DocStore.readJson('players', 'progress_$playerId.json');
      if (raw is Map) {
        final s = raw['stars'];
        if (s is num) _stars = s.toInt();
        final d = raw['days'];
        if (d is Map) {
          d.forEach((dynamic k, dynamic v) {
            if (v is Map) {
              _days['$k'] = <String, int>{for (final e in v.entries) '${e.key}': (e.value is num) ? (e.value as num).toInt() : 0};
            }
          });
        }
      }
    } catch (_) {}
    changed.value++;
  }

  /// mode: 'spell' | 'math' | 'quiz' | 'learn'
  static void note(String mode, bool clean) {
    if (_pid.isEmpty) return;
    final day = _days.putIfAbsent(_dayKey(DateTime.now()), () => <String, int>{});
    day[mode] = (day[mode] ?? 0) + 1;
    if (clean) _stars++;
    // keep about two months
    if (_days.length > 70) {
      final keys = _days.keys.toList()..sort();
      for (final k in keys.take(_days.length - 60)) {
        _days.remove(k);
      }
    }
    _save();
    changed.value++;
  }

  static int get stars => _stars;

  static int today(String mode) => _days[_dayKey(DateTime.now())]?[mode] ?? 0;

  static int get todayTotal {
    final d = _days[_dayKey(DateTime.now())];
    if (d == null) return 0;
    return d.values.fold<int>(0, (int a, int b) => a + b);
  }

  static int _total(DateTime d) {
    final m = _days[_dayKey(d)];
    if (m == null) return 0;
    return m.values.fold<int>(0, (int a, int b) => a + b);
  }

  /// Days in a row. Today counts once it reaches the goal; until then yesterday keeps the streak alive.
  static int get streak {
    var d = DateTime.now();
    if (_total(d) < dayGoal) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (_total(d) >= dayGoal) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Answers for each of the last 7 days, oldest first.
  static List<int> get lastWeek {
    final now = DateTime.now();
    return <int>[for (var i = 6; i >= 0; i--) _total(now.subtract(Duration(days: i)))];
  }

  static String modeOfKey(String key) {
    if (key.startsWith('spell:')) return 'spell';
    if (key.startsWith('quiz:')) return 'quiz';
    return 'learn';
  }

  static Future<void> deleteFor(String id) => DocStore.deleteFile('players', 'progress_$id.json');

  static void _save() {
    final id = _pid;
    if (id.isEmpty) return;
    final snapshot = <String, dynamic>{'stars': _stars, 'days': _days.map((String k, Map<String, int> v) => MapEntry<String, dynamic>(k, Map<String, int>.from(v)))};
    _saving = _saving.then((_) => DocStore.writeJson('players', 'progress_$id.json', snapshot)).catchError((Object e) {});
  }
}
