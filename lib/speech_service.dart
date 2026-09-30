import 'package:flutter_tts/flutter_tts.dart';
import 'app_store.dart';

/// English + Hindi text-to-speech used by the Maths and Quiz games.
/// (Spelling keeps using GameAudioService.) Respects the global "Text to speech" switch.
class Speaker {
  Speaker._();
  static final Speaker instance = Speaker._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String _lang = '';
  int _gen = 0;

  /// True when the text contains Devanagari (Hindi) letters.
  static bool isHindi(String text) {
    for (final r in text.runes) {
      if (r >= 0x0900 && r <= 0x097F) return true;
    }
    return false;
  }

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.05);
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> _setLang(String lang) async {
    final code = lang == 'hi' ? 'hi-IN' : 'en-IN';
    if (_lang == code) return;
    try {
      final r = await _tts.setLanguage(code);
      if (r != 1 && lang != 'hi') {
        await _tts.setLanguage('en-US');
      }
    } catch (_) {}
    _lang = code;
  }

  /// Is a voice for this language installed on the TV?  ('en' or 'hi')
  Future<bool> isAvailable(String lang) async {
    try {
      final r = await _tts.isLanguageAvailable(lang == 'hi' ? 'hi-IN' : 'en-IN');
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }

  Future<void> speak(String text, {String? lang}) async {
    if (!CardStore.ttsOn) return;
    final t = text.trim();
    if (t.isEmpty) return;
    final myGen = ++_gen;
    try {
      await _init();
      await _tts.stop();
      if (myGen != _gen) return;
      await _setLang(lang ?? (isHindi(t) ? 'hi' : 'en'));
      if (myGen != _gen) return;
      await _tts.speak(t);
    } catch (_) {}
  }

  /// Speaks several parts one after another (each part picks Hindi/English by itself).
  Future<void> speakAll(List<String> parts) async {
    if (!CardStore.ttsOn) return;
    final myGen = ++_gen;
    try {
      await _init();
      await _tts.stop();
      for (final part in parts) {
        if (myGen != _gen) return;
        final t = part.trim();
        if (t.isEmpty) continue;
        await _setLang(isHindi(t) ? 'hi' : 'en');
        if (myGen != _gen) return;
        await _tts.speak(t);
      }
    } catch (_) {}
  }

  void stop() {
    _gen++;
    try {
      _tts.stop();
    } catch (_) {}
  }
}
