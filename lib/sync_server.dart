import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'app_store.dart';
import 'core_audio_models.dart';
import 'doc_store.dart';
import 'quiz_model.dart';

// ----------------------------------------------------------------------
// Image files for photo cards
// ----------------------------------------------------------------------
class CardImages {
  static int _counter = 0;

  static Future<Directory> dir() async {
    return DocStore.folder('photos');
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

  static const Map<String, String> _corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'access-control-allow-private-network': 'true',
  };

  Middleware get _cors => createMiddleware(
        requestHandler: (Request r) => r.method == 'OPTIONS' ? Response(204, headers: _corsHeaders) : null,
        responseHandler: (Response resp) => resp.change(headers: _corsHeaders),
      );

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
      return Response.ok(_embeddedWebPageHtml.replaceFirst('</body>', '$_pageCropHtml</body>'), headers: {'content-type': 'text/html; charset=utf-8'});
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

    // ---- OFFLINE MAKER: the phone saves words/quizzes locally and sends them when connected ----
    router.get('/api/ping', (Request request) {
      return Response.ok(json.encode({'ok': true}), headers: _jsonHeaders);
    });

    router.get('/offline', (Request request) {
      return Response.ok(_offlinePageHtml.replaceAll('__TV_BASE__', '').replaceFirst('</body>', '$_pageCropHtml</body>'), headers: {'content-type': 'text/html; charset=utf-8'});
    });

    // same page as a downloadable file, with this TV's address built in
    router.get('/offline.html', (Request request) {
      final host = request.headers['host'] ?? '';
      final base = host.isEmpty ? '' : 'http://$host';
      return Response.ok(
        _offlinePageHtml.replaceAll('__TV_BASE__', base).replaceFirst('</body>', '$_pageCropHtml</body>'),
        headers: {
          'content-type': 'text/html; charset=utf-8',
          'content-disposition': 'attachment; filename="KidsLearning_Offline.html"',
        },
      );
    });

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
      final handler = const Pipeline().addMiddleware(_cors).addHandler(router.call);
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      return _server!.port;
    } catch (e) {
      return null;
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  static const String _pageCropHtml = r'''
<style>
#pcOv{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:#0b1220;z-index:400;color:#fff;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;flex-direction:column}
#pcOv *{box-sizing:border-box}
#pcOv .pcTop{display:flex;align-items:center;gap:8px;padding:8px 10px;background:#1e3a8a}
#pcOv .pcTop b{flex:1;font-size:16px}
#pcOv button{border:0;border-radius:10px;font-weight:700;font-size:15px;color:#fff;background:#3b82f6;padding:10px 12px;cursor:pointer}
#pcOv button.g{background:#16a34a}#pcOv button.r{background:#dc2626}#pcOv button.s{background:#475569}
#pcOv .pcChips{display:flex;gap:6px;overflow-x:auto;padding:8px 8px 4px;background:#111c33}
#pcOv .chip{flex:none;display:flex;align-items:center;gap:6px;padding:4px 10px 4px 4px;border-radius:20px;background:#1f2a44;border:2px solid transparent;font-size:14px;cursor:pointer}
#pcOv .chip.cur{border-color:#facc15;background:#334155}
#pcOv .chip img{width:26px;height:26px;border-radius:50%;object-fit:cover}
#pcOv .chip i{width:26px;height:26px;border-radius:50%;background:#475569;display:inline-block}
#pcOv .pcWrap{flex:1;overflow:auto;position:relative;background:#000;-webkit-overflow-scrolling:touch}
#pcOv .pcBox{position:relative;display:inline-block;line-height:0;cursor:crosshair}
#pcOv .pcBox img{display:block;max-width:none}
#pcOv .pcSel{position:absolute;border:3px solid #facc15;box-shadow:0 0 0 9999px rgba(0,0,0,.55);pointer-events:none;border-radius:4px}
#pcOv .pcBar{padding:8px 10px;background:#111c33;display:flex;flex-wrap:wrap;gap:6px;align-items:center;justify-content:center}
#pcOv .pcBar canvas{width:64px;height:64px;border-radius:8px;background:#222;border:2px solid #facc15}
#pcOv .pcHint{padding:6px 10px;text-align:center;font-size:13px;background:#0f172a;color:#cbd5e1}
#pcOv .pcBtn{min-width:48px}
</style>
<div id="pcOv">
  <div class="pcTop"><b id="pcTitle">Crop pictures from a page</b><button class="r" id="pcClose">&#10006; Close</button></div>
  <div class="pcChips" id="pcChips"></div>
  <div class="pcHint" id="pcHint">Step 1: choose a photo of the book page</div>
  <div class="pcWrap" id="pcWrap" style="display:none"><div class="pcBox" id="pcBox"><img id="pcImg" alt=""><div class="pcSel" id="pcSel"></div></div></div>
  <div id="pcStart" style="padding:30px 16px;text-align:center">
    <button class="g" id="pcPick" style="font-size:18px;padding:16px 22px">&#128247; Choose / take page photo</button>
    <p style="color:#94a3b8;font-size:14px;line-height:1.5">Take one photo of the whole page. Then, for each word, tap on its picture and press <b>Use</b>.</p>
  </div>
  <div class="pcBar" id="pcBar" style="display:none">
    <canvas id="pcPrev" width="64" height="64"></canvas>
    <button class="s pcBtn" id="pcL">&#9664;</button><button class="s pcBtn" id="pcU">&#9650;</button><button class="s pcBtn" id="pcD">&#9660;</button><button class="s pcBtn" id="pcR">&#9654;</button>
    <button class="s pcBtn" id="pcMinus">&#8722; Size</button><button class="s pcBtn" id="pcPlus">&#43; Size</button>
    <button class="s pcBtn" id="pcShape">&#9633; Square</button>
    <button class="s pcBtn" id="pcZm">&#128269; &#8722;</button><button class="s pcBtn" id="pcZp">&#128269; &#43;</button>
    <button class="g" id="pcUse" style="flex:1 1 140px;font-size:17px">&#10004; Use for ...</button>
    <button class="s" id="pcSkip">Skip</button>
    <button class="g" id="pcDone">Done</button>
  </div>
</div>
<script>
(function(){
  var ov, words = [], results = [], cur = 0, cb = null;
  var img = null, natW = 0, natH = 0;
  var cx = 0.5, cy = 0.5, size = 0.22, shape = 0, zoom = 1;   // size = box width as a fraction of the image width
  var SHAPES = [{n: "\u25A1 Square", a: 1}, {n: "\u25AD Wide", a: 4 / 3}, {n: "\u25AF Tall", a: 3 / 4}];
  function g(id){ return document.getElementById(id); }

  function boxDims(){   // box width/height as fractions of the image width/height
    var a = SHAPES[shape].a;
    var w = size, h = (size * natW / a) / natH;
    if (w > 1){ w = 1; h = (w * natW / a) / natH; }
    if (h > 1){ h = 1; w = (h * natH * a) / natW; }
    return {w: w, h: h};
  }
  function clampPos(){
    var d = boxDims();
    cx = Math.min(1 - d.w / 2, Math.max(d.w / 2, cx));
    cy = Math.min(1 - d.h / 2, Math.max(d.h / 2, cy));
  }
  function drawSel(){
    if (!img) return;
    clampPos();
    var d = boxDims(), el = g("pcSel"), r = g("pcImg");
    var W = r.clientWidth, H = r.clientHeight;
    el.style.left = ((cx - d.w / 2) * W) + "px"; el.style.top = ((cy - d.h / 2) * H) + "px";
    el.style.width = (d.w * W) + "px"; el.style.height = (d.h * H) + "px";
    var c = g("pcPrev"), x = c.getContext("2d");
    x.fillStyle = "#222"; x.fillRect(0, 0, 64, 64);
    var sw = d.w * natW, sh = d.h * natH, sx = (cx - d.w / 2) * natW, sy = (cy - d.h / 2) * natH;
    var k = Math.min(64 / sw, 64 / sh);
    x.drawImage(img, sx, sy, sw, sh, (64 - sw * k) / 2, (64 - sh * k) / 2, sw * k, sh * k);
  }
  function chips(){
    var box = g("pcChips"); box.innerHTML = "";
    words.forEach(function(w, i){
      var c = document.createElement("div"); c.className = "chip" + (i === cur ? " cur" : "");
      var th;
      if (results[i]){ th = document.createElement("img"); th.src = results[i]; } else { th = document.createElement("i"); }
      var s = document.createElement("span"); s.textContent = w;
      c.appendChild(th); c.appendChild(s);
      c.onclick = function(){ cur = i; refresh(); };
      box.appendChild(c);
    });
    var cc = box.children[cur]; if (cc && cc.scrollIntoView) cc.scrollIntoView({inline: "center", block: "nearest"});
  }
  function refresh(){
    chips();
    g("pcUse").innerHTML = "\u2714 Use for " + (words[cur] || "");
    g("pcShape").textContent = SHAPES[shape].n;
    g("pcHint").textContent = img ? ("Tap on the picture of  " + (words[cur] || "") + "  then press Use  (" + (cur + 1) + "/" + words.length + ")") : "Step 1: choose a photo of the book page";
    drawSel();
  }
  function nextFree(from){
    for (var k = 1; k <= words.length; k++){ var i = (from + k) % words.length; if (!results[i]) return i; }
    return Math.min(words.length - 1, from + 1);
  }
  function finish(){
    ov.style.display = "none"; document.body.style.overflow = "";
    var f = cb; cb = null; img = null;
    if (f) f(results);
  }
  function setZoom(z){
    zoom = Math.min(5, Math.max(1, z));
    var r = g("pcImg"), wrap = g("pcWrap");
    r.style.width = (wrap.clientWidth * zoom) + "px";
    setTimeout(drawSel, 30);
  }
  function loadFile(f){
    var rd = new FileReader();
    rd.onload = function(e){
      var im = new Image();
      im.onload = function(){
        img = im; natW = im.naturalWidth || im.width; natH = im.naturalHeight || im.height;
        g("pcImg").src = e.target.result;
        g("pcStart").style.display = "none"; g("pcWrap").style.display = "block"; g("pcBar").style.display = "flex";
        cx = 0.5; cy = 0.5; zoom = 1; setZoom(1); refresh();
      };
      im.src = e.target.result;
    };
    rd.readAsDataURL(f);
  }
  function cropNow(){
    var d = boxDims();
    var sw = d.w * natW, sh = d.h * natH, sx = (cx - d.w / 2) * natW, sy = (cy - d.h / 2) * natH;
    var k = Math.min(1, 480 / Math.max(sw, sh));
    var c = document.createElement("canvas"); c.width = Math.max(1, Math.round(sw * k)); c.height = Math.max(1, Math.round(sh * k));
    c.getContext("2d").drawImage(img, sx, sy, sw, sh, 0, 0, c.width, c.height);
    return c.toDataURL("image/jpeg", 0.72);
  }
  function nudge(dx, dy){ var d = boxDims(); cx += dx * d.w * 0.12; cy += dy * d.h * 0.12; drawSel(); }

  function init(){
    ov = g("pcOv");
    g("pcClose").onclick = finish;
    g("pcDone").onclick = finish;
    g("pcPick").onclick = function(){
      var inp = document.createElement("input"); inp.type = "file"; inp.accept = "image/*"; inp.style.display = "none";
      inp.onchange = function(){ if (inp.files[0]) loadFile(inp.files[0]); document.body.removeChild(inp); };
      document.body.appendChild(inp); inp.click();
    };
    g("pcBox").onclick = function(e){
      if (!img) return;
      var r = g("pcImg").getBoundingClientRect();
      cx = (e.clientX - r.left) / r.width; cy = (e.clientY - r.top) / r.height; drawSel();
    };
    g("pcL").onclick = function(){ nudge(-1, 0); }; g("pcR").onclick = function(){ nudge(1, 0); };
    g("pcU").onclick = function(){ nudge(0, -1); }; g("pcD").onclick = function(){ nudge(0, 1); };
    g("pcPlus").onclick = function(){ size = Math.min(1, size * 1.12); drawSel(); };
    g("pcMinus").onclick = function(){ size = Math.max(0.03, size / 1.12); drawSel(); };
    g("pcShape").onclick = function(){ shape = (shape + 1) % SHAPES.length; refresh(); };
    g("pcZp").onclick = function(){ setZoom(zoom * 1.4); };
    g("pcZm").onclick = function(){ setZoom(zoom / 1.4); };
    g("pcSkip").onclick = function(){ cur = nextFree(cur); refresh(); };
    g("pcUse").onclick = function(){
      if (!img || !words.length) return;
      results[cur] = cropNow();
      var done = results.filter(function(x){ return !!x; }).length;
      if (done >= words.length){ finish(); return; }
      cur = nextFree(cur); refresh();
    };
    window.addEventListener("resize", function(){ if (img) setZoom(zoom); });
  }
  window.openPageCrop = function(wordList, done){
    if (!ov) init();
    words = wordList.slice(); results = words.map(function(){ return null; }); cur = 0; cb = done; img = null;
    g("pcStart").style.display = "block"; g("pcWrap").style.display = "none"; g("pcBar").style.display = "none";
    ov.style.display = "flex"; document.body.style.overflow = "hidden";
    refresh();
  };
})();
</script>
''';

  static const String _offlinePageHtml = r'''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Offline Maker</title>
<style>
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:linear-gradient(180deg,#8fd0f5,#d6efff 70%,#e9f7ff);min-height:100vh;color:#0f172a;padding-bottom:70px}
header{background:#3f6fbf;color:#fff;padding:14px 12px;display:flex;align-items:center;gap:8px;position:sticky;top:0;z-index:10}
header a{color:#fff;text-decoration:none;font-size:28px;width:36px;text-align:center}
header h1{flex:1;margin:0;font-size:21px;font-weight:600;text-align:center}
#dot{width:16px;height:16px;border-radius:50%;background:#ef4444;margin-right:8px}
#dot.on{background:#22c55e}
main{max-width:760px;margin:0 auto;padding:14px}
.box{background:#fff;border-radius:16px;padding:14px;margin-bottom:12px;box-shadow:0 3px 0 rgba(30,64,200,.25)}
.hide{display:none}
.tabs{display:flex;gap:8px;margin-bottom:12px}
.tabs button{flex:1;padding:12px 4px;border:0;border-radius:12px;font-weight:700;font-size:15px;background:#94a3b8;color:#fff}
.tabs button.sel{background:#1d4ed8}
input,textarea{width:100%;padding:12px;border-radius:10px;border:2px solid #3b82f6;font-size:16px;margin-bottom:8px;background:#fff;color:#0f172a}
textarea{min-height:120px;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:14px}
button.b{border:0;border-radius:12px;color:#fff;font-weight:700;font-size:16px;padding:13px;width:100%;margin-top:6px;background:#3b82f6}
.green{background:#10b981!important}.red{background:#ef4444!important}.gray{background:#64748b!important}
.row{display:flex;align-items:center;gap:10px;background:#f1f7ff;border-radius:12px;padding:8px;margin-top:8px}
.grow{flex:1;min-width:0;overflow-wrap:anywhere}
.thumb{width:48px;height:48px;border-radius:10px;object-fit:cover;background:#cbd5e1;flex:none;display:flex;align-items:center;justify-content:center;font-size:22px}
.mini{border:0;border-radius:10px;background:#fde047;font-size:18px;width:40px;height:40px;flex:none}
.muted{color:#64748b;font-size:13px;margin:4px 0}
.err{color:#b91c1c;font-size:13px}
#toast{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);background:#0f172a;color:#fff;padding:12px 18px;border-radius:24px;font-size:15px;display:none;z-index:60;max-width:90%}
a.dl{display:block;text-align:center;background:#7c3aed;color:#fff;text-decoration:none;font-weight:700;border-radius:12px;padding:13px;margin-top:6px}
</style>
</head>
<body>
<header><a href="/">&#8249;</a><h1>Offline Maker</h1><div id="dot"></div></header>
<main>
  <div class="box">
    <b id="status">Checking the TV...</b>
    <p class="muted">Add words, photos and quizzes any time. If the TV is not reachable they are saved on this phone and sent automatically when you are connected again.</p>
    <div id="addrBox" class="hide">
      <input id="addr" type="text" placeholder="TV address, e.g. 192.168.1.5:8080">
      <button class="b gray" id="addrBtn">Save TV address</button>
      <p class="muted">The address is shown under the QR code on the TV.</p>
    </div>
    <div id="saveBox" class="hide">
      <a class="dl" href="/offline.html" download="KidsLearning_Offline.html">Save this page on my phone (works without the TV)</a>
      <p class="muted">Open the saved file later with Chrome (Downloads). It keeps your work on the phone and sends it to the TV when you are on the same Wi-Fi.</p>
    </div>
    <p class="err hide" id="noStore">This browser blocks saving for this page. Open the page from the TV address instead.</p>
  </div>

  <div class="tabs">
    <button id="tWords" class="sel">Words</button>
    <button id="tQuiz">Quizzes</button>
    <button id="tWait">Waiting (<span id="cnt">0</span>)</button>
  </div>

  <section id="sWords">
    <div class="box">
      <b>1. Category</b>
      <input id="cat" type="text" placeholder="e.g. FRUITS" value="MIXED">
      <b>2. Words (comma or new line)</b>
      <textarea id="wordsText" placeholder="APPLE, BANANA, MANGO" style="text-transform:uppercase;font-family:inherit;font-size:16px"></textarea>
      <button class="b" id="addDrafts">Add to list</button>
    </div>
    <div class="box">
      <b>3. Words to save (<span id="dcnt">0</span>)</b>
      <button class="b" id="pageCropBtn">&#128214; Crop pictures from a book page</button>
      <div id="drafts"></div>
      <button class="b green" id="saveWords">Save (send to TV when connected)</button>
    </div>
  </section>

  <section id="sQuiz" class="hide">
    <div class="box">
      <b>Quiz JSON</b>
      <p class="muted">Paste the quiz or choose a .json file.</p>
      <input type="file" id="qfile" accept=".json,.txt,application/json,text/plain">
      <textarea id="qtext" placeholder='{ "title": "My quiz", "questions": [ ... ] }'></textarea>
      <button class="b green" id="saveQuiz">Save quiz (send to TV when connected)</button>
    </div>
  </section>

  <section id="sWait" class="hide">
    <div class="box">
      <b>Saved on this phone, not yet on the TV</b>
      <div id="wlist"></div>
      <button class="b" id="syncBtn">Send to the TV now</button>
      <button class="b gray" id="checkBtn">Check connection</button>
      <button class="b gray" id="expBtn">Save a backup file on this phone</button>
      <button class="b gray" id="impBtn">Open a backup file</button>
    </div>
  </section>
</main>
<div id="toast"></div>
<script>
var TV_BASE = "__TV_BASE__";
var KEY = "kls_pending";
var KEYBASE = "kls_base";
var pending = [];
var drafts = [];
var online = false;
var syncing = false;
var storageOk = true;

function $(id){ return document.getElementById(id); }
function clean(s){ return (s || "").trim().toUpperCase(); }
function uid(){ return "p" + Date.now() + "_" + Math.floor(Math.random() * 100000); }
function toast(msg){
  var t = $("toast"); t.textContent = msg; t.style.display = "block";
  clearTimeout(toast.timer); toast.timer = setTimeout(function(){ t.style.display = "none"; }, 2600);
}
function isLive(){ return TV_BASE === "" && location.protocol.indexOf("http") === 0; }

function load(){
  try { localStorage.setItem("kls_test", "1"); localStorage.removeItem("kls_test"); } catch(e){ storageOk = false; }
  try { pending = JSON.parse(localStorage.getItem(KEY) || "[]"); } catch(e){ pending = []; }
  if (!Array.isArray(pending)) pending = [];
}
function store(){
  try { localStorage.setItem(KEY, JSON.stringify(pending)); return true; }
  catch(e){ alert("There is no space left to save more on this phone page. Send the waiting items to the TV first."); return false; }
}
function base(){
  if (isLive()) return "";
  var b = "";
  try { b = localStorage.getItem(KEYBASE) || ""; } catch(e){}
  if (!b) b = TV_BASE;
  b = (b || "").trim();
  if (b && !/^https?:\/\//i.test(b)) b = "http://" + b;
  return b.replace(/\/+$/, "");
}

/* ------------------------------------------------------------ connection */
async function ping(){
  var b = base();
  if (!isLive() && !b) return false;
  var ctl = new AbortController();
  var t = setTimeout(function(){ ctl.abort(); }, 2500);
  try {
    var r = await fetch(b + "/api/ping?t=" + Date.now(), {signal: ctl.signal, cache: "no-store"});
    clearTimeout(t);
    return r.ok;
  } catch(e){ clearTimeout(t); return false; }
}
async function check(){ setOnline(await ping()); }
function setOnline(v){
  online = v;
  render();
  if (v && pending.length && !syncing) syncNow();
}

/* ----------------------------------------------------------------- sync */
async function syncNow(){
  if (syncing || !pending.length) return;
  syncing = true;
  render();
  try {
    var b = base();
    var i = 0;
    while (i < pending.length) {
      var it = pending[i];
      if (it.fatal) { i++; continue; }
      var url = it.type === "words" ? "/api/upload-batch" : "/api/quiz/import";
      var body = it.type === "words" ? it.items : {text: it.text};
      var r;
      try {
        r = await fetch(b + url, {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(body)});
      } catch(e){ online = false; break; }
      if (r.ok) { pending.splice(i, 1); store(); continue; }
      var msg = "";
      try { var d = await r.json(); msg = d.error || ""; } catch(e2){}
      it.error = msg || ("The TV answered with error " + r.status);
      it.fatal = (r.status === 400);
      store();
      i++;
    }
  } finally {
    syncing = false;
    render();
  }
  if (!pending.length) toast("All sent to the TV");
}

/* ---------------------------------------------------------------- words */
function squareFromDataUrl(src, cb){
  var img = new Image();
  img.onload = function(){
    var side = Math.min(img.width, img.height);
    var c = document.createElement("canvas");
    c.width = 360; c.height = 360;
    c.getContext("2d").drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, 360, 360);
    cb(c.toDataURL("image/jpeg", 0.65));
  };
  img.src = src;
}
function pickPhoto(i){
  var inp = document.createElement("input");
  inp.type = "file"; inp.accept = "image/*"; inp.style.display = "none";
  inp.onchange = function(){
    var f = inp.files[0];
    if (f){
      var rd = new FileReader();
      rd.onload = function(e){ squareFromDataUrl(e.target.result, function(d){ drafts[i].image = d; render(); }); };
      rd.readAsDataURL(f);
    }
    document.body.removeChild(inp);
  };
  document.body.appendChild(inp);
  inp.click();
}
$("addDrafts").onclick = function(){
  var parts = $("wordsText").value.split(/[,\n]/).map(clean).filter(function(w){ return w.length > 0; });
  if (!parts.length){ toast("Type some words first"); return; }
  parts.forEach(function(w){ drafts.push({word: w, image: null}); });
  $("wordsText").value = "";
  render();
};
$("pageCropBtn").onclick = function(){
  if (!drafts.length){ toast("Add the words to the list first"); return; }
  openPageCrop(drafts.map(function(d){ return d.word; }), function(res){
    var n = 0;
    res.forEach(function(u, i){ if (u){ drafts[i].image = u; n++; } });
    render();
    if (n) toast(n + " pictures added");
  });
};
$("saveWords").onclick = function(){
  if (!drafts.length){ toast("Add some words first"); return; }
  var topic = clean($("cat").value) || "MIXED";
  var items = drafts.map(function(d){ return {word: d.word, image_base64: d.image, topic: topic}; });
  pending.push({id: uid(), type: "words", topic: topic, items: items});
  if (!store()){ pending.pop(); return; }
  drafts = [];
  toast(online ? "Saved - sending to the TV..." : "Saved on this phone - will be sent later");
  render();
  if (online) syncNow();
};

/* --------------------------------------------------------------- quizzes */
$("qfile").onchange = function(){
  var f = $("qfile").files[0];
  if (!f) return;
  var rd = new FileReader();
  rd.onload = function(){ $("qtext").value = rd.result; toast("File loaded - press the green button"); };
  rd.readAsText(f, "utf-8");
};
$("saveQuiz").onclick = function(){
  var text = $("qtext").value.trim();
  if (!text){ toast("Paste the quiz JSON first"); return; }
  var probe = text.replace(/^```[a-zA-Z]*\s*/, "").replace(/```\s*$/, "");
  var title = "Quiz";
  var count = 0;
  try {
    var data = JSON.parse(probe);
    if (Array.isArray(data)) count = data.length;
    else if (data && typeof data === "object") {
      title = data.title || data.name || "Quiz";
      if (Array.isArray(data.questions)) count = data.questions.length;
      else if (Array.isArray(data.quizzes)) { title = data.quizzes.length + " quizzes"; count = 0; }
    }
  } catch(e){
    toast("This is not valid JSON - please check it");
    return;
  }
  pending.push({id: uid(), type: "quiz", text: text, title: title, count: count});
  if (!store()){ pending.pop(); return; }
  $("qtext").value = "";
  toast(online ? "Saved - sending to the TV..." : "Saved on this phone - will be sent later");
  render();
  if (online) syncNow();
};

/* ------------------------------------------------------ backup file (works even if the browser blocks saving) */
$("expBtn").onclick = function(){
  if (!pending.length){ toast("Nothing is waiting"); return; }
  var blob = new Blob([JSON.stringify({kls: 1, pending: pending})], {type: "application/json"});
  var a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "KidsLearning_waiting_" + Date.now() + ".json";
  document.body.appendChild(a); a.click();
  setTimeout(function(){ document.body.removeChild(a); URL.revokeObjectURL(a.href); }, 800);
  toast("Backup file saved in Downloads");
};
$("impBtn").onclick = function(){
  var inp = document.createElement("input");
  inp.type = "file"; inp.accept = ".json,application/json"; inp.style.display = "none";
  inp.onchange = function(){
    var f = inp.files[0];
    if (f){
      var rd = new FileReader();
      rd.onload = function(){
        try {
          var d = JSON.parse(rd.result);
          var list = d && Array.isArray(d.pending) ? d.pending : [];
          var n = 0;
          list.forEach(function(it){
            if (it && (it.type === "words" || it.type === "quiz")){ it.id = uid(); delete it.error; delete it.fatal; pending.push(it); n++; }
          });
          store(); render();
          toast(n + " item(s) loaded from the backup file");
          if (online) syncNow();
        } catch(e){ toast("This is not a backup file"); }
      };
      rd.readAsText(f, "utf-8");
    }
    document.body.removeChild(inp);
  };
  document.body.appendChild(inp); inp.click();
};

/* --------------------------------------------------------------- render */
function renderDrafts(){
  $("dcnt").textContent = drafts.length;
  var box = $("drafts"); box.innerHTML = "";
  drafts.forEach(function(d, i){
    var row = document.createElement("div"); row.className = "row";
    var th;
    if (d.image){ th = document.createElement("img"); th.className = "thumb"; th.src = d.image; }
    else { th = document.createElement("div"); th.className = "thumb"; th.textContent = "\uD83D\uDDBC"; }
    var nm = document.createElement("div"); nm.className = "grow"; var bb = document.createElement("b"); bb.textContent = d.word; nm.appendChild(bb);
    var ph = document.createElement("button"); ph.className = "mini"; ph.textContent = "\uD83D\uDCF7"; ph.onclick = function(){ pickPhoto(i); };
    var rm = document.createElement("button"); rm.className = "mini"; rm.textContent = "\u2716"; rm.onclick = function(){ drafts.splice(i, 1); render(); };
    row.appendChild(th); row.appendChild(nm); row.appendChild(ph); row.appendChild(rm);
    box.appendChild(row);
  });
}
function renderWait(){
  var box = $("wlist"); box.innerHTML = "";
  if (!pending.length){
    var p = document.createElement("p"); p.className = "muted"; p.textContent = "Nothing is waiting. Everything is on the TV."; box.appendChild(p);
  }
  pending.forEach(function(it, i){
    var row = document.createElement("div"); row.className = "row";
    var th = document.createElement("div"); th.className = "thumb"; th.textContent = it.type === "words" ? "\uD83D\uDCDD" : "\uD83E\uDDE0";
    var info = document.createElement("div"); info.className = "grow";
    var b = document.createElement("b");
    b.textContent = it.type === "words" ? (it.items.length + " word(s) in " + it.topic) : ("Quiz: " + it.title + (it.count ? " (" + it.count + " questions)" : ""));
    var st = document.createElement("div");
    if (it.error){ st.className = "err"; st.textContent = "\u26A0 " + it.error; }
    else { st.className = "muted"; st.textContent = syncing ? "Sending..." : (online ? "Ready to send" : "Waiting for the TV"); }
    info.appendChild(b); info.appendChild(st);
    var del = document.createElement("button"); del.className = "mini"; del.textContent = "\uD83D\uDDD1";
    del.onclick = function(){ if (confirm("Delete this waiting item?")){ pending.splice(i, 1); store(); render(); } };
    row.appendChild(th); row.appendChild(info); row.appendChild(del);
    box.appendChild(row);
  });
}
function render(){
  $("cnt").textContent = pending.length;
  $("dot").className = online ? "on" : "";
  $("status").textContent = online ? "\uD83D\uDFE2 Connected to the TV" : "\uD83D\uDD34 Not connected to the TV - saving on this phone";
  $("addrBox").className = isLive() ? "hide" : "";
  $("saveBox").className = isLive() ? "" : "hide";
  $("noStore").className = storageOk ? "err hide" : "err";
  renderDrafts();
  renderWait();
}

/* ----------------------------------------------------------------- tabs */
function showTab(t){
  $("sWords").className = t === "w" ? "" : "hide";
  $("sQuiz").className = t === "q" ? "" : "hide";
  $("sWait").className = t === "x" ? "" : "hide";
  $("tWords").className = t === "w" ? "sel" : "";
  $("tQuiz").className = t === "q" ? "sel" : "";
  $("tWait").className = t === "x" ? "sel" : "";
}
$("tWords").onclick = function(){ showTab("w"); };
$("tQuiz").onclick = function(){ showTab("q"); };
$("tWait").onclick = function(){ showTab("x"); };
$("syncBtn").onclick = function(){ if (!online) toast("The TV is not reachable yet"); else syncNow(); };
$("checkBtn").onclick = function(){ check(); toast("Checking..."); };
$("addrBtn").onclick = function(){
  try { localStorage.setItem(KEYBASE, $("addr").value.trim()); } catch(e){}
  toast("TV address saved");
  check();
};

load();
try { $("addr").value = localStorage.getItem(KEYBASE) || TV_BASE; } catch(e){ $("addr").value = TV_BASE; }
render();
check();
setInterval(check, 5000);
window.addEventListener("online", check);
</script>
</body>
</html>
''';

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
      <div class="mrow" onclick="location.href='/offline'"><span>Offline mode - save on phone, send later</span><i class="play">&#9654;</i></div>
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
      <button id="pageCropBtn" class="blue full" style="margin-bottom:10px;">&#128214; Crop pictures from a book page</button>
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
    el("pageCropBtn").addEventListener("click", () => {
      if (!queue.length) { toast("Type the words first and press Create Drafts", true); return; }
      openPageCrop(queue.map(q => q.word), results => {
        let n = 0;
        results.forEach((u, i) => { if (u) { queue[i].image_base64 = u; n++; } });
        renderQueue();
        if (n) toast(n + " pictures added");
      });
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
