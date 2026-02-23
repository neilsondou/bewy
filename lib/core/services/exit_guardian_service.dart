import 'dart:io';

class ExitGuardianService {
  ExitGuardianService._();

  static bool _started = false;
  static String? _triggerFilePath;

  static Future<void> ensureStarted() async {
    if (_started || !Platform.isWindows) return;
    _started = true;

    final id = DateTime.now().microsecondsSinceEpoch;
    final tempDir = Directory.systemTemp.path;
    _triggerFilePath =
        '$tempDir${Platform.pathSeparator}bewy_exit_guard_$id.signal';

    final escapedPath = _escapeForPsSingleQuoted(_triggerFilePath!);
    final script = [
      "\$trigger='$escapedPath'",
      "\$timeoutAt=(Get-Date).AddHours(12)",
      'while (-not (Test-Path -LiteralPath \$trigger)) {',
      '  if ((Get-Date) -gt \$timeoutAt) { exit 0 }',
      '  Start-Sleep -Milliseconds 250',
      '}',
      'Start-Sleep -Milliseconds 400',
      'taskkill /IM bewy.exe /F > \$null 2>&1',
      'Remove-Item -LiteralPath \$trigger -Force -ErrorAction SilentlyContinue',
    ].join('; ');

    try {
      await Process.start('powershell', [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-Command',
        script,
      ], mode: ProcessStartMode.detached);
    } catch (_) {
      // Best effort only. Normal close path still executes.
    }
  }

  static Future<void> requestKillAll() async {
    if (!Platform.isWindows) return;
    final path = _triggerFilePath;
    if (path == null) return;
    try {
      await File(path).writeAsString('shutdown');
    } catch (_) {}
  }

  static String _escapeForPsSingleQuoted(String input) {
    return input.replaceAll("'", "''");
  }
}
