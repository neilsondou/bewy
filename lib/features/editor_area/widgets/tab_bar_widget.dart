import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_menu.dart';
import '../models/editor_tab_model.dart';
import 'editor_tab.dart';

class TabDragPayload {
  const TabDragPayload({
    required this.tabId,
    required this.sourceGroupId,
    required this.sourceIndex,
  });

  final String tabId;
  final int sourceGroupId;
  final int sourceIndex;
}

class TabBarWidget extends StatefulWidget {
  const TabBarWidget({
    super.key,
    required this.groupId,
    required this.tabs,
    this.activeTabId,
    required this.onTabSelected,
    required this.onTabClosed,
    this.onCloseOthers,
    this.onCloseAll,
    this.onCloseSaved,
    this.onReorder,
    this.onTogglePin,
    this.onTabDetached,
    this.onDropToGroup,
    this.buildExtraContextMenuItems,
  });

  final int groupId;
  final List<EditorTabModel> tabs;
  final String? activeTabId;
  final void Function(String id) onTabSelected;
  final void Function(String id) onTabClosed;
  final void Function(String id)? onCloseOthers;
  final VoidCallback? onCloseAll;
  final VoidCallback? onCloseSaved;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(String id)? onTogglePin;
  final Future<void> Function(String id)? onTabDetached;
  final void Function(
    String tabId,
    int fromGroupId,
    int toGroupId,
    int? toIndex,
  )?
  onDropToGroup;
  final List<ContextMenuItem> Function(EditorTabModel tab)?
  buildExtraContextMenuItems;

  @override
  State<TabBarWidget> createState() => _TabBarWidgetState();
}

class _TabBarWidgetState extends State<TabBarWidget> {
  final ScrollController _scrollController = ScrollController();
  int? _dragSourceIndex;
  int? _dropTargetIndex;
  Offset? _dragStartGlobal;
  Offset? _dragLastGlobal;
  DateTime? _dragStartedAt;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final newOffset = (_scrollController.offset + event.scrollDelta.dy).clamp(
        0.0,
        maxExtent,
      );
      _scrollController.jumpTo(newOffset);
    }
  }

  Future<bool> _isOutsideWindow(Offset globalOffset) async {
    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      const outsideThreshold = 24.0;
      return globalOffset.dx < position.dx - outsideThreshold ||
          globalOffset.dy < position.dy - outsideThreshold ||
          globalOffset.dx > position.dx + size.width + outsideThreshold ||
          globalOffset.dy > position.dy + size.height + outsideThreshold;
    } catch (_) {
      return false;
    }
  }

  bool _hasEnoughDetachDistance() {
    final start = _dragStartGlobal;
    final end = _dragLastGlobal;
    if (start == null || end == null) return false;
    const minDetachDistance = 145.0;
    return (end - start).distance >= minDetachDistance;
  }

  bool _hasEnoughDetachDuration() {
    final startedAt = _dragStartedAt;
    if (startedAt == null) return false;
    const minDetachDurationMs = 220;
    return DateTime.now().difference(startedAt).inMilliseconds >=
        minDetachDurationMs;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LayoutConstants.tabBarHeight,
      decoration: BoxDecoration(
        color: AppColors.panelBase,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.tabs.length + 1,
          itemBuilder: (context, index) {
            if (index == widget.tabs.length) {
              return DragTarget<TabDragPayload>(
                onWillAcceptWithDetails: (details) {
                  setState(() => _dropTargetIndex = index);
                  return true;
                },
                onLeave: (_) {
                  if (_dropTargetIndex == index) {
                    setState(() => _dropTargetIndex = null);
                  }
                },
                onAcceptWithDetails: (details) {
                  final payload = details.data;
                  if (payload.sourceGroupId == widget.groupId) {
                    widget.onReorder?.call(
                      payload.sourceIndex,
                      widget.tabs.length,
                    );
                  } else {
                    widget.onDropToGroup?.call(
                      payload.tabId,
                      payload.sourceGroupId,
                      widget.groupId,
                      widget.tabs.length,
                    );
                  }
                  setState(() {
                    _dragSourceIndex = null;
                    _dropTargetIndex = null;
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final showIndicator =
                      _dropTargetIndex == index && _dragSourceIndex != null;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showIndicator)
                        Container(
                          width: 2,
                          height: LayoutConstants.tabBarHeight - 10,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      const SizedBox(
                        width: 32,
                        height: LayoutConstants.tabBarHeight,
                      ),
                    ],
                  );
                },
              );
            }
            final tab = widget.tabs[index];
            return _buildDraggableTab(tab, index);
          },
        ),
      ),
    );
  }

  Widget _buildDraggableTab(EditorTabModel tab, int index) {
    return DragTarget<TabDragPayload>(
      onWillAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceGroupId == widget.groupId &&
            payload.sourceIndex == index) {
          return false;
        }
        setState(() => _dropTargetIndex = index);
        return true;
      },
      onLeave: (_) {
        if (_dropTargetIndex == index) {
          setState(() => _dropTargetIndex = null);
        }
      },
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.sourceGroupId == widget.groupId) {
          widget.onReorder?.call(payload.sourceIndex, index);
        } else {
          widget.onDropToGroup?.call(
            payload.tabId,
            payload.sourceGroupId,
            widget.groupId,
            index,
          );
        }
        setState(() {
          _dragSourceIndex = null;
          _dropTargetIndex = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final showIndicator =
            _dropTargetIndex == index &&
            _dragSourceIndex != null &&
            _dragSourceIndex != index;

        final tabWidget = EditorTab(
          key: ValueKey(tab.id),
          tab: tab,
          isActive: tab.id == widget.activeTabId,
          onTap: () => widget.onTabSelected(tab.id),
          onClose: () => widget.onTabClosed(tab.id),
          onSecondaryTapUp: (details) {
            final extra =
                widget.buildExtraContextMenuItems?.call(tab) ?? const [];
            showAppContextMenu(context, details.globalPosition, [
              ContextMenuItem(
                label:
                    tab.isPinned
                        ? context.tr('menu.unpinTab')
                        : context.tr('menu.pinTab'),
                icon: Icons.push_pin,
                onTap: () => widget.onTogglePin?.call(tab.id),
              ),
              const ContextMenuSeparator(),
              ContextMenuItem(
                label: context.tr('menu.closeTab'),
                icon: Icons.close,
                shortcut: 'Ctrl+W',
                onTap: () => widget.onTabClosed(tab.id),
              ),
              ContextMenuItem(
                label: context.tr('menu.closeOthers'),
                onTap: () => widget.onCloseOthers?.call(tab.id),
              ),
              ContextMenuItem(
                label: context.tr('menu.closeAll'),
                onTap: () => widget.onCloseAll?.call(),
              ),
              ContextMenuItem(
                label: context.tr('menu.closeSaved'),
                onTap: () => widget.onCloseSaved?.call(),
              ),
              if (extra.isNotEmpty) ...[const ContextMenuSeparator(), ...extra],
            ]);
          },
        );

        return Draggable<TabDragPayload>(
          data: TabDragPayload(
            tabId: tab.id,
            sourceGroupId: widget.groupId,
            sourceIndex: index,
          ),
          feedback: Material(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: Container(
                height: LayoutConstants.tabBarHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.fileName, style: AppTextStyles.tabActive),
                  ],
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: tabWidget),
          onDragStarted:
              () => setState(() {
                _dragSourceIndex = index;
                _dragStartGlobal = null;
                _dragLastGlobal = null;
                _dragStartedAt = DateTime.now();
              }),
          onDragUpdate: (details) {
            _dragStartGlobal ??= details.globalPosition;
            _dragLastGlobal = details.globalPosition;
          },
          onDragEnd: (details) async {
            final endPos = _dragLastGlobal ?? details.offset;
            final detached =
                !details.wasAccepted &&
                _hasEnoughDetachDistance() &&
                _hasEnoughDetachDuration() &&
                await _isOutsideWindow(endPos);
            if (detached && mounted) {
              await widget.onTabDetached?.call(tab.id);
            }
            if (!mounted) return;
            setState(() {
              _dragSourceIndex = null;
              _dropTargetIndex = null;
              _dragStartGlobal = null;
              _dragLastGlobal = null;
              _dragStartedAt = null;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIndicator)
                Container(
                  width: 2,
                  height: LayoutConstants.tabBarHeight - 10,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              tabWidget,
            ],
          ),
        );
      },
    );
  }
}
