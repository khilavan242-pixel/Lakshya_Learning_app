import 'dart:convert';
import 'package:flutter/material.dart';
import 'add_content.dart';
import 'app_store.dart';
import 'bin.dart';
import 'cbse_class1.dart';
import 'core_audio_models.dart';
import 'kids_ui.dart';
import 'library.dart';
import 'quiz_model.dart';
import 'tv_link.dart';

/// Phone "Content" tab: everything the parent has added, in one place.
/// Search, filter by type, send an item to the TV, and jump to Add, Organize and Recently deleted.
class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});
  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  List<LibItem> _items = <LibItem>[];
  bool _loading = true;
  String _filter = 'all'; // all | quiz | spell | learn
  String _query = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await Library.allItems();
    if (!mounted) return;
    setState(() {
      _items = all;
      _loading = false;
    });
  }

  String _where(LibItem it) {
    final parts = <String>[
      Library.classById(it.classId)?.name ?? '',
      Library.subjectById(it.subjectId)?.name ?? '',
      it.chapter,
    ].where((String p) => p.isNotEmpty).toList();
    return parts.isEmpty ? 'Not sorted' : parts.join(' › ');
  }

  String _kindLabel(String k) => k == 'quiz' ? 'Quiz' : (k == 'spell' ? 'Words' : 'Notes');

  /// The quiz as JSON text the TV can import (same shape the importer reads).
  String _quizJson(QuizSet set) {
    final qs = <Map<String, dynamic>>[];
    for (final q in set.questions) {
      final m = <String, dynamic>{'type': q.type, 'question': q.question};
      if (q.explanation.isNotEmpty) m['explanation'] = q.explanation;
      if (q.hint.isNotEmpty) m['hint'] = q.hint;
      if (q.passage.isNotEmpty) m['passage'] = q.passage;
      if (q.type == 'match') {
        m['pairs'] = q.pairs;
      } else if (q.type == 'tf') {
        m['answer'] = q.correctIndex == 0;
      } else if (q.options.length >= 2) {
        m['options'] = q.options;
        m['answer_index'] = q.correctIndex;
      } else {
        m['answer'] = q.answers;
      }
      qs.add(m);
    }
    return json.encode(<String, dynamic>{'title': set.title, 'emoji': set.emoji, 'questions': qs});
  }

  Future<String?> _askCode(bool err) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('TV code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${err ? 'That code was not accepted. ' : ''}Type the 4 digit code shown on the TV: Parent (lock button) > TV code.'),
          const SizedBox(height: 10),
          TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _sendToTv(LibItem it) async {
    if (it.kind == 'learn') {
      setState(() => _status = 'Notes cannot be sent from here yet. Use Add content to send notes.');
      return;
    }
    setState(() => _status = 'Looking for your TV on this Wi-Fi...');
    final ip = await TvLink.find();
    if (ip == null) {
      if (mounted) setState(() => _status = 'No TV found. Open GyanTara on the TV home screen and use the same Wi-Fi.');
      return;
    }
    final cls = Library.classById(it.classId)?.name ?? '';
    final sub = Library.subjectById(it.subjectId)?.name ?? '';
    Object body;
    String path;
    if (it.kind == 'quiz') {
      final sets = (await QuizStore.loadAll()).where((QuizSet q) => q.id == it.id).toList();
      if (sets.isEmpty) {
        if (mounted) setState(() => _status = 'That quiz could not be found.');
        return;
      }
      path = '/api/quiz/import';
      body = <String, dynamic>{'text': _quizJson(sets.first), 'class': cls, 'subject': sub};
    } else {
      final words = (await CardStore.loadCards()).where((WordCard c) => c.topic == it.id).map((WordCard c) => c.word).toList();
      path = '/api/upload-batch';
      body = <Map<String, dynamic>>[for (final w in words) <String, dynamic>{'word': w, 'topic': it.id}];
    }
    var code = await TvLink.savedCode();
    var err = await TvLink.post(ip, path, body, code: code);
    if (err == 'code') {
      final entered = await _askCode(code.isNotEmpty);
      if (entered == null) {
        if (mounted) setState(() => _status = '');
        return;
      }
      code = entered;
      err = await TvLink.post(ip, path, body, code: code);
      if (err == null) await TvLink.saveCode(code);
    }
    if (!mounted) return;
    setState(() => _status = err == null ? 'Sent "${it.title}" to the TV.' : (err == 'code' ? 'Wrong TV code. See Parent on the TV.' : err!));
  }

  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => w));
    if (mounted) _load();
  }

  Widget _action(double s, IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16 * s),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10 * s),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16 * s)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 22 * s),
            SizedBox(height: 2 * s),
            Text(label, style: kidText(12 * s)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final q = _query.trim().toLowerCase();
    final shown = _items.where((LibItem i) => (_filter == 'all' || i.kind == _filter) && (q.isEmpty || i.title.toLowerCase().contains(q) || _where(i).toLowerCase().contains(q))).toList();
    return ScreenFrame(
      title: '\u{1F4DA} Content',
      body: Column(children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12 * s),
          child: Row(children: [
            _action(s, Icons.add_circle_rounded, 'Add', const Color(0xFFF59E0B), () => _open(const AddContentScreen())),
            SizedBox(width: 8 * s),
            _action(s, Icons.folder_open_rounded, 'Organize', const Color(0xFF8E24AA), () => _open(const LibraryManagerScreen())),
            SizedBox(width: 8 * s),
            _action(s, Icons.menu_book_rounded, 'Class 1', const Color(0xFF00897B), () => _open(const CbseSyllabusScreen())),
            SizedBox(width: 8 * s),
            _action(s, Icons.restore_from_trash_rounded, 'Deleted', const Color(0xFF607D8B), () => _open(const BinScreen())),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 4 * s),
          child: TextField(
            onChanged: (String v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search content',
              filled: true,
              fillColor: const Color(0xFF181B3A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20 * s), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12 * s),
          child: Wrap(spacing: 8 * s, children: [
            for (final f in const <List<String>>[
              <String>['all', 'All'],
              <String>['quiz', 'Quiz'],
              <String>['spell', 'Words'],
              <String>['learn', 'Notes'],
            ])
              ChoiceChip(label: Text(f[1]), selected: _filter == f[0], onSelected: (_) => setState(() => _filter = f[0])),
          ]),
        ),
        if (_status.isNotEmpty)
          Padding(padding: EdgeInsets.fromLTRB(12 * s, 6 * s, 12 * s, 0), child: Text(_status, style: kidText(14 * s, c: const Color(0xFF7DF0DC), w: FontWeight.w700))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : shown.isEmpty
                  ? Center(child: Text(_items.isEmpty ? 'Nothing here yet.\nTap Add to scan or paste your first page.' : 'No match.', textAlign: TextAlign.center, style: kidText(18 * s, w: FontWeight.w600)))
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 24 * s),
                      itemCount: shown.length,
                      itemBuilder: (BuildContext context, int i) {
                        final it = shown[i];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8 * s),
                          decoration: BoxDecoration(color: const Color(0xFF181B3A), borderRadius: BorderRadius.circular(18 * s)),
                          child: ListTile(
                            leading: Text(it.emoji, style: TextStyle(fontSize: 28 * s)),
                            title: Text(it.title, style: kidText(16 * s), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${_kindLabel(it.kind)}  •  ${it.subtitle}\n${_where(it)}', style: kidText(12 * s, w: FontWeight.w600, c: const Color(0xFFA9ADDB))),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Send to TV',
                              icon: const Icon(Icons.cast_rounded, color: Color(0xFF7DF0DC)),
                              onPressed: () => _sendToTv(it),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
