import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'phone_manager.dart';
import 'quiz_model.dart';
import 'speech_service.dart';

// ======================================================================
// QUIZ GAME UI: choose (4 options), true/false, one-word, fill-in-the-blank,
// matching.  English + Hindi text-to-speech, on-screen Hindi/English keyboard.
// ======================================================================

class QuizPrefs {
  static bool speak = true;
  static bool shuffle = true;

  static Future<void> load() async {
    final kv = await AppKV.open();
    speak = kv.getBool('quiz_speak') ?? true;
    shuffle = kv.getBool('quiz_shuffle') ?? true;
  }

  static Future<void> save() async {
    final kv = await AppKV.open();
    await kv.setBool('quiz_speak', speak);
    await kv.setBool('quiz_shuffle', shuffle);
  }
}

void _quizSfx(bool good) {
  if (good) {
    GameAudioService.instance.playSuccessFanfare();
  } else {
    GameAudioService.instance.playErrorFeedback();
  }
}

// ----------------------------------------------------------------------
// QUIZ HOME (list of quiz sets)
// ----------------------------------------------------------------------
class QuizHomeScreen extends StatefulWidget {
  const QuizHomeScreen({super.key});
  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  List<QuizSet> _sets = <QuizSet>[];
  Map<String, int> _best = <String, int>{};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await QuizPrefs.load();
    final sets = await QuizStore.loadAll();
    final best = await QuizStore.bestScores();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _best = best;
      _loaded = true;
    });
  }

  Future<void> _play(QuizSet set) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => QuizPlayScreen(quiz: set)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white));
    } else if (_sets.isEmpty) {
      body = Center(
        child: Text('No quizzes yet.\nPress "Add Quiz" and send a JSON file from your phone.', textAlign: TextAlign.center, style: kidText(24 * s)),
      );
    } else {
      final tiles = <Widget>[];
      for (var i = 0; i < _sets.length; i++) {
        final q = _sets[i];
        final best = _best[q.id];
        tiles.add(BigTile(
          emoji: q.emoji,
          title: q.title,
          subtitle: '${q.questions.length} questions${best != null ? '  •  best $best%' : ''}',
          colors: kTopicGradients[i % kTopicGradients.length],
          s: s,
          width: 230,
          height: 180,
          autofocus: i == 0,
          onPressed: () => _play(q),
        ));
      }
      body = Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 12 * s),
          child: Wrap(alignment: WrapAlignment.center, spacing: 22 * s, runSpacing: 22 * s, children: tiles),
        ),
      );
    }

    return ScreenFrame(
      title: '🧠 Quiz Time',
      actions: [
        ActionButton(
          s: s,
          icon: Icons.record_voice_over_rounded,
          label: QuizPrefs.speak ? 'Read: ON' : 'Read: OFF',
          color: const Color(0xFF00ACC1),
          onPressed: () {
            setState(() => QuizPrefs.speak = !QuizPrefs.speak);
            QuizPrefs.save();
          },
        ),
        SizedBox(width: 10 * s),
        ActionButton(
          s: s,
          icon: Icons.shuffle_rounded,
          label: QuizPrefs.shuffle ? 'Shuffle: ON' : 'Shuffle: OFF',
          color: const Color(0xFF7E57C2),
          onPressed: () {
            setState(() => QuizPrefs.shuffle = !QuizPrefs.shuffle);
            QuizPrefs.save();
          },
        ),
        SizedBox(width: 10 * s),
        ActionButton(
          s: s,
          icon: Icons.qr_code_2_rounded,
          label: 'Add Quiz',
          color: const Color(0xFF00BFA5),
          onPressed: () async {
            await showPhoneManager(context, path: '/quiz');
            _reload();
          },
        ),
      ],
      body: body,
    );
  }
}

// ----------------------------------------------------------------------
// ON-SCREEN KEYBOARD (English + Hindi) for typed answers
// ----------------------------------------------------------------------
class _KeyDef {
  final String label;
  final String value;
  const _KeyDef(this.label, this.value);
}

List<List<_KeyDef>> _buildRows(List<String> rows) {
  final out = <List<_KeyDef>>[];
  for (final row in rows) {
    final keys = <_KeyDef>[];
    for (final token in row.split(' ')) {
      if (token.isEmpty) continue;
      final r = token.runes.first;
      final isMark = (r >= 0x0900 && r <= 0x0903) || (r >= 0x093E && r <= 0x094D) || r == 0x093C;
      keys.add(_KeyDef(isMark ? '\u25CC$token' : token, token));
    }
    out.add(keys);
  }
  return out;
}

final List<List<_KeyDef>> _englishRows = _buildRows(<String>[
  '1 2 3 4 5 6 7 8 9 0',
  'Q W E R T Y U I O P',
  'A S D F G H J K L',
  'Z X C V B N M',
]);

final List<List<_KeyDef>> _hindiRows = _buildRows(<String>[
  'अ आ इ ई उ ऊ ऋ ए ऐ ओ औ अं अः',
  'ा ि ी ु ू ृ े ै ो ौ ं ः ँ ्',
  'क ख ग घ ङ च छ ज झ ञ',
  'ट ठ ड ढ ण त थ द ध न',
  'प फ ब भ म य र ल व श',
  'ष स ह ळ क्ष त्र ज्ञ ड़ ढ़',
  '0 1 2 3 4 5 6 7 8 9',
]);

class OnScreenKeyboard extends StatelessWidget {
  final bool hindi;
  final double s;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onToggleLanguage;

  const OnScreenKeyboard({
    super.key,
    required this.hindi,
    required this.s,
    required this.onKey,
    required this.onBackspace,
    required this.onToggleLanguage,
  });

  Widget _key(String label, VoidCallback onTap, {double wFactor = 1.0, Color color = const Color(0xFF3B82F6)}) {
    final k = (hindi ? 36.0 : 42.0) * s;
    return TVFocusable(
      onPressed: onTap,
      scale: 1.15,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: k * wFactor,
        height: k,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? Colors.amberAccent : color,
          borderRadius: BorderRadius.circular(10 * s),
          border: Border.all(color: focused ? Colors.white : Colors.white30, width: focused ? 3 : 1.5),
        ),
        child: Text(label, style: kidText(k * 0.5, c: focused ? Colors.black87 : Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = hindi ? _hindiRows : _englishRows;
    final gap = 5.0 * s;
    final lines = <Widget>[];
    for (final row in rows) {
      lines.add(Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: row.map((_KeyDef d) => _key(d.label, () => onKey(d.value), wFactor: d.value.runes.length > 2 ? 1.5 : 1.0)).toList(),
      ));
      lines.add(SizedBox(height: gap));
    }
    lines.add(Wrap(
      alignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: [
        _key('SPACE', () => onKey(' '), wFactor: 4.0, color: const Color(0xFF6366F1)),
        _key('⌫', onBackspace, wFactor: 1.8, color: const Color(0xFFEF4444)),
        _key(hindi ? 'EN' : 'हिं', onToggleLanguage, wFactor: 1.8, color: const Color(0xFF22C55E)),
      ],
    ));
    return Column(mainAxisSize: MainAxisSize.min, children: lines);
  }
}

// ----------------------------------------------------------------------
// PLAY SCREEN
// ----------------------------------------------------------------------
class QuizPlayScreen extends StatefulWidget {
  final QuizSet quiz;
  const QuizPlayScreen({super.key, required this.quiz});
  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  late List<QuizQuestion> _qs;
  int _i = 0;
  int _correct = 0;
  bool _locked = false;
  bool _firstTry = true;
  bool _finished = false;
  int _token = 0;
  String _message = '';

  // choice
  List<int> _order = <int>[];
  final Set<int> _wrongPos = <int>{};
  int _rightPos = -1;

  // typed
  String _typed = '';
  bool _hindiKb = false;
  int _hintLevel = 0;

  // match
  List<int> _rightOrder = <int>[];
  int _selLeft = -1;
  final Set<int> _matched = <int>{};
  int _flashRight = -1;

  @override
  void initState() {
    super.initState();
    QuizPrefs.load().then((_) {
      if (mounted) _start();
    });
    _qs = List<QuizQuestion>.from(widget.quiz.questions);
    _resetQuestion();
  }

  @override
  void dispose() {
    Speaker.instance.stop();
    super.dispose();
  }

  void _start() {
    setState(() {
      _qs = List<QuizQuestion>.from(widget.quiz.questions);
      if (QuizPrefs.shuffle) _qs.shuffle();
      _i = 0;
      _correct = 0;
      _finished = false;
      _resetQuestion();
    });
    _autoSpeak();
  }

  QuizQuestion get _q => _qs[_i];

  void _resetQuestion() {
    final q = _qs[_i];
    _locked = false;
    _firstTry = true;
    _message = '';
    _wrongPos.clear();
    _rightPos = -1;
    _typed = '';
    _hintLevel = 0;
    _selLeft = -1;
    _matched.clear();
    _flashRight = -1;
    if (q.type == 'tf') {
      _order = <int>[0, 1];
    } else if (q.isChoice) {
      _order = List<int>.generate(q.options.length, (int k) => k);
      if (QuizPrefs.shuffle) _order.shuffle();
    } else {
      _order = <int>[];
    }
    if (q.type == 'match') {
      _rightOrder = List<int>.generate(q.pairs.length, (int k) => k);
      _rightOrder.shuffle();
    } else {
      _rightOrder = <int>[];
    }
    final probe = q.answers.isNotEmpty ? q.answers.first : q.question;
    _hindiKb = Speaker.isHindi(probe);
    _token++;
  }

  String _spoken(String t) {
    return t.replaceAll(RegExp(r'_{2,}'), Speaker.isHindi(t) ? ' खाली स्थान ' : ' blank ');
  }

  void _autoSpeak() {
    if (QuizPrefs.speak) _say(withOptions: false);
  }

  void _say({bool withOptions = true}) {
    if (_finished) return;
    final q = _q;
    final parts = <String>[_spoken(q.question)];
    if (withOptions && q.isChoice) {
      for (var pos = 0; pos < _order.length; pos++) {
        parts.add('${pos + 1}. ${q.options[_order[pos]]}');
      }
    }
    if (parts.length == 1 && q.lang.isNotEmpty) {
      Speaker.instance.speak(parts.first, lang: q.lang);
    } else {
      Speaker.instance.speakAll(parts);
    }
  }

  void _speakFeedback(String text) {
    if (QuizPrefs.speak && text.isNotEmpty) Speaker.instance.speak(text);
  }

  // ------------------------------------------------------ answering
  void _scheduleNext(int ms) {
    final token = _token;
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (mounted && token == _token) _next();
    });
  }

  void _markCorrect() {
    _quizSfx(true);
    if (_firstTry) _correct++;
    final q = _q;
    setState(() {
      _locked = true;
      _message = q.explanation.isNotEmpty ? '🎉 ${q.explanation}' : '🎉 Correct!';
    });
    _speakFeedback(q.explanation);
    _scheduleNext(q.explanation.isNotEmpty ? 3200 : 1200);
  }

  void _pickChoice(int pos) {
    if (_locked || _finished || pos < 0 || pos >= _order.length || _wrongPos.contains(pos)) return;
    CardStore.keyClick();
    final q = _q;
    if (_order[pos] == q.correctIndex) {
      setState(() => _rightPos = pos);
      _markCorrect();
    } else {
      _quizSfx(false);
      setState(() {
        _wrongPos.add(pos);
        _firstTry = false;
        _message = 'Try again 🙂';
      });
    }
  }

  static String _norm(String t) {
    return t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[.।!?]+$'), '');
  }

  void _check() {
    if (_locked || _finished) return;
    final t = _norm(_typed);
    if (t.isEmpty) return;
    final ok = _q.answers.any((String a) => _norm(a) == t);
    if (ok) {
      _markCorrect();
    } else {
      _quizSfx(false);
      setState(() {
        _firstTry = false;
        _message = 'Not quite - try again 🙂';
      });
    }
  }

  void _hint() {
    if (_locked || _finished) return;
    final q = _q;
    final answer = q.answers.isNotEmpty ? q.answers.first : '';
    _hintLevel++;
    setState(() {
      _firstTry = false;
      if (q.hint.isNotEmpty && _hintLevel == 1) {
        _message = '💡 ${q.hint}';
      } else {
        final runes = answer.runes.toList();
        final n = math.max(0, math.min(runes.length - 1, math.max(1, _hintLevel - (q.hint.isNotEmpty ? 1 : 0))));
        _message = '💡 ${String.fromCharCodes(runes.take(n))} …  (${runes.length} letters)';
      }
    });
  }

  void _skip() {
    if (_locked || _finished) return;
    final q = _q;
    setState(() {
      _locked = true;
      _firstTry = false;
      _message = q.answers.isNotEmpty ? 'Answer: ${q.answers.first}' : '';
    });
    _quizSfx(false);
    _speakFeedback(q.answers.isNotEmpty ? q.answers.first : '');
    _scheduleNext(2400);
  }

  void _typeKey(String v) {
    if (_locked) return;
    CardStore.keyClick();
    setState(() => _typed = _typed + v);
  }

  void _backspace() {
    if (_locked || _typed.isEmpty) return;
    final runes = _typed.runes.toList();
    setState(() => _typed = String.fromCharCodes(runes.sublist(0, runes.length - 1)));
  }

  void _pickLeft(int li) {
    if (_locked || _matched.contains(li)) return;
    CardStore.keyClick();
    setState(() {
      _selLeft = li;
      _message = '';
    });
    if (QuizPrefs.speak) Speaker.instance.speak(_q.pairs[li][0]);
  }

  void _pickRight(int pos) {
    if (_locked || _selLeft < 0) return;
    final pairIdx = _rightOrder[pos];
    if (_matched.contains(pairIdx)) return;
    final q = _q;
    if (pairIdx == _selLeft) {
      _quizSfx(true);
      setState(() {
        _matched.add(pairIdx);
        _selLeft = -1;
      });
      if (QuizPrefs.speak) Speaker.instance.speak(q.pairs[pairIdx][1]);
      if (_matched.length == q.pairs.length) {
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _markCorrect();
        });
      }
    } else {
      _quizSfx(false);
      setState(() {
        _firstTry = false;
        _flashRight = pos;
        _message = 'Not a match - try again 🙂';
      });
      final token = _token;
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted && token == _token) setState(() => _flashRight = -1);
      });
    }
  }

  void _next() {
    if (_i + 1 >= _qs.length) {
      QuizStore.recordScore(widget.quiz.id, _correct, _qs.length);
      setState(() {
        _finished = true;
        _token++;
      });
      if (_correct * 2 >= _qs.length) _quizSfx(true);
      return;
    }
    setState(() {
      _i++;
      _resetQuestion();
    });
    _autoSpeak();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _finished) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final q = _q;
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      if (q.isTyped) {
        _backspace();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.f1 || k == LogicalKeyboardKey.colorF2Yellow) {
      _say();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;
    if (q.isTyped) {
      final code = ch.runes.first;
      if (code >= 32 && ch != '\u007f') {
        _typeKey(ch);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final n = int.tryParse(ch);
    if (n != null && n >= 1 && (q.isChoice || q.type == 'tf')) {
      _pickChoice(n - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------ UI pieces
  Widget _questionText(double s, Size size) {
    final q = _q;
    final text = q.question;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * s),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: kidText(text.length > 70 ? 26 * s : (text.length > 35 ? 32 * s : 40 * s)),
      ),
    );
  }

  Widget _choiceArea(double s, Size size) {
    final q = _q;
    final widgets = <Widget>[];
    final isTf = q.type == 'tf';
    final hi = Speaker.isHindi(q.question);
    final cols = isTf ? 2 : (_order.length <= 4 ? 2 : 3);
    final w = math.min(420.0 * s, (size.width - 64 * s - (cols - 1) * 16 * s) / cols);
    for (var pos = 0; pos < _order.length; pos++) {
      final index = pos;
      final orig = _order[pos];
      final isRight = _rightPos == pos;
      final isWrong = _wrongPos.contains(pos);
      String label = q.options[orig];
      if (isTf) label = orig == 0 ? (hi ? 'सही ✔' : 'True ✔') : (hi ? 'गलत ✘' : 'False ✘');
      Color base = kTileColors[pos % kTileColors.length];
      if (isTf) base = orig == 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      widgets.add(TVFocusable(
        autofocus: pos == 0,
        onPressed: () => _pickChoice(index),
        scale: 1.06,
        builder: (BuildContext context, bool focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: w,
          constraints: BoxConstraints(minHeight: 62 * s),
          padding: EdgeInsets.symmetric(vertical: 10 * s, horizontal: 14 * s),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isRight ? const Color(0xFF22C55E) : (isWrong ? Colors.grey.shade700 : base),
            borderRadius: BorderRadius.circular(22 * s),
            border: Border.all(color: focused ? Colors.white : Colors.white38, width: focused ? 5 * s : 2 * s),
            boxShadow: [BoxShadow(color: focused ? Colors.white.withOpacity(0.7) : Colors.black26, blurRadius: focused ? 22 : 6, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isTf)
                Container(
                  width: 28 * s,
                  height: 28 * s,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: Text('${pos + 1}', style: kidText(16 * s)),
                ),
              if (!isTf) SizedBox(width: 10 * s),
              Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: kidText(isTf ? 36 * s : 26 * s))),
            ],
          ),
        ),
      ));
    }
    return Wrap(alignment: WrapAlignment.center, spacing: 16 * s, runSpacing: 14 * s, children: widgets);
  }

  Widget _typedArea(double s, Size size) {
    final shown = _typed.isEmpty ? (_hindiKb ? 'उत्तर लिखें…' : 'Type your answer…') : _typed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: math.min(size.width * 0.8, 760 * s),
          padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 10 * s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: Text(
            shown,
            textAlign: TextAlign.center,
            style: kidText(34 * s, c: _typed.isEmpty ? Colors.white60 : Colors.white),
          ),
        ),
        SizedBox(height: 8 * s),
        OnScreenKeyboard(
          hindi: _hindiKb,
          s: s,
          onKey: _typeKey,
          onBackspace: _backspace,
          onToggleLanguage: () => setState(() => _hindiKb = !_hindiKb),
        ),
        SizedBox(height: 8 * s),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14 * s,
          runSpacing: 8 * s,
          children: [
            ActionButton(s: s, icon: Icons.check_circle_rounded, label: 'Check', color: const Color(0xFF22C55E), onPressed: _check),
            ActionButton(s: s, icon: Icons.lightbulb_rounded, label: 'Hint', color: const Color(0xFFF59E0B), onPressed: _hint),
            ActionButton(s: s, icon: Icons.skip_next_rounded, label: 'Skip', color: const Color(0xFF6366F1), onPressed: _skip),
          ],
        ),
      ],
    );
  }

  Widget _matchArea(double s, Size size) {
    final q = _q;
    final colW = (size.width - 64 * s - 60 * s) / 2;
    Widget item(String text, Color color, bool focusedAllowed, VoidCallback onTap, {bool autofocus = false}) {
      return TVFocusable(
        autofocus: autofocus,
        onPressed: onTap,
        scale: 1.04,
        builder: (BuildContext context, bool focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: colW,
          constraints: BoxConstraints(minHeight: 54 * s),
          padding: EdgeInsets.symmetric(vertical: 8 * s, horizontal: 12 * s),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(color: focused ? Colors.white : Colors.white38, width: focused ? 5 * s : 2 * s),
          ),
          child: Text(text, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: kidText(24 * s)),
        ),
      );
    }

    final left = <Widget>[];
    final right = <Widget>[];
    for (var li = 0; li < q.pairs.length; li++) {
      final index = li;
      Color c = const Color(0xFF3B82F6);
      if (_matched.contains(li)) {
        c = const Color(0xFF22C55E);
      } else if (_selLeft == li) {
        c = const Color(0xFFF59E0B);
      }
      left.add(Padding(padding: EdgeInsets.only(bottom: 10 * s), child: item(q.pairs[li][0], c, true, () => _pickLeft(index), autofocus: li == 0)));
    }
    for (var pos = 0; pos < _rightOrder.length; pos++) {
      final index = pos;
      final pairIdx = _rightOrder[pos];
      Color c = const Color(0xFFAB47BC);
      if (_matched.contains(pairIdx)) {
        c = const Color(0xFF22C55E);
      } else if (_flashRight == pos) {
        c = const Color(0xFFEF4444);
      }
      right.add(Padding(padding: EdgeInsets.only(bottom: 10 * s), child: item(q.pairs[pairIdx][1], c, true, () => _pickRight(index))));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: left),
        SizedBox(width: 60 * s),
        Column(children: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final size = MediaQuery.of(context).size;
    final quiz = widget.quiz;

    if (_finished) {
      final ratio = _qs.isEmpty ? 0.0 : _correct / _qs.length;
      final stars = ratio >= 0.9 ? 3 : (ratio >= 0.6 ? 2 : (ratio >= 0.3 ? 1 : 0));
      return ScreenFrame(
        title: '${quiz.emoji} ${quiz.title}',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stars == 0 ? '💪' : ('⭐' * stars), style: TextStyle(fontSize: 70 * s)),
              SizedBox(height: 8 * s),
              Text('$_correct / ${_qs.length} correct', style: kidText(42 * s)),
              SizedBox(height: 22 * s),
              Wrap(
                spacing: 16 * s,
                runSpacing: 10 * s,
                alignment: WrapAlignment.center,
                children: [
                  ActionButton(s: s, icon: Icons.replay_rounded, label: 'Play Again', color: const Color(0xFF22C55E), autofocus: true, onPressed: _start),
                  ActionButton(s: s, icon: Icons.home_rounded, label: 'Back', color: const Color(0xFF5C6BC0), onPressed: () => Navigator.maybePop(context)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final q = _q;
    Widget area;
    if (q.type == 'match') {
      area = _matchArea(s, size);
    } else if (q.isTyped) {
      area = _typedArea(s, size);
    } else {
      area = _choiceArea(s, size);
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: ScreenFrame(
        title: '${quiz.emoji} ${quiz.title}',
        actions: [
          Text('${_i + 1}/${_qs.length}  ⭐$_correct', style: kidText(24 * s)),
          SizedBox(width: 14 * s),
          ActionButton(s: s, icon: Icons.volume_up_rounded, label: 'Say', color: const Color(0xFF00ACC1), onPressed: _say),
        ],
        body: SingleChildScrollView(
          child: Column(
            children: [
              _questionText(s, size),
              SizedBox(height: 26 * s, child: Text(_message, textAlign: TextAlign.center, style: kidText(20 * s), overflow: TextOverflow.ellipsis)),
              SizedBox(height: 8 * s),
              area,
              SizedBox(height: 16 * s),
            ],
          ),
        ),
      ),
    );
  }
}
