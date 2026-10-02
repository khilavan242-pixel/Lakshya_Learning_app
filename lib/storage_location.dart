import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ======================================================================
// WHERE THE APP SAVES ITS DATA
//   default : <Internal storage>/Documents/KidsSuperApp   (visible in the TV file manager)
//   custom  : any folder on internal storage, SD card or USB drive
//   private : the app's own hidden folder (needs no permission, used as a safe fallback)
// The choice is remembered in a small file inside the app's private folder.
// When the location changes, all data (words, photos, quizzes, players, progress)
// is copied to the new place. The app must then be reopened.
// ======================================================================

class DriveInfo {
  final String label;
  final String path; // root of the drive, e.g. /storage/emulated/0 or /storage/ABCD-1234
  final String appPath; // app-specific folder on that drive (works without any permission)
  const DriveInfo(this.label, this.path, this.appPath);
}

class StorageLocation {
  StorageLocation._();

  static const String appFolderName = 'KidsSuperApp';
  static const String sharedDocuments = '/storage/emulated/0/Documents';

  static String mode = 'documents'; // documents | custom | private
  static String customBase = ''; // folder chosen by the user; data goes in <customBase>/KidsSuperApp
  static String lastRoot = ''; // where the data was last known to be
  static bool isFallback = false; // wanted place is not writable -> using the private folder
  static String statusNote = '';
  static Directory? _root;

  static String get activePath => _root?.path ?? '';

  static String get shortLabel {
    if (isFallback) return '⚠ App folder';
    if (mode == 'documents') return 'Documents';
    if (mode == 'custom') {
      final parts = customBase.split('/').where((String p) => p.isNotEmpty).toList();
      return parts.isEmpty ? customBase : parts.last;
    }
    return 'App folder';
  }

  static Future<File> _configFile() async {
    final d = await getApplicationSupportDirectory(); // always private + writable
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}/storage_config.json');
  }

  static Future<String> _privateRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$appFolderName';
  }

  static Future<String> _legacyPhotos() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/custom_cards';
  }

  static String _wantedPath() {
    if (mode == 'custom' && customBase.isNotEmpty) return '$customBase/$appFolderName';
    return '$sharedDocuments/$appFolderName';
  }

  static Future<void> _saveConfig() async {
    try {
      final f = await _configFile();
      await f.writeAsString(
        json.encode(<String, dynamic>{'mode': mode, 'customBase': customBase, 'lastRoot': lastRoot}),
        flush: true,
      );
    } catch (_) {}
  }

  /// Call once at start-up, before anything else touches the storage.
  static Future<void> init() async {
    var firstRun = true;
    try {
      final f = await _configFile();
      if (await f.exists()) {
        final m = json.decode(await f.readAsString());
        if (m is Map) {
          mode = (m['mode'] ?? 'documents').toString();
          customBase = (m['customBase'] ?? '').toString();
          lastRoot = (m['lastRoot'] ?? '').toString();
          firstRun = false;
        }
      }
    } catch (_) {}
    if (firstRun) {
      // first start of this version: Documents is the default; remember where the old data is
      mode = Platform.isAndroid ? 'documents' : 'private';
      final priv = await _privateRoot();
      if (await File('$priv/data/app_kv.json').exists()) lastRoot = priv;
    }
    await _resolve();
  }

  static Future<Directory> rootDir() async {
    final r = _root;
    if (r != null) return r;
    await init();
    return _root!;
  }

  static Future<bool> canWrite(String path) async {
    try {
      final d = Directory(path);
      if (!await d.exists()) await d.create(recursive: true);
      final f = File('${d.path}/.write_test');
      await f.writeAsString('ok', flush: true);
      await f.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _resolve() async {
    final priv = await _privateRoot();
    var target = priv;
    isFallback = false;
    statusNote = '';
    if (mode != 'private') {
      final want = _wantedPath();
      if (await canWrite(want)) {
        target = want;
      } else {
        isFallback = true;
        statusNote = 'Cannot write to $want yet. Using the app folder for now. Allow storage access or choose another folder.';
      }
    }
    if (!isFallback) {
      if (lastRoot.isNotEmpty && lastRoot != target) await _migrate(lastRoot, target);
      lastRoot = target;
    }
    await _saveConfig();
    final d = Directory(target);
    if (!await d.exists()) await d.create(recursive: true);
    _root = d;
  }

  // ------------------------------------------------------------ copying data
  static Future<void> _copyDir(Directory src, Directory dst) async {
    if (!await dst.exists()) await dst.create(recursive: true);
    await for (final e in src.list(followLinks: false)) {
      final name = e.path.split('/').last;
      if (name.endsWith('.tmp') || name == '.write_test') continue;
      if (e is File) {
        final target = File('${dst.path}/$name');
        if (!await target.exists()) await e.copy(target.path);
      } else if (e is Directory) {
        await _copyDir(e, Directory('${dst.path}/$name'));
      }
    }
  }

  /// Copies everything from the old place to the new one. If the new place already
  /// holds app data (for example a backup on a USB drive) that data is used as it is.
  static Future<void> _migrate(String from, String to) async {
    try {
      if (to == from || to.startsWith('$from/')) return;
      if (await File('$to/data/app_kv.json').exists()) return;
      final src = Directory(from);
      if (await src.exists()) await _copyDir(src, Directory(to));
      final legacy = await _legacyPhotos();
      final legacyDir = Directory(legacy);
      if (await legacyDir.exists()) await _copyDir(legacyDir, Directory('$to/photos'));
      await _rewritePhotoPaths(to, <String>['$from/photos', legacy], '$to/photos');
    } catch (_) {}
  }

  /// Spelling cards remember their photo by full path, so the paths are updated too.
  static Future<void> _rewritePhotoPaths(String root, List<String> oldPrefixes, String newPrefix) async {
    final f = File('$root/data/app_kv.json');
    if (!await f.exists()) return;
    var text = await f.readAsString();
    for (final p in oldPrefixes) {
      if (p.isNotEmpty && p != newPrefix) text = text.replaceAll(p, newPrefix);
    }
    await f.writeAsString(text, flush: true);
  }

  // ------------------------------------------------------------- switching
  /// Returns null on success, or a message explaining what went wrong.
  /// The app has to be reopened afterwards so every screen reads the new place.
  static Future<String?> switchTo(String newMode, String base) async {
    final priv = await _privateRoot();
    String target;
    if (newMode == 'private') {
      target = priv;
    } else if (newMode == 'custom') {
      target = '$base/$appFolderName';
    } else {
      target = '$sharedDocuments/$appFolderName';
    }
    if (newMode != 'private' && !await canWrite(target)) {
      return 'Cannot write to $target. Allow storage access first, or choose another folder.';
    }
    final current = activePath;
    if (current.isNotEmpty && current != target) await _migrate(current, target);
    mode = newMode;
    customBase = newMode == 'custom' ? base : '';
    lastRoot = target;
    await _saveConfig();
    return null;
  }

  // ------------------------------------------------------------ permissions
  static Future<bool> hasAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      return await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      final a = await Permission.storage.request();
      if (a.isGranted) return true;
      final b = await Permission.manageExternalStorage.request();
      return b.isGranted;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------------------- drives
  static Future<List<DriveInfo>> drives() async {
    final out = <DriveInfo>[];
    if (!Platform.isAndroid) return out;
    final apps = <String, String>{};
    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs != null) {
        for (final d in dirs) {
          final i = d.path.indexOf('/Android/');
          if (i > 0) apps[d.path.substring(0, i)] = d.path;
        }
      }
    } catch (_) {}
    out.add(DriveInfo('Internal storage', '/storage/emulated/0', apps['/storage/emulated/0'] ?? ''));
    final roots = <String>{};
    try {
      await for (final e in Directory('/storage').list()) {
        final name = e.path.split('/').last;
        if (name == 'emulated' || name == 'self') continue;
        roots.add(e.path);
      }
    } catch (_) {}
    for (final r in apps.keys) {
      if (r != '/storage/emulated/0') roots.add(r);
    }
    for (final r in roots) {
      out.add(DriveInfo('USB drive / SD card (${r.split('/').last})', r, apps[r] ?? ''));
    }
    return out;
  }
}
