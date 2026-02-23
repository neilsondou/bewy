import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/shell/presentation/ide_shell_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IDEShellNotifier notifier;

  setUp(() {
    notifier = IDEShellNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  // ── Initial state ─────────────────────────────────────────────────
  group('Initial state', () {
    test('sideBarWidth defaults to 250', () {
      expect(notifier.state.sideBarWidth, 250.0);
    });

    test('bottomPanelVisible defaults to false', () {
      expect(notifier.state.bottomPanelVisible, isFalse);
    });

    test('bottomPanelHeight defaults to 200', () {
      expect(notifier.state.bottomPanelHeight, 200.0);
    });
  });

  // ── Sidebar width ─────────────────────────────────────────────────
  group('Sidebar width', () {
    test('setSideBarWidth clamps to min 170', () {
      notifier.setSideBarWidth(50);
      expect(notifier.state.sideBarWidth, 170.0);
    });

    test('setSideBarWidth clamps to max 500', () {
      notifier.setSideBarWidth(900);
      expect(notifier.state.sideBarWidth, 500.0);
    });

    test('setSideBarWidth allows valid range', () {
      notifier.setSideBarWidth(300);
      expect(notifier.state.sideBarWidth, 300.0);
    });

    test('toggleSidebar hides then restores width', () {
      notifier.setSideBarWidth(300);
      notifier.toggleSidebar();
      expect(notifier.state.sideBarWidth, 0.0);

      notifier.toggleSidebar();
      expect(notifier.state.sideBarWidth, 300.0);
    });
  });

  // ── Bottom panel ──────────────────────────────────────────────────
  group('Bottom panel', () {
    test('toggleBottomPanel shows panel', () {
      notifier.toggleBottomPanel();
      expect(notifier.state.bottomPanelVisible, isTrue);
    });

    test('toggleBottomPanel twice hides panel again', () {
      notifier.toggleBottomPanel();
      notifier.toggleBottomPanel();
      expect(notifier.state.bottomPanelVisible, isFalse);
    });

    test('setBottomPanelHeight clamps to min 100', () {
      notifier.setBottomPanelHeight(20);
      expect(notifier.state.bottomPanelHeight, 100.0);
    });

    test('setBottomPanelHeight clamps to max 600', () {
      notifier.setBottomPanelHeight(1000);
      expect(notifier.state.bottomPanelHeight, 600.0);
    });
  });

  // ── Editor visibility ──────────────────────────────────────────────
  group('Editor visibility', () {
    test('editorVisible defaults to true', () {
      expect(notifier.state.editorVisible, isTrue);
    });

    test('toggleEditor hides editor', () {
      notifier.toggleEditor();
      expect(notifier.state.editorVisible, isFalse);
    });

    test('toggleEditor twice shows editor again', () {
      notifier.toggleEditor();
      notifier.toggleEditor();
      expect(notifier.state.editorVisible, isTrue);
    });

    test('setEditorVisible sets explicit value', () {
      notifier.setEditorVisible(false);
      expect(notifier.state.editorVisible, isFalse);
      notifier.setEditorVisible(true);
      expect(notifier.state.editorVisible, isTrue);
    });
  });

  // ── copyWith ─────────────────────────────────────────────────────
  group('IDEShellState.copyWith', () {
    test('copies with new sideBarWidth', () {
      const state = IDEShellState();
      final copied = state.copyWith(sideBarWidth: 400);
      expect(copied.sideBarWidth, 400);
      expect(copied.bottomPanelVisible, isFalse);
      expect(copied.bottomPanelHeight, 200.0);
      expect(copied.editorVisible, isTrue);
    });

    test('copies with all fields', () {
      const state = IDEShellState();
      final copied = state.copyWith(
        sideBarWidth: 300,
        bottomPanelVisible: false,
        bottomPanelHeight: 150,
        editorVisible: false,
      );
      expect(copied.sideBarWidth, 300);
      expect(copied.bottomPanelVisible, isFalse);
      expect(copied.bottomPanelHeight, 150);
      expect(copied.editorVisible, isFalse);
    });
  });
}
