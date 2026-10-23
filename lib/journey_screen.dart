import 'package:flutter/material.dart';
import 'app_store.dart';
import 'chapter_screen.dart';
import 'core_audio_models.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'players.dart';
import 'quiz_model.dart';

/// Subject Journey: the chapters of one subject as a path. Finished chapters are ticked,
/// the next one to do glows. Any chapter can be opened.
class JourneyScreen extends StatefulWidget {
  final String title; // "Class 2 › Maths"
  final List<String> chapters; // in order
  final Map<String, List<LibItem>> items; // chapter -> items
  const JourneyScreen({super.key, required this.title, required this.chapters, required this.items});
  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  bool _loaded = false;
  List<WordCard> _words = <WordCard>[];
  List<QuizSet> _sets = <QuizSet>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await CardStore.loadCards();
    final q = await QuizStore.loadAll();
    if (!mounted) return;
    setState(() {
      _words = w;
      _sets = q;
      _loaded = true;
    });
  }

  /// 0..1 share of this chapter's words and quiz questions that are mastered. -1 = nothing to practise.
  double _progress(String ch) {
    final its = widget.items[ch] ?? <LibItem>[];
    final topics = its.where((LibItem i) => i.kind == 'spell').map((LibItem i) => i.id).toSet();
    final ids = its.where((LibItem i) => i.kind == 'quiz').map((LibItem i) => i.id).toSet();
    var total = 0;
    var done = 0;
    for (final c in _words) {
      if (!topics.contains(c.topic)) continue;
      total++;
      if (Mastery.isMastered('spell:${c.word}')) done++;
    }
    for (final set in _sets) {
      if (!ids.contains(set.id)) continue;
      for (final q in set.questions) {
        total++;
        if (Mastery.isMastered('quiz:${set.id}:${q.question}')) done++;
      }
    }
    return total == 0 ? -1 : done / total;
  }

  Future<void> _open(String ch) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ChapterScreen(title: ch, trail: widget.title, items: widget.items[ch] ?? <LibItem>[])),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    if (!_loaded) return ScreenFrame(title: '\u{1F5FA}️ ${widget.title}', body: const Center(child: CircularProgressIndicator(color: Colors.white)));
    final prog = <String, double>{for (final c in widget.chapters) c: _progress(c)};
    var current = widget.chapters.indexWhere((String c) => prog[c]! < 1);
    if (current < 0) current = 0;
    final rows = <Widget>[];
    for (var i = 0; i < widget.chapters.length; i++) {
      final ch = widget.chapters[i];
      final p = prog[ch]!;
      final done = p >= 1;
      final isCur = i == current && !done;
      final color = done ? const Color(0xFF35D0BA) : (isCur ? const Color(0xFFFFB84D) : const Color(0xFF5B3FD1));
      final node = TVFocusable(
        autofocus: i == current,
        scale: 1.08,
        onPressed: () => _open(ch),
        builder: (BuildContext context, bool focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 250 * s,
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
          decoration: BoxDecoration(
            color: const Color(0xFF181B3A),
            borderRadius: BorderRadius.circular(40 * s),
            border: Border.all(color: focused ? Colors.white : color, width: focused ? 4 : 3),
            boxShadow: isCur || focused ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 24)] : null,
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 22 * s,
              backgroundColor: color,
              child: done ? const Icon(Icons.check_rounded, color: Colors.black87) : Text('${i + 1}', style: kidText(20 * s, c: Colors.black87)),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(ch, style: kidText(17 * s), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (p >= 0)
                  Padding(
                    padding: EdgeInsets.only(top: 6 * s),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: p, minHeight: 6 * s, color: const Color(0xFF35D0BA), backgroundColor: const Color(0xFF2A2E63)),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      );
      // zig-zag: odd rows shift right a little so it reads as a path
      rows.add(Align(alignment: i.isEven ? const Alignment(-0.45, 0) : const Alignment(0.45, 0), child: node));
      if (i < widget.chapters.length - 1) {
        rows.add(Align(
          alignment: i.isEven ? const Alignment(-0.45, 0) : const Alignment(0.45, 0),
          child: Container(width: 6 * s, height: 22 * s, margin: EdgeInsets.symmetric(vertical: 2 * s), color: const Color(0xFF5A5FA6)),
        ));
      }
    }
    return ScreenFrame(
      title: '\u{1F5FA}️ ${widget.title}',
      body: ListView(padding: EdgeInsets.symmetric(vertical: 10 * s, horizontal: 8 * s), children: rows),
    );
  }
}
