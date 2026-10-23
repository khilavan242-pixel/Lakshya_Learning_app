import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'learn_model.dart';
import 'library.dart';
import 'quiz_model.dart';

/// Recently deleted items wait here for [days] days, so nothing is lost by accident.
class Bin {
  Bin._();

  static const int days = 30;
  static const String _folder = 'bin';

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Saves a copy of an item before it is deleted. kind: quiz | learn | spell.
  static Future<void> put(String kind, String id, String title, Map<String, dynamic> data) async {
    final at = DateTime.now().millisecondsSinceEpoch;
    final meta = Library.meta['$kind:$id'] ?? <String, String>{};
    await DocStore.writeJson(_folder, '${at}_${kind}_${_safe(id)}.json', <String, dynamic>{
      'kind': kind,
      'id': id,
      'title': title,
      'at': at,
      'data': data,
      'meta': meta,
    });
  }

  static Future<void> putQuiz(String id) async {
    for (final q in await QuizStore.loadAll()) {
      if (q.id == id) await put('quiz', id, q.title, q.toJson());
    }
  }

  static Future<void> putLearn(String id) async {
    for (final d in await LearnStore.loadAll()) {
      if (d.id == id) await put('learn', id, d.title, d.toJson());
    }
  }

  static Future<void> putWords(String topic, List<WordCard> cards) async {
    if (cards.isEmpty) return;
    await put('spell', topic, topic, <String, dynamic>{'cards': cards.map((WordCard c) => c.toMap()).toList()});
  }

  /// All entries, newest first. Entries older than [days] are removed for good.
  static Future<List<Map<String, dynamic>>> list() async {
    final out = <Map<String, dynamic>>[];
    final limit = DateTime.now().subtract(const Duration(days: days)).millisecondsSinceEpoch;
    for (final f in await DocStore.listJsonFiles(_folder)) {
      try {
        final m = Map<String, dynamic>.from(json.decode(await f.readAsString()) as Map);
        m['_file'] = f.path.split('/').last;
        if (((m['at'] as num?) ?? 0) < limit) {
          await _discard(m);
          continue;
        }
        out.add(m);
      } catch (_) {}
    }
    out.sort((a, b) => ((b['at'] as num?) ?? 0).compareTo((a['at'] as num?) ?? 0));
    return out;
  }

  static Future<void> _discard(Map<String, dynamic> m) async {
    if (m['kind'] == 'spell') {
      final cards = (m['data'] is Map ? (m['data'] as Map)['cards'] : null);
      if (cards is List) {
        for (final c in cards) {
          final p = c is Map ? c['imagePath'] : null;
          if (p is String && p.isNotEmpty) {
            try {
              final f = File(p);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          }
        }
      }
    }
    await DocStore.deleteFile(_folder, (m['_file'] ?? '').toString());
  }

  static Future<void> deleteForever(Map<String, dynamic> m) => _discard(m);

  static Future<void> restore(Map<String, dynamic> m) async {
    final kind = (m['kind'] ?? '').toString();
    final id = (m['id'] ?? '').toString();
    final data = Map<String, dynamic>.from(m['data'] as Map);
    if (kind == 'quiz') {
      await QuizStore.save(QuizSet.fromJson(data));
    } else if (kind == 'learn') {
      await LearnStore.save(LearnDoc.fromJson(data));
    } else if (kind == 'spell') {
      final list = <WordCard>[for (final c in (data['cards'] as List)) WordCard.fromMap(Map<String, dynamic>.from(c as Map))];
      await CardStore.addCards(list);
    }
    final meta = m['meta'];
    if (meta is Map) {
      await Library.load();
      await Library.setMeta(
        '$kind:$id',
        c: meta['c']?.toString(),
        s: meta['s']?.toString(),
        t: meta['t']?.toString(),
        e: meta['e']?.toString(),
        ch: meta['ch']?.toString(),
      );
    }
    await DocStore.deleteFile(_folder, (m['_file'] ?? '').toString());
  }
}

class BinScreen extends StatefulWidget {
  const BinScreen({super.key});
  @override
  State<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends State<BinScreen> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Bin.list();
    if (mounted) setState(() => _items = l);
  }

  String _left(Map<String, dynamic> m) {
    final at = DateTime.fromMillisecondsSinceEpoch(((m['at'] as num?) ?? 0).toInt());
    final left = Bin.days - DateTime.now().difference(at).inDays;
    return left <= 1 ? 'last day' : '$left days left';
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final items = _items;
    return ScreenFrame(
      title: '\u{1F5D1}️ Recently deleted',
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : items.isEmpty
              ? Center(child: Text('Nothing here.\nDeleted items wait ${Bin.days} days.', textAlign: TextAlign.center, style: kidText(22 * s)))
              : ListView(
                  padding: EdgeInsets.all(12 * s),
                  children: [
                    for (final m in items)
                      Container(
                        margin: EdgeInsets.only(bottom: 10 * s),
                        padding: EdgeInsets.all(12 * s),
                        decoration: BoxDecoration(color: const Color(0xFF181B3A), borderRadius: BorderRadius.circular(18 * s)),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text((m['title'] ?? '').toString(), style: kidText(18 * s), maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text('${m['kind'] == 'quiz' ? 'Quiz' : (m['kind'] == 'learn' ? 'Notes' : 'Words')}  •  ${_left(m)}', style: kidText(13 * s, w: FontWeight.w600)),
                            ]),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await Bin.restore(m);
                              await _load();
                              if (mounted) showKidsSnack(context, 'Restored.');
                            },
                            child: const Text('Restore'),
                          ),
                          IconButton(
                            tooltip: 'Delete for good',
                            icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF8A80)),
                            onPressed: () async {
                              if (!await askConfirm(context, 'Delete for good?\nThis cannot be undone.')) return;
                              await Bin.deleteForever(m);
                              await _load();
                            },
                          ),
                        ]),
                      ),
                  ],
                ),
    );
  }
}
