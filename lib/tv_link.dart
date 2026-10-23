import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'doc_store.dart';
import 'sync_server.dart';

/// Phone side of "Send to TV". The TV runs a small receiver on port [tvPort] whenever the app is open
/// on its home screen. The phone finds it on the same Wi-Fi and sends content straight to it.
class TvLink {
  TvLink._();

  static const int tvPort = 8765;
  static const String _kvKey = 'tv_last_ip';

  // ------------------------------------------------------------ TV side
  static TVSyncServer? _receiver;

  /// Starts the receiver on the TV (safe to call many times).
  static Future<void> startReceiver(void Function() onChanged) async {
    if (_receiver != null) return;
    final r = TVSyncServer(onChanged: onChanged, port: tvPort);
    _receiver = r;
    final p = await r.startServer();
    if (p == null) _receiver = null;
  }

  // ---------------------------------------------------------- phone side
  static Future<bool> _isTv(String ip) async {
    final c = HttpClient()..connectionTimeout = const Duration(milliseconds: 900);
    try {
      final req = await c.getUrl(Uri.parse('http://$ip:$tvPort/api/ping'));
      final res = await req.close().timeout(const Duration(milliseconds: 1500));
      final body = await res.transform(utf8.decoder).join();
      return res.statusCode == 200 && body.contains('gyantara');
    } catch (_) {
      return false;
    } finally {
      c.close(force: true);
    }
  }

  static Future<List<String>> _myPrefixes() async {
    final out = <String>[];
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false)) {
        for (final a in i.addresses) {
          final parts = a.address.split('.');
          if (parts.length == 4) out.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
    } catch (_) {}
    return out;
  }

  /// Returns the TV address like "192.168.1.20", or null when no TV with the app open was found.
  static Future<String?> find() async {
    final kv = await AppKV.open();
    final last = kv.getString(_kvKey) ?? '';
    if (last.isNotEmpty && await _isTv(last)) return last;
    for (final prefix in await _myPrefixes()) {
      String? found;
      for (var start = 1; start < 255 && found == null; start += 40) {
        final batch = <Future<void>>[];
        for (var n = start; n < start + 40 && n < 255; n++) {
          final ip = '$prefix.$n';
          batch.add(() async {
            if (found == null && await _isTv(ip)) found = ip;
          }());
        }
        await Future.wait(batch);
      }
      if (found != null) {
        await kv.setString(_kvKey, found!);
        return found;
      }
    }
    return null;
  }

  /// POSTs JSON to the TV. Returns null when it worked, otherwise a short message.
  static Future<String?> post(String ip, String path, Object body) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await c.postUrl(Uri.parse('http://$ip:$tvPort$path'));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(json.encode(body)));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode == 200) return null;
      try {
        final d = json.decode(text);
        if (d is Map && d['error'] != null) return d['error'].toString();
      } catch (_) {}
      return 'The TV answered with error ${res.statusCode}.';
    } catch (e) {
      return 'Could not reach the TV.';
    } finally {
      c.close(force: true);
    }
  }
}
