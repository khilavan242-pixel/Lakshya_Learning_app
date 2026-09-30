import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'sync_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameAudioService.instance.init();
  await CardStore.init();
  runApp(const KidsSpellingTVApp());
}

class KidsSpellingTVApp extends StatelessWidget {
  const KidsSpellingTVApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Spelling TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const TopicLobbyScreen(),
    );
  }
}

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

const List<Color> _tileColors = [
  Color(0xFFEF5350), Color(0xFFFFA726), Color(0xFF26A69A), Color(0xFF42A5F5),
  Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFF66BB6A), Color(0xFF5C6BC0),
];

const List<List<Color>> _topicGradients = [
  [Color(0xFFFF9A44), Color(0xFFFC6076)],
  [Color(0xFF36D1DC), Color(0xFF5B86E5)],
  [Color(0xFF56AB2F), Color(0xFFA8E063)],
  [Color(0xFFF7971E), Color(0xFFFFD200)],
  [Color(0xFFB24592), Color(0xFFF15F79)],
  [Color(0xFF7F7FD5), Color(0xFF91EAE4)],
];

String _emojiFor(String topic) {
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
  final Widget Function(BuildContext context, bool focused) builder;

  const TVFocusable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.autofocus = false,
    this.scale = 1.1,
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

  void _activate() {
    final cb = widget.onPressed;
    if (cb != null) cb();
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

// --------------------------------------------------------- 1. LOBBY
class TopicLobbyScreen extends StatefulWidget {
  const TopicLobbyScreen({super.key});
  @override
  State<TopicLobbyScreen> createState() => _TopicLobbyScreenState();
}

class _TopicLobbyScreenState extends State<TopicLobbyScreen> {
  Map<String, List<WordCard>> _topics = {};
  TVSyncServer? _syncServer;
  bool _loaded = false;
  int _lastCount = -1;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void dispose() {
    _syncServer?.stopServer();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final cards = await CardStore.loadCards();
    final topics = <String, List<WordCard>>{};
    if (cards.isNotEmpty) topics['ALL WORDS'] = List<WordCard>.of(cards);
    for (final card in cards) {
      if (card.topic == 'ALL WORDS') continue;
      topics.putIfAbsent(card.topic, () => <WordCard>[]).add(card);
    }
    if (!mounted) return;
    final added = _lastCount >= 0 && cards.length > _lastCount;
    _lastCount = cards.length;
    if (added) GameAudioService.instance.playSuccessFanfare();
    setState(() {
      _topics = topics;
      _loaded = true;
    });
  }

  // Called by the sync server after ANY change made from the phone.
  void _onServerChanged() {
    _loadCards();
  }

  Future<String?> _findLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      String? fallback;
      for (final i in ifaces) {
        for (final a in i.addresses) {
          if (a.isLoopback) continue;
          final ip = a.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) return ip;
          fallback ??= ip;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSyncModal() async {
    if (_syncServer != null) return;
    final server = TVSyncServer(onChanged: _onServerChanged);
    _syncServer = server;
    final port = await server.startServer();
    final ip = await _findLocalIp();

    if (!mounted) {
      await server.stopServer();
      _syncServer = null;
      return;
    }

    final url = (port != null && ip != null) ? 'http://$ip:$port' : null;
    final s = uiScale(context);

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('📱 Scan to Manage Words', style: kidText(26 * s)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 700 * s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (url != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(data: url, size: 170 * s),
                ),
              SizedBox(width: 20 * s),
              Flexible(
                child: Text(
                  url != null
                      ? 'Connect your phone to the same Wi-Fi.\nOpen: $url\n\nAdd words & photos, manage categories, pronunciation and the report card from your phone.'
                      : 'Could not start the sync server. Please check the Wi-Fi connection.',
                  style: TextStyle(fontSize: 17 * s, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: TextStyle(fontSize: 18 * s)),
          ),
        ],
      ),
    );

    await server.stopServer();
    _syncServer = null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = uiScale(context);
    final keys = _topics.keys.toList();

    Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white));
    } else if (keys.isEmpty) {
      body = Center(
        child: Text(
          'No words yet!\nPress "Add Words" and add some from your phone.',
          textAlign: TextAlign.center,
          style: kidText(24 * s),
        ),
      );
    } else {
      final cards = <Widget>[];
      for (var i = 0; i < keys.length; i++) {
        final topic = keys[i];
        cards.add(TopicCard(
          topic: topic,
          count: _topics[topic]!.length,
          colorIndex: i,
          s: s,
          autofocus: i == 0,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TVGameScreen(deck: _topics[topic]!, title: topic),
              ),
            );
          },
        ));
      }
      body = Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 16 * s),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 24 * s,
            runSpacing: 24 * s,
            children: cards,
          ),
        ),
      );
    }

    return Scaffold(
      body: KidsBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32 * s, 12 * s, 32 * s, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('🌈 Pick a Topic!', style: kidText(38 * s))),
                    ActionButton(
                      s: s,
                      icon: Icons.qr_code_2_rounded,
                      label: 'Add Words',
                      color: const Color(0xFF00BFA5),
                      onPressed: _openSyncModal,
                    ),
                  ],
                ),
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

class TopicCard extends StatelessWidget {
  final String topic;
  final int count;
  final int colorIndex;
  final double s;
  final bool autofocus;
  final VoidCallback onPressed;

  const TopicCard({
    super.key,
    required this.topic,
    required this.count,
    required this.colorIndex,
    required this.s,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _topicGradients[colorIndex % _topicGradients.length];
    return TVFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      scale: 1.1,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 210 * s,
        height: 190 * s,
        padding: EdgeInsets.all(12 * s),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28 * s),
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
            Text(_emojiFor(topic), style: TextStyle(fontSize: 54 * s)),
            SizedBox(height: 6 * s),
            Text(topic, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: kidText(26 * s)),
            SizedBox(height: 4 * s),
            Text(count == 1 ? '1 word' : '$count words', style: kidText(17 * s, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------ 2. GAME SCREEN
class TVGameScreen extends StatefulWidget {
  final List<WordCard> deck;
  final String title;
  const TVGameScreen({super.key, required this.deck, this.title = 'Spelling'});
  @override
  State<TVGameScreen> createState() => _TVGameScreenState();
}

class _TVGameScreenState extends State<TVGameScreen> {
  int _currentIndex = 0;
  List<String> _shuffledLetters = [];
  final List<int> _selectedTileIndices = [];
  bool _locked = false;
  bool _solved = false;
  bool _wrong = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _prepareWord();
  }

  void _prepareWord() {
    final word = widget.deck[_currentIndex].word;
    final scrambled = word.split('');
    for (var i = 0; i < 10; i++) {
      scrambled.shuffle();
      if (scrambled.join() != word) break;
    }
    _shuffledLetters = scrambled;
    _selectedTileIndices.clear();
    _locked = false;
    _solved = false;
    _wrong = false;
    _token++;
    CardStore.speak(word);
  }

  void _goTo(int delta) {
    final n = widget.deck.length;
    setState(() {
      _currentIndex = (_currentIndex + delta + n) % n;
      _prepareWord();
    });
  }

  void _nextWord() => _goTo(1);
  void _previousWord() => _goTo(-1);

  void _onLetterSelected(int index) {
    if (_locked || _selectedTileIndices.contains(index)) return;
    CardStore.keyClick();
    setState(() => _selectedTileIndices.add(index));

    final target = widget.deck[_currentIndex].word;
    if (_selectedTileIndices.length != target.length) return;

    final spelled = _selectedTileIndices.map((i) => _shuffledLetters[i]).join();
    final token = _token;
    if (spelled == target) {
      setState(() {
        _locked = true;
        _solved = true;
      });
      CardStore.recordResult(target, correct: true);
      GameAudioService.instance.playSuccessFanfare();
      CardStore.speak(target);
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (mounted && token == _token) _nextWord();
      });
    } else {
      setState(() {
        _locked = true;
        _wrong = true;
      });
      CardStore.recordResult(target, wrong: true);
      GameAudioService.instance.playErrorFeedback();
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted && token == _token) {
          setState(() {
            _selectedTileIndices.clear();
            _locked = false;
            _wrong = false;
          });
        }
      });
    }
  }

  void _undoLastLetter() {
    if (_locked || _selectedTileIndices.isEmpty) return;
    CardStore.keyClick();
    setState(() => _selectedTileIndices.removeLast());
  }

  int? _findTile(String letter) {
    for (var i = 0; i < _shuffledLetters.length; i++) {
      if (_shuffledLetters[i] == letter && !_selectedTileIndices.contains(i)) return i;
    }
    return null;
  }

  void _triggerHint() {
    if (_locked) return;
    final target = widget.deck[_currentIndex].word;

    var ok = 0;
    while (ok < _selectedTileIndices.length && _shuffledLetters[_selectedTileIndices[ok]] == target[ok]) {
      ok++;
    }
    if (ok < _selectedTileIndices.length) {
      setState(() => _selectedTileIndices.removeRange(ok, _selectedTileIndices.length));
    }
    if (_selectedTileIndices.length >= target.length) return;

    final idx = _findTile(target[_selectedTileIndices.length]);
    if (idx != null) {
      CardStore.recordResult(target, hint: true);
      _onLetterSelected(idx);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.colorF0Red) {
      _undoLastLetter();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;

    if (k == LogicalKeyboardKey.f1 || k == LogicalKeyboardKey.colorF2Yellow) {
      _triggerHint();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.mediaTrackNext || k == LogicalKeyboardKey.colorF1Green) {
      _nextWord();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.mediaTrackPrevious || k == LogicalKeyboardKey.colorF3Blue) {
      _previousWord();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    final ch = event.character;
    if (ch != null && ch.length == 1) {
      final index = _findTile(ch.toUpperCase());
      if (index != null) {
        _onLetterSelected(index);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildPhoto(WordCard card, double size, double s) {
    final path = card.imagePath;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22 * s),
        border: Border.all(color: Colors.white, width: 5 * s),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))],
        gradient: path == null
            ? const LinearGradient(
                colors: [Color(0xFFFFB74D), Color(0xFFFF4081)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17 * s),
        child: path != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      color: Colors.black45,
                      colorBlendMode: BlendMode.darken,
                      errorBuilder: (BuildContext c, Object e, StackTrace? st) => const SizedBox.shrink(),
                    ),
                  ),
                  Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (BuildContext c, Object e, StackTrace? st) =>
                        Center(child: Icon(Icons.broken_image_rounded, size: 80 * s, color: Colors.white70)),
                  ),
                ],
              )
            : Center(child: Text('⭐', style: TextStyle(fontSize: size * 0.4))),
      ),
    );
  }

  Widget _buildSlot(int i, double w, double h) {
    final filled = i < _selectedTileIndices.length;
    final letter = filled ? _shuffledLetters[_selectedTileIndices[i]] : ''; // empty = no watermark
    Color fill;
    Color border;
    if (!filled) {
      fill = Colors.white.withOpacity(0.22);
      border = Colors.white54;
    } else if (_solved) {
      fill = const Color(0xFF22C55E);
      border = Colors.white;
    } else if (_wrong) {
      fill = const Color(0xFFEF4444);
      border = Colors.white;
    } else {
      fill = _tileColors[_selectedTileIndices[i] % _tileColors.length];
      border = Colors.white;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(w * 0.2),
        border: Border.all(color: border, width: 3),
      ),
      child: Text(letter, style: kidText(w * 0.6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = uiScale(context);
    final card = widget.deck[_currentIndex];
    final target = card.word;
    final n = target.length;

    final poolGap = 12 * s;
    final tile = ((size.width - 64 * s - (n - 1) * poolGap) / n).clamp(40.0, 76 * s).toDouble();
    final message = _solved ? '🎉 Great job!' : (_wrong ? 'Oops! Try again 🙂' : '');

    final pool = <Widget>[];
    for (var index = 0; index < _shuffledLetters.length; index++) {
      pool.add(TVLetterTile(
        letter: _shuffledLetters[index],
        isUsed: _selectedTileIndices.contains(index),
        size: tile,
        color: _tileColors[index % _tileColors.length],
        autofocus: index == 0,
        onSelected: () => _onLetterSelected(index),
      ));
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
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
                      Expanded(
                        child: Text(
                          '${widget.title}  •  ${_currentIndex + 1} / ${widget.deck.length}',
                          style: kidText(26 * s),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ActionButton(
                        s: s,
                        icon: Icons.volume_up_rounded,
                        label: 'Say Word',
                        color: const Color(0xFF00ACC1),
                        onPressed: () => CardStore.speak(target),
                      ),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
                      final photo = math.min(box.maxHeight, size.width * 0.32);
                      final availW = box.maxWidth - photo - 40 * s;
                      final gap = 10 * s;
                      final slotW = ((availW - (n - 1) * gap) / n).clamp(30.0, 66 * s).toDouble();
                      final slotH = slotW * 1.15;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPhoto(card, photo, s),
                          SizedBox(width: 40 * s),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: List<Widget>.generate(n, (int i) => _buildSlot(i, slotW, slotH)),
                                ),
                                SizedBox(height: 14 * s),
                                SizedBox(height: 34 * s, child: Text(message, style: kidText(24 * s))),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  Wrap(alignment: WrapAlignment.center, spacing: poolGap, runSpacing: poolGap, children: pool),
                  SizedBox(height: 16 * s),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20 * s,
                    runSpacing: 10 * s,
                    children: [
                      ActionButton(
                        s: s,
                        icon: Icons.skip_previous_rounded,
                        label: 'Previous',
                        color: const Color(0xFF6366F1),
                        onPressed: _previousWord,
                      ),
                      ActionButton(
                        s: s,
                        icon: Icons.backspace_rounded,
                        label: 'Undo Letter',
                        color: const Color(0xFFEF4444),
                        onPressed: _undoLastLetter,
                      ),
                      ActionButton(
                        s: s,
                        icon: Icons.lightbulb_rounded,
                        label: 'Hint',
                        color: const Color(0xFFF59E0B),
                        onPressed: _triggerHint,
                      ),
                      ActionButton(
                        s: s,
                        icon: Icons.skip_next_rounded,
                        label: 'Next',
                        color: const Color(0xFF22C55E),
                        onPressed: _nextWord,
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.13),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ 3. LETTER TILE
class TVLetterTile extends StatelessWidget {
  final String letter;
  final bool isUsed;
  final VoidCallback onSelected;
  final double size;
  final Color color;
  final bool autofocus;

  const TVLetterTile({
    super.key,
    required this.letter,
    required this.isUsed,
    required this.onSelected,
    required this.size,
    required this.color,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      autofocus: autofocus,
      scale: 1.18,
      onPressed: isUsed ? null : onSelected,
      builder: (BuildContext context, bool focused) => AnimatedOpacity(
        opacity: isUsed ? 0.25 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: focused ? Colors.amberAccent : color,
            borderRadius: BorderRadius.circular(size * 0.22),
            border: Border.all(color: Colors.white, width: focused ? 4 : 2),
            boxShadow: [
              BoxShadow(
                color: focused ? Colors.amberAccent.withOpacity(0.8) : Colors.black26,
                blurRadius: focused ? 22 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(letter, style: kidText(size * 0.5, c: focused ? Colors.black87 : Colors.white)),
        ),
      ),
    );
  }
}
