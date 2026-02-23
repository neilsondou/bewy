import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/editor_area/presentation/editor_settings_provider.dart';
import 'package:bewy/core/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorSettingsNotifier notifier;

  setUp(() {
    notifier = EditorSettingsNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  // ── Initial state ─────────────────────────────────────────────────
  group('Initial state', () {
    test('auto-save mode defaults to off', () {
      expect(notifier.state.autoSaveMode, AutoSaveMode.off);
    });

    test('auto-save delay defaults to 1000ms', () {
      expect(notifier.state.autoSaveDelayMs, 1000);
    });

    test('auto format on save defaults to false', () {
      expect(notifier.state.autoFormatOnSave, isFalse);
    });

    test('word wrap defaults to false', () {
      expect(notifier.state.wordWrap, isFalse);
    });

    test('font size defaults to 14.0', () {
      expect(notifier.state.fontSize, 14.0);
    });

    test('startup folder restore defaults to enabled', () {
      expect(notifier.state.openLastFolderOnStartup, isTrue);
    });

    test('default file encoding defaults to UTF-8', () {
      expect(notifier.state.defaultFileEncoding, FileEncodingOption.utf8);
    });

    test('auto pair symbols defaults to enabled', () {
      expect(notifier.state.autoPairSymbols, isTrue);
    });

    test('app theme mode defaults to dark', () {
      expect(notifier.state.appThemeMode, AppThemeMode.dark);
    });

    test('diagnostics engine defaults to treeSitter', () {
      expect(
          notifier.state.diagnosticsEngine, DiagnosticsEngine.treeSitter);
    });
  });

  // ── Auto-save mode ────────────────────────────────────────────────
  group('Auto-save mode', () {
    test('setAutoSaveMode changes mode to afterDelay', () {
      notifier.setAutoSaveMode(AutoSaveMode.afterDelay);
      expect(notifier.state.autoSaveMode, AutoSaveMode.afterDelay);
    });

    test('setAutoSaveMode changes mode to onFocusLost', () {
      notifier.setAutoSaveMode(AutoSaveMode.onFocusLost);
      expect(notifier.state.autoSaveMode, AutoSaveMode.onFocusLost);
    });

    test('setAutoSaveMode changes mode back to off', () {
      notifier.setAutoSaveMode(AutoSaveMode.afterDelay);
      notifier.setAutoSaveMode(AutoSaveMode.off);
      expect(notifier.state.autoSaveMode, AutoSaveMode.off);
    });
  });

  // ── Auto-save delay ───────────────────────────────────────────────
  group('Auto-save delay', () {
    test('setAutoSaveDelay changes delay to 500ms', () {
      notifier.setAutoSaveDelay(500);
      expect(notifier.state.autoSaveDelayMs, 500);
    });

    test('setAutoSaveDelay changes delay to 2000ms', () {
      notifier.setAutoSaveDelay(2000);
      expect(notifier.state.autoSaveDelayMs, 2000);
    });

    test('setAutoSaveDelay changes delay to 5000ms', () {
      notifier.setAutoSaveDelay(5000);
      expect(notifier.state.autoSaveDelayMs, 5000);
    });

    test('delay is preserved when changing mode', () {
      notifier.setAutoSaveDelay(2000);
      notifier.setAutoSaveMode(AutoSaveMode.afterDelay);
      expect(notifier.state.autoSaveDelayMs, 2000);
    });

    test('mode is preserved when changing delay', () {
      notifier.setAutoSaveMode(AutoSaveMode.afterDelay);
      notifier.setAutoSaveDelay(5000);
      expect(notifier.state.autoSaveMode, AutoSaveMode.afterDelay);
    });
  });

  group('Auto format on save', () {
    test('setAutoFormatOnSave enables option', () {
      notifier.setAutoFormatOnSave(true);
      expect(notifier.state.autoFormatOnSave, isTrue);
    });

    test('setAutoFormatOnSave disables option', () {
      notifier.setAutoFormatOnSave(true);
      notifier.setAutoFormatOnSave(false);
      expect(notifier.state.autoFormatOnSave, isFalse);
    });
  });

  // ── Diagnostics engine ──────────────────────────────────────────────
  group('Diagnostics engine', () {
    test('setDiagnosticsEngine switches to languageServer', () {
      notifier.setDiagnosticsEngine(DiagnosticsEngine.languageServer);
      expect(
          notifier.state.diagnosticsEngine, DiagnosticsEngine.languageServer);
    });

    test('setDiagnosticsEngine switches back to treeSitter', () {
      notifier.setDiagnosticsEngine(DiagnosticsEngine.languageServer);
      notifier.setDiagnosticsEngine(DiagnosticsEngine.treeSitter);
      expect(notifier.state.diagnosticsEngine, DiagnosticsEngine.treeSitter);
    });
  });

  // ── Word wrap ─────────────────────────────────────────────────────
  group('Word wrap', () {
    test('toggleWordWrap enables wrap', () {
      notifier.toggleWordWrap();
      expect(notifier.state.wordWrap, isTrue);
    });

    test('toggleWordWrap twice disables wrap', () {
      notifier.toggleWordWrap();
      notifier.toggleWordWrap();
      expect(notifier.state.wordWrap, isFalse);
    });
  });

  // ── Zoom ──────────────────────────────────────────────────────────
  group('Zoom', () {
    test('zoomIn increases font size by 1', () {
      notifier.zoomIn();
      expect(notifier.state.fontSize, 15.0);
    });

    test('zoomOut decreases font size by 1', () {
      notifier.zoomOut();
      expect(notifier.state.fontSize, 13.0);
    });

    test('resetZoom returns to 14.0', () {
      notifier.zoomIn();
      notifier.zoomIn();
      notifier.resetZoom();
      expect(notifier.state.fontSize, 14.0);
    });

    test('zoom does not go below 8.0', () {
      for (int i = 0; i < 20; i++) {
        notifier.zoomOut();
      }
      expect(notifier.state.fontSize, 8.0);
    });

    test('zoom does not go above 40.0', () {
      for (int i = 0; i < 40; i++) {
        notifier.zoomIn();
      }
      expect(notifier.state.fontSize, 40.0);
    });
  });

  group('New settings bounds', () {
    test('folding max lines is clamped to minimum', () {
      notifier.setCodeFoldingMaxLines(-5);
      expect(notifier.state.codeFoldingMaxLines, 50);
    });

    test('folding max lines is clamped to maximum', () {
      notifier.setCodeFoldingMaxLines(999999);
      expect(notifier.state.codeFoldingMaxLines, 20000);
    });

    test('editor font size is clamped to minimum', () {
      notifier.setEditorFontSize(1);
      expect(notifier.state.fontSize, 8.0);
    });

    test('editor font size is clamped to maximum', () {
      notifier.setEditorFontSize(100);
      expect(notifier.state.fontSize, 40.0);
    });

    test('editor letter spacing is clamped to minimum', () {
      notifier.setEditorLetterSpacing(-10);
      expect(notifier.state.editorLetterSpacing, -1.0);
    });

    test('editor letter spacing is clamped to maximum', () {
      notifier.setEditorLetterSpacing(10);
      expect(notifier.state.editorLetterSpacing, 6.0);
    });

    test('setAppThemeMode updates state', () {
      notifier.setAppThemeMode(AppThemeMode.light);
      expect(notifier.state.appThemeMode, AppThemeMode.light);
    });
  });

  // ── EditorSettingsState copyWith ──────────────────────────────────
  group('EditorSettingsState.copyWith', () {
    test('copies with new autoSaveMode', () {
      const state = EditorSettingsState();
      final copied = state.copyWith(autoSaveMode: AutoSaveMode.afterDelay);
      expect(copied.autoSaveMode, AutoSaveMode.afterDelay);
      expect(copied.autoSaveDelayMs, 1000); // unchanged
    });

    test('copies with new autoSaveDelayMs', () {
      const state = EditorSettingsState();
      final copied = state.copyWith(autoSaveDelayMs: 5000);
      expect(copied.autoSaveDelayMs, 5000);
      expect(copied.autoSaveMode, AutoSaveMode.off); // unchanged
    });

    test('copies with all fields', () {
      const state = EditorSettingsState();
      final copied = state.copyWith(
        wordWrap: true,
        fontSize: 20.0,
        autoSaveMode: AutoSaveMode.onFocusLost,
        autoSaveDelayMs: 2000,
      );
      expect(copied.wordWrap, isTrue);
      expect(copied.fontSize, 20.0);
      expect(copied.autoSaveMode, AutoSaveMode.onFocusLost);
      expect(copied.autoSaveDelayMs, 2000);
    });
  });
}
