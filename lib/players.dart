import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_store.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'math_data.dart';
import 'quiz_model.dart';

// ======================================================================
// PLAYERS (children): name, avatar, level, per-child settings and the
// content each child may play.  Plus the "smart practice" memory that
// remembers which words / questions a child has mastered or struggles with.
// Saved in <Documents>/KidsSuperApp/players/
// ======================================================================

List<String>? _optList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : null;
int _intOf(dynamic v, int fallback) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? fallback);
bool _boolOf(dynamic v, bool fallback) => v is bool ? v : fallback;

class Player {
  String id;
  String name;
  String emoji;
  int grade; // 0 = Kindergarten ... 6
  String lang; // 'en' or 'hi' (voice language for maths)
  bool sound; // sound effects
  bool speak; // read questions aloud automatically
  bool hints;
  bool retries;
  bool smart; // smart practice: hide mastered content, repeat difficult content
  int options; // answer options in maths: 4, 5 or 6
  int rounds; // questions per round: 5, 10, 15, 20
  List<String>? spellingTopics; // null = all
  List<String>? quizIds; // null = all
  List<String>? mathTopics; // null = all

  Player({
    required this.id,
    required this.name,
    this.emoji = '🦁',
    this.grade = 1,
    this.lang = 'en',
    this.sound = true,
    this.speak = true,
    this.hints = true,
    this.retries = true,
    this.smart = true,
    this.options = 4,
    this.rounds = 10,
    this.spellingTopics,
    this.quizIds,
    this.mathTopics,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'emoji': emoji,
      'grade': grade,
      'lang': lang,
      'sound': sound,
      'speak': speak,
      'hints': hints,
      'retries': retries,
      'smart': smart,
      'options': options,
      'rounds': rounds,
      'spellingTopics': spellingTopics,
      'quizIds': quizIds,
      'mathTopics': mathTopics,
    };
  }

  factory Player.fromJson(Map<String, dynamic> m) {
    return Player(
      id: (m['id'] ?? 'p${DateTime.now().microsecondsSinceEpoch}').toString(),
      name: (m['name'] ?? 'Player').toString(),
      emoji: (m['emoji'] ?? '🦁').toString(),
      grade: _intOf(m['grade'], 1).clamp(0, 6).toInt(),
      lang: (m['lang'] ?? 'en').toString() == 'hi' ? 'hi' : 'en',
      sound: _boolOf(m['sound'], true),
      speak: _boolOf(m['speak'], true),
      hints: _boolOf(m['hints'], true),
      retries: _boolOf(m['retries'], true),
      smart: _boolOf(m['smart'], true),
      options: _intOf(m['options'], 4).clamp(4, 6).toInt(),
      rounds: _intOf(m['rounds'], 10).clamp(5, 20).toInt(),
      spellingTopics: _optList(m['spellingTopics']),
      quizIds: _optList(m['quizIds']),
      mathTopics: _optList(m['mathTopics']),
    );
  }
}

class PlayerStore {
  static List<Player> players = <Player>[];
  static String activeId = '';
  static Future<void> _saving = Future<void>.value();

  static const List<String> avatars = <String>[
    '🦁', '🐯', '🐼', '🦊', '🐰', '🐵', '🐶', '🐱', '🦄', '🐸', '🐧', '🐘', '🦉', '🐢', '🚀', '⭐',
  ];

  static Player get active {
    for (final p in players) {
      if (p.id == activeId) return p;
    }
    if (players.isEmpty) players.add(Player(id: 'c1', name: 'Player 1'));
    return players.first;
  }

  static Future<void> init() async {
    players = <Player>[];
    final raw = await DocStore.readJson('players', 'players.json');
    if (raw is Map && raw['players'] is List) {
      for (final e in raw['players'] as List) {
        if (e is Map) players.add(Player.fromJson(Map<String, dynamic>.from(e)));
      }
      activeId = (raw['active'] ?? '').toString();
    }
    if (players.isEmpty) await _migrate();
    if (!players.any((Player p) => p.id == activeId)) activeId = players.first.id;
    await Mastery.load(activeId);
  }

  /// First run of this version: build players from the old maths child profiles.
  static Future<void> _migrate() async {
    final kv = await AppKV.open();
    final sound = kv.getBool('math_sound') ?? true;
    final speak = kv.getBool('math_autospeak') ?? true;
    final retries = kv.getBool('math_retries') ?? true;
    final options = int.tryParse(kv.getString('math_options') ?? '') ?? 4;
    final rounds = int.tryParse(kv.getString('math_count') ?? '') ?? 10;
    final lang = kv.getString('math_lang') ?? 'en';
    final grade = int.tryParse(kv.getString('math_grade') ?? '') ?? 1;

    final prof = await DocStore.readJson('math', 'profiles.json');
    var act = '';
    if (prof is Map && prof['children'] is List) {
      for (final c in prof['children'] as List) {
        if (c is Map) {
          final id = (c['id'] ?? '').toString();
          if (id.isEmpty) continue;
          players.add(Player(
            id: id,
            name: (c['name'] ?? 'Player').toString(),
            emoji: avatars[players.length % avatars.length],
            grade: grade.clamp(0, 6).toInt(),
            lang: lang == 'hi' ? 'hi' : 'en',
            sound: sound,
            speak: speak,
            retries: retries,
            options: options.clamp(4, 6).toInt(),
            rounds: rounds.clamp(5, 20).toInt(),
          ));
        }
      }
      act = (prof['active'] ?? '').toString();
    }
    if (players.isEmpty) players.add(Player(id: 'c1', name: 'Player 1'));
    activeId = players.any((Player p) => p.id == act) ? act : players.first.id;
    await save();
  }

  static Future<void> save() {
    final data = <String, dynamic>{
      'players': players.map((Player p) => p.toJson()).toList(),
      'active': activeId,
    };
    _saving = _saving.then((_) => DocStore.writeJson('players', 'players.json', data)).catchError((Object e) {});
    return _saving;
  }

  static Future<Player> add(String name) async {
    final p = Player(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: avatars[players.length % avatars.length],
    );
    players.add(p);
    activeId = p.id;
    await save();
    await Mastery.load(p.id);
    return p;
  }

  static Future<void> setActive(String id) async {
    activeId = id;
    await save();
    await Mastery.load(id);
  }

  static Future<void> remove(String id) async {
    if (players.length <= 1) return;
    players.removeWhere((Player p) => p.id == id);
    await Mastery.deleteFor(id);
    await MathReview.reset(id);
    if (activeId == id) {
      activeId = players.first.id;
      await Mastery.load(activeId);
    }
    await save();
  }

  static Future<void> resetLearning(String id) async {
    if (id == activeId) {
      await Mastery.reset();
    } else {
      await Mastery.deleteFor(id);
    }
    await MathReview.reset(id);
  }
}

// ----------------------------------------------------------------------
// SMART PRACTICE MEMORY (Leitner-style)
//   new      : never played
//   weak     : last answer wrong / needed a hint  -> comes back first
//   learning : 1-2 clean answers in a row         -> comes back
//   mastered : 3 clean answers in a row           -> hidden
//   review   : mastered, but 7+ days ago          -> shown now and then
// ----------------------------------------------------------------------
class Mastery {
  static const int masteredStreak = 3;
  static const int reviewDays = 7;

  static String _pid = '';
  static Map<String, dynamic> _data = <String, dynamic>{};
  static Future<void> _saving = Future<void>.value();

  static Future<void> load(String playerId) async {
    _pid = playerId;
    final raw = await DocStore.readJson('players', 'mastery_$playerId.json');
    _data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static String statusOf(String key) {
    final raw = _data[key];
    if (raw is! Map) return 'new';
    final n = _intOf(raw['n'], 0);
    final s = _intOf(raw['s'], 0);
    final l = _intOf(raw['l'], 0);
    if (n == 0) return 'new';
    if (s >= masteredStreak) {
      final ageDays = (DateTime.now().millisecondsSinceEpoch - l) / 86400000;
      return ageDays >= reviewDays ? 'review' : 'mastered';
    }
    return s == 0 ? 'weak' : 'learning';
  }

  static bool isMastered(String key) => statusOf(key) == 'mastered';

  static int masteredIn<T>(List<T> items, String Function(T) keyOf) {
    var n = 0;
    for (final it in items) {
      if (isMastered(keyOf(it))) n++;
    }
    return n;
  }

  /// clean = correct at the first try and without a hint.
  static Future<void> record(String key, {required bool clean}) async {
    final raw = _data[key];
    final st = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    st['n'] = _intOf(st['n'], 0) + 1;
    st['l'] = DateTime.now().millisecondsSinceEpoch;
    if (clean) {
      st['s'] = _intOf(st['s'], 0) + 1;
      st['c'] = _intOf(st['c'], 0) + 1;
    } else {
      st['s'] = 0;
      st['w'] = _intOf(st['w'], 0) + 1;
    }
    _data[key] = st;
    await _save();
  }

  /// Items that still need practice (everything except mastered ones).
  static List<T> notMastered<T>(List<T> items, String Function(T) keyOf) {
    return items.where((T it) => !isMastered(keyOf(it))).toList();
  }

  /// Smart selection: difficult first, then in-progress, then new, then old reviews.
  static List<T> smartPick<T>(List<T> items, String Function(T) keyOf, int count) {
    final rnd = math.Random();
    final weak = <T>[];
    final learning = <T>[];
    final fresh = <T>[];
    final review = <T>[];
    for (final it in items) {
      switch (statusOf(keyOf(it))) {
        case 'weak':
          weak.add(it);
          break;
        case 'learning':
          learning.add(it);
          break;
        case 'new':
          fresh.add(it);
          break;
        case 'review':
          review.add(it);
          break;
      }
    }
    weak.shuffle(rnd);
    learning.shuffle(rnd);
    fresh.shuffle(rnd);
    review.shuffle(rnd);
    final out = <T>[];
    out.addAll(weak.take(count));
    if (out.length < count) out.addAll(learning.take(count - out.length));
    if (out.length < count) out.addAll(fresh.take(count - out.length));
    if (out.length < count) out.addAll(review.take(count - out.length));
    out.shuffle(rnd);
    return out;
  }

  static Future<void> reset() async {
    _data = <String, dynamic>{};
    await _save();
  }

  static Future<void> deleteFor(String id) => DocStore.deleteFile('players', 'mastery_$id.json');

  static Future<void> _save() {
    final id = _pid;
    if (id.isEmpty) return Future<void>.value();
    final snapshot = Map<String, dynamic>.from(_data);
    _saving = _saving.then((_) => DocStore.writeJson('players', 'mastery_$id.json', snapshot)).catchError((Object e) {});
    return _saving;
  }
}

// ----------------------------------------------------------------------
// SCREENS
// ----------------------------------------------------------------------
class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  Future<void> _add() async {
    final name = await askText(context, 'Player name', 'Type a name');
    if (name == null) return;
    final p = await PlayerStore.add(name);
    if (!mounted) return;
    setState(() {});
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PlayerSettingsScreen(playerId: p.id)));
    if (mounted) setState(() {});
  }

  Future<void> _openSettings(String id) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PlayerSettingsScreen(playerId: id)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final rows = <Widget>[];
    for (var i = 0; i < PlayerStore.players.length; i++) {
      final p = PlayerStore.players[i];
      final active = p.id == PlayerStore.activeId;
      rows.add(Row(
        children: [
          Expanded(
            child: SettingLinkRow(
              label: '${p.emoji}  ${p.name}',
              value: active ? '✅ Playing' : 'Select',
              s: s,
              autofocus: i == 0,
              onPressed: () async {
                await PlayerStore.setActive(p.id);
                if (mounted) setState(() {});
              },
            ),
          ),
          SizedBox(width: 12 * s),
          ActionButton(
            s: s,
            icon: Icons.tune_rounded,
            label: 'Settings',
            color: const Color(0xFF3949AB),
            onPressed: () => _openSettings(p.id),
          ),
        ],
      ));
    }
    return ScreenFrame(
      title: '👧👦 Who is playing?',
      actions: [
        ActionButton(s: s, icon: Icons.person_add_alt_1_rounded, label: 'Add Player', color: const Color(0xFF22C55E), onPressed: _add),
      ],
      body: FocusList(s: s, items: rows),
    );
  }
}

class PlayerSettingsScreen extends StatefulWidget {
  final String playerId;
  const PlayerSettingsScreen({super.key, required this.playerId});
  @override
  State<PlayerSettingsScreen> createState() => _PlayerSettingsScreenState();
}

class _PlayerSettingsScreenState extends State<PlayerSettingsScreen> {
  Player get _p {
    for (final p in PlayerStore.players) {
      if (p.id == widget.playerId) return p;
    }
    return PlayerStore.active;
  }

  Future<void> _commit(VoidCallback change) async {
    setState(change);
    await PlayerStore.save();
  }

  String _countText(List<String>? sel, String all) => sel == null ? all : '${sel.length} selected';

  Future<void> _pickSpelling() async {
    final cards = await CardStore.loadCards();
    final topics = <String>[];
    for (final c in cards) {
      if (!topics.contains(c.topic)) topics.add(c.topic);
    }
    topics.sort();
    if (!mounted) return;
    if (topics.isEmpty) {
      showKidsSnack(context, 'No spelling words yet. Add some with the Phone Manager.');
      return;
    }
    final p = _p;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContentPickerScreen(
          title: 'Spelling topics for ${p.name}',
          items: topics.map((String t) => PickItem(t, t, emojiForTopic(t))).toList(),
          initial: p.spellingTopics,
          onChanged: (List<String>? sel) {
            p.spellingTopics = sel;
            PlayerStore.save();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickQuiz() async {
    final sets = await QuizStore.loadAll();
    if (!mounted) return;
    if (sets.isEmpty) {
      showKidsSnack(context, 'No quizzes yet.');
      return;
    }
    final p = _p;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContentPickerScreen(
          title: 'Quizzes for ${p.name}',
          items: sets.map((QuizSet q) => PickItem(q.id, q.title, q.emoji)).toList(),
          initial: p.quizIds,
          onChanged: (List<String>? sel) {
            p.quizIds = sel;
            PlayerStore.save();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickMath() async {
    final p = _p;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContentPickerScreen(
          title: 'Maths topics for ${p.name}',
          items: kMathTopics.map((MathTopic t) => PickItem(t.id, t.name, t.emoji)).toList(),
          initial: p.mathTopics,
          onChanged: (List<String>? sel) {
            p.mathTopics = sel;
            PlayerStore.save();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final p = _p;
    const optionChoices = <String>['4', '5', '6'];
    const roundChoices = <String>['5', '10', '15', '20'];

    final rows = <Widget>[
      SettingLinkRow(
        label: 'Name',
        value: p.name,
        s: s,
        autofocus: true,
        onPressed: () async {
          final n = await askText(context, 'Player name', 'Type a name');
          if (n != null) await _commit(() => p.name = n);
        },
      ),
      SettingLinkRow(
        label: 'Avatar',
        value: p.emoji,
        s: s,
        onPressed: () async {
          final e = await Navigator.push<String>(context, MaterialPageRoute<String>(builder: (_) => const AvatarPickerScreen()));
          if (e != null) await _commit(() => p.emoji = e);
        },
      ),
      SettingChoiceRow(
        label: 'Level / Grade',
        choices: kGradeShort,
        selectedIndex: p.grade.clamp(0, 6).toInt(),
        s: s,
        onSelected: (int i) => _commit(() => p.grade = i),
      ),
      SettingChoiceRow(
        label: 'Voice language (maths)',
        choices: const <String>['English', 'हिन्दी'],
        selectedIndex: p.lang == 'hi' ? 1 : 0,
        s: s,
        onSelected: (int i) => _commit(() => p.lang = i == 1 ? 'hi' : 'en'),
      ),
      SettingToggleRow(label: 'Sound effects', value: p.sound, s: s, onChanged: (bool v) => _commit(() => p.sound = v)),
      SettingToggleRow(label: 'Read questions aloud', value: p.speak, s: s, onChanged: (bool v) => _commit(() => p.speak = v)),
      SettingToggleRow(label: 'Hint buttons', value: p.hints, s: s, onChanged: (bool v) => _commit(() => p.hints = v)),
      SettingToggleRow(label: 'Retries after a mistake', value: p.retries, s: s, onChanged: (bool v) => _commit(() => p.retries = v)),
      SettingToggleRow(label: 'Smart practice (repeat hard, hide mastered)', value: p.smart, s: s, onChanged: (bool v) => _commit(() => p.smart = v)),
      SettingChoiceRow(
        label: 'Answer options (maths)',
        choices: optionChoices,
        selectedIndex: optionChoices.indexOf(p.options.toString()).clamp(0, 2).toInt(),
        s: s,
        onSelected: (int i) => _commit(() => p.options = int.parse(optionChoices[i])),
      ),
      SettingChoiceRow(
        label: 'Questions per round',
        choices: roundChoices,
        selectedIndex: roundChoices.indexOf(p.rounds.toString()).clamp(0, 3).toInt(),
        s: s,
        onSelected: (int i) => _commit(() => p.rounds = int.parse(roundChoices[i])),
      ),
      SettingLinkRow(label: 'Spelling topics', value: _countText(p.spellingTopics, 'All'), s: s, onPressed: _pickSpelling),
      SettingLinkRow(label: 'Quizzes', value: _countText(p.quizIds, 'All'), s: s, onPressed: _pickQuiz),
      SettingLinkRow(label: 'Maths topics', value: _countText(p.mathTopics, 'All'), s: s, onPressed: _pickMath),
      SettingLinkRow(
        label: 'Reset learning progress',
        s: s,
        onPressed: () async {
          final ok = await askConfirm(context, 'Forget what ${p.name} has learned? Mastered items will come back.');
          if (!ok) return;
          await PlayerStore.resetLearning(p.id);
          if (mounted) showKidsSnack(context, 'Learning progress reset.');
        },
      ),
      SettingLinkRow(
        label: 'Delete this player',
        s: s,
        onPressed: () async {
          if (PlayerStore.players.length <= 1) {
            showKidsSnack(context, 'At least one player is needed.');
            return;
          }
          final ok = await askConfirm(context, 'Delete ${p.name} and all their progress?');
          if (!ok) return;
          await PlayerStore.remove(p.id);
          if (mounted) Navigator.pop(context);
        },
      ),
    ];
    return ScreenFrame(title: '${p.emoji} ${p.name} - Settings', body: FocusList(s: s, items: rows));
  }
}

class PickItem {
  final String id;
  final String label;
  final String emoji;
  const PickItem(this.id, this.label, this.emoji);
}

/// Tick the content a child is allowed to play. Everything ticked = "All".
class ContentPickerScreen extends StatefulWidget {
  final String title;
  final List<PickItem> items;
  final List<String>? initial;
  final void Function(List<String>? selection) onChanged;

  const ContentPickerScreen({
    super.key,
    required this.title,
    required this.items,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<ContentPickerScreen> createState() => _ContentPickerScreenState();
}

class _ContentPickerScreenState extends State<ContentPickerScreen> {
  final Set<String> _sel = <String>{};

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) _sel.addAll(init);
    if (init == null || !widget.items.any((PickItem e) => _sel.contains(e.id))) {
      _sel
        ..clear()
        ..addAll(widget.items.map((PickItem e) => e.id));
    }
  }

  void _emit() {
    final all = widget.items.every((PickItem e) => _sel.contains(e.id));
    widget.onChanged(all ? null : widget.items.where((PickItem e) => _sel.contains(e.id)).map((PickItem e) => e.id).toList());
  }

  void _toggle(String id) {
    if (_sel.contains(id)) {
      if (_sel.length <= 1) {
        showKidsSnack(context, 'Keep at least one selected.');
        return;
      }
      setState(() => _sel.remove(id));
    } else {
      setState(() => _sel.add(id));
    }
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final rows = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      final it = widget.items[i];
      rows.add(SettingToggleRow(
        label: '${it.emoji}  ${it.label}',
        value: _sel.contains(it.id),
        s: s,
        autofocus: i == 0,
        onChanged: (bool v) => _toggle(it.id),
      ));
    }
    return ScreenFrame(
      title: widget.title,
      actions: [
        ActionButton(
          s: s,
          icon: Icons.select_all_rounded,
          label: 'Select All',
          color: const Color(0xFF22C55E),
          onPressed: () {
            setState(() {
              _sel
                ..clear()
                ..addAll(widget.items.map((PickItem e) => e.id));
            });
            _emit();
          },
        ),
      ],
      body: FocusList(s: s, items: rows),
    );
  }
}

class AvatarPickerScreen extends StatelessWidget {
  const AvatarPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final tiles = <Widget>[];
    for (var i = 0; i < PlayerStore.avatars.length; i++) {
      final e = PlayerStore.avatars[i];
      tiles.add(BigTile(
        emoji: e,
        title: '',
        colors: kTopicGradients[i % kTopicGradients.length],
        s: s,
        width: 110,
        height: 100,
        autofocus: i == 0,
        onPressed: () => Navigator.pop(context, e),
      ));
    }
    return ScreenFrame(
      title: 'Choose an avatar',
      body: Center(
        child: SingleChildScrollView(
          child: Wrap(alignment: WrapAlignment.center, spacing: 14 * s, runSpacing: 14 * s, children: tiles),
        ),
      ),
    );
  }
}
