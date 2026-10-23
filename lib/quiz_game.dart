import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'mistakes.dart';
import 'phone_manager.dart';
import 'players.dart';
import 'quick_learn.dart';
import 'quiz_model.dart';
import 'speech_service.dart';

// ======================================================================
// QUIZ GAME UI: choose (4 options), true/false, one-word, fill-in-the-blank,
// matching.  English + Hindi text-to-speech, on-screen Hindi/English keyboard.
// Smart play: mastered questions stop showing, difficult ones come back.
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
  if (!PlayerStore.active.sound) return;
  if (good) {
    GameAudioService.instance.playSuccessFanfare();
  } else {
    GameAudioService.instance.playErrorFeedback();
  }
}

/// One question to ask (a question may be asked again later = repeat).
class QuizItem {
  final String quizId;
  final QuizQuestion q;
  final bool repeat;
  const QuizItem(this.quizId, this.q, {this.repeat = false});
  String get key => 'quiz:$quizId:${q.question}';
}

String _itemKey(QuizItem i) => i.key;

List<QuizItem> _itemsForSet(QuizSet set) {
  var items = set.questions.map((QuizQuestion q) => QuizItem(set.id, q)).toList();
  if (QuizPrefs.shuffle) items.shuffle();
  return items;
}

/// Master Play: every question the child has not mastered yet (3 clean answers in a row),
/// hardest first. Returns an empty list when everything is mastered.
List<QuizItem> _masterItems(List<QuizSet> sets) {
  final all = <QuizItem>[];
  for (final set in sets) {
    for (final q in set.questions) {
      all.add(QuizItem(set.id, q));
    }
  }
  final pool = Mastery.notMastered<QuizItem>(all, _itemKey);
  return Mastery.smartPick<QuizItem>(pool, _itemKey, PlayerStore.active.rounds);
}

// ----------------------------------------------------------------------
// QUIZ HOME (list of quiz sets for the active player)
// ----------------------------------------------------------------------
class QuizHomeScreen extends StatefulWidget {
  const QuizHomeScreen({super.key});
  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  final ValueNotifier<int> _refresh = ValueNotifier<int>(0);

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  /// The quiz sets this player may use, as library items (Class > Subject > Quiz).
  Future<List<LibItem>> _loadItems() async {
    await QuizPrefs.load();
    await Mistakes.load();
    final all = await QuizStore.loadAll();
    await Library.syncQuizzes(all);
    final allowed = PlayerStore.active.quizIds;
    final picked = allowed == null ? all : all.where((QuizSet q) => allowed.contains(q.id)).toList();
    final sets = picked.isEmpty ? all : picked;
    final best = await QuizStore.bestScores();
    final items = <LibItem>[];
    for (final set in sets) {
      final b = best[set.id];
      final extra = <String>[];
      if (b != null) extra.add('best $b%');
      items.add(LibItem(
        kind: 'quiz',
        id: set.id,
        title: set.title,
        emoji: set.emoji,
        subtitle: '${set.questions.length} questions${extra.isEmpty ? '' : '  •  ${extra.join('  ')}'}',
        count: set.questions.length,
        payload: set,
      ));
    }
    return items;
  }

  Future<void> _play(String title, String emoji, String scoreId, List<QuizItem> Function() builder, {bool master = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => QuizPlayScreen(title: title, emoji: emoji, scoreId: scoreId, builder: builder, master: master)),
    );
  }

  List<LibExtra> _extras(List<LibItem> scope, String scopeName) {
    final sets = <QuizSet>[];
    for (final it in scope) {
      final p = it.payload;
      if (p is QuizSet) sets.add(p);
    }
    return <LibExtra>[
      LibExtra(
        emoji: '\u{1F4DD}',
        title: 'Mistakes notebook',
        subtitle: Mistakes.count == 0 ? 'No mistakes yet' : '${Mistakes.count} to try again',
        colors: const <Color>[Color(0xFFFF7043), Color(0xFFFFB74D)],
        onPressed: () {
          if (Mistakes.count == 0) {
            showKidsSnack(context, 'No mistakes to practise. Well done!');
            return;
          }
          _play('Mistakes notebook', '\u{1F4DD}', 'mistakes', () => <QuizItem>[for (final m in Mistakes.items) QuizItem(m.setId, m.q)]);
        },
      ),
      if (sets.isNotEmpty)
        LibExtra(
          emoji: '📖',
          title: 'Study',
          subtitle: 'See all questions',
          colors: const <Color>[Color(0xFF7C4DFF), Color(0xFF40C4FF)],
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => LearnGridScreen(set: LearnSources.fromQuizSets(sets.length == 1 ? sets.first.title : 'All questions', sets))),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LibraryBrowser(
      title: '🧠 Quiz Time',
      myClassId: PlayerStore.active.libClass,
      emptyText: 'No quizzes yet.\nPress "Add Quiz" and send a JSON file from your phone.',
      loader: _loadItems,
      onOpen: (LibItem item) {
        final p = item.payload;
        if (p is QuizSet) return _play(item.title, item.emoji, p.id, () => _itemsForSet(p));
        return Future<void>.value();
      },
      extras: _extras,
      refresh: _refresh,
      actions: (double s, Future<void> Function() reload) => <Widget>[
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
        ActionButton(
          s: s,
          icon: Icons.qr_code_2_rounded,
          label: 'Add Quiz',
          color: const Color(0xFF00BFA5),
          onPressed: () async {
            await showPhoneManager(context, path: '/quiz');
            await reload();
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// PLAY SCREEN
// ----------------------------------------------------------------------
class QuizPlayScreen extends StatefulWidget {
  final String title;
  final String emoji;
  final String scoreId;
  final List<QuizItem> Function() builder;
  final bool master; // master play: continue round after round until everything is mastered
  const QuizPlayScreen({
    super.key,
    required this.title,
    required this.emoji,
    required this.scoreId,
    required this.builder,
    this.master = false,
  });
  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  List<QuizItem> _items = <QuizItem>[];
  final Map<String, int> _repeatCount = <String, int>{};
  int _baseCount = 0;
  int _needPractice = 0;
  bool _moreLeft = false;
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
    _begin();
    _autoSpeak();
  }

  @override
  void dispose() {
    Speaker.instance.stop();
    super.dispose();
  }

  void _begin() {
    _items = widget.builder();
    _repeatCount.clear();
    _baseCount = _items.length;
    _needPractice = 0;
    _i = 0;
    _correct = 0;
    _finished = false;
    if (_items.isNotEmpty) _resetQuestion();
  }

  void _restart() {
    setState(_begin);
    _autoSpeak();
  }

  QuizQuestion get _q => _items[_i].q;

  void _resetQuestion() {
    final q = _items[_i].q;
    _locked = false;
    _firstTry = true;
    _message = _items[_i].repeat ? '🔁 Let\'s try this one again!' : '';
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
    if (_items.isEmpty) return;
    if (QuizPrefs.speak && PlayerStore.active.speak) _say(withOptions: false);
  }

  void _say({bool withOptions = true}) {
    if (_finished || _items.isEmpty) return;
    final q = _q;
    final parts = <String>[_spoken(q.question)];
    if (withOptions && q.isChoice) {
      for (var pos = 0; pos < _order.length; pos++) {
        parts.add('${optionLetter(pos)}. ${q.options[_order[pos]]}');
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

  // ------------------------------------------------------ remembering
  String _answerText(QuizQuestion q) {
    if (q.type == 'tf') {
      final hi = Speaker.isHindi(q.question);
      return q.correctIndex == 0 ? (hi ? 'सही' : 'True') : (hi ? 'गलत' : 'False');
    }
    if (q.isChoice) return q.options[q.correctIndex];
    if (q.answers.isNotEmpty) return q.answers.first;
    return '';
  }

  void _requeue(QuizItem item, int gap) {
    final used = _repeatCount[item.key] ?? 0;
    final cap = widget.master ? 5 : 2;
    if (used >= cap) return;
    _repeatCount[item.key] = used + 1;
    final at = math.min(_items.length, _i + gap);
    _items.insert(at, QuizItem(item.quizId, item.q, repeat: true));
  }

  /// Called once when a question is finished. Right at the first try without help = clean.
  /// Not clean -> it comes back a few questions later (and in later rounds) until learned.
  void _finishQuestion({required bool clean}) {
    final item = _items[_i];
    if (clean) {
      if (!item.repeat) _correct++;
      Mistakes.remove(item.q);
      return;
    }
    _needPractice++;
    Mistakes.add(item.quizId, item.q);
    _requeue(item, 4);
  }

  void _scheduleNext(int ms) {
    final token = _token;
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (mounted && token == _token) _next();
    });
  }

  void _markCorrect() {
    _quizSfx(true);
    final q = _q;
    final clean = _firstTry;
    _finishQuestion(clean: clean);
    final remember = clean ? '' : '  Remember: ${_answerText(q)}';
    setState(() {
      _locked = true;
      _message = q.explanation.isNotEmpty ? '🎉 ${q.explanation}$remember' : (clean ? '🎉 Correct!' : '👍 Good!$remember');
    });
    _speakFeedback(q.explanation.isNotEmpty ? q.explanation : (clean ? '' : _answerText(q)));
    _scheduleNext(q.explanation.isNotEmpty ? 3400 : (clean ? 1200 : 2400));
  }

  void _revealAndNext(String shown) {
    final q = _q;
    _quizSfx(false);
    _firstTry = false;
    _finishQuestion(clean: false);
    setState(() {
      _locked = true;
      _message = shown;
    });
    _speakFeedback(_answerText(q));
    _scheduleNext(2800);
  }

  // ------------------------------------------------------ answering
  void _pickChoice(int pos) {
    if (_locked || _finished || pos < 0 || pos >= _order.length || _wrongPos.contains(pos)) return;
    CardStore.keyClick();
    final q = _q;
    if (_order[pos] == q.correctIndex) {
      setState(() => _rightPos = pos);
      _markCorrect();
    } else if (PlayerStore.active.retries) {
      _quizSfx(false);
      setState(() {
        _wrongPos.add(pos);
        _firstTry = false;
        _message = 'Try again 🙂';
      });
    } else {
      setState(() {
        _wrongPos.add(pos);
        _rightPos = _order.indexOf(q.correctIndex);
      });
      _revealAndNext('Answer: ${_answerText(q)}');
    }
  }

  void _hintChoice() {
    if (_locked || _finished || !PlayerStore.active.hints) return;
    final q = _q;
    if (!q.isChoice) return;
    var wrongLeft = 0;
    var target = -1;
    for (var pos = 0; pos < _order.length; pos++) {
      if (_order[pos] != q.correctIndex && !_wrongPos.contains(pos)) {
        wrongLeft++;
        if (target < 0) target = pos;
      }
    }
    if (target < 0 || wrongLeft < 2) {
      setState(() => _message = '💡 It is one of the last choices!');
      return;
    }
    setState(() {
      _wrongPos.add(target);
      _firstTry = false;
      _message = '💡 That one is not the answer';
    });
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
    } else if (PlayerStore.active.retries) {
      _quizSfx(false);
      setState(() {
        _firstTry = false;
        _message = 'Not quite - try again 🙂';
      });
    } else {
      _revealAndNext('Answer: ${_answerText(_q)}');
    }
  }

  void _hintTyped() {
    if (_locked || _finished || !PlayerStore.active.hints) return;
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
    _revealAndNext('Answer: ${_answerText(_q)}');
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
    if (_i + 1 >= _items.length) {
      QuizStore.recordScore(widget.scoreId, _correct, _baseCount);
      final more = widget.master && widget.builder().isNotEmpty;
      setState(() {
        _moreLeft = more;
        _finished = true;
        _token++;
      });
      if (_baseCount > 0 && _correct * 2 >= _baseCount) _quizSfx(true);
      return;
    }
    setState(() {
      _i++;
      _resetQuestion();
    });
    _autoSpeak();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _finished || _items.isEmpty) return KeyEventResult.ignored;
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
    final up = ch.toUpperCase();
    if (q.isChoice && up.length == 1 && up.codeUnitAt(0) >= 65 && up.codeUnitAt(0) <= 72) {
      _pickChoice(up.codeUnitAt(0) - 65);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------ UI pieces
  Widget _questionText(double s) {
    final text = _q.question;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * s),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: kidText(text.length > 70 ? 24 * s : (text.length > 35 ? 30 * s : 38 * s)),
      ),
    );
  }

  Widget _choiceArea(double s, Size size) {
    final q = _q;
    final widgets = <Widget>[];
    final isTf = q.type == 'tf';
    final hi = Speaker.isHindi(q.question);
    final cols = isTf ? 2 : (_order.length <= 4 ? 2 : 3);
    final w = math.min(420.0 * s, (size.width - 88 * s - (cols - 1) * 16 * s) / cols);
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
                  child: Text(optionLetter(pos), style: kidText(16 * s)),
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

  /// Typed answers: question + answer box + buttons on the left, keyboard on the right.
  /// Everything fits on one screen (no scrolling, nothing hidden).
  Widget _typedLayout(double s) {
    final q = _q;
    final shown = _typed.isEmpty ? (_hindiKb ? 'उत्तर लिखें…' : 'Type your answer…') : _typed;
    final hints = PlayerStore.active.hints;
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final leftW = box.maxWidth * 0.36;
      return Row(
        children: [
          SizedBox(
            width: leftW,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: leftW,
                      child: Text(q.shown, textAlign: TextAlign.center, style: kidText(q.shown.length > 60 ? 24 * s : 30 * s)),
                    ),
                  ),
                ),
                SizedBox(height: 6 * s),
                SizedBox(
                  height: 30 * s,
                  width: leftW,
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(_message, textAlign: TextAlign.center, style: kidText(20 * s))),
                ),
                Container(
                  width: leftW,
                  padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16 * s),
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(shown, textAlign: TextAlign.center, style: kidText(30 * s, c: _typed.isEmpty ? Colors.white60 : Colors.white)),
                  ),
                ),
                SizedBox(height: 8 * s),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10 * s,
                  runSpacing: 8 * s,
                  children: [
                    ActionButton(s: s, icon: Icons.check_circle_rounded, label: 'Check', color: const Color(0xFF22C55E), onPressed: _check),
                    if (hints) ActionButton(s: s, icon: Icons.lightbulb_rounded, label: 'Hint', color: const Color(0xFFF59E0B), onPressed: _hintTyped),
                    ActionButton(s: s, icon: Icons.skip_next_rounded, label: 'Skip', color: const Color(0xFF6366F1), onPressed: _skip),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: OnScreenKeyboard(
              hindi: _hindiKb,
              s: s,
              onKey: _typeKey,
              onBackspace: _backspace,
              onToggleLanguage: () => setState(() => _hindiKb = !_hindiKb),
            ),
          ),
        ],
      );
    });
  }

  Widget _matchArea(double s, Size size) {
    final q = _q;
    final colW = (size.width - 88 * s - 60 * s) / 2;
    Widget item(String text, Color color, VoidCallback onTap, {bool autofocus = false}) {
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
      left.add(Padding(padding: EdgeInsets.only(bottom: 10 * s), child: item(q.pairs[li][0], c, () => _pickLeft(index), autofocus: li == 0)));
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
      right.add(Padding(padding: EdgeInsets.only(bottom: 10 * s), child: item(q.pairs[pairIdx][1], c, () => _pickRight(index))));
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
    final title = '${widget.emoji} ${widget.title}';

    if (_items.isEmpty) {
      if (widget.master) {
        return ScreenFrame(
          title: title,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏆', style: TextStyle(fontSize: 80 * s)),
                Text('Everything is mastered!', style: kidText(40 * s)),
                SizedBox(height: 6 * s),
                Text('Amazing work, ${PlayerStore.active.name}!', style: kidText(24 * s)),
                SizedBox(height: 22 * s),
                ActionButton(s: s, icon: Icons.home_rounded, label: 'Back', color: const Color(0xFF5C6BC0), autofocus: true, onPressed: () => Navigator.maybePop(context)),
              ],
            ),
          ),
        );
      }
      return ScreenFrame(title: title, body: Center(child: Text('No questions available.', style: kidText(26 * s))));
    }

    if (_finished) {
      final ratio = _baseCount == 0 ? 0.0 : _correct / _baseCount;
      final stars = ratio >= 0.9 ? 3 : (ratio >= 0.6 ? 2 : (ratio >= 0.3 ? 1 : 0));
      return ScreenFrame(
        title: title,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stars == 0 ? '💪' : ('⭐' * stars), style: TextStyle(fontSize: 70 * s)),
              SizedBox(height: 8 * s),
              Text('$_correct / $_baseCount first-time correct', style: kidText(38 * s)),
              if (_needPractice > 0)
                Padding(
                  padding: EdgeInsets.only(top: 8 * s),
                  child: Text('🔁 $_needPractice question(s) will come back until you know them', style: kidText(20 * s, w: FontWeight.w600)),
                ),
              if (widget.master)
                Padding(
                  padding: EdgeInsets.only(top: 8 * s),
                  child: Text(_moreLeft ? 'Keep going - master every question! 💪' : '🏆 Every question is mastered!', style: kidText(22 * s)),
                ),
              SizedBox(height: 22 * s),
              Wrap(
                spacing: 16 * s,
                runSpacing: 10 * s,
                alignment: WrapAlignment.center,
                children: [
                  if (!widget.master || _moreLeft)
                    ActionButton(
                      s: s,
                      icon: widget.master ? Icons.arrow_forward_rounded : Icons.replay_rounded,
                      label: widget.master ? 'Next Round' : 'Play Again',
                      color: const Color(0xFF22C55E),
                      autofocus: true,
                      onPressed: _restart,
                    ),
                  ActionButton(s: s, icon: Icons.home_rounded, label: 'Back', color: const Color(0xFF5C6BC0), autofocus: widget.master && !_moreLeft, onPressed: () => Navigator.maybePop(context)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final q = _q;
    Widget body;
    if (q.isTyped) {
      body = _typedLayout(s);
    } else {
      final area = q.type == 'match' ? _matchArea(s, size) : _choiceArea(s, size);
      body = Column(
        children: [
          _questionText(s),
          SizedBox(height: 26 * s, child: Text(_message, textAlign: TextAlign.center, style: kidText(20 * s), overflow: TextOverflow.ellipsis)),
          SizedBox(height: 6 * s),
          Expanded(child: SingleChildScrollView(child: Center(child: area))),
        ],
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: ScreenFrame(
        title: title,
        actions: [
          Text('${_i + 1}/${_items.length}  ⭐$_correct', style: kidText(24 * s)),
          SizedBox(width: 12 * s),
          if (q.isChoice && PlayerStore.active.hints) ActionButton(s: s, icon: Icons.lightbulb_rounded, label: 'Hint', color: const Color(0xFFF59E0B), onPressed: _hintChoice),
          if (q.isChoice && PlayerStore.active.hints) SizedBox(width: 10 * s),
          ActionButton(s: s, icon: Icons.volume_up_rounded, label: 'Say', color: const Color(0xFF00ACC1), onPressed: _say),
        ],
        body: body,
      ),
    );
  }
}
