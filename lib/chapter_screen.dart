import 'package:flutter/material.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'kids_ui.dart';
import 'learn_model.dart';
import 'library.dart';
import 'players.dart';
import 'quick_learn.dart';
import 'quiz_game.dart';
import 'quiz_model.dart';
import 'spelling_game.dart';

/// The Chapter page: one chapter, three clear steps (Read, Words, Quiz).
/// It only shows the steps this chapter really has, and a progress bar for each.
class ChapterScreen extends StatefulWidget {
  final String title; // e.g. "Ch 3: Subtraction"
  final String trail; // e.g. "Class 2 › Maths"
  final List<LibItem> items;
  const ChapterScreen({super.key, required this.title, required this.trail, required this.items});
  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  bool _loaded = false;
  List<LearnCard> _cards = <LearnCard>[];
  List<WordCard> _words = <WordCard>[];
  List<QuizSet> _sets = <QuizSet>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = <LearnCard>[];
    final docs = widget.items.any((LibItem i) => i.kind == 'learn' && i.payload is! LearnSet) ? await LearnStore.loadAll() : <LearnDoc>[];
    for (final it in widget.items) {
      final p = it.payload;
      if (p is LearnSet && it.kind == 'learn') {
        cards.addAll(p.cards);
      } else if (it.kind == 'learn') {
        for (final d in docs) {
          if (d.id == it.id) cards.addAll(d.cards);
        }
      }
    }
    final topics = widget.items.where((LibItem i) => i.kind == 'spell').map((LibItem i) => i.id).toSet();
    final ids = widget.items.where((LibItem i) => i.kind == 'quiz').map((LibItem i) => i.id).toSet();
    final words = topics.isEmpty ? <WordCard>[] : (await CardStore.loadCards()).where((WordCard c) => topics.contains(c.topic)).toList();
    final sets = ids.isEmpty ? <QuizSet>[] : (await QuizStore.loadAll()).where((QuizSet q) => ids.contains(q.id)).toList();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _words = words;
      _sets = sets;
      _loaded = true;
    });
  }

  String _wk(WordCard c) => 'spell:${c.word}';

  int get _quizTotal => _sets.fold<int>(0, (int a, QuizSet q) => a + q.questions.length);
  int get _quizDone {
    var n = 0;
    return n;
  }

  Future<void> _read() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LearnGridScreen(set: LearnSet(widget.title, '\u{1F4D8}', _cards))));
  }

  Future<void> _playWords() async {
    final smart = PlayerStore.active.smart;
    var deck = List<WordCard>.of(_words);
    if (smart) {
      final left = Mastery.notMastered<WordCard>(_words, _wk);
      if (left.isNotEmpty) deck = List<WordCard>.of(left);
    }
    deck.shuffle();
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => TVGameScreen(deck: deck, title: widget.title, session: smart)));
    if (mounted) setState(() {});
  }

  double get _overall {
    final wDone = Mastery.masteredIn<WordCard>(_words, _wk);
    final total = _words.length;
    return total == 0 ? 0 : wDone / total;
  }

  /// Test: a short round of this chapter's questions, mixed, no repeats of the same question.
  Future<void> _playTest() async {
    List<QuizItem> build() {
      final list = <QuizItem>[for (final set in _sets) for (final q in set.questions) QuizItem(set.id, q)]..shuffle();
      return list.take(PlayerStore.active.rounds).toList();
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => QuizPlayScreen(title: '${widget.title} Test', emoji: '\u{1F3C6}', scoreId: 'test:${widget.title}', builder: build)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _playQuiz() async {
    List<QuizItem> build() {
      var list = <QuizItem>[for (final set in _sets) for (final q in set.questions) QuizItem(set.id, q)];
      list.shuffle();
      return list;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => QuizPlayScreen(title: widget.title, emoji: '\u{1F9E0}', scoreId: 'ch:${widget.title}', builder: build)),
    );
    if (mounted) setState(() {});
  }

  Widget _step(double s, {required int n, required String title, required String text, required double progress, required String button, required Color color, required VoidCallback onTap, bool first = false, bool locked = false}) {
    final done = progress >= 1;
    return TVFocusable(
      autofocus: first,
      scale: 1.04,
      onPressed: onTap,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.all(18 * s),
        decoration: BoxDecoration(
          color: const Color(0xFF181B3A),
          borderRadius: BorderRadius.circular(24 * s),
          border: Border.all(color: focused ? Colors.white : color.withOpacity(0.5), width: focused ? 4 : 2),
          boxShadow: focused ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 28)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              CircleAvatar(radius: 18 * s, backgroundColor: color, child: locked ? const Icon(Icons.lock_rounded, color: Colors.black87, size: 18) : done ? const Icon(Icons.check_rounded, color: Colors.black87) : Text('$n', style: kidText(18 * s, c: Colors.black87))),
              SizedBox(width: 10 * s),
              Text(title, style: kidText(26 * s)),
            ]),
            SizedBox(height: 8 * s),
            Text(text, style: kidText(16 * s, w: FontWeight.w600)),
            SizedBox(height: 10 * s),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0).toDouble(), minHeight: 8 * s, color: const Color(0xFF35D0BA), backgroundColor: const Color(0xFF2A2E63)),
            ),
            SizedBox(height: 12 * s),
            Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 10 * s),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30 * s)),
              child: Text(button, style: kidText(20 * s, c: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(double s, int stepCount) {
    final pct = (_overall.clamp(0.0, 1.0) * 100).round();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12 * s),
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
      decoration: BoxDecoration(color: const Color(0xFF181B3A), borderRadius: BorderRadius.circular(22 * s)),
      child: Row(children: [
        SizedBox(
          width: 56 * s,
          height: 56 * s,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 56 * s,
              height: 56 * s,
              child: CircularProgressIndicator(value: _overall.clamp(0.0, 1.0).toDouble(), strokeWidth: 7 * s, color: const Color(0xFF35D0BA), backgroundColor: const Color(0xFF2A2E63)),
            ),
            Text('$pct%', style: kidText(14 * s)),
          ]),
        ),
        SizedBox(width: 14 * s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.trail.isNotEmpty) Text(widget.trail, style: kidText(13 * s, w: FontWeight.w600, c: const Color(0xFFA9ADDB))),
            Text(widget.title, style: kidText(20 * s), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_words.isEmpty ? '$stepCount steps' : '$pct% of the words learned  \u2022  $stepCount steps', style: kidText(13 * s, w: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    if (!_loaded) {
      return ScreenFrame(title: widget.title, body: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final steps = <Widget>[];
    var n = 0;
    if (_cards.isNotEmpty) {
      n++;
      steps.add(_step(s, n: n, title: 'Read', text: '${_cards.length} study cards with answers.', progress: 0, button: 'Open', color: const Color(0xFF4C7BF0), onTap: _read, first: steps.isEmpty));
    }
    if (_words.isNotEmpty) {
      n++;
      final done = Mastery.masteredIn<WordCard>(_words, _wk);
      steps.add(_step(s, n: n, title: 'Words', text: '${_words.length} spelling words. $done mastered.', progress: done / _words.length, button: done == 0 ? 'Start' : 'Continue', color: const Color(0xFFFFB84D), onTap: _playWords, first: steps.isEmpty));
    }
    if (_sets.isNotEmpty) {
      n++;
      steps.add(_step(s, n: n, title: 'Quiz', text: '$_quizTotal questions.', progress: 0, button: 'Start', color: const Color(0xFFF2709C), onTap: _playQuiz, first: steps.isEmpty));
    }
    if (_sets.isNotEmpty) {
      n++;
      const open = true;
      steps.add(_step(s, n: n, title: 'Test', text: open ? 'A mixed round of ${PlayerStore.active.rounds} questions.' : 'Opens when ready.', progress: _overall, button: open ? 'Start Test' : '80% needed', color: open ? const Color(0xFF35D0BA) : const Color(0xFF5A5FA6), onTap: _playTest, locked: !open));
    }
    final phone = isPhone(context);
    final body = steps.isEmpty
        ? Center(child: Text('This chapter is empty.', style: kidText(24 * s)))
        : phone
            ? ListView.separated(padding: EdgeInsets.all(12 * s), itemCount: steps.length, separatorBuilder: (_, __) => SizedBox(height: 14 * s), itemBuilder: (_, int i) => steps[i])
            : Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final w in steps) Padding(padding: EdgeInsets.symmetric(horizontal: 10 * s), child: SizedBox(width: 250 * s, child: w))],
                ),
              );
    return ScreenFrame(
      title: '\u{1F4D8} ${widget.title}',
      body: Column(children: [
        _header(s, steps.length),
        SizedBox(height: 10 * s),
        Expanded(child: body),
        Padding(
          padding: EdgeInsets.only(top: 6 * s),
          child: Text(
            'Do the steps in order, or pick any. Wrong answers come back so you can learn them.',
            textAlign: TextAlign.center,
            style: kidText(13 * s, w: FontWeight.w600, c: const Color(0xFFA9ADDB)),
          ),
        ),
      ]),
    );
  }
}
