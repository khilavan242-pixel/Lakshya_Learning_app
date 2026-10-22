import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'math_data.dart';
import 'players.dart';
import 'progress.dart';
import 'speech_service.dart';

// ======================================================================
// MATHS GAME  (grades, topics, math test, daily challenge, report card,
// players, settings)  - data saved in <Documents>/KidsSuperApp
// ======================================================================


class MathEngine {
  final math.Random rnd;
  final int optionCount;
  MathEngine(this.rnd, this.optionCount);

  int _r(int lo, int hi) => lo + rnd.nextInt(hi - lo + 1); // inclusive

  String _wordsEn(String e) {
    return e
        .replaceAll('+', ' plus ')
        .replaceAll('−', ' minus ')
        .replaceAll('×', ' times ')
        .replaceAll('÷', ' divided by ')
        .replaceAll('/', ' over ')
        .replaceAll('=', ' equals ')
        .replaceAll('?', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _wordsHi(String e) {
    return e
        .replaceAll('+', ' जोड़ ')
        .replaceAll('−', ' घटा ')
        .replaceAll('×', ' गुणा ')
        .replaceAll('÷', ' भाग ')
        .replaceAll('/', ' बटा ')
        .replaceAll('=', ' बराबर ')
        .replaceAll('?', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Options for a whole-number answer (works for any formatter).
  List<String> _intOptions(int ans, {String Function(int)? fmt}) {
    final f = fmt ?? (int v) => v.toString();
    final set = <int>{ans};
    final spread = math.max(3, (ans.abs() / 5).ceil());
    var tries = 0;
    while (set.length < optionCount && tries < 400) {
      tries++;
      final c = ans + rnd.nextInt(spread * 2 + 1) - spread;
      if (ans >= 0 && c < 0) continue;
      set.add(c);
    }
    var k = 1;
    while (set.length < optionCount) {
      set.add(ans + k);
      k++;
    }
    final list = set.map(f).toList();
    list.shuffle(rnd);
    return list;
  }

  /// Options built from an answer + hand-made wrong answers (padded if needed).
  List<String> _strOptions(String ans, List<String> wrongs, {String Function()? filler}) {
    final set = <String>{ans};
    final pool = List<String>.from(wrongs)..shuffle(rnd);
    for (final w in pool) {
      if (set.length >= optionCount) break;
      set.add(w);
    }
    var tries = 0;
    while (filler != null && set.length < optionCount && tries < 100) {
      tries++;
      set.add(filler());
    }
    final list = set.toList();
    list.shuffle(rnd);
    return list;
  }

  String _fmtTenths(int v) => (v / 10).toStringAsFixed(1);

  MathQuestion _expr(String topic, String expr, String answer, List<String> options) {
    return MathQuestion(
      topicId: topic,
      text: '$expr = ?',
      spokenEn: 'What is ${_wordsEn(expr)}?',
      spokenHi: '${_wordsHi(expr)} कितना होता है?',
      answer: answer,
      options: options,
    );
  }

  MathQuestion make(String topic, int grade) {
    final int g = grade.clamp(0, 6).toInt();
    switch (topic) {
      case 'counting':
        return _counting(g);
      case 'addition':
        return _addition(g);
      case 'subtraction':
        return _subtraction(g);
      case 'multiplication':
        return _multiplication(g);
      case 'division':
        return _division(g);
      case 'fractions':
        return _fractions(g);
      case 'time':
        return _time(g);
      case 'decimals':
        return _decimals(g);
      case 'squareroot':
        return _squareRoot(g);
      case 'exponents':
        return _exponents(g);
      case 'algebra':
        return _algebra(g);
      case 'mixed':
        return _mixed(g);
      case 'fun':
        return _fun(g);
      case 'geometry':
        return _geometry(g);
      case 'percentage':
        return _percentage(g);
    }
    return _addition(g);
  }

  MathQuestion _counting(int g) {
    final n = _r(1, g == 0 ? 10 : 20);
    const emojis = <String>['🍎', '⭐', '🐟', '🎈', '🐥', '🌸', '🚗', '🦋'];
    final e = emojis[rnd.nextInt(emojis.length)];
    return MathQuestion(
      topicId: 'counting',
      text: 'How many?',
      spokenEn: 'How many are there?',
      spokenHi: 'कितने हैं?',
      answer: n.toString(),
      options: _intOptions(n),
      emoji: e,
      emojiCount: n,
    );
  }

  MathQuestion _addition(int g) {
    const hi = <int>[5, 10, 50, 500, 5000, 20000, 50000];
    final a = _r(1, hi[g]);
    final b = _r(1, hi[g]);
    return _expr('addition', '$a + $b', (a + b).toString(), _intOptions(a + b));
  }

  MathQuestion _subtraction(int g) {
    const hi = <int>[5, 10, 50, 500, 5000, 20000, 50000];
    final a = _r(1, hi[g]);
    final b = _r(0, a);
    return _expr('subtraction', '$a − $b', (a - b).toString(), _intOptions(a - b));
  }

  MathQuestion _multiplication(int g) {
    const aLo = <int>[1, 1, 2, 2, 10, 10, 100];
    const aHi = <int>[3, 5, 5, 10, 99, 99, 999];
    const bLo = <int>[1, 1, 1, 2, 2, 10, 2];
    const bHi = <int>[3, 5, 10, 10, 9, 30, 12];
    final a = _r(aLo[g], aHi[g]);
    final b = _r(bLo[g], bHi[g]);
    return _expr('multiplication', '$a × $b', (a * b).toString(), _intOptions(a * b));
  }

  MathQuestion _division(int g) {
    const dHi = <int>[2, 3, 5, 10, 10, 12, 15];
    const qHi = <int>[5, 5, 10, 10, 20, 30, 50];
    final b = _r(2, math.max(2, dHi[g]));
    final q = _r(1, qHi[g]);
    return _expr('division', '${b * q} ÷ $b', q.toString(), _intOptions(q));
  }

  MathQuestion _fractions(int g) {
    String filler() => '${_r(1, 9)}/${_r(2, 10)}';
    if (g >= 5 && rnd.nextInt(3) == 0) {
      // simplify
      const simple = <List<int>>[
        [1, 2], [1, 3], [2, 3], [1, 4], [3, 4], [1, 5], [2, 5], [3, 5], [1, 6], [5, 6]
      ];
      final s = simple[rnd.nextInt(simple.length)];
      final m = _r(2, 6);
      final ans = '${s[0]}/${s[1]}';
      return MathQuestion(
        topicId: 'fractions',
        text: '${s[0] * m}/${s[1] * m} = ? (simplest form)',
        spokenEn: 'Write ${s[0] * m} over ${s[1] * m} in simplest form.',
        spokenHi: '${s[0] * m} बटा ${s[1] * m} को सरलतम रूप में लिखिए।',
        answer: ans,
        options: _strOptions(ans, <String>['${s[1]}/${s[0]}', '${s[0]}/${s[1] + 1}', '${s[0] + 1}/${s[1]}', '${s[0] * m}/${s[1]}', '${s[0]}/${s[1] * m}'], filler: filler),
      );
    }
    final d = _r(3, g <= 3 ? 8 : 12);
    final subtract = g >= 4 && rnd.nextBool();
    if (subtract) {
      final n1 = _r(2, d - 1);
      final n2 = _r(1, n1 - 1);
      final ans = '${n1 - n2}/$d';
      return _expr('fractions', '$n1/$d − $n2/$d', ans, _strOptions(ans, <String>['${n1 - n2 + 1}/$d', '${math.max(1, n1 - n2 - 1)}/$d', '${n1 - n2}/${d + 1}', '${n1 + n2}/$d', '${n1 - n2}/${d * 2}'], filler: filler));
    }
    final n1 = _r(1, d - 2);
    final n2 = _r(1, d - n1 - 1);
    final ans = '${n1 + n2}/$d';
    return _expr('fractions', '$n1/$d + $n2/$d', ans, _strOptions(ans, <String>['${n1 + n2 + 1}/$d', '${n1 + n2 - 1}/$d', '${n1 + n2}/${d + 1}', '${n1 + n2}/${d * 2}', '${n1 * n2}/$d'], filler: filler));
  }

  MathQuestion _time(int g) {
    final h = _r(1, 12);
    int m;
    if (g == 0) {
      m = 0;
    } else if (g == 1) {
      m = rnd.nextBool() ? 0 : 30;
    } else {
      m = _r(0, 11) * 5;
    }
    String fmt(int hh, int mm) => '$hh:${mm.toString().padLeft(2, '0')}';
    final ans = fmt(h, m);
    final set = <String>{ans};
    var tries = 0;
    while (set.length < optionCount && tries < 200) {
      tries++;
      final hh = ((h - 1 + _r(-2, 2)) % 12 + 12) % 12 + 1;
      final mm = g <= 1 ? (rnd.nextBool() ? 0 : 30) : _r(0, 11) * 5;
      set.add(fmt(hh, mm));
    }
    var k = 1;
    while (set.length < optionCount) {
      set.add(fmt(((h - 1 + k) % 12) + 1, m));
      k++;
    }
    final list = set.toList();
    list.shuffle(rnd);
    return MathQuestion(
      topicId: 'time',
      text: 'What time is it?',
      spokenEn: 'What time is shown on the clock?',
      spokenHi: 'घड़ी में कितने बजे हैं?',
      answer: ans,
      options: list,
      clockHour: h,
      clockMinute: m,
    );
  }

  MathQuestion _decimals(int g) {
    const hi = <int>[20, 30, 50, 50, 100, 200, 500];
    final a = _r(1, hi[g]);
    final b = _r(1, hi[g]);
    if (rnd.nextBool()) {
      return _expr('decimals', '${_fmtTenths(a)} + ${_fmtTenths(b)}', _fmtTenths(a + b), _intOptions(a + b, fmt: _fmtTenths));
    }
    final big = math.max(a, b);
    final small = math.min(a, b);
    return _expr('decimals', '${_fmtTenths(big)} − ${_fmtTenths(small)}', _fmtTenths(big - small), _intOptions(big - small, fmt: _fmtTenths));
  }

  MathQuestion _squareRoot(int g) {
    final r = _r(2, g <= 5 ? 12 : 20);
    return MathQuestion(
      topicId: 'squareroot',
      text: '√${r * r} = ?',
      spokenEn: 'What is the square root of ${r * r}?',
      spokenHi: '${r * r} का वर्गमूल क्या है?',
      answer: r.toString(),
      options: _intOptions(r),
    );
  }

  String _sup(int n) {
    const map = <String, String>{'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'};
    return n.toString().split('').map((String c) => map[c] ?? c).join();
  }

  MathQuestion _exponents(int g) {
    final base = _r(2, g <= 5 ? 5 : 9);
    final exp = _r(2, g <= 5 ? 3 : 4);
    var v = 1;
    for (var i = 0; i < exp; i++) {
      v *= base;
    }
    return MathQuestion(
      topicId: 'exponents',
      text: '$base${_sup(exp)} = ?',
      spokenEn: '$base to the power $exp equals what?',
      spokenHi: '$base की घात $exp का मान क्या है?',
      answer: v.toString(),
      options: _intOptions(v),
    );
  }

  MathQuestion _algebra(int g) {
    final x = _r(1, 12);
    final kind = rnd.nextInt(3);
    String eq;
    if (kind == 0) {
      final a = _r(1, 20);
      eq = 'x + $a = ${x + a}';
    } else if (kind == 1) {
      final a = _r(1, x);
      eq = 'x − $a = ${x - a}';
    } else {
      final a = _r(2, 9);
      eq = '${a}x = ${a * x}';
    }
    return MathQuestion(
      topicId: 'algebra',
      text: '$eq,  x = ?',
      spokenEn: 'If ${_wordsEn(eq)}, what is x?',
      spokenHi: 'यदि ${_wordsHi(eq)} है, तो x का मान क्या है?',
      answer: x.toString(),
      options: _intOptions(x),
    );
  }

  MathQuestion _mixed(int g) {
    if (g >= 4 && rnd.nextInt(3) == 0) {
      final a = _r(2, 20);
      final b = _r(2, 9);
      final c = _r(2, 9);
      return _expr('mixed', '$a + $b × $c', (a + b * c).toString(), _intOptions(a + b * c));
    }
    const ops = <String>['addition', 'subtraction', 'multiplication', 'division'];
    final op = ops[rnd.nextInt(g <= 1 ? 2 : 4)];
    return make(op, g).withTopic('mixed');
  }

  MathQuestion _fun(int g) {
    if (rnd.nextBool()) {
      final step = _r(1, g <= 1 ? 3 : (g <= 3 ? 10 : 25));
      final start = _r(0, 20);
      final missing = _r(1, 3);
      final terms = <int>[for (var i = 0; i < 5; i++) start + step * i];
      final ans = terms[missing];
      final shown = <String>[for (var i = 0; i < 5; i++) i == missing ? '__' : terms[i].toString()];
      return MathQuestion(
        topicId: 'fun',
        text: shown.join(',  '),
        spokenEn: 'Which number is missing in the pattern?',
        spokenHi: 'पैटर्न में कौन सी संख्या छूट गई है?',
        answer: ans.toString(),
        options: _intOptions(ans),
      );
    }
    final n = _r(2, g <= 1 ? 30 : 500);
    if (rnd.nextBool()) {
      return MathQuestion(
        topicId: 'fun',
        text: 'What comes after $n ?',
        spokenEn: 'What number comes after $n?',
        spokenHi: '$n के बाद कौन सी संख्या आती है?',
        answer: (n + 1).toString(),
        options: _intOptions(n + 1),
      );
    }
    return MathQuestion(
      topicId: 'fun',
      text: 'What comes before $n ?',
      spokenEn: 'What number comes before $n?',
      spokenHi: '$n से पहले कौन सी संख्या आती है?',
      answer: (n - 1).toString(),
      options: _intOptions(n - 1),
    );
  }

  MathQuestion _bank(String q, String hi, String ans, List<String> wrongs) {
    return MathQuestion(
      topicId: 'geometry',
      text: q,
      spokenEn: q,
      spokenHi: hi,
      answer: ans,
      options: _strOptions(ans, wrongs, filler: () => (_r(2, 12)).toString()),
    );
  }

  MathQuestion _geometry(int g) {
    if (g >= 4) {
      final kind = rnd.nextInt(3);
      if (kind == 0) {
        final a = _r(30, 80);
        final b = _r(30, 80);
        return MathQuestion(
          topicId: 'geometry',
          text: 'Two angles of a triangle are $a° and $b°. The third angle = ?',
          spokenEn: 'Two angles of a triangle are $a degrees and $b degrees. What is the third angle?',
          spokenHi: 'एक त्रिभुज के दो कोण $a डिग्री और $b डिग्री हैं। तीसरा कोण कितना है?',
          answer: '${180 - a - b}°',
          options: _intOptions(180 - a - b, fmt: (int v) => '$v°'),
        );
      }
      final l = _r(3, 15);
      final w = _r(2, 12);
      if (kind == 1) {
        return MathQuestion(
          topicId: 'geometry',
          text: 'Perimeter of a rectangle: length $l, width $w = ?',
          spokenEn: 'What is the perimeter of a rectangle with length $l and width $w?',
          spokenHi: 'लंबाई $l और चौड़ाई $w वाले आयत का परिमाप कितना है?',
          answer: (2 * (l + w)).toString(),
          options: _intOptions(2 * (l + w)),
        );
      }
      return MathQuestion(
        topicId: 'geometry',
        text: 'Area of a rectangle: length $l, width $w = ?',
        spokenEn: 'What is the area of a rectangle with length $l and width $w?',
        spokenHi: 'लंबाई $l और चौड़ाई $w वाले आयत का क्षेत्रफल कितना है?',
        answer: (l * w).toString(),
        options: _intOptions(l * w),
      );
    }
    final easy = <MathQuestion Function()>[
      () => _bank('How many sides does a triangle have?', 'त्रिभुज की कितनी भुजाएँ होती हैं?', '3', <String>['2', '4', '5', '6', '1']),
      () => _bank('How many corners does a square have?', 'वर्ग के कितने कोने होते हैं?', '4', <String>['3', '5', '6', '2', '8']),
      () => _bank('Which shape is perfectly round?', 'कौन सी आकृति पूरी गोल है?', 'Circle', <String>['Square', 'Triangle', 'Rectangle', 'Star', 'Diamond']),
      () => _bank('Which shape has 3 corners?', 'किस आकृति के 3 कोने होते हैं?', 'Triangle', <String>['Circle', 'Square', 'Rectangle', 'Oval', 'Star']),
      () => _bank('How many sides does a pentagon have?', 'पंचभुज की कितनी भुजाएँ होती हैं?', '5', <String>['3', '4', '6', '7', '8']),
      () => _bank('How many sides does a hexagon have?', 'षट्भुज की कितनी भुजाएँ होती हैं?', '6', <String>['4', '5', '7', '8', '3']),
      () => _bank('Which shape has 4 equal sides?', 'किस आकृति की चारों भुजाएँ बराबर होती हैं?', 'Square', <String>['Triangle', 'Circle', 'Oval', 'Pentagon', 'Star']),
      () => _bank('How many faces does a cube have?', 'घन के कितने फलक होते हैं?', '6', <String>['4', '5', '8', '12', '3']),
      () => _bank('How many degrees is a right angle?', 'समकोण कितने डिग्री का होता है?', '90', <String>['45', '60', '180', '100', '30']),
      () => _bank('How many sides does an octagon have?', 'अष्टभुज की कितनी भुजाएँ होती हैं?', '8', <String>['6', '7', '9', '10', '5']),
    ];
    final pool = g <= 1 ? easy.sublist(0, 7) : easy;
    return pool[rnd.nextInt(pool.length)]();
  }

  MathQuestion _percentage(int g) {
    final ps = g <= 4 ? <int>[10, 20, 25, 50, 75] : <int>[5, 10, 15, 20, 25, 30, 40, 50, 60, 75, 80, 90];
    final p = ps[rnd.nextInt(ps.length)];
    final n = 20 * _r(1, 10);
    final ans = p * n ~/ 100;
    return MathQuestion(
      topicId: 'percentage',
      text: 'What is $p% of $n ?',
      spokenEn: 'What is $p percent of $n?',
      spokenHi: '$n का $p प्रतिशत कितना होता है?',
      answer: ans.toString(),
      options: _intOptions(ans),
    );
  }
}

// ----------------------------------------------------------------------
// STORAGE: maths report card (per player). Settings live in PlayerStore.
// ----------------------------------------------------------------------
class MathStore {
  static Map<String, dynamic> progress = <String, dynamic>{};

  static Player get _p => PlayerStore.active;

  // ---- settings of the active player (saved by PlayerStore) ----
  static bool get sound => _p.sound;
  static set sound(bool v) {
    _p.sound = v;
    PlayerStore.save();
  }

  static bool get autoSpeak => _p.speak;
  static set autoSpeak(bool v) {
    _p.speak = v;
    PlayerStore.save();
  }

  static bool get retries => _p.retries;
  static set retries(bool v) {
    _p.retries = v;
    PlayerStore.save();
  }

  static bool get hints => _p.hints;
  static bool get smart => _p.smart;

  static int get optionCount => _p.options;
  static set optionCount(int v) {
    _p.options = v;
    PlayerStore.save();
  }

  static int get questionCount => _p.rounds;
  static set questionCount(int v) {
    _p.rounds = v;
    PlayerStore.save();
  }

  static String get lang => _p.lang;
  static set lang(String v) {
    _p.lang = v;
    PlayerStore.save();
  }

  static int get lastGrade => _p.grade;
  static set lastGrade(int v) {
    _p.grade = v;
    PlayerStore.save();
  }

  static String get activeId => PlayerStore.activeId;
  static String get activeName => _p.name;

  /// Keeps only the topics this child is allowed to play (falls back to all).
  static List<String> allowedTopicIds(Iterable<String> ids) {
    final allowed = _p.mathTopics;
    final list = ids.toList();
    if (allowed == null) return list;
    final filtered = list.where((String t) => allowed.contains(t)).toList();
    return filtered.isEmpty ? list : filtered;
  }

  static Future<void> init() async {
    final prog = await DocStore.readJson('math', 'progress.json');
    if (prog is Map) progress = Map<String, dynamic>.from(prog);
  }

  // Old call sites: settings are now saved automatically by the setters above.
  static Future<void> saveSetting(String key, String value) async {}
  static Future<void> saveBool(String key, bool value) async {}

  static Future<void> _saveProgress() => DocStore.writeJson('math', 'progress.json', progress);

  static Map<String, dynamic> _childData() {
    final existing = progress[activeId];
    if (existing is Map<String, dynamic>) return existing;
    final created = <String, dynamic>{};
    progress[activeId] = created;
    return created;
  }

  static Map<String, dynamic> topicStats(String topicId) {
    final data = _childData();
    final t = data[topicId];
    if (t is Map) return Map<String, dynamic>.from(t);
    return <String, dynamic>{'a': 0, 'c': 0, 's': 0};
  }

  static Future<void> recordAnswer(String topicId, bool correct) async {
    final data = _childData();
    final t = topicStats(topicId);
    t['a'] = ((t['a'] ?? 0) as num).toInt() + 1;
    if (correct) t['c'] = ((t['c'] ?? 0) as num).toInt() + 1;
    data[topicId] = t;
    Progress.note('math', correct);
    await _saveProgress();
  }

  static Future<void> recordStars(String topicId, int stars) async {
    final data = _childData();
    final t = topicStats(topicId);
    if (stars > ((t['s'] ?? 0) as num).toInt()) t['s'] = stars;
    data[topicId] = t;
    await _saveProgress();
  }

  static String _dayKey(DateTime n) =>
      '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';

  static String todayKey() => _dayKey(DateTime.now());

  static Map<String, dynamic> daily() {
    final data = _childData();
    final d = data['_daily'];
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{'last': '', 'streak': 0};
  }

  static bool dailyDoneToday() => daily()['last'] == todayKey();

  static Future<void> markDailyDone() async {
    final data = _childData();
    final d = daily();
    final today = todayKey();
    if (d['last'] == today) return;
    final yKey = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final streak = d['last'] == yKey ? ((d['streak'] ?? 0) as num).toInt() + 1 : 1;
    data['_daily'] = <String, dynamic>{'last': today, 'streak': streak};
    await _saveProgress();
  }

  static Future<void> resetActiveProgress() async {
    progress.remove(activeId);
    await _saveProgress();
  }
}

void _mathSfx(bool good) {
  if (!MathStore.sound) return;
  if (good) {
    GameAudioService.instance.playSuccessFanfare();
  } else {
    GameAudioService.instance.playErrorFeedback();
  }
}

// ----------------------------------------------------------------------
// HOME OF THE MATHS GAME
// ----------------------------------------------------------------------
class MathHomeScreen extends StatefulWidget {
  const MathHomeScreen({super.key});
  @override
  State<MathHomeScreen> createState() => _MathHomeScreenState();
}

class _MathHomeScreenState extends State<MathHomeScreen> {
  int _tab = 0; // 0 = grades, 1 = topics
  late int _grade = MathStore.lastGrade.clamp(0, 6).toInt();

  void _setGrade(int g) {
    setState(() => _grade = g);
    MathStore.lastGrade = g;
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) {
      setState(() {
        _grade = MathStore.lastGrade.clamp(0, 6).toInt();
      });
    }
  }

  void _play(String topicId, String mode) {
    _open(MathPlayScreen(topicId: topicId, grade: _grade, mode: mode));
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final baseIds = _tab == 0 ? (kGradeTopics[_grade] ?? <String>[]) : kMathTopics.map((MathTopic t) => t.id).toList();
    final topicIds = MathStore.allowedTopicIds(baseIds);

    final tiles = <Widget Function(double, double)>[];
    for (var i = 0; i < topicIds.length; i++) {
      final t = mathTopicById(topicIds[i]);
      final stats = MathStore.topicStats(t.id);
      final stars = ((stats['s'] ?? 0) as num).toInt();
      final index = i;
      tiles.add((double w, double h) => BigTile(
            emoji: t.emoji,
            title: t.name,
            subtitle: stars > 0 ? '⭐' * stars : null,
            colors: t.colors,
            s: s,
            width: w / s,
            height: h / s,
            autofocus: index == 0,
            onPressed: () => _play(t.id, 'practice'),
          ));
    }

    final gradeChips = <Widget>[];
    for (var g = 0; g < kGradeNames.length; g++) {
      final index = g;
      gradeChips.add(ChoiceChipTV(label: g == 0 ? 'K' : 'G${kGradeShort[g]}', selected: g == _grade, s: s, onPressed: () => _setGrade(index)));
    }

    return ScreenFrame(
      title: '🧮 Math Games',
      actions: [
        ActionButton(
          s: s,
          icon: Icons.face_rounded,
          label: '${PlayerStore.active.emoji} ${MathStore.activeName}',
          color: const Color(0xFF26A69A),
          onPressed: () => _open(const PlayersScreen()),
        ),
        SizedBox(width: 12 * s),
        ActionButton(
          s: s,
          icon: Icons.folder_open_rounded,
          label: 'Organize',
          color: const Color(0xFF8E24AA),
          onPressed: () => _open(const LibraryManagerScreen()),
        ),
        SizedBox(width: 12 * s),
        ActionButton(
          s: s,
          icon: Icons.settings_rounded,
          color: const Color(0xFF78909C),
          onPressed: () => _open(const PlayerSettingsScreen(home: true)),
        ),
      ],
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChipTV(label: 'GRADES', selected: _tab == 0, s: s, onPressed: () => setState(() => _tab = 0)),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: ChoiceChipTV(label: 'TOPICS', selected: _tab == 1, s: s, onPressed: () => setState(() => _tab = 1)),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10 * s,
            runSpacing: 6 * s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(kGradeNames[_grade], style: kidText(22 * s)),
              ...gradeChips,
            ],
          ),
          Expanded(child: AdaptiveGrid(builders: tiles, aspect: 1.3, minWidth: 130 * s, maxWidth: 230 * s, gap: 14 * s)),
          ButtonRow(
            alignment: WrapAlignment.center,
            spacing: 14 * s,
            runSpacing: 8 * s,
            children: [
              ActionButton(
                s: s,
                icon: Icons.psychology_rounded,
                label: 'Smart Practice${MathReview.count > 0 ? ' (${MathReview.count})' : ''}',
                color: const Color(0xFF00897B),
                onPressed: () => _play('', 'smart'),
              ),
              ActionButton(
                s: s,
                icon: Icons.calendar_month_rounded,
                label: MathStore.dailyDoneToday() ? 'Daily ✓' : 'Daily Challenge',
                color: const Color(0xFF3949AB),
                onPressed: () => _play('', 'daily'),
              ),
              ActionButton(
                s: s,
                icon: Icons.assignment_rounded,
                label: 'Math Test',
                color: const Color(0xFF8E24AA),
                onPressed: () => _play('', 'test'),
              ),
              ActionButton(
                s: s,
                icon: Icons.emoji_events_rounded,
                label: 'Report Card',
                color: const Color(0xFFF57C00),
                onPressed: () => _open(const MathReportScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// PLAY SCREEN  (modes: practice | test | daily | smart)
// Wrong answers and hints are remembered: the question comes back a few
// questions later, and again in Smart Practice, until it is answered
// correctly twice in a row.
// ----------------------------------------------------------------------
class MathPlayScreen extends StatefulWidget {
  final String topicId; // '' for test / daily / smart
  final int grade;
  final String mode;
  const MathPlayScreen({super.key, required this.topicId, required this.grade, required this.mode});
  @override
  State<MathPlayScreen> createState() => _MathPlayScreenState();
}

class _MathPlayScreenState extends State<MathPlayScreen> {
  List<MathQuestion> _questions = <MathQuestion>[];
  List<bool> _isRepeat = <bool>[];
  final Map<String, int> _repeatCount = <String, int>{};
  int _baseCount = 0;
  bool _ready = false;
  int _index = 0;
  int _correct = 0;
  int _needPractice = 0;
  bool _locked = false;
  bool _firstTry = true;
  bool _finished = false;
  int _token = 0;
  int _pickedRight = -1;
  final Set<int> _wrongIdx = <int>{};
  String _message = '';

  int get _total => _questions.length;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await MathReview.ensure(PlayerStore.activeId);
    _setupSession();
    if (!mounted) return;
    setState(() => _ready = true);
    _speakCurrent();
  }

  @override
  void dispose() {
    Speaker.instance.stop();
    super.dispose();
  }

  void _setupSession() {
    _questions = _buildQuestions();
    _isRepeat = List<bool>.filled(_questions.length, false);
    _repeatCount.clear();
    _baseCount = _questions.length;
    _index = 0;
    _correct = 0;
    _needPractice = 0;
    _resetQuestionState();
  }

  void _resetQuestionState() {
    _locked = false;
    _firstTry = true;
    _pickedRight = -1;
    _wrongIdx.clear();
    _token++;
    _message = (_isRepeat.isNotEmpty && _index < _isRepeat.length && _isRepeat[_index]) ? '🔁 Let\'s try this one again!' : '';
  }

  List<MathQuestion> _buildQuestions() {
    final now = DateTime.now();
    final seed = widget.mode == 'daily'
        ? now.year * 10000 + now.month * 100 + now.day + MathStore.activeId.codeUnits.fold<int>(0, (int a, int b) => (a * 31 + b) % 1000)
        : DateTime.now().microsecondsSinceEpoch;
    final rnd = math.Random(seed);
    final engine = MathEngine(rnd, MathStore.optionCount);
    final count = widget.mode == 'daily' ? 5 : MathStore.questionCount;
    final gradeTopics = MathStore.allowedTopicIds(kGradeTopics[widget.grade] ?? <String>['addition']);
    var pool = gradeTopics.where((String t) => t != 'mixed').toList();
    if (pool.isEmpty) pool = gradeTopics;
    if (widget.mode == 'practice') pool = <String>[widget.topicId];

    final out = <MathQuestion>[];
    final seen = <String>{};
    void addUnique(MathQuestion q) {
      if (seen.add('${q.topicId}|${q.text}')) out.add(q);
    }

    // questions the child struggled with come first (smart practice, or a few in normal practice)
    if (widget.mode == 'smart') {
      for (final q in MathReview.due((count / 2).ceil())) {
        addUnique(q);
      }
    } else if (widget.mode == 'practice' && MathStore.smart) {
      for (final q in MathReview.due(30).where((MathQuestion mq) => mq.topicId == widget.topicId).take(3)) {
        addUnique(q);
      }
    }

    // weak topics are picked more often in smart practice
    final weights = <double>[];
    for (final t in pool) {
      final st = MathStore.topicStats(t);
      final a = ((st['a'] ?? 0) as num).toInt();
      final c = ((st['c'] ?? 0) as num).toInt();
      final acc = a == 0 ? 0.5 : c / a;
      weights.add(widget.mode == 'smart' ? 1 + (1 - acc) * 3 : 1.0);
    }
    final totalWeight = weights.fold<double>(0, (double a, double b) => a + b);

    var guard = 0;
    while (out.length < count && guard < count * 30) {
      guard++;
      String t;
      if (widget.mode == 'smart') {
        var r = rnd.nextDouble() * totalWeight;
        var idx = 0;
        for (var i = 0; i < weights.length; i++) {
          r -= weights[i];
          if (r <= 0) {
            idx = i;
            break;
          }
        }
        t = pool[idx];
      } else {
        t = pool[out.length % pool.length];
      }
      addUnique(engine.make(t, widget.grade));
    }
    out.shuffle(rnd);
    return out;
  }

  void _speakCurrent() {
    if (!MathStore.autoSpeak || _questions.isEmpty) return;
    _sayQuestion();
  }

  void _sayQuestion() {
    if (_questions.isEmpty) return;
    final q = _questions[_index];
    final hi = MathStore.lang == 'hi';
    Speaker.instance.speak(hi ? q.spokenHi : q.spokenEn, lang: hi ? 'hi' : 'en');
  }

  /// Called once per question when it is finished. clean = right first time, no hint.
  void _resolve(bool clean) {
    final q = _questions[_index];
    MathStore.recordAnswer(q.topicId, clean);
    MathReview.result(q, clean);
    if (clean) {
      if (!_isRepeat[_index]) _correct++;
    } else {
      _needPractice++;
      final key = '${q.topicId}|${q.text}';
      final used = _repeatCount[key] ?? 0;
      if (used < 2) {
        _repeatCount[key] = used + 1;
        final at = math.min(_questions.length, _index + 4);
        _questions.insert(at, q);
        _isRepeat.insert(at, true);
      }
    }
  }

  void _choose(int i) {
    if (_locked || _finished) return;
    final q = _questions[_index];
    if (i < 0 || i >= q.options.length || _wrongIdx.contains(i)) return;
    CardStore.keyClick();
    final token = _token;
    if (q.options[i] == q.answer) {
      _mathSfx(true);
      _resolve(_firstTry);
      setState(() {
        _locked = true;
        _pickedRight = i;
        _message = _firstTry ? '🎉 Correct!' : '👍 Good! Remember: ${q.answer}';
      });
      Future<void>.delayed(Duration(milliseconds: _firstTry ? 1000 : 1800), () {
        if (mounted && token == _token) _next();
      });
    } else {
      _mathSfx(false);
      if (MathStore.retries) {
        setState(() {
          _wrongIdx.add(i);
          _firstTry = false;
          _message = 'Try again 🙂';
        });
      } else {
        _firstTry = false;
        _resolve(false);
        setState(() {
          _wrongIdx.add(i);
          _locked = true;
          _pickedRight = q.options.indexOf(q.answer);
          _message = 'The answer is ${q.answer}';
        });
        Future<void>.delayed(const Duration(milliseconds: 2200), () {
          if (mounted && token == _token) _next();
        });
      }
    }
  }

  void _hint() {
    if (_locked || _finished || !MathStore.hints) return;
    final q = _questions[_index];
    var wrongLeft = 0;
    var target = -1;
    for (var i = 0; i < q.options.length; i++) {
      if (q.options[i] != q.answer && !_wrongIdx.contains(i)) {
        wrongLeft++;
        if (target < 0) target = i;
      }
    }
    if (target < 0 || wrongLeft <= 1) {
      setState(() => _message = '💡 The answer is one of the last options!');
      return;
    }
    setState(() {
      _wrongIdx.add(target);
      _firstTry = false;
      _message = '💡 That one is not the answer';
    });
  }

  void _next() {
    if (_index + 1 >= _total) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _resetQuestionState();
    });
    _speakCurrent();
  }

  int _stars() {
    final ratio = _baseCount == 0 ? 0.0 : _correct / _baseCount;
    if (ratio >= 0.9) return 3;
    if (ratio >= 0.6) return 2;
    if (ratio >= 0.3) return 1;
    return 0;
  }

  void _finish() {
    final stars = _stars();
    if (widget.mode == 'practice') MathStore.recordStars(widget.topicId, stars);
    if (widget.mode == 'daily') MathStore.markDailyDone();
    if (stars >= 2) _mathSfx(true);
    setState(() {
      _finished = true;
      _token++;
    });
  }

  void _restart() {
    setState(() {
      _finished = false;
      _setupSession();
    });
    _speakCurrent();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_ready) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.f1 || event.logicalKey == LogicalKeyboardKey.colorF2Yellow) {
      if (!_finished) _sayQuestion();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.length == 1 && !_finished && _questions.isNotEmpty) {
      final n = int.tryParse(ch);
      if (n != null && n >= 1 && n <= _questions[_index].options.length) {
        _choose(n - 1);
        return KeyEventResult.handled;
      }
      final up = ch.toUpperCase();
      if (up.length == 1 && up.codeUnitAt(0) >= 65 && up.codeUnitAt(0) - 65 < _questions[_index].options.length) {
        _choose(up.codeUnitAt(0) - 65);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  String get _title {
    if (widget.mode == 'daily') return '📅 Daily Challenge';
    if (widget.mode == 'smart') return '🧠 Smart Practice';
    if (widget.mode == 'test') return '📝 Math Test • ${kGradeNames[widget.grade]}';
    final t = mathTopicById(widget.topicId);
    return '${t.emoji} ${t.name} • ${kGradeNames[widget.grade]}';
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final size = MediaQuery.of(context).size;

    if (!_ready) {
      return ScreenFrame(title: _title, body: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_questions.isEmpty) {
      return ScreenFrame(title: _title, body: Center(child: Text('No questions available.', style: kidText(26 * s))));
    }

    if (_finished) {
      final stars = _stars();
      return ScreenFrame(
        title: _title,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stars == 0 ? '💪' : ('⭐' * stars), style: TextStyle(fontSize: 70 * s)),
              SizedBox(height: 8 * s),
              Text('$_correct / $_baseCount first-time correct', style: kidText(38 * s)),
              SizedBox(height: 6 * s),
              Text(stars >= 2 ? 'Great work, ${MathStore.activeName}!' : 'Keep practising, ${MathStore.activeName}!', style: kidText(24 * s)),
              if (_needPractice > 0)
                Padding(
                  padding: EdgeInsets.only(top: 6 * s),
                  child: Text('🔁 $_needPractice question(s) will come back in Smart Practice', style: kidText(20 * s, w: FontWeight.w600)),
                ),
              SizedBox(height: 22 * s),
              Wrap(
                spacing: 16 * s,
                runSpacing: 10 * s,
                alignment: WrapAlignment.center,
                children: [
                  ActionButton(s: s, icon: Icons.replay_rounded, label: 'Play Again', color: const Color(0xFF22C55E), autofocus: true, onPressed: _restart),
                  ActionButton(s: s, icon: Icons.home_rounded, label: 'Back', color: const Color(0xFF5C6BC0), onPressed: () => Navigator.maybePop(context)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions[_index];
    final optionWidgets = <Widget>[];
    final cols = q.options.length <= 4 ? 2 : 3;
    final optW = math.min(300.0 * s, (size.width - 88 * s - (cols - 1) * 16 * s) / cols);
    for (var i = 0; i < q.options.length; i++) {
      final index = i;
      final isRight = _pickedRight == i;
      final isWrong = _wrongIdx.contains(i);
      optionWidgets.add(TVFocusable(
        autofocus: i == 0,
        onPressed: () => _choose(index),
        scale: 1.06,
        builder: (BuildContext context, bool focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: optW,
          padding: EdgeInsets.symmetric(vertical: 10 * s, horizontal: 12 * s),
          decoration: BoxDecoration(
            color: isRight
                ? const Color(0xFF22C55E)
                : (isWrong ? const Color(0xFFEF4444) : kTileColors[i % kTileColors.length]),
            borderRadius: BorderRadius.circular(22 * s),
            border: Border.all(color: focused ? Colors.white : Colors.white38, width: focused ? 5 * s : 2 * s),
            boxShadow: [BoxShadow(color: focused ? Colors.white.withOpacity(0.7) : Colors.black26, blurRadius: focused ? 22 : 6, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28 * s,
                height: 28 * s,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: Text(optionLetter(i), style: kidText(16 * s)),
              ),
              SizedBox(width: 10 * s),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(q.options[i], style: kidText(34 * s)))),
            ],
          ),
        ),
      ));
    }

    Widget visual = const SizedBox.shrink();
    if (q.clockHour != null && q.clockMinute != null) {
      visual = ClockFace(hour: q.clockHour!, minute: q.clockMinute!, size: math.min(size.height * 0.30, 200 * s));
    } else if (q.emoji != null) {
      visual = Wrap(
        alignment: WrapAlignment.center,
        children: List<Widget>.generate(q.emojiCount, (int i) => Text(q.emoji ?? '', style: TextStyle(fontSize: 34 * s))),
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: ScreenFrame(
        title: _title,
        actions: [
          Text('${_index + 1}/$_total  ⭐$_correct', style: kidText(24 * s)),
          SizedBox(width: 12 * s),
          if (MathStore.hints) ActionButton(s: s, icon: Icons.lightbulb_rounded, label: 'Hint', color: const Color(0xFFF59E0B), onPressed: _hint),
          if (MathStore.hints) SizedBox(width: 10 * s),
          ActionButton(s: s, icon: Icons.volume_up_rounded, label: 'Say', color: const Color(0xFF00ACC1), onPressed: _sayQuestion),
        ],
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(q.text, textAlign: TextAlign.center, style: kidText(q.text.length > 24 ? 34 * s : 56 * s)),
                      SizedBox(height: 8 * s),
                      visual,
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 26 * s, child: Text(_message, textAlign: TextAlign.center, style: kidText(22 * s))),
            SizedBox(height: 6 * s),
            Wrap(alignment: WrapAlignment.center, spacing: 16 * s, runSpacing: 14 * s, children: optionWidgets),
            SizedBox(height: 10 * s),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// SETTINGS / PROFILES / REPORT CARD
// ----------------------------------------------------------------------
class MathReportScreen extends StatefulWidget {
  const MathReportScreen({super.key});
  @override
  State<MathReportScreen> createState() => _MathReportScreenState();
}

class _MathReportScreenState extends State<MathReportScreen> {
  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    var totalA = 0;
    var totalC = 0;
    final rows = <Widget>[];
    for (final t in kMathTopics) {
      final st = MathStore.topicStats(t.id);
      final a = ((st['a'] ?? 0) as num).toInt();
      final c = ((st['c'] ?? 0) as num).toInt();
      final stars = ((st['s'] ?? 0) as num).toInt();
      if (a == 0) continue;
      totalA += a;
      totalC += c;
      final pct = (c * 100 / a).round();
      rows.add(TVFocusable(
        onPressed: null,
        scale: 1.02,
        builder: (BuildContext context, bool focused) => Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 10 * s),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: t.colors),
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(color: focused ? Colors.white : Colors.white24, width: focused ? 4 * s : 2 * s),
          ),
          child: Row(
            children: [
              Text(t.emoji, style: TextStyle(fontSize: 30 * s)),
              SizedBox(width: 12 * s),
              Expanded(child: Text(t.name, style: kidText(22 * s))),
              Text('$c / $a   ($pct%)', style: kidText(20 * s)),
              SizedBox(width: 14 * s),
              Text(stars > 0 ? '⭐' * stars : '–', style: TextStyle(fontSize: 22 * s)),
            ],
          ),
        ),
      ));
    }
    final streak = ((MathStore.daily()['streak'] ?? 0) as num).toInt();
    final header = TVFocusable(
      autofocus: true,
      onPressed: null,
      scale: 1.02,
      builder: (BuildContext context, bool focused) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(14 * s),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18 * s),
          border: Border.all(color: focused ? Colors.white : Colors.white24, width: focused ? 4 * s : 2 * s),
        ),
        child: Text(
          '${MathStore.activeName}  •  ${totalA == 0 ? 'No answers yet' : '$totalC / $totalA correct (${(totalC * 100 / totalA).round()}%)'}  •  🔥 Daily streak: $streak',
          style: kidText(22 * s),
        ),
      ),
    );
    final items = <Widget>[header, ...rows];
    if (rows.isEmpty) {
      items.add(Padding(
        padding: EdgeInsets.all(20 * s),
        child: Text('Play some questions and the results appear here.', style: kidText(22 * s)),
      ));
    }
    return ScreenFrame(
      title: '🏆 Report Card',
      actions: [
        ActionButton(
          s: s,
          icon: Icons.delete_sweep_rounded,
          label: 'Reset',
          color: const Color(0xFFEF4444),
          onPressed: () async {
            final ok = await askConfirm(context, 'Clear ${MathStore.activeName}\'s report card?');
            if (!ok) return;
            await MathStore.resetActiveProgress();
            if (mounted) setState(() {});
          },
        ),
      ],
      body: FocusList(s: s, items: items),
    );
  }
}
