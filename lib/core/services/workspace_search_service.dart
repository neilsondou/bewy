import 'dart:convert';
import 'dart:io';

class WorkspaceSearchMatch {
  const WorkspaceSearchMatch({
    required this.filePath,
    required this.line,
    required this.column,
    required this.preview,
  });

  final String filePath;
  final int line;
  final int column;
  final String preview;
}

class WorkspaceSearchProgress {
  const WorkspaceSearchProgress({
    required this.processedFiles,
    required this.totalFiles,
    required this.currentFilePath,
  });

  final int processedFiles;
  final int totalFiles;
  final String currentFilePath;

  double get ratio {
    if (totalFiles <= 0) return 0;
    return processedFiles / totalFiles;
  }
}

class WorkspaceSearchResult {
  const WorkspaceSearchResult({
    required this.matches,
    required this.scannedFiles,
  });

  final List<WorkspaceSearchMatch> matches;
  final int scannedFiles;
}

class WorkspaceReplaceResult {
  const WorkspaceReplaceResult({
    required this.scannedFiles,
    required this.changedFiles,
    required this.replacements,
  });

  final int scannedFiles;
  final int changedFiles;
  final int replacements;
}

class WorkspaceSearchService {
  const WorkspaceSearchService();

  Future<WorkspaceSearchResult> search({
    required String rootPath,
    required String query,
    void Function(WorkspaceSearchProgress progress)? onProgress,
  }) async {
    if (query.isEmpty) {
      return const WorkspaceSearchResult(matches: [], scannedFiles: 0);
    }

    final files = _collectCandidateFiles(rootPath);
    final matches = <WorkspaceSearchMatch>[];
    var scanned = 0;

    for (final file in files) {
      scanned++;
      onProgress?.call(
        WorkspaceSearchProgress(
          processedFiles: scanned,
          totalFiles: files.length,
          currentFilePath: file.path,
        ),
      );

      final text = await _readTextFile(file);
      if (text == null || text.isEmpty) continue;
      matches.addAll(_findMatches(file.path, text, query));
    }

    return WorkspaceSearchResult(matches: matches, scannedFiles: scanned);
  }

  Future<WorkspaceReplaceResult> replaceAll({
    required String rootPath,
    required String query,
    required String replacement,
    void Function(WorkspaceSearchProgress progress)? onProgress,
  }) async {
    if (query.isEmpty) {
      return const WorkspaceReplaceResult(
        scannedFiles: 0,
        changedFiles: 0,
        replacements: 0,
      );
    }

    final files = _collectCandidateFiles(rootPath);
    var scanned = 0;
    var changedFiles = 0;
    var replacements = 0;

    for (final file in files) {
      scanned++;
      onProgress?.call(
        WorkspaceSearchProgress(
          processedFiles: scanned,
          totalFiles: files.length,
          currentFilePath: file.path,
        ),
      );

      final text = await _readTextFile(file);
      if (text == null || text.isEmpty) continue;
      if (!text.contains(query)) continue;

      final count = _countOccurrences(text, query);
      if (count <= 0) continue;

      final replaced = text.replaceAll(query, replacement);
      if (replaced == text) continue;

      await file.writeAsString(replaced);
      changedFiles++;
      replacements += count;
    }

    return WorkspaceReplaceResult(
      scannedFiles: scanned,
      changedFiles: changedFiles,
      replacements: replacements,
    );
  }

  List<File> _collectCandidateFiles(String rootPath) {
    final root = Directory(rootPath);
    if (!root.existsSync()) return const [];
    final files = <File>[];
    final stack = <Directory>[root];
    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(followLinks: false);
      } catch (_) {
        continue;
      }
      for (final entity in children) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.') && name != '.gitignore') continue;
        if (entity is Directory) {
          stack.add(entity);
        } else if (entity is File && !_isLikelyBinaryByExtension(entity.path)) {
          files.add(entity);
        }
      }
    }
    return files;
  }

  Future<String?> _readTextFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (_containsNullByte(bytes)) return null;
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  List<WorkspaceSearchMatch> _findMatches(
    String path,
    String content,
    String query,
  ) {
    final out = <WorkspaceSearchMatch>[];
    final lines = const LineSplitter().convert(content);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var start = 0;
      while (true) {
        final index = line.indexOf(query, start);
        if (index < 0) break;
        out.add(
          WorkspaceSearchMatch(
            filePath: path,
            line: i + 1,
            column: index + 1,
            preview: line.trim(),
          ),
        );
        start = index + query.length;
        if (start >= line.length) break;
      }
    }
    return out;
  }

  int _countOccurrences(String text, String query) {
    var count = 0;
    var start = 0;
    while (true) {
      final index = text.indexOf(query, start);
      if (index < 0) break;
      count++;
      start = index + query.length;
      if (start >= text.length) break;
    }
    return count;
  }

  bool _containsNullByte(List<int> bytes) {
    final n = bytes.length < 2048 ? bytes.length : 2048;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }

  bool _isLikelyBinaryByExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    final ext = path.substring(dot + 1).toLowerCase();
    const exts = {
      'exe',
      'dll',
      'so',
      'dylib',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'ico',
      'pdf',
      'zip',
      '7z',
      'tar',
      'mp3',
      'mp4',
      'wav',
      'ttf',
      'otf',
      'woff',
      'woff2',
      'class',
      'o',
      'obj',
      'bin',
    };
    return exts.contains(ext);
  }
}
