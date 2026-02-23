import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:xml/xml.dart';

class CodeFormatResult {
  const CodeFormatResult({
    required this.supported,
    required this.changed,
    this.formattedText,
    this.message,
    this.tool,
  });

  final bool supported;
  final bool changed;
  final String? formattedText;
  final String? message;
  final String? tool;
}

class FormatterSupportItem {
  const FormatterSupportItem({
    required this.tool,
    required this.languages,
    required this.mode,
  });

  final String tool;
  final String languages;
  final String mode;
}

class CodeFormatService {
  const CodeFormatService();

  static const supports = <FormatterSupportItem>[
    FormatterSupportItem(
      tool: 'dart_style',
      languages: 'Dart',
      mode: 'Built-in',
    ),
    FormatterSupportItem(tool: 'xml', languages: 'XML, SVG', mode: 'Built-in'),
    FormatterSupportItem(
      tool: 'prettier',
      languages:
          'JavaScript, TypeScript, JSX, TSX, CSS, SCSS, HTML, JSONC, YAML, Markdown, Vue, Svelte',
      mode: 'External CLI',
    ),
    FormatterSupportItem(
      tool: 'black',
      languages: 'Python',
      mode: 'External CLI',
    ),
    FormatterSupportItem(tool: 'gofmt', languages: 'Go', mode: 'External CLI'),
    FormatterSupportItem(
      tool: 'rustfmt',
      languages: 'Rust',
      mode: 'External CLI',
    ),
    FormatterSupportItem(
      tool: 'clang-format',
      languages: 'C, C++, C#, Java, Objective-C',
      mode: 'External CLI',
    ),
    FormatterSupportItem(
      tool: 'shfmt',
      languages: 'Shell/Bash',
      mode: 'External CLI',
    ),
    FormatterSupportItem(
      tool: 'stylua',
      languages: 'Lua',
      mode: 'External CLI',
    ),
  ];

  static int get supportedToolCount => supports.length;

  Future<CodeFormatResult> format({
    required String fileNameOrPath,
    required String source,
  }) async {
    final ext = _extensionOf(fileNameOrPath);
    if (ext.isEmpty) {
      return const CodeFormatResult(
        supported: false,
        changed: false,
        message: 'No extension',
      );
    }

    final internal = _formatInternal(ext, source);
    if (internal != null) return internal;

    final external = await _formatExternal(ext, fileNameOrPath, source);
    if (external != null) return external;

    return CodeFormatResult(
      supported: false,
      changed: false,
      message: 'No formatter for .$ext',
    );
  }

  CodeFormatResult? _formatInternal(String ext, String source) {
    switch (ext) {
      case 'dart':
        try {
          final formatter = DartFormatter(
            languageVersion: DartFormatter.latestLanguageVersion,
          );
          final formatted = formatter.format(source);
          return CodeFormatResult(
            supported: true,
            changed: formatted != source,
            formattedText: formatted,
            tool: 'dart_style',
          );
        } catch (e) {
          return CodeFormatResult(
            supported: true,
            changed: false,
            message: e.toString(),
            tool: 'dart_style',
          );
        }
      case 'json':
        try {
          final dynamic parsed = jsonDecode(source);
          final encoder = const JsonEncoder.withIndent('  ');
          final formatted = '${encoder.convert(parsed)}\n';
          return CodeFormatResult(
            supported: true,
            changed: formatted != source,
            formattedText: formatted,
            tool: 'json',
          );
        } catch (e) {
          return CodeFormatResult(
            supported: true,
            changed: false,
            message: e.toString(),
            tool: 'json',
          );
        }
      case 'xml':
      case 'svg':
        try {
          final doc = XmlDocument.parse(source);
          final formatted = '${doc.toXmlString(pretty: true, indent: '  ')}\n';
          return CodeFormatResult(
            supported: true,
            changed: formatted != source,
            formattedText: formatted,
            tool: 'xml',
          );
        } catch (e) {
          return CodeFormatResult(
            supported: true,
            changed: false,
            message: e.toString(),
            tool: 'xml',
          );
        }
      default:
        return null;
    }
  }

  Future<CodeFormatResult?> _formatExternal(
    String ext,
    String fileNameOrPath,
    String source,
  ) async {
    final candidates = _externalCandidates(ext, fileNameOrPath);
    if (candidates.isEmpty) return null;

    String? lastError;
    var executedAnyCandidate = false;
    for (final candidate in candidates) {
      final output = await _runExternalFormatter(
        executable: candidate.executable,
        arguments: candidate.arguments,
        input: source,
      );
      if (output == null) {
        continue;
      }
      executedAnyCandidate = true;
      if (output.exitCode != 0) {
        final stderr = output.stderr.trim();
        lastError = stderr.isEmpty ? 'exitCode=${output.exitCode}' : stderr;
        continue;
      }
      final formatted = output.stdout;
      if (formatted.isEmpty) continue;
      return CodeFormatResult(
        supported: true,
        changed: formatted != source,
        formattedText: formatted,
        tool: candidate.tool,
      );
    }

    return CodeFormatResult(
      supported: candidates.isNotEmpty,
      changed: false,
      message:
          lastError ??
          (executedAnyCandidate
              ? 'Formatter returned no output'
              : 'Formatter executable unavailable'),
      tool: candidates.first.tool,
    );
  }

  List<_ExternalCandidate> _externalCandidates(String ext, String path) {
    if (_prettierExts.contains(ext)) {
      return [
        _ExternalCandidate(
          tool: 'prettier',
          executable: 'prettier',
          arguments: ['--stdin-filepath', path],
        ),
      ];
    }
    switch (ext) {
      case 'py':
        return [
          const _ExternalCandidate(
            tool: 'black',
            executable: 'black',
            arguments: ['-q', '-'],
          ),
        ];
      case 'go':
        return [
          const _ExternalCandidate(
            tool: 'gofmt',
            executable: 'gofmt',
            arguments: [],
          ),
        ];
      case 'rs':
        return [
          const _ExternalCandidate(
            tool: 'rustfmt',
            executable: 'rustfmt',
            arguments: ['--emit', 'stdout'],
          ),
        ];
      case 'sh':
      case 'bash':
      case 'zsh':
        return [
          const _ExternalCandidate(
            tool: 'shfmt',
            executable: 'shfmt',
            arguments: [],
          ),
        ];
      case 'lua':
        return [
          const _ExternalCandidate(
            tool: 'stylua',
            executable: 'stylua',
            arguments: ['-'],
          ),
        ];
      default:
        if (_clangFormatExts.contains(ext)) {
          return [
            _ExternalCandidate(
              tool: 'clang-format',
              executable: 'clang-format',
              arguments: ['--assume-filename=$path'],
            ),
          ];
        }
        return const [];
    }
  }

  Future<_ProcessOutput?> _runExternalFormatter({
    required String executable,
    required List<String> arguments,
    required String input,
  }) async {
    try {
      final process = await Process.start(
        executable,
        arguments,
        runInShell: Platform.isWindows,
      );
      process.stdin.write(input);
      await process.stdin.close();
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitFuture = process.exitCode;
      final results = await Future.wait([
        stdoutFuture,
        stderrFuture,
        exitFuture,
      ]).timeout(const Duration(seconds: 6));
      return _ProcessOutput(
        stdout: results[0] as String,
        stderr: results[1] as String,
        exitCode: results[2] as int,
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _extensionOf(String path) {
    final fileName =
        path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).lastOrNull;
    if (fileName == null) return '';
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static const _prettierExts = <String>{
    'js',
    'jsx',
    'ts',
    'tsx',
    'css',
    'scss',
    'less',
    'html',
    'jsonc',
    'yml',
    'yaml',
    'md',
    'markdown',
    'vue',
    'svelte',
  };

  static const _clangFormatExts = <String>{
    'c',
    'h',
    'cc',
    'hh',
    'cpp',
    'hpp',
    'cxx',
    'hxx',
    'm',
    'mm',
    'java',
    'cs',
  };
}

class _ExternalCandidate {
  const _ExternalCandidate({
    required this.tool,
    required this.executable,
    required this.arguments,
  });

  final String tool;
  final String executable;
  final List<String> arguments;
}

class _ProcessOutput {
  const _ProcessOutput({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull {
    if (isEmpty) return null;
    return last;
  }
}
