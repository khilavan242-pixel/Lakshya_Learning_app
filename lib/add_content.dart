import 'package:flutter/material.dart';
import 'kids_ui.dart';
import 'learn_model.dart';
import 'quiz_model.dart';

/// Phone-friendly "Add content": paste quiz questions or study notes and save them
/// straight into the app (no web page needed). On a TV the web page via QR still works.
class AddContentScreen extends StatefulWidget {
  const AddContentScreen({super.key});
  @override
  State<AddContentScreen> createState() => _AddContentScreenState();
}

class _AddContentScreenState extends State<AddContentScreen> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _title = TextEditingController();
  bool _quiz = true;
  bool _busy = false;
  String _msg = '';

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _msg = 'Paste some text first.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      if (_quiz) {
        final sets = await QuizStore.importText(t);
        final n = sets.fold<int>(0, (int a, QuizSet q) => a + q.questions.length);
        _msg = 'Saved ${sets.length} quiz with $n questions.';
      } else {
        final doc = await LearnStore.importText(t, title: _title.text.trim());
        _msg = 'Saved "${doc.title}" with ${doc.cards.length} cards.';
      }
      _text.clear();
    } on FormatException catch (e) {
      _msg = e.message;
    } catch (e) {
      _msg = 'Could not save: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    return ScreenFrame(
      title: 'Add content',
      body: ListView(
        padding: EdgeInsets.all(12 * s),
        children: [
          Wrap(spacing: 10 * s, children: [
            ChoiceChip(label: const Text('Quiz questions'), selected: _quiz, onSelected: (_) => setState(() => _quiz = true)),
            ChoiceChip(label: const Text('Study notes'), selected: !_quiz, onSelected: (_) => setState(() => _quiz = false)),
          ]),
          SizedBox(height: 10 * s),
          if (!_quiz)
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (optional)', border: OutlineInputBorder())),
          if (!_quiz) SizedBox(height: 10 * s),
          TextField(
            controller: _text,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _quiz ? 'Paste quiz JSON or text here' : 'One note per line, like:\nSun => A star\nMoon | Goes around Earth',
            ),
          ),
          SizedBox(height: 12 * s),
          FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.check_rounded), label: Text(_busy ? 'Saving...' : 'Save')),
          if (_msg.isNotEmpty) Padding(padding: EdgeInsets.only(top: 12 * s), child: Text(_msg, style: kidText(18 * s, w: FontWeight.w700))),
        ],
      ),
    );
  }
}
