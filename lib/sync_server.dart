import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'quiz_model.dart';

// ----------------------------------------------------------------------
// Image files for photo cards
// ----------------------------------------------------------------------
class CardImages {
  static int _counter = 0;

  static Future<Directory> dir() async {
    final doc = await getApplicationDocumentsDirectory();
    final d = Directory('${doc.path}/custom_cards');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<String> save(String dataUrl) async {
    final bytes = base64Decode(dataUrl.split(',').last);
    final d = await dir();
    final file = File('${d.path}/card_${DateTime.now().microsecondsSinceEpoch}_${_counter++}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

// ----------------------------------------------------------------------
// Phone <-> TV sync server (serves the "TV Card Maker" web menu)
// ----------------------------------------------------------------------
class TVSyncServer {
  HttpServer? _server;

  /// Called after ANY change made from the phone so the TV screen can refresh.
  final void Function() onChanged;

  TVSyncServer({required this.onChanged});

  static const Map<String, String> _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  String _clean(dynamic v) => (v ?? '').toString().trim().toUpperCase();
  String _cleanTopic(dynamic v) {
    final t = _clean(v);
    return t.isEmpty ? 'MIXED' : t;
  }

  Map<String, dynamic> _cardToMap(WordCard c) {
    String? url;
    if (c.imagePath != null) {
      url = '/img/${c.imagePath!.split(RegExp(r'[\\/]')).last}';
    }
    return {'id': c.id, 'word': c.word, 'topic': c.topic, 'image': url};
  }

  Future<Response> _guard(Future<Object?> Function() fn) async {
    try {
      final res = await fn();
      return Response.ok(json.encode(res ?? {'status': 'ok'}), headers: _jsonHeaders);
    } catch (e) {
      return Response.internalServerError(body: json.encode({'error': '$e'}), headers: _jsonHeaders);
    }
  }

  Future<Map<String, dynamic>> _body(Request r) async =>
      json.decode(await r.readAsString()) as Map<String, dynamic>;

  Future<int?> startServer() async {
    if (_server != null) return _server!.port;
    final router = Router();

    router.get('/', (Request request) {
      return Response.ok(_embeddedWebPageHtml, headers: {'content-type': 'text/html; charset=utf-8'});
    });

    // ---- everything the phone page needs in one call
    router.get('/api/state', (Request r) => _guard(() async {
          final cards = await CardStore.loadCards();
          final cats = await CardStore.allCategories(cards);
          return {
            'cards': cards.map(_cardToMap).toList(),
            'categories': cats,
            'settings': {'key_sound': CardStore.keySoundOn, 'tts': CardStore.ttsOn},
            'stats': CardStore.stats,
            'pron': CardStore.pronunciations,
          };
        }));

    // ---- card photos
    router.get('/img/<name>', (Request r, String name) async {
      if (name.contains('/') || name.contains('\\') || name.contains('..')) {
        return Response.notFound('not found');
      }
      final d = await CardImages.dir();
      final f = File('${d.path}/$name');
      if (!await f.exists()) return Response.notFound('not found');
      return Response.ok(await f.readAsBytes(), headers: {
        'content-type': 'image/jpeg',
        'cache-control': 'max-age=86400',
      });
    });

    // ---- add a batch of words (with optional photos)
    router.post('/api/upload-batch', (Request r) => _guard(() async {
          final payload = json.decode(await r.readAsString()) as List<dynamic>;
          final newCards = <WordCard>[];
          for (final item in payload) {
            final word = _clean(item['word']);
            if (word.isEmpty) continue;
            final img = item['image_base64'] as String?;
            String? path;
            if (img != null && img.isNotEmpty) path = await CardImages.save(img);
            newCards.add(WordCard(
              id: 'custom_${DateTime.now().microsecondsSinceEpoch}_${newCards.length}',
              word: word,
              topic: _cleanTopic(item['topic']),
              imagePath: path,
              isCustom: true,
            ));
          }
          await CardStore.addCards(newCards);
          onChanged();
          return {'status': 'ok', 'added': newCards.length};
        }));

    // ---- edit one card (word / category / photo)
    router.post('/api/update-card', (Request r) => _guard(() async {
          final data = await _body(r);
          final cards = await CardStore.loadCards();
          final idx = cards.indexWhere((c) => c.id == data['id']);
          if (idx < 0) throw 'Card not found';
          final old = cards[idx];
          var path = old.imagePath;
          final img = data['image_base64'] as String?;
          if (img != null && img.isNotEmpty) {
            await CardImages.delete(path);
            path = await CardImages.save(img);
          } else if (data['remove_image'] == true) {
            await CardImages.delete(path);
            path = null;
          }
          final word = _clean(data['word']);
          cards[idx] = WordCard(
            id: old.id,
            word: word.isEmpty ? old.word : word,
            topic: _cleanTopic(data['topic']),
            imagePath: path,
            isCustom: old.isCustom,
          );
          await CardStore.saveCards(cards);
          onChanged();
          return {'status': 'ok'};
        }));

    // ---- delete cards
    router.post('/api/delete-cards', (Request r) => _guard(() async {
          final data = await _body(r);
          final ids = (data['ids'] as List).map((e) => '$e').toSet();
          for (final id in ids) {
            await CardStore.deleteCard(id);
          }
          onChanged();
          return {'status': 'ok'};
        }));

    // ---- categories
    router.post('/api/add-category', (Request r) => _guard(() async {
          final name = _clean((await _body(r))['name']);
          if (name.isEmpty) throw 'Name is empty';
          await CardStore.addCategory(name);
          onChanged();
          return {'status': 'ok'};
        }));

    router.post('/api/rename-category', (Request r) => _guard(() async {
          final data = await _body(r);
          final from = _clean(data['from']);
          final to = _clean(data['to']);
          if (to.isEmpty || from == 'MIXED') throw 'Cannot rename';
          await CardStore.renameCategory(from, to);
          onChanged();
          return {'status': 'ok'};
        }));

    router.post('/api/delete-category', (Request r) => _guard(() async {
          final name = _clean((await _body(r))['name']);
          if (name == 'MIXED') throw 'MIXED cannot be deleted';
          await CardStore.deleteCategory(name);
          onChanged();
          return {'status': 'ok'};
        }));

    // ---- pronunciation ("say as")
    router.post('/api/set-pronunciation', (Request r) => _guard(() async {
          final data = await _body(r);
          await CardStore.setPronunciation(_clean(data['word']), (data['text'] ?? '').toString());
          onChanged();
          return {'status': 'ok'};
        }));

    // ---- settings toggles
    router.post('/api/settings', (Request r) => _guard(() async {
          final data = await _body(r);
          if (data.containsKey('key_sound')) await CardStore.setKeySound(data['key_sound'] == true);
          if (data.containsKey('tts')) await CardStore.setTts(data['tts'] == true);
          onChanged();
          return {'status': 'ok'};
        }));

    // ---- report card reset
    router.post('/api/reset-stats', (Request r) => _guard(() async {
          await CardStore.resetStats();
          onChanged();
          return {'status': 'ok'};
        }));

    // ---- QUIZ MANAGER (paste / upload JSON from the phone) ----
    router.get('/quiz', (Request request) {
      return Response.ok(_quizPageHtml, headers: {'content-type': 'text/html; charset=utf-8'});
    });

    router.get('/api/quiz/sample', (Request request) {
      return Response.ok(kSampleQuizEnglish, headers: {'content-type': 'text/plain; charset=utf-8'});
    });

    router.get('/api/quiz/list', (Request request) async {
      try {
        final sets = await QuizStore.loadAll();
        final path = await QuizStore.folderPath();
        return Response.ok(
          json.encode({
            'path': path,
            'quizzes': sets
                .map((q) => {'id': q.id, 'title': q.title, 'emoji': q.emoji, 'count': q.questions.length})
                .toList(),
          }),
          headers: _jsonHeaders,
        );
      } catch (e) {
        return Response.internalServerError(body: json.encode({'error': '$e'}), headers: _jsonHeaders);
      }
    });

    router.post('/api/quiz/import', (Request request) async {
      try {
        final body = json.decode(await request.readAsString()) as Map<String, dynamic>;
        final saved = await QuizStore.importText((body['text'] ?? '').toString());
        onChanged();
        return Response.ok(
          json.encode({'status': 'ok', 'count': saved.length, 'titles': saved.map((q) => q.title).toList()}),
          headers: _jsonHeaders,
        );
      } on FormatException catch (e) {
        return Response(400, body: json.encode({'error': e.message}), headers: _jsonHeaders);
      } catch (e) {
        return Response.internalServerError(body: json.encode({'error': '$e'}), headers: _jsonHeaders);
      }
    });

    router.post('/api/quiz/delete', (Request request) async {
      try {
        final body = json.decode(await request.readAsString()) as Map<String, dynamic>;
        await QuizStore.delete((body['id'] ?? '').toString());
        onChanged();
        return Response.ok(json.encode({'status': 'ok'}), headers: _jsonHeaders);
      } catch (e) {
        return Response.internalServerError(body: json.encode({'error': '$e'}), headers: _jsonHeaders);
      }
    });

    try {
      _server = await shelf_io.serve(router.call, InternetAddress.anyIPv4, 8080);
      return _server!.port;
    } catch (e) {
      return null;
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  static const String _quizPageHtml = r'''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Quiz Manager</title>
<style>
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:linear-gradient(180deg,#8fd0f5,#d6efff 70%,#e9f7ff);min-height:100vh;color:#0f172a;padding-bottom:50px}
header{background:#3f6fbf;color:#fff;padding:14px 12px;display:flex;align-items:center;gap:10px;position:sticky;top:0;z-index:10}
header a{color:#fff;text-decoration:none;font-size:28px;width:40px;text-align:center}
header h1{flex:1;text-align:center;font-size:21px;margin:0;font-weight:600;padding-right:40px}
main{max-width:760px;margin:0 auto;padding:16px}
.box{background:#fff;border-radius:16px;padding:16px;margin-bottom:14px;box-shadow:0 3px 0 rgba(30,64,200,.25)}
h2{margin:0 0 8px;font-size:18px}
.muted{color:#64748b;font-size:14px;margin:4px 0 8px}
textarea{width:100%;min-height:200px;padding:12px;border-radius:10px;border:2px solid #3b82f6;font-size:14px;font-family:ui-monospace,Menlo,Consolas,monospace}
button{border:none;border-radius:10px;font-weight:bold;font-size:15px;cursor:pointer;padding:12px 14px;color:#fff;background:#3b82f6}
button.full{width:100%;margin-top:10px}
button.green{background:#10b981}button.red{background:#ef4444}button.gray{background:#64748b}
.row{display:flex;align-items:center;justify-content:space-between;background:#f1f7ff;padding:10px;border-radius:12px;margin-top:8px;gap:8px}
.row b{flex:1;min-width:0;overflow-wrap:anywhere}
#msg{margin-top:10px;padding:10px;border-radius:10px;display:none;white-space:pre-wrap;font-size:14px}
#msg.ok{display:block;background:#dcfce7;color:#166534}
#msg.bad{display:block;background:#fee2e2;color:#991b1b}
pre{background:#0f172a;color:#e2e8f0;padding:12px;border-radius:10px;overflow:auto;font-size:12px;max-height:280px}
ul{margin:6px 0 6px 18px;padding:0;font-size:14px}
</style>
</head>
<body>
<header><a href="/">&#8249;</a><h1>Quiz Manager</h1></header>
<main>
  <div class="box">
    <h2>1. Add a quiz</h2>
    <p class="muted">Paste JSON below, or choose a .json file from your phone. English and Hindi (Devanagari) both work.</p>
    <input type="file" id="file" accept=".json,.txt,application/json,text/plain">
    <textarea id="text" placeholder='{ "title": "My quiz", "questions": [ ... ] }'></textarea>
    <button class="full green" id="importBtn">Check &amp; add to TV</button>
    <div id="msg"></div>
  </div>

  <div class="box">
    <h2>2. Quizzes on the TV</h2>
    <p class="muted" id="path"></p>
    <div id="list"></div>
  </div>

  <div class="box">
    <h2>3. Format guide</h2>
    <p class="muted">Question types (put <b>"type"</b> in each question - or leave it out and it is detected):</p>
    <ul>
      <li><b>mcq</b> - choose one: <code>options</code> + <code>answer</code> (the option text, its number 1-6, or a letter A-F)</li>
      <li><b>short</b> - one word answer: <code>answer</code> (+ optional <code>alternatives</code>)</li>
      <li><b>fill</b> - fill in the blank: use ___ in the question; with <code>options</code> it becomes choose-one</li>
      <li><b>match</b> - matching: <code>pairs</code> as [{"left":"..","right":".."}]</li>
      <li><b>tf</b> - true / false: <code>"answer": true</code></li>
    </ul>
    <p class="muted">Optional per question: <code>explanation</code> (read aloud after a correct answer), <code>hint</code>, <code>lang</code> ("en" or "hi"). Several quizzes in one file: {"quizzes": [ ... ]}. A plain list of questions also works.</p>
    <pre id="sample">Loading...</pre>
    <button class="full" id="copySample">Copy this example</button>
    <button class="full gray" id="copyPrompt">Copy an AI prompt to make quizzes</button>
  </div>
</main>
<script>
function $(id){ return document.getElementById(id); }
function showMsg(text, ok){ var m = $("msg"); m.textContent = text; m.className = ok ? "ok" : "bad"; }

async function loadList(){
  try {
    var r = await fetch("/api/quiz/list");
    var d = await r.json();
    $("path").textContent = "Saved on the TV in: " + d.path;
    var box = $("list");
    box.innerHTML = "";
    if (!d.quizzes.length){ box.textContent = "No quizzes yet."; return; }
    d.quizzes.forEach(function(q){
      var row = document.createElement("div"); row.className = "row";
      var b = document.createElement("b"); b.textContent = q.emoji + "  " + q.title + "  (" + q.count + " questions)";
      var del = document.createElement("button"); del.className = "red"; del.textContent = "Delete";
      del.onclick = async function(){
        if (!confirm("Delete " + q.title + "?")) return;
        await fetch("/api/quiz/delete", {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({id:q.id})});
        loadList();
      };
      row.appendChild(b); row.appendChild(del); box.appendChild(row);
    });
  } catch(e){ $("list").textContent = "Cannot reach the TV: " + e.message; }
}

$("file").onchange = function(){
  var f = $("file").files[0];
  if (!f) return;
  var rd = new FileReader();
  rd.onload = function(){ $("text").value = rd.result; showMsg("File loaded - now press the green button.", true); };
  rd.readAsText(f, "utf-8");
};

$("importBtn").onclick = async function(){
  var text = $("text").value;
  if (!text.trim()){ showMsg("Paste some JSON first.", false); return; }
  try {
    var r = await fetch("/api/quiz/import", {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({text:text})});
    var d = await r.json();
    if (!r.ok){ showMsg("Problem: " + (d.error || "unknown"), false); return; }
    showMsg("Added " + d.count + " quiz(zes): " + d.titles.join(", "), true);
    $("text").value = "";
    loadList();
  } catch(e){ showMsg("Could not reach the TV: " + e.message, false); }
};

var sampleText = "";
fetch("/api/quiz/sample").then(function(r){ return r.text(); }).then(function(t){ sampleText = t.trim(); $("sample").textContent = sampleText; });

function copyText(t){
  if (navigator.clipboard && navigator.clipboard.writeText){ navigator.clipboard.writeText(t).then(function(){ showMsg("Copied!", true); }); return; }
  var ta = document.createElement("textarea"); ta.value = t; document.body.appendChild(ta); ta.select(); document.execCommand("copy"); document.body.removeChild(ta); showMsg("Copied!", true);
}
$("copySample").onclick = function(){ copyText(sampleText); };
$("copyPrompt").onclick = function(){
  copyText("Create a kids quiz as JSON only (no explanation). Topic: <TOPIC>. Language: <English or Hindi>. Make 10 questions mixing these types: mcq (4 options), short (one word), fill (with ___), match (4 pairs) and tf (true/false). Use exactly this format:\n\n" + sampleText);
};
loadList();
</script>
</body>
</html>
''';

  // Raw string: JavaScript template text and dollar signs are safe inside.
  static const String _embeddedWebPageHtml = r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>TV Card Maker</title>
  <link href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css" rel="stylesheet">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js"></script>
  <style>
    :root { --hdr:#3f6fbf; --blue:#3b82f6; --deep:#1e40c8; --yellow:#fde047; --green:#10b981; --red:#ef4444; --ink:#0f172a; --muted:#64748b; }
    * { box-sizing: border-box; }
    body { margin:0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; color:var(--ink);
           background: linear-gradient(180deg,#8fd0f5,#d6efff 70%,#e9f7ff); min-height:100vh; padding-bottom:40px; }
    header { background:var(--hdr); color:#fff; padding:14px 12px; display:flex; align-items:center; gap:10px; position:sticky; top:0; z-index:20; }
    header h1 { flex:1; text-align:center; font-size:21px; margin:0; font-weight:600; }
    #backBtn { background:transparent; border:none; color:#fff; font-size:28px; width:40px; visibility:hidden; cursor:pointer; }
    #hdrSpace { width:40px; }
    .view { display:none; padding:16px; max-width:720px; margin:0 auto; }
    .view.active { display:block; }
    .menu { background:linear-gradient(90deg,#3b82f6,#6da8f7); border:3px solid var(--deep); border-radius:22px; overflow:hidden; }
    .mrow { display:flex; align-items:center; justify-content:space-between; padding:22px 18px; color:#fff; font-size:21px; border-bottom:2px solid var(--deep); cursor:pointer; }
    .mrow:last-child { border-bottom:none; }
    .play { width:48px; height:48px; border-radius:50%; background:#facc15; color:#111; display:flex; align-items:center; justify-content:center; font-style:normal; font-size:18px; }
    .sw { display:flex; align-items:center; justify-content:space-between; gap:8px; background:#facc15; color:#111; font-weight:bold; border-radius:30px; width:92px; height:42px; padding:0 8px 0 14px; }
    .sw u { width:28px; height:28px; border-radius:50%; background:#111; }
    .sw.off { flex-direction:row-reverse; padding:0 14px 0 8px; background:#cbd5e1; }
    .box { background:#fff; border-radius:16px; padding:16px; margin-bottom:14px; box-shadow:0 3px 0 rgba(30,64,200,.25); }
    h2 { margin:0 0 6px; font-size:18px; }
    .muted { color:var(--muted); font-size:14px; margin:4px 0 8px; }
    input[type=text], textarea, select { width:100%; padding:12px; border-radius:10px; border:2px solid var(--blue); background:#fff; color:var(--ink); font-size:16px; }
    textarea { text-transform:uppercase; min-height:100px; resize:vertical; }
    button { border:none; border-radius:10px; font-weight:bold; font-size:15px; cursor:pointer; padding:12px 14px; color:#fff; }
    button:disabled { opacity:.45; }
    .full { width:100%; margin-top:10px; }
    .blue { background:var(--blue); } .green { background:var(--green); } .red { background:var(--red); } .gray { background:#64748b; }
    .outline { background:#fff; border:2px solid var(--blue); color:var(--blue); padding:8px 10px; font-size:14px; }
    .chips { display:flex; flex-wrap:wrap; gap:8px; margin:8px 0 0; }
    .chip { background:#e0efff; color:var(--deep); border-radius:20px; padding:6px 12px; font-size:13px; font-weight:600; cursor:pointer; }
    .row { display:flex; align-items:center; justify-content:space-between; background:#f1f7ff; padding:10px; border-radius:12px; margin-top:8px; gap:8px; }
    .row .left { display:flex; align-items:center; gap:10px; min-width:0; flex:1; }
    .thumb { width:50px; height:50px; border-radius:10px; object-fit:cover; background:#cbd5e1; display:flex; align-items:center; justify-content:center; font-size:22px; flex-shrink:0; }
    .word { font-weight:bold; font-size:17px; overflow:hidden; text-overflow:ellipsis; }
    .tag { font-size:12px; color:var(--deep); font-weight:600; }
    .actions { display:flex; gap:6px; }
    .actions button { padding:8px 10px; font-size:13px; }
    .bar { display:flex; gap:8px; margin-top:8px; }
    .stats { display:flex; gap:10px; }
    .stat { flex:1; background:#f1f7ff; border-radius:12px; padding:10px; text-align:center; font-size:13px; color:var(--muted); }
    .stat b { display:block; font-size:24px; color:var(--deep); }
    .rep { display:grid; grid-template-columns:1fr 46px 46px 46px; gap:4px; align-items:center; padding:8px 4px; border-bottom:1px solid #e2e8f0; text-align:center; }
    .rep .w { text-align:left; font-weight:bold; }
    .rep.head { font-size:12px; color:var(--muted); }
    .pron { display:flex; gap:8px; align-items:center; margin-top:8px; }
    .pron b { width:90px; flex-shrink:0; overflow:hidden; text-overflow:ellipsis; }
    .pron input { flex:1; padding:9px; }
    .modal { display:none; position:fixed; inset:0; background:rgba(0,0,0,.92); z-index:100; padding:16px; overflow:auto; }
    #cropContainer { max-height:60vh; margin-bottom:16px; }
    img { max-width:100%; }
    #toast { position:fixed; left:50%; bottom:30px; transform:translateX(-50%); background:var(--green); color:#fff; padding:12px 18px; border-radius:24px; opacity:0; pointer-events:none; transition:opacity .25s; z-index:200; }
    #toast.show { opacity:1; } #toast.bad { background:var(--red); }
  </style>
</head>
<body>
  <header>
    <button id="backBtn">&#8249;</button>
    <h1 id="title">Settings</h1>
    <div id="hdrSpace"></div>
  </header>

  <!-- HOME MENU -->
  <section id="v-home" class="view active">
    <div class="menu">
      <div class="mrow" onclick="location.href='/quiz'"><span>Quiz Time - add / manage quizzes</span><i class="play">&#9654;</i></div>
      <div class="mrow" data-go="add"><span>Add words &amp; photos</span><i class="play">&#9654;</i></div>
      <div class="mrow" data-go="manage"><span>Manage spelling list</span><i class="play">&#9654;</i></div>
      <div class="mrow" data-go="cats"><span>Manage custom category</span><i class="play">&#9654;</i></div>
      <div class="mrow" data-go="report"><span>Report Card</span><i class="play">&#9654;</i></div>
      <div class="mrow" data-go="pron"><span>Change pronounce</span><i class="play">&#9654;</i></div>
      <div class="mrow" id="rowKey"><span>Key press sound</span><div class="sw" id="swKey"><b>ON</b><u></u></div></div>
      <div class="mrow" id="rowTts"><span>Text to speech</span><div class="sw" id="swTts"><b>ON</b><u></u></div></div>
    </div>
  </section>

  <!-- ADD WORDS -->
  <section id="v-add" class="view">
    <div class="box">
      <h2>1. Category</h2>
      <p class="muted">Tap one or type a new name (e.g. FRUITS). Empty means MIXED.</p>
      <input type="text" id="catInput" list="catList" placeholder="MIXED" autocomplete="off">
      <datalist id="catList"></datalist>
      <div class="chips" id="catChips"></div>
    </div>
    <div class="box">
      <h2>2. Paste words</h2>
      <p class="muted">Separate words with commas (APPLE, BANANA, MANGO)</p>
      <textarea id="bulkInput" placeholder="APPLE, BANANA..."></textarea>
      <button id="createDraftsBtn" class="blue full">Create Drafts</button>
    </div>
    <div class="box">
      <h2>3. Draft queue (<span id="qCount">0</span>)</h2>
      <div id="queueList"></div>
      <button id="sendBtn" class="green full" style="display:none;">Send All to TV</button>
    </div>
  </section>

  <!-- MANAGE SPELLING LIST -->
  <section id="v-manage" class="view">
    <div class="box">
      <input type="text" id="search" placeholder="Search word..." autocomplete="off">
      <div style="height:8px"></div>
      <select id="filterCat"></select>
      <p class="muted" id="mCount"></p>
      <div class="bar">
        <button id="selAllBtn" class="gray" style="flex:1">Select all</button>
        <button id="delSelBtn" class="red" style="flex:1" disabled>Delete selected</button>
      </div>
      <div id="cardList"></div>
    </div>
  </section>

  <!-- CUSTOM CATEGORIES -->
  <section id="v-cats" class="view">
    <div class="box">
      <h2>New category</h2>
      <div class="bar">
        <input type="text" id="newCat" placeholder="e.g. VEGETABLES" autocomplete="off">
        <button id="addCatBtn" class="blue">Add</button>
      </div>
    </div>
    <div class="box">
      <h2>Your categories</h2>
      <p class="muted">Deleting a category moves its words to MIXED.</p>
      <div id="catManage"></div>
    </div>
  </section>

  <!-- REPORT CARD -->
  <section id="v-report" class="view">
    <div class="box">
      <div class="stats">
        <div class="stat"><b id="rC">0</b>&#10004; Correct</div>
        <div class="stat"><b id="rW">0</b>&#10008; Wrong</div>
        <div class="stat"><b id="rH">0</b>&#128161; Hints</div>
      </div>
    </div>
    <div class="box">
      <h2>Words</h2>
      <p class="muted" id="rNote"></p>
      <div id="repList"></div>
      <button id="resetBtn" class="red full">Reset report card</button>
    </div>
  </section>

  <!-- PRONUNCIATION -->
  <section id="v-pron" class="view">
    <div class="box">
      <h2>Change pronounce</h2>
      <p class="muted">Type how the TV should say a word (e.g. write "kee wee" for KIWI). Leave empty to use the normal word.</p>
      <input type="text" id="pronSearch" placeholder="Search word..." autocomplete="off">
      <div id="pronList"></div>
    </div>
  </section>

  <!-- CROP MODAL -->
  <div id="cropModal" class="modal" style="z-index:150;">
    <div id="cropContainer"><img id="cropImage"></div>
    <button id="confirmCropBtn" class="green full">Confirm Crop</button>
    <button id="cancelCropBtn" class="outline full" style="border-color:#ef4444;color:#ef4444;">Cancel</button>
  </div>

  <!-- EDIT MODAL -->
  <div id="editModal" class="modal">
    <div class="box">
      <h2>Edit card</h2>
      <p class="muted">Word</p>
      <input type="text" id="editWord" autocomplete="off" style="text-transform:uppercase">
      <p class="muted">Category</p>
      <input type="text" id="editCat" list="catList" autocomplete="off" style="text-transform:uppercase">
      <p class="muted">Photo</p>
      <div style="display:flex;align-items:center;gap:12px;">
        <img id="editPreview" class="thumb" style="width:90px;height:90px;display:none;">
        <div style="flex:1">
          <button id="editPhotoBtn" class="outline full" style="margin-top:0">Choose / Crop photo</button>
          <button id="editRemoveBtn" class="outline full" style="border-color:#ef4444;color:#ef4444;">Remove photo</button>
        </div>
      </div>
      <button id="editSaveBtn" class="green full">Save</button>
      <button id="editCancelBtn" class="gray full">Cancel</button>
    </div>
  </div>

  <div id="toast"></div>

  <script>
    let S = { cards: [], categories: [], settings: { key_sound: true, tts: true }, stats: {}, pron: {} };
    let queue = [], cropper = null, cropCallback = null;
    let editing = null, editImage = undefined; // undefined = unchanged, null = removed, string = new photo
    const selected = new Set();
    const el = id => document.getElementById(id);
    const TITLES = { home: "Settings", add: "Add words", manage: "Manage spelling list", cats: "Custom categories", report: "Report Card", pron: "Change pronounce" };

    function esc(s) {
      return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
    }
    function toast(msg, bad) {
      const t = el("toast");
      t.textContent = msg;
      t.className = "show" + (bad ? " bad" : "");
      clearTimeout(toast.h);
      toast.h = setTimeout(() => { t.className = ""; }, 2400);
    }
    async function api(path, body) {
      const opt = body === undefined ? {} : { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) };
      const r = await fetch(path, opt);
      if (!r.ok) throw new Error(await r.text());
      return r.json();
    }
    async function load() {
      try { S = await api("/api/state"); renderAll(); }
      catch (e) { toast("Cannot reach TV", true); }
    }

    // ---------- navigation ----------
    function showView(name) {
      document.querySelectorAll(".view").forEach(v => v.classList.toggle("active", v.id === "v-" + name));
      el("title").innerText = TITLES[name];
      el("backBtn").style.visibility = name === "home" ? "hidden" : "visible";
      window.scrollTo(0, 0);
      if (name !== "add") load();
    }
    el("backBtn").addEventListener("click", () => showView("home"));
    document.querySelectorAll(".mrow[data-go]").forEach(r => r.addEventListener("click", () => showView(r.dataset.go)));

    // ---------- toggles ----------
    function paintSwitch(id, on) {
      const s = el(id);
      s.className = "sw" + (on ? "" : " off");
      s.querySelector("b").innerText = on ? "ON" : "OFF";
    }
    async function toggle(key) {
      try { await api("/api/settings", { [key]: !S.settings[key] }); await load(); }
      catch (e) { toast("Failed", true); }
    }
    el("rowKey").addEventListener("click", () => toggle("key_sound"));
    el("rowTts").addEventListener("click", () => toggle("tts"));

    // ---------- rendering ----------
    function catCounts() {
      const m = {};
      S.categories.forEach(c => { m[c] = 0; });
      S.cards.forEach(c => { m[c.topic] = (m[c.topic] || 0) + 1; });
      return m;
    }
    function renderAll() {
      paintSwitch("swKey", S.settings.key_sound);
      paintSwitch("swTts", S.settings.tts);

      el("catList").innerHTML = S.categories.map(t => "<option value=\"" + esc(t) + "\">").join("");
      el("catChips").innerHTML = S.categories.map(t => "<span class=\"chip\" data-cat=\"" + esc(t) + "\">" + esc(t) + "</span>").join("");

      const counts = catCounts();
      const fc = el("filterCat");
      const prev = fc.value;
      fc.innerHTML = "<option value=\"\">All categories (" + S.cards.length + ")</option>" +
        S.categories.map(t => "<option value=\"" + esc(t) + "\">" + esc(t) + " (" + (counts[t] || 0) + ")</option>").join("");
      fc.value = S.categories.includes(prev) ? prev : "";

      el("catManage").innerHTML = S.categories.map(t => {
        const locked = t === "MIXED";
        return "<div class=\"row\"><div class=\"left\"><div><div class=\"word\">" + esc(t) + "</div><div class=\"tag\">" + (counts[t] || 0) + " words</div></div></div>" +
          "<div class=\"actions\"><button class=\"outline\" data-cact=\"rename\" data-name=\"" + esc(t) + "\"" + (locked ? " disabled" : "") + ">Rename</button>" +
          "<button class=\"red\" data-cact=\"delete\" data-name=\"" + esc(t) + "\"" + (locked ? " disabled" : "") + ">Delete</button></div></div>";
      }).join("");

      renderManage();
      renderQueue();
      renderReport();
      renderPron();
    }

    function renderQueue() {
      const list = el("queueList");
      el("qCount").innerText = queue.length;
      el("sendBtn").style.display = queue.length > 0 ? "block" : "none";
      list.innerHTML = "";
      queue.forEach((item, index) => {
        const div = document.createElement("div");
        div.className = "row";
        const thumb = item.image_base64 ? "<img class=\"thumb\" src=\"" + item.image_base64 + "\">" : "<div class=\"thumb\">&#11088;</div>";
        div.innerHTML = "<div class=\"left\">" + thumb + "<div><div class=\"word\">" + esc(item.word) + "</div><div class=\"tag\">" + esc(item.topic) + "</div></div></div>" +
          "<div class=\"actions\"><button class=\"outline\" data-q=\"photo\">" + (item.image_base64 ? "Edit" : "+ Photo") + "</button>" +
          "<button class=\"red\" data-q=\"remove\">&#10005;</button></div>";
        div.querySelector("[data-q=photo]").onclick = () => pickPhoto(url => { queue[index].image_base64 = url; renderQueue(); });
        div.querySelector("[data-q=remove]").onclick = () => { queue.splice(index, 1); renderQueue(); };
        list.appendChild(div);
      });
    }

    function filteredCards() {
      const q = el("search").value.trim().toUpperCase();
      const f = el("filterCat").value;
      return S.cards.filter(c => (!q || c.word.includes(q)) && (!f || c.topic === f));
    }
    function renderManage() {
      const list = filteredCards();
      el("mCount").innerText = list.length + " of " + S.cards.length + " words";
      el("cardList").innerHTML = list.length ? list.map(c => {
        const thumb = c.image ? "<img class=\"thumb\" src=\"" + c.image + "\">" : "<div class=\"thumb\">&#11088;</div>";
        return "<div class=\"row\"><div class=\"left\"><input type=\"checkbox\" data-sel=\"" + esc(c.id) + "\"" + (selected.has(c.id) ? " checked" : "") + ">" + thumb +
          "<div style=\"min-width:0\"><div class=\"word\">" + esc(c.word) + "</div><div class=\"tag\">" + esc(c.topic) + "</div></div></div>" +
          "<div class=\"actions\"><button class=\"outline\" data-act=\"edit\" data-id=\"" + esc(c.id) + "\">Edit</button>" +
          "<button class=\"red\" data-act=\"del\" data-id=\"" + esc(c.id) + "\">&#128465;</button></div></div>";
      }).join("") : "<p class=\"muted\">No words found.</p>";
      el("delSelBtn").disabled = selected.size === 0;
      el("delSelBtn").innerText = selected.size ? "Delete selected (" + selected.size + ")" : "Delete selected";
    }

    function renderReport() {
      let tc = 0, tw = 0, th = 0, practiced = 0;
      const rows = S.cards.map(c => {
        const s = S.stats[c.word] || { c: 0, w: 0, h: 0 };
        tc += s.c || 0; tw += s.w || 0; th += s.h || 0;
        if ((s.c || 0) + (s.w || 0) + (s.h || 0) > 0) practiced++;
        return { word: c.word, c: s.c || 0, w: s.w || 0, h: s.h || 0 };
      }).filter(r => r.c + r.w + r.h > 0).sort((a, b) => b.w - a.w || b.h - a.h);
      el("rC").innerText = tc; el("rW").innerText = tw; el("rH").innerText = th;
      el("rNote").innerText = practiced + " of " + S.cards.length + " words practiced. Words with the most mistakes are on top.";
      el("repList").innerHTML = "<div class=\"rep head\"><div class=\"w\">Word</div><div>&#10004;</div><div>&#10008;</div><div>&#128161;</div></div>" +
        (rows.length ? rows.map(r => "<div class=\"rep\"><div class=\"w\">" + esc(r.word) + "</div><div>" + r.c + "</div><div>" + r.w + "</div><div>" + r.h + "</div></div>").join("") : "<p class=\"muted\">Nothing practiced yet.</p>");
    }

    function renderPron() {
      const q = el("pronSearch").value.trim().toUpperCase();
      const words = Array.from(new Set(S.cards.map(c => c.word))).sort().filter(w => !q || w.includes(q));
      el("pronList").innerHTML = words.length ? words.map(w =>
        "<div class=\"pron\"><b>" + esc(w) + "</b><input type=\"text\" value=\"" + esc(S.pron[w] || "") + "\" placeholder=\"say as...\" autocomplete=\"off\">" +
        "<button class=\"blue\" data-pw=\"" + esc(w) + "\">Save</button></div>").join("") : "<p class=\"muted\">No words.</p>";
    }

    // ---------- add words ----------
    el("catChips").addEventListener("click", e => {
      const c = e.target.closest("[data-cat]");
      if (c) el("catInput").value = c.dataset.cat;
    });
    el("createDraftsBtn").addEventListener("click", () => {
      const topic = (el("catInput").value.trim().toUpperCase()) || "MIXED";
      const words = el("bulkInput").value.split(",").map(w => w.trim().toUpperCase()).filter(w => w.length > 0);
      if (!words.length) { toast("Type some words first", true); return; }
      words.forEach(word => queue.push({ word: word, topic: topic, image_base64: null }));
      el("bulkInput").value = "";
      renderQueue();
    });
    el("sendBtn").addEventListener("click", async () => {
      const btn = el("sendBtn");
      btn.disabled = true; btn.innerText = "Sending...";
      try {
        const r = await api("/api/upload-batch", queue);
        toast("Sent " + r.added + " cards to TV");
        queue = [];
        await load();
      } catch (e) { toast("Error sending to TV", true); }
      btn.disabled = false; btn.innerText = "Send All to TV";
    });

    // ---------- manage list ----------
    el("search").addEventListener("input", renderManage);
    el("filterCat").addEventListener("change", renderManage);
    el("cardList").addEventListener("change", e => {
      const id = e.target.dataset.sel;
      if (!id) return;
      if (e.target.checked) selected.add(id); else selected.delete(id);
      renderManage();
    });
    el("cardList").addEventListener("click", async e => {
      const b = e.target.closest("[data-act]");
      if (!b) return;
      if (b.dataset.act === "del") {
        if (!confirm("Delete this word?")) return;
        await deleteCards([b.dataset.id]);
      } else { openEdit(b.dataset.id); }
    });
    el("selAllBtn").addEventListener("click", () => {
      const list = filteredCards();
      const all = list.every(c => selected.has(c.id));
      list.forEach(c => { if (all) selected.delete(c.id); else selected.add(c.id); });
      renderManage();
    });
    el("delSelBtn").addEventListener("click", async () => {
      if (!selected.size || !confirm("Delete " + selected.size + " selected words?")) return;
      await deleteCards(Array.from(selected));
    });
    async function deleteCards(ids) {
      try {
        await api("/api/delete-cards", { ids: ids });
        ids.forEach(i => selected.delete(i));
        toast("Deleted");
        await load();
      } catch (e) { toast("Delete failed", true); }
    }

    // ---------- edit modal ----------
    function openEdit(id) {
      editing = S.cards.find(c => c.id === id);
      if (!editing) return;
      editImage = undefined;
      el("editWord").value = editing.word;
      el("editCat").value = editing.topic;
      showEditPreview(editing.image);
      el("editModal").style.display = "block";
    }
    function showEditPreview(src) {
      const p = el("editPreview");
      if (src) { p.src = src; p.style.display = "block"; } else { p.style.display = "none"; }
    }
    el("editPhotoBtn").addEventListener("click", () => pickPhoto(url => { editImage = url; showEditPreview(url); }));
    el("editRemoveBtn").addEventListener("click", () => { editImage = null; showEditPreview(null); });
    el("editCancelBtn").addEventListener("click", () => { el("editModal").style.display = "none"; });
    el("editSaveBtn").addEventListener("click", async () => {
      const body = { id: editing.id, word: el("editWord").value, topic: el("editCat").value };
      if (typeof editImage === "string") body.image_base64 = editImage;
      else if (editImage === null) body.remove_image = true;
      try {
        await api("/api/update-card", body);
        el("editModal").style.display = "none";
        toast("Saved");
        await load();
      } catch (e) { toast("Save failed", true); }
    });

    // ---------- categories ----------
    el("addCatBtn").addEventListener("click", async () => {
      const name = el("newCat").value.trim();
      if (!name) return;
      try { await api("/api/add-category", { name: name }); el("newCat").value = ""; toast("Category added"); await load(); }
      catch (e) { toast("Failed", true); }
    });
    el("catManage").addEventListener("click", async e => {
      const b = e.target.closest("[data-cact]");
      if (!b) return;
      const name = b.dataset.name;
      try {
        if (b.dataset.cact === "rename") {
          const to = prompt("New name for " + name, name);
          if (!to || !to.trim()) return;
          await api("/api/rename-category", { from: name, to: to });
        } else {
          if (!confirm("Delete category " + name + "? Its words move to MIXED.")) return;
          await api("/api/delete-category", { name: name });
        }
        toast("Done");
        await load();
      } catch (err) { toast("Failed", true); }
    });

    // ---------- report card ----------
    el("resetBtn").addEventListener("click", async () => {
      if (!confirm("Reset the whole report card?")) return;
      try { await api("/api/reset-stats", {}); toast("Report card reset"); await load(); }
      catch (e) { toast("Failed", true); }
    });

    // ---------- pronunciation ----------
    el("pronSearch").addEventListener("input", renderPron);
    el("pronList").addEventListener("click", async e => {
      const b = e.target.closest("[data-pw]");
      if (!b) return;
      const text = b.parentElement.querySelector("input").value;
      try { await api("/api/set-pronunciation", { word: b.dataset.pw, text: text }); S.pron[b.dataset.pw] = text.trim(); toast("Saved"); }
      catch (err) { toast("Failed", true); }
    });

    // ---------- photo pick + crop ----------
    function pickPhoto(cb) {
      const inp = document.createElement("input");
      inp.type = "file";
      inp.accept = "image/*";
      inp.onchange = () => { const f = inp.files[0]; if (f) openCropper(f, cb); };
      inp.click();
    }
    function autoSquare(dataUrl) {
      return new Promise(resolve => {
        const im = new Image();
        im.onload = () => {
          const s = Math.min(im.width, im.height);
          const cv = document.createElement("canvas");
          cv.width = 400; cv.height = 400;
          cv.getContext("2d").drawImage(im, (im.width - s) / 2, (im.height - s) / 2, s, s, 0, 0, 400, 400);
          resolve(cv.toDataURL("image/jpeg", 0.7));
        };
        im.src = dataUrl;
      });
    }
    function openCropper(file, cb) {
      cropCallback = cb;
      const reader = new FileReader();
      reader.onload = e => {
        if (typeof Cropper === "undefined") { autoSquare(e.target.result).then(cb); return; }
        el("cropModal").style.display = "block";
        const img = el("cropImage");
        if (cropper) { cropper.destroy(); cropper = null; }
        img.onload = () => { cropper = new Cropper(img, { aspectRatio: 1, viewMode: 1, autoCropArea: 1 }); };
        img.src = e.target.result;
      };
      reader.readAsDataURL(file);
    }
    function closeCrop() {
      el("cropModal").style.display = "none";
      if (cropper) { cropper.destroy(); cropper = null; }
    }
    el("confirmCropBtn").addEventListener("click", () => {
      if (!cropper) return;
      const url = cropper.getCroppedCanvas({ width: 400, height: 400 }).toDataURL("image/jpeg", 0.7);
      closeCrop();
      if (cropCallback) cropCallback(url);
    });
    el("cancelCropBtn").addEventListener("click", closeCrop);

    load();
  </script>
</body>
</html>
''';
}
