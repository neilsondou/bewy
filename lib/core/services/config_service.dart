import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Persistent JSON config stored at %APPDATA%/bewy/config.json.
class ConfigService {
  static final String configDir =
      '${Platform.environment['APPDATA']}${Platform.pathSeparator}bewy';
  static final String configFile =
      '$configDir${Platform.pathSeparator}config.json';
  static final StreamController<void> _changeController =
      StreamController<void>.broadcast(
        onListen: _ensureWatching,
        onCancel: _maybeStopWatching,
      );
  static StreamSubscription<FileSystemEvent>? _watchSub;

  static Stream<void> watchChanges() {
    return _changeController.stream;
  }

  static Future<Map<String, dynamic>> load() async {
    try {
      final file = File(configFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<void> save(Map<String, dynamic> data) async {
    try {
      final dir = Directory(configDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(configFile);
      await file.writeAsString(json.encode(data));
      _emitChange();
    } catch (_) {}
  }

  static void _ensureWatching() {
    if (_watchSub != null) return;
    try {
      final dir = Directory(configDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _watchSub = dir.watch().listen((event) {
        if (_isConfigPath(event.path)) {
          _emitChange();
        }
      });
    } catch (_) {}
  }

  static void _maybeStopWatching() {
    if (_changeController.hasListener) return;
    _watchSub?.cancel();
    _watchSub = null;
  }

  static bool _isConfigPath(String path) {
    final normalizedPath = path.replaceAll('/', Platform.pathSeparator);
    final normalizedConfig = configFile.replaceAll('/', Platform.pathSeparator);
    if (Platform.isWindows) {
      return normalizedPath.toLowerCase() == normalizedConfig.toLowerCase();
    }
    return normalizedPath == normalizedConfig;
  }

  static void _emitChange() {
    if (_changeController.isClosed) return;
    _changeController.add(null);
  }
}
