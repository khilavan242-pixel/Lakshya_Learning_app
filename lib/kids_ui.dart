import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_store.dart';

// ---------------------------------------------------------------- look
/// The name of the app (shown on the start screen and the home page).
const String kAppName = 'GyanTara';
const String kAppTagline = 'Learn. Shine. Repeat.';

/// 0 -> A, 1 -> B ... used for answer options.
String optionLetter(int i) => String.fromCharCode(65 + i);

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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B1550), Color(0xFF0E1026), Color(0xFF0B2B3C)],
            ),
          ),
        ),
        // soft glows (replace the old bright sky)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.9, -1.0),
              radius: 1.0,
              colors: [Color(0x553B2FB0), Color(0x003B2FB0)],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-1.0, 1.0),
              radius: 0.9,
              colors: [Color(0x4412607A), Color(0x0012607A)],
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
      canvas.drawCircle(Offset(x, y), r, Paint()..color = b.color.withOpacity(0.10));
      canvas.drawCircle(Offset(x - r * 0.3, y - r * 0.3), r * 0.22,
          Paint()..color = Colors.white.withOpacity(0.18));
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
    final titleSize = math.max(base * 0.125, 15.0);
    final subSize = math.max(base * 0.085, 12.5);
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
              style: kidText(titleSize * s),
            ),
            if (sub != null) Text(sub, textAlign: TextAlign.center, style: kidText(subSize * s, w: FontWeight.w600)),
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
  final VoidCallback? onBack; // default: leave the screen

  const ScreenFrame({super.key, required this.title, required this.body, this.actions = const <Widget>[], this.onBack});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = uiScale(context);
    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: Padding(
            padding: tvPadding(s),
            child: Column(
              children: [
                Row(
                  children: [
                    ActionButton(
                      s: s,
                      icon: Icons.arrow_back_rounded,
                      color: const Color(0xFF5C6BC0),
                      onPressed: onBack ?? () => Navigator.maybePop(context),
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

Future<bool> askConfirm(BuildContext context, String message) async {
  final s = uiScale(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1B4B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28 * s)),
      content: Text(message, style: TextStyle(fontSize: 21 * s, color: Colors.white)),
      actions: [
        ActionButton(s: s, icon: Icons.close_rounded, label: 'No', color: const Color(0xFF64748B), onPressed: () => Navigator.pop(ctx, false)),
        ActionButton(s: s, icon: Icons.check_rounded, label: 'Yes', color: const Color(0xFF22C55E), autofocus: true, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return result == true;
}

void showKidsSnack(BuildContext context, String message) {
  final s = uiScale(context);
  final h = MediaQuery.of(context).size.height;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(60 * s, 0, 60 * s, h * 0.15),
      duration: const Duration(seconds: 4),
    ),
  );
}

/// TV-safe screen margins (about 5% of the screen) so nothing is cut off by TV overscan.
EdgeInsets tvPadding(double s) => EdgeInsets.fromLTRB(44 * s, 22 * s, 44 * s, 0);

/// Several buttons in ONE row that always fits the screen (shrinks a little if needed).
class ButtonRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final WrapAlignment alignment; // kept so it can replace a Wrap without other edits
  final double runSpacing;
  const ButtonRow({
    super.key,
    required this.children,
    this.spacing = 12,
    this.alignment = WrapAlignment.center,
    this.runSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(width: spacing));
      items.add(children[i]);
    }
    return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: items));
  }
}

/// Tiles that use the free space as well as possible: as large as possible without
/// scrolling; if there are too many, they stay readable and the grid scrolls.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget Function(double width, double height)> builders;
  final double aspect; // tile width / tile height
  final double minWidth;
  final double maxWidth;
  final double gap;

  const AdaptiveGrid({
    super.key,
    required this.builders,
    required this.aspect,
    required this.minWidth,
    required this.maxWidth,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final pad = 12.0;
      final count = builders.length;
      final availW = math.max(100.0, box.maxWidth - pad * 2);
      final availH = box.maxHeight.isFinite ? box.maxHeight - pad * 2 : 100000.0;
      var bestW = 0.0;
      var fits = false;
      for (var cols = 1; cols <= math.max(1, count); cols++) {
        var cw = (availW - gap * (cols - 1)) / cols;
        if (cw < minWidth) break;
        if (cw > maxWidth) cw = maxWidth;
        final ch = cw / aspect;
        final rows = (count / cols).ceil();
        final total = rows * ch + (rows - 1) * gap;
        if (total <= availH && cw > bestW) {
          bestW = cw;
          fits = true;
        }
      }
      double tileW;
      if (fits) {
        tileW = bestW;
      } else {
        final colsFallback = math.max(1, ((availW + gap) / (minWidth + gap)).floor());
        tileW = math.min(maxWidth, (availW - gap * (colsFallback - 1)) / colsFallback);
      }
      final tileH = tileW / aspect;
      final items = <Widget>[for (final b in builders) b(tileW, tileH)];
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Wrap(alignment: WrapAlignment.center, spacing: gap, runSpacing: gap, children: items),
        ),
      );
    });
  }
}

// ----------------------------------------------------------------------
// ON-SCREEN KEYBOARD (English + Hindi). Key size adapts to the free space.
// Used for typed quiz answers and for every text box (player names ...),
// because the TV's own keyboard often does not appear.
// ----------------------------------------------------------------------
class _KeyDef {
  final String label;
  final String value;
  const _KeyDef(this.label, this.value);
}

List<List<_KeyDef>> _buildRows(List<String> rows) {
  final out = <List<_KeyDef>>[];
  for (final row in rows) {
    final keys = <_KeyDef>[];
    for (final token in row.split(' ')) {
      if (token.isEmpty) continue;
      final r = token.runes.first;
      final isMark = (r >= 0x0900 && r <= 0x0903) || (r >= 0x093E && r <= 0x094D) || r == 0x093C;
      keys.add(_KeyDef(isMark ? '\u0915$token' : token, token));
    }
    out.add(keys);
  }
  return out;
}

final List<List<_KeyDef>> _englishRows = _buildRows(<String>[
  '1 2 3 4 5 6 7 8 9 0',
  'Q W E R T Y U I O P',
  'A S D F G H J K L',
  'Z X C V B N M',
]);

final List<List<_KeyDef>> _hindiRows = _buildRows(<String>[
  'अ आ इ ई उ ऊ ऋ ए ऐ ओ औ अं अः',
  'ा ि ी ु ू ृ े ै ो ौ ं ः ँ ्',
  'क ख ग घ ङ च छ ज झ ञ',
  'ट ठ ड ढ ण त थ द ध न',
  'प फ ब भ म य र ल व श',
  'ष स ह ळ क्ष त्र ज्ञ ड़ ढ़',
  '0 1 2 3 4 5 6 7 8 9',
]);

class OnScreenKeyboard extends StatelessWidget {
  final bool hindi;
  final double s;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onToggleLanguage;
  final bool autofocus; // focus the first key when the screen opens

  const OnScreenKeyboard({
    super.key,
    required this.hindi,
    required this.s,
    required this.onKey,
    required this.onBackspace,
    required this.onToggleLanguage,
    this.autofocus = false,
  });

  Widget _key(double k, String label, VoidCallback onTap, {double wFactor = 1.0, Color color = const Color(0xFF3B82F6), bool focusFirst = false}) {
    return TVFocusable(
      debounceMs: 300,
      autofocus: focusFirst,
      onPressed: onTap,
      scale: 1.12,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: k * wFactor,
        height: k,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? Colors.amberAccent : color,
          borderRadius: BorderRadius.circular(k * 0.22),
          border: Border.all(color: focused ? Colors.white : Colors.white30, width: focused ? 3 : 1.5),
        ),
        child: Text(label, style: kidText(k * 0.5, c: focused ? Colors.black87 : Colors.white)),
      ),
    );
  }

  double _units(List<_KeyDef> row) {
    var u = 0.0;
    for (final d in row) {
      u += d.value.runes.length > 2 ? 1.5 : 1.0;
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final rows = hindi ? _hindiRows : _englishRows;
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final gap = 4.0 * s;
      final lineCount = rows.length + 1;
      var maxUnits = 7.6;
      for (final row in rows) {
        final u = _units(row);
        if (u > maxUnits) maxUnits = u;
      }
      final w = box.maxWidth.isFinite ? box.maxWidth : 800.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : 400.0;
      final byW = (w - gap * (maxUnits + 1)) / maxUnits;
      final byH = (h - gap * (lineCount + 1)) / lineCount;
      final k = math.max(20.0, math.min(math.min(byW, byH), 54.0 * s));

      final lines = <Widget>[];
      var first = true;
      for (final row in rows) {
        final keys = <Widget>[];
        for (final d in row) {
          keys.add(Padding(
            padding: EdgeInsets.all(gap / 2),
            child: _key(k, d.label, () => onKey(d.value), wFactor: d.value.runes.length > 2 ? 1.5 : 1.0, focusFirst: autofocus && first),
          ));
          first = false;
        }
        lines.add(Row(mainAxisSize: MainAxisSize.min, children: keys));
      }
      lines.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(padding: EdgeInsets.all(gap / 2), child: _key(k, 'SPACE', () => onKey(' '), wFactor: 4.0, color: const Color(0xFF6366F1))),
          Padding(padding: EdgeInsets.all(gap / 2), child: _key(k, '⌫', onBackspace, wFactor: 1.8, color: const Color(0xFFEF4444))),
          Padding(padding: EdgeInsets.all(gap / 2), child: _key(k, hindi ? 'EN' : 'हिं', onToggleLanguage, wFactor: 1.8, color: const Color(0xFF22C55E))),
        ],
      ));
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: lines),
        ),
      );
    });
  }
}

/// Ask for a text (player name, folder name ...) with the on-screen keyboard.
/// Works with the remote, a mouse and a physical keyboard. Returns null if cancelled.
Future<String?> askText(BuildContext context, String title, String hint, {String initial = ''}) async {
  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute<String>(builder: (_) => _TextEntryScreen(title: title, hint: hint, initial: initial)),
  );
  if (result == null || result.trim().isEmpty) return null;
  return result.trim();
}

class _TextEntryScreen extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;
  const _TextEntryScreen({required this.title, required this.hint, required this.initial});
  @override
  State<_TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends State<_TextEntryScreen> {
  String _text = '';
  bool _hindi = false;
  static const int _maxLength = 30;

  @override
  void initState() {
    super.initState();
    _text = widget.initial;
  }

  /// Names look right automatically: first letter of every word is a capital.
  void _type(String v) {
    if (_text.runes.length >= _maxLength) return;
    var c = v;
    if (c.length == 1 && RegExp(r'[A-Za-z]').hasMatch(c)) {
      final prev = _text.isEmpty ? ' ' : _text[_text.length - 1];
      c = prev == ' ' ? c.toUpperCase() : c.toLowerCase();
    }
    CardStore.keyClick();
    setState(() => _text = _text + c);
  }

  void _backspace() {
    if (_text.isEmpty) return;
    final runes = _text.runes.toList();
    setState(() => _text = String.fromCharCodes(runes.sublist(0, runes.length - 1)));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final ch = event.character;
    if (ch != null && ch.isNotEmpty && ch.runes.first >= 32 && ch != '\u007f') {
      _type(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final empty = _text.isEmpty;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: ScreenFrame(
        title: widget.title,
        actions: [
          ActionButton(
            s: s,
            icon: Icons.check_circle_rounded,
            label: 'Done',
            color: const Color(0xFF22C55E),
            onPressed: () => Navigator.pop(context, _text),
          ),
        ],
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 10 * s),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(18 * s),
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  empty ? widget.hint : '$_text|',
                  style: kidText(36 * s, c: empty ? Colors.white60 : Colors.white),
                ),
              ),
            ),
            SizedBox(height: 8 * s),
            Expanded(
              child: OnScreenKeyboard(
                hindi: _hindi,
                s: s,
                autofocus: true,
                onKey: _type,
                onBackspace: _backspace,
                onToggleLanguage: () => setState(() => _hindi = !_hindi),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
