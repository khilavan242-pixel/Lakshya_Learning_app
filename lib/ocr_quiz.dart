import 'dart:convert';

/// Turns text read from a worksheet photo into quiz questions the app understands.
/// Works on numbered questions: multiple choice, fill in the blanks, true or false,
/// match the following (lines like  Cat - Meow) and short answers.
/// Answers are taken from "Ans: b" lines under a question or from an "Answers" list at the end.
/// When the page has no answer, a question is still made and listed in [unsure] so it can be checked.
class OcrQuizResult {
  final String json;
  final int count;
  final List<int> unsure; // question numbers whose answer was not on the page
  final Map<String, int> kinds; // type name -> how many
  const OcrQuizResult(this.json, this.count, this.unsure, this.kinds);
}

class OcrQuiz {
  static final RegExp _qStart = RegExp(r'^\s*(?:Q(?:uestion)?\.?\s*)?(\d{1,3})\s*[.)\-:]\s*(\S.*)$', caseSensitive: false);
  static final RegExp _optMark = RegExp('^\\(?([a-dA-D\u0915\u0916\u0917\u0918])[.)]\\s*(.*)\$');
  static final RegExp _optSplit = RegExp('\\s+(?=\\(?[a-dA-D\u0915\u0916\u0917\u0918][.)]\\s)');
  static final RegExp _blank = RegExp('_{2,}|\\.{4,}|\u2026{1,}|-{4,}');
  static final RegExp _tfMark = RegExp(r'\(?\b(true\s*(?:or|/|\|)\s*false|t\s*/\s*f)\b\)?', caseSensitive: false);
  static final RegExp _ansLine = RegExp(r'^\s*(?:ans(?:wer)?\.?|उत्तर)\s*[:\-=]\s*(.+)$', caseSensitive: false);
  static final RegExp _keyHeader = RegExp(r'^\s*(?:answers?|answer\s*key|ans\.?\s*key|उत्तर)\s*:?\s*$', caseSensitive: false);
  static final RegExp _pair = RegExp(r'^(.+?)\s*(?:->|\u2192|\u2013|\u2014|=|:|-)\s*(.+)$');

  static final RegExp _passageHead = RegExp(
      '^\\s*(?:read\\s+the\\s+(?:following\\s+)?(?:passage|paragraph|story|poem|case|extract|text)|case\\s*(?:study|based)|source\\s*based|unseen\\s+passage|passage|comprehension|\u0917\u0926\u094D\u092F\u093E\u0902\u0936|\u0905\u0928\u0941\u091A\u094D\u091B\u0947\u0926|\u092A\u0926\u094D\u092F\u093E\u0902\u0936)\\b[^\\n]*\$',
      caseSensitive: false);
  static final RegExp _assertRe = RegExp(r'assertion\s*\(?a\)?\s*[:\-.]\s*(.*?)\s*reason\s*\(?r\)?\s*[:\-.]\s*(.*)$', caseSensitive: false, dotAll: true);
  static const List<String> _assertOpts = <String>[
    'Both A and R are true and R is the correct explanation of A.',
    'Both A and R are true but R is not the correct explanation of A.',
    'A is true but R is false.',
    'A is false but R is true.',
  ];

  static int _letterIndex(String l) {
    final c = l.trim().toLowerCase();
    const en = <String>['a', 'b', 'c', 'd'];
    const hi = <String>['\u0915', '\u0916', '\u0917', '\u0918'];
    final i = en.indexOf(c);
    return i >= 0 ? i : hi.indexOf(c);
  }

  static bool? _truth(String s) {
    final t = s.trim().toLowerCase().replaceAll(RegExp(r'[.\s]'), '');
    if (t == 'true' || t == 't' || t == 'yes' || t == '\u0938\u0939\u0940') return true;
    if (t == 'false' || t == 'f' || t == 'no' || t == '\u0917\u0932\u0924') return false;
    return null;
  }

  /// Returns null when the text does not look like a numbered question paper.
  static OcrQuizResult? convert(String text) {
    final all = text.split('\n').map((String l) => l.trim()).where((String l) => l.isNotEmpty).toList();
    if (all.length < 2) return null;

    // Answer list at the end ("Answers" then "1. b  2. True ...").
    final key = <int, String>{};
    var end = all.length;
    for (var i = 0; i < all.length; i++) {
      if (_keyHeader.hasMatch(all[i])) {
        end = i;
        for (final l in all.sublist(i + 1)) {
          for (final m in RegExp(r'(\d{1,3})\s*[.)\-:=]\s*([^\n]+?)(?=\s+\d{1,3}\s*[.)\-:=]|$)').allMatches(l)) {
            final n = int.tryParse(m.group(1) ?? '');
            if (n != null) key[n] = (m.group(2) ?? '').trim();
          }
        }
        break;
      }
    }
    final lines = all.sublist(0, end);

    // Split into numbered blocks.
    final blocks = <int, List<String>>{};
    final order = <int>[];
    final passageOf = <int, String>{};
    var cur = -1;
    var inPassage = false;
    final buf = <String>[];
    var passage = '';
    for (final l in lines) {
      final m = _qStart.firstMatch(l);
      final isQ = m != null && !_optMark.hasMatch(l);
      if (!isQ && _passageHead.hasMatch(l) && !_ansLine.hasMatch(l)) {
        inPassage = true; // a reading passage or case: the questions after it belong to it
        buf.clear();
        cur = -1;
        continue;
      }
      if (isQ) {
        if (inPassage) {
          passage = buf.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          inPassage = false;
        }
        cur = int.parse(m.group(1)!);
        if (blocks.containsKey(cur)) cur = cur + 1000 * order.length; // same number again on another page
        blocks[cur] = <String>[m.group(2)!.trim()];
        if (passage.isNotEmpty) passageOf[cur] = passage;
        order.add(cur);
      } else if (inPassage) {
        buf.add(l);
      } else if (cur >= 0) {
        blocks[cur]!.add(l);
      }
    }
    if (blocks.length < 2) return null;

    final questions = <Map<String, dynamic>>[];
    final unsure = <int>[];
    final kinds = <String, int>{};
    void kind(String k) => kinds[k] = (kinds[k] ?? 0) + 1;

    for (final id in order) {
      final shownNo = id % 1000;
      final raw = blocks[id]!;
      var inlineAns = '';
      final body = <String>[];
      for (final l in raw) {
        final a = _ansLine.firstMatch(l);
        if (a != null) {
          inlineAns = (a.group(1) ?? '').trim();
        } else {
          body.add(l);
        }
      }
      final given = inlineAns.isNotEmpty ? inlineAns : (key[shownNo] ?? '');

      // Options: lines (or pieces of lines) that start with a), b), (c) ...
      final qLines = <String>[];
      final options = <String>[];
      final optLetters = <String>[];
      var inOptions = false;
      for (final l in body) {
        final pieces = l.split(_optSplit);
        var anyOpt = false;
        for (final p in pieces) {
          final m = _optMark.firstMatch(p.trim());
          if (m != null && (m.group(2) ?? '').trim().isNotEmpty) {
            options.add((m.group(2) ?? '').trim());
            optLetters.add(m.group(1)!);
            anyOpt = true;
            inOptions = true;
          }
        }
        if (!anyOpt) {
          if (inOptions && options.isNotEmpty) {
            options[options.length - 1] = '${options.last} ${l.trim()}'; // an option wrapped onto a second line
          } else {
            qLines.add(l);
          }
        }
      }
      var q = qLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (q.isEmpty) continue;

      // ---- assertion and reason
      final am = _assertRe.firstMatch(q);
      if (am != null) {
        final opts = options.length >= 2 ? options : _assertOpts;
        var idx = -1;
        if (given.isNotEmpty) {
          final letter = given.replaceAll(RegExp(r'[\(\)\.\s]'), '');
          if (letter.length == 1) idx = _letterIndex(letter);
          if (idx < 0) {
            final n = int.tryParse(letter);
            if (n != null && n >= 1 && n <= opts.length) idx = n - 1;
          }
        }
        if (idx < 0 || idx >= opts.length) {
          unsure.add(shownNo);
          idx = 0;
        }
        questions.add(<String, dynamic>{
          'type': 'mcq',
          'assertion': (am.group(1) ?? '').trim(),
          'reason': (am.group(2) ?? '').trim(),
          'options': opts,
          'answer_index': idx,
          if (passageOf[id] != null) 'passage': passageOf[id],
        });
        kind('assertion and reason');
        continue;
      }

      // ---- match the following
      if (RegExp(r'\bmatch\b|\u092E\u093F\u0932\u093E\u0928', caseSensitive: false).hasMatch(q) && options.isEmpty) {
        final pairs = <List<String>>[];
        final items = <String>[];
        for (final l in qLines.skip(1)) {
          if (RegExp(r'^\s*(?:column|col\.?)\s*[ab]?\b', caseSensitive: false).hasMatch(l)) continue;
          final m = _pair.firstMatch(l) ?? RegExp(r'^(.+?)\s{3,}(.+)$').firstMatch(l) ?? RegExp(r'^(.+?)\s*\|\s*(.+)$').firstMatch(l);
          if (m != null) {
            pairs.add(<String>[(m.group(1) ?? '').trim(), (m.group(2) ?? '').trim()]);
          } else {
            items.add(l.replaceFirst(RegExp(r'^\(?[a-dA-D1-9][.)]\s*'), '').trim());
          }
        }
        // Two columns read one after the other: first half goes with second half, to be checked.
        if (pairs.isEmpty && items.length >= 4 && items.length <= 16 && items.length.isEven) {
          final half = items.length ~/ 2;
          for (var i = 0; i < half; i++) {
            pairs.add(<String>[items[i], items[i + half]]);
          }
          unsure.add(shownNo);
        }
        if (pairs.length >= 2 && pairs.length <= 8) {
          questions.add(<String, dynamic>{'type': 'match', 'question': qLines.first.replaceAll(RegExp(r'\s+'), ' ').trim(), 'pairs': pairs, if (passageOf[id] != null) 'passage': passageOf[id]});
          kind('match');
        } else {
          unsure.add(shownNo);
        }
        continue;
      }

      // ---- true or false
      if (_tfMark.hasMatch(q) || (options.length == 2 && _truth(options[0]) == true && _truth(options[1]) == false)) {
        q = q.replaceAll(_tfMark, '').replaceAll(RegExp(r'\s+'), ' ').trim();
        final t = _truth(given);
        if (t == null) unsure.add(shownNo);
        questions.add(<String, dynamic>{'type': 'tf', 'question': q, 'answer': t ?? true});
        kind('true/false');
        continue;
      }

      // ---- fill in the blanks (with or without options)
      final hasBlank = _blank.hasMatch(q);
      if (hasBlank) q = q.replaceAll(_blank, '___');

      if (options.length >= 2) {
        var idx = -1;
        if (given.isNotEmpty) {
          final letter = given.replaceAll(RegExp(r'[\(\)\.\s]'), '');
          if (letter.length == 1) idx = _letterIndex(letter);
          if (idx < 0) idx = options.indexWhere((String o) => o.toLowerCase() == given.toLowerCase());
        }
        if (idx < 0 || idx >= options.length) {
          unsure.add(shownNo);
          idx = 0;
        }
        questions.add(<String, dynamic>{'type': hasBlank ? 'fill' : 'mcq', 'question': q, 'options': options, 'answer_index': idx});
        kind(hasBlank ? 'fill in the blanks' : 'multiple choice');
        continue;
      }

      // ---- typed answer
      var ans = given.trim();
      if (ans.isEmpty) {
        unsure.add(shownNo);
        ans = '?';
      }
      questions.add(<String, dynamic>{'type': hasBlank ? 'fill' : 'short', 'question': q, 'answer': ans});
      kind(hasBlank ? 'fill in the blanks' : 'short answer');
    }

    if (questions.length < 2) return null;
    return OcrQuizResult(json.encode(<String, dynamic>{'title': 'Scanned quiz', 'questions': questions}), questions.length, unsure, kinds);
  }
}
