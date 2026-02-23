import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the IDE shell layout.
class IDEShellState {
  const IDEShellState({
    this.sideBarWidth = 250.0,
    this.bottomPanelVisible = false,
    this.bottomPanelHeight = 200.0,
    this.editorVisible = true,
    this.isZenMode = false,
  });

  final double sideBarWidth;
  final bool bottomPanelVisible;
  final double bottomPanelHeight;
  final bool editorVisible;
  final bool isZenMode;

  IDEShellState copyWith({
    double? sideBarWidth,
    bool? bottomPanelVisible,
    double? bottomPanelHeight,
    bool? editorVisible,
    bool? isZenMode,
  }) {
    return IDEShellState(
      sideBarWidth: sideBarWidth ?? this.sideBarWidth,
      bottomPanelVisible: bottomPanelVisible ?? this.bottomPanelVisible,
      bottomPanelHeight: bottomPanelHeight ?? this.bottomPanelHeight,
      editorVisible: editorVisible ?? this.editorVisible,
      isZenMode: isZenMode ?? this.isZenMode,
    );
  }
}

class IDEShellNotifier extends StateNotifier<IDEShellState> {
  IDEShellNotifier() : super(const IDEShellState());

  double _lastSideBarWidth = 250.0;
  double _restoreSideBarWidth = 250.0;
  bool _restoreBottomPanelVisible = false;
  double _restoreBottomPanelHeight = 200.0;
  bool _restoreEditorVisible = true;

  void setSideBarWidth(double width) {
    final clamped = width.clamp(170.0, 500.0);
    _lastSideBarWidth = clamped;
    state = state.copyWith(sideBarWidth: clamped);
  }

  void toggleSidebar() {
    if (state.isZenMode) return;
    if (state.sideBarWidth > 0) {
      state = state.copyWith(sideBarWidth: 0.0);
    } else {
      state = state.copyWith(sideBarWidth: _lastSideBarWidth);
    }
  }

  void toggleBottomPanel() {
    if (state.isZenMode) return;
    state = state.copyWith(bottomPanelVisible: !state.bottomPanelVisible);
  }

  void setBottomPanelVisible(bool visible) {
    if (state.isZenMode) return;
    state = state.copyWith(bottomPanelVisible: visible);
  }

  void setBottomPanelHeight(double height) {
    if (state.isZenMode) return;
    state = state.copyWith(bottomPanelHeight: height.clamp(100.0, 600.0));
  }

  void toggleEditor() {
    if (state.isZenMode) return;
    state = state.copyWith(editorVisible: !state.editorVisible);
  }

  void setEditorVisible(bool visible) {
    if (state.isZenMode) return;
    state = state.copyWith(editorVisible: visible);
  }

  void toggleZenMode() {
    if (state.isZenMode) {
      exitZenMode();
    } else {
      enterZenMode();
    }
  }

  void setZenMode(bool enabled) {
    if (enabled) {
      enterZenMode();
    } else {
      exitZenMode();
    }
  }

  void enterZenMode() {
    if (state.isZenMode) return;
    _restoreSideBarWidth = state.sideBarWidth;
    _restoreBottomPanelVisible = state.bottomPanelVisible;
    _restoreBottomPanelHeight = state.bottomPanelHeight;
    _restoreEditorVisible = state.editorVisible;
    final zenSideBarWidth =
        state.sideBarWidth > 0 ? state.sideBarWidth : _lastSideBarWidth;
    state = state.copyWith(
      isZenMode: true,
      sideBarWidth: zenSideBarWidth,
      bottomPanelVisible: false,
      editorVisible: true,
    );
  }

  void exitZenMode() {
    if (!state.isZenMode) return;
    state = state.copyWith(
      isZenMode: false,
      sideBarWidth: _restoreSideBarWidth,
      bottomPanelVisible: _restoreBottomPanelVisible,
      bottomPanelHeight: _restoreBottomPanelHeight,
      editorVisible: _restoreEditorVisible,
    );
  }
}

final ideShellProvider = StateNotifierProvider<IDEShellNotifier, IDEShellState>(
  (ref) => IDEShellNotifier(),
);
