import 'package:flutter/material.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'home_screen.dart';
import 'math_game.dart';
import 'players.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameAudioService.instance.init();
  await CardStore.init(); // also moves old SharedPreferences data into the Documents folder
  await PlayerStore.init(); // children, per-child settings and learning memory
  await MathStore.init();
  runApp(const KidsSuperApp());
}

class KidsSuperApp extends StatelessWidget {
  const KidsSuperApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Super Learning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const HomeScreen(),
    );
  }
}
