import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';
import 'chapter_screen.dart';
import 'journey_screen.dart';
import 'kids_ui.dart';
import 'learn_facts.dart';
import 'learn_model.dart';
import 'library.dart';
import 'players.dart';
import 'quiz_model.dart';
import 'speech_service.dart';

// ======================================================================
// QUICK LEARN: study the content of every game before (or instead of) playing.
//   Many cards on ONE screen (colourful page), or one big card at a time.
//   📖 Show answers  - everything visible, like a textbook page
//   🙈 Hide answers  - self test: tap a card to see its answer
//   ▶ Auto play      - the TV reads the questions and answers by itself
// Sources: spelling words, quiz questions, study lists added from the phone,
// and ready-made maths & everyday facts (numbers 1-100, tables, ...).
// ======================================================================

String _sayMath(String t) {
  return t
      .replaceAll('×', ' times ')
      .replaceAll('²', ' squared ')
      .replaceAll('³', ' cubed ')
      .replaceAll('√', 'square root of ')
      .replaceAll('−', ' minus ')
      .replaceAll('÷', ' divided by ');
}

/// Parts of a table row to read aloud (English and Hindi parts are spoken separately).
List<String> learnRowParts(LearnCard c, int r) {
  final l = c.rows[r][0];
  final v = c.rows[r][1];
  if (c.math) return <String>[_sayMath(l), _sayMath(v)];
  final out = <String>[];
  for (final part in <String>[...l.split('·'), ...v.split('·')]) {
    final p = part.trim();
    if (p.isNotEmpty) out.add(p);
  }
  return out;
}

String learnSpokenFront(LearnCard c) => c.spell ? '' : c.front.replaceAll(RegExp(r'_{2,}'), ' blank ');

String learnSpokenBack(LearnCard c) {
  if (c.spell) return '${c.back}. ${c.back.split('').join(', ')}';
  final note = c.note.isNotEmpty ? '. ${c.note}' : '';
  return '${c.back}$note';
}

class LearnSources {
  /// Spelling words of the topics this player may use, one set per topic.
  static Future<List<LearnSet>> spelling() async {
    final all = await CardStore.loadCards();
    final allowed = PlayerStore.active.spellingTopics;
    var cards = allowed == null ? all : all.where((c) => allowed.contains(c.topic)).toList();
    if (cards.isEmpty) cards = all;
    final byTopic = <String, List<LearnCard>>{};
    for (final c in cards) {
      final lc = LearnCard(front: '', back: c.word, imagePath: c.imagePath, emoji: emojiForTopic(c.topic), key: 'spell:${c.word}', spell: true);
      byTopic.putIfAbsent(c.topic, () => <LearnCard>[]).add(lc);
    }
    final out = <LearnSet>[];
    byTopic.forEach((String topic, List<LearnCard> list) {
      out.add(LearnSet(topic, emojiForTopic(topic), list, id: topic));
    });
    return out;
  }

  static LearnCard _fromQuestion(String quizId, QuizQuestion q) {
    final key = 'quiz:$quizId:${q.question}';
    if (q.type == 'match') {
      return LearnCard(front: q.question, rows: q.pairs, note: q.explanation, key: key);
    }
    if (q.type == 'tf') {
      final hi = Speaker.isHindi(q.question);
      final ans = q.correctIndex == 0 ? (hi ? 'सही' : 'True') : (hi ? 'गलत' : 'False');
      return LearnCard(front: q.question, back: ans, note: q.explanation, key: key);
    }
    if (q.isChoice) {
      return LearnCard(front: q.question, back: q.options[q.correctIndex], options: q.options, correct: q.correctIndex, note: q.explanation, key: key);
    }
    return LearnCard(front: q.question, back: q.answers.isNotEmpty ? q.answers.first : '', note: q.explanation, key: key);
  }

  static Future<List<LearnSet>> quizzes() async {
    final all = await QuizStore.loadAll();
    final allowed = PlayerStore.active.quizIds;
    var sets = allowed == null ? all : all.where((QuizSet q) => allowed.contains(q.id)).toList();
    if (sets.isEmpty) sets = all;
    final out = <LearnSet>[];
    for (final set in sets) {
      out.add(LearnSet(set.title, set.emoji, set.questions.map((QuizQuestion q) => _fromQuestion(set.id, q)).toList(), id: set.id));
    }
    return out;
  }

  /// Study view of words (used by the "Study" button inside Spelling).
  static LearnSet fromWords(String title, List<dynamic> words) {
    final cards = <LearnCard>[];
    for (final w in words) {
      cards.add(LearnCard(front: '', back: w.word as String, imagePath: w.imagePath as String?, emoji: emojiForTopic(w.topic as String), key: 'spell:${w.word}', spell: true));
    }
    return LearnSet(title, '✏️', cards);
  }

  /// Study view of quiz sets (used by the "Study" button inside Quiz).
  static LearnSet fromQuizSets(String title, List<QuizSet> sets) {
    final cards = <LearnCard>[];
    for (final s in sets) {
      for (final q in s.questions) {
        cards.add(_fromQuestion(s.id, q));
      }
    }
    return LearnSet(title, '🧠', cards);
  }

  static Future<List<LearnSet>> studyLists() async {
    final docs = await LearnStore.loadAll();
    await Library.syncLearn(docs);
    return docs.map((LearnDoc d) => d.toSet()).toList();
  }

  static List<LearnSet> mathFacts() => LearnFacts.all();
}

// ----------------------------------------------------------------------
// CHOOSE WHAT TO LEARN
// ----------------------------------------------------------------------
class QuickLearnHome extends StatelessWidget {
  const QuickLearnHome({super.key});

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    Widget Function(double, double) tile(String emoji, String title, String sub, List<Color> colors, Widget Function() screen, bool first) {
      return (double w, double h) => BigTile(
            emoji: emoji,
            title: title,
            subtitle: sub,
            colors: colors,
            s: s,
            width: w / s,
            height: h / s,
            autofocus: first,
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen())),
          );
    }

    final tiles = <Widget Function(double, double)>[
      tile('📚', 'My library', 'Class > Subject > Topic', const <Color>[Color(0xFFFF9A44), Color(0xFFFC6076)], () => const QuickLearnLibrary(), true),
      tile('🧮', 'Maths & facts', 'Numbers 1-100, tables ...', const <Color>[Color(0xFF36D1DC), Color(0xFF5B86E5)], () => const QuickLearnMathHome(), false),
    ];
    return ScreenFrame(
      title: '📖 Quick Learn',
      actions: [
        ActionButton(
          s: s,
          icon: Icons.folder_open_rounded,
          label: 'Organize',
          color: const Color(0xFF8E24AA),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LibraryManagerScreen())),
        ),
      ],
      body: Column(
        children: [
          Text('Study first, then play! What do you want to learn?', style: kidText(22 * s, w: FontWeight.w600)),
          Expanded(child: AdaptiveGrid(builders: tiles, aspect: 1.1, minWidth: 150 * s, maxWidth: 270 * s, gap: 22 * s)),
        ],
      ),
    );
  }
}

/// Ready-made facts in groups (Numbers, Tables, Add & subtract ...).
class QuickLearnMathHome extends StatelessWidget {
  const QuickLearnMathHome({super.key});

  static const Map<String, String> _emoji = <String, String>{
    'Numbers': '🔢',
    'Tables': '✖️',
    'Add & subtract': '➕',
    'Squares & roots': '⚡',
    'Time & measures': '⏰',
    'Shapes & colours': '🎨',
  };

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final sets = LearnSources.mathFacts();
    final groups = LearnFacts.groups(sets);
    final tiles = <Widget Function(double, double)>[];
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final index = i;
      final inGroup = sets.where((LearnSet x) => x.group == g).toList();
      tiles.add((double w, double h) => BigTile(
            emoji: _emoji[g] ?? '📘',
            title: g,
            subtitle: '${inGroup.length} lists',
            colors: kTopicGradients[index % kTopicGradients.length],
            s: s,
            width: w / s,
            height: h / s,
            autofocus: index == 0,
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => QuickLearnSets(title: '${_emoji[g] ?? '📘'} $g', sets: inGroup))),
          ));
    }
    return ScreenFrame(title: '🧮 Maths & facts', body: AdaptiveGrid(builders: tiles, aspect: 1.2, minWidth: 150 * s, maxWidth: 260 * s, gap: 20 * s));
  }
}

/// A plain list of study sets (used for the maths facts).
class QuickLearnSets extends StatelessWidget {
  final String title;
  final List<LearnSet> sets;
  const QuickLearnSets({super.key, required this.title, required this.sets});

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final tiles = <Widget Function(double, double)>[];
    for (var i = 0; i < sets.length; i++) {
      final set = sets[i];
      final index = i;
      tiles.add((double w, double h) => BigTile(
            emoji: set.emoji,
            title: set.title,
            subtitle: set.cards.length == 1 ? '1 card' : '${set.cards.length} cards',
            colors: kTopicGradients[index % kTopicGradients.length],
            s: s,
            width: w / s,
            height: h / s,
            autofocus: index == 0,
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LearnGridScreen(set: set))),
          ));
    }
    return ScreenFrame(title: title, body: AdaptiveGrid(builders: tiles, aspect: 1.2, minWidth: 150 * s, maxWidth: 260 * s, gap: 20 * s));
  }
}

/// Spelling topics, quiz sets and study lists in their Class > Subject folders.
class QuickLearnLibrary extends StatelessWidget {
  const QuickLearnLibrary({super.key});

  Future<List<LibItem>> _load() async {
    await Library.load();
    final out = <LibItem>[];
    final all = await QuizStore.loadAll();
    await Library.syncQuizzes(all);
    for (final set in await LearnSources.spelling()) {
      if (set.id.isEmpty) continue;
      out.add(LibItem(kind: 'spell', id: set.id, title: set.title, emoji: set.emoji, subtitle: '✏️ ${set.cards.length} words', count: set.cards.length, payload: set));
    }
    for (final set in await LearnSources.quizzes()) {
      if (set.id.isEmpty) continue;
      out.add(LibItem(kind: 'quiz', id: set.id, title: set.title, emoji: set.emoji, subtitle: '🧠 ${set.cards.length} questions', count: set.cards.length, payload: set));
    }
    for (final set in await LearnSources.studyLists()) {
      if (set.id.isEmpty) continue;
      out.add(LibItem(kind: 'learn', id: set.id, title: set.title, emoji: set.emoji, subtitle: '📖 ${set.cards.length} cards', count: set.cards.length, payload: set));
    }
    return out;
  }

  List<LibExtra> _extras(BuildContext context, List<LibItem> scope, String name) {
    final cards = <LearnCard>[];
    for (final it in scope) {
      final p = it.payload;
      if (p is LearnSet) cards.addAll(p.cards);
    }
    if (scope.length < 2 || cards.isEmpty) return <LibExtra>[];
    return <LibExtra>[
      LibExtra(
        emoji: '📖',
        title: 'Learn all',
        subtitle: '${cards.length} cards',
        colors: const <Color>[Color(0xFF00897B), Color(0xFF26C6DA)],
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => LearnGridScreen(set: LearnSet(name.isEmpty ? 'Everything' : name, '📚', cards))),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LibraryBrowser(
      title: '📚 Quick Learn',
      myClassId: PlayerStore.active.libClass,
      emptyText: 'Nothing to learn yet.\nAdd words, quizzes or study lists first.',
      loader: _load,
      onOpen: (LibItem item) async {
        final p = item.payload;
        if (p is LearnSet) {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LearnGridScreen(set: p)));
        }
      },
      extras: (List<LibItem> scope, String name) => _extras(context, scope, name),
      onOpenChapter: (String chapter, String trail, List<LibItem> items) =>
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChapterScreen(title: chapter, trail: trail, items: items))),
      onOpenJourney: (String trail, List<String> chapters, Map<String, List<LibItem>> items) =>
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => JourneyScreen(title: trail, chapters: chapters, items: items))),
      actions: (double s, Future<void> Function() reload) => <Widget>[],
    );
  }
}

// ----------------------------------------------------------------------
// MANY CARDS ON ONE COLOURFUL PAGE
// ----------------------------------------------------------------------
Widget learnTable(LearnCard c, double s, double w, {required bool Function(int row) shown, required int nextRow}) {
  final n = c.rows.length;
  final twoCols = n > 5;
  final perCol = twoCols ? (n / 2).ceil() : n;
  final cols = <Widget>[];
  for (var start = 0; start < n; start += perCol) {
    final end = math.min(n, start + perCol);
    final items = <Widget>[];
    for (var r = start; r < end; r++) {
      final on = shown(r);
      final isNext = r == nextRow;
      items.add(Container(
        margin: EdgeInsets.symmetric(vertical: 4 * s),
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: kTopicGradients[r % kTopicGradients.length]),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: isNext ? const Color(0xFFFDE047) : Colors.white30, width: isNext ? 3 * s : 1.5 * s),
        ),
        child: Row(
          children: [
            Expanded(child: Text(c.rows[r][0], style: kidText(28 * s))),
            SizedBox(width: 8 * s),
            Expanded(
              child: Container(
                alignment: Alignment.centerRight,
                padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 2 * s),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF16A34A).withOpacity(0.85) : Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10 * s),
                ),
                child: Text(on ? c.rows[r][1] : '❓', textAlign: TextAlign.right, style: kidText(28 * s, c: on ? Colors.white : Colors.white60)),
              ),
            ),
          ],
        ),
      ));
    }
    cols.add(SizedBox(width: twoCols ? (w - 24 * s) / 2 : w, child: Column(mainAxisSize: MainAxisSize.min, children: items)));
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (c.front.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 8 * s),
          child: Text(c.front, textAlign: TextAlign.center, style: kidText(32 * s)),
        ),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cols.length; i++) ...[
            if (i > 0) SizedBox(width: 24 * s),
            cols[i],
          ],
        ],
      ),
    ],
  );
}

class LearnGridScreen extends StatefulWidget {
  final LearnSet set;
  const LearnGridScreen({super.key, required this.set});
  @override
  State<LearnGridScreen> createState() => _LearnGridScreenState();
}

class _LearnGridScreenState extends State<LearnGridScreen> {
  int _mode = 0; // 0 show answers, 1 hide answers, 2 auto play
  int _start = 0;
  int _perPage = 6;
  final Set<int> _shown = <int>{};
  final Map<int, int> _rowsShown = <int, int>{};
  int _cur = -1;
  int _auto = 0;
  bool _playing = false;

  List<LearnCard> get _cards => widget.set.cards;

  @override
  void dispose() {
    _auto++;
    Speaker.instance.stop();
    super.dispose();
  }

  // ----------------------------------------------------------------- pages
  List<int> _starts(int per) {
    final out = <int>[];
    var i = 0;
    final n = _cards.length;
    while (i < n) {
      out.add(i);
      if (_cards[i].isTable) {
        i++;
      } else {
        var c = 0;
        while (i < n && c < per && !_cards[i].isTable) {
          i++;
          c++;
        }
      }
    }
    return out;
  }

  List<int> _pageIndices(int start, int per) {
    final n = _cards.length;
    if (start >= n) return <int>[];
    if (_cards[start].isTable) return <int>[start];
    final out = <int>[];
    var i = start;
    while (i < n && out.length < per && !_cards[i].isTable) {
      out.add(i);
      i++;
    }
    return out;
  }

  int _pageNumber(int per) {
    final st = _starts(per);
    var idx = 0;
    for (var k = 0; k < st.length; k++) {
      if (st[k] <= _start) idx = k;
    }
    return idx;
  }

  void _stopAuto() {
    _auto++;
    _playing = false;
    Speaker.instance.stop();
  }

  void _goPage(int delta) {
    final st = _starts(_perPage);
    if (st.isEmpty) return;
    final k = _pageNumber(_perPage);
    _stopAuto();
    setState(() {
      _start = st[((k + delta) % st.length + st.length) % st.length];
      _cur = -1;
    });
  }

  // --------------------------------------------------------------- reveal
  bool _isShown(int idx) => _mode == 0 || _shown.contains(idx);

  int _rowsOf(int idx) => _mode == 0 ? _cards[idx].rows.length : (_rowsShown[idx] ?? 0);

  void _onCard(int idx) {
    final c = _cards[idx];
    if (_mode == 1) {
      setState(() {
        if (c.isTable) {
          _rowsShown[idx] = math.min(c.rows.length, (_rowsShown[idx] ?? 0) + 1);
        } else if (_shown.contains(idx)) {
          _shown.remove(idx);
        } else {
          _shown.add(idx);
        }
      });
      if (!c.isTable && _shown.contains(idx)) Speaker.instance.speak(learnSpokenBack(c));
      return;
    }
    _speakCard(idx);
  }

  void _speakCard(int idx) {
    final c = _cards[idx];
    final parts = <String>[];
    final front = learnSpokenFront(c);
    if (front.isNotEmpty) parts.add(front);
    if (_isShown(idx) || _mode == 0) {
      if (c.isTable) {
        for (var r = 0; r < c.rows.length; r++) {
          parts.addAll(learnRowParts(c, r));
        }
      } else {
        parts.add(learnSpokenBack(c));
      }
    }
    Speaker.instance.speakAll(parts);
  }

  void _revealPage() {
    final idxs = _pageIndices(_start, _perPage);
    final allOn = idxs.every((int i) => _cards[i].isTable ? (_rowsShown[i] ?? 0) >= _cards[i].rows.length : _shown.contains(i));
    setState(() {
      for (final i in idxs) {
        if (allOn) {
          _shown.remove(i);
          _rowsShown.remove(i);
        } else {
          _shown.add(i);
          if (_cards[i].isTable) _rowsShown[i] = _cards[i].rows.length;
        }
      }
    });
  }

  void _sayPage() {
    final parts = <String>[];
    for (final idx in _pageIndices(_start, _perPage)) {
      final c = _cards[idx];
      final front = learnSpokenFront(c);
      if (front.isNotEmpty) parts.add(front);
      if (_isShown(idx)) {
        if (c.isTable) {
          for (var r = 0; r < _rowsOf(idx); r++) {
            parts.addAll(learnRowParts(c, r));
          }
        } else {
          parts.add(learnSpokenBack(c));
        }
      }
    }
    Speaker.instance.speakAll(parts);
  }

  // ------------------------------------------------------------ auto play
  void _setMode(int m) {
    _stopAuto();
    setState(() {
      _mode = m;
      _cur = -1;
      _shown.clear();
      _rowsShown.clear();
    });
    if (m == 2) {
      setState(() => _playing = true);
      _autoLoop();
    }
  }

  void _togglePlay() {
    if (_playing) {
      _stopAuto();
      setState(() {});
    } else {
      setState(() => _playing = true);
      _autoLoop();
    }
  }

  Future<void> _autoLoop() async {
    final my = ++_auto;
    while (mounted && my == _auto) {
      final idxs = _pageIndices(_start, _perPage);
      setState(() {
        for (final i in idxs) {
          _shown.remove(i);
          _rowsShown.remove(i);
        }
      });
      for (final idx in idxs) {
        if (!mounted || my != _auto) return;
        final c = _cards[idx];
        setState(() => _cur = idx);
        final front = learnSpokenFront(c);
        if (front.isNotEmpty) await Speaker.instance.speak(front);
        if (!mounted || my != _auto) return;
        await Future<void>.delayed(Duration(milliseconds: c.isTable ? 700 : (c.spell ? 2200 : 2600)));
        if (!mounted || my != _auto) return;
        if (c.isTable) {
          for (var r = 1; r <= c.rows.length; r++) {
            if (!mounted || my != _auto) return;
            setState(() => _rowsShown[idx] = r);
            await Speaker.instance.speakAll(learnRowParts(c, r - 1));
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
        } else {
          setState(() => _shown.add(idx));
          await Speaker.instance.speak(learnSpokenBack(c));
        }
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      if (!mounted || my != _auto) return;
      final st = _starts(_perPage);
      final k = _pageNumber(_perPage);
      setState(() {
        _start = st[(k + 1) % st.length];
        _cur = -1;
      });
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.f1 || k == LogicalKeyboardKey.colorF2Yellow) {
      _sayPage();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.mediaTrackNext || k == LogicalKeyboardKey.colorF1Green) {
      _goPage(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.mediaTrackPrevious || k == LogicalKeyboardKey.colorF3Blue) {
      _goPage(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ----------------------------------------------------------------- cards
  Widget _qaCard(int idx, double w, double h, double s) {
    final c = _cards[idx];
    final on = _isShown(idx);
    final isCur = idx == _cur;
    var ans = c.back;
    if (c.options.isNotEmpty && c.correct >= 0) ans = '${optionLetter(c.correct)}.  ${c.back}';
    return TVFocusable(
      onPressed: () => _onCard(idx),
      scale: 1.04,
      builder: (BuildContext context, bool focused) => Container(
        width: w,
        height: h,
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: kTopicGradients[idx % kTopicGradients.length], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18 * s),
          border: Border.all(color: (focused || isCur) ? Colors.white : Colors.white30, width: (focused || isCur) ? 4 * s : 2 * s),
          boxShadow: (focused || isCur) ? [BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 16)] : const <BoxShadow>[],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: math.max(40.0, w - 26 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${idx + 1}.  ${c.front}', style: kidText(22 * s)),
                SizedBox(height: 6 * s),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFF16A34A).withOpacity(0.9) : Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(12 * s),
                  ),
                  child: Text(on ? ans : '❓  tap to see', style: kidText(24 * s, c: on ? Colors.white : Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _spellCard(int idx, double w, double h, double s) {
    final c = _cards[idx];
    final on = _isShown(idx);
    final isCur = idx == _cur;
    final pic = math.max(30.0, math.min(w - 20 * s, h * 0.58));
    final path = c.imagePath;
    Widget picture;
    if (path != null && File(path).existsSync()) {
      picture = ClipRRect(
        borderRadius: BorderRadius.circular(14 * s),
        child: Image.file(File(path), width: pic, height: pic, fit: BoxFit.cover, errorBuilder: (BuildContext x, Object e, StackTrace? st) => Text(c.emoji, style: TextStyle(fontSize: pic * 0.6))),
      );
    } else {
      picture = Text(c.emoji, style: TextStyle(fontSize: pic * 0.6));
    }
    return TVFocusable(
      onPressed: () => _onCard(idx),
      scale: 1.05,
      builder: (BuildContext context, bool focused) => Container(
        width: w,
        height: h,
        padding: EdgeInsets.all(6 * s),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: kTopicGradients[idx % kTopicGradients.length], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18 * s),
          border: Border.all(color: (focused || isCur) ? Colors.white : Colors.white30, width: (focused || isCur) ? 4 * s : 2 * s),
          boxShadow: (focused || isCur) ? [BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 16)] : const <BoxShadow>[],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: pic, height: pic, child: Center(child: picture)),
              SizedBox(height: 4 * s),
              Text(on ? c.back : c.back.split('').map((String _) => '_').join(' '), style: kidText(on ? 30 * s : 24 * s, c: on ? Colors.white : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(double s) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      if (_cards.isEmpty) return Center(child: Text('Nothing here yet.', style: kidText(26 * s)));
      if (_start >= _cards.length) _start = 0;
      final first = _cards[_start];
      final frame = BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24 * s),
        border: Border.all(color: Colors.white30, width: 2 * s),
      );
      if (first.isTable) {
        final idx = _start;
        final on = _mode == 0;
        final next = _mode == 1 ? (_rowsShown[idx] ?? 0) : -1;
        return TVFocusable(
          onPressed: () => _onCard(idx),
          scale: 1.01,
          builder: (BuildContext context, bool focused) => Container(
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.all(8 * s),
            decoration: frame.copyWith(border: Border.all(color: focused ? Colors.white : Colors.white30, width: focused ? 4 * s : 2 * s)),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: box.maxWidth * 0.92,
                  child: learnTable(first, s, box.maxWidth * 0.92, shown: (int r) => on || r < _rowsOf(idx), nextRow: next),
                ),
              ),
            ),
          ),
        );
      }
      final spell = first.spell;
      final gap = 12.0 * s;
      final minW = (spell ? 150 : 300) * s;
      final minH = (spell ? 170 : 96) * s;
      final cols = math.min(spell ? 6 : 4, math.max(1, ((box.maxWidth + gap) / (minW + gap)).floor()));
      final rows = math.min(6, math.max(1, ((box.maxHeight + gap) / (minH + gap)).floor()));
      _perPage = cols * rows;
      final cw = (box.maxWidth - gap * (cols - 1)) / cols;
      final ch = (box.maxHeight - gap * (rows - 1)) / rows;
      final idxs = _pageIndices(_start, _perPage);
      final lines = <Widget>[];
      for (var r = 0; r < rows; r++) {
        final cells = <Widget>[];
        for (var c = 0; c < cols; c++) {
          final k = r * cols + c;
          if (k < idxs.length) {
            cells.add(spell ? _spellCard(idxs[k], cw, ch, s) : _qaCard(idxs[k], cw, ch, s));
          } else {
            cells.add(SizedBox(width: cw, height: ch));
          }
          if (c < cols - 1) cells.add(SizedBox(width: gap));
        }
        lines.add(Row(mainAxisAlignment: MainAxisAlignment.center, children: cells));
        if (r < rows - 1) lines.add(SizedBox(height: gap));
      }
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: lines);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final title = '${widget.set.emoji} ${widget.set.title}';
    final st = _starts(_perPage);
    final page = _pageNumber(_perPage) + 1;

    Widget primary;
    if (_mode == 0) {
      primary = ActionButton(key: const ValueKey<String>('primary'), s: s, icon: Icons.arrow_forward_rounded, label: 'Next page', color: const Color(0xFF22C55E), autofocus: true, onPressed: () => _goPage(1));
    } else if (_mode == 1) {
      primary = ActionButton(key: const ValueKey<String>('primary'), s: s, icon: Icons.visibility_rounded, label: 'Show / hide page', color: const Color(0xFF3B82F6), autofocus: true, onPressed: _revealPage);
    } else {
      primary = ActionButton(
        key: const ValueKey<String>('primary'),
        s: s,
        icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        label: _playing ? 'Pause' : 'Play',
        color: const Color(0xFF22C55E),
        autofocus: true,
        onPressed: _togglePlay,
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: ScreenFrame(
        title: title,
        actions: [Text('Page $page / ${st.length}', style: kidText(24 * s))],
        body: Column(
          children: [
            ButtonRow(
              spacing: 12 * s,
              children: [
                ChoiceChipTV(label: '📖 Show answers', selected: _mode == 0, s: s, onPressed: () => _setMode(0)),
                ChoiceChipTV(label: '🙈 Hide answers', selected: _mode == 1, s: s, onPressed: () => _setMode(1)),
                ChoiceChipTV(label: '▶ Auto play', selected: _mode == 2, s: s, onPressed: () => _setMode(2)),
              ],
            ),
            SizedBox(height: 8 * s),
            Expanded(child: _grid(s)),
            SizedBox(height: 10 * s),
            ButtonRow(
              spacing: 12 * s,
              children: [
                ActionButton(s: s, icon: Icons.skip_previous_rounded, label: 'Page', color: const Color(0xFF6366F1), onPressed: () => _goPage(-1)),
                primary,
                if (_mode != 0) ActionButton(s: s, icon: Icons.skip_next_rounded, label: 'Page', color: const Color(0xFF6366F1), onPressed: () => _goPage(1)),
                ActionButton(s: s, icon: Icons.volume_up_rounded, label: 'Say', color: const Color(0xFF00ACC1), onPressed: _sayPage),
                ActionButton(
                  s: s,
                  icon: Icons.zoom_in_rounded,
                  label: 'One by one',
                  color: const Color(0xFF7E57C2),
                  onPressed: () {
                    _stopAuto();
                    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => LearnScreen(set: widget.set)));
                  },
                ),
              ],
            ),
            SizedBox(height: 6 * s),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// ONE BIG CARD AT A TIME
// ----------------------------------------------------------------------
class LearnScreen extends StatefulWidget {
  final LearnSet set;
  const LearnScreen({super.key, required this.set});
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late List<LearnCard> _cards;
  final Map<String, int> _again = <String, int>{};
  int _mode = 0; // 0 show answers, 1 hide answers, 2 auto play
  int _i = 0;
  int _rows = 0; // answers revealed so far (table rows, or 0/1)
  int _known = 0;
  int _needAgain = 0;
  bool _finished = false;
  bool _playing = false;
  int _auto = 0;

  @override
  void initState() {
    super.initState();
    _cards = List<LearnCard>.of(widget.set.cards);
    _resetRows();
  }

  @override
  void dispose() {
    _auto++;
    Speaker.instance.stop();
    super.dispose();
  }

  LearnCard get _card => _cards[_i];
  int _fullRows(LearnCard c) => c.isTable ? c.rows.length : 1;
  bool get _allShown => _mode == 0 || _rows >= _fullRows(_card);

  void _resetRows() {
    _rows = _mode == 0 ? _fullRows(_card) : 0;
  }

  // ------------------------------------------------------------ speaking
  String _say(String t) {
    return t
        .replaceAll('×', ' times ')
        .replaceAll('²', ' squared ')
        .replaceAll('³', ' cubed ')
        .replaceAll('√', 'square root of ');
  }

  String _spokenFront(LearnCard c) => c.spell ? '' : c.front.replaceAll(RegExp(r'_{2,}'), ' blank ');

  String _spokenBack(LearnCard c) {
    if (c.spell) return '${c.back}. ${c.back.split('').join(', ')}';
    final note = c.note.isNotEmpty ? '. ${c.note}' : '';
    return '${c.back}$note';
  }

  String _spokenRow(LearnCard c, int r) {
    final l = c.rows[r][0];
    final v = c.rows[r][1];
    return c.math ? '${_say(l)} ${_say(v)}' : '$l, $v';
  }

  void _speakNow() {
    final c = _card;
    final parts = <String>[];
    final front = _spokenFront(c);
    if (front.isNotEmpty) parts.add(front);
    if (_allShown) {
      if (c.isTable) {
        for (var r = 0; r < c.rows.length; r++) {
          parts.addAll(learnRowParts(c, r));
        }
      } else {
        parts.add(_spokenBack(c));
      }
    }
    Speaker.instance.speakAll(parts);
  }

  // ----------------------------------------------------------- auto play
  void _stopAuto() {
    _auto++;
    _playing = false;
    Speaker.instance.stop();
  }

  void _startAuto() {
    _playing = true;
    _autoLoop();
  }

  Future<void> _autoLoop() async {
    final my = ++_auto;
    while (mounted && my == _auto) {
      final c = _card;
      setState(() => _rows = 0);
      final front = _spokenFront(c);
      if (front.isNotEmpty) await Speaker.instance.speak(front);
      if (!mounted || my != _auto) return;
      await Future<void>.delayed(Duration(milliseconds: c.isTable ? 900 : (c.spell ? 2500 : 3200)));
      if (!mounted || my != _auto) return;
      if (c.isTable) {
        for (var r = 1; r <= c.rows.length; r++) {
          if (!mounted || my != _auto) return;
          setState(() => _rows = r);
          await Speaker.instance.speakAll(learnRowParts(c, r - 1));
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      } else {
        setState(() => _rows = 1);
        await Speaker.instance.speak(_spokenBack(c));
      }
      if (!mounted || my != _auto) return;
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (!mounted || my != _auto) return;
      setState(() {
        _i = (_i + 1) % _cards.length;
        _rows = 0;
      });
    }
  }

  // ------------------------------------------------------------ actions
  void _setMode(int m) {
    _stopAuto();
    setState(() {
      _mode = m;
      _finished = false;
      _resetRows();
    });
    if (m == 2) {
      setState(() => _playing = true);
      _autoLoop();
    }
  }

  void _goTo(int index) {
    final n = _cards.length;
    setState(() {
      _i = ((index % n) + n) % n;
      _resetRows();
    });
  }

  void _next() => _goTo(_i + 1);
  void _prev() => _goTo(_i - 1);

  void _reveal() {
    setState(() {
      _rows = math.min(_fullRows(_card), _rows + 1);
    });
  }

  void _revealAll() {
    setState(() => _rows = _fullRows(_card));
  }

  void _advance() {
    if (_i + 1 >= _cards.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _i++;
      _resetRows();
    });
  }

  void _gotIt() {
    _known++;
    _advance();
  }

  void _againCard() {
    final c = _card;
    _needAgain++;
    if (c.key.isNotEmpty) Mastery.record(c.key, clean: false);
    final used = _again[c.key.isEmpty ? c.front + c.back : c.key] ?? 0;
    if (used < 2) {
      _again[c.key.isEmpty ? c.front + c.back : c.key] = used + 1;
      final at = math.min(_cards.length, _i + 4);
      _cards.insert(at, c);
    }
    _advance();
  }

  void _toggleAuto() {
    if (_playing) {
      _stopAuto();
      setState(() {});
    } else {
      setState(() => _playing = true);
      _autoLoop();
    }
  }

  void _primary() {
    if (_mode == 0) {
      _next();
    } else if (_mode == 2) {
      _toggleAuto();
    } else if (!_allShown) {
      _reveal();
    } else {
      _gotIt();
    }
  }

  void _restart() {
    setState(() {
      _cards = List<LearnCard>.of(widget.set.cards);
      _again.clear();
      _i = 0;
      _known = 0;
      _needAgain = 0;
      _finished = false;
      _resetRows();
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.f1 || k == LogicalKeyboardKey.colorF2Yellow) {
      _speakNow();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.mediaTrackNext || k == LogicalKeyboardKey.colorF1Green) {
      _primary();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.mediaTrackPrevious || k == LogicalKeyboardKey.colorF3Blue) {
      _prev();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.colorF0Red && _mode == 1 && _allShown) {
      _againCard();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------ card views
  Widget _tableView(LearnCard c, double s, double w) {
    final n = c.rows.length;
    final twoCols = n > 5;
    final perCol = twoCols ? (n / 2).ceil() : n;
    final cols = <Widget>[];
    for (var start = 0; start < n; start += perCol) {
      final end = math.min(n, start + perCol);
      final items = <Widget>[];
      for (var r = start; r < end; r++) {
        final shown = _mode == 0 || r < _rows;
        final isNext = _mode == 1 && r == _rows;
        items.add(Container(
          margin: EdgeInsets.symmetric(vertical: 4 * s),
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
          decoration: BoxDecoration(
            color: shown ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: isNext ? const Color(0xFFFDE047) : Colors.white24, width: isNext ? 3 * s : 1.5 * s),
          ),
          child: Row(
            children: [
              Expanded(child: Text(c.rows[r][0], style: kidText(30 * s))),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  shown ? c.rows[r][1] : '❓',
                  textAlign: TextAlign.right,
                  style: kidText(30 * s, c: shown ? const Color(0xFF86EFAC) : Colors.white54),
                ),
              ),
            ],
          ),
        ));
      }
      cols.add(SizedBox(width: twoCols ? (w - 24 * s) / 2 : w, child: Column(mainAxisSize: MainAxisSize.min, children: items)));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (c.front.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8 * s),
            child: Text(c.front, textAlign: TextAlign.center, style: kidText(32 * s)),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) SizedBox(width: 24 * s),
              cols[i],
            ],
          ],
        ),
      ],
    );
  }

  Widget _spellView(LearnCard c, double s, double w, double h) {
    final pic = math.min(h * 0.62, w * 0.55);
    final path = c.imagePath;
    final shown = _mode == 0 || _rows >= 1;
    Widget picture;
    if (path != null && File(path).existsSync()) {
      picture = ClipRRect(
        borderRadius: BorderRadius.circular(20 * s),
        child: Image.file(File(path), width: pic, height: pic, fit: BoxFit.cover, errorBuilder: (BuildContext x, Object e, StackTrace? st) => Text(c.emoji, style: TextStyle(fontSize: pic * 0.6))),
      );
    } else {
      picture = Text(c.emoji, style: TextStyle(fontSize: pic * 0.6));
    }
    final letters = c.back.split('');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: pic,
          height: pic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24 * s),
            border: Border.all(color: Colors.white, width: 4 * s),
            color: Colors.white.withOpacity(0.15),
          ),
          child: picture,
        ),
        SizedBox(height: 8 * s),
        Text(
          shown ? c.back : letters.map((String _) => '_').join(' '),
          style: kidText(shown ? 52 * s : 40 * s, c: shown ? const Color(0xFF86EFAC) : Colors.white70),
        ),
        SizedBox(
          height: 30 * s,
          child: shown ? Text(letters.join('  -  '), style: kidText(22 * s, w: FontWeight.w600)) : null,
        ),
      ],
    );
  }

  Widget _qaView(LearnCard c, double s, double w) {
    final shown = _mode == 0 || _rows >= 1;
    final optionWidgets = <Widget>[];
    for (var i = 0; i < c.options.length; i++) {
      final right = shown && i == c.correct;
      optionWidgets.add(Container(
        margin: EdgeInsets.symmetric(vertical: 3 * s),
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
        decoration: BoxDecoration(
          color: right ? const Color(0xFF22C55E) : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: right ? Colors.white : Colors.white24, width: 2 * s),
        ),
        child: Text('${optionLetter(i)}.  ${c.options[i]}', style: kidText(26 * s)),
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.front, textAlign: TextAlign.center, style: kidText(c.front.length > 70 ? 28 * s : 38 * s)),
        SizedBox(height: 8 * s),
        if (optionWidgets.isNotEmpty) Column(mainAxisSize: MainAxisSize.min, children: optionWidgets),
        if (optionWidgets.isEmpty)
          Container(
            width: w * 0.8,
            padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
            decoration: BoxDecoration(
              color: shown ? const Color(0xFF16A34A).withOpacity(0.85) : Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18 * s),
              border: Border.all(color: Colors.white54, width: 2 * s),
            ),
            child: Text(
              shown ? c.back : '❓',
              textAlign: TextAlign.center,
              style: kidText(40 * s, c: shown ? Colors.white : Colors.white54),
            ),
          ),
        if (shown && c.note.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8 * s),
            child: Text('💡 ${c.note}', textAlign: TextAlign.center, style: kidText(22 * s, w: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _cardArea(double s) {
    final c = _card;
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      Widget content;
      if (c.isTable) {
        content = _tableView(c, s, w * 0.92);
      } else if (c.spell) {
        content = _spellView(c, s, w, h);
      } else {
        content = _qaView(c, s, w);
      }
      return Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(10 * s),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(26 * s),
          border: Border.all(color: Colors.white30, width: 2 * s),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: w * 0.94, child: Center(child: content)),
          ),
        ),
      );
    });
  }

  Widget _primaryButton(double s) {
    if (_mode == 0) {
      return ActionButton(key: const ValueKey<String>('primary'), s: s, icon: Icons.arrow_forward_rounded, label: 'Next', color: const Color(0xFF22C55E), autofocus: true, onPressed: _next);
    }
    if (_mode == 2) {
      return ActionButton(
        key: const ValueKey<String>('primary'),
        s: s,
        icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        label: _playing ? 'Pause' : 'Play',
        color: const Color(0xFF22C55E),
        autofocus: true,
        onPressed: _toggleAuto,
      );
    }
    if (!_allShown) {
      return ActionButton(
        key: const ValueKey<String>('primary'),
        s: s,
        icon: Icons.visibility_rounded,
        label: _card.isTable ? 'Next answer' : 'Show answer',
        color: const Color(0xFF3B82F6),
        autofocus: true,
        onPressed: _reveal,
      );
    }
    return ActionButton(key: const ValueKey<String>('primary'), s: s, icon: Icons.check_circle_rounded, label: 'Got it', color: const Color(0xFF22C55E), autofocus: true, onPressed: _gotIt);
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final title = '${widget.set.emoji} ${widget.set.title}';

    if (_finished) {
      return ScreenFrame(
        title: title,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_needAgain == 0 ? '🌟' : '💪', style: TextStyle(fontSize: 70 * s)),
              Text('✅ $_known known   🔁 $_needAgain to practise again', style: kidText(32 * s)),
              SizedBox(height: 22 * s),
              ButtonRow(
                spacing: 16 * s,
                children: [
                  ActionButton(s: s, icon: Icons.replay_rounded, label: 'Learn again', color: const Color(0xFF22C55E), autofocus: true, onPressed: _restart),
                  ActionButton(s: s, icon: Icons.home_rounded, label: 'Back', color: const Color(0xFF5C6BC0), onPressed: () => Navigator.maybePop(context)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final hiddenRevealed = _mode == 1 && _allShown;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: ScreenFrame(
        title: title,
        actions: [Text('${_i + 1} / ${_cards.length}', style: kidText(26 * s))],
        body: Column(
          children: [
            ButtonRow(
              spacing: 12 * s,
              children: [
                ChoiceChipTV(label: '📖 Show answers', selected: _mode == 0, s: s, onPressed: () => _setMode(0)),
                ChoiceChipTV(label: '🙈 Hide answers', selected: _mode == 1, s: s, onPressed: () => _setMode(1)),
                ChoiceChipTV(label: '▶ Auto play', selected: _mode == 2, s: s, onPressed: () => _setMode(2)),
              ],
            ),
            SizedBox(height: 8 * s),
            Expanded(child: _cardArea(s)),
            SizedBox(height: 10 * s),
            ButtonRow(
              spacing: 14 * s,
              children: [
                ActionButton(s: s, icon: Icons.skip_previous_rounded, label: 'Previous', color: const Color(0xFF6366F1), onPressed: _prev),
                _primaryButton(s),
                if (_mode == 1 && !_allShown && _card.isTable)
                  ActionButton(s: s, icon: Icons.visibility_rounded, label: 'Show all', color: const Color(0xFF0EA5E9), onPressed: _revealAll),
                if (hiddenRevealed)
                  ActionButton(s: s, icon: Icons.replay_rounded, label: 'Again', color: const Color(0xFFEF4444), onPressed: _againCard),
                if (_mode == 2) ActionButton(s: s, icon: Icons.skip_next_rounded, label: 'Next', color: const Color(0xFF6366F1), onPressed: _next),
                ActionButton(s: s, icon: Icons.volume_up_rounded, label: 'Say', color: const Color(0xFF00ACC1), onPressed: _speakNow),
                ActionButton(
                  s: s,
                  icon: Icons.grid_view_rounded,
                  label: 'Many',
                  color: const Color(0xFF7E57C2),
                  onPressed: () {
                    _stopAuto();
                    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => LearnGridScreen(set: widget.set)));
                  },
                ),
              ],
            ),
            SizedBox(height: 6 * s),
          ],
        ),
      ),
    );
  }
}
