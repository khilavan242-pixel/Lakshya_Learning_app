import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'quiz_model.dart';

class _Pic {
  final String path;
  final TextEditingController answer = TextEditingController();
  _Pic(this.path);
}

/// Make your own picture quiz: pick photos from the phone, type what each one is, save.
/// Saving again with the same quiz name adds the new pictures to that quiz.
class PictureMakerScreen extends StatefulWidget {
  const PictureMakerScreen({super.key});
  @override
  State<PictureMakerScreen> createState() => _PictureMakerScreenState();
}

class _PictureMakerScreenState extends State<PictureMakerScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _ask = TextEditingController(text: 'What is this?');
  final List<_Pic> _pics = <_Pic>[];
  String _msg = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _ask.dispose();
    for (final p in _pics) {
      p.answer.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final picker = ImagePicker();
      if (src == ImageSource.gallery) {
        final files = await picker.pickMultiImage(imageQuality: 90, maxWidth: 1000);
        for (final f in files) {
          _pics.add(_Pic(f.path));
        }
      } else {
        final f = await picker.pickImage(source: src, imageQuality: 90, maxWidth: 1000);
        if (f != null) _pics.add(_Pic(f.path));
      }
      if (mounted) setState(() => _msg = '');
    } catch (e) {
      if (mounted) setState(() => _msg = 'Could not open the pictures: $e');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final ready = _pics.where((p) => p.answer.text.trim().isNotEmpty).toList();
    if (name.isEmpty) {
      setState(() => _msg = 'Type a quiz name first.');
      return;
    }
    if (ready.isEmpty) {
      setState(() => _msg = 'Add at least one picture and type what it is.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/quiz_pics');
      if (!await dir.exists()) await dir.create(recursive: true);
      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final id = 'mypic_$slug';
      final all = await QuizStore.loadAll();
      QuizSet? old;
      for (final q in all) {
        if (q.id == id) old = q;
      }
      final entries = <(String, String)>[]; // (image path, answer)
      for (final q in old?.questions ?? <QuizQuestion>[]) {
        final a = q.type == 'mcq' ? q.options[q.correctIndex] : (q.answers.isEmpty ? '' : q.answers.first);
        if (a.isNotEmpty) entries.add((q.image, a));
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      var n = 0;
      for (final p in ready) {
        final dest = '${dir.path}/${slug}_${stamp}_${n++}.jpg';
        await File(p.path).copy(dest);
        entries.add((dest, p.answer.text.trim()));
      }
      final answers = entries.map(((String, String) e) => e.$2).toSet().toList();
      final ask = _ask.text.trim().isEmpty ? 'What is this?' : _ask.text.trim();
      final qs = <QuizQuestion>[];
      for (var i = 0; i < entries.length; i++) {
        final right = entries[i].$2;
        final others = answers.where((String a) => a != right).toList();
        if (others.length >= 3) {
          final pickOthers = <String>[];
          for (var k = 0; pickOthers.length < 3; k++) {
            final c = others[(i + k * 2) % others.length];
            if (!pickOthers.contains(c)) pickOthers.add(c);
            if (k > others.length * 2) break;
          }
          final pos = i % 4;
          final opts = List<String>.from(pickOthers)..insert(pos, right);
          qs.add(QuizQuestion(type: 'mcq', question: ask, options: opts, correctIndex: pos, explanation: 'This is $right.', image: entries[i].$1));
        } else {
          qs.add(QuizQuestion(type: 'short', question: ask, answers: <String>[right], explanation: 'This is $right.', image: entries[i].$1));
        }
      }
      await QuizStore.save(QuizSet(
        id: id,
        title: name,
        emoji: '🖼️',
        lang: 'en',
        questions: qs,
        cls: 'Picture Quizzes',
        subject: 'My Pictures',
      ));
      await Library.load();
      await Library.save();
      if (!mounted) return;
      for (final p in _pics) {
        p.answer.dispose();
      }
      setState(() {
        _pics.clear();
        _busy = false;
        _msg = 'Saved "$name" with ${qs.length} pictures. Open Quiz Time > Picture Quizzes > My Pictures.${answers.length < 4 ? ' (With fewer than 4 different answers the child types the answer.)' : ''}';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = 'Could not save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    return ScreenFrame(
      title: '🖼️ My Picture Quiz',
      body: ListView(
        padding: EdgeInsets.all(12 * s),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Quiz name (use the same name to add more pictures)')),
          SizedBox(height: 10 * s),
          TextField(controller: _ask, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Question shown with each picture')),
          SizedBox(height: 10 * s),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _busy ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: const Text('Choose pictures')),
            FilledButton.tonalIcon(onPressed: _busy ? null : () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Take a photo')),
          ]),
          SizedBox(height: 10 * s),
          for (var i = 0; i < _pics.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_pics[i].path), width: 90, height: 90, fit: BoxFit.cover)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _pics[i].answer, decoration: const InputDecoration(labelText: 'What is it? (the answer)'))),
                  IconButton(
                    onPressed: () => setState(() {
                      _pics[i].answer.dispose();
                      _pics.removeAt(i);
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
            ),
          if (_msg.isNotEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 8 * s), child: Text(_msg, style: kidText(16 * s))),
          SizedBox(height: 8 * s),
          FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(_busy ? 'Saving...' : 'Save quiz')),
        ],
      ),
    );
  }
}
