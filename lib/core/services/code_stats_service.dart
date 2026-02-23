import 'dart:convert';
import 'dart:io';

class CodeStatsProgress {
  const CodeStatsProgress({
    required this.processedFiles,
    required this.totalFiles,
  });

  final int processedFiles;
  final int totalFiles;

  double get ratio => totalFiles == 0 ? 1 : processedFiles / totalFiles;
}

class LanguageCodeStat {
  const LanguageCodeStat({
    required this.language,
    required this.lines,
    required this.files,
  });

  final String language;
  final int lines;
  final int files;
}

class ExtensionLineStat {
  const ExtensionLineStat({
    required this.extension,
    required this.lines,
    required this.files,
  });

  final String extension;
  final int lines;
  final int files;
}

class CodeStatsResult {
  const CodeStatsResult({
    required this.scannedFiles,
    required this.totalLines,
    required this.languageStats,
    required this.extensionStats,
  });

  final int scannedFiles;
  final int totalLines;
  final List<LanguageCodeStat> languageStats;
  final List<ExtensionLineStat> extensionStats;
}

class CodeStatsService {
  const CodeStatsService();

  static const Map<String, String> _languageByExtension = {
    'dart': 'Dart',
    'js': 'JavaScript',
    'jsx': 'JavaScript (JSX)',
    'ts': 'TypeScript',
    'tsx': 'TypeScript (TSX)',
    'json': 'JSON',
    'yml': 'YAML',
    'yaml': 'YAML',
    'xml': 'XML',
    'html': 'HTML',
    'htm': 'HTML',
    'css': 'CSS',
    'scss': 'SCSS',
    'less': 'Less',
    'md': 'Markdown',
    'py': 'Python',
    'java': 'Java',
    'kt': 'Kotlin',
    'kts': 'Kotlin',
    'go': 'Go',
    'rs': 'Rust',
    'c': 'C',
    'h': 'C/C++ Header',
    'cpp': 'C++',
    'cc': 'C++',
    'cxx': 'C++',
    'hpp': 'C++ Header',
    'hh': 'C++ Header',
    'hxx': 'C++ Header',
    'cs': 'C#',
    'php': 'PHP',
    'rb': 'Ruby',
    'swift': 'Swift',
    'm': 'Objective-C',
    'mm': 'Objective-C++',
    'lua': 'Lua',
    'sql': 'SQL',
    'sh': 'Shell',
    'bash': 'Shell',
    'zsh': 'Shell',
    'ps1': 'PowerShell',
    'bat': 'Batch',
    'cmd': 'Batch',
    'toml': 'TOML',
    'ini': 'INI',
    'conf': 'Config',
    'gradle': 'Gradle',
    'properties': 'Properties',
    'vue': 'Vue',
    'svelte': 'Svelte',
    'lock': 'Lockfile',
  };

  static const Set<String> _likelyBinaryExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
    'ico',
    'svgz',
    'pdf',
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'exe',
    'dll',
    'so',
    'dylib',
    'bin',
    'dat',
    'class',
    'jar',
    'ttf',
    'otf',
    'woff',
    'woff2',
    'mp3',
    'mp4',
    'wav',
    'ogg',
    'avi',
    'mov',
  };

  Future<CodeStatsResult> analyzeWorkspace({
    required String rootPath,
    Set<String>? includeExtensions,
    void Function(CodeStatsProgress progress)? onProgress,
  }) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      return const CodeStatsResult(
        scannedFiles: 0,
        totalLines: 0,
        languageStats: [],
        extensionStats: [],
      );
    }

    final normalizedInclude =
        includeExtensions == null || includeExtensions.isEmpty
            ? null
            : includeExtensions
                .map((e) => e.trim().toLowerCase().replaceFirst('.', ''))
                .where((e) => e.isNotEmpty)
                .toSet();

    final allFiles = <File>[];
    await for (final entity in rootDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) allFiles.add(entity);
    }

    final targetFiles = allFiles
        .where((f) {
          final ext = _extOf(f.path);
          if (normalizedInclude == null) return true;
          return normalizedInclude.contains(ext);
        })
        .toList(growable: false);

    final languageLines = <String, int>{};
    final languageFiles = <String, int>{};
    final extensionLines = <String, int>{};
    final extensionFiles = <String, int>{};

    var scannedFiles = 0;
    var totalLines = 0;

    onProgress?.call(
      CodeStatsProgress(processedFiles: 0, totalFiles: targetFiles.length),
    );

    for (var i = 0; i < targetFiles.length; i++) {
      final file = targetFiles[i];
      final ext = _extOf(file.path);
      final extKey = ext.isEmpty ? '[no ext]' : '.$ext';

      if (_likelyBinaryExtensions.contains(ext)) {
        onProgress?.call(
          CodeStatsProgress(
            processedFiles: i + 1,
            totalFiles: targetFiles.length,
          ),
        );
        continue;
      }

      try {
        final bytes = await file.readAsBytes();
        if (_isBinary(bytes)) {
          onProgress?.call(
            CodeStatsProgress(
              processedFiles: i + 1,
              totalFiles: targetFiles.length,
            ),
          );
          continue;
        }
        final lineCount = _countLines(bytes);
        final language =
            _languageByExtension[ext] ??
            (ext.isEmpty ? 'Unknown' : ext.toUpperCase());

        scannedFiles += 1;
        totalLines += lineCount;
        languageLines[language] = (languageLines[language] ?? 0) + lineCount;
        languageFiles[language] = (languageFiles[language] ?? 0) + 1;
        extensionLines[extKey] = (extensionLines[extKey] ?? 0) + lineCount;
        extensionFiles[extKey] = (extensionFiles[extKey] ?? 0) + 1;
      } catch (_) {
        // Ignore unreadable files and continue scanning.
      }

      onProgress?.call(
        CodeStatsProgress(
          processedFiles: i + 1,
          totalFiles: targetFiles.length,
        ),
      );
    }

    final languageStats =
        languageLines.entries
            .map(
              (e) => LanguageCodeStat(
                language: e.key,
                lines: e.value,
                files: languageFiles[e.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.lines.compareTo(a.lines));

    final extensionStats =
        extensionLines.entries
            .map(
              (e) => ExtensionLineStat(
                extension: e.key,
                lines: e.value,
                files: extensionFiles[e.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.lines.compareTo(a.lines));

    return CodeStatsResult(
      scannedFiles: scannedFiles,
      totalLines: totalLines,
      languageStats: languageStats,
      extensionStats: extensionStats,
    );
  }

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static bool _isBinary(List<int> bytes) {
    if (bytes.isEmpty) return false;
    final sample = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
    for (final b in sample) {
      if (b == 0) return true;
    }
    return false;
  }

  static int _countLines(List<int> bytes) {
    if (bytes.isEmpty) return 0;
    final text = const Utf8Decoder(allowMalformed: true).convert(bytes);
    if (text.isEmpty) return 0;
    return '\n'.allMatches(text).length + 1;
  }
}
