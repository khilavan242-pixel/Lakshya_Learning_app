import 'package:flutter/material.dart';
import 'app_store.dart';
import 'bin.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'phone_manager.dart';
import 'players.dart';
import 'learn_model.dart';
import 'quiz_model.dart';
import 'speech_service.dart';

// ======================================================================
// LIBRARY: Class > Subject > Topic, like a school app.
//   * every spelling topic and every quiz set is an "item"
//   * each item can be put in a class and a subject, renamed, given a new picture,
//     moved, or deleted (Organize screen)
//   * the Spelling, Quiz and Quick Learn screens all browse the same folders
// Saved in <Documents>/KidsSuperApp/library/library.json
// ======================================================================

const String kUnsorted = '~';
const String kAll = '*';

class LibClass {
  String id;
  String name;
  String emoji;
  LibClass(this.id, this.name, this.emoji);
  Map<String, String> toJson() => <String, String>{'id': id, 'name': name, 'emoji': emoji};
}

class LibSubject {
  String id;
  String name;
  String emoji;
  LibSubject(this.id, this.name, this.emoji);
  Map<String, String> toJson() => <String, String>{'id': id, 'name': name, 'emoji': emoji};
}

/// One thing a child can open: a spelling topic, a quiz set or a study list.
class LibItem {
  final String kind; // 'quiz' | 'spell' | 'learn'
  final String id; // quiz id, or the spelling topic name
  String title;
  String emoji;
  final String subtitle;
  final int count;
  final Object? payload;
  String classId = '';
  String subjectId = '';
  String chapter = ''; // 'Ch 3: Subtraction' or '' (no chapter)

  LibItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.count,
    this.payload,
  });

  String get key => '$kind:$id';
}

class LibExtra {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Future<void> Function() onPressed;
  LibExtra({required this.emoji, required this.title, required this.subtitle, required this.colors, required this.onPressed});
}

class Library {
  Library._();

  static List<LibClass> classes = <LibClass>[];
  static List<LibSubject> subjects = <LibSubject>[];
  static Map<String, Map<String, String>> meta = <String, Map<String, String>>{};
  static bool _loaded = false;
  static Future<void> _saving = Future<void>.value();

  static List<LibClass> _defaultClasses() => <LibClass>[
        LibClass('cls_nursery', 'Nursery', '🧸'),
        LibClass('cls_lkg', 'LKG', '🎒'),
        LibClass('cls_ukg', 'UKG', '🎨'),
        LibClass('cls_1', 'Class 1', '1️⃣'),
        LibClass('cls_2', 'Class 2', '2️⃣'),
        LibClass('cls_3', 'Class 3', '3️⃣'),
        LibClass('cls_4', 'Class 4', '4️⃣'),
        LibClass('cls_5', 'Class 5', '5️⃣'),
      ];

  static List<LibSubject> _defaultSubjects() => <LibSubject>[
        LibSubject('sub_english', 'English', '🔤'),
        LibSubject('sub_hindi', 'Hindi', '🇮🇳'),
        LibSubject('sub_maths', 'Maths', '🧮'),
        LibSubject('sub_evs', 'EVS', '🌿'),
        LibSubject('sub_gk', 'General Knowledge', '🧠'),
        LibSubject('sub_rhymes', 'Rhymes & Stories', '🎵'),
        LibSubject('sub_science', 'Science', '🔬'),
        LibSubject('sub_computer', 'Computer', '💻'),
        LibSubject('sub_drawing', 'Drawing', '🎨'),
      ];

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await DocStore.readJson('library', 'library.json');
    if (raw is Map) {
      final c = raw['classes'];
      if (c is List) {
        for (final e in c) {
          if (e is Map) classes.add(LibClass((e['id'] ?? '').toString(), (e['name'] ?? '').toString(), (e['emoji'] ?? '📁').toString()));
        }
      }
      final s = raw['subjects'];
      if (s is List) {
        for (final e in s) {
          if (e is Map) subjects.add(LibSubject((e['id'] ?? '').toString(), (e['name'] ?? '').toString(), (e['emoji'] ?? '📁').toString()));
        }
      }
      final m = raw['meta'];
      if (m is Map) {
        m.forEach((dynamic k, dynamic v) {
          if (v is Map) {
            meta[k.toString()] = v.map((dynamic a, dynamic b) => MapEntry<String, String>(a.toString(), b.toString()));
          }
        });
      }
    }
    if (classes.isEmpty) classes = _defaultClasses();
    if (subjects.isEmpty) subjects = _defaultSubjects();
  }

  static Future<void> save() {
    final data = <String, dynamic>{
      'classes': classes.map((LibClass c) => c.toJson()).toList(),
      'subjects': subjects.map((LibSubject c) => c.toJson()).toList(),
      'meta': meta,
    };
    _saving = _saving.then((_) => DocStore.writeJson('library', 'library.json', data)).catchError((Object e) {});
    return _saving;
  }

  static String _newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';

  static LibClass? classById(String id) {
    for (final c in classes) {
      if (c.id == id) return c;
    }
    return null;
  }

  static LibSubject? subjectById(String id) {
    for (final c in subjects) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---------------------------------------------------------- classes
  static Future<LibClass> addClass(String name) async {
    final n = name.trim();
    for (final c in classes) {
      if (c.name.toLowerCase() == n.toLowerCase()) return c;
    }
    final c = LibClass(_newId('cls_'), n, '📘');
    classes.add(c);
    await save();
    return c;
  }

  static Future<void> deleteClass(String id) async {
    classes.removeWhere((LibClass c) => c.id == id);
    meta.forEach((String k, Map<String, String> m) {
      if (m['c'] == id) m['c'] = '';
    });
    await save();
  }

  static Future<void> moveClass(String id, int delta) async {
    final i = classes.indexWhere((LibClass c) => c.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= classes.length) return;
    final c = classes.removeAt(i);
    classes.insert(j, c);
    await save();
  }

  // --------------------------------------------------------- subjects
  static Future<LibSubject> addSubject(String name) async {
    final n = name.trim();
    for (final c in subjects) {
      if (c.name.toLowerCase() == n.toLowerCase()) return c;
    }
    final c = LibSubject(_newId('sub_'), n, '📗');
    subjects.add(c);
    await save();
    return c;
  }

  static Future<void> deleteSubject(String id) async {
    subjects.removeWhere((LibSubject c) => c.id == id);
    meta.forEach((String k, Map<String, String> m) {
      if (m['s'] == id) m['s'] = '';
    });
    await save();
  }

  static Future<void> moveSubject(String id, int delta) async {
    final i = subjects.indexWhere((LibSubject c) => c.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= subjects.length) return;
    final c = subjects.removeAt(i);
    subjects.insert(j, c);
    await save();
  }

  // ------------------------------------------------------------- items
  /// null = keep as it is, '' = clear.
  static Future<void> setMeta(String key, {String? c, String? s, String? t, String? e, String? ch}) async {
    final m = Map<String, String>.from(meta[key] ?? <String, String>{});
    if (c != null) m['c'] = c;
    if (s != null) m['s'] = s;
    if (t != null) m['t'] = t;
    if (e != null) m['e'] = e;
    if (ch != null) m['ch'] = ch;
    meta[key] = m;
    await save();
  }

  static Future<void> removeMeta(String key) async {
    meta.remove(key);
    await save();
  }

  /// "Chapter 3: Subtraction", "Ch 3 - Time", "Ch.3 Shapes" at the start of a title -> "Ch 3: Subtraction".
  static String chapterOf(String title) {
    final m = RegExp(r'^\s*(?:chapter|ch)\.?\s*(\d+)\s*[:\-\u2013\u2014.]?\s*(.*)$', caseSensitive: false).firstMatch(title);
    if (m == null) return '';
    final rest = (m.group(2) ?? '').trim();
    return rest.isEmpty ? 'Ch ${m.group(1)}' : 'Ch ${m.group(1)}: $rest';
  }

  /// Sorts chapter names by their number (Ch 2 before Ch 10), then by name.
  static int compareChapters(String a, String b) {
    int num(String x) => int.tryParse(RegExp(r'^Ch (\d+)').firstMatch(x)?.group(1) ?? '') ?? 100000;
    final d = num(a).compareTo(num(b));
    return d != 0 ? d : a.toLowerCase().compareTo(b.toLowerCase());
  }

  static void apply(List<LibItem> items) {
    for (final it in items) {
      it.chapter = chapterOf(it.title);
      final m = meta[it.key];
      if (m == null) continue;
      final c = m['c'] ?? '';
      final s = m['s'] ?? '';
      it.classId = classById(c) != null ? c : '';
      it.subjectId = subjectById(s) != null ? s : '';
      final t = m['t'] ?? '';
      if (t.isNotEmpty) it.title = t;
      final e = m['e'] ?? '';
      if (e.isNotEmpty) it.emoji = e;
      final ch = m['ch'] ?? '';
      if (ch == '-') {
        it.chapter = ''; // parent says: no chapter
      } else if (ch.isNotEmpty) {
        it.chapter = ch;
      } else {
        it.chapter = chapterOf(it.title);
      }
    }
  }

  /// A quiz file may say  "class": "Class 1", "subject": "English"  - then it is sorted automatically.
  static Future<void> syncQuizzes(List<QuizSet> sets) async {
    await load();
    for (final q in sets) {
      final key = 'quiz:${q.id}';
      if (meta.containsKey(key)) continue;
      if (q.cls.isEmpty && q.subject.isEmpty) continue;
      final cl = q.cls.isNotEmpty ? await addClass(q.cls) : null;
      final sb = q.subject.isNotEmpty ? await addSubject(q.subject) : null;
      await setMeta(key, c: cl?.id ?? '', s: sb?.id ?? '');
    }
  }

  /// Study lists from the phone may carry "cls" / "subject" - sort them automatically.
  static Future<void> syncLearn(List<LearnDoc> docs) async {
    await load();
    for (final d in docs) {
      final key = 'learn:${d.id}';
      if (meta.containsKey(key)) continue;
      if (d.cls.isEmpty && d.subject.isEmpty) continue;
      final cl = d.cls.isNotEmpty ? await addClass(d.cls) : null;
      final sb = d.subject.isNotEmpty ? await addSubject(d.subject) : null;
      await setMeta(key, c: cl?.id ?? '', s: sb?.id ?? '');
    }
  }

  static Future<List<LibItem>> allItems() async {
    await load();
    final out = <LibItem>[];
    final quizzes = await QuizStore.loadAll();
    await syncQuizzes(quizzes);
    for (final q in quizzes) {
      out.add(LibItem(kind: 'quiz', id: q.id, title: q.title, emoji: q.emoji, subtitle: '🧠 ${q.questions.length} questions', count: q.questions.length));
    }
    final docs = await LearnStore.loadAll();
    await syncLearn(docs);
    for (final d in docs) {
      out.add(LibItem(kind: 'learn', id: d.id, title: d.title, emoji: d.emoji, subtitle: '📖 ${d.cards.length} cards', count: d.cards.length));
    }
    final cards = await CardStore.loadCards();
    final counts = <String, int>{};
    for (final c in cards) {
      counts[c.topic] = (counts[c.topic] ?? 0) + 1;
    }
    counts.forEach((String topic, int n) {
      out.add(LibItem(kind: 'spell', id: topic, title: topic, emoji: emojiForTopic(topic), subtitle: '✏️ $n words', count: n));
    });
    apply(out);
    await _stampNew(out);
    return out;
  }

  /// Remembers when each item first showed up. The first time ever, everything counts as old.
  static Future<void> _stampNew(List<LibItem> items) async {
    final firstRun = !meta.containsKey('__init');
    if (firstRun) meta['__init'] = <String, String>{'at': '1'};
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    var changed = firstRun;
    for (final it in items) {
      final m = Map<String, String>.from(meta[it.key] ?? <String, String>{});
      if (m.containsKey('at')) continue;
      m['at'] = firstRun ? '0' : now;
      meta[it.key] = m;
      changed = true;
    }
    if (changed) await save();
  }

  /// Items added in the last [days] days (newest first).
  static Future<List<LibItem>> newItems({int days = 7}) async {
    final all = await allItems();
    final limit = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    int at(LibItem i) => int.tryParse(meta[i.key]?['at'] ?? '') ?? 0;
    final fresh = all.where((LibItem i) => at(i) > limit).toList()..sort((LibItem a, LibItem b) => at(b).compareTo(at(a)));
    return fresh;
  }

  static String? _subjectIdNamed(String start) {
    for (final s in subjects) {
      if (s.name.toLowerCase().startsWith(start.toLowerCase())) return s.id;
    }
    return null;
  }

  /// A simple guess from the title, so many items can be sorted in one go.
  static String? guessSubjectId(String title) {
    if (Speaker.isHindi(title)) return _subjectIdNamed('hindi');
    final t = title.toLowerCase();
    bool has(List<String> words) => words.any((String w) => t.contains(w));
    if (has(<String>['math', 'number', 'count', 'table', 'add', 'subtract', 'shape', 'fraction', 'clock', 'time'])) return _subjectIdNamed('math');
    if (has(<String>['rhyme', 'hands', 'twinkle', 'story', 'monkey', 'cap seller', 'song'])) return _subjectIdNamed('rhymes');
    if (has(<String>['animal', 'bird', 'plant', 'body', 'water', 'farm', 'season', 'family', 'food', 'fruit', 'vegetable', 'transport', 'weather'])) return _subjectIdNamed('evs');
    if (has(<String>['general knowledge', 'gk', 'quiz'])) return _subjectIdNamed('general');
    return _subjectIdNamed('english');
  }

  static Future<int> autoSort(List<LibItem> items, String classId) async {
    var n = 0;
    for (final it in items) {
      final needClass = it.classId.isEmpty && classId.isNotEmpty;
      final guess = it.subjectId.isEmpty ? guessSubjectId(it.title) : null;
      if (!needClass && guess == null) continue;
      await setMeta(it.key, c: needClass ? classId : null, s: guess);
      n++;
    }
    return n;
  }
}

// ----------------------------------------------------------------------
// SMALL HELPERS (pick one / action menu / emoji)
// ----------------------------------------------------------------------
class _Opt {
  final String id;
  final String label;
  const _Opt(this.id, this.label);
}

class _ChooseScreen extends StatelessWidget {
  final String title;
  final List<_Opt> options;
  final String? newLabel;
  final Future<String?> Function()? onNew;
  const _ChooseScreen({required this.title, required this.options, this.newLabel, this.onNew});

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      rows.add(SettingLinkRow(label: o.label, s: s, autofocus: i == 0, onPressed: () => Navigator.pop(context, o.id)));
    }
    final nl = newLabel;
    final create = onNew;
    if (nl != null && create != null) {
      rows.add(SettingLinkRow(
        label: '➕  $nl',
        s: s,
        onPressed: () async {
          final id = await create();
          if (id != null && context.mounted) Navigator.pop(context, id);
        },
      ));
    }
    return ScreenFrame(title: title, body: FocusList(s: s, items: rows));
  }
}

Future<String?> _chooseOne(BuildContext context, String title, List<_Opt> options, {String? newLabel, Future<String?> Function()? onNew}) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute<String>(builder: (_) => _ChooseScreen(title: title, options: options, newLabel: newLabel, onNew: onNew)),
  );
}

List<_Opt> _classOptions(String noneLabel) {
  return <_Opt>[
    _Opt('', noneLabel),
    for (final c in Library.classes) _Opt(c.id, '${c.emoji}  ${c.name}'),
  ];
}

List<_Opt> _subjectOptions() {
  return <_Opt>[
    const _Opt('', '📥  No subject'),
    for (final c in Library.subjects) _Opt(c.id, '${c.emoji}  ${c.name}'),
  ];
}

Future<String?> _askNewClass(BuildContext context) async {
  final name = await askText(context, 'Class name', 'e.g. Class 2');
  if (name == null) return null;
  final c = await Library.addClass(name);
  return c.id;
}

Future<String?> _askNewSubject(BuildContext context) async {
  final name = await askText(context, 'Subject name', 'e.g. Science');
  if (name == null) return null;
  final c = await Library.addSubject(name);
  return c.id;
}

/// Choose a class (for a player). Returns the class id, '' for "none", or null if cancelled.
Future<String?> pickLibClass(BuildContext context, {String noneLabel = '🌍  All classes'}) async {
  await Library.load();
  if (!context.mounted) return null;
  return _chooseOne(context, 'Choose a class', _classOptions(noneLabel), newLabel: 'New class...', onNew: () => _askNewClass(context));
}

Future<int?> showActionMenu(BuildContext context, String title, List<String> labels) {
  final s = uiScale(context);
  return showDialog<int>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1B4B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28 * s)),
      title: Text(title, style: kidText(24 * s)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 5 * s),
                child: SizedBox(
                  width: 460 * s,
                  child: SettingLinkRow(label: labels[i], s: s, autofocus: i == 0, onPressed: () => Navigator.pop(ctx, i)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

const List<String> _emojiChoices = <String>[
  '📚', '🧠', '🔤', '🇮🇳', '🧮', '🌿', '🎵', '🔬', '💻', '🎨', '🍎', '🦁', '🐦', '🧒', '🚜', '🐄',
  '🐒', '🧢', '👋', '🖼️', '🔢', '📅', '🌍', '🚗', '⚽', '🏠', '👪', '🌦️', '🍽️', '🌈', '⭐', '🎈',
];

class _EmojiScreen extends StatelessWidget {
  const _EmojiScreen();
  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final tiles = <Widget Function(double, double)>[];
    for (var i = 0; i < _emojiChoices.length; i++) {
      final e = _emojiChoices[i];
      final index = i;
      tiles.add((double w, double h) => BigTile(
            emoji: e,
            title: '',
            colors: kTopicGradients[index % kTopicGradients.length],
            s: s,
            width: w / s,
            height: h / s,
            autofocus: index == 0,
            onPressed: () => Navigator.pop(context, e),
          ));
    }
    return ScreenFrame(title: 'Choose a picture', body: AdaptiveGrid(builders: tiles, aspect: 1.1, minWidth: 70 * s, maxWidth: 120 * s, gap: 12 * s));
  }
}

// ----------------------------------------------------------------------
// THE BROWSER: Class > Subject > Topics (used by Spelling, Quiz, Quick Learn)
// ----------------------------------------------------------------------
class _Eff {
  final String? cls;
  final String? sub;
  const _Eff(this.cls, this.sub);
}

class _ChInfo {
  final String key;
  final String chip;
  final String title;
  final List<LibItem> items;
  final int notes;
  final int quiz;
  final int words;
  final double progress;
  final String status;
  final bool isNew;
  const _ChInfo(this.key, this.chip, this.title, this.items, this.notes, this.quiz, this.words, this.progress, this.status, this.isNew);
}

class LibraryBrowser extends StatefulWidget {
  final String title;
  final String myClassId;
  final String emptyText;
  final Future<List<LibItem>> Function() loader;
  final Future<void> Function(LibItem item) onOpen;
  final List<LibExtra> Function(List<LibItem> scope, String scopeName) extras;
  final List<Widget> Function(double s, Future<void> Function() reload) actions;
  final Listenable? refresh;
  /// When set, tapping a chapter opens this (the Chapter page) instead of listing its items.
  final Future<void> Function(String chapter, String trail, List<LibItem> items)? onOpenChapter;
  /// When set, a "Journey" tile shows the chapters of a subject as a path.
  final Future<void> Function(String trail, List<String> chapters, Map<String, List<LibItem>> items)? onOpenJourney;

  const LibraryBrowser({
    super.key,
    required this.title,
    required this.myClassId,
    required this.emptyText,
    required this.loader,
    required this.onOpen,
    required this.extras,
    required this.actions,
    this.refresh,
    this.onOpenChapter,
    this.onOpenJourney,
  });

  @override
  State<LibraryBrowser> createState() => _LibraryBrowserState();
}

class _LibraryBrowserState extends State<LibraryBrowser> {
  List<LibItem> _items = <LibItem>[];
  bool _loaded = false;
  bool _autoClassDone = false;
  String? _cls;
  String? _sub;
  String? _ch; // chapter chosen inside a subject (null = chapter list)
  bool _noAutoCls = false;
  bool _noAutoSub = false;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_reloadSync);
    _reload();
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_reloadSync);
    super.dispose();
  }

  void _reloadSync() {
    _reload();
  }

  Future<void> _reload() async {
    await Library.load();
    final items = await widget.loader();
    Library.apply(items);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loaded = true;
      if (!_autoClassDone) {
        _autoClassDone = true;
        if (widget.myClassId.isNotEmpty && items.any((LibItem i) => i.classId == widget.myClassId)) _cls = widget.myClassId;
      }
    });
  }

  List<String> _classKeys() {
    final keys = <String>[];
    for (final c in Library.classes) {
      if (_items.any((LibItem i) => i.classId == c.id)) keys.add(c.id);
    }
    if (_items.any((LibItem i) => i.classId.isEmpty)) keys.add(kUnsorted);
    return keys;
  }

  List<LibItem> _scopeClass(String cls) {
    if (cls == kAll) return _items;
    return _items.where((LibItem i) => cls == kUnsorted ? i.classId.isEmpty : i.classId == cls).toList();
  }

  List<String> _subjectKeys(List<LibItem> inClass) {
    final keys = <String>[];
    for (final s in Library.subjects) {
      if (inClass.any((LibItem i) => i.subjectId == s.id)) keys.add(s.id);
    }
    if (inClass.any((LibItem i) => i.subjectId.isEmpty)) keys.add(kUnsorted);
    return keys;
  }

  List<LibItem> _scopeSub(List<LibItem> inClass, String sub) {
    if (sub == kAll) return inClass;
    return inClass.where((LibItem i) => sub == kUnsorted ? i.subjectId.isEmpty : i.subjectId == sub).toList();
  }

  String _clsLabel(String key) {
    if (key == kAll) return 'All';
    if (key == kUnsorted) return 'Not sorted';
    return Library.classById(key)?.name ?? '';
  }

  String _subLabel(String key) {
    if (key == kAll) return 'All subjects';
    if (key == kUnsorted) return 'No subject';
    return Library.subjectById(key)?.name ?? '';
  }

  /// What is really shown: levels with only one choice are skipped automatically.
  _Eff _eff() {
    var cls = _cls;
    final classKeys = _classKeys();
    if (cls == null && !_noAutoCls && classKeys.length == 1) cls = classKeys.first;
    var sub = _sub;
    if (cls != null && sub == null && !_noAutoSub) {
      final keys = _subjectKeys(_scopeClass(cls));
      if (keys.length == 1) sub = keys.first;
    }
    return _Eff(cls, sub);
  }

  bool _canGoUp() => _ch != null || _sub != null || _cls != null;

  bool _up() {
    if (_ch != null) {
      setState(() => _ch = null);
      return true;
    }
    if (_sub != null) {
      setState(() {
        _sub = null;
        _noAutoSub = true;
      });
      return true;
    }
    if (_cls != null) {
      setState(() {
        _cls = null;
        _sub = null;
        _noAutoCls = true;
      });
      return true;
    }
    return false;
  }

  Future<void> _openOrganize() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LibraryManagerScreen()));
    if (mounted) _reload();
  }


  String _filter = 'all'; // all | new | needs | done

  _ChInfo _info(String key, List<LibItem> items) {
    var notes = 0, quiz = 0, words = 0, total = 0, mastered = 0, started = 0, weak = 0;
    var isNew = false;
    final limit = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    void card(String k) {
      if (k.isEmpty) return;
      total++;
      final st = Mastery.statusOf(k);
      if (st == 'mastered' || st == 'review') mastered++;
      if (st != 'new') started++;
      if (st == 'weak') weak++;
    }

    for (final it in items) {
      if (it.kind == 'learn') notes += it.count;
      if (it.kind == 'quiz') quiz += it.count;
      if (it.kind == 'spell') words += it.count;
      if ((int.tryParse(Library.meta[it.key]?['at'] ?? '') ?? 0) > limit) isNew = true;
      final p = it.payload;
      if (p is LearnSet) {
        for (final c in p.cards) {
          card(c.key);
        }
      } else if (p is QuizSet) {
        for (final q in p.questions) {
          card('quiz:${p.id}:${q.question}');
        }
      }
    }
    var chip = 'Other';
    var title = 'Other';
    if (key != kUnsorted) {
      final m = RegExp(r'^(Ch \d+)\s*:?\s*(.*)$').firstMatch(key);
      chip = m?.group(1) ?? 'Chapter';
      title = (m != null && (m.group(2) ?? '').isNotEmpty) ? m.group(2)! : key;
    }
    String status;
    if (weak > 0) {
      status = 'Needs practice';
    } else if (total > 0 && mastered / total >= 0.9) {
      status = 'Mastered';
    } else if (started > 0) {
      status = 'Learning';
    } else {
      status = 'Not started';
    }
    return _ChInfo(key, chip, title, items, notes, quiz, words, total == 0 ? 0 : mastered / total, status, isNew);
  }

  Widget _chip(double s, String text, Color bg, Color fg, {bool selected = false}) => Container(
        padding: EdgeInsets.symmetric(horizontal: 11 * s, vertical: 4 * s),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20 * s), border: selected ? Border.all(color: Colors.white, width: 2) : null),
        child: Text(text, style: kidText(12.5 * s, c: fg)),
      );

  Future<void> _openChapter(String key, String scopeName, List<LibItem> items) async {
    final open = widget.onOpenChapter;
    if (open == null) {
      setState(() => _ch = key);
      return;
    }
    await open(key, scopeName, items);
    if (mounted) _reload();
  }

  /// The chapter shelf from the design: filters, one card per chapter with its status, content and progress.
  Widget _chapterView(double s, List<LibItem> scope, String scopeName, List<String> chapters, String subjectName, String crumb) {
    final all = <_ChInfo>[for (final c in chapters) _info(c, scope.where((LibItem x) => x.chapter == c).toList())];
    final others = scope.where((LibItem x) => x.chapter.isEmpty).toList();
    if (others.isNotEmpty) all.add(_info(kUnsorted, others));
    final nNew = all.where((_ChInfo c) => c.isNew).length;
    final nNeeds = all.where((_ChInfo c) => c.status == 'Needs practice').length;
    final nDone = all.where((_ChInfo c) => c.status == 'Mastered').length;
    final shown = all.where((_ChInfo c) {
      if (_filter == 'new') return c.isNew;
      if (_filter == 'needs') return c.status == 'Needs practice';
      if (_filter == 'done') return c.status == 'Mastered';
      return true;
    }).toList();
    final extras = widget.extras(scope, scopeName);
    final journey = widget.onOpenJourney;

    Widget filter(String id, String label) => Padding(
          padding: EdgeInsets.only(right: 10 * s),
          child: TVFocusable(
            onPressed: () => setState(() => _filter = id),
            builder: (BuildContext context, bool focused) => Container(
              padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 8 * s),
              decoration: BoxDecoration(
                color: _filter == id ? Colors.white : const Color(0xFF1E2150),
                borderRadius: BorderRadius.circular(30 * s),
                border: Border.all(color: focused ? const Color(0xFFFFB84D) : Colors.transparent, width: 3),
              ),
              child: Text(label, style: kidText(16 * s, c: _filter == id ? const Color(0xFF0E1026) : Colors.white)),
            ),
          ),
        );

    Widget pill(String label, VoidCallback f) => Padding(
          padding: EdgeInsets.only(right: 10 * s),
          child: TVFocusable(
            onPressed: f,
            builder: (BuildContext context, bool focused) => Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2F66),
                borderRadius: BorderRadius.circular(30 * s),
                border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
              ),
              child: Text(label, style: kidText(15 * s)),
            ),
          ),
        );

    Widget card(_ChInfo c, double w, bool first) {
      Color sbg, sfg, bar;
      switch (c.status) {
        case 'Mastered':
          sbg = const Color(0x40FFB84D);
          sfg = const Color(0xFFFFD9A0);
          bar = const Color(0xFFFFB84D);
          break;
        case 'Needs practice':
          sbg = const Color(0x40FF7B6B);
          sfg = const Color(0xFFFFB4A8);
          bar = const Color(0xFFFF7B6B);
          break;
        case 'Learning':
          sbg = const Color(0x4D8F82FF);
          sfg = const Color(0xFFCFC9FF);
          bar = const Color(0xFF35D0BA);
          break;
        default:
          sbg = const Color(0xFF2B2F66);
          sfg = const Color(0xFFA9ADDB);
          bar = const Color(0xFF35D0BA);
      }
      return SizedBox(
        width: w,
        child: TVFocusable(
          autofocus: first,
          scale: 1.04,
          onPressed: () => _openChapter(c.key, scopeName, c.items),
          builder: (BuildContext context, bool focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: BoxConstraints(minHeight: 128 * s),
            padding: EdgeInsets.all(14 * s),
            decoration: BoxDecoration(
              color: focused ? const Color(0xFF242862) : const Color(0xFF181B3A),
              borderRadius: BorderRadius.circular(22 * s),
              border: Border.all(color: focused ? Colors.white : (c.isNew ? const Color(0xFF35D0BA) : Colors.transparent), width: focused ? 4 : 2),
              boxShadow: focused ? const [BoxShadow(color: Color(0x668F82FF), blurRadius: 26)] : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 8 * s, runSpacing: 4 * s, children: [
                _chip(s, c.chip, const Color(0xFF2B2F66), Colors.white),
                if (c.isNew) _chip(s, 'NEW', const Color(0xFF35D0BA), const Color(0xFF06241F)) else _chip(s, c.status, sbg, sfg),
              ]),
              SizedBox(height: 8 * s),
              Text(c.title, style: kidText(20 * s), maxLines: 2, overflow: TextOverflow.ellipsis),
              SizedBox(height: 8 * s),
              Wrap(spacing: 6 * s, runSpacing: 4 * s, children: [
                if (c.notes > 0) _chip(s, 'Notes ${c.notes}', const Color(0x404C7BF0), const Color(0xFFB9CBFF)),
                if (c.quiz > 0) _chip(s, 'Quiz ${c.quiz}', const Color(0x40F2709C), const Color(0xFFFFC1D6)),
                if (c.words > 0) _chip(s, 'Words ${c.words}', const Color(0x40FFB84D), const Color(0xFFFFD9A0)),
              ]),
              SizedBox(height: 12 * s),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: c.progress, minHeight: 7 * s, color: bar, backgroundColor: const Color(0xFF2A2E63)),
              ),
            ]),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final gap = 14 * s;
      final cols = box.maxWidth >= 820 ? 4 : (box.maxWidth >= 560 ? 3 : 2);
      final w = (box.maxWidth - gap * (cols - 1) - 4) / cols;
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$subjectName chapters', style: kidText(28 * s)),
          SizedBox(height: 10 * s),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              filter('all', 'All ${all.length}'),
              filter('new', 'New $nNew'),
              filter('needs', 'Needs practice $nNeeds'),
              filter('done', 'Done $nDone'),
              SizedBox(width: 10 * s),
              if (journey != null && chapters.length >= 2)
                pill('\u{1F5FA}️ Journey', () async {
                  await journey(scopeName, chapters, <String, List<LibItem>>{for (final c in chapters) c: scope.where((LibItem x) => x.chapter == c).toList()});
                  if (mounted) _reload();
                }),
              for (final ex in extras)
                pill('${ex.emoji} ${ex.title}', () async {
                  await ex.onPressed();
                  if (mounted) _reload();
                }),
            ]),
          ),
          SizedBox(height: 14 * s),
          Wrap(spacing: gap, runSpacing: gap, children: [
            for (var i = 0; i < shown.length; i++) card(shown[i], w, i == 0),
            if (!isPhone(context))
              SizedBox(
                width: w,
                child: TVFocusable(
                  onPressed: () => showPhoneManager(context),
                  builder: (BuildContext context, bool focused) => Container(
                    constraints: BoxConstraints(minHeight: 128 * s),
                    padding: EdgeInsets.all(14 * s),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22 * s),
                      border: Border.all(color: focused ? Colors.white : const Color(0xFF5A5FA6), width: focused ? 4 : 2),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.qr_code_2_rounded, size: 40 * s, color: Colors.white),
                      SizedBox(height: 6 * s),
                      Text('Add from phone', style: kidText(18 * s)),
                      Text('Scan the QR code', style: kidText(13 * s, c: const Color(0xFFA9ADDB), w: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ]),
          SizedBox(height: 16 * s),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    if (!_loaded) {
      return ScreenFrame(title: widget.title, body: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final e = _eff();
    final tiles = <Widget Function(double, double)>[];
    Widget? chapterView;
    var crumb = widget.title;
    var gradientIndex = 0;

    Widget Function(double, double) folder(String emoji, String name, String sub, VoidCallback onTap) {
      final first = tiles.isEmpty;
      final colors = kTopicGradients[gradientIndex % kTopicGradients.length];
      gradientIndex++;
      return (double w, double h) => BigTile(emoji: emoji, title: name, subtitle: sub, colors: colors, s: s, width: w / s, height: h / s, autofocus: first, onPressed: onTap);
    }

    String countText(int n) => n == 1 ? '1 item' : '$n items';

    if (_items.isEmpty) {
      // nothing to show
    } else if (e.cls == null) {
      final keys = _classKeys();
      for (final key in keys) {
        final list = _scopeClass(key);
        final lc = Library.classById(key);
        tiles.add(folder(key == kUnsorted ? '📥' : (lc?.emoji ?? '📁'), _clsLabel(key), countText(list.length), () {
          setState(() {
            _cls = key;
            _sub = null;
            _ch = null;
            _noAutoSub = false;
          });
        }));
      }
      if (keys.length > 1) {
        tiles.add(folder('📚', 'All content', countText(_items.length), () {
          setState(() {
            _cls = kAll;
            _sub = null;
            _noAutoSub = false;
          });
        }));
      }
    } else {
      crumb = '$crumb  ›  ${_clsLabel(e.cls!)}';
      final inClass = _scopeClass(e.cls!);
      if (e.sub == null) {
        final keys = _subjectKeys(inClass);
        for (final key in keys) {
          final list = _scopeSub(inClass, key);
          final ls = Library.subjectById(key);
          tiles.add(folder(key == kUnsorted ? '📥' : (ls?.emoji ?? '📁'), _subLabel(key), countText(list.length), () {
            setState(() => _sub = key);
          }));
        }
        if (keys.length > 1) {
          tiles.add(folder('📚', 'All subjects', countText(inClass.length), () {
            setState(() => _sub = kAll);
          }));
        }
      } else {
        final scope = _scopeSub(inClass, e.sub!);
        if (e.sub != kAll || _subjectKeys(inClass).length > 1) crumb = '$crumb  ›  ${_subLabel(e.sub!)}';
        final scopeName = e.sub == kAll ? _clsLabel(e.cls!) : '${_clsLabel(e.cls!)} › ${_subLabel(e.sub!)}';
        final chapters = scope.map((LibItem x) => x.chapter).where((String c) => c.isNotEmpty).toSet().toList()..sort(Library.compareChapters);
        final inChapterList = chapters.isNotEmpty && _ch == null;
        var shownScope = scope;
        var shownName = scopeName;
        if (chapters.isNotEmpty && _ch != null) {
          shownScope = scope.where((LibItem x) => _ch == kUnsorted ? x.chapter.isEmpty : x.chapter == _ch).toList();
          final chLabel = _ch == kUnsorted ? 'Other' : _ch!;
          crumb = '$crumb  \u203A  $chLabel';
          shownName = '$scopeName \u203A $chLabel';
        }
        for (final ex in widget.extras(shownScope, shownName)) {
          final first = tiles.isEmpty;
          tiles.add((double w, double h) => BigTile(
                emoji: ex.emoji,
                title: ex.title,
                subtitle: ex.subtitle,
                colors: ex.colors,
                s: s,
                width: w / s,
                height: h / s,
                autofocus: first,
                onPressed: () async {
                  await ex.onPressed();
                  if (mounted) _reload();
                },
              ));
        }
        if (inChapterList) {
          chapterView = _chapterView(s, scope, scopeName, chapters, e.sub == kAll ? _clsLabel(e.cls!) : _subLabel(e.sub!), crumb);
          final journey = widget.onOpenJourney;
          if (journey != null && chapters.length >= 2) {
            final first = tiles.isEmpty;
            tiles.add((double w, double h) => BigTile(
                  emoji: '\u{1F5FA}\uFE0F',
                  title: 'Journey',
                  subtitle: '${chapters.length} chapters in order',
                  colors: const <Color>[Color(0xFF7C4DFF), Color(0xFF40C4FF)],
                  s: s,
                  width: w / s,
                  height: h / s,
                  autofocus: first,
                  onPressed: () async {
                    await journey(scopeName, chapters, <String, List<LibItem>>{for (final c in chapters) c: scope.where((LibItem x) => x.chapter == c).toList()});
                    if (mounted) _reload();
                  },
                ));
          }
          for (final ch in chapters) {
            final n = scope.where((LibItem x) => x.chapter == ch).length;
            tiles.add(folder('\u{1F4D8}', ch, countText(n), () async {
              final open = widget.onOpenChapter;
              if (open == null) {
                setState(() => _ch = ch);
                return;
              }
              await open(ch, scopeName, scope.where((LibItem x) => x.chapter == ch).toList());
              if (mounted) _reload();
            }));
          }
          final others = scope.where((LibItem x) => x.chapter.isEmpty).length;
          if (others > 0) tiles.add(folder('\u{1F4E5}', 'Other', countText(others), () => setState(() => _ch = kUnsorted)));
        } else {
          for (var i = 0; i < shownScope.length; i++) {
            final it = shownScope[i];
            final first = tiles.isEmpty;
            final colors = kTopicGradients[i % kTopicGradients.length];
            tiles.add((double w, double h) => BigTile(
                  emoji: it.emoji,
                  title: it.title,
                  subtitle: it.subtitle,
                  colors: colors,
                  s: s,
                  width: w / s,
                  height: h / s,
                  autofocus: first,
                  onPressed: () async {
                    await widget.onOpen(it);
                    if (mounted) _reload();
                  },
                ));
          }
        }
      }
    }

    final Widget grid = _items.isEmpty
        ? Center(child: Text(widget.emptyText, textAlign: TextAlign.center, style: kidText(24 * s)))
        : (chapterView ?? AdaptiveGrid(builders: tiles, aspect: 1.2, minWidth: 150 * s, maxWidth: 260 * s, gap: 20 * s));

    return PopScope(
      canPop: !_canGoUp(),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _up();
      },
      child: ScreenFrame(
        title: crumb,
        onBack: () {
          if (!_up()) Navigator.maybePop(context);
        },
        body: Column(
          children: [
            Expanded(child: grid),
            SizedBox(height: 8 * s),
            ButtonRow(
              spacing: 14 * s,
              children: [
                ...widget.actions(s, _reload),
                ActionButton(s: s, icon: Icons.folder_open_rounded, label: 'Organize', color: const Color(0xFF78909C), onPressed: _openOrganize),
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
// ORGANIZE: tick items, then move / rename / change picture / delete
// ----------------------------------------------------------------------
class LibraryManagerScreen extends StatefulWidget {
  const LibraryManagerScreen({super.key});
  @override
  State<LibraryManagerScreen> createState() => _LibraryManagerScreenState();
}

class _LibraryManagerScreenState extends State<LibraryManagerScreen> {
  List<LibItem> _items = <LibItem>[];
  final Set<String> _sel = <String>{};
  String _filter = kAll;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await Library.allItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loaded = true;
      _sel.removeWhere((String k) => !items.any((LibItem i) => i.key == k));
    });
  }

  List<LibItem> get _shown {
    if (_filter == kAll) return _items;
    return _items.where((LibItem i) => _filter == kUnsorted ? i.classId.isEmpty : i.classId == _filter).toList();
  }

  List<LibItem> get _selected => _items.where((LibItem i) => _sel.contains(i.key)).toList();

  String _where(LibItem it) {
    final c = Library.classById(it.classId);
    final s = Library.subjectById(it.subjectId);
    if (c == null && s == null) return '📥 Not sorted';
    return '${c?.name ?? '-'}  ›  ${s?.name ?? '-'}';
  }

  Future<void> _move() async {
    final sel = _selected;
    if (sel.isEmpty) {
      showKidsSnack(context, 'Tick the items you want to move first.');
      return;
    }
    final cls = await _chooseOne(context, 'Move ${sel.length} item(s) to which class?', _classOptions('📥  Not sorted'), newLabel: 'New class...', onNew: () => _askNewClass(context));
    if (cls == null || !mounted) return;
    final sub = await _chooseOne(context, 'Which subject?', _subjectOptions(), newLabel: 'New subject...', onNew: () => _askNewSubject(context));
    if (sub == null || !mounted) return;
    for (final it in sel) {
      await Library.setMeta(it.key, c: cls, s: sub);
    }
    _sel.clear();
    await _reload();
    if (mounted) showKidsSnack(context, 'Moved ${sel.length} item(s).');
  }

  Future<void> _chapter() async {
    final sel = _selected;
    if (sel.isEmpty) {
      showKidsSnack(context, 'Tick the items you want to put in a chapter first.');
      return;
    }
    final name = await askText(context, 'Chapter name', 'e.g. Ch 3: Subtraction   (type - for no chapter)', initial: sel.first.chapter);
    if (name == null || !mounted) return;
    final v = name.trim();
    for (final it in sel) {
      await Library.setMeta(it.key, ch: v.isEmpty ? '' : v);
    }
    _sel.clear();
    await _reload();
    if (mounted) showKidsSnack(context, 'Chapter saved for ${sel.length} item(s).');
  }

  Future<void> _rename() async {
    final sel = _selected;
    if (sel.length != 1) {
      showKidsSnack(context, 'Tick exactly one item to rename it.');
      return;
    }
    final it = sel.first;
    final name = await askText(context, 'New name', 'Type a name', initial: it.title);
    if (name == null || !mounted) return;
    if (it.kind == 'spell') {
      final up = name.toUpperCase();
      if (up != it.id) {
        await CardStore.renameCategory(it.id, up);
        final m = Library.meta['spell:${it.id}'];
        if (m != null) {
          Library.meta['spell:$up'] = Map<String, String>.from(m);
          Library.meta.remove('spell:${it.id}');
          await Library.save();
        }
        for (final p in PlayerStore.players) {
          final t = p.spellingTopics;
          if (t != null && t.contains(it.id)) p.spellingTopics = t.map((String x) => x == it.id ? up : x).toList();
        }
        await PlayerStore.save();
      }
    } else {
      await Library.setMeta(it.key, t: name);
    }
    _sel.clear();
    await _reload();
  }

  Future<void> _emoji() async {
    final sel = _selected;
    if (sel.isEmpty) {
      showKidsSnack(context, 'Tick the items first.');
      return;
    }
    final e = await Navigator.push<String>(context, MaterialPageRoute<String>(builder: (_) => const _EmojiScreen()));
    if (e == null || !mounted) return;
    for (final it in sel) {
      await Library.setMeta(it.key, e: e);
    }
    await _reload();
  }

  Future<void> _delete() async {
    final sel = _selected;
    if (sel.isEmpty) {
      showKidsSnack(context, 'Tick the items you want to delete first.');
      return;
    }
    final ok = await askConfirm(context, 'Delete ${sel.length} item(s)?\nThey wait 30 days in Parent Zone > Recently deleted.');
    if (!ok || !mounted) return;
    final cards = await CardStore.loadCards();
    for (final it in sel) {
      if (it.kind == 'quiz') {
        await Bin.putQuiz(it.id);
        await QuizStore.delete(it.id);
        for (final p in PlayerStore.players) {
          final q = p.quizIds;
          if (q != null && q.contains(it.id)) p.quizIds = q.where((String x) => x != it.id).toList();
        }
      } else if (it.kind == 'learn') {
        await Bin.putLearn(it.id);
        await LearnStore.delete(it.id);
      } else {
        await Bin.putWords(it.id, cards.where((c) => c.topic == it.id).toList());
        for (final c in cards.where((c) => c.topic == it.id).toList()) {
          await CardStore.deleteCard(c.id, keepImage: true);
        }
        for (final p in PlayerStore.players) {
          final t = p.spellingTopics;
          if (t != null && t.contains(it.id)) p.spellingTopics = t.where((String x) => x != it.id).toList();
        }
      }
      await Library.removeMeta(it.key);
    }
    await PlayerStore.save();
    _sel.clear();
    await _reload();
  }

  Future<void> _autoSort() async {
    final todo = _items.where((LibItem i) => i.classId.isEmpty || i.subjectId.isEmpty).toList();
    if (todo.isEmpty) {
      showKidsSnack(context, 'Everything is already sorted.');
      return;
    }
    final cls = await _chooseOne(context, 'Put the not-sorted items in which class?', _classOptions('(keep class as it is)'), newLabel: 'New class...', onNew: () => _askNewClass(context));
    if (cls == null || !mounted) return;
    final n = await Library.autoSort(todo, cls);
    await _reload();
    if (mounted) showKidsSnack(context, '$n item(s) sorted by their names. Check them and move any that are wrong.');
  }

  Future<void> _structure() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LibraryStructureScreen()));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    if (!_loaded) {
      return ScreenFrame(title: '🗂 Organize', body: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final shown = _shown;
    final chips = <Widget>[
      ChoiceChipTV(label: 'All', selected: _filter == kAll, s: s, onPressed: () => setState(() => _filter = kAll)),
      ChoiceChipTV(label: '📥 Not sorted', selected: _filter == kUnsorted, s: s, onPressed: () => setState(() => _filter = kUnsorted)),
      for (final c in Library.classes)
        ChoiceChipTV(label: c.name, selected: _filter == c.id, s: s, onPressed: () => setState(() => _filter = c.id)),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      final it = shown[i];
      final on = _sel.contains(it.key);
      rows.add(TVFocusable(
        autofocus: i == 0,
        scale: 1.02,
        onPressed: () => setState(() {
          if (on) {
            _sel.remove(it.key);
          } else {
            _sel.add(it.key);
          }
        }),
        builder: (BuildContext context, bool focused) => Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF16A34A).withOpacity(0.55) : Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(color: focused ? Colors.white : Colors.white24, width: focused ? 4 * s : 2 * s),
          ),
          child: Row(
            children: [
              Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 30 * s, color: Colors.white),
              SizedBox(width: 10 * s),
              Text(it.emoji, style: TextStyle(fontSize: 30 * s)),
              SizedBox(width: 10 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: kidText(22 * s)),
                    Text(it.subtitle, style: kidText(15 * s, w: FontWeight.w500)),
                  ],
                ),
              ),
              Text(_where(it), style: kidText(17 * s, w: FontWeight.w600, c: const Color(0xFFFDE047))),
            ],
          ),
        ),
      ));
    }
    if (rows.isEmpty) {
      rows.add(Padding(padding: EdgeInsets.all(24 * s), child: Text('Nothing here.', style: kidText(24 * s))));
    }
    return ScreenFrame(
      title: '🗂 Organize${_sel.isEmpty ? '' : '  (${_sel.length} ticked)'}',
      actions: [
        ActionButton(s: s, icon: Icons.auto_fix_high_rounded, label: 'Auto-sort', color: const Color(0xFF8E24AA), onPressed: _autoSort),
        SizedBox(width: 10 * s),
        ActionButton(s: s, icon: Icons.account_tree_rounded, label: 'Classes', color: const Color(0xFF3949AB), onPressed: _structure),
      ],
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(vertical: 6 * s, horizontal: 8 * s),
            child: Row(children: [for (final c in chips) Padding(padding: EdgeInsets.only(right: 10 * s), child: c)]),
          ),
          Expanded(child: FocusList(s: s, items: rows)),
          SizedBox(height: 8 * s),
          ButtonRow(
            spacing: 12 * s,
            children: [
              ActionButton(s: s, icon: Icons.select_all_rounded, label: 'All', color: const Color(0xFF5C6BC0), onPressed: () => setState(() => _sel.addAll(shown.map((LibItem i) => i.key)))),
              ActionButton(s: s, icon: Icons.deselect_rounded, label: 'None', color: const Color(0xFF64748B), onPressed: () => setState(_sel.clear)),
              ActionButton(s: s, icon: Icons.drive_file_move_rounded, label: 'Move', color: const Color(0xFF22C55E), onPressed: _move),
              ActionButton(s: s, icon: Icons.menu_book_rounded, label: 'Chapter', color: const Color(0xFF14B8A6), onPressed: _chapter),
              ActionButton(s: s, icon: Icons.edit_rounded, label: 'Rename', color: const Color(0xFF0EA5E9), onPressed: _rename),
              ActionButton(s: s, icon: Icons.emoji_emotions_rounded, label: 'Picture', color: const Color(0xFFF59E0B), onPressed: _emoji),
              ActionButton(s: s, icon: Icons.delete_rounded, label: 'Delete', color: const Color(0xFFEF4444), onPressed: _delete),
            ],
          ),
          SizedBox(height: 6 * s),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// CLASSES & SUBJECTS: add, rename, picture, order, delete
// ----------------------------------------------------------------------
class LibraryStructureScreen extends StatefulWidget {
  const LibraryStructureScreen({super.key});
  @override
  State<LibraryStructureScreen> createState() => _LibraryStructureScreenState();
}

class _LibraryStructureScreenState extends State<LibraryStructureScreen> {
  List<LibItem> _items = <LibItem>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await Library.allItems();
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _pickEmoji(void Function(String e) apply) async {
    final e = await Navigator.push<String>(context, MaterialPageRoute<String>(builder: (_) => const _EmojiScreen()));
    if (e == null) return;
    apply(e);
    await Library.save();
    if (mounted) setState(() {});
  }

  Future<void> _editClass(LibClass c) async {
    final i = await showActionMenu(context, '${c.emoji} ${c.name}', <String>['✏️  Rename', '🙂  Change picture', '⬆  Move up', '⬇  Move down', '🗑  Delete (its content becomes Not sorted)']);
    if (i == null || !mounted) return;
    if (i == 0) {
      final n = await askText(context, 'Class name', 'Type a name', initial: c.name);
      if (n != null) {
        c.name = n;
        await Library.save();
      }
    } else if (i == 1) {
      await _pickEmoji((String e) => c.emoji = e);
    } else if (i == 2) {
      await Library.moveClass(c.id, -1);
    } else if (i == 3) {
      await Library.moveClass(c.id, 1);
    } else if (i == 4) {
      final ok = await askConfirm(context, 'Delete the class ${c.name}? Its content is kept as "Not sorted".');
      if (ok) await Library.deleteClass(c.id);
    }
    await _reload();
  }

  Future<void> _editSubject(LibSubject c) async {
    final i = await showActionMenu(context, '${c.emoji} ${c.name}', <String>['✏️  Rename', '🙂  Change picture', '⬆  Move up', '⬇  Move down', '🗑  Delete (its content loses the subject)']);
    if (i == null || !mounted) return;
    if (i == 0) {
      final n = await askText(context, 'Subject name', 'Type a name', initial: c.name);
      if (n != null) {
        c.name = n;
        await Library.save();
      }
    } else if (i == 1) {
      await _pickEmoji((String e) => c.emoji = e);
    } else if (i == 2) {
      await Library.moveSubject(c.id, -1);
    } else if (i == 3) {
      await Library.moveSubject(c.id, 1);
    } else if (i == 4) {
      final ok = await askConfirm(context, 'Delete the subject ${c.name}?');
      if (ok) await Library.deleteSubject(c.id);
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final rows = <Widget>[];
    rows.add(Text('🏫  Classes', style: kidText(26 * s)));
    for (var i = 0; i < Library.classes.length; i++) {
      final c = Library.classes[i];
      final n = _items.where((LibItem it) => it.classId == c.id).length;
      rows.add(SettingLinkRow(label: '${c.emoji}  ${c.name}', value: '$n items', s: s, autofocus: i == 0, onPressed: () => _editClass(c)));
    }
    rows.add(SettingLinkRow(
      label: '➕  Add a class',
      s: s,
      onPressed: () async {
        await _askNewClass(context);
        await _reload();
      },
    ));
    rows.add(SizedBox(height: 10 * s));
    rows.add(Text('📖  Subjects', style: kidText(26 * s)));
    for (final c in Library.subjects) {
      final n = _items.where((LibItem it) => it.subjectId == c.id).length;
      rows.add(SettingLinkRow(label: '${c.emoji}  ${c.name}', value: '$n items', s: s, onPressed: () => _editSubject(c)));
    }
    rows.add(SettingLinkRow(
      label: '➕  Add a subject',
      s: s,
      onPressed: () async {
        await _askNewSubject(context);
        await _reload();
      },
    ));
    return ScreenFrame(title: '🏫 Classes & subjects', body: FocusList(s: s, items: rows));
  }
}
