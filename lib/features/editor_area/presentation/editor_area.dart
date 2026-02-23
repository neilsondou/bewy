import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/multi_window_provider.dart';
import '../../../core/providers/timeline_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../shell/presentation/ide_shell_provider.dart';
import '../../status_bar/presentation/status_info_provider.dart';
import '../../status_bar/presentation/status_notification_provider.dart';
import '../models/editor_tab_model.dart';
import '../widgets/binary_file_tab.dart';
import '../widgets/breadcrumb_bar.dart';
import 'package:bewy/features/editor_area/widgets/editor_content.dart';
import '../widgets/settings_tab.dart';
import '../widgets/tab_bar_widget.dart';
import '../widgets/welcome_tab.dart';
import 'editor_area_provider.dart';

Future<void> handleTabCloseWithSaveCheck(
  BuildContext context,
  WidgetRef ref,
  String tabId,
) async {
  final notifier = ref.read(editorAreaProvider.notifier);
  if (!notifier.isModified(tabId)) {
    notifier.closeTab(tabId);
    return;
  }
  final tab = ref
      .read(editorAreaProvider)
      .tabGroup
      .tabs
      .firstWhere((t) => t.id == tabId);
  final result = await AppDialog.showConfirmSave(context, tab.fileName);
  if (result == 'save') {
    await notifier.saveTab(tabId);
    notifier.closeTab(tabId);
  } else if (result == 'discard') {
    notifier.closeTab(tabId);
  }
}

class EditorArea extends ConsumerStatefulWidget {
  const EditorArea({super.key});

  @override
  ConsumerState<EditorArea> createState() => _EditorAreaState();
}

class _EditorAreaState extends ConsumerState<EditorArea> {
  static const int _maxEditorGroups = 3;
  final Map<String, int> _tabToGroup = {};
  final Map<int, String> _groupActiveTabId = {};
  final List<int> _groupOrder = [0];
  int _activeGroupId = 0;
  int _nextGroupId = 1;

  void _syncAssignments(EditorAreaState state) {
    final tabs = state.tabGroup.tabs;
    final validIds = tabs.map((t) => t.id).toSet();
    _tabToGroup.removeWhere((tabId, _) => !validIds.contains(tabId));

    if (tabs.isEmpty) {
      _groupOrder
        ..clear()
        ..add(0);
      _groupActiveTabId.clear();
      _activeGroupId = 0;
      return;
    }

    if (_groupOrder.isEmpty) {
      _groupOrder.add(0);
    }
    for (final tab in tabs) {
      _tabToGroup.putIfAbsent(tab.id, () => _activeGroupId);
      final groupId = _tabToGroup[tab.id]!;
      if (!_groupOrder.contains(groupId)) {
        _groupOrder.add(groupId);
      }
    }

    final groupToCount = <int, int>{};
    for (final tab in tabs) {
      final groupId = _tabToGroup[tab.id] ?? _activeGroupId;
      groupToCount[groupId] = (groupToCount[groupId] ?? 0) + 1;
    }
    _groupOrder.removeWhere(
      (groupId) => (groupToCount[groupId] ?? 0) == 0 && _groupOrder.length > 1,
    );
    if (_groupOrder.isEmpty) {
      final fallback =
          groupToCount.keys.isNotEmpty ? groupToCount.keys.first : 0;
      _groupOrder.add(fallback);
    }
    _groupActiveTabId.removeWhere(
      (groupId, _) => !_groupOrder.contains(groupId),
    );

    final activeId = state.tabGroup.activeTabId;
    if (activeId != null && _tabToGroup.containsKey(activeId)) {
      _activeGroupId = _tabToGroup[activeId]!;
      _groupActiveTabId[_activeGroupId] = activeId;
    }

    if (_groupOrder.isEmpty) {
      _groupOrder.add(0);
    }
    if (!_groupOrder.contains(_activeGroupId)) {
      _activeGroupId = _groupOrder.first;
    }
    _groupActiveTabId.removeWhere(
      (groupId, tabId) => !validIds.contains(tabId),
    );
  }

  List<EditorTabModel> _tabsForGroup(List<EditorTabModel> tabs, int groupId) {
    return tabs.where((t) => _tabToGroup[t.id] == groupId).toList();
  }

  EditorTabModel? _activeTabForGroup(
    List<EditorTabModel> allTabs,
    int groupId,
    String? globalActiveId,
  ) {
    final groupTabs = _tabsForGroup(allTabs, groupId);
    if (groupTabs.isEmpty) return null;
    final preferred = _groupActiveTabId[groupId];
    if (preferred != null) {
      final hit = groupTabs.where((t) => t.id == preferred).firstOrNull;
      if (hit != null) return hit;
    }
    final global =
        globalActiveId == null
            ? null
            : groupTabs.where((t) => t.id == globalActiveId).firstOrNull;
    if (global != null) return global;
    final first = groupTabs.first;
    _groupActiveTabId[groupId] = first.id;
    return first;
  }

  void _showMaxGroupsTip() {
    ref
        .read(statusNotificationProvider.notifier)
        .show(
          context.tr('status.diffMaxEditorsReached'),
          type: StatusNotificationType.info,
        );
  }

  void _moveTabToGroup(
    String tabId, {
    required int targetGroupId,
    int? targetIndex,
    bool activate = true,
    bool keepSourceGroupWhenEmpty = false,
  }) {
    final state = ref.read(editorAreaProvider);
    final tabs = state.tabGroup.tabs;
    if (tabs.where((t) => t.id == tabId).isEmpty) return;

    if (!_groupOrder.contains(targetGroupId)) {
      if (_groupOrder.length >= _maxEditorGroups) {
        _showMaxGroupsTip();
        return;
      }
      _groupOrder.add(targetGroupId);
    }

    final currentGroup = _tabToGroup[tabId] ?? _activeGroupId;
    final groupToIds = <int, List<String>>{
      for (final groupId in _groupOrder) groupId: <String>[],
    };
    for (final tab in tabs) {
      final groupId = _tabToGroup[tab.id] ?? _activeGroupId;
      groupToIds.putIfAbsent(groupId, () => <String>[]);
      groupToIds[groupId]!.add(tab.id);
    }

    groupToIds[currentGroup]?.remove(tabId);
    final targetList = groupToIds.putIfAbsent(targetGroupId, () => <String>[]);
    final insertIndex = (targetIndex ?? targetList.length).clamp(
      0,
      targetList.length,
    );
    targetList.insert(insertIndex, tabId);
    _tabToGroup[tabId] = targetGroupId;
    _groupActiveTabId[targetGroupId] = tabId;

    final orderedIds = <String>[];
    for (final groupId in _groupOrder) {
      final ids = groupToIds[groupId] ?? const <String>[];
      orderedIds.addAll(ids);
    }
    ref.read(editorAreaProvider.notifier).reorderTabsByIdOrder(orderedIds);
    if (activate) {
      _activeGroupId = targetGroupId;
      ref.read(editorAreaProvider.notifier).activateTab(tabId);
    }

    if (!keepSourceGroupWhenEmpty) {
      _groupOrder.removeWhere(
        (groupId) =>
            (groupToIds[groupId]?.isEmpty ?? true) && _groupOrder.length > 1,
      );
    }
    if (!_groupOrder.contains(_activeGroupId)) {
      _activeGroupId = _groupOrder.first;
    }
    setState(() {});
  }

  void _moveTabToNewGroup(String tabId) {
    if (_groupOrder.length >= _maxEditorGroups) {
      _showMaxGroupsTip();
      return;
    }
    final newGroupId = _nextGroupId++;
    _moveTabToGroup(
      tabId,
      targetGroupId: newGroupId,
      targetIndex: 0,
      keepSourceGroupWhenEmpty: true,
    );
  }

  void _closeEditorGroup(int groupId) {
    if (_groupOrder.length <= 1) return;
    final state = ref.read(editorAreaProvider);
    final allTabs = state.tabGroup.tabs;
    final groupIndex = _groupOrder.indexOf(groupId);
    if (groupIndex == -1) return;
    final targetGroupId =
        groupIndex > 0 ? _groupOrder[groupIndex - 1] : _groupOrder[1];

    final groupToIds = <int, List<String>>{
      for (final g in _groupOrder) g: <String>[],
    };
    for (final tab in allTabs) {
      final g = _tabToGroup[tab.id] ?? _activeGroupId;
      groupToIds.putIfAbsent(g, () => <String>[]);
      groupToIds[g]!.add(tab.id);
    }

    final movedIds = List<String>.from(groupToIds[groupId] ?? const <String>[]);
    if (movedIds.isNotEmpty) {
      final targetIds = groupToIds.putIfAbsent(targetGroupId, () => <String>[]);
      targetIds.addAll(movedIds);
      for (final id in movedIds) {
        _tabToGroup[id] = targetGroupId;
      }
      _groupActiveTabId[targetGroupId] = movedIds.last;
    }

    _groupOrder.remove(groupId);
    _groupActiveTabId.remove(groupId);
    if (_activeGroupId == groupId) {
      _activeGroupId = targetGroupId;
    }

    final orderedIds = <String>[];
    for (final g in _groupOrder) {
      orderedIds.addAll(groupToIds[g] ?? const <String>[]);
    }
    ref.read(editorAreaProvider.notifier).reorderTabsByIdOrder(orderedIds);

    final activateId = _groupActiveTabId[targetGroupId];
    if (activateId != null &&
        state.tabGroup.tabs.any((t) => t.id == activateId)) {
      ref.read(editorAreaProvider.notifier).activateTab(activateId);
    }
    setState(() {});
  }

  void _swapGroupWithNeighbor(int groupId, {required bool withLeft}) {
    final idx = _groupOrder.indexOf(groupId);
    if (idx == -1) return;
    final neighbor = withLeft ? idx - 1 : idx + 1;
    if (neighbor < 0 || neighbor >= _groupOrder.length) return;
    final tmp = _groupOrder[idx];
    _groupOrder[idx] = _groupOrder[neighbor];
    _groupOrder[neighbor] = tmp;
    setState(() {});
  }

  List<ContextMenuItem> _buildDiffContextItems(
    EditorTabModel tab,
    int groupId,
    List<int> visibleGroups,
  ) {
    final items = <ContextMenuItem>[];
    final idx = visibleGroups.indexOf(groupId);

    if (_groupOrder.length < _maxEditorGroups) {
      items.add(
        ContextMenuItem(
          label: context.tr('menu.openInNewEditor'),
          onTap: () => _moveTabToNewGroup(tab.id),
        ),
      );
    }
    if (idx > 0) {
      items.add(
        ContextMenuItem(
          label: context.tr('menu.moveTabToLeftEditor'),
          onTap:
              () => _moveTabToGroup(
                tab.id,
                targetGroupId: visibleGroups[idx - 1],
                targetIndex: null,
              ),
        ),
      );
      items.add(
        ContextMenuItem(
          label: context.tr('menu.swapEditorWithLeft'),
          onTap: () => _swapGroupWithNeighbor(groupId, withLeft: true),
        ),
      );
    }
    if (idx >= 0 && idx < visibleGroups.length - 1) {
      items.add(
        ContextMenuItem(
          label: context.tr('menu.moveTabToRightEditor'),
          onTap:
              () => _moveTabToGroup(
                tab.id,
                targetGroupId: visibleGroups[idx + 1],
                targetIndex: null,
              ),
        ),
      );
      items.add(
        ContextMenuItem(
          label: context.tr('menu.swapEditorWithRight'),
          onTap: () => _swapGroupWithNeighbor(groupId, withLeft: false),
        ),
      );
    }
    if (visibleGroups.length > 1) {
      items.add(
        ContextMenuItem(
          label: context.tr('menu.closeEditorGroup'),
          onTap: () => _closeEditorGroup(groupId),
        ),
      );
    }
    return items;
  }

  Widget _buildTabContent(EditorTabModel activeTab, int groupId) {
    if (activeTab.isSettings) {
      return SettingsTab(
        key: ValueKey(
          'settings_${groupId}_${activeTab.id}_${activeTab.settingsSection}',
        ),
        tab: activeTab,
      );
    }
    if (activeTab.isBinary) {
      return BinaryFileTab(
        key: ValueKey('binary_${groupId}_${activeTab.id}'),
        tab: activeTab,
      );
    }
    return EditorContent(
      key: ValueKey('${groupId}_${activeTab.id}'),
      tab: activeTab,
    );
  }

  void _applyTimelineCompareRequest(String currentTabId, String snapshotTabId) {
    final tabs = ref.read(editorAreaProvider).tabGroup.tabs;
    final hasCurrent = tabs.any((t) => t.id == currentTabId);
    final hasSnapshot = tabs.any((t) => t.id == snapshotTabId);
    if (!hasCurrent || !hasSnapshot) return;

    final visibleGroups = List<int>.from(_groupOrder);
    int currentGroupId;
    int snapshotGroupId;

    if (visibleGroups.length >= 3) {
      currentGroupId = visibleGroups[1];
      snapshotGroupId = visibleGroups[2];
    } else if (visibleGroups.length == 2) {
      currentGroupId = visibleGroups[0];
      snapshotGroupId = visibleGroups[1];
    } else {
      currentGroupId = visibleGroups.first;
      snapshotGroupId = _nextGroupId++;
      _groupOrder.add(snapshotGroupId);
    }

    _moveTabToGroup(
      currentTabId,
      targetGroupId: currentGroupId,
      targetIndex: null,
      activate: true,
      keepSourceGroupWhenEmpty: true,
    );
    _moveTabToGroup(
      snapshotTabId,
      targetGroupId: snapshotGroupId,
      targetIndex: null,
      activate: false,
      keepSourceGroupWhenEmpty: true,
    );
    _activeGroupId = currentGroupId;
    ref.read(editorAreaProvider.notifier).activateTab(currentTabId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorAreaProvider);
    final allTabs = state.tabGroup.tabs;
    final hasOpenTabs = allTabs.isNotEmpty;

    _syncAssignments(state);

    ref.listen(editorAreaProvider, (prev, next) {
      if (next.tabGroup.tabs.isEmpty) {
        ref.read(statusInfoProvider.notifier).clear();
      }
    });
    ref.listen(timelineCompareRequestProvider, (prev, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyTimelineCompareRequest(next.currentTabId, next.snapshotTabId);
        ref.read(timelineCompareRequestProvider.notifier).state = null;
      });
    });

    final visibleGroups = List<int>.from(_groupOrder);

    return Container(
      color: AppColors.editorBackground,
      child:
          hasOpenTabs
              ? Row(
                children: [
                  for (int i = 0; i < visibleGroups.length; i++) ...[
                    Expanded(
                      child: _EditorGroupPane(
                        groupId: visibleGroups[i],
                        tabs: _tabsForGroup(allTabs, visibleGroups[i]),
                        activeTab: _activeTabForGroup(
                          allTabs,
                          visibleGroups[i],
                          state.tabGroup.activeTabId,
                        ),
                        onSelectTab: (id) {
                          _groupActiveTabId[visibleGroups[i]] = id;
                          _activeGroupId = visibleGroups[i];
                          ref.read(editorAreaProvider.notifier).activateTab(id);
                          setState(() {});
                        },
                        onCloseTab:
                            (id) =>
                                handleTabCloseWithSaveCheck(context, ref, id),
                        onCloseOthers:
                            (id) => ref
                                .read(editorAreaProvider.notifier)
                                .closeOtherTabs(id),
                        onCloseAll:
                            () =>
                                ref
                                    .read(editorAreaProvider.notifier)
                                    .closeAllTabs(),
                        onCloseSaved:
                            () =>
                                ref
                                    .read(editorAreaProvider.notifier)
                                    .closeSavedTabs(),
                        onReorder: (oldIndex, newIndex) {
                          final groupTabs = _tabsForGroup(
                            allTabs,
                            visibleGroups[i],
                          );
                          if (oldIndex < 0 || oldIndex >= groupTabs.length)
                            return;
                          final tabId = groupTabs[oldIndex].id;
                          _moveTabToGroup(
                            tabId,
                            targetGroupId: visibleGroups[i],
                            targetIndex: newIndex,
                            activate: false,
                          );
                        },
                        onTogglePin:
                            (id) => ref
                                .read(editorAreaProvider.notifier)
                                .togglePinTab(id),
                        onTabDetached:
                            (id) => ref
                                .read(multiWindowProvider.notifier)
                                .handleDetachedTab(id),
                        onDropToGroup:
                            (tabId, _, toGroupId, toIndex) => _moveTabToGroup(
                              tabId,
                              targetGroupId: toGroupId,
                              targetIndex: toIndex,
                            ),
                        buildExtraContextMenuItems:
                            (tab) => _buildDiffContextItems(
                              tab,
                              visibleGroups[i],
                              visibleGroups,
                            ),
                        onBackgroundMenu: (position) {
                          showAppContextMenu(context, position, [
                            ContextMenuItem(
                              label: context.tr('menu.hideEditor'),
                              shortcut: 'Ctrl+Shift+E',
                              onTap:
                                  () =>
                                      ref
                                          .read(ideShellProvider.notifier)
                                          .toggleEditor(),
                            ),
                          ]);
                        },
                        onDropIntoContent:
                            (payload) => _moveTabToGroup(
                              payload.tabId,
                              targetGroupId: visibleGroups[i],
                              targetIndex: null,
                            ),
                        buildContent:
                            (tab) => _buildTabContent(tab, visibleGroups[i]),
                      ),
                    ),
                    if (i < visibleGroups.length - 1)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                  ],
                ],
              )
              : const WelcomeTab(),
    );
  }
}

class _EditorGroupPane extends StatelessWidget {
  const _EditorGroupPane({
    required this.groupId,
    required this.tabs,
    required this.activeTab,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onCloseOthers,
    required this.onCloseAll,
    required this.onCloseSaved,
    required this.onReorder,
    required this.onTogglePin,
    required this.onTabDetached,
    required this.onDropToGroup,
    required this.buildExtraContextMenuItems,
    required this.onBackgroundMenu,
    required this.onDropIntoContent,
    required this.buildContent,
  });

  final int groupId;
  final List<EditorTabModel> tabs;
  final EditorTabModel? activeTab;
  final void Function(String id) onSelectTab;
  final void Function(String id) onCloseTab;
  final void Function(String id) onCloseOthers;
  final VoidCallback onCloseAll;
  final VoidCallback onCloseSaved;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String id) onTogglePin;
  final Future<void> Function(String id) onTabDetached;
  final void Function(
    String tabId,
    int fromGroupId,
    int toGroupId,
    int? toIndex,
  )
  onDropToGroup;
  final List<ContextMenuItem> Function(EditorTabModel tab)
  buildExtraContextMenuItems;
  final void Function(Offset position) onBackgroundMenu;
  final void Function(TabDragPayload payload) onDropIntoContent;
  final Widget Function(EditorTabModel tab) buildContent;

  @override
  Widget build(BuildContext context) {
    final tab = activeTab;
    return DragTarget<TabDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDropIntoContent(details.data),
      builder:
          (context, candidateData, rejectedData) => Column(
            children: [
              GestureDetector(
                onSecondaryTapUp:
                    (details) => onBackgroundMenu(details.globalPosition),
                child: TabBarWidget(
                  groupId: groupId,
                  tabs: tabs,
                  activeTabId: tab?.id,
                  onTabSelected: onSelectTab,
                  onTabClosed: onCloseTab,
                  onCloseOthers: onCloseOthers,
                  onCloseAll: onCloseAll,
                  onCloseSaved: onCloseSaved,
                  onReorder: onReorder,
                  onTogglePin: onTogglePin,
                  onTabDetached: onTabDetached,
                  onDropToGroup: onDropToGroup,
                  buildExtraContextMenuItems: buildExtraContextMenuItems,
                ),
              ),
              if (tab != null && tab.filePath != null)
                BreadcrumbBar(filePath: tab.filePath),
              Expanded(
                child:
                    tab == null ? const SizedBox.shrink() : buildContent(tab),
              ),
            ],
          ),
    );
  }
}
