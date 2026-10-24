import 'package:flutter/material.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'quiz_model.dart';

// ======================================================================
// CBSE Class 1: chapter lists of the NCERT books and a small starter pack.
// Chapter titles come from NCERT's own audio-book pages (ciet.ncert.gov.in):
//   Maths  = Joyful Mathematics (13 chapters), English = Mridang (9), Hindi = Sarangi (19).
// The practice questions are original (not copied from any textbook).
// Please check the titles against the printed book you use.
// ======================================================================

class CbseSubject {
  final String id; // library subject id
  final String name;
  final String book;
  final List<String> chapters;
  const CbseSubject(this.id, this.name, this.book, this.chapters);
}

class CbseClass1 {
  static const String classId = 'cls_1';

  static const List<CbseSubject> subjects = <CbseSubject>[
    CbseSubject('sub_maths', 'Maths', 'Joyful Mathematics', <String>[
      'Finding the Furry Cat!',
      'What is Long?',
      'Mango Treat',
      'Making 10',
      'How Many?',
      'Vegetable Farm',
      "Lina's Family",
      'Fun with Numbers',
      'Utsav',
      'How do I Spend my Day?',
      'How Many Times?',
      'How Much Can We Spend?',
      'So Many Toys',
    ]),
    CbseSubject('sub_english', 'English', 'Mridang', <String>[
      'Two Little Hands',
      'Greetings',
      'Picture Time',
      'The Cap Seller and the Monkeys',
      'A Farm',
      'Fun with Pictures',
      'The Food We Eat',
      'The Four Seasons',
      "Anandi's Rainbow",
    ]),
    CbseSubject('sub_hindi', 'Hindi', 'Sarangi', <String>[
      'मीना का परिवार',
      'दादा-दादी',
      'रीना का दिन',
      'रानी भी',
      'मिठाई',
      'तीन साथी',
      'वाह मेरे घोड़े',
      'खतरे में साँप',
      'आलू की सड़क',
      'झूलम झूली',
      'भुट्टे',
      'फूली रोटी',
      'मेला',
      'बरखा और मेघा',
      'होली',
      'जन्मदिन पर पेड़ लगाओ',
      'हवा',
      'कितनी प्यारी है ये दुनिया',
      'चाँद का बच्चा',
    ]),
  ];

  static QuizQuestion _q(String q, List<String> opts, int right, String why) =>
      QuizQuestion(type: 'mcq', question: q, options: opts, correctIndex: right, explanation: why);

  /// Starter practice: subject id -> chapter number -> (emoji, questions).
  static Map<String, Map<int, (String, List<QuizQuestion>)>> starter() => <String, Map<int, (String, List<QuizQuestion>)>>{
        'sub_maths': <int, (String, List<QuizQuestion>)>{
          2: ('\u{1F4CF}', <QuizQuestion>[
            _q('Which is longer?', <String>['A train', 'A toy car', 'Both are same'], 0, 'A train is much longer than a toy car.'),
            _q('Which rope is shorter?', <String>['A rope 10 cm long', 'A rope 2 cm long'], 1, '2 cm is less than 10 cm, so that rope is shorter.'),
            _q('Which word means "not long"?', <String>['Tall', 'Short', 'Heavy'], 1, 'Short is the opposite of long.'),
            _q('A giraffe\'s neck is ___ than a rabbit\'s neck.', <String>['shorter', 'longer', 'lighter'], 1, 'A giraffe has a very long neck.'),
          ]),
          4: ('\u{1F51F}', <QuizQuestion>[
            _q('7 + ___ = 10', <String>['2', '3', '4', '5'], 1, '7 and 3 make 10.'),
            _q('6 and 4 make', <String>['9', '10', '11'], 1, '6 + 4 = 10.'),
            _q('10 - 5 = ?', <String>['4', '5', '6'], 1, 'Take 5 away from 10 and 5 are left.'),
            _q('Which two numbers make 10?', <String>['8 + 1', '8 + 2', '8 + 3'], 1, '8 + 2 = 10.'),
          ]),
          5: ('\u{1F522}', <QuizQuestion>[
            _q('How many apples?  \u{1F34E}\u{1F34E}\u{1F34E}\u{1F34E}', <String>['3', '4', '5'], 1, 'Count them one by one: 4.'),
            _q('How many stars?  ⭐⭐⭐⭐⭐⭐', <String>['5', '6', '7'], 1, 'There are 6 stars.'),
            _q('Which is more?', <String>['3', '8'], 1, '8 is more than 3.'),
            _q('Which number comes after 6?', <String>['5', '7', '8'], 1, 'After 6 comes 7.'),
          ]),
          8: ('\u{1F3B2}', <QuizQuestion>[
            _q('Which number comes just before 15?', <String>['13', '14', '16'], 1, '14 comes just before 15.'),
            _q('Which is the biggest?', <String>['12', '21', '19'], 1, '21 is bigger than 12 and 19.'),
            _q('5, 6, ___, 8', <String>['4', '7', '9'], 1, 'The missing number is 7.'),
            _q('Which is the smallest?', <String>['9', '4', '7'], 1, '4 is the smallest.'),
          ]),
          10: ('⏰', <QuizQuestion>[
            _q('We go to bed at', <String>['Morning', 'Night', 'Noon'], 1, 'We sleep at night.'),
            _q('The sun rises in the', <String>['Morning', 'Night', 'Evening'], 0, 'The sun comes up in the morning.'),
            _q('How many days are there in a week?', <String>['5', '6', '7'], 2, 'A week has 7 days.'),
            _q('Which day comes after Monday?', <String>['Sunday', 'Tuesday', 'Friday'], 1, 'Tuesday comes after Monday.'),
          ]),
          12: ('\u{1FA99}', <QuizQuestion>[
            _q('We use ___ to buy things.', <String>['Money', 'Stones', 'Leaves'], 0, 'Money is used to buy things.'),
            _q('₹5 + ₹5 = ?', <String>['₹8', '₹10', '₹12'], 1, '5 + 5 = 10.'),
            _q('₹10 - ₹4 = ?', <String>['₹6', '₹7', '₹5'], 0, '10 - 4 = 6.'),
            _q('Which is worth more?', <String>['₹1', '₹5'], 1, '₹5 is worth more than ₹1.'),
          ]),
        },
        'sub_english': <int, (String, List<QuizQuestion>)>{
          2: ('\u{1F44B}', <QuizQuestion>[
            _q('What do we say in the morning?', <String>['Good night', 'Good morning', 'Goodbye'], 1, 'We say Good morning when the day begins.'),
            _q('What do we say before we go to sleep?', <String>['Good night', 'Good morning', 'Hello'], 0, 'We say Good night at bedtime.'),
            _q('When we meet someone we say', <String>['Hello', 'Goodbye', 'Good night'], 0, 'Hello is a greeting.'),
            _q('When we leave we say', <String>['Hello', 'Goodbye', 'Good morning'], 1, 'Goodbye is said when we leave.'),
          ]),
          4: ('\u{1F412}', <QuizQuestion>[
            _q('What did the cap seller sell?', <String>['Caps', 'Shoes', 'Toys'], 0, 'He sold caps.'),
            _q('Who took the caps?', <String>['Birds', 'Monkeys', 'Dogs'], 1, 'The monkeys took the caps.'),
            _q('Where did the monkeys sit?', <String>['On the tree', 'In the river', 'In a house'], 0, 'They sat on the tree.'),
            _q('How did the cap seller get his caps back?', <String>['He threw his own cap on the ground', 'He ran away', 'He asked a policeman'], 0, 'The monkeys copied him and threw their caps down.'),
          ]),
          5: ('\u{1F404}', <QuizQuestion>[
            _q('Which animal gives us eggs?', <String>['Cow', 'Hen', 'Goat'], 1, 'A hen lays eggs.'),
            _q('A baby cow is called a', <String>['Calf', 'Kitten', 'Puppy'], 0, 'A baby cow is a calf.'),
            _q('Which animal says "moo"?', <String>['Cow', 'Duck', 'Sheep'], 0, 'A cow says moo.'),
            _q('Where do farmers grow crops?', <String>['In a field', 'In a shop', 'In a bus'], 0, 'Crops grow in a field.'),
          ]),
          7: ('\u{1F34E}', <QuizQuestion>[
            _q('Which is a fruit?', <String>['Mango', 'Carrot', 'Potato'], 0, 'Mango is a fruit.'),
            _q('Which animal gives us milk?', <String>['Cow', 'Lion', 'Hen'], 0, 'We get milk from a cow.'),
            _q('Which is a vegetable?', <String>['Banana', 'Carrot', 'Grapes'], 1, 'Carrot is a vegetable.'),
            _q('We should wash our hands ___ eating.', <String>['before', 'never', 'after sleeping'], 0, 'Clean hands keep us healthy.'),
          ]),
          8: ('\u{1F326}️', <QuizQuestion>[
            _q('Which season is very hot?', <String>['Summer', 'Winter', 'Rainy'], 0, 'Summer is the hot season.'),
            _q('In which season does it rain a lot?', <String>['Summer', 'Rainy', 'Winter'], 1, 'The rainy season brings a lot of rain.'),
            _q('In winter we wear a', <String>['Sweater', 'Raincoat only', 'Swimsuit'], 0, 'A sweater keeps us warm.'),
            _q('How many seasons are in the title "The Four Seasons"?', <String>['Two', 'Three', 'Four'], 2, 'Four, as the title says.'),
          ]),
        },
      };

  static String _chapterTitle(int n, String name) => 'Ch $n: $name';

  /// Saves the starter quizzes (same ids every time, so installing again never duplicates)
  /// and files them under Class 1 and the right subject. Returns how many quizzes were saved.
  static Future<int> install() async {
    await Library.load();
    var saved = 0;
    final data = starter();
    for (final sub in subjects) {
      final chapters = data[sub.id];
      if (chapters == null) continue;
      for (final entry in chapters.entries) {
        final n = entry.key;
        if (n < 1 || n > sub.chapters.length) continue;
        final id = 'cbse1_${sub.id}_$n';
        final set = QuizSet(
          id: id,
          title: _chapterTitle(n, sub.chapters[n - 1]),
          emoji: entry.value.$1,
          lang: 'en',
          questions: entry.value.$2,
          cls: 'Class 1',
          subject: sub.name,
        );
        await QuizStore.save(set);
        final m = Map<String, String>.from(Library.meta['quiz:$id'] ?? <String, String>{});
        m['c'] = classId;
        m['s'] = sub.id;
        m['at'] = m['at'] ?? '0';
        Library.meta['quiz:$id'] = m;
        saved++;
      }
    }
    await Library.save();
    return saved;
  }
}

/// Class 1 syllabus: every NCERT chapter with a tick when the app has practice for it.
class CbseSyllabusScreen extends StatefulWidget {
  const CbseSyllabusScreen({super.key});
  @override
  State<CbseSyllabusScreen> createState() => _CbseSyllabusScreenState();
}

class _CbseSyllabusScreenState extends State<CbseSyllabusScreen> {
  List<LibItem> _items = <LibItem>[];
  bool _loading = true;
  bool _busy = false;
  String _msg = '';
  int _sub = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await Library.allItems();
    if (!mounted) return;
    setState(() {
      _items = all;
      _loading = false;
    });
  }

  int _count(CbseSubject sub, int n) {
    var c = 0;
    for (final it in _items) {
      if (it.classId == CbseClass1.classId && it.subjectId == sub.id && it.chapter.startsWith('Ch $n:')) c++;
    }
    return c;
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _msg = '';
    });
    final n = await CbseClass1.install();
    await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = 'Added $n practice quizzes. Open Library > Class 1 to see them.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final sub = CbseClass1.subjects[_sub];
    var done = 0;
    for (var i = 1; i <= sub.chapters.length; i++) {
      if (_count(sub, i) > 0) done++;
    }
    return ScreenFrame(
      title: '\u{1F4D8} Class 1 syllabus',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12 * s),
                child: Wrap(spacing: 8 * s, children: [
                  for (var i = 0; i < CbseClass1.subjects.length; i++)
                    ChoiceChip(label: Text(CbseClass1.subjects[i].name), selected: _sub == i, onSelected: (_) => setState(() => _sub = i)),
                ]),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 4 * s),
                child: Row(children: [
                  Expanded(child: Text('${sub.book}: $done of ${sub.chapters.length} chapters have practice', style: kidText(14 * s, w: FontWeight.w700, c: const Color(0xFFA9ADDB)))),
                  FilledButton.icon(
                    onPressed: _busy ? null : _install,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(_busy ? 'Adding...' : 'Add starter practice'),
                  ),
                ]),
              ),
              if (_msg.isNotEmpty) Padding(padding: EdgeInsets.symmetric(horizontal: 12 * s), child: Text(_msg, style: kidText(13 * s, c: const Color(0xFF7DF0DC), w: FontWeight.w700))),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(12 * s, 6 * s, 12 * s, 20 * s),
                  itemCount: sub.chapters.length,
                  itemBuilder: (BuildContext context, int i) {
                    final c = _count(sub, i + 1);
                    return Container(
                      margin: EdgeInsets.only(bottom: 6 * s),
                      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
                      decoration: BoxDecoration(color: const Color(0xFF181B3A), borderRadius: BorderRadius.circular(16 * s)),
                      child: Row(children: [
                        Icon(c > 0 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: c > 0 ? const Color(0xFF35D0BA) : Colors.white38, size: 22 * s),
                        SizedBox(width: 10 * s),
                        Expanded(child: Text('Ch ${i + 1}: ${sub.chapters[i]}', style: kidText(15 * s, w: FontWeight.w700))),
                        Text(c > 0 ? '$c item${c == 1 ? '' : 's'}' : 'Add content', style: kidText(12 * s, w: FontWeight.w600, c: const Color(0xFFA9ADDB))),
                      ]),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12 * s, 0, 12 * s, 8 * s),
                child: Text('Titles from the NCERT books. Check them against your printed book.', style: kidText(12 * s, w: FontWeight.w600, c: const Color(0xFFA9ADDB))),
              ),
            ]),
    );
  }
}
