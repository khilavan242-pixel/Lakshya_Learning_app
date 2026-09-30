import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'kids_ui.dart';
import 'sync_server.dart';

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

/// Opens the phone-manager server and shows a QR code.
/// path = '' opens the main menu, '/quiz' opens the quiz page directly.
Future<void> showPhoneManager(BuildContext context, {VoidCallback? onChanged, String path = ''}) async {
  final server = TVSyncServer(onChanged: () {
    if (onChanged != null) onChanged();
  });
  final port = await server.startServer();
  final ip = await _findLocalIp();

  if (!context.mounted) {
    await server.stopServer();
    return;
  }

  final url = (port != null && ip != null) ? 'http://$ip:$port$path' : null;
  final s = uiScale(context);

  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1B4B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('📱 Scan with your phone', style: kidText(26 * s)),
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
                    ? 'Connect your phone to the same Wi-Fi.\nOpen: $url\n\nManage spelling words, quizzes (paste or upload JSON), pronunciation and reports from your phone.'
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
}
