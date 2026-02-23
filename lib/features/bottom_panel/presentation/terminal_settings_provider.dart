import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/config_service.dart';

class TerminalSettingsState {
  const TerminalSettingsState({
    this.defaultProfileId = 'cmd',
    this.fontSize = 12.0,
    this.letterSpacing = 0.2,
    this.lineHeight = 1.35,
  });

  final String defaultProfileId;
  final double fontSize;
  final double letterSpacing;
  final double lineHeight;

  TerminalSettingsState copyWith({
    String? defaultProfileId,
    double? fontSize,
    double? letterSpacing,
    double? lineHeight,
  }) {
    return TerminalSettingsState(
      defaultProfileId: defaultProfileId ?? this.defaultProfileId,
      fontSize: fontSize ?? this.fontSize,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}

class TerminalSettingsNotifier extends StateNotifier<TerminalSettingsState> {
  TerminalSettingsNotifier() : super(const TerminalSettingsState()) {
    _load();
    _sub = ConfigService.watchChanges().listen((_) => _load());
  }

  StreamSubscription<void>? _sub;

  Future<void> _load() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    final id = data['terminalDefaultProfile'] as String?;
    final fs = data['terminalFontSize'];
    final ls = data['terminalLetterSpacing'];
    final lh = data['terminalLineHeight'];
    state = state.copyWith(
      defaultProfileId: id,
      fontSize: fs is num ? fs.toDouble().clamp(9.0, 28.0) : null,
      letterSpacing: ls is num ? ls.toDouble().clamp(-0.5, 3.0) : null,
      lineHeight: lh is num ? lh.toDouble().clamp(1.0, 2.2) : null,
    );
  }

  void setDefaultProfileId(String id) {
    state = state.copyWith(defaultProfileId: id);
    _persist();
  }

  void setFontSize(double value) {
    state = state.copyWith(fontSize: value.clamp(9.0, 28.0));
    _persist();
  }

  void setLetterSpacing(double value) {
    state = state.copyWith(letterSpacing: value.clamp(-0.5, 3.0));
    _persist();
  }

  void setLineHeight(double value) {
    state = state.copyWith(lineHeight: value.clamp(1.0, 2.2));
    _persist();
  }

  Future<void> _persist() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['terminalDefaultProfile'] = state.defaultProfileId;
    data['terminalFontSize'] = state.fontSize;
    data['terminalLetterSpacing'] = state.letterSpacing;
    data['terminalLineHeight'] = state.lineHeight;
    await ConfigService.save(data);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final terminalSettingsProvider =
    StateNotifierProvider<TerminalSettingsNotifier, TerminalSettingsState>(
      (ref) => TerminalSettingsNotifier(),
    );
