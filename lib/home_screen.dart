import 'package:flutter/material.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'math_game.dart';
import 'phone_manager.dart';
import 'players.dart';
import 'quiz_game.dart';
import 'speech_service.dart';
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
        autofocus: true,
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
                        child: Text('🎈 Kids Super Learning', style: kidText(34 * s)),
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
                Text('Hi ${player.name}! What shall we play today?', style: kidText(22 * s, w: FontWeight.w600)),
                Expanded(child: AdaptiveGrid(builders: tiles, aspect: 1.1, minWidth: 150 * s, maxWidth: 270 * s, gap: 18 * s)),
                if (_savePath.isNotEmpty)
                  Text('Saved in: $_savePath', style: kidText(13 * s, w: FontWeight.w400), overflow: TextOverflow.ellipsis),
                SizedBox(height: size.height * 0.13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
