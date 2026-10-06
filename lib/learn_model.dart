import 'dart:convert';
import 'doc_store.dart';

// ======================================================================
// STUDY CARDS (Quick Learn): data model, text/JSON parser and storage.
// Pure Dart (no screens) so the phone server can use it as well.
//
// SIMPLE TEXT FORMAT (also see the sample on the phone page):
//   # Title of the list                    @class Class 3     @subject English     @emoji 🔤
//   ## Section heading (title of the next table)
//   big = small                             pair lines   (=  ->  |  - )
//   happy - glad
//   Q: What is the plural of child?         question + answer
//   A: children
//   What is the plural of child?            options: put * before the right one
//   a) childs
//   *b) children
//   c) childes
//   A [cat] is a pet.                       [answer] or **answer** = hidden word
// ======================================================================

class LearnCard {
  final String front; // question / title (spelling cards: empty, the picture is the question)
  final String back; // answer ('' for tables)
  final String? imagePath;
  final String emoji; // placeholder when there is no picture
  final List<List<String>> rows; // table rows [left, right]
  final List<String> options; // quiz choices (shown with the right one marked)
  final int correct;
  final String note; // explanation
  final String key; // memory key ('' = none)
  final bool spell;
  final bool math;

  const LearnCard({
    required this.front,
    this.back = '',
    this.imagePath,
    this.emoji = '⭐',
    this.rows = const <List<String>>[],
    this.options = const <String>[],
    this.correct = -1,
    this.note = '',
    this.key = '',
    this.spell = false,
    this.math = false,
  });

  bool get isTable => rows.isNotEmpty;

  LearnCard withKey(String k) => LearnCard(
        front: front,
        back: back,
        imagePath: imagePath,
        emoji: emoji,
        rows: rows,
        options: options,
        correct: correct,
        note: note,
        key: k,
        spell: spell,
        math: math,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'front': front,
        'back': back,
        'rows': rows,
        'options': options,
        'correct': correct,
        'note': note,
      };

  factory LearnCard.fromJson(Map<String, dynamic> m) {
    final rows = <List<String>>[];
    final r = m['rows'];
    if (r is List) {
      for (final e in r) {
        if (e is List && e.length >= 2) rows.add(<String>[e[0].toString(), e[1].toString()]);
      }
    }
    final o = m['options'];
    return LearnCard(
      front: (m['front'] ?? '').toString(),
      back: (m['back'] ?? '').toString(),
      rows: rows,
      options: o is List ? o.map((e) => e.toString()).toList() : <String>[],
      correct: m['correct'] is num ? (m['correct'] as num).toInt() : -1,
      note: (m['note'] ?? '').toString(),
    );
  }
}

class LearnSet {
  final String title;
  final String emoji;
  final List<LearnCard> cards;
  final String id; // spelling topic name, quiz id or study-list id ('' = not part of the library)
  final String group; // used to group the maths facts
  const LearnSet(this.title, this.emoji, this.cards, {this.id = '', this.group = ''});
}

/// A study list added from the phone.
class LearnDoc {
  final String id;
  final String title;
  final String emoji;
  final String cls;
  final String subject;
  final List<LearnCard> cards;
  const LearnDoc({required this.id, required this.title, required this.emoji, required this.cls, required this.subject, required this.cards});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'emoji': emoji,
        'cls': cls,
        'subject': subject,
        'cards': cards.map((LearnCard c) => c.toJson()).toList(),
      };

  factory LearnDoc.fromJson(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final list = <LearnCard>[];
    final raw = m['cards'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final c = LearnCard.fromJson(Map<String, dynamic>.from(e));
          list.add(c.withKey('learn:$id:${c.front}${c.rows.isNotEmpty ? c.rows.first[0] : ''}'));
        }
      }
    }
    return LearnDoc(
      id: id,
      title: (m['title'] ?? 'Study list').toString(),
      emoji: (m['emoji'] ?? '📖').toString(),
      cls: (m['cls'] ?? '').toString(),
      subject: (m['subject'] ?? '').toString(),
      cards: list,
    );
  }

  LearnSet toSet() => LearnSet(title, emoji, cards, id: id);
}

class LearnStore {
  static const String _folder = 'learn';

  static Future<List<LearnDoc>> loadAll() async {
    final files = await DocStore.listJsonFiles(_folder);
    final out = <LearnDoc>[];
    for (final f in files) {
      final raw = await DocStore.readJson(_folder, f.path.split('/').last);
      if (raw is Map) {
        final d = LearnDoc.fromJson(Map<String, dynamic>.from(raw));
        if (d.cards.isNotEmpty) out.add(d);
      }
    }
    return out;
  }

  static Future<void> save(LearnDoc d) => DocStore.writeJson(_folder, '${d.id}.json', d.toJson());
  static Future<void> delete(String id) => DocStore.deleteFile(_folder, '$id.json');

  /// Parses text/JSON and saves it. Throws FormatException with a friendly message.
  static Future<LearnDoc> importText(String text, {String title = '', String emoji = '', String cls = '', String subject = ''}) async {
    final parsed = LearnParser.parse(text, title: title, emoji: emoji, cls: cls, subject: subject);
    final id = 'l${DateTime.now().microsecondsSinceEpoch}';
    final doc = LearnDoc(id: id, title: parsed.title, emoji: parsed.emoji, cls: parsed.cls, subject: parsed.subject, cards: parsed.cards);
    await save(doc);
    return doc;
  }
}

class LearnParser {
  static const List<String> _seps = <String>['=>', '->', '→', ' | ', '|', ' = ', '=', ' – ', ' — ', ' - ', ' : ', ': '];

  static String _clean(String s) => s.trim();

  static List<String>? _pair(String line) {
    for (final sep in _seps) {
      final i = line.indexOf(sep);
      if (i > 0) {
        final l = _clean(line.substring(0, i));
        final r = _clean(line.substring(i + sep.length));
        if (l.isNotEmpty && r.isNotEmpty) return <String>[l, r];
      }
    }
    return null;
  }

  static final RegExp _optionRe = RegExp(r'^\s*(\*|✓|✔)?\s*\(?([A-Fa-f])[\)\.]\s+(.+?)\s*(\*|✓|✔)?\s*$');
  static final RegExp _markRe = RegExp(r'\[([^\]]+)\]|\*\*([^*]+)\*\*');

  static LearnDoc parse(String input, {String title = '', String emoji = '', String cls = '', String subject = ''}) {
    var text = input.trim();
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceFirst(RegExp(r'```\s*$'), '').trim();
    if (text.isEmpty) throw const FormatException('Nothing to add - the text is empty.');

    var docTitle = title;
    var docEmoji = emoji;
    var docCls = cls;
    var docSub = subject;
    List<LearnCard> cards;

    if (text.startsWith('{') || text.startsWith('[')) {
      dynamic data;
      try {
        data = json.decode(text);
      } on FormatException catch (e) {
        throw FormatException('This is not valid JSON (${e.message}).');
      }
      List<dynamic> list = <dynamic>[];
      if (data is List) {
        list = data;
      } else if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        if (docTitle.isEmpty) docTitle = (m['title'] ?? m['name'] ?? '').toString();
        if (docEmoji.isEmpty) docEmoji = (m['emoji'] ?? '').toString();
        if (docCls.isEmpty) docCls = (m['class'] ?? m['cls'] ?? '').toString();
        if (docSub.isEmpty) docSub = (m['subject'] ?? '').toString();
        final l = m['cards'] ?? m['items'] ?? m['data'] ?? m['questions'];
        if (l is List) list = l;
      }
      cards = _fromJsonList(list);
    } else {
      final result = _fromText(text);
      cards = result.cards;
      if (docTitle.isEmpty) docTitle = result.title;
      if (docEmoji.isEmpty) docEmoji = result.emoji;
      if (docCls.isEmpty) docCls = result.cls;
      if (docSub.isEmpty) docSub = result.subject;
    }
    if (cards.isEmpty) {
      throw const FormatException('No cards found. Use pair lines (big = small), Q:/A: lines, options with * on the right one, or [hidden words].');
    }
    if (cards.length > 1000) throw const FormatException('Too many cards (maximum 1000 in one list).');
    final t = docTitle.isEmpty ? 'Study list' : docTitle;
    final out = <LearnCard>[
      for (final c in cards) c.withKey('learn:$t:${c.front}${c.rows.isNotEmpty ? c.rows.first[0] : ''}'),
    ];
    return LearnDoc(id: '', title: t, emoji: docEmoji.isEmpty ? '📖' : docEmoji, cls: docCls, subject: docSub, cards: out);
  }

  // --------------------------------------------------------------- JSON
  static String _s(dynamic v) => v == null ? '' : v.toString().trim();

  static List<LearnCard> _fromJsonList(List<dynamic> list) {
    final out = <LearnCard>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final pairs = m['pairs'] ?? m['rows'] ?? m['list'];
      final heading = _s(m['title'] ?? m['front'] ?? m['heading'] ?? m['q'] ?? m['question']);
      if (pairs is List) {
        final rows = <List<String>>[];
        for (final p in pairs) {
          if (p is List && p.length >= 2) {
            rows.add(<String>[_s(p[0]), _s(p[1])]);
          } else if (p is Map) {
            final pm = Map<String, dynamic>.from(p);
            final l = _s(pm['left'] ?? pm['a'] ?? pm['word'] ?? pm['q'] ?? pm['key']);
            final r = _s(pm['right'] ?? pm['b'] ?? pm['meaning'] ?? pm['a'] ?? pm['answer'] ?? pm['value']);
            if (l.isNotEmpty && r.isNotEmpty) rows.add(<String>[l, r]);
          }
        }
        for (var i = 0; i < rows.length; i += 10) {
          out.add(LearnCard(front: heading, rows: rows.sublist(i, i + 10 > rows.length ? rows.length : i + 10), note: _s(m['note'])));
        }
        continue;
      }
      final q = _s(m['q'] ?? m['question'] ?? m['front'] ?? m['word']);
      final a = _s(m['a'] ?? m['answer'] ?? m['back'] ?? m['meaning']);
      final note = _s(m['note'] ?? m['explanation']);
      final optsRaw = m['options'] ?? m['choices'];
      if (q.isNotEmpty && optsRaw is List && optsRaw.length >= 2) {
        final opts = optsRaw.map((dynamic e) => _s(e)).toList();
        var idx = opts.indexWhere((String o) => o.toLowerCase() == a.toLowerCase());
        if (idx < 0 && a.length == 1) {
          final c = a.toUpperCase().codeUnitAt(0) - 65;
          if (c >= 0 && c < opts.length) idx = c;
        }
        if (idx < 0) {
          final n = int.tryParse(a);
          if (n != null && n >= 1 && n <= opts.length) idx = n - 1;
        }
        if (idx < 0) continue;
        out.add(LearnCard(front: q, back: opts[idx], options: opts, correct: idx, note: note));
        continue;
      }
      final text = _s(m['text']);
      if (text.isNotEmpty && _markRe.hasMatch(text)) {
        out.add(_fill(text));
        continue;
      }
      if (q.isNotEmpty && a.isNotEmpty) out.add(LearnCard(front: q, back: a, note: note));
    }
    return out;
  }

  // --------------------------------------------------------------- text
  static LearnCard _fill(String line) {
    final answers = <String>[];
    final front = line.replaceAllMapped(_markRe, (Match m) {
      answers.add((m.group(1) ?? m.group(2) ?? '').trim());
      return '_____';
    });
    return LearnCard(front: front.trim(), back: answers.join(', '));
  }

  static ({List<LearnCard> cards, String title, String emoji, String cls, String subject}) _fromText(String text) {
    var title = '';
    var emoji = '';
    var cls = '';
    var subject = '';
    var section = '';
    final cards = <LearnCard>[];
    final rows = <List<String>>[];

    void flushRows() {
      var i = 0;
      while (i < rows.length) {
        final end = i + 10 > rows.length ? rows.length : i + 10;
        cards.add(LearnCard(front: section.isNotEmpty ? section : title, rows: List<List<String>>.of(rows.sublist(i, end))));
        i = end;
      }
      rows.clear();
    }

    // split into blocks separated by blank lines; directives are handled on the way
    final blocks = <List<String>>[];
    var cur = <String>[];
    void closeBlock() {
      if (cur.isNotEmpty) blocks.add(cur);
      cur = <String>[];
    }

    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trimRight();
      final t = line.trim();
      if (t.isEmpty) {
        closeBlock();
      } else if (t.startsWith('@')) {
        final sp = t.indexOf(' ');
        final key = (sp < 0 ? t : t.substring(0, sp)).toLowerCase();
        final val = sp < 0 ? '' : t.substring(sp + 1).trim();
        if (key == '@class') cls = val;
        if (key == '@subject') subject = val;
        if (key == '@emoji') emoji = val;
        if (key == '@title') title = val;
      } else if (t.startsWith('##')) {
        closeBlock();
        blocks.add(<String>['##${t.substring(2).trim()}']);
      } else if (t.startsWith('#')) {
        if (title.isEmpty) title = t.substring(1).trim();
      } else {
        cur.add(t);
      }
    }
    closeBlock();

    for (final block in blocks) {
      if (block.length == 1 && block.first.startsWith('##')) {
        flushRows();
        section = block.first.substring(2);
        continue;
      }
      // ---- multiple choice block: lines with a) b) c) ...
      final optLines = block.where((String l) => _optionRe.hasMatch(l)).toList();
      if (optLines.length >= 2) {
        final first = block.indexWhere((String l) => _optionRe.hasMatch(l));
        var q = block.sublist(0, first).join(' ').replaceFirst(RegExp(r'^(Q|Question)\s*[:.\-]\s*', caseSensitive: false), '').trim();
        final opts = <String>[];
        var correct = -1;
        var note = '';
        for (var i = first; i < block.length; i++) {
          final m = _optionRe.firstMatch(block[i]);
          if (m != null) {
            if (m.group(1) != null || m.group(4) != null) correct = opts.length;
            opts.add(m.group(3)!.trim());
          } else {
            final am = RegExp(r'^(A|Ans|Answer)\s*[:.\-]\s*(.+)$', caseSensitive: false).firstMatch(block[i]);
            if (am != null) {
              final v = am.group(2)!.trim();
              if (v.length == 1 && RegExp(r'[A-Fa-f]').hasMatch(v)) {
                correct = v.toUpperCase().codeUnitAt(0) - 65;
              } else {
                final k = opts.indexWhere((String o) => o.toLowerCase() == v.toLowerCase());
                if (k >= 0) correct = k;
              }
            } else {
              note = block[i];
            }
          }
        }
        if (q.isEmpty) q = 'Choose the right answer';
        if (correct < 0 || correct >= opts.length) {
          throw FormatException('The question "$q" has options but no right answer. Put * before the right option (for example  *b) children).');
        }
        flushRows();
        cards.add(LearnCard(front: q, back: opts[correct], options: opts, correct: correct, note: note));
        continue;
      }
      // ---- line by line
      String? pendingQ;
      for (final line in block) {
        final qm = RegExp(r'^(Q|Question)\s*[:.\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
        final am = RegExp(r'^(A|Ans|Answer)\s*[:.\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
        if (qm != null) {
          pendingQ = qm.group(2)!.trim();
          continue;
        }
        if (am != null && pendingQ != null) {
          flushRows();
          cards.add(LearnCard(front: pendingQ, back: am.group(2)!.trim()));
          pendingQ = null;
          continue;
        }
        if (_markRe.hasMatch(line)) {
          flushRows();
          cards.add(_fill(line));
          continue;
        }
        final p = _pair(line);
        if (p != null) {
          if (p[0].length > 32 || p[0].endsWith('?') || p[1].length > 60) {
            flushRows();
            cards.add(LearnCard(front: p[0], back: p[1]));
          } else {
            rows.add(p);
          }
        }
      }
      if (pendingQ != null) {
        throw FormatException('The question "$pendingQ" has no answer. Add a line  A: the answer');
      }
    }
    flushRows();
    return (cards: cards, title: title, emoji: emoji, cls: cls, subject: subject);
  }
}

/// Shown on the phone page.
const String kSampleLearnText = r'''
# Antonyms (opposites)
@class Class 3
@subject English
@emoji 🔄

## Opposite words
big = small
hot = cold
happy = sad
up = down
early = late
rich = poor
strong = weak
open = close

## Synonyms (same meaning)
big - large
happy - glad
quick - fast
begin - start

## Homophones
see = sea
no = know
write = right
pair = pear

Q: What is the plural of child?
A: children

What does the mouth like to do?
a) Walk
*b) Eat
c) See
d) Hear

A [cat] says meow and a [dog] says bow-wow.
''';
