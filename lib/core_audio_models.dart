import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class WordCard {
  final String id;
  final String word;
  final String topic;
  final String? imagePath;
  final bool isCustom;

  WordCard({
    required this.id,
    required this.word,
    required this.topic,
    this.imagePath,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'word': word.toUpperCase().trim(),
        'topic': topic.toUpperCase().trim(),
        'imagePath': imagePath,
        'isCustom': isCustom,
      };

  factory WordCard.fromMap(Map<String, dynamic> map) => WordCard(
        id: map['id'] as String,
        word: (map['word'] as String).toUpperCase().trim(),
        topic: (map['topic'] as String?)?.toUpperCase().trim() ?? 'MIXED',
        imagePath: map['imagePath'] as String?,
        isCustom: map['isCustom'] as bool? ?? false,
      );

  String toJson() => json.encode(toMap());
  factory WordCard.fromJson(String source) =>
      WordCard.fromMap(json.decode(source) as Map<String, dynamic>);
}

class GameAudioService {
  static final GameAudioService instance = GameAudioService._internal();
  GameAudioService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  Future<void> init() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.1);
      _ttsInitialized = true;
    } catch (_) {}
  }

  void playFocusMove() => SystemSound.play(SystemSoundType.click);
  void playLetterClick() => SystemSound.play(SystemSoundType.click);
  void playSuccessFanfare() => SystemSound.play(SystemSoundType.alert);
  void playErrorFeedback() => HapticFeedback.vibrate();

  Future<void> speakWord(String word) async {
    if (!_ttsInitialized) await init();
    try {
      await _tts.stop();
      await _tts.speak(word.toLowerCase());
    } catch (_) {}
  }
}
