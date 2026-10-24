import 'package:flutter/material.dart';
import 'add_content.dart';
import 'chapter_screen.dart';
import 'content_screen.dart';
import 'continue_shelf.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'math_game.dart';
import 'parent_zone.dart';
import 'phone_manager.dart';
import 'players.dart';
import 'progress.dart';
import 'quick_learn.dart';
import 'quiz_game.dart';
import 'speech_service.dart';
import 'storage_location.dart';
import 'storage_ui.dart';
import 'tv_link.dart';
import 'spelling_game.dart';

/// The "super app" home: pick a game mode, change player, open Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _greeted = false;
  String _savePath = '';
  Future<List<LibItem>> _newFuture = Library.newItems();
  Future<List<ContinueItem>> _contFuture = loadContinue();

  @override
  void initState() {
    super.initState();
    if (!_isPhoneApp()) TvLink.startReceiver(() {});
    DocStore.root().then((dir) {
      if (mounted) setState(() => _savePath = dir.path);
    });
    if (!_greeted) {
      _greeted = true;
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        Speaker.instance.speak("Hello! Let's learn and play.", lang: 'en');
      });
    }
  }

  Widget _newShelf(double s) => FutureBuilder<List<LibItem>>(
        future: _newFuture,
        builder: (BuildContext context, AsyncSnapshot<List<LibItem>> snap) {
          final list = snap.data ?? <LibItem>[];
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(top: 6 * s),
            child: TVFocusable(
              onPressed: () => _go(const QuickLearnLibrary()),
              builder: (BuildContext context, bool focused) => Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 4 * s),
                decoration: BoxDecoration(
                  color: const Color(0xFF181B3A),
                  borderRadius: BorderRadius.circular(16 * s),
                  border: Border.all(color: focused ? Colors.white : const Color(0xFF35D0BA), width: focused ? 3 : 2),
                ),
                child: Row(children: [
                  Text('\u{1F195}', style: TextStyle(fontSize: 22 * s)),
                  SizedBox(width: 8 * s),
                  Expanded(
                    child: Text(
                      '${list.length} new this week: ${list.take(3).map((LibItem i) => i.title).join(', ')}${list.length > 3 ? '...' : ''}',
                      style: kidText(15 * s, w: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24 * s),
                ]),
              ),
            ),
          );
        },
      );

  // On a TV (wide landscape screen) the app waits for content sent from the phone.
  bool _isPhoneApp() {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final z = v.physicalSize / v.devicePixelRatio;
    return z.width < 700 && z.height > z.width;
  }

  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) {
      setState(() {
        _newFuture = Library.newItems();
        _contFuture = loadContinue();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = uiScale(context);
    final player = PlayerStore.active;

    final modes = <_Mode>[
      _Mode('\u270F\uFE0F', 'Spelling', 'Unscramble letters', const <Color>[Color(0xFFFFB84D), Color(0xFFFF7B6B)], () => _go(const TopicLobbyScreen())),
      _Mode('\u{1F9EE}', 'Maths', 'Grades, topics, tests', const <Color>[Color(0xFF1FB4D0), Color(0xFF4C7BF0)], () => _go(const MathHomeScreen())),
      _Mode('\u{1F9E0}', 'Quiz Time', 'English & \u0939\u093F\u0928\u094D\u0926\u0940', const <Color>[Color(0xFFF2709C), Color(0xFFFF9472)], () => _go(const QuizHomeScreen())),
      _Mode('\u{1F4D6}', 'Quick Learn', 'Study with answers', const <Color>[Color(0xFF00A38C), Color(0xFF35D0BA)], () => _go(const QuickLearnHome())),
      _Mode('\u{1F4C5}', 'Daily Challenge', "Today's maths quiz", const <Color>[Color(0xFF7C4DFF), Color(0xFF8B5CF6)], () => _go(MathPlayScreen(topicId: '', grade: player.grade, mode: 'daily'))),
    ];

    if (isPhone(context)) return _phoneHome(context, s, player, modes);

    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: Row(
            children: [
              _rail(s, modes),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(26 * s, 22 * s, 26 * s, 10 * s),
                  child: SingleChildScrollView(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: _GreetingRow(player: player, s: s)),
                        SizedBox(width: 10 * s),
                        TVFocusable(
                          onPressed: () => _go(const AddContentScreen()),
                          builder: (BuildContext context, bool focused) => Container(
                            padding: EdgeInsets.all(8 * s),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB84D),
                              shape: BoxShape.circle,
                              border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
                            ),
                            child: Icon(Icons.add_rounded, size: 24 * s, color: const Color(0xFF1A1300)),
                          ),
                        ),
                        SizedBox(width: 10 * s),
                        TVFocusable(
                          onPressed: () => _go(const PlayersScreen()),
                          builder: (BuildContext context, bool focused) => Container(
                            padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
                            decoration: BoxDecoration(
                              color: const Color(0xFF26A69A),
                              borderRadius: BorderRadius.circular(30 * s),
                              border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
                            ),
                            child: Text('${player.emoji} ${player.name}', style: kidText(17 * s)),
                          ),
                        ),
                      ]),
                      SizedBox(height: 12 * s),
                      _MissionCard(s: s, grade: player.grade, onOpen: _go),
                      _newShelf(s),
                      SizedBox(height: 14 * s),
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text('Keep going', style: kidText(20 * s)),
                        SizedBox(width: 10 * s),
                        Text('Pick up where you stopped', style: kidText(13 * s, c: const Color(0xFFA9ADDB), w: FontWeight.w700)),
                      ]),
                      SizedBox(height: 8 * s),
                      SizedBox(height: 118 * s, child: _keepGoing(s, modes, column: false)),
                      SizedBox(height: 12 * s),
                    ],
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Keep going": what the child practised last. A new child sees the first games instead.
  Widget _keepGoing(double s, List<_Mode> modes, {required bool column}) => FutureBuilder<List<ContinueItem>>(
        future: _contFuture,
        builder: (BuildContext context, AsyncSnapshot<List<ContinueItem>> snap) {
          final list = snap.data ?? <ContinueItem>[];
          final List<Widget> cards = list.isEmpty
              ? <Widget>[for (final m in modes.take(3)) _ModeCard(mode: m, s: s, fill: !column)]
              : <Widget>[
                  for (final c in list)
                    _ContinueCard(
                      c: c,
                      s: s,
                      fill: !column,
                      onTap: () => _go(ChapterScreen(title: c.item.title, trail: c.item.chapter, items: <LibItem>[c.item])),
                    ),
                ];
          if (column) {
            return Column(children: [for (final w in cards) Padding(padding: EdgeInsets.only(bottom: 10 * s), child: w)]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var i = 0; i < cards.length; i++) Expanded(child: Padding(padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 14 * s), child: cards[i]))],
          );
        },
      );

  /// Left navigation rail (TV): big, easy to reach with the remote.
  Widget _rail(double s, List<_Mode> modes) {
    Widget item(IconData icon, String label, VoidCallback onTap, {bool active = false}) => Padding(
          padding: EdgeInsets.symmetric(vertical: 3 * s),
          child: TVFocusable(
            onPressed: onTap,
            scale: 1.06,
            builder: (BuildContext context, bool focused) => Container(
              width: 74 * s,
              padding: EdgeInsets.symmetric(vertical: 6 * s),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF2B2F66) : (focused ? const Color(0x33FFFFFF) : Colors.transparent),
                borderRadius: BorderRadius.circular(18 * s),
                border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 24 * s, color: active || focused ? Colors.white : const Color(0xFFB4B8E6)),
                SizedBox(height: 3 * s),
                Text(label, style: kidText(11.5 * s, c: active || focused ? Colors.white : const Color(0xFFB4B8E6))),
              ]),
            ),
          ),
        );
    return Container(
      width: 94 * s,
      padding: EdgeInsets.symmetric(vertical: 12 * s),
      decoration: const BoxDecoration(color: Color(0xB80A0B20), border: Border(right: BorderSide(color: Color(0x12FFFFFF)))),
      child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(10 * s), child: Image.asset('assets/logo.png', width: 40 * s, height: 40 * s)),
        SizedBox(height: 10 * s),
        item(Icons.home_rounded, 'Home', () {}, active: true),
        item(Icons.menu_book_rounded, 'Learn', () => _go(const QuickLearnHome())),
        item(Icons.sports_esports_rounded, 'Play', () => _go(PlayHubScreen(modes: modes))),
        item(Icons.folder_open_rounded, 'Library', () => _go(const LibraryManagerScreen())),
        const Spacer(),
        item(Icons.lock_rounded, 'Parents', () => _go(const ParentZoneScreen())),
        item(Icons.settings_rounded, 'Settings', () => _go(const PlayerSettingsScreen(home: true))),
        item(Icons.qr_code_2_rounded, 'Share', () => showPhoneManager(context)),
      ]),
    );
  }

  Widget _phoneHome(BuildContext context, double s, Player player, List<_Mode> modes) {
    Widget chipBtn(IconData icon, String label, Color c, VoidCallback f) => Expanded(
          child: TVFocusable(
            onPressed: f,
            builder: (BuildContext context, bool focused) => Container(
              padding: EdgeInsets.symmetric(vertical: 10 * s),
              decoration: BoxDecoration(
                color: c.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18 * s),
                border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white, size: 24 * s),
                SizedBox(height: 2 * s),
                Text(label, style: kidText(12 * s), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
            const gap = 12.0;
            final tileW = (box.maxWidth - 28 - gap) / 2;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/logo.png', width: 40 * s, height: 40 * s)),
                    SizedBox(width: 10 * s),
                    Expanded(child: Text(kAppName, style: kidText(28 * s))),
                    GestureDetector(
                      onTap: () => _go(const PlayersScreen()),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
                        decoration: BoxDecoration(color: const Color(0xFF26A69A), borderRadius: BorderRadius.circular(30 * s)),
                        child: Text('${player.emoji} ${player.name}', style: kidText(16 * s), maxLines: 1),
                      ),
                    ),
                  ]),
                  SizedBox(height: 12 * s),
                  Row(children: [
                    chipBtn(Icons.add_circle_rounded, 'Add', const Color(0xFFF59E0B), () => _go(const AddContentScreen())),
                    SizedBox(width: 8 * s),
                    chipBtn(Icons.folder_open_rounded, 'Content', const Color(0xFF8E24AA), () => _go(const ContentScreen())),
                    SizedBox(width: 8 * s),
                    chipBtn(Icons.lock_rounded, 'Parent', const Color(0xFF5C6BC0), () => _go(const ParentZoneScreen())),
                    SizedBox(width: 8 * s),
                    chipBtn(Icons.settings_rounded, 'Settings', const Color(0xFF607D8B), () => _go(const PlayerSettingsScreen(home: true))),
                    SizedBox(width: 8 * s),
                    chipBtn(Icons.qr_code_2_rounded, 'Share', const Color(0xFF00A38C), () => showPhoneManager(context)),
                  ]),
                  SizedBox(height: 14 * s),
                  _GreetingRow(player: player, s: s, compact: true),
                  SizedBox(height: 12 * s),
                  _MissionCard(s: s, grade: player.grade, onOpen: _go, compact: true),
                  _newShelf(s),
                  SizedBox(height: 14 * s),
                  Text('Keep going', style: kidText(20 * s)),
                  SizedBox(height: 10 * s),
                  _keepGoing(s, modes, column: true),
                  SizedBox(height: 6 * s),
                  Text('Learn and play', style: kidText(20 * s)),
                  SizedBox(height: 10 * s),
                  Wrap(spacing: gap, runSpacing: gap, children: [for (final m in modes) SizedBox(width: tileW, child: _ModeCard(mode: m, s: s))]),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}


String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Good morning, Name" with the streak and star counters.
class _GreetingRow extends StatelessWidget {
  final Player player;
  final double s;
  final bool compact;
  const _GreetingRow({required this.player, required this.s, this.compact = false});

  Widget _chip(String text, Color c) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
        decoration: BoxDecoration(color: c.withOpacity(0.22), borderRadius: BorderRadius.circular(30 * s), border: Border.all(color: c.withOpacity(0.7), width: 2)),
        child: Text(text, style: kidText(18 * s)),
      );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_greeting()}, ${player.name}!', style: kidText(24 * s)),
        SizedBox(height: 8 * s),
        ValueListenableBuilder<int>(
          valueListenable: Progress.changed,
          builder: (BuildContext context, int _, Widget? __) => Wrap(spacing: 10 * s, runSpacing: 6 * s, children: [
            _chip('\u{1F525} ${Progress.streak} day streak', const Color(0xFFFF7B6B)),
            _chip('\u2B50 ${Progress.stars} stars', const Color(0xFFFFB84D)),
          ]),
        ),
      ]);
    }
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${_greeting()}, ${player.name}!', style: kidText(26 * s)),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: Progress.changed,
          builder: (BuildContext context, int _, Widget? __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _chip('\u{1F525} ${Progress.streak} day streak', const Color(0xFFFF7B6B)),
              SizedBox(width: 10 * s),
              _chip('\u2B50 ${Progress.stars} stars', const Color(0xFFFFB84D)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's Mission: three short steps (spelling, maths, quiz). Each is done after [Progress.stepGoal] answers.
class _MissionCard extends StatelessWidget {
  final double s;
  final int grade;
  final Future<void> Function(Widget screen) onOpen;
  final bool compact;
  const _MissionCard({required this.s, required this.grade, required this.onOpen, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Progress.changed,
      builder: (BuildContext context, int _, Widget? __) {
        final steps = <({String emoji, String label, String mode, Widget Function() screen})>[
          (emoji: '\u270F\uFE0F', label: 'Spelling', mode: 'spell', screen: () => const TopicLobbyScreen()),
          (emoji: '\u{1F9EE}', label: 'Maths', mode: 'math', screen: () => MathPlayScreen(topicId: '', grade: grade, mode: 'daily')),
          (emoji: '\u{1F9E0}', label: 'Quiz', mode: 'quiz', screen: () => const QuizHomeScreen()),
        ];
        final doneCount = steps.where((e) => Progress.today(e.mode) >= Progress.stepGoal).length;
        final all = doneCount == steps.length;
        var next = steps.indexWhere((e) => Progress.today(e.mode) < Progress.stepGoal);
        if (next < 0) next = 0;

        Widget pill(int i) {
          final st = steps[i];
          final n = Progress.today(st.mode);
          final done = n >= Progress.stepGoal;
          final current = !all && i == next;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 7 * s),
            decoration: BoxDecoration(
              color: done ? const Color(0xFF35D0BA).withOpacity(0.28) : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30 * s),
              border: Border.all(color: current ? const Color(0xFFFFB84D) : Colors.transparent, width: 3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(st.emoji, style: TextStyle(fontSize: 20 * s)),
                SizedBox(width: 6 * s),
                Text(st.label, style: kidText(17 * s)),
                SizedBox(width: 8 * s),
                Text(done ? '\u2705' : '${n.clamp(0, Progress.stepGoal)}/${Progress.stepGoal}', style: kidText(16 * s, w: FontWeight.w700)),
              ],
            ),
          );
        }

        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(all ? 'MISSION COMPLETE!' : "TODAY'S MISSION", style: kidText(15 * s, c: const Color(0xFFFFD9A0))),
            SizedBox(height: 2 * s),
            Text(
              all ? 'Great job! Play more to earn extra stars.' : 'Do ${Progress.stepGoal} in each to finish. $doneCount of ${steps.length} done.',
              style: kidText(18 * s, w: FontWeight.w600),
            ),
            SizedBox(height: 8 * s),
            if (compact)
              Wrap(spacing: 10 * s, runSpacing: 6 * s, children: [for (var i = 0; i < steps.length; i++) pill(i)])
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(children: [for (var i = 0; i < steps.length; i++) Padding(padding: EdgeInsets.only(right: 10 * s), child: pill(i))]),
              ),
          ],
        );
        final startBtn = TVFocusable(
          autofocus: true,
          scale: 1.1,
          onPressed: () => onOpen(steps[next].screen()),
          builder: (BuildContext context, bool focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 8 * s),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB84D),
              borderRadius: BorderRadius.circular(40 * s),
              border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 4 * s),
              boxShadow: [BoxShadow(color: focused ? const Color(0x99FFB84D) : Colors.black26, blurRadius: focused ? 30 : 8)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 26 * s, color: const Color(0xFF1A1300)),
                SizedBox(width: 6 * s),
                Text(all ? 'Play more' : 'Start ${steps[next].label}', style: kidText(18 * s, c: const Color(0xFF1A1300))),
              ],
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(22 * s, 10 * s, 22 * s, 10 * s),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3A2F9E), Color(0xFF5B3FD1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(26 * s),
            boxShadow: const [BoxShadow(color: Color(0x663A2F9E), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: compact ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, SizedBox(height: 12 * s), startBtn]) : Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  info,
                  SizedBox(height: 10 * s),
                  Row(children: [
                    startBtn,
                    SizedBox(width: 12 * s),
                    Text('Press OK', style: kidText(13 * s, c: const Color(0xFFE6E3FF), w: FontWeight.w700)),
                  ]),
                ]),
              ),
              SizedBox(width: 10 * s),
              SizedBox(width: 120 * s, height: 112 * s, child: CustomPaint(painter: _OwlPainter())),
            ],
          ),
        );
      },
    );
  }
}


class _Mode {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  const _Mode(this.emoji, this.title, this.subtitle, this.colors, this.onTap);
}

/// A premium dark card with a coloured top strip (same look as the design).
class _ModeCard extends StatelessWidget {
  final _Mode mode;
  final double s;
  final bool fill;
  const _ModeCard({required this.mode, required this.s, this.fill = false});

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      scale: 1.05,
      onPressed: mode.onTap,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: const Color(0xFF181B3A),
          borderRadius: BorderRadius.circular(22 * s),
          border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
          boxShadow: focused ? [BoxShadow(color: mode.colors.last.withOpacity(0.55), blurRadius: 26)] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19 * s),
          child: Column(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: (fill ? 46 : 66) * s,
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14 * s),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(gradient: LinearGradient(colors: mode.colors)),
                child: Text(mode.emoji, style: TextStyle(fontSize: (fill ? 26 : 34) * s)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 12 * s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(mode.title, style: kidText(17 * s), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2 * s),
                  Text(mode.subtitle, style: kidText(12.5 * s, c: const Color(0xFFA9ADDB), w: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Lumi the owl mascot from the design (graduation cap), drawn with code so it is sharp on any screen.
class _OwlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 210, size.height / 196);
    Paint f(int c) => Paint()..color = Color(c);
    canvas.drawOval(Rect.fromCenter(center: const Offset(105, 190), width: 112, height: 12), f(0x40000000));
    canvas.drawOval(Rect.fromCenter(center: const Offset(105, 118), width: 124, height: 136), f(0xFFA99BFF));
    canvas.drawOval(Rect.fromCenter(center: const Offset(105, 132), width: 80, height: 92), f(0xFFE4DFFF));
    for (final w in const <List<double>>[<double>[46, 124, 14], <double>[164, 124, -14]]) {
      canvas.save();
      canvas.translate(w[0], w[1]);
      canvas.rotate(w[2] * 3.14159265 / 180);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 32, height: 76), f(0xFF8B7BF2));
      canvas.restore();
    }
    canvas.drawCircle(const Offset(80, 96), 25, f(0xFFFFFFFF));
    canvas.drawCircle(const Offset(130, 96), 25, f(0xFFFFFFFF));
    canvas.drawCircle(const Offset(84, 98), 13, f(0xFF14163A));
    canvas.drawCircle(const Offset(126, 98), 13, f(0xFF14163A));
    canvas.drawCircle(const Offset(88, 93), 4.5, f(0xFFFFFFFF));
    canvas.drawCircle(const Offset(130, 93), 4.5, f(0xFFFFFFFF));
    canvas.drawPath(Path()..moveTo(96, 112)..lineTo(105, 126)..lineTo(114, 112)..close(), f(0xFFFFB84D));
    canvas.drawPath(Path()..moveTo(105, 44)..lineTo(167, 68)..lineTo(105, 92)..lineTo(43, 68)..close(), f(0xFF1B1C45));
    canvas.drawPath(
      Path()
        ..moveTo(70, 78)
        ..lineTo(70, 92)
        ..cubicTo(70, 102, 140, 102, 140, 92)
        ..lineTo(140, 78)
        ..lineTo(105, 92)
        ..close(),
      f(0xFF2A2C66),
    );
    final line = Paint()
      ..color = const Color(0xFFFFB84D)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(162, 70), const Offset(162, 104), line);
    canvas.drawCircle(const Offset(162, 108), 6, f(0xFFFFB84D));
    line.strokeWidth = 4;
    canvas.drawLine(const Offset(88, 184), const Offset(86, 191), line);
    canvas.drawLine(const Offset(96, 184), const Offset(97, 191), line);
    canvas.drawLine(const Offset(122, 184), const Offset(121, 191), line);
    canvas.drawLine(const Offset(114, 184), const Offset(116, 191), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// "Play" page: all the games in big cards.
class PlayHubScreen extends StatelessWidget {
  final List<_Mode> modes;
  const PlayHubScreen({super.key, required this.modes});

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    return ScreenFrame(
      title: '\u{1F3AE} Play',
      body: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
        final cols = box.maxWidth >= 800 ? 3 : 2;
        final gap = 14 * s;
        final w = (box.maxWidth - gap * (cols - 1) - 4) / cols;
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 20 * s),
          child: Wrap(spacing: gap, runSpacing: gap, children: [for (final m in modes) SizedBox(width: w, child: _ModeCard(mode: m, s: s))]),
        );
      }),
    );
  }
}

/// "Keep going" card from the design: coloured strip, title and a progress bar.
class _ContinueCard extends StatelessWidget {
  final ContinueItem c;
  final double s;
  final bool fill;
  final VoidCallback onTap;
  const _ContinueCard({required this.c, required this.s, required this.onTap, this.fill = false});

  @override
  Widget build(BuildContext context) {
    final kind = c.item.kind;
    final colors = kind == 'quiz'
        ? const <Color>[Color(0xFFF2709C), Color(0xFFFF9472)]
        : (kind == 'learn' ? const <Color>[Color(0xFF1FB4D0), Color(0xFF4C7BF0)] : const <Color>[Color(0xFFFFB84D), Color(0xFFFF7B6B)]);
    final label = kind == 'quiz' ? 'Quiz' : (kind == 'learn' ? 'Notes' : 'Spelling');
    return TVFocusable(
      scale: 1.05,
      onPressed: onTap,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: const Color(0xFF181B3A),
          borderRadius: BorderRadius.circular(22 * s),
          border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
          boxShadow: focused ? [BoxShadow(color: colors.last.withOpacity(0.55), blurRadius: 26)] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19 * s),
          child: Column(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: (fill ? 44 : 56) * s,
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14 * s),
                decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
                child: Row(children: [
                  Text(c.item.emoji, style: TextStyle(fontSize: 28 * s)),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 3 * s),
                    decoration: BoxDecoration(color: const Color(0x40000000), borderRadius: BorderRadius.circular(20 * s)),
                    child: Text(label, style: kidText(12.5 * s)),
                  ),
                ]),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14 * s, 8 * s, 14 * s, 12 * s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(c.item.title, style: kidText(16 * s), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 8 * s),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: c.progress, minHeight: 7 * s, color: const Color(0xFF35D0BA), backgroundColor: const Color(0xFF2A2E63)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
