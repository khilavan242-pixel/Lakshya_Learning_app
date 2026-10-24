import 'package:flutter/material.dart';
import 'kids_ui.dart';
import 'players.dart';
import 'progress.dart';

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
                  Text('Who is learning today?', style: kidText(38 * s), textAlign: TextAlign.center),
                  SizedBox(height: 4 * s),
                  Text('Choose a profile. Each child keeps their own stars, streak and practice list.', style: kidText(15 * s, w: FontWeight.w600), textAlign: TextAlign.center),
                  SizedBox(height: 24 * s),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18 * s,
                    runSpacing: 18 * s,
                    children: [
                      for (var i = 0; i < list.length; i++)
                        _card(list[i], _cols[i % _cols.length], w, s, autofocus: list[i].id == PlayerStore.activeId),
                      _addCard(w, s),
                    ],
                  ),
                  SizedBox(height: 22 * s),
                  Text('Parents: open the Parent Zone from the menu on the home screen', style: kidText(13 * s, w: FontWeight.w600, c: const Color(0xFFA9ADDB)), textAlign: TextAlign.center),
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
            FutureBuilder<({int stars, int streak, Map<String, int> today, List<int> week})>(
              future: Progress.summary(p.id),
              builder: (BuildContext context, AsyncSnapshot<({int stars, int streak, Map<String, int> today, List<int> week})> snap) {
                final streak = snap.data?.streak ?? 0;
                final cls = p.grade <= 0 ? 'Kindergarten' : 'Class ${p.grade}';
                return Text('$cls  \u2022  $streak day streak', style: kidText(13 * s, w: FontWeight.w600), textAlign: TextAlign.center);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addChild() async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add child'),
        content: TextField(controller: ctl, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final p = await PlayerStore.add(name);
    await PlayerStore.setActive(p.id);
    if (mounted) widget.onDone();
  }

  Widget _addCard(double w, double s) {
    return TVFocusable(
      scale: 1.08,
      onPressed: _addChild,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: w,
        padding: EdgeInsets.symmetric(vertical: 20 * s, horizontal: 10 * s),
        decoration: BoxDecoration(
          color: const Color(0xFF181B3A),
          borderRadius: BorderRadius.circular(28 * s),
          border: Border.all(color: focused ? Colors.white : const Color(0xFF3A3F7A), width: 4 * s),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 64 * s, color: Colors.white70),
            SizedBox(height: 8 * s),
            Text('Add child', style: kidText(24 * s)),
            SizedBox(height: 4 * s),
            Text('Name, class, language', style: kidText(13 * s, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
