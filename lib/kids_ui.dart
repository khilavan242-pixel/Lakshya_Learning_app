import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';

// ---------------------------------------------------------------- look
TextStyle kidText(double size, {FontWeight w = FontWeight.w800, Color c = Colors.white}) {
  return TextStyle(
    fontSize: size,
    fontWeight: w,
    color: c,
    shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
  );
}

double uiScale(BuildContext context) {
  return (MediaQuery.of(context).size.height / 540).clamp(0.85, 2.5).toDouble();
}

const List<Color> kTileColors = [
  Color(0xFFEF5350), Color(0xFFFFA726), Color(0xFF26A69A), Color(0xFF42A5F5),
  Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFF66BB6A), Color(0xFF5C6BC0),
];

const List<List<Color>> kTopicGradients = [
  [Color(0xFFFF9A44), Color(0xFFFC6076)],
  [Color(0xFF36D1DC), Color(0xFF5B86E5)],
  [Color(0xFF56AB2F), Color(0xFFA8E063)],
  [Color(0xFFF7971E), Color(0xFFFFD200)],
  [Color(0xFFB24592), Color(0xFFF15F79)],
  [Color(0xFF7F7FD5), Color(0xFF91EAE4)],
];

String emojiForTopic(String topic) {
  final t = topic.toUpperCase();
  if (t == 'ALL WORDS') return '📚';
  if (t.contains('FRUIT')) return '🍎';
  if (t.contains('VEG')) return '🥕';
  if (t.contains('ANIMAL')) return '🦁';
  if (t.contains('BIRD')) return '🐦';
  if (t.contains('BODY')) return '🧒';
  if (t.contains('COLOR') || t.contains('COLOUR')) return '🎨';
  if (t.contains('DAY')) return '📅';
  if (t.contains('ALPHABET')) return '🔤';
  if (t.contains('NUMBER')) return '🔢';
  if (t.contains('FAMILY')) return '👪';
  if (t.contains('FOOD')) return '🍔';
  if (t.contains('SHAPE')) return '🔷';
  if (t.contains('VEHICLE')) return '🚗';
  if (t == 'MIXED') return '⭐';
  return '🌈';
}

// ---------------------------------------------------------- background
class KidsBackground extends StatefulWidget {
  final Widget child;
  const KidsBackground({super.key, required this.child});
  @override
  State<KidsBackground> createState() => _KidsBackgroundState();
}

class _KidsBackgroundState extends State<KidsBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E86F5), Color(0xFF7C4DFF), Color(0xFFFF5FA2)],
            ),
          ),
        ),
        RepaintBoundary(child: CustomPaint(painter: _SceneryPainter(_c), size: Size.infinite)),
        widget.child,
      ],
    );
  }
}

class _Bubble {
  final double fx, fy, r, phase;
  final int speed, sway;
  final Color color;
  const _Bubble(this.fx, this.fy, this.r, this.speed, this.sway, this.phase, this.color);
}

class _SceneryPainter extends CustomPainter {
  final Animation<double> anim;
  _SceneryPainter(this.anim) : super(repaint: anim);

  static final List<_Bubble> _bubbles = _makeBubbles();

  static List<_Bubble> _makeBubbles() {
    final rnd = math.Random(7);
    const colors = <Color>[
      Color(0xFFFFEB3B), Color(0xFFFF80AB), Color(0xFF80D8FF),
      Color(0xFFB9F6CA), Color(0xFFFFAB40), Color(0xFFEA80FC),
    ];
    final out = <_Bubble>[];
    for (var i = 0; i < 16; i++) {
      out.add(_Bubble(
        rnd.nextDouble(),
        rnd.nextDouble(),
        14 + rnd.nextDouble() * 34,
        1 + rnd.nextInt(2),
        2 + rnd.nextInt(3),
        rnd.nextDouble() * math.pi * 2,
        colors[i % colors.length],
      ));
    }
    return out;
  }

  static const List<Color> _picketColors = <Color>[
    Color(0xFFEF9A9A), Color(0xFFFFF59D), Color(0xFF90CAF9), Color(0xFFA5D6A7),
    Color(0xFFF48FB1), Color(0xFFFFCC80), Color(0xFF9FA8DA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = anim.value;
    final scale = (h / 540).clamp(0.85, 2.5).toDouble();

    for (final b in _bubbles) {
      final r = b.r * scale;
      final y = ((b.fy - t * b.speed) % 1.0) * (h + 2 * r) - r;
      final x = b.fx * w + math.sin(t * math.pi * 2 * b.sway + b.phase) * 24 * scale;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = b.color.withOpacity(0.22));
      canvas.drawCircle(Offset(x - r * 0.3, y - r * 0.3), r * 0.22,
          Paint()..color = Colors.white.withOpacity(0.35));
    }

    final picketTop = h * 0.865;
    final picketBottom = h * 0.955;
    final pw = 34 * scale;
    var x = 0.0;
    var i = 0;
    while (x < w) {
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(x + 2, picketTop, x + pw - 2, picketBottom),
        topLeft: Radius.circular(pw / 2),
        topRight: Radius.circular(pw / 2),
      );
      canvas.drawRRect(rect, Paint()..color = _picketColors[i % _picketColors.length]);
      x += pw;
      i++;
    }
    canvas.drawRect(Rect.fromLTWH(0, h * 0.905, w, 5 * scale), Paint()..color = const Color(0xFF8D6E63));

    final y0 = h * 0.94;
    final grass = Path()
      ..moveTo(0, h)
      ..lineTo(0, y0)
      ..quadraticBezierTo(w * 0.15, y0 - h * 0.03, w * 0.30, y0)
      ..quadraticBezierTo(w * 0.45, y0 + h * 0.03, w * 0.60, y0)
      ..quadraticBezierTo(w * 0.80, y0 - h * 0.035, w, y0)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(grass, Paint()..color = const Color(0xFF43A047));

    const flowerX = <double>[0.06, 0.18, 0.33, 0.47, 0.62, 0.74, 0.88, 0.95];
    const flowerColors = <Color>[Color(0xFFFFEB3B), Color(0xFFFF80AB), Color(0xFFFFFFFF), Color(0xFFFFAB40)];
    for (var f = 0; f < flowerX.length; f++) {
      canvas.drawCircle(Offset(w * flowerX[f], h * (0.965 + (f % 3) * 0.008)), 5 * scale,
          Paint()..color = flowerColors[f % flowerColors.length]);
    }
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter oldDelegate) => false;
}

// ------------------------------------------------ TV focus + buttons
class TVFocusable extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool autofocus;
  final double scale;
  final int debounceMs; // ignore repeated clicks closer together than this
  final Widget Function(BuildContext context, bool focused) builder;

  const TVFocusable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.autofocus = false,
    this.scale = 1.1,
    this.debounceMs = 450,
  });

  @override
  State<TVFocusable> createState() => _TVFocusableState();
}

class _TVFocusableState extends State<TVFocusable> {
  final FocusNode _node = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  static DateTime _globalLast = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// One physical click can arrive twice (mouse click + a key event from the TV,
  /// or accidental double clicks). Repeats inside a short window are ignored.
  void _activate() {
    final cb = widget.onPressed;
    if (cb == null) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < widget.debounceMs) return;
    if (now.difference(_globalLast).inMilliseconds < 250) return;
    _last = now;
    _globalLast = now;
    cb();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!_node.hasFocus) _node.requestFocus();
      },
      child: FocusableActionDetector(
        focusNode: _node,
        autofocus: widget.autofocus,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (ActivateIntent intent) {
            _activate();
            return null;
          }),
        },
        onFocusChange: (bool f) {
          if (mounted) setState(() => _focused = f);
          if (f) CardStore.focusMove();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          child: AnimatedScale(
            scale: _focused ? widget.scale : 1.0,
            duration: const Duration(milliseconds: 140),
            child: widget.builder(context, _focused),
          ),
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onPressed;
  final double s;
  final bool autofocus;

  const ActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.s,
    this.label,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = label;
    return TVFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      scale: 1.12,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: (text == null ? 14 : 22) * s, vertical: 12 * s),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!]),
          borderRadius: BorderRadius.circular(30 * s),
          border: Border.all(color: focused ? Colors.white : Colors.white24, width: focused ? 4 * s : 2 * s),
          boxShadow: [
            BoxShadow(
              color: focused ? Colors.white.withOpacity(0.7) : Colors.black26,
              blurRadius: focused ? 22 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28 * s, color: Colors.white),
            if (text != null) SizedBox(width: 8 * s),
            if (text != null) Text(text, style: kidText(20 * s)),
          ],
        ),
      ),
    );
  }
}


// ======================================================================
// MORE SHARED WIDGETS (used by Home, Maths and Quiz modes)
// ======================================================================

/// Big colourful tile: emoji + title (+ subtitle). Works with remote/mouse/keyboard.
class BigTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final List<Color> colors;
  final double s;
  final double width;
  final double height;
  final bool autofocus;
  final VoidCallback onPressed;

  const BigTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.colors,
    required this.s,
    required this.onPressed,
    this.subtitle,
    this.width = 210,
    this.height = 190,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = math.min(width, height);
    final sub = subtitle;
    return TVFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      scale: 1.08,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width * s,
        height: height * s,
        padding: EdgeInsets.all(8 * s),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(base * 0.15 * s),
          border: Border.all(color: focused ? Colors.white : Colors.white30, width: focused ? 5 * s : 2 * s),
          boxShadow: [
            BoxShadow(
              color: focused ? Colors.white.withOpacity(0.75) : Colors.black26,
              blurRadius: focused ? 26 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: base * 0.30 * s)),
            SizedBox(height: base * 0.02 * s),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kidText(base * 0.125 * s),
            ),
            if (sub != null) Text(sub, textAlign: TextAlign.center, style: kidText(base * 0.085 * s, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Small pill button used for tabs / choices.
class ChoiceChipTV extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final double s;
  final bool autofocus;

  const ChoiceChipTV({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.s,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      scale: 1.1,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 9 * s),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDE047) : Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(24 * s),
          border: Border.all(color: focused ? Colors.white : Colors.white30, width: focused ? 4 * s : 2 * s),
          boxShadow: focused ? [BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 16)] : const <BoxShadow>[],
        ),
        child: Text(label, style: kidText(18 * s, c: selected ? Colors.black87 : Colors.white)),
      ),
    );
  }
}

BoxDecoration _rowDecoration(double s, bool focused) {
  return BoxDecoration(
    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
    borderRadius: BorderRadius.circular(20 * s),
    border: Border.all(color: focused ? Colors.white : Colors.white30, width: focused ? 4 * s : 2 * s),
    boxShadow: focused ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 16)] : const <BoxShadow>[],
  );
}

/// Whole row is one focusable button (label on the left, arrow / value on the right).
class SettingLinkRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onPressed;
  final double s;
  final bool autofocus;

  const SettingLinkRow({
    super.key,
    required this.label,
    required this.onPressed,
    required this.s,
    this.value,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    return TVFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      scale: 1.02,
      builder: (BuildContext context, bool focused) => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 14 * s),
        decoration: _rowDecoration(s, focused),
        child: Row(
          children: [
            Expanded(child: Text(label, style: kidText(22 * s))),
            if (v != null) Text(v, style: kidText(20 * s, c: const Color(0xFFFDE047))),
            SizedBox(width: 12 * s),
            Container(
              width: 38 * s,
              height: 38 * s,
              decoration: const BoxDecoration(color: Color(0xFFFDE047), shape: BoxShape.circle),
              child: Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 26 * s),
            ),
          ],
        ),
      ),
    );
  }
}

/// ON / OFF row.
class SettingToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double s;
  final bool autofocus;

  const SettingToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.s,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      autofocus: autofocus,
      onPressed: () => onChanged(!value),
      scale: 1.02,
      builder: (BuildContext context, bool focused) => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 14 * s),
        decoration: _rowDecoration(s, focused),
        child: Row(
          children: [
            Expanded(child: Text(label, style: kidText(22 * s))),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 6 * s),
              decoration: BoxDecoration(
                color: value ? const Color(0xFF84CC16) : const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(20 * s),
              ),
              child: Text(value ? 'ON' : 'OFF', style: kidText(20 * s)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row with several choices (e.g. 4 | 5 | 6). Each choice is its own focus target.
class SettingChoiceRow extends StatelessWidget {
  final String label;
  final List<String> choices;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double s;

  const SettingChoiceRow({
    super.key,
    required this.label,
    required this.choices,
    required this.selectedIndex,
    required this.onSelected,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (var i = 0; i < choices.length; i++) {
      final index = i;
      chips.add(Padding(
        padding: EdgeInsets.only(left: 10 * s),
        child: ChoiceChipTV(label: choices[i], selected: i == selectedIndex, s: s, onPressed: () => onSelected(index)),
      ));
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 10 * s),
      decoration: _rowDecoration(s, false),
      child: Row(
        children: [
          Expanded(child: Text(label, style: kidText(22 * s))),
          ...chips,
        ],
      ),
    );
  }
}

/// Standard screen: colourful background, Back button, title, optional right-side buttons.
class ScreenFrame extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;

  const ScreenFrame({super.key, required this.title, required this.body, this.actions = const <Widget>[]});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = uiScale(context);
    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32 * s, 12 * s, 32 * s, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    ActionButton(
                      s: s,
                      icon: Icons.arrow_back_rounded,
                      color: const Color(0xFF5C6BC0),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    SizedBox(width: 16 * s),
                    Expanded(child: Text(title, style: kidText(30 * s), overflow: TextOverflow.ellipsis)),
                    ...actions,
                  ],
                ),
                SizedBox(height: 8 * s),
                Expanded(child: body),
                SizedBox(height: size.height * 0.13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> askText(BuildContext context, String title, String hint) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1B4B),
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (String v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('OK')),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
}

Future<bool> askConfirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1B4B),
      content: Text(message, style: const TextStyle(fontSize: 20)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        ElevatedButton(autofocus: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
      ],
    ),
  );
  return result == true;
}

void showKidsSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}

/// Draws an analog clock (used by the "Time & Clock" maths topic).
class ClockFace extends StatelessWidget {
  final int hour;
  final int minute;
  final double size;
  const ClockFace({super.key, required this.hour, required this.minute, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _ClockPainter(hour, minute)));
  }
}

class _ClockPainter extends CustomPainter {
  final int hour;
  final int minute;
  _ClockPainter(this.hour, this.minute);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFFF7043)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07,
    );
    for (var n = 1; n <= 12; n++) {
      final a = n / 12 * math.pi * 2 - math.pi / 2;
      final p = Offset(c.dx + math.cos(a) * r * 0.78, c.dy + math.sin(a) * r * 0.78);
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(color: Colors.black87, fontSize: r * 0.22, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
    final minuteAngle = minute / 60 * math.pi * 2 - math.pi / 2;
    final hourAngle = ((hour % 12) + minute / 60) / 12 * math.pi * 2 - math.pi / 2;
    canvas.drawLine(
      c,
      Offset(c.dx + math.cos(hourAngle) * r * 0.5, c.dy + math.sin(hourAngle) * r * 0.5),
      Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      c,
      Offset(c.dx + math.cos(minuteAngle) * r * 0.72, c.dy + math.sin(minuteAngle) * r * 0.72),
      Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, r * 0.06, Paint()..color = const Color(0xFFEF4444));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) =>
      oldDelegate.hour != hour || oldDelegate.minute != minute;
}

/// Scrollable column where EVERY item is built (so the remote can reach all of them).
class FocusList extends StatelessWidget {
  final List<Widget> items;
  final double s;
  const FocusList({super.key, required this.items, required this.s});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(SizedBox(height: 10 * s));
      children.add(items[i]);
    }
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 6 * s),
      child: Column(children: children),
    );
  }
}
