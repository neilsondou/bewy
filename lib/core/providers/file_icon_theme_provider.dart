import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../services/config_service.dart';

enum FileIconThemeMode { classic, material, cupertino, fontAwesome, phosphor }

enum FileIconColorTheme { muted, vivid, monochrome }

class FileIconThemeState {
  const FileIconThemeState({
    this.themeMode = FileIconThemeMode.classic,
    this.colorTheme = FileIconColorTheme.monochrome,
  });

  final FileIconThemeMode themeMode;
  final FileIconColorTheme colorTheme;

  FileIconThemeState copyWith({
    FileIconThemeMode? themeMode,
    FileIconColorTheme? colorTheme,
  }) {
    return FileIconThemeState(
      themeMode: themeMode ?? this.themeMode,
      colorTheme: colorTheme ?? this.colorTheme,
    );
  }
}

class FileIconThemeNotifier extends StateNotifier<FileIconThemeState> {
  FileIconThemeNotifier() : super(const FileIconThemeState()) {
    _load();
    _configSub = ConfigService.watchChanges().listen((_) {
      final until = _ignoreExternalUntil;
      if (until != null && DateTime.now().isBefore(until)) return;
      _load();
    });
  }
  StreamSubscription<void>? _configSub;
  DateTime? _ignoreExternalUntil;

  Future<void> _load() async {
    try {
      final data = await ConfigService.load();
      if (!mounted) return;
      final rawTheme = data['fileIconTheme'] as String?;
      final rawColors = data['fileIconColorTheme'] as String?;
      state = state.copyWith(
        themeMode: rawTheme == null ? null : _parseThemeMode(rawTheme),
        colorTheme: rawColors == null ? null : _parseColorTheme(rawColors),
      );
    } catch (_) {}
  }

  Future<void> setThemeMode(FileIconThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final data = await ConfigService.load();
    if (!mounted) return;
    data['fileIconTheme'] = mode.name;
    _ignoreExternalUntil = DateTime.now().add(
      const Duration(milliseconds: 300),
    );
    await ConfigService.save(data);
  }

  Future<void> setColorTheme(FileIconColorTheme theme) async {
    state = state.copyWith(colorTheme: theme);
    final data = await ConfigService.load();
    if (!mounted) return;
    data['fileIconColorTheme'] = theme.name;
    _ignoreExternalUntil = DateTime.now().add(
      const Duration(milliseconds: 300),
    );
    await ConfigService.save(data);
  }

  FileIconThemeMode _parseThemeMode(String? value) {
    if (value == null) return FileIconThemeMode.classic;
    return FileIconThemeMode.values.firstWhere(
      (it) => it.name == value,
      orElse: () => FileIconThemeMode.classic,
    );
  }

  FileIconColorTheme _parseColorTheme(String? value) {
    if (value == null) return FileIconColorTheme.monochrome;
    return FileIconColorTheme.values.firstWhere(
      (it) => it.name == value,
      orElse: () => FileIconColorTheme.monochrome,
    );
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }
}

final fileIconThemeProvider =
    StateNotifierProvider<FileIconThemeNotifier, FileIconThemeState>(
      (ref) => FileIconThemeNotifier(),
    );
