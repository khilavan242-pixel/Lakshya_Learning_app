import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// ======================================================================
// WHERE THE APP SAVES ITS DATA
//   default : <Internal storage>/Documents/KidsSuperApp   (when the TV allows it), otherwise
//             the app's own Documents folder on internal storage (needs no permission)
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
  static bool isFallback = false; // the wanted place is not writable -> using another place
  static String tier = 'wanted'; // wanted | appdocs | private
  static bool readBlocked = false; // the folder has old data but Android does not let this app open it
  static String statusNote = '';
  static Directory? _root;

  static String get activePath => _root?.path ?? '';

  static String get shortLabel {
    if (isFallback) return tier == 'appdocs' ? 'App Documents' : '⚠ App folder';
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

  /// The app's own "Documents" folder on the first external volume (no permission needed).
  static Future<String> _appExternalDocuments() async {
    try {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
      if (dirs != null && dirs.isNotEmpty) return dirs.first.path;
    } catch (_) {}
    return '';
  }

  /// 'ok' = readable, 'none' = nothing saved there yet, 'blocked' = exists but this app may not open it
  /// (typical after reinstalling: Android removes the permission and the old files become unreadable).
  static Future<String> readState(String root) async {
    try {
      await File('$root/data/app_kv.json').readAsString();
      return 'ok';
    } on FileSystemException catch (e) {
      final code = e.osError?.errorCode ?? 0;
      return code == 2 ? 'none' : 'blocked';
    } catch (_) {
      return 'blocked';
    }
  }

  static Future<void> _resolve() async {
    final priv = await _privateRoot();
    var target = priv;
    tier = 'private';
    if (mode != 'private') {
      final want = _wantedPath();
      readBlocked = false;
      var usable = await canWrite(want);
      if (usable && await readState(want) == 'blocked') {
        usable = false; // old data is there but unreadable: never write over it
        readBlocked = true;
      }
      if (usable) {
        target = want;
        tier = 'wanted';
      } else if (mode == 'documents') {
        final alt = await _appExternalDocuments();
        if (alt.isNotEmpty && await canWrite('$alt/$appFolderName')) {
          target = '$alt/$appFolderName';
          tier = 'appdocs';
        }
      }
    }
    isFallback = mode != 'private' && tier != 'wanted';
    if (!isFallback) {
      statusNote = '';
    } else if (readBlocked) {
      statusNote = 'Your old data is still safe in ${_wantedPath()}, but Android does not let this newly installed app open it. Allow "Files and media" / "All files access" for the app in TV Settings > Apps, then open the app again.';
    } else if (tier == 'appdocs') {
      statusNote = 'The shared Documents folder needs storage permission. Saving in this app\'s own Documents folder on the TV for now: $target';
    } else {
      statusNote = 'Cannot write to ${_wantedPath()}. Using the hidden app folder for now. Choose a folder or a USB drive below.';
    }
    if (tier != 'private' || mode == 'private') {
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
  /// A short report for the Storage screen.
  static Future<String> diagnose() async {
    final shared = '$sharedDocuments/$appFolderName';
    if (!Platform.isAndroid) return 'Saving in: $activePath';
    final w = await canWrite(shared);
    final r = await readState(shared);
    final write = w ? 'yes' : 'NO';
    final read = r == 'ok' ? 'yes (old data found)' : (r == 'none' ? 'nothing saved there yet' : 'NO (old data is blocked)');
    return 'Documents folder: can write: $write  |  can read: $read';
  }

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
  /// True when the shared Documents folder can be written right now.
  /// (Android only shows a permission screen from the TV's own Settings.)
  static Future<bool> hasAccess() async {
    if (!Platform.isAndroid) return true;
    return canWrite('$sharedDocuments/$appFolderName');
  }

  static Future<bool> requestAccess() => hasAccess();

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
