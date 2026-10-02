import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'kids_ui.dart';
import 'players.dart';
import 'sync_server.dart';

// --------------------------------------------------------- 1. LOBBY
String _spellKey(WordCard c) => 'spell:${c.word}';

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

  List<WordCard> _allWords = <WordCard>[];

  Future<void> _loadCards() async {
    final all = await CardStore.loadCards();
    // each player only sees the topics selected for him/her in Settings
    final allowed = PlayerStore.active.spellingTopics;
    var cards = allowed == null ? all : all.where((WordCard c) => allowed.contains(c.topic)).toList();
    if (cards.isEmpty) cards = all;
    final topics = <String, List<WordCard>>{};
    if (cards.isNotEmpty) topics['ALL WORDS'] = List<WordCard>.of(cards);
    for (final card in cards) {
      if (card.topic == 'ALL WORDS') continue;
      topics.putIfAbsent(card.topic, () => <WordCard>[]).add(card);
    }
    if (!mounted) return;
    final added = _lastCount >= 0 && all.length > _lastCount;
    _lastCount = all.length;
    if (added) GameAudioService.instance.playSuccessFanfare();
    setState(() {
      _allWords = cards;
      _topics = topics;
      _loaded = true;
    });
  }

  List<WordCard> _masterRound() {
    final pool = Mastery.notMastered<WordCard>(_allWords, _spellKey);
    return Mastery.smartPick<WordCard>(pool, _spellKey, PlayerStore.active.rounds);
  }

  /// Master Play: rounds of the words the child has not mastered yet, hardest first,
  /// until every word has been spelled correctly 3 times in a row.
  Future<void> _masterPlay() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TVGameScreen(deck: <WordCard>[], title: 'Master Play', session: true, master: true, builder: _masterRound),
      ),
    );
    if (mounted) _loadCards();
  }

  Future<void> _playTopic(String topic) async {
    final cards = _topics[topic] ?? <WordCard>[];
    final smart = PlayerStore.active.smart;
    var deck = List<WordCard>.of(cards);
    if (smart) {
      final left = Mastery.notMastered<WordCard>(cards, _spellKey);
      if (left.isEmpty) {
        showKidsSnack(context, '🏆 All words in $topic are mastered - revision round!');
      } else {
        deck = List<WordCard>.of(left);
      }
      deck.shuffle();
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => TVGameScreen(deck: deck, title: topic, session: smart)),
    );
    if (mounted) _loadCards();
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
      final pending = Mastery.notMastered<WordCard>(_allWords, _spellKey).length;
      cards.add(BigTile(
        emoji: '🏆',
        title: 'Master Play',
        subtitle: pending == 0 ? 'All mastered 🎉' : '$pending to master',
        colors: const <Color>[Color(0xFF00897B), Color(0xFF26C6DA)],
        s: s,
        width: 210,
        height: 190,
        autofocus: true,
        onPressed: _masterPlay,
      ));
      for (var i = 0; i < keys.length; i++) {
        final topic = keys[i];
        final list = _topics[topic]!;
        final smart = PlayerStore.active.smart;
        final left = Mastery.notMastered<WordCard>(list, _spellKey).length;
        final done = list.length - left;
        String? sub;
        if (smart) {
          sub = left == 0 ? '✅ all mastered' : '$left to learn${done > 0 ? '  •  ✅$done' : ''}';
        }
        cards.add(TopicCard(
          topic: topic,
          count: list.length,
          subtitle: sub,
          colorIndex: i,
          s: s,
          autofocus: false,
          onPressed: () => _playTopic(topic),
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
  final String? subtitle;
  final int colorIndex;
  final double s;
  final bool autofocus;
  final VoidCallback onPressed;

  const TopicCard({
    super.key,
    required this.topic,
    required this.count,
    this.subtitle,
    required this.colorIndex,
    required this.s,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = kTopicGradients[colorIndex % kTopicGradients.length];
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
            Text(emojiForTopic(topic), style: TextStyle(fontSize: 54 * s)),
            SizedBox(height: 6 * s),
            Text(topic, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: kidText(26 * s)),
            SizedBox(height: 4 * s),
            Text(subtitle ?? (count == 1 ? '1 word' : '$count words'), textAlign: TextAlign.center, style: kidText(16 * s, w: FontWeight.w600)),
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
  final bool session; // finite round with a summary (smart practice)
  final bool master; // master play: continue until every word is mastered
  final List<WordCard> Function()? builder; // makes a new round (master play)
  const TVGameScreen({
    super.key,
    required this.deck,
    this.title = 'Spelling',
    this.session = false,
    this.master = false,
    this.builder,
  });
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

  List<WordCard> _deck = <WordCard>[];
  List<bool> _isRepeat = <bool>[];
  final Map<String, int> _repeatCount = <String, int>{};
  int _baseCount = 0;
  int _correctFirst = 0;
  int _needPractice = 0;
  bool _finished = false;
  bool _moreLeft = false;
  bool _mistake = false;
  bool _hintUsed = false;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _loadDeck();
    _prepareWord();
  }

  void _loadDeck() {
    final make = widget.builder;
    _deck = make != null ? make() : List<WordCard>.of(widget.deck);
    _isRepeat = List<bool>.filled(_deck.length, false);
    _repeatCount.clear();
    _baseCount = _deck.length;
    _currentIndex = 0;
    _correctFirst = 0;
    _needPractice = 0;
    _finished = false;
  }

  void _prepareWord() {
    if (_deck.isEmpty) return;
    final word = _deck[_currentIndex].word;
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
    _mistake = false;
    _hintUsed = false;
    _registered = false;
    _token++;
    if (PlayerStore.active.speak) CardStore.speak(word);
  }

  /// Remember how the child did. clean = spelled right with no mistake and no hint.
  void _registerResult(bool clean) {
    final card = _deck[_currentIndex];
    final key = _spellKey(card);
    Mastery.record(key, clean: clean);
    if (!widget.session) return;
    if (clean) {
      if (!_isRepeat[_currentIndex]) _correctFirst++;
      if (widget.master && !Mastery.isMastered(key)) _requeue(card, 6);
    } else {
      _needPractice++;
      _requeue(card, 4);
    }
  }

  void _requeue(WordCard card, int gap) {
    final key = _spellKey(card);
    final used = _repeatCount[key] ?? 0;
    final cap = widget.master ? 5 : 2;
    if (used >= cap) return;
    _repeatCount[key] = used + 1;
    final at = math.min(_deck.length, _currentIndex + gap);
    _deck.insert(at, card);
    _isRepeat.insert(at, true);
  }

  void _finishSession() {
    final make = widget.builder;
    final more = widget.master && make != null && make().isNotEmpty;
    final sfx = _baseCount > 0 && _correctFirst * 2 >= _baseCount;
    setState(() {
      _moreLeft = more;
      _finished = true;
      _token++;
    });
    if (sfx && PlayerStore.active.sound) GameAudioService.instance.playSuccessFanfare();
  }

  void _restart() {
    setState(() {
      _loadDeck();
      _prepareWord();
    });
  }

  void _goTo(int delta) {
    if (_deck.isEmpty) return;
    final n = _deck.length;
    if (widget.session) {
      final next = _currentIndex + delta;
      if (next < 0) return;
      if (delta > 0 && !_solved && !_registered) {
        _registered = true; // skipped = needs more practice
        _registerResult(false);
      }
      if (next >= _deck.length) {
        _finishSession();
        return;
      }
      setState(() {
        _currentIndex = next;
        _prepareWord();
      });
      return;
    }
    setState(() {
      _currentIndex = (_currentIndex + delta + n) % n;
      _prepareWord();
    });
  }

  Widget _doneScreen({required bool empty}) {
    final s = uiScale(context);
    if (empty) {
      return ScreenFrame(
        title: '🏆 ${widget.title}',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏆', style: TextStyle(fontSize: 80 * s)),
              Text('Everything is mastered!', style: kidText(40 * s)),
              SizedBox(height: 6 * s),
              Text('Amazing work, ${PlayerStore.active.name}!', style: kidText(24 * s)),
              SizedBox(height: 22 * s),
              ActionButton(s: s, icon: Icons.home_rounded, label: 'Back', color: const Color(0xFF5C6BC0), autofocus: true, onPressed: () => Navigator.maybePop(context)),
            ],
          ),
        ),
      );
    }
    final ratio = _baseCount == 0 ? 0.0 : _correctFirst / _baseCount;
    final stars = ratio >= 0.9 ? 3 : (ratio >= 0.6 ? 2 : (ratio >= 0.3 ? 1 : 0));
    final canContinue = widget.master ? _moreLeft : true;
    return ScreenFrame(
      title: '🏆 ${widget.title}',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stars == 0 ? '💪' : ('⭐' * stars), style: TextStyle(fontSize: 70 * s)),
            SizedBox(height: 8 * s),
            Text('$_correctFirst / $_baseCount first-time correct', style: kidText(38 * s)),
            if (_needPractice > 0)
              Padding(
                padding: EdgeInsets.only(top: 8 * s),
                child: Text('🔁 $_needPractice word(s) will come back until you know them', style: kidText(20 * s, w: FontWeight.w600)),
              ),
            if (widget.master)
              Padding(
                padding: EdgeInsets.only(top: 8 * s),
                child: Text(_moreLeft ? 'Keep going - master every word! 💪' : '🏆 Every word is mastered!', style: kidText(22 * s)),
              ),
            SizedBox(height: 22 * s),
            Wrap(
              spacing: 16 * s,
              runSpacing: 10 * s,
              alignment: WrapAlignment.center,
              children: [
                if (canContinue)
                  ActionButton(
                    s: s,
                    icon: widget.master ? Icons.arrow_forward_rounded : Icons.replay_rounded,
                    label: widget.master ? 'Next Round' : 'Play Again',
                    color: const Color(0xFF22C55E),
                    autofocus: true,
                    onPressed: _restart,
                  ),
                ActionButton(s: s, icon: Icons.home_rounded, label: 'Back', color: const Color(0xFF5C6BC0), autofocus: !canContinue, onPressed: () => Navigator.maybePop(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _nextWord() => _goTo(1);
  void _previousWord() => _goTo(-1);

  void _onLetterSelected(int index) {
    if (_locked || _selectedTileIndices.contains(index)) return;
    CardStore.keyClick();
    setState(() => _selectedTileIndices.add(index));

    final target = _deck[_currentIndex].word;
    if (_selectedTileIndices.length != target.length) return;

    final spelled = _selectedTileIndices.map((i) => _shuffledLetters[i]).join();
    final token = _token;
    if (spelled == target) {
      setState(() {
        _locked = true;
        _solved = true;
      });
      final clean = !_mistake && !_hintUsed;
      CardStore.recordResult(target, correct: true);
      if (PlayerStore.active.sound) GameAudioService.instance.playSuccessFanfare();
      CardStore.speak(target);
      _registered = true;
      _registerResult(clean);
      Future<void>.delayed(Duration(milliseconds: clean ? 1600 : 2800), () {
        if (mounted && token == _token) _nextWord();
      });
    } else {
      setState(() {
        _locked = true;
        _wrong = true;
      });
      _mistake = true;
      CardStore.recordResult(target, wrong: true);
      if (PlayerStore.active.sound) GameAudioService.instance.playErrorFeedback();
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
    if (_locked || _deck.isEmpty || !PlayerStore.active.hints) return;
    final target = _deck[_currentIndex].word;

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
      _hintUsed = true;
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
      fill = kTileColors[_selectedTileIndices[i] % kTileColors.length];
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
    if (_deck.isEmpty) return _doneScreen(empty: true);
    if (_finished) return _doneScreen(empty: false);
    final card = _deck[_currentIndex];
    final target = card.word;
    final n = target.length;

    final poolGap = 12 * s;
    final tile = ((size.width - 64 * s - (n - 1) * poolGap) / n).clamp(40.0, 76 * s).toDouble();
    final repeatMsg = (_currentIndex < _isRepeat.length && _isRepeat[_currentIndex]) ? '🔁 Let\'s try this word again!' : '';
    final message = _solved ? ((_mistake || _hintUsed) ? '🌟 Remember: $target' : '🎉 Great job!') : (_wrong ? 'Oops! Try again 🙂' : repeatMsg);

    final pool = <Widget>[];
    for (var index = 0; index < _shuffledLetters.length; index++) {
      pool.add(TVLetterTile(
        letter: _shuffledLetters[index],
        isUsed: _selectedTileIndices.contains(index),
        size: tile,
        color: kTileColors[index % kTileColors.length],
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
                          '${widget.title}  •  ${_currentIndex + 1} / ${_deck.length}',
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
                      if (PlayerStore.active.hints)
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
