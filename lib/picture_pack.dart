import 'library.dart';
import 'quiz_model.dart';

/// Picture quizzes (flags, space, instruments, logos). Pictures are bundled in assets/quiz/.
class PicturePack {
  // topic id -> (title, emoji, question text, [file number, answer])
  static const List<(String, String, String, String, List<(int, String)>)> topics = <(String, String, String, String, List<(int, String)>)>[
    ('flags', 'World Flags', '🚩', 'Which country\'s flag is this?', <(int, String)>[
      (1, 'India'),
      (2, 'United States of America (USA)'),
      (3, 'Japan'),
      (4, 'Canada'),
      (5, 'United Kingdom (UK)'),
      (6, 'China'),
      (7, 'Brazil'),
      (8, 'Germany'),
      (9, 'France'),
      (10, 'Australia'),
    ]),
    ('space', 'Astronauts and Space Craft', '🚀', 'What is this?', <(int, String)>[
      (1, 'Astronaut / Space Suit'),
      (2, 'Rocket'),
      (3, 'Space Shuttle'),
      (4, 'Satellite'),
      (5, 'Mars Rover'),
      (6, 'International Space Station (ISS)'),
      (7, 'Telescope'),
      (8, 'Space Capsule'),
      (9, 'Lunar Lander'),
      (10, 'Jupiter'),
    ]),
    ('instruments', 'Indian Musical Instruments', '🎶', 'Which instrument is this?', <(int, String)>[
      (1, 'Sitar'),
      (2, 'Tabla'),
      (3, 'Bansuri (Flute)'),
      (5, 'Harmonium'),
      (6, 'Dholak'),
      (7, 'Shehnai'),
      (8, 'Violin'),
      (10, 'Santoor'),
    ]),
    ('logos', 'Logos and Brands', '🏷️', 'Which brand is this?', <(int, String)>[
      (1, 'McDonald\'s'),
      (2, 'Apple'),
      (3, 'Nike'),
      (4, 'Adidas'),
      (5, 'Mercedes-Benz'),
      (6, 'YouTube'),
      (7, 'Starbucks'),
      (8, 'Pepsi'),
      (9, 'Amazon'),
      (10, 'Google'),
    ]),
  ];

  static QuizSet build(int topic) {
    final t = topics[topic];
    final names = t.$5.map(((int, String) e) => e.$2).toList();
    final qs = <QuizQuestion>[];
    for (var i = 0; i < t.$5.length; i++) {
      final e = t.$5[i];
      // three other answers from the same topic, always the same ones
      final others = <String>[];
      for (var k = 1; others.length < 3 && k < names.length; k++) {
        others.add(names[(i + k * 3) % names.length] == e.$2 ? names[(i + k * 3 + 1) % names.length] : names[(i + k * 3) % names.length]);
      }
      final uniq = <String>[];
      for (final o in others) {
        if (o != e.$2 && !uniq.contains(o)) uniq.add(o);
      }
      for (final n in names) {
        if (uniq.length >= 3) break;
        if (n != e.$2 && !uniq.contains(n)) uniq.add(n);
      }
      final pos = i % 4;
      final opts = List<String>.from(uniq.take(3))..insert(pos, e.$2);
      final nn = e.$1.toString().padLeft(2, '0');
      qs.add(QuizQuestion(
        type: 'mcq',
        question: t.$4,
        options: opts,
        correctIndex: pos,
        explanation: 'This is ${e.$2}.',
        image: 'assets/quiz/${t.$1}_$nn.jpg',
      ));
    }
    return QuizSet(
      id: 'pic_${t.$1}',
      title: 'Picture Quiz: ${t.$2}',
      emoji: t.$3,
      lang: 'en',
      questions: qs,
      cls: '',
      subject: 'Picture Quiz',
    );
  }

  /// Saves the picture quizzes (same ids every time, so it never duplicates). Returns how many were saved.
  static Future<int> install() async {
    await Library.load();
    var n = 0;
    for (var i = 0; i < topics.length; i++) {
      final set = build(i);
      await QuizStore.save(set);
      n++;
    }
    await Library.save();
    return n;
  }
}
