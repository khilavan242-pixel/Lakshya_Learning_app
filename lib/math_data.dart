import 'package:flutter/material.dart';
import 'doc_store.dart';

// Maths data (topics, grades, question model, review queue). No UI here.

class MathTopic {
  final String id;
  final String name;
  final String emoji;
  final List<Color> colors;
  const MathTopic(this.id, this.name, this.emoji, this.colors);
}

const List<MathTopic> kMathTopics = <MathTopic>[
  MathTopic('counting', 'Counting', '🔢', <Color>[Color(0xFF26C6DA), Color(0xFF00838F)]),
  MathTopic('addition', 'Addition', '➕', <Color>[Color(0xFFAB47BC), Color(0xFF6A1B9A)]),
  MathTopic('subtraction', 'Subtraction', '➖', <Color>[Color(0xFFFF7043), Color(0xFFD84315)]),
  MathTopic('multiplication', 'Multiplication', '✖️', <Color>[Color(0xFF9CCC65), Color(0xFF558B2F)]),
  MathTopic('division', 'Division', '➗', <Color>[Color(0xFFFFB300), Color(0xFFEF6C00)]),
  MathTopic('fractions', 'Fractions', '🍕', <Color>[Color(0xFF42A5F5), Color(0xFF1565C0)]),
  MathTopic('time', 'Time & Clock', '⏰', <Color>[Color(0xFF7E57C2), Color(0xFF4527A0)]),
  MathTopic('decimals', 'Decimals', '🔟', <Color>[Color(0xFFEC407A), Color(0xFFAD1457)]),
  MathTopic('squareroot', 'Square Root', '√', <Color>[Color(0xFF78909C), Color(0xFF37474F)]),
  MathTopic('exponents', 'Exponents', '⚡', <Color>[Color(0xFF26A69A), Color(0xFF00695C)]),
  MathTopic('algebra', 'Algebra', '🔤', <Color>[Color(0xFF5C6BC0), Color(0xFF283593)]),
  MathTopic('mixed', 'Mixed Operations', '🎲', <Color>[Color(0xFF8D6E63), Color(0xFF4E342E)]),
  MathTopic('fun', 'Fun Math', '🎈', <Color>[Color(0xFFBA68C8), Color(0xFF8E24AA)]),
  MathTopic('geometry', 'Geometry', '📐', <Color>[Color(0xFFFF8A65), Color(0xFFE64A19)]),
  MathTopic('percentage', 'Percentage', '％', <Color>[Color(0xFF66BB6A), Color(0xFF2E7D32)]),
];

const List<String> kGradeNames = <String>[
  'Kindergarten',
  'Grade 1',
  'Grade 2',
  'Grade 3',
  'Grade 4',
  'Grade 5',
  'Grade 6',
];

const List<String> kGradeShort = <String>['K', '1', '2', '3', '4', '5', '6'];

const Map<int, List<String>> kGradeTopics = <int, List<String>>{
  0: <String>['counting', 'addition', 'subtraction', 'time', 'fun', 'geometry'],
  1: <String>['counting', 'addition', 'subtraction', 'time', 'fun', 'geometry', 'mixed'],
  2: <String>['addition', 'subtraction', 'multiplication', 'division', 'time', 'fractions', 'fun', 'geometry', 'mixed'],
  3: <String>['addition', 'subtraction', 'multiplication', 'division', 'fractions', 'time', 'decimals', 'geometry', 'fun', 'mixed'],
  4: <String>['multiplication', 'division', 'fractions', 'decimals', 'percentage', 'geometry', 'time', 'exponents', 'fun', 'mixed'],
  5: <String>['fractions', 'decimals', 'percentage', 'exponents', 'squareroot', 'algebra', 'geometry', 'fun', 'mixed'],
  6: <String>['fractions', 'decimals', 'percentage', 'exponents', 'squareroot', 'algebra', 'geometry', 'fun', 'mixed'],
};

MathTopic mathTopicById(String id) {
  for (final t in kMathTopics) {
    if (t.id == id) return t;
  }
  return kMathTopics[0];
}

// ----------------------------------------------------------------------
// QUESTION + GENERATOR
// ----------------------------------------------------------------------
class MathQuestion {
  final String topicId;
  final String text;
  final String spokenEn;
  final String spokenHi;
  final String answer;
  final List<String> options;
  final int? clockHour;
  final int? clockMinute;
  final String? emoji;
  final int emojiCount;

  const MathQuestion({
    required this.topicId,
    required this.text,
    required this.spokenEn,
    required this.spokenHi,
    required this.answer,
    required this.options,
    this.clockHour,
    this.clockMinute,
    this.emoji,
    this.emojiCount = 0,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'topicId': topicId,
      'text': text,
      'spokenEn': spokenEn,
      'spokenHi': spokenHi,
      'answer': answer,
      'options': options,
      'clockHour': clockHour,
      'clockMinute': clockMinute,
      'emoji': emoji,
      'emojiCount': emojiCount,
    };
  }

  factory MathQuestion.fromJson(Map<String, dynamic> m) {
    final opts = m['options'];
    return MathQuestion(
      topicId: (m['topicId'] ?? 'addition').toString(),
      text: (m['text'] ?? '').toString(),
      spokenEn: (m['spokenEn'] ?? '').toString(),
      spokenHi: (m['spokenHi'] ?? '').toString(),
      answer: (m['answer'] ?? '').toString(),
      options: opts is List ? opts.map((e) => e.toString()).toList() : <String>[],
      clockHour: m['clockHour'] is num ? (m['clockHour'] as num).toInt() : null,
      clockMinute: m['clockMinute'] is num ? (m['clockMinute'] as num).toInt() : null,
      emoji: m['emoji']?.toString(),
      emojiCount: m['emojiCount'] is num ? (m['emojiCount'] as num).toInt() : 0,
    );
  }

  MathQuestion withTopic(String id) {
    return MathQuestion(
      topicId: id,
      text: text,
      spokenEn: spokenEn,
      spokenHi: spokenHi,
      answer: answer,
      options: options,
      clockHour: clockHour,
      clockMinute: clockMinute,
      emoji: emoji,
      emojiCount: emojiCount,
    );
  }
}


/// Questions the child got wrong (or needed help with). They come back in
/// Smart Practice until they are answered correctly twice in a row.
/// Saved in <Documents>/KidsSuperApp/players/mathreview_<player>.json
class MathReview {
  static String _pid = '';
  static List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  static Future<void> _saving = Future<void>.value();

  static Future<void> ensure(String playerId) async {
    if (_pid == playerId) return;
    _pid = playerId;
    _items = <Map<String, dynamic>>[];
    final raw = await DocStore.readJson('players', 'mathreview_$playerId.json');
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) _items.add(Map<String, dynamic>.from(e));
      }
    }
  }

  static int get count => _items.length;

  static List<MathQuestion> due(int max) {
    final copy = List<Map<String, dynamic>>.from(_items)..shuffle();
    final out = <MathQuestion>[];
    for (final e in copy) {
      if (out.length >= max) break;
      final q = e['q'];
      if (q is Map) out.add(MathQuestion.fromJson(Map<String, dynamic>.from(q)));
    }
    return out;
  }

  static String _key(MathQuestion q) => '${q.topicId}|${q.text}';

  static Future<void> result(MathQuestion q, bool clean) async {
    if (_pid.isEmpty) return;
    final k = _key(q);
    final i = _items.indexWhere((Map<String, dynamic> e) => e['k'] == k);
    if (clean) {
      if (i < 0) return;
      final s = ((_items[i]['s'] ?? 0) as num).toInt() + 1;
      if (s >= 2) {
        _items.removeAt(i);
      } else {
        _items[i]['s'] = s;
      }
    } else if (i >= 0) {
      _items[i]['s'] = 0;
    } else {
      if (_items.length >= 40) _items.removeAt(0);
      _items.add(<String, dynamic>{'k': k, 's': 0, 'q': q.toJson()});
    }
    await _save();
  }

  static Future<void> reset(String playerId) async {
    if (_pid == playerId) _items = <Map<String, dynamic>>[];
    await DocStore.deleteFile('players', 'mathreview_$playerId.json');
  }

  static Future<void> _save() {
    final id = _pid;
    _saving = _saving
        .then((_) => DocStore.writeJson('players', 'mathreview_$id.json', _items))
        .catchError((Object e) {});
    return _saving;
  }
}
