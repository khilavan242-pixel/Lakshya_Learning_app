import 'dart:convert';
import 'doc_store.dart';

// ======================================================================
// QUIZ DATA MODEL + FLEXIBLE JSON PARSER + FILE STORAGE (no UI here)
// Question types: mcq (choose), short (one word), fill (fill in the blank),
// match (matching pairs), tf (true / false).  English + Hindi.
// ======================================================================

class QuizQuestion {
  final String type; // mcq | short | fill | match | tf
  final String question;
  final List<String> options; // choices for mcq / fill-with-options
  final int correctIndex; // index in options (tf: 0 = True, 1 = False)
  final List<String> answers; // accepted typed answers (short / fill without options)
  final List<List<String>> pairs; // match: [left, right]
  final String explanation;
  final String hint;
  final String lang; // '', 'en' or 'hi'  ('' = detect from the text)

  const QuizQuestion({
    required this.type,
    required this.question,
    this.options = const <String>[],
    this.correctIndex = 0,
    this.answers = const <String>[],
    this.pairs = const <List<String>>[],
    this.explanation = '',
    this.hint = '',
    this.lang = '',
  });

  bool get isChoice => type == 'mcq' || (type == 'fill' && options.length >= 2);
  bool get isTyped => (type == 'short' || type == 'fill') && options.length < 2;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'answers': answers,
      'pairs': pairs,
      'explanation': explanation,
      'hint': hint,
      'lang': lang,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> m) {
    List<String> strList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
    final pairList = <List<String>>[];
    final rawPairs = m['pairs'];
    if (rawPairs is List) {
      for (final p in rawPairs) {
        if (p is List && p.length >= 2) pairList.add(<String>[p[0].toString(), p[1].toString()]);
      }
    }
    return QuizQuestion(
      type: (m['type'] ?? 'mcq').toString(),
      question: (m['question'] ?? '').toString(),
      options: strList(m['options']),
      correctIndex: m['correctIndex'] is num ? (m['correctIndex'] as num).toInt() : 0,
      answers: strList(m['answers']),
      pairs: pairList,
      explanation: (m['explanation'] ?? '').toString(),
      hint: (m['hint'] ?? '').toString(),
      lang: (m['lang'] ?? '').toString(),
    );
  }
}

class QuizSet {
  final String id;
  final String title;
  final String emoji;
  final String lang;
  final List<QuizQuestion> questions;
  final String cls; // optional "class" written in the JSON (e.g. Class 1)
  final String subject; // optional "subject" written in the JSON (e.g. English)

  const QuizSet({
    required this.id,
    required this.title,
    required this.emoji,
    required this.lang,
    required this.questions,
    this.cls = '',
    this.subject = '',
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'emoji': emoji,
      'lang': lang,
      'cls': cls,
      'subject': subject,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  factory QuizSet.fromJson(Map<String, dynamic> m) {
    final qs = <QuizQuestion>[];
    final raw = m['questions'];
    if (raw is List) {
      for (final q in raw) {
        if (q is Map) qs.add(QuizQuestion.fromJson(Map<String, dynamic>.from(q)));
      }
    }
    return QuizSet(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? 'Quiz').toString(),
      emoji: (m['emoji'] ?? '🧠').toString(),
      lang: (m['lang'] ?? '').toString(),
      questions: qs,
      cls: (m['cls'] ?? '').toString(),
      subject: (m['subject'] ?? '').toString(),
    );
  }
}

// ----------------------------------------------------------------------
// PARSER: accepts many JSON shapes and key names
// ----------------------------------------------------------------------
class QuizParser {
  static String _str(dynamic v) => v == null ? '' : v.toString().trim();

  static dynamic _first(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
    }
    return null;
  }

  static bool _same(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  static String _normLang(String v) {
    final t = v.trim().toLowerCase();
    if (t == 'hi' || t == 'hindi' || t == 'hin' || t == 'हिंदी' || t == 'हिन्दी' || t == 'hi-in') return 'hi';
    if (t == 'en' || t == 'english' || t == 'eng' || t == 'en-us' || t == 'en-in') return 'en';
    return '';
  }

  static String _normType(String raw) {
    final t = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-/]+'), '_');
    if (t.isEmpty) return '';
    const mcq = <String>{
      'mcq', 'multiple_choice', 'multiplechoice', 'choice', 'choices', 'options', 'option',
      '4_options', 'four_options', 'single_choice', 'quiz', 'select'
    };
    const shortT = <String>{
      'short', 'short_answer', 'shortanswer', 'one_word', 'oneword', 'word', 'text', 'input',
      'typed', 'answer', 'write', 'one_word_answer'
    };
    const fill = <String>{
      'fill', 'fill_blank', 'fill_blanks', 'fill_in_the_blank', 'fill_in_the_blanks',
      'fill_in_blank', 'fill_in_blanks', 'fillblank', 'blank', 'blanks', 'fib', 'cloze'
    };
    const match = <String>{
      'match', 'matching', 'pairs', 'match_pairs', 'match_the_following', 'matchthefollowing',
      'match_following'
    };
    const tf = <String>{'tf', 'truefalse', 'true_false', 'boolean', 'bool', 'yes_no', 'true_or_false'};
    if (mcq.contains(t)) return 'mcq';
    if (shortT.contains(t)) return 'short';
    if (fill.contains(t)) return 'fill';
    if (match.contains(t)) return 'match';
    if (tf.contains(t)) return 'tf';
    throw FormatException('unknown question type "$raw" (use mcq, short, fill, match or tf)');
  }

  static bool? _truth(dynamic v) {
    if (v is bool) return v;
    final t = _str(v).toLowerCase();
    if (<String>['true', 't', 'yes', 'y', '1', 'sahi', 'सही', 'हाँ', 'हां', 'ha', 'correct'].contains(t)) return true;
    if (<String>['false', 'f', 'no', 'n', '0', 'galat', 'गलत', 'नहीं', 'nahi', 'wrong', 'incorrect'].contains(t)) {
      return false;
    }
    return null;
  }

  static List<QuizSet> parse(String input) {
    var text = input.trim();
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    text = text.replaceFirst(RegExp(r'```\s*$'), '').trim();
    if (text.isEmpty) throw const FormatException('Nothing to import - the text is empty.');

    dynamic data;
    try {
      data = json.decode(text);
    } on FormatException {
      // second try: fix smart quotes and trailing commas
      var fixed = text
          .replaceAll('\u201C', '"')
          .replaceAll('\u201D', '"')
          .replaceAll('\u2018', "'")
          .replaceAll('\u2019', "'");
      fixed = fixed.replaceAllMapped(RegExp(r',\s*([}\]])'), (Match m) => m.group(1) ?? '');
      try {
        data = json.decode(fixed);
      } on FormatException catch (e) {
        throw FormatException('This is not valid JSON (${e.message}).');
      }
    }

    final sets = <QuizSet>[];
    if (data is List) {
      sets.add(_buildSet(<String, dynamic>{'questions': data}, 1));
    } else if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final multi = m['quizzes'] ?? m['sets'];
      if (multi is List) {
        var n = 1;
        for (final item in multi) {
          if (item is Map) sets.add(_buildSet(Map<String, dynamic>.from(item), n));
          n++;
        }
      } else {
        sets.add(_buildSet(m, 1));
      }
    } else {
      throw const FormatException('The top level must be an object { } or a list [ ].');
    }
    if (sets.isEmpty) throw const FormatException('No quiz found in this JSON.');
    return sets;
  }

  static QuizSet _buildSet(Map<String, dynamic> m, int n) {
    final title = _str(_first(m, ['title', 'name', 'topic', 'subject']));
    final emoji = _str(_first(m, ['emoji', 'icon']));
    final lang = _normLang(_str(_first(m, ['language', 'lang'])));
    final cls = _str(_first(m, ['class', 'className', 'class_name', 'standard', 'std']));
    final subject = _str(_first(m, ['subject', 'subject_name', 'subjectName']));

    dynamic listRaw = _first(m, ['questions', 'items', 'data', 'qa', 'quiz']);
    if (listRaw is! List) {
      throw const FormatException('Could not find the "questions" list.');
    }
    final list = listRaw;
    if (list.isEmpty) throw const FormatException('The "questions" list is empty.');
    if (list.length > 500) throw const FormatException('Too many questions (maximum 500 per quiz).');

    final qs = <QuizQuestion>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) {
        throw FormatException('Question ${i + 1} must be an object { }.');
      }
      try {
        qs.add(_buildQuestion(Map<String, dynamic>.from(item), lang));
      } on FormatException catch (e) {
        throw FormatException('Question ${i + 1}: ${e.message}');
      }
    }
    return QuizSet(
      id: 'q${DateTime.now().microsecondsSinceEpoch}_$n',
      title: title.isEmpty ? 'Quiz $n' : title,
      emoji: emoji.isEmpty ? '🧠' : emoji,
      lang: lang,
      questions: qs,
      cls: cls,
      subject: subject,
    );
  }

  static QuizQuestion _buildQuestion(Map<String, dynamic> m, String setLang) {
    final q = _str(_first(m, ['question', 'q', 'text', 'prompt', 'title', 'प्रश्न']));
    final qLang = _normLang(_str(_first(m, ['lang', 'language'])));
    final explanation = _str(_first(m, ['explanation', 'why', 'reason', 'note']));
    final hint = _str(_first(m, ['hint', 'clue']));

    final optionsRaw = _first(m, ['options', 'choices', 'opts']);
    final pairsRaw = _first(m, ['pairs', 'matches', 'match']);
    final answerRaw = _first(m, ['answer', 'correct', 'correct_answer', 'correctAnswer', 'ans', 'right', 'solution']);
    final altRaw = _first(m, ['alternatives', 'alternates', 'accept', 'also_accept', 'answers', 'synonyms']);

    var type = _normType(_str(_first(m, ['type', 'kind', 'format'])));
    if (type.isEmpty) {
      if (pairsRaw is List || pairsRaw is Map || (m['left'] is List && m['right'] is List)) {
        type = 'match';
      } else if (optionsRaw == null && (answerRaw is bool || (answerRaw != null && _truth(answerRaw) != null && _str(answerRaw).length <= 5 && q.isNotEmpty && !q.contains('_')))) {
        type = answerRaw is bool ? 'tf' : 'short';
      } else if ((optionsRaw is List && optionsRaw.length >= 2) || optionsRaw is Map) {
        type = q.contains('__') ? 'fill' : 'mcq';
      } else if (q.contains('__')) {
        type = 'fill';
      } else {
        type = 'short';
      }
    }
    if (q.isEmpty && type != 'match') throw const FormatException('the question text is missing.');

    // ---------------------------------------------------------- match
    if (type == 'match') {
      final pairs = <List<String>>[];
      if (pairsRaw is List) {
        for (final p in pairsRaw) {
          if (p is Map) {
            final pm = Map<String, dynamic>.from(p);
            final l = _str(_first(pm, ['left', 'a', 'key', 'item', 'question']));
            final r = _str(_first(pm, ['right', 'b', 'value', 'match', 'answer']));
            if (l.isNotEmpty && r.isNotEmpty) pairs.add(<String>[l, r]);
          } else if (p is List && p.length >= 2) {
            pairs.add(<String>[_str(p[0]), _str(p[1])]);
          }
        }
      } else if (pairsRaw is Map) {
        pairsRaw.forEach((dynamic k, dynamic v) {
          pairs.add(<String>[_str(k), _str(v)]);
        });
      } else if (m['left'] is List && m['right'] is List) {
        final l = m['left'] as List;
        final r = m['right'] as List;
        final n = l.length < r.length ? l.length : r.length;
        for (var i = 0; i < n; i++) {
          pairs.add(<String>[_str(l[i]), _str(r[i])]);
        }
      }
      if (pairs.length < 2) throw const FormatException('a matching question needs at least 2 pairs.');
      if (pairs.length > 8) throw const FormatException('a matching question can have at most 8 pairs.');
      return QuizQuestion(
        type: 'match',
        question: q.isEmpty ? 'Match the pairs' : q,
        pairs: pairs,
        explanation: explanation,
        hint: hint,
        lang: qLang,
      );
    }

    // ---------------------------------------------------------- true / false
    if (type == 'tf') {
      final t = _truth(answerRaw);
      if (t == null) throw const FormatException('a true/false question needs "answer": true or false.');
      return QuizQuestion(
        type: 'tf',
        question: q,
        options: const <String>['True', 'False'],
        correctIndex: t ? 0 : 1,
        explanation: explanation,
        hint: hint,
        lang: qLang,
      );
    }

    // ---------------------------------------------------------- options (mcq / fill with options)
    final options = <String>[];
    var flagIndex = -1;
    if (optionsRaw is List) {
      for (final o in optionsRaw) {
        if (o is Map) {
          final om = Map<String, dynamic>.from(o);
          final t = _str(_first(om, ['text', 'option', 'label', 'value', 'name']));
          if (om['correct'] == true || om['isCorrect'] == true || om['is_correct'] == true) flagIndex = options.length;
          options.add(t);
        } else {
          options.add(_str(o));
        }
      }
    } else if (optionsRaw is Map) {
      optionsRaw.forEach((dynamic k, dynamic v) {
        options.add(_str(v));
      });
    }
    options.removeWhere((String o) => o.isEmpty);

    if (options.length >= 2) {
      if (options.length > 8) throw const FormatException('at most 8 options are allowed.');
      var idx = flagIndex;
      if (idx < 0) {
        final ai = _first(m, ['answer_index', 'answerIndex', 'correct_index', 'correctIndex']);
        if (ai != null) {
          final n = int.tryParse(_str(ai));
          if (n != null) idx = n; // 0-based
        }
      }
      if (idx < 0 && answerRaw != null) {
        final a = _str(answerRaw);
        idx = options.indexWhere((String o) => _same(o, a));
        if (idx < 0) {
          final letter = a.replaceAll(RegExp(r'[\(\)\.\s]'), '');
          if (letter.length == 1) {
            final c = letter.toUpperCase().codeUnitAt(0);
            if (c >= 65 && c < 65 + options.length) idx = c - 65;
          }
        }
        if (idx < 0) {
          final n = int.tryParse(a);
          if (n != null && n >= 1 && n <= options.length) idx = n - 1; // 1-based
        }
      }
      if (idx < 0 || idx >= options.length) {
        throw const FormatException('the correct answer was not found in the options.');
      }
      return QuizQuestion(
        type: type == 'fill' ? 'fill' : 'mcq',
        question: q,
        options: options,
        correctIndex: idx,
        explanation: explanation,
        hint: hint,
        lang: qLang,
      );
    }

    // ---------------------------------------------------------- typed answer
    final answers = <String>[];
    if (answerRaw is List) {
      for (final a in answerRaw) {
        if (_str(a).isNotEmpty) answers.add(_str(a));
      }
    } else if (answerRaw != null && _str(answerRaw).isNotEmpty) {
      answers.add(_str(answerRaw));
    }
    if (altRaw is List) {
      for (final a in altRaw) {
        if (_str(a).isNotEmpty && !answers.contains(_str(a))) answers.add(_str(a));
      }
    }
    if (answers.isEmpty) throw const FormatException('the "answer" is missing.');
    return QuizQuestion(
      type: type == 'fill' ? 'fill' : 'short',
      question: q,
      answers: answers,
      explanation: explanation,
      hint: hint,
      lang: qLang,
    );
  }
}

// ----------------------------------------------------------------------
// STORAGE: <Documents>/KidsSuperApp/quizzes/<id>.json
// ----------------------------------------------------------------------
class QuizStore {
  static const String _folder = 'quizzes';

  static String newId() => 'q${DateTime.now().microsecondsSinceEpoch}';

  static Future<String> folderPath() async {
    final d = await DocStore.folder(_folder);
    return d.path;
  }

  static Future<List<QuizSet>> loadAll() async {
    await installSamplesOnce();
    final files = await DocStore.listJsonFiles(_folder);
    final out = <QuizSet>[];
    for (final f in files) {
      final name = f.path.split('/').last;
      final raw = await DocStore.readJson(_folder, name);
      if (raw is Map) {
        final set = QuizSet.fromJson(Map<String, dynamic>.from(raw));
        if (set.questions.isNotEmpty) out.add(set);
      }
    }
    return out;
  }

  static Future<void> save(QuizSet s) => DocStore.writeJson(_folder, '${s.id}.json', s.toJson());

  static Future<void> delete(String id) => DocStore.deleteFile(_folder, '$id.json');

  /// Imports JSON text; returns the sets that were saved. Throws FormatException with a friendly message.
  static Future<List<QuizSet>> importText(String text) async {
    final sets = QuizParser.parse(text);
    final saved = <QuizSet>[];
    var n = 0;
    for (final s in sets) {
      final withId = QuizSet(
        id: '${newId()}_${n++}',
        title: s.title,
        emoji: s.emoji,
        lang: s.lang,
        questions: s.questions,
        cls: s.cls,
        subject: s.subject,
      );
      await save(withId);
      saved.add(withId);
    }
    return saved;
  }

  // ---- best scores (percent) ----
  static Future<Map<String, int>> bestScores() async {
    final raw = await DocStore.readJson('quiz', 'progress.json');
    final out = <String, int>{};
    if (raw is Map) {
      raw.forEach((dynamic k, dynamic v) {
        if (v is num) out[k.toString()] = v.toInt();
      });
    }
    return out;
  }

  static Future<void> recordScore(String id, int correct, int total) async {
    if (total <= 0) return;
    final best = await bestScores();
    final pct = (correct * 100 / total).round();
    if (pct > (best[id] ?? -1)) {
      best[id] = pct;
      await DocStore.writeJson('quiz', 'progress.json', best);
    }
  }

  // ---- ready-made sample quizzes, installed once ----
  static Future<void> installSamplesOnce() async {
    final kv = await AppKV.open();
    if (kv.getBool('quiz_samples_installed') == true) return;
    await kv.setBool('quiz_samples_installed', true);
    try {
      await importText(kSampleQuizEnglish);
      await importText(kSampleQuizHindi);
    } catch (_) {}
  }
}

/// Shown on the phone page as the format example.
const String kSampleQuizEnglish = r'''
{
  "title": "General Knowledge",
  "emoji": "🧠",
  "language": "en",
  "questions": [
    { "type": "mcq", "question": "Which planet is known as the Red Planet?",
      "options": ["Venus", "Mars", "Jupiter", "Saturn"], "answer": "Mars",
      "explanation": "Mars looks red because of iron-rich dust." },
    { "type": "mcq", "question": "How many legs does a spider have?",
      "options": ["6", "8", "10", "4"], "answer": "8" },
    { "type": "short", "question": "What colour do you get by mixing blue and yellow?",
      "answer": "green", "hint": "Think of grass" },
    { "type": "fill", "question": "The Sun rises in the ___ .",
      "options": ["east", "west", "north", "south"], "answer": "east" },
    { "type": "fill", "question": "A baby cat is called a ___ .",
      "answer": "kitten", "alternatives": ["kitty"] },
    { "type": "match", "question": "Match the animal with its home",
      "pairs": [ {"left": "Bird", "right": "Nest"}, {"left": "Bee", "right": "Hive"},
                 {"left": "Lion", "right": "Den"}, {"left": "Rabbit", "right": "Burrow"} ] },
    { "type": "tf", "question": "A whale is a fish.", "answer": false,
      "explanation": "A whale is a mammal." }
  ]
}
''';

const String kSampleQuizHindi = r'''
{
  "title": "हिन्दी प्रश्नोत्तरी",
  "emoji": "🇮🇳",
  "language": "hi",
  "questions": [
    { "type": "mcq", "question": "भारत की राजधानी क्या है?",
      "options": ["मुंबई", "नई दिल्ली", "कोलकाता", "चेन्नई"], "answer": "नई दिल्ली" },
    { "type": "mcq", "question": "सप्ताह में कितने दिन होते हैं?",
      "options": ["5", "6", "7", "8"], "answer": "7" },
    { "type": "short", "question": "हमारे राष्ट्रीय ध्वज में कितने रंग होते हैं?",
      "answer": "तीन", "alternatives": ["3"] },
    { "type": "fill", "question": "सूरज ___ दिशा में उगता है।",
      "options": ["पूर्व", "पश्चिम", "उत्तर", "दक्षिण"], "answer": "पूर्व" },
    { "type": "match", "question": "जानवर और उनके बच्चे मिलाइए",
      "pairs": [ {"left": "गाय", "right": "बछड़ा"}, {"left": "कुत्ता", "right": "पिल्ला"},
                 {"left": "शेर", "right": "शावक"}, {"left": "मुर्गी", "right": "चूज़ा"} ] },
    { "type": "tf", "question": "पृथ्वी सूर्य के चारों ओर घूमती है।", "answer": true }
  ]
}
''';
