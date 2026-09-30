import 'package:flutter/material.dart';
import 'doc_store.dart';
import 'home_screen.dart';
import 'speech_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DocStore.root();
  await AppKV.open();
  // Initialize your new speech service if it requires an init call
  // await Speaker.instance.init(); 
  runApp(const KidsLearningTVApp());
}

class KidsLearningTVApp extends StatelessWidget {
  const KidsLearningTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Learning TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1322),
      ),
      home: const HomeScreen(),
    );
  }
}
