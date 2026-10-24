import 'package:flutter/material.dart';
import 'kids_ui.dart';
import 'learn_model.dart';
import 'players.dart';
import 'speech_service.dart';

/// Flashcards: see the front, press OK to flip, then say "Got it" or "Practise again".
/// Cards marked "Practise again" come back at the end of the round.
class FlashcardsScreen extends StatefulWidget {
  final String title;
  final List<LearnCard> cards;
  const FlashcardsScreen({super.key, required this.title, required this.cards});

  /// Cards that make sense as flashcards: a front and an answer (tables are left out).
  static List<LearnCard> usable(List<LearnCard> all) =>
      all.where((LearnCard c) => !c.isTable && c.front.trim().isNotEmpty && c.back.trim().isNotEmpty).toList();

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late List<LearnCard> _queue;
  int _total = 0;
  int _known = 0;
  bool _flipped = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _queue = List<LearnCard>.of(widget.cards)..shuffle();
    _total = _queue.length;
    if (_queue.isEmpty) _done = true;
  }

  LearnCard get _card => _queue.first;

  void _flip() {
    setState(() => _flipped = true);
    final c = _card;
    if (PlayerStore.active.speak) Speaker.instance.speak('${c.front}. ${c.back}');
  }

  void _answer(bool gotIt) {
    final c = _card;
    if (c.key.isNotEmpty) Mastery.record(c.key, clean: gotIt);
    setState(() {
      _queue.removeAt(0);
      if (gotIt) {
        _known++;
      } else {
        _queue.add(c);
      }
      _flipped = false;
      if (_queue.isEmpty) _done = true;
    });
  }

  Widget _btn(double s, String label, IconData icon, Color color, VoidCallback onTap, {bool autofocus = false}) {
    return TVFocusable(
      autofocus: autofocus,
      onPressed: onTap,
      builder: (BuildContext context, bool focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 12 * s),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(40 * s),
          border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 4 * s),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.black87, size: 26 * s),
          SizedBox(width: 8 * s),
          Text(label, style: kidText(20 * s, c: Colors.black87)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    if (_done) {
      return ScreenFrame(
        title: '\u{1F0CF} ${widget.title}',
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_total == 0 ? 'No flashcards in this chapter yet.' : 'All $_total cards done! \u{1F389}', style: kidText(30 * s), textAlign: TextAlign.center),
            SizedBox(height: 16 * s),
            _btn(s, 'Back', Icons.arrow_back_rounded, const Color(0xFF35D0BA), () => Navigator.pop(context), autofocus: true),
          ]),
        ),
      );
    }
    final c = _card;
    return ScreenFrame(
      title: '\u{1F0CF} ${widget.title}',
      body: Column(children: [
        Text('${_known} of $_total known  •  ${_queue.length} left', style: kidText(15 * s, w: FontWeight.w600, c: const Color(0xFFA9ADDB))),
        SizedBox(height: 10 * s),
        Expanded(
          child: Center(
            child: Container(
              width: 560 * s,
              padding: EdgeInsets.all(24 * s),
              decoration: BoxDecoration(
                color: const Color(0xFF181B3A),
                borderRadius: BorderRadius.circular(30 * s),
                border: Border.all(color: _flipped ? const Color(0xFF35D0BA) : const Color(0xFF4C7BF0), width: 3),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 500 * s),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(c.front, textAlign: TextAlign.center, style: kidText(30 * s)),
                    if (_flipped) ...[
                      SizedBox(height: 14 * s),
                      Divider(color: Colors.white24, height: 1),
                      SizedBox(height: 14 * s),
                      Text(c.back, textAlign: TextAlign.center, style: kidText(28 * s, c: const Color(0xFF7DF0DC))),
                      if (c.note.isNotEmpty) ...[SizedBox(height: 8 * s), Text(c.note, textAlign: TextAlign.center, style: kidText(16 * s, w: FontWeight.w600))],
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12 * s),
        if (!_flipped)
          _btn(s, 'Show answer', Icons.flip_rounded, const Color(0xFF4C7BF0), _flip, autofocus: true)
        else
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _btn(s, 'Practise again', Icons.refresh_rounded, const Color(0xFFFFB84D), () => _answer(false)),
            SizedBox(width: 16 * s),
            _btn(s, 'Got it', Icons.check_rounded, const Color(0xFF35D0BA), () => _answer(true), autofocus: true),
          ]),
        SizedBox(height: 10 * s),
      ]),
    );
  }
}
