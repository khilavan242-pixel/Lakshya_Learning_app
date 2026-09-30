import 'package:flutter/material.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'math_game.dart';
import 'phone_manager.dart';
import 'quiz_game.dart';
import 'speech_service.dart';
import 'spelling_game.dart';

/// The "super app" home: pick a game mode.
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

    final tiles = <Widget>[
      BigTile(
        emoji: '✏️',
        title: 'Spelling',
        subtitle: 'Unscramble the letters',
        colors: const <Color>[Color(0xFFFF9A44), Color(0xFFFC6076)],
        s: s,
        width: 230,
        height: 200,
        autofocus: true,
        onPressed: () => _go(const TopicLobbyScreen()),
      ),
      BigTile(
        emoji: '🧮',
        title: 'Maths',
        subtitle: 'Grades, topics & tests',
        colors: const <Color>[Color(0xFF36D1DC), Color(0xFF5B86E5)],
        s: s,
        width: 230,
        height: 200,
        onPressed: () => _go(const MathHomeScreen()),
      ),
      BigTile(
        emoji: '🧠',
        title: 'Quiz Time',
        subtitle: 'English & हिन्दी',
        colors: const <Color>[Color(0xFFB24592), Color(0xFFF15F79)],
        s: s,
        width: 230,
        height: 200,
        onPressed: () => _go(const QuizHomeScreen()),
      ),
      BigTile(
        emoji: '📅',
        title: 'Daily Challenge',
        subtitle: 'Today\'s maths quiz',
        colors: const <Color>[Color(0xFF56AB2F), Color(0xFFA8E063)],
        s: s,
        width: 230,
        height: 200,
        onPressed: () => _go(MathPlayScreen(topicId: '', grade: MathStore.lastGrade, mode: 'daily')),
      ),
    ];

    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32 * s, 12 * s, 32 * s, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('🎈 Kids Super Learning', style: kidText(38 * s))),
                    ActionButton(
                      s: s,
                      icon: Icons.qr_code_2_rounded,
                      label: 'Phone Manager',
                      color: const Color(0xFF00BFA5),
                      onPressed: () => showPhoneManager(context),
                    ),
                  ],
                ),
                Text('Hi ${MathStore.activeName}! What shall we play today?', style: kidText(22 * s, w: FontWeight.w600)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(vertical: 12 * s),
                      child: Wrap(alignment: WrapAlignment.center, spacing: 24 * s, runSpacing: 24 * s, children: tiles),
                    ),
                  ),
                ),
                if (_savePath.isNotEmpty)
                  Text('Saved in: $_savePath', style: kidText(11 * s, w: FontWeight.w400), overflow: TextOverflow.ellipsis),
                SizedBox(height: size.height * 0.13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
