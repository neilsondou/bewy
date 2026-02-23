import 'dart:io';

class LanguageServerInstallResult {
  const LanguageServerInstallResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;
}

class LanguageServerInstallService {
  const LanguageServerInstallService._();

  static Future<bool> isExecutableAvailable(String executable) async {
    final lookup = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(lookup, [executable], runInShell: true);
      if (result.exitCode != 0) return false;
      final out = (result.stdout ?? '').toString().trim();
      return out.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<LanguageServerInstallResult> installByCommand(
    String command,
  ) async {
    if (command.trim().isEmpty) {
      return const LanguageServerInstallResult(
        success: false,
        exitCode: -1,
        stdout: '',
        stderr: 'empty command',
      );
    }

    final executable = Platform.isWindows ? 'cmd' : 'sh';
    final args = Platform.isWindows ? ['/c', command] : ['-lc', command];
    try {
      final result = await Process.run(executable, args, runInShell: true);
      return LanguageServerInstallResult(
        success: result.exitCode == 0,
        exitCode: result.exitCode,
        stdout: (result.stdout ?? '').toString(),
        stderr: (result.stderr ?? '').toString(),
      );
    } catch (e) {
      return LanguageServerInstallResult(
        success: false,
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
      );
    }
  }
}
