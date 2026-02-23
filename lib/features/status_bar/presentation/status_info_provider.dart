import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatusInfo {
  const StatusInfo({
    this.line = 1,
    this.column = 1,
    this.encoding = 'UTF-8',
    this.language = 'Plain Text',
    this.lineEnding = 'LF',
    this.hasActiveEditor = false,
    this.selectedChars = 0,
    this.selectedLines = 0,
  });

  final int line;
  final int column;
  final String encoding;
  final String language;
  final String lineEnding;
  final bool hasActiveEditor;
  final int selectedChars;
  final int selectedLines;

  bool get hasSelection => selectedChars > 0;
}

class StatusInfoNotifier extends StateNotifier<StatusInfo> {
  StatusInfoNotifier() : super(const StatusInfo());

  void update({
    int? line,
    int? column,
    String? encoding,
    String? language,
    String? lineEnding,
    int? selectedChars,
    int? selectedLines,
  }) {
    state = StatusInfo(
      line: line ?? state.line,
      column: column ?? state.column,
      encoding: encoding ?? state.encoding,
      language: language ?? state.language,
      lineEnding: lineEnding ?? state.lineEnding,
      hasActiveEditor: true,
      selectedChars: selectedChars ?? state.selectedChars,
      selectedLines: selectedLines ?? state.selectedLines,
    );
  }

  void setLineEnding(String lineEnding) {
    state = StatusInfo(
      line: state.line,
      column: state.column,
      encoding: state.encoding,
      language: state.language,
      lineEnding: lineEnding,
      hasActiveEditor: state.hasActiveEditor,
      selectedChars: state.selectedChars,
      selectedLines: state.selectedLines,
    );
  }

  void setEncoding(String encoding) {
    state = StatusInfo(
      line: state.line,
      column: state.column,
      encoding: encoding,
      language: state.language,
      lineEnding: state.lineEnding,
      hasActiveEditor: state.hasActiveEditor,
      selectedChars: state.selectedChars,
      selectedLines: state.selectedLines,
    );
  }

  void clear() {
    state = const StatusInfo();
  }
}

final statusInfoProvider =
    StateNotifierProvider<StatusInfoNotifier, StatusInfo>(
      (ref) => StatusInfoNotifier(),
    );
