import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomPanelState {
  const BottomPanelState({this.activeTab = 'problems'});

  final String activeTab;

  BottomPanelState copyWith({String? activeTab}) {
    return BottomPanelState(activeTab: activeTab ?? this.activeTab);
  }
}

class BottomPanelNotifier extends StateNotifier<BottomPanelState> {
  BottomPanelNotifier() : super(const BottomPanelState());

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }
}

final bottomPanelProvider =
    StateNotifierProvider<BottomPanelNotifier, BottomPanelState>(
      (ref) => BottomPanelNotifier(),
    );
