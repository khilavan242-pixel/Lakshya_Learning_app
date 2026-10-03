import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'kids_ui.dart';
import 'storage_location.dart';

// ======================================================================
// STORAGE SETTINGS: Documents (default) / internal / SD card / USB drive / any folder
// ======================================================================

Widget _infoRow(double s, String text) {
  return TVFocusable(
    onPressed: null,
    scale: 1.01,
    builder: (BuildContext context, bool focused) => Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: focused ? Colors.white : Colors.white24, width: focused ? 4 * s : 2 * s),
      ),
      child: Text(text, style: kidText(18 * s, w: FontWeight.w600)),
    ),
  );
}

Future<void> showRestartDialog(BuildContext context, String where) async {
  final s = uiScale(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1B4B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28 * s)),
      title: Text('✅ Storage changed', style: kidText(26 * s)),
      content: Text('All data was copied to:\n$where\n\nThe old copy was kept. Please close the app and open it again.', style: TextStyle(fontSize: 19 * s, color: Colors.white)),
      actions: [
        ActionButton(s: s, icon: Icons.power_settings_new_rounded, label: 'Close the app', color: const Color(0xFF22C55E), autofocus: true, onPressed: () => SystemNavigator.pop()),
      ],
    ),
  );
}

/// Kept only so an older home_screen.dart still compiles while files are uploaded one by one.
/// (Android cannot show a storage permission dialog without extra plugins, so this does nothing.)
Future<void> offerDocumentsFolder(BuildContext context) async {}

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});
  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  List<DriveInfo> _drives = <DriveInfo>[];
  bool _access = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final d = await StorageLocation.drives();
    final a = await StorageLocation.hasAccess();
    if (!mounted) return;
    setState(() {
      _drives = d;
      _access = a;
    });
  }

  Future<void> _restartDialog(String where) => showRestartDialog(context, where);

  Future<void> _switch(String where, String mode, String base) async {
    final ok = await askConfirm(context, 'Save all data in:\n$where\n\nWords, photos, quizzes and progress are copied there. The old copy stays where it was.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await StorageLocation.switchTo(mode, base);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showKidsSnack(context, err);
      return;
    }
    await _restartDialog(where);
  }

  Future<void> _allow() async {
    final ok = await StorageLocation.requestAccess();
    await _refresh();
    if (!mounted) return;
    if (ok) {
      if (StorageLocation.isFallback && StorageLocation.mode == 'documents') {
        await _switch('${StorageLocation.sharedDocuments}/${StorageLocation.appFolderName}', 'documents', '');
      } else {
        showKidsSnack(context, 'Storage access is working.');
      }
      return;
    }
    final s = uiScale(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28 * s)),
        title: Text('🔓 Allow storage access', style: kidText(26 * s)),
        content: Text(
          'Android only lets you do this in the TV\'s own Settings:\n\nSettings > Apps > this app > Permissions > allow "Files and media" / "All files access".\n\nThen come back here and press this button again.\n\nIf your TV has no such option, use an app folder on a USB drive or the internal storage below. They need no permission.',
          style: TextStyle(fontSize: 18 * s, color: Colors.white),
        ),
        actions: [
          ActionButton(s: s, icon: Icons.check_rounded, label: 'OK', color: const Color(0xFF22C55E), autofocus: true, onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  Future<void> _pickFolder(DriveInfo d) async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (_) => FolderPickerScreen(startPath: d.path)),
    );
    if (path == null || !mounted) return;
    await _switch('$path/${StorageLocation.appFolderName}', 'custom', path);
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final inDocs = StorageLocation.mode == 'documents' && !StorageLocation.isFallback;
    final rows = <Widget>[
      _infoRow(s, 'Saving in now:\n${StorageLocation.activePath}'),
      if (StorageLocation.isFallback) _infoRow(s, '⚠ ${StorageLocation.statusNote}'),
      SettingLinkRow(
        label: '📁 Documents folder (default)',
        value: inDocs ? '✅ in use' : null,
        s: s,
        autofocus: true,
        onPressed: () => _switch('${StorageLocation.sharedDocuments}/${StorageLocation.appFolderName}', 'documents', ''),
      ),
      if (!_access) SettingLinkRow(label: '🔓 Allow access to the shared Documents folder', s: s, onPressed: _allow),
      for (final d in _drives)
        SettingLinkRow(label: '📂 Choose a folder on ${d.label}', s: s, onPressed: () => _pickFolder(d)),
      for (final d in _drives)
        if (d.appPath.isNotEmpty)
          SettingLinkRow(
            label: '🔒 ${d.label} - app folder (no permission needed)',
            s: s,
            onPressed: () => _switch('${d.appPath}/${StorageLocation.appFolderName}', 'custom', d.appPath),
          ),
      SettingLinkRow(
        label: '🔒 App private folder (hidden)',
        value: StorageLocation.mode == 'private' ? '✅ in use' : null,
        s: s,
        onPressed: () => _switch('the app private folder', 'private', ''),
      ),
    ];
    return ScreenFrame(
      title: '💾 Storage location',
      body: _busy
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12 * s),
              Text('Copying data...', style: kidText(24 * s)),
            ]))
          : FocusList(s: s, items: rows),
    );
  }
}

/// Simple folder browser that works with the TV remote. Returns the chosen folder path.
class FolderPickerScreen extends StatefulWidget {
  final String startPath;
  const FolderPickerScreen({super.key, required this.startPath});
  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  String _path = '';
  List<String> _dirs = <String>[];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _path = widget.startPath;
    _load();
  }

  Future<void> _load() async {
    final out = <String>[];
    var err = '';
    try {
      await for (final e in Directory(_path).list(followLinks: false)) {
        if (e is Directory) {
          final name = e.path.split('/').last;
          if (!name.startsWith('.') && name != 'Android') out.add(name);
        }
      }
      out.sort();
    } catch (_) {
      err = 'No access to this folder. Allow storage access first, or go back.';
    }
    if (!mounted) return;
    setState(() {
      _dirs = out;
      _error = err;
    });
  }

  void _enter(String name) {
    setState(() => _path = '$_path/$name');
    _load();
  }

  void _up() {
    if (_path == '/storage' || _path == '/' || !_path.contains('/')) return;
    final i = _path.lastIndexOf('/');
    final parent = i <= 0 ? '/' : _path.substring(0, i);
    setState(() => _path = parent);
    _load();
  }

  Future<void> _newFolder() async {
    final n = await askText(context, 'New folder name', 'Type a name');
    if (n == null) return;
    try {
      await Directory('$_path/${n.replaceAll('/', '_')}').create();
    } catch (_) {
      if (mounted) showKidsSnack(context, 'Could not create the folder here.');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final rows = <Widget>[
      _infoRow(s, 'Folder: $_path\n(Data will be saved in a "${StorageLocation.appFolderName}" folder inside it)'),
      if (_path != '/storage')
        SettingLinkRow(label: '⬆  Up', s: s, autofocus: true, onPressed: _up),
      if (_error.isNotEmpty) _infoRow(s, '⚠ $_error'),
      for (final name in _dirs) SettingLinkRow(label: '📁  $name', s: s, onPressed: () => _enter(name)),
      if (_dirs.isEmpty && _error.isEmpty) _infoRow(s, 'No sub-folders here.'),
    ];
    return ScreenFrame(
      title: 'Choose a folder',
      actions: [
        ActionButton(s: s, icon: Icons.create_new_folder_rounded, label: 'New', color: const Color(0xFF3949AB), onPressed: _newFolder),
        SizedBox(width: 10 * s),
        ActionButton(s: s, icon: Icons.check_circle_rounded, label: 'Use this folder', color: const Color(0xFF22C55E), onPressed: () => Navigator.pop(context, _path)),
      ],
      body: FocusList(s: s, items: rows),
    );
  }
}
