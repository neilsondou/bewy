import 'editor_tab_model.dart';

const _sentinel = Object();

/// Represents a group of tabs in the editor.
class TabGroupModel {
  const TabGroupModel({this.tabs = const [], this.activeTabId});

  final List<EditorTabModel> tabs;
  final String? activeTabId;

  TabGroupModel copyWith({
    List<EditorTabModel>? tabs,
    Object? activeTabId = _sentinel,
  }) {
    return TabGroupModel(
      tabs: tabs ?? this.tabs,
      activeTabId:
          activeTabId == _sentinel ? this.activeTabId : activeTabId as String?,
    );
  }
}
