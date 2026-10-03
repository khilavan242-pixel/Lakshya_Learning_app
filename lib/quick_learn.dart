import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';
import 'kids_ui.dart';
import 'players.dart';
import 'quiz_model.dart';
import 'speech_service.dart';

// ======================================================================
// QUICK LEARN: study the content of every game before (or instead of) playing.
//   📖 Show answers  - everything visible, like a textbook page
//   🙈 Hide answers  - self test: say it, reveal it, press "Got it" or "Again"
//   ▶ Auto play      - the TV reads the questions and answers by itself
// Sources: spelling words, quiz questions (including matching tables), maths facts.
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
}

class LearnSet {
  final String title;
  final String emoji;
  final List<LearnCard> cards;
  const LearnSet(this.title, this.emoji, this.cards);
}

class LearnSources {
  /// Spelling words of the topics this player may use, one set per topic + "All words".
  static Future<List<LearnSet>> spelling() async {
    final all = await CardStore.loadCards();
    final allowed = PlayerStore.active.spellingTopics;
    var cards = allowed == null ? all : all.where((c) => allowed.contains(c.topic)).toList();
    if (cards.isEmpty) cards = all;
    final byTopic = <String, List<LearnCard>>{};
    final every = <LearnCard>[];
    for (final c in cards) {
      final lc = LearnCard(front: '', back: c.word, imagePath: c.imagePath, emoji: emojiForTopic(c.topic), key: 'spell:${c.word}', spell: true);
      every.add(lc);
      byTopic.putIfAbsent(c.topic, () => <LearnCard>[]).add(lc);
    }
    final out = <LearnSet>[];
    if (every.isNotEmpty) out.add(LearnSet('All words', '📚', every));
    byTopic.forEach((String topic, List<LearnCard> list) {
      out.add(LearnSet(topic, emojiForTopic(topic), list));
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
      out.add(LearnSet(set.title, set.emoji, set.questions.map((QuizQuestion q) => _fromQuestion(set.id, q)).toList()));
    }
    return out;
  }

  static List<LearnSet> mathFacts() {
    final allowed = PlayerStore.active.mathTopics;
    bool ok(String id) => allowed == null || allowed.contains(id);
    final out = <LearnSet>[];

    List<LearnCard> chunk(String title, List<List<String>> rows, int per) {
      final cards = <LearnCard>[];
      for (var i = 0; i < rows.length; i += per) {
        final end = math.min(rows.length, i + per);
        cards.add(LearnCard(front: title, rows: rows.sublist(i, end), math: true, emoji: '🧮'));
      }
      return cards;
    }

    void build(bool force) {
      if (force || ok('multiplication')) {
        final tables = <LearnCard>[];
        for (var n = 2; n <= 20; n++) {
          final rows = <List<String>>[for (var k = 1; k <= 10; k++) <String>['$n × $k =', '${n * k}']];
          tables.add(LearnCard(front: 'Table of $n', rows: rows, math: true, emoji: '✖️'));
        }
        out.add(LearnSet('Multiplication tables', '✖️', tables));
      }
      if (force || ok('exponents')) {
        out.add(LearnSet('Squares', '⚡', chunk('Squares', <List<String>>[for (var n = 1; n <= 30; n++) <String>['$n² =', '${n * n}']], 10)));
        out.add(LearnSet('Cubes', '🧊', chunk('Cubes', <List<String>>[for (var n = 1; n <= 15; n++) <String>['$n³ =', '${n * n * n}']], 8)));
      }
      if (force || ok('squareroot')) {
        out.add(LearnSet('Square roots', '√', chunk('Square roots', <List<String>>[for (var n = 1; n <= 20; n++) <String>['√${n * n} =', '$n']], 10)));
      }
    }

    build(false);
    if (out.isEmpty) build(true);
    return out;
  }
}

// ----------------------------------------------------------------------
// CHOOSE WHAT TO LEARN
// ----------------------------------------------------------------------
class QuickLearnHome extends StatelessWidget {
  const QuickLearnHome({super.key});

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    Widget Function(double, double) tile(String emoji, String title, String sub, List<Color> colors, String group, bool first) {
      return (double w, double h) => BigTile(
            emoji: emoji,
            title: title,
            subtitle: sub,
            colors: colors,
            s: s,
            width: w / s,
            height: h / s,
            autofocus: first,
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => QuickLearnTopics(group: group))),
          );
    }

    final tiles = <Widget Function(double, double)>[
      tile('✏️', 'Spelling words', 'Pictures & letters', const <Color>[Color(0xFFFF9A44), Color(0xFFFC6076)], 'spelling', true),
      tile('🧠', 'Quiz questions', 'Questions & answers', const <Color>[Color(0xFFB24592), Color(0xFFF15F79)], 'quiz', false),
      tile('🧮', 'Maths facts', 'Tables, squares, roots', const <Color>[Color(0xFF36D1DC), Color(0xFF5B86E5)], 'math', false),
    ];
    return ScreenFrame(
      title: '📖 Quick Learn',
      body: Column(
        children: [
          Text('Study first, then play! What do you want to learn?', style: kidText(22 * s, w: FontWeight.w600)),
          Expanded(child: AdaptiveGrid(builders: tiles, aspect: 1.1, minWidth: 150 * s, maxWidth: 270 * s, gap: 22 * s)),
        ],
      ),
    );
  }
}

class QuickLearnTopics extends StatefulWidget {
  final String group; // spelling | quiz | math
  const QuickLearnTopics({super.key, required this.group});
  @override
  State<QuickLearnTopics> createState() => _QuickLearnTopicsState();
}

class _QuickLearnTopicsState extends State<QuickLearnTopics> {
  List<LearnSet> _sets = <LearnSet>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<LearnSet> sets;
    if (widget.group == 'spelling') {
      sets = await LearnSources.spelling();
    } else if (widget.group == 'quiz') {
      sets = await LearnSources.quizzes();
    } else {
      sets = LearnSources.mathFacts();
    }
    if (!mounted) return;
    setState(() {
      _sets = sets.where((LearnSet x) => x.cards.isNotEmpty).toList();
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final title = widget.group == 'spelling' ? '✏️ Spelling words' : (widget.group == 'quiz' ? '🧠 Quiz questions' : '🧮 Maths facts');
    Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white));
    } else if (_sets.isEmpty) {
      body = Center(child: Text('Nothing to learn here yet.', style: kidText(26 * s)));
    } else {
      final tiles = <Widget Function(double, double)>[];
      for (var i = 0; i < _sets.length; i++) {
        final set = _sets[i];
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
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LearnScreen(set: set))),
            ));
      }
      body = AdaptiveGrid(builders: tiles, aspect: 1.2, minWidth: 150 * s, maxWidth: 260 * s, gap: 20 * s);
    }
    return ScreenFrame(title: title, body: body);
  }
}

// ----------------------------------------------------------------------
// THE LEARNING SCREEN
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
          parts.add(_spokenRow(c, r));
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
          await Speaker.instance.speak(_spokenRow(c, r - 1));
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
        child: Text('${i + 1}.  ${c.options[i]}', style: kidText(26 * s)),
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
              ],
            ),
            SizedBox(height: 6 * s),
          ],
        ),
      ),
    );
  }
}
