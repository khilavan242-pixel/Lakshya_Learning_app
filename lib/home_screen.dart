import 'package:flutter/material.dart';
import 'add_content.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'math_game.dart';
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

  // On a TV (wide landscape screen) the app waits for content sent from the phone.
  bool _isPhoneApp() {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final z = v.physicalSize / v.devicePixelRatio;
    return z.width < 700 && z.height > z.width;
  }

  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = uiScale(context);
    final player = PlayerStore.active;

    final tiles = <Widget Function(double, double)>[
      (double w, double h) => BigTile(
        emoji: '✏️',
        title: 'Spelling',
        subtitle: 'Unscramble letters',
        colors: const <Color>[Color(0xFFFF9A44), Color(0xFFFC6076)],
        s: s,
        width: w / s,
        height: h / s,
        onPressed: () => _go(const TopicLobbyScreen()),
      ),
      (double w, double h) => BigTile(
        emoji: '🧮',
        title: 'Maths',
        subtitle: 'Grades, topics, tests',
        colors: const <Color>[Color(0xFF36D1DC), Color(0xFF5B86E5)],
        s: s,
        width: w / s,
        height: h / s,
        onPressed: () => _go(const MathHomeScreen()),
      ),
      (double w, double h) => BigTile(
        emoji: '🧠',
        title: 'Quiz Time',
        subtitle: 'English & हिन्दी',
        colors: const <Color>[Color(0xFFB24592), Color(0xFFF15F79)],
        s: s,
        width: w / s,
        height: h / s,
        onPressed: () => _go(const QuizHomeScreen()),
      ),
      (double w, double h) => BigTile(
        emoji: '📖',
        title: 'Quick Learn',
        subtitle: 'Study with answers',
        colors: const <Color>[Color(0xFF00897B), Color(0xFF26C6DA)],
        s: s,
        width: w / s,
        height: h / s,
        onPressed: () => _go(const QuickLearnHome()),
      ),
      (double w, double h) => BigTile(
        emoji: '📅',
        title: 'Daily Challenge',
        subtitle: "Today's maths quiz",
        colors: const <Color>[Color(0xFF56AB2F), Color(0xFFA8E063)],
        s: s,
        width: w / s,
        height: h / s,
        onPressed: () => _go(MathPlayScreen(topicId: '', grade: player.grade, mode: 'daily')),
      ),
    ];

    if (isPhone(context)) return _phoneHome(context, s, player, tiles);

    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: Padding(
            padding: tvPadding(s),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [ClipRRect(borderRadius: BorderRadius.circular(8 * s), child: Image.asset('assets/logo.png', width: 38 * s, height: 38 * s)), SizedBox(width: 10 * s), Text(kAppName, style: kidText(34 * s))]),
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    ActionButton(
                      s: s,
                      icon: Icons.face_rounded,
                      label: '${player.emoji} ${player.name}',
                      color: const Color(0xFF26A69A),
                      onPressed: () => _go(const PlayersScreen()),
                    ),
                    SizedBox(width: 10 * s),
                    ActionButton(
                      s: s,
                      icon: Icons.folder_open_rounded,
                      label: 'Organize',
                      color: const Color(0xFF8E24AA),
                      onPressed: () => _go(const LibraryManagerScreen()),
                    ),
                    SizedBox(width: 10 * s),
                    ActionButton(
                      s: s,
                      icon: Icons.add_circle_rounded,
                      label: 'Add',
                      color: const Color(0xFFFFB84D),
                      onPressed: () => _go(const AddContentScreen()),
                    ),
                    SizedBox(width: 10 * s),
                    ActionButton(
                      s: s,
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      color: const Color(0xFF78909C),
                      onPressed: () => _go(const PlayerSettingsScreen(home: true)),
                    ),
                    SizedBox(width: 10 * s),
                    ActionButton(
                      s: s,
                      icon: Icons.qr_code_2_rounded,
                      color: const Color(0xFF00BFA5),
                      onPressed: () => showPhoneManager(context),
                    ),
                  ],
                ),
                SizedBox(height: 4 * s),
                _GreetingRow(player: player, s: s),
                SizedBox(height: 8 * s),
                _MissionCard(s: s, grade: player.grade, onOpen: _go),
                if (StorageLocation.isFallback && StorageLocation.mode == 'documents' && !StorageLocation.hideWarning)
                  Padding(
                    padding: EdgeInsets.only(top: 6 * s),
                    child: ActionButton(
                      s: s,
                      icon: Icons.warning_amber_rounded,
                      label: 'Old data missing? Tap to fix storage access',
                      color: const Color(0xFFF57C00),
                      onPressed: () => _go(const StorageScreen()),
                    ),
                  ),
                Expanded(child: AdaptiveGrid(builders: tiles, aspect: 1.25, minWidth: 130 * s, maxWidth: 230 * s, gap: 16 * s)),
                if (_savePath.isNotEmpty)
                  Text('Saved in: $_savePath', style: kidText(13 * s, w: FontWeight.w400), overflow: TextOverflow.ellipsis),
                SizedBox(height: size.height * 0.06),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneHome(BuildContext context, double s, Player player, List<Widget Function(double, double)> tiles) {
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
            final tileH = tileW / 1.15;
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
                    chipBtn(Icons.folder_open_rounded, 'Organize', const Color(0xFF8E24AA), () => _go(const LibraryManagerScreen())),
                    SizedBox(width: 8 * s),
                    chipBtn(Icons.settings_rounded, 'Settings', const Color(0xFF607D8B), () => _go(const PlayerSettingsScreen(home: true))),
                    SizedBox(width: 8 * s),
                    chipBtn(Icons.qr_code_2_rounded, 'Share', const Color(0xFF00A38C), () => showPhoneManager(context)),
                  ]),
                  SizedBox(height: 14 * s),
                  _GreetingRow(player: player, s: s, compact: true),
                  SizedBox(height: 12 * s),
                  _MissionCard(s: s, grade: player.grade, onOpen: _go, compact: true),
                  SizedBox(height: 14 * s),
                  Wrap(spacing: gap, runSpacing: gap, children: [for (final b in tiles) SizedBox(width: tileW, height: tileH, child: b(tileW, tileH))]),
                  if (_savePath.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 14 * s),
                      child: Text('Saved in: $_savePath', style: kidText(11 * s, w: FontWeight.w400), textAlign: TextAlign.center),
                    ),
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
            Wrap(spacing: 10 * s, runSpacing: 6 * s, children: [for (var i = 0; i < steps.length; i++) pill(i)]),
          ],
        );
        final startBtn = TVFocusable(
          autofocus: true,
          scale: 1.1,
          onPressed: () => onOpen(steps[next].screen()),
          builder: (BuildContext context, bool focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 14 * s),
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
                Icon(Icons.play_arrow_rounded, size: 34 * s, color: const Color(0xFF1A1300)),
                SizedBox(width: 6 * s),
                Text(all ? 'Play more' : 'Start ${steps[next].label}', style: kidText(22 * s, c: const Color(0xFF1A1300))),
              ],
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(22 * s, 14 * s, 22 * s, 14 * s),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3A2F9E), Color(0xFF5B3FD1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(26 * s),
            boxShadow: const [BoxShadow(color: Color(0x663A2F9E), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: compact ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, SizedBox(height: 12 * s), startBtn]) : Row(
            children: [
              Expanded(child: info),
              SizedBox(width: 16 * s),
              startBtn,
              SizedBox(width: 14 * s),
              Text('\u{1F989}', style: TextStyle(fontSize: 62 * s)),
            ],
          ),
        );
      },
    );
  }
}
