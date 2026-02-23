import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config_service.dart';

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.scope,
    required this.message,
  });

  final DateTime timestamp;
  final String level;
  final String scope;
  final String message;

  String formatLine() {
    final iso = timestamp.toIso8601String();
    return '[$iso] [$level] [$scope] $message';
  }

  static AppLogEntry parseOrFallback(String line) {
    final regex = RegExp(r'^\[(.*?)\] \[(.*?)\] \[(.*?)\] (.*)$');
    final match = regex.firstMatch(line);
    if (match == null) {
      return AppLogEntry(
        timestamp: DateTime.now(),
        level: 'INFO',
        scope: 'runtime',
        message: line,
      );
    }
    return AppLogEntry(
      timestamp: DateTime.tryParse(match.group(1) ?? '') ?? DateTime.now(),
      level: match.group(2) ?? 'INFO',
      scope: match.group(3) ?? 'runtime',
      message: match.group(4) ?? '',
    );
  }
}

class AppLogService {
  AppLogService._();

  static final AppLogService instance = AppLogService._();

  final StreamController<AppLogEntry> _streamController =
      StreamController<AppLogEntry>.broadcast();
  final List<AppLogEntry> _recentEntries = <AppLogEntry>[];
  final List<String> _pendingLines = <String>[];
  Timer? _flushTimer;
  bool _initialized = false;
  bool _flushing = false;

  static const int _maxInMemory = 1000;
  static const int _maxDialogEntries = 400;
  static const Duration _flushEvery = Duration(seconds: 6);

  Stream<AppLogEntry> get stream => _streamController.stream;

  String get logDirPath =>
      '${ConfigService.configDir}${Platform.pathSeparator}logs';
  String get logFilePath {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '$logDirPath${Platform.pathSeparator}$date.log';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Directory(logDirPath).create(recursive: true);
    } catch (_) {}
    _flushTimer = Timer.periodic(_flushEvery, (_) => flush());
  }

  void info(String scope, String message) {
    _append('INFO', scope, message);
  }

  void warn(String scope, String message) {
    _append('WARN', scope, message);
  }

  void error(String scope, String message) {
    _append('ERROR', scope, message);
  }

  void _append(String level, String scope, String message) {
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      scope: scope,
      message: message,
    );
    _recentEntries.add(entry);
    if (_recentEntries.length > _maxInMemory) {
      _recentEntries.removeRange(0, _recentEntries.length - _maxInMemory);
    }
    _pendingLines.add(entry.formatLine());
    if (_pendingLines.length >= 24) {
      unawaited(flush());
    }
    if (!_streamController.isClosed) {
      _streamController.add(entry);
    }
  }

  List<AppLogEntry> getRecentInMemory() {
    if (_recentEntries.length <= _maxDialogEntries) {
      return List<AppLogEntry>.from(_recentEntries);
    }
    return List<AppLogEntry>.from(
      _recentEntries.sublist(_recentEntries.length - _maxDialogEntries),
    );
  }

  Future<List<AppLogEntry>> readRecentFromDisk({int maxLines = 600}) async {
    try {
      final file = File(logFilePath);
      if (!await file.exists()) {
        return getRecentInMemory();
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return getRecentInMemory();
      }
      final lines = const LineSplitter()
          .convert(raw)
          .where((l) => l.trim().isNotEmpty);
      final all = lines.map(AppLogEntry.parseOrFallback).toList();
      final clipped =
          all.length <= maxLines ? all : all.sublist(all.length - maxLines);
      return clipped;
    } catch (_) {
      return getRecentInMemory();
    }
  }

  Future<void> flush() async {
    if (_flushing || _pendingLines.isEmpty) return;
    _flushing = true;
    try {
      await initialize();
      final toWrite = List<String>.from(_pendingLines);
      _pendingLines.clear();
      final file = File(logFilePath);
      final payload = '${toWrite.join('\n')}\n';
      await file.writeAsString(payload, mode: FileMode.append, flush: true);
    } catch (_) {
      // Keep the queue if writing failed.
      if (_pendingLines.isEmpty) {
        // If failed after clear, best effort to preserve visibility.
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> openLogDirectory() async {
    final dir = logDirPath;
    try {
      await Directory(dir).create(recursive: true);
      if (Platform.isWindows) {
        await Process.run('explorer', [dir]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
    await _streamController.close();
  }
}
