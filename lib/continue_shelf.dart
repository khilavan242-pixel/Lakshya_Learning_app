import 'app_store.dart';
import 'core_audio_models.dart';
import 'learn_model.dart';
import 'library.dart';
import 'players.dart';
import 'quiz_model.dart';

/// One thing the child started but has not finished (for the home screen "Keep going" row).
class ContinueItem {
  final LibItem item;
  final double progress; // 0..1 mastered share
  final int last; // last answered, ms since 1970
  const ContinueItem(this.item, this.progress, this.last);
}

/// The 3 most recently practised items that are not mastered yet.
Future<List<ContinueItem>> loadContinue() async {
  final items = await Library.allItems();
  final quizzes = <String, QuizSet>{for (final q in await QuizStore.loadAll()) q.id: q};
  final docs = <String, LearnDoc>{for (final d in await LearnStore.loadAll()) d.id: d};
  final words = <String, List<WordCard>>{};
  for (final c in await CardStore.loadCards()) {
    words.putIfAbsent(c.topic, () => <WordCard>[]).add(c);
  }
  final out = <ContinueItem>[];
  for (final it in items) {
    final keys = <String>[];
    if (it.kind == 'quiz') {
      final q = quizzes[it.id];
      if (q != null) keys.addAll(q.questions.map((QuizQuestion x) => 'quiz:${q.id}:${x.question}'));
    } else if (it.kind == 'learn') {
      final d = docs[it.id];
      if (d != null) keys.addAll(d.cards.map((LearnCard c) => c.key).where((String k) => k.isNotEmpty));
    } else {
      keys.addAll((words[it.id] ?? <WordCard>[]).map((WordCard w) => 'spell:${w.word}'));
    }
    if (keys.isEmpty) continue;
    var mastered = 0;
    var last = 0;
    for (final k in keys) {
      if (Mastery.isMastered(k)) mastered++;
      final t = Mastery.lastTime(k);
      if (t > last) last = t;
    }
    if (last == 0 || mastered == keys.length) continue;
    out.add(ContinueItem(it, mastered / keys.length, last));
  }
  out.sort((ContinueItem a, ContinueItem b) => b.last.compareTo(a.last));
  return out.take(3).toList();
}

/// Words the child has got wrong most often (for the Parent Zone "Needs a little practice" list).
Future<List<String>> loadWeak() async {
  final out = <String>[];
  for (final c in await CardStore.loadCards()) {
    if (Mastery.statusOf('spell:${c.word}') == 'weak') out.add('Spelling: ${c.word}');
    if (out.length >= 4) break;
  }
  return out;
}
