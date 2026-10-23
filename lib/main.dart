import 'package:flutter/material.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'home_screen.dart';
import 'kids_ui.dart';
import 'math_game.dart';
import 'players.dart';
import 'parent_zone.dart';
import 'storage_location.dart';
import 'who_screen.dart';

/// The first picture appears at once; the slow work (storage, sounds, saved data)
/// happens behind the splash screen instead of a black screen.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KidsSuperApp());
}

class KidsSuperApp extends StatelessWidget {
  const KidsSuperApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (BuildContext context, Widget? child) => Stack(children: [
        child ?? const SizedBox.shrink(),
        ValueListenableBuilder<bool>(valueListenable: UsageGuard.locked, builder: (BuildContext c, bool on, Widget? _) => on ? const Positioned.fill(child: TimeUpOverlay()) : const SizedBox.shrink()),
      ]),
      home: const BootGate(),
    );
  }
}

class BootGate extends StatefulWidget {
  const BootGate({super.key});
  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  bool _ready = false;
  bool _chosen = false;
  String _msg = 'Starting...';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _say(String m) {
    if (mounted) setState(() => _msg = m);
  }

  Future<void> _boot() async {
    try {
      _say('Opening your saved data...');
      await StorageLocation.init(); // decides where all data is saved (Documents by default)
      _say('Loading players and settings...');
      await Future.wait(<Future<void>>[CardStore.init(), PlayerStore.init(), MathStore.init()]);
      _say('Getting the sounds ready...');
      // Sound start-up can be slow on a TV: wait at most 3 seconds, it keeps loading in the background.
      await Future.any<void>(<Future<void>>[
        () async {
          await GameAudioService.instance.init();
        }(),
        Future<void>.delayed(const Duration(seconds: 3)),
      ]);
    } catch (e) {
      _say('Almost ready...');
    }
    UsageGuard.start();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && PlayerStore.players.length > 1 && !_chosen) {
      return WhoScreen(onDone: () => setState(() => _chosen = true));
    }
    if (_ready) return const HomeScreen();
    final s = uiScale(context);
    return Scaffold(
      body: KidsBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(28 * s), child: Image.asset('assets/logo.png', width: 120 * s, height: 120 * s)),
              SizedBox(height: 10 * s),
              Text(kAppName, style: kidText(46 * s)),
              Text(kAppTagline, style: kidText(18 * s, w: FontWeight.w600)),
              SizedBox(height: 18 * s),
              SizedBox(width: 44 * s, height: 44 * s, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 5)),
              SizedBox(height: 14 * s),
              Text(_msg, style: kidText(20 * s, w: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
