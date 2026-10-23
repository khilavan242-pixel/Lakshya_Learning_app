import 'dart:convert';
import 'dart:io';
import 'doc_store.dart';
import 'core_audio_models.dart';

/// Single place that reads/writes everything the TV app saves.
/// Used by BOTH main.dart (the TV UI) and sync_server.dart (the phone menu),
/// so a change made on the phone shows up on the TV immediately.
class CardStore {
  CardStore._();

  static const _cardsKey = 'saved_custom_cards'; // same key as before -> old data keeps working
  static const _catsKey = 'custom_categories';
  static const _pronKey = 'pronunciations';
  static const _statsKey = 'word_stats';
  static const _soundKey = 'key_sound_on';
  static const _ttsKey = 'tts_on';

  // ---- in-memory copies (so the game can read them without await) ----
  static bool keySoundOn = true;
  static bool ttsOn = true;
  static Map<String, String> pronunciations = {};
  /// word -> {'c': correct, 'w': wrong, 'h': hints}
  static Map<String, Map<String, int>> stats = {};

  static Future<void> init() async {
    final p = await AppKV.open();
    keySoundOn = p.getBool(_soundKey) ?? true;
    ttsOn = p.getBool(_ttsKey) ?? true;

    final pr = p.getString(_pronKey);
    if (pr != null) {
      try {
        pronunciations = (json.decode(pr) as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (_) {}
    }
    final st = p.getString(_statsKey);
    if (st != null) {
      try {
        stats = (json.decode(st) as Map).map((k, v) => MapEntry(
            k.toString(),
            (v as Map).map((a, b) => MapEntry(a.toString(), (b as num).toInt()))));
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------- cards
  static Future<List<WordCard>> loadCards() async {
    final p = await AppKV.open();
    if (!p.containsKey(_cardsKey)) {
      // First run: seed the starter words so they can be managed from the phone too.
      final defaults = <WordCard>[
        WordCard(id: 'def_1', word: 'APPLE', topic: 'FRUITS'),
        WordCard(id: 'def_2', word: 'NOSE', topic: 'BODY PARTS'),
        WordCard(id: 'def_3', word: 'TIGER', topic: 'ANIMALS'),
      ];
      await saveCards(defaults);
      return defaults;
    }
    final list = p.getStringList(_cardsKey) ?? [];
    final out = <WordCard>[];
    for (final s in list) {
      try {
        out.add(WordCard.fromJson(s));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> saveCards(List<WordCard> cards) async {
    final p = await AppKV.open();
    await p.setStringList(_cardsKey, cards.map((c) => c.toJson()).toList());
  }

  static Future<void> addCards(List<WordCard> newCards) async {
    final cards = await loadCards();
    cards.addAll(newCards);
    await saveCards(cards);
  }

  static Future<void> updateCard(String id,
      {String? word, String? topic, String? imagePath}) async {
    final cards = await loadCards();
    final i = cards.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final old = cards[i];
    if (imagePath != null && old.imagePath != null && old.imagePath != imagePath) {
      _deleteFile(old.imagePath!);
    }
    cards[i] = WordCard(
      id: old.id,
      word: (word != null && word.isNotEmpty) ? word : old.word,
      topic: (topic != null && topic.isNotEmpty) ? topic : old.topic,
      imagePath: imagePath ?? old.imagePath,
      isCustom: old.isCustom,
    );
    await saveCards(cards);
  }

  static Future<void> deleteCard(String id, {bool keepImage = false}) async {
    final cards = await loadCards();
    for (final c in cards.where((c) => c.id == id)) {
      if (c.imagePath != null && !keepImage) _deleteFile(c.imagePath!);
    }
    cards.removeWhere((c) => c.id == id);
    await saveCards(cards);
  }

  static void _deleteFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  // ----------------------------------------------------------- categories
  static Future<List<String>> _customCategories() async {
    final p = await AppKV.open();
    return p.getStringList(_catsKey) ?? [];
  }

  /// MIXED first, then everything else A-Z (custom empty categories included).
  static Future<List<String>> allCategories([List<WordCard>? cards]) async {
    final list = cards ?? await loadCards();
    final set = <String>{...await _customCategories(), ...list.map((c) => c.topic)};
    set.remove('MIXED');
    final sorted = set.toList()..sort();
    return ['MIXED', ...sorted];
  }

  static Future<void> addCategory(String name) async {
    final p = await AppKV.open();
    final cats = await _customCategories();
    if (!cats.contains(name)) cats.add(name);
    await p.setStringList(_catsKey, cats);
  }

  static Future<void> renameCategory(String from, String to) async {
    final p = await AppKV.open();
    final cards = await loadCards();
    final renamed = cards
        .map((c) => c.topic == from
            ? WordCard(
                id: c.id, word: c.word, topic: to, imagePath: c.imagePath, isCustom: c.isCustom)
            : c)
        .toList();
    await saveCards(renamed);
    final cats = await _customCategories();
    cats.remove(from);
    if (!cats.contains(to)) cats.add(to);
    await p.setStringList(_catsKey, cats);
  }

  /// Words of a deleted category are moved to MIXED (nothing is lost).
  static Future<void> deleteCategory(String name) async {
    await renameCategory(name, 'MIXED');
    final p = await AppKV.open();
    final cats = await _customCategories();
    cats.remove(name);
    await p.setStringList(_catsKey, cats);
  }

  // -------------------------------------------------------- pronunciation
  static Future<void> setPronunciation(String word, String text) async {
    final t = text.trim();
    if (t.isEmpty) {
      pronunciations.remove(word);
    } else {
      pronunciations[word] = t;
    }
    final p = await AppKV.open();
    await p.setString(_pronKey, json.encode(pronunciations));
  }

  // -------------------------------------------------------- report card
  static Future<void> recordResult(String word,
      {bool correct = false, bool wrong = false, bool hint = false}) async {
    final s = stats.putIfAbsent(word, () => {'c': 0, 'w': 0, 'h': 0});
    if (correct) s['c'] = (s['c'] ?? 0) + 1;
    if (wrong) s['w'] = (s['w'] ?? 0) + 1;
    if (hint) s['h'] = (s['h'] ?? 0) + 1;
    final p = await AppKV.open();
    await p.setString(_statsKey, json.encode(stats));
  }

  static Future<void> resetStats() async {
    stats = {};
    final p = await AppKV.open();
    await p.remove(_statsKey);
  }

  // ------------------------------------------------------------ settings
  static Future<void> setKeySound(bool v) async {
    keySoundOn = v;
    final p = await AppKV.open();
    await p.setBool(_soundKey, v);
  }

  static Future<void> setTts(bool v) async {
    ttsOn = v;
    final p = await AppKV.open();
    await p.setBool(_ttsKey, v);
  }

  // --------------------------------- audio helpers that respect settings
  static void speak(String word) {
    if (!ttsOn) return;
    GameAudioService.instance.speakWord(pronunciations[word] ?? word);
  }

  static void keyClick() {
    if (keySoundOn) GameAudioService.instance.playLetterClick();
  }

  static void focusMove() {
    if (keySoundOn) GameAudioService.instance.playFocusMove();
  }
}
