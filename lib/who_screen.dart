import 'package:flutter/material.dart';
import 'kids_ui.dart';
import 'players.dart';

/// "Who's learning?" Big picture cards, one per child. Works with the TV remote and with touch.
class WhoScreen extends StatefulWidget {
  final VoidCallback onDone;
  const WhoScreen({super.key, required this.onDone});
  @override
  State<WhoScreen> createState() => _WhoScreenState();
}

class _WhoScreenState extends State<WhoScreen> {
  static const List<List<Color>> _cols = <List<Color>>[
    <Color>[Color(0xFFFF9A44), Color(0xFFFC6076)],
    <Color>[Color(0xFF36D1DC), Color(0xFF5B86E5)],
    <Color>[Color(0xFFB24592), Color(0xFFF15F79)],
    <Color>[Color(0xFF00897B), Color(0xFF26C6DA)],
    <Color>[Color(0xFF56AB2F), Color(0xFFA8E063)],
  ];

  Future<void> _pick(Player p) async {
    await PlayerStore.setActive(p.id);
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final phone = isPhone(context);
    final list = PlayerStore.players;
    final w = (phone ? 150.0 : 200.0) * s;
    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20 * s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Who's learning?", style: kidText(40 * s)),
                  SizedBox(height: 4 * s),
                  Text(kAppTagline, style: kidText(16 * s, w: FontWeight.w600)),
                  SizedBox(height: 24 * s),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18 * s,
                    runSpacing: 18 * s,
                    children: [
                      for (var i = 0; i < list.length; i++)
                        _card(list[i], _cols[i % _cols.length], w, s, autofocus: list[i].id == PlayerStore.activeId),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Player p, List<Color> c, double w, double s, {required bool autofocus}) {
    return TVFocusable(
      autofocus: autofocus,
      scale: 1.08,
      onPressed: () => _pick(p),
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: w,
        padding: EdgeInsets.symmetric(vertical: 20 * s, horizontal: 10 * s),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28 * s),
          border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 4 * s),
          boxShadow: [BoxShadow(color: focused ? c.last.withOpacity(0.7) : Colors.black26, blurRadius: focused ? 30 : 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.emoji, style: TextStyle(fontSize: 64 * s)),
            SizedBox(height: 8 * s),
            Text(p.name, style: kidText(24 * s), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 4 * s),
          ],
        ),
      ),
    );
  }
}
