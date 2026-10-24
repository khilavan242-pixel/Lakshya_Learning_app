import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'kids_ui.dart';
import 'learn_model.dart';
import 'library.dart';
import 'ocr_quiz.dart';
import 'quiz_model.dart';
import 'tv_link.dart';

/// Add content in three easy steps: paste, check what the app found, save.
/// The app detects Quiz / Words / Notes by itself (you can change it), puts the content in a
/// Class > Subject > Chapter, and skips things that were already added.
class AddContentScreen extends StatefulWidget {
  const AddContentScreen({super.key});
  @override
  State<AddContentScreen> createState() => _AddContentScreenState();
}

class _Row {
  final String text;
  final String sub;
  final bool dup;
  const _Row(this.text, this.sub, this.dup);
}

class _AddContentScreenState extends State<AddContentScreen> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _chapter = TextEditingController();
  String _kind = 'notes'; // quiz | words | notes
  bool _kindForced = false;
  String _classId = '';
  String _subjectId = '';
  String _error = '';
  String _done = '';
  bool _busy = false;
  List<_Row> _rows = <_Row>[];
  int _dups = 0;
  String _eff = ''; // the text that is really saved (paragraphs become fill-in-the-blank lines)
  String _info = '';
  Set<String> _knownQuestions = <String>{};
  Set<String> _knownWords = <String>{};

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await Library.load();
    final quizzes = await QuizStore.loadAll();
    final cards = await CardStore.loadCards();
    if (!mounted) return;
    setState(() {
      _knownQuestions = <String>{for (final q in quizzes) for (final x in q.questions) _n(x.question)};
      _knownWords = <String>{for (final c in cards) '${c.topic}|${c.word}'};
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    _chapter.dispose();
    super.dispose();
  }

  static String _n(String s) => s.trim().toLowerCase();

  // ------------------------------------------------------------ detection
  String _detect(String t) {
    final s = t.trim();
    if (s.startsWith('{') || s.startsWith('[') || s.startsWith('```')) {
      final low = s.toLowerCase();
      if (low.contains('"questions"') || low.contains('"quizzes"') || low.contains('"options"') || low.contains('"correct')) return 'quiz';
      return 'notes';
    }
    final lines = s.split('\n').map((String e) => e.trim()).where((String e) => e.isNotEmpty).toList();
    if (lines.length >= 3 && lines.every((String l) => l.split(RegExp(r'\s+')).length <= 2 && !RegExp(r'[=:|>→]').hasMatch(l) && !l.endsWith('?'))) return 'words';
    return 'notes';
  }

  List<String> _wordList(String t) {
    final out = <String>[];
    for (final l in t.split(RegExp(r'[\n,]'))) {
      final w = l.trim();
      if (w.isNotEmpty && !out.contains(w.toUpperCase())) out.add(w.toUpperCase());
    }
    return out;
  }

  void _check() {
    final t = _text.text.trim();
    _error = '';
    _done = '';
    _info = '';
    _eff = t;
    _rows = <_Row>[];
    _dups = 0;
    if (t.isEmpty) {
      setState(() {});
      return;
    }
    var src = t;
    if (!t.startsWith('{') && !t.startsWith('[') && !t.startsWith('```') && (!_kindForced || _kind == 'quiz')) {
      final c = OcrQuiz.convert(t);
      if (c != null) {
        src = c.json;
        _eff = src;
        _kind = 'quiz';
        final names = c.kinds.entries.map((MapEntry<String, int> e) => '${e.value} ${e.key}').join(', ');
        _info = 'Made ${c.count} quiz questions from the text ($names).';
        if (c.unsure.isNotEmpty) {
          _info += ' No answer found for question ${c.unsure.join(', ')}. Under each of those questions type  Ans: b  (or the answer) and it updates here.';
        }
      }
    }
    if (!_kindForced && src == t) _kind = _detect(t);
    try {
      if (_kind == 'quiz') {
        for (final set in QuizParser.parse(src)) {
          for (final q in set.questions) {
            final dup = _knownQuestions.contains(_n(q.question));
            if (dup) _dups++;
            final ans = q.options.isNotEmpty && q.correctIndex >= 0 && q.correctIndex < q.options.length ? q.options[q.correctIndex] : (q.answers.isNotEmpty ? q.answers.first : '');
            final label = q.type == 'match' ? 'Match the following (${q.pairs.length} pairs)' : (q.type == 'tf' ? 'True or false' : (q.type == 'fill' ? 'Fill in the blank' : (q.type == 'short' ? 'Short answer' : (q.question.startsWith('Assertion') || q.question.contains('Assertion (A)') ? 'Assertion and reason' : 'Multiple choice'))));
            final tag = q.passage.isNotEmpty ? '$label, with passage' : label;
            _rows.add(_Row(q.question, ans.isEmpty ? tag : '$tag  \u2022  Answer: $ans', dup));
          }
        }
      } else if (_kind == 'words') {
        final topic = _topicName();
        for (final w in _wordList(t)) {
          final dup = _knownWords.contains('$topic|$w');
          if (dup) _dups++;
          _rows.add(_Row(w, '', dup));
        }
      } else {
        LearnDoc doc;
        try {
          doc = LearnParser.parse(t, title: _title.text.trim());
        } on FormatException {
          // A paragraph from a book page: turn every sentence into a fill-in-the-blank card.
          final blanks = _autoBlanks(t);
          if (blanks.isEmpty) rethrow;
          doc = LearnParser.parse(blanks, title: _title.text.trim());
          _eff = blanks;
          _info = 'This looks like a paragraph. Made ${doc.cards.length} fill-in-the-blank cards: one hidden word in each sentence.';
        }
        if (_title.text.isEmpty && doc.title != 'Study list') _title.text = doc.title;
        for (final c in doc.cards) {
          final head = c.front.isNotEmpty ? c.front : (c.rows.isNotEmpty ? '${c.rows.first[0]} = ${c.rows.first[1]}' : '');
          _rows.add(_Row(head, c.back.isNotEmpty ? c.back : (c.rows.length > 1 ? '${c.rows.length} lines' : ''), false));
        }
      }
    } on FormatException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not read this text.';
    }
    setState(() {});
  }

  /// "Teachers teach us good values." -> "Teachers teach us good [values]."
  String _autoBlanks(String t) {
    final flat = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    final out = <String>[];
    for (final raw in flat.split(RegExp(r'(?<=[.?!\u0964])\s+'))) {
      final sentence = raw.trim();
      final words = sentence.split(' ');
      if (words.length < 3) continue;
      var best = -1;
      var bestLen = 0;
      for (var i = 0; i < words.length; i++) {
        final core = words[i].replaceAll(RegExp(r'[.,;:!?"()\u0964\u2018\u2019\u201C\u201D\[\]*]'), '');
        if (core.length >= 4 && core.length > bestLen) {
          best = i;
          bestLen = core.length;
        }
      }
      if (best < 0) continue;
      final w = words[best];
      final core = w.replaceAll(RegExp(r'[.,;:!?"()\u0964\u2018\u2019\u201C\u201D\[\]*]'), '');
      words[best] = w.replaceFirst(core, '[$core]');
      out.add(words.join(' '));
    }
    return out.join('\n');
  }

  String _topicName() {
    final t = _title.text.trim();
    return (t.isEmpty ? 'MY WORDS' : t).toUpperCase();
  }

  bool _hindi = false;

  /// Takes a photo (or picks one) of a book page and reads the text on it. The text lands in the
  /// paste box so it can be corrected before it is saved.
  Future<void> _scan(ImageSource src) async {
    List<XFile> files = <XFile>[];
    try {
      if (src == ImageSource.gallery) {
        files = await ImagePicker().pickMultiImage(imageQuality: 92);
      } else {
        final f = await ImagePicker().pickImage(source: src, imageQuality: 92);
        if (f != null) files = <XFile>[f];
      }
    } catch (e) {
      setState(() => _error = 'Could not open the camera or gallery.');
      return;
    }
    if (files.isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
      _done = 'Reading ${files.length} page${files.length == 1 ? '' : 's'}...';
    });
    final rec = TextRecognizer(script: _hindi ? TextRecognitionScript.devanagiri : TextRecognitionScript.latin);
    var total = 0;
    var failed = 0;
    final pages = <String>[];
    try {
      for (var i = 0; i < files.length; i++) {
        if (mounted) setState(() => _done = 'Reading page ${i + 1} of ${files.length}...');
        try {
          final r = await rec.processImage(InputImage.fromFilePath(files[i].path));
          final lines = <String>[];
          for (final b in r.blocks) {
            for (final l in b.lines) {
              final t = l.text.replaceFirst(RegExp(r'^[\u2022\u00B7*\-\s]+(?![\d]+[.)])'), '').trim();
              if (t.isNotEmpty) lines.add(t);
            }
          }
          if (lines.isEmpty) {
            failed++;
          } else {
            total += lines.length;
            pages.add(lines.join('\n'));
          }
        } catch (e) {
          failed++;
        }
      }
      if (pages.isEmpty) {
        _error = _hindi ? 'Could not read Hindi text on this phone. Try English or type it.' : 'No text found. Try again with more light and the page flat.';
        _done = '';
      } else {
        final old = _text.text.trim();
        final joined = pages.join('\n');
        _text.text = old.isEmpty ? joined : '$old\n$joined';
        _kindForced = false;
        _done = 'Read $total lines from ${pages.length} page${pages.length == 1 ? '' : 's'}.${failed > 0 ? ' $failed page${failed == 1 ? '' : 's'} could not be read.' : ''} Check the text below and fix any mistakes.';
        _check();
      }
    } finally {
      rec.close();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    final t = d?.text ?? '';
    if (t.trim().isEmpty) {
      setState(() => _error = 'The clipboard is empty. Copy some text first.');
      return;
    }
    _text.text = t;
    _kindForced = false;
    _check();
  }

  // --------------------------------------------------------------- saving
  Future<void> _applyDestination(String key) async {
    await Library.setMeta(
      key,
      c: _classId.isEmpty ? null : _classId,
      s: _subjectId.isEmpty ? null : _subjectId,
      ch: _chapter.text.trim().isEmpty ? null : _chapter.text.trim(),
    );
  }

  Future<void> _save() async {
    final t = _eff.isNotEmpty ? _eff : _text.text.trim();
    if (t.isEmpty || _error.isNotEmpty || _rows.isEmpty) return;
    setState(() {
      _busy = true;
      _done = '';
    });
    try {
      if (_kind == 'quiz') {
        var saved = 0;
        var n = 0;
        for (final set in QuizParser.parse(t)) {
          final fresh = set.questions.where((QuizQuestion q) => !_knownQuestions.contains(_n(q.question))).toList();
          if (fresh.isEmpty) continue;
          final id = '${QuizStore.newId()}_${n++}';
          await QuizStore.save(QuizSet(id: id, title: set.title, emoji: set.emoji, lang: set.lang, questions: fresh, cls: set.cls, subject: set.subject));
          await _applyDestination('quiz:$id');
          saved += fresh.length;
          for (final q in fresh) {
            _knownQuestions.add(_n(q.question));
          }
        }
        _done = saved == 0 ? 'Nothing new: all these questions were already added.' : 'Saved $saved quiz questions.${_dups > 0 ? ' Skipped $_dups already added.' : ''}';
      } else if (_kind == 'words') {
        final topic = _topicName();
        final fresh = _wordList(t).where((String w) => !_knownWords.contains('$topic|$w')).toList();
        if (fresh.isEmpty) {
          _done = 'Nothing new: all these words were already added.';
        } else {
          final stamp = DateTime.now().microsecondsSinceEpoch;
          await CardStore.addCards(<WordCard>[for (var i = 0; i < fresh.length; i++) WordCard(id: 'w${stamp}_$i', word: fresh[i], topic: topic, isCustom: true)]);
          await _applyDestination('spell:$topic');
          for (final w in fresh) {
            _knownWords.add('$topic|$w');
          }
          _done = 'Saved ${fresh.length} words in "$topic".${_dups > 0 ? ' Skipped $_dups already added.' : ''} Add pictures later from the TV or the web page.';
        }
      } else {
        final doc = await LearnStore.importText(t, title: _title.text.trim());
        await _applyDestination('learn:${doc.id}');
        _done = 'Saved "${doc.title}" with ${doc.cards.length} cards.';
      }
      _text.clear();
      _rows = <_Row>[];
      _dups = 0;
      _kindForced = false;
    } on FormatException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not save: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _askCode({required bool err}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('TV code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${err ? 'That code was not accepted. ' : ''}Type the 4 digit code shown on the TV: Parent (lock button) > TV code.'),
          const SizedBox(height: 10),
          TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _sendToTv() async {
    final t = _eff.isNotEmpty ? _eff : _text.text.trim();
    if (t.isEmpty || _error.isNotEmpty || _rows.isEmpty) return;
    setState(() {
      _busy = true;
      _done = 'Looking for your TV on this Wi-Fi...';
    });
    final ip = await TvLink.find();
    if (ip == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _done = '';
          _error = 'No TV found. Open GyanTara on the TV (home screen), connect the phone to the same Wi-Fi, then try again.';
        });
      }
      return;
    }
    final cls = Library.classById(_classId)?.name ?? '';
    final sub = Library.subjectById(_subjectId)?.name ?? '';
    Future<String?> attempt(String code) {
      if (_kind == 'quiz') return TvLink.post(ip, '/api/quiz/import', <String, dynamic>{'text': t, 'class': cls, 'subject': sub}, code: code);
      if (_kind == 'words') {
        return TvLink.post(ip, '/api/upload-batch', <Map<String, dynamic>>[for (final w in _wordList(t)) <String, dynamic>{'word': w, 'topic': _topicName()}], code: code);
      }
      final ch = _chapter.text.trim();
      final title = _title.text.trim().isNotEmpty ? _title.text.trim() : ch;
      return TvLink.post(ip, '/api/learn/import', <String, dynamic>{'text': t, 'title': title, 'class': cls, 'subject': sub}, code: code);
    }

    var code = await TvLink.savedCode();
    var err = await attempt(code);
    if (err == 'code' && mounted) {
      final entered = await _askCode(err: code.isNotEmpty);
      if (entered == null) {
        if (mounted) setState(() {
          _busy = false;
          _done = '';
        });
        return;
      }
      code = entered;
      err = await attempt(code);
      if (err == null) await TvLink.saveCode(code);
    }
    if (err == 'code') err = 'Wrong TV code. On the TV open Parent (lock button) to see the 4 digit code.';
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err != null) {
        _done = '';
        _error = err;
      } else {
        _error = '';
        _done = 'Sent to the TV (${_rows.length} ${_kind == 'quiz' ? 'questions' : (_kind == 'words' ? 'words' : 'cards')}). Open it on the TV.';
        _text.clear();
        _rows = <_Row>[];
        _kindForced = false;
      }
    });
  }

  // ------------------------------------------------------------------ UI
  Widget _card(double s, Widget child, {Color? border}) => Container(
        margin: EdgeInsets.only(bottom: 12 * s),
        padding: EdgeInsets.all(14 * s),
        decoration: BoxDecoration(color: const Color(0xFF181B3A), borderRadius: BorderRadius.circular(20 * s), border: border == null ? null : Border.all(color: border, width: 2)),
        child: child,
      );

  Widget _label(double s, String t) => Padding(padding: EdgeInsets.only(bottom: 6 * s), child: Text(t.toUpperCase(), style: kidText(12 * s, c: const Color(0xFFA9ADDB))));

  Widget _stepBar(double s, int step) {
    const names = <String>['Add', 'Check', 'Save'];
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Step $step of 3  \u2022  ${names[step - 1]}', style: kidText(14 * s, w: FontWeight.w700, c: const Color(0xFFA9ADDB))),
        SizedBox(height: 6 * s),
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Container(
                height: 6 * s,
                margin: EdgeInsets.only(right: i < 3 ? 6 * s : 0),
                decoration: BoxDecoration(color: i <= step ? const Color(0xFF35D0BA) : const Color(0xFF2A2E63), borderRadius: BorderRadius.circular(4 * s)),
              ),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final hasText = _text.text.trim().isNotEmpty;
    final kindName = _kind == 'quiz' ? 'quiz questions' : (_kind == 'words' ? 'spelling words' : 'study cards');
    return ScreenFrame(
      title: '➕ Add content',
      body: ListView(
        padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 24 * s),
        children: [
          _stepBar(s, (hasText && _error.isEmpty && _rows.isNotEmpty) ? 3 : (hasText ? 2 : 1)),
          if (isPhone(context))
            _card(
              s,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(s, 'Scan homework'),
                Text('Take a photo of a book page. The app reads the words for you.', style: kidText(14 * s, w: FontWeight.w600)),
                SizedBox(height: 8 * s),
                Wrap(spacing: 8 * s, children: [
                  ChoiceChip(label: const Text('English'), selected: !_hindi, onSelected: (_) => setState(() => _hindi = false)),
                  ChoiceChip(label: const Text('\u0939\u093F\u0928\u094D\u0926\u0940'), selected: _hindi, onSelected: (_) => setState(() => _hindi = true)),
                ]),
                SizedBox(height: 8 * s),
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: _busy ? null : () => _scan(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Camera'))),
                  SizedBox(width: 10 * s),
                  Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _scan(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: const Text('Gallery (many)'))),
                ]),
              ]),
            ),
          _card(
            s,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label(s, 'Step 1: paste'),
              TextField(
                controller: _text,
                minLines: 5,
                maxLines: 10,
                onChanged: (_) {
                  _kindForced = false;
                  _check();
                },
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste quiz JSON, a word list, or notes like  Sun => A star'),
              ),
              SizedBox(height: 8 * s),
              OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded), label: const Text('Paste from clipboard')),
            ]),
          ),
          if (hasText && _error.isEmpty && _rows.isNotEmpty) ...[
            _card(
              s,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(s, 'Step 2: check what we found'),
                Text('Found ${_rows.length} $kindName', style: kidText(20 * s)),
                if (_info.isNotEmpty) Text(_info, style: kidText(14 * s, c: const Color(0xFF7DF0DC), w: FontWeight.w700)),
                if (_dups > 0) Text('$_dups already added, they will be skipped.', style: kidText(14 * s, c: const Color(0xFFFFD9A0), w: FontWeight.w700)),
                SizedBox(height: 8 * s),
                Wrap(spacing: 8 * s, children: [
                  for (final k in const <String>['quiz', 'words', 'notes'])
                    ChoiceChip(
                      label: Text(k == 'quiz' ? 'Quiz' : (k == 'words' ? 'Words' : 'Notes')),
                      selected: _kind == k,
                      onSelected: (_) {
                        _kind = k;
                        _kindForced = true;
                        _check();
                      },
                    ),
                ]),
                SizedBox(height: 8 * s),
                for (final r in _rows.take(5))
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4 * s),
                    child: Row(children: [
                      Icon(r.dup ? Icons.block_rounded : Icons.check_circle_rounded, size: 18 * s, color: r.dup ? const Color(0xFFFFB84D) : const Color(0xFF35D0BA)),
                      SizedBox(width: 8 * s),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.text, style: kidText(15 * s, w: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (r.sub.isNotEmpty) Text(r.sub, style: kidText(13 * s, c: const Color(0xFF7DF0DC), w: FontWeight.w600)),
                      ])),
                    ]),
                  ),
                if (_rows.length > 5) Text('${_rows.length - 5} more...', style: kidText(13 * s, w: FontWeight.w600)),
              ]),
              border: const Color(0xFF35D0BA),
            ),
            _card(
              s,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(s, 'Step 3: where it goes'),
                TextField(
                  controller: _title,
                  onChanged: (_) {
                    if (_kind == 'words') _check();
                  },
                  decoration: InputDecoration(border: const OutlineInputBorder(), labelText: _kind == 'words' ? 'Word group name' : 'Title (optional)'),
                ),
                SizedBox(height: 10 * s),
                DropdownButtonFormField<String>(
                  value: _classId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Class'),
                  items: [const DropdownMenuItem<String>(value: '', child: Text('Not sorted')), for (final c in Library.classes) DropdownMenuItem<String>(value: c.id, child: Text(c.name))],
                  onChanged: (String? v) => setState(() => _classId = v ?? ''),
                ),
                SizedBox(height: 10 * s),
                DropdownButtonFormField<String>(
                  value: _subjectId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Subject'),
                  items: [const DropdownMenuItem<String>(value: '', child: Text('Not sorted')), for (final c in Library.subjects) DropdownMenuItem<String>(value: c.id, child: Text(c.name))],
                  onChanged: (String? v) => setState(() => _subjectId = v ?? ''),
                ),
                SizedBox(height: 10 * s),
                TextField(controller: _chapter, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Chapter (example: Ch 3: Subtraction)')),
              ]),
            ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.phone_android_rounded),
                  label: const Text('Save on phone'),
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _sendToTv,
                  icon: const Icon(Icons.tv_rounded),
                  label: Text(_busy ? 'Working...' : 'Send to TV'),
                ),
              ),
            ]),
          ],
          if (_error.isNotEmpty) Padding(padding: EdgeInsets.only(top: 8 * s), child: Text(_error, style: kidText(16 * s, c: const Color(0xFFFF8A80), w: FontWeight.w700))),
          if (_done.isNotEmpty) Padding(padding: EdgeInsets.only(top: 8 * s), child: Text(_done, style: kidText(18 * s, c: const Color(0xFF7DF0DC)))),
        ],
      ),
    );
  }
}
