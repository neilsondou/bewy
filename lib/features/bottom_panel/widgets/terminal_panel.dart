import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_menu.dart';
import '../presentation/terminal_provider.dart';
import '../presentation/terminal_settings_provider.dart';

class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  bool _autoCreated = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalProvider);
    final settings = ref.watch(terminalSettingsProvider);

    // Auto-create a CMD session when the panel is first shown with no sessions.
    if (!_autoCreated && state.sessions.isEmpty && state.profiles.isNotEmpty) {
      _autoCreated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Re-check: another path may have already created a session.
        if (ref.read(terminalProvider).sessions.isEmpty) {
          ref.read(terminalProvider.notifier).createSession();
        }
      });
    }

    final activeId = state.activeSessionId;
    final activeTerminal =
        activeId == null
            ? null
            : ref.read(terminalProvider.notifier).terminalForSession(activeId);
    final activeOutput =
        activeId == null
            ? ''
            : ref.read(terminalProvider.notifier).outputForSession(activeId);

    return Container(
      color: AppColors.terminalBackground,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.terminalBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:
                        activeTerminal == null
                            ? const SizedBox.shrink()
                            : GestureDetector(
                              onSecondaryTapDown: (details) {
                                _showTerminalContextMenu(
                                  context,
                                  details.globalPosition,
                                  activeOutput,
                                  ref,
                                  activeId,
                                );
                              },
                              child: TerminalView(
                                activeTerminal,
                                autofocus: true,
                                backgroundOpacity: 1,
                                textStyle: TerminalStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: settings.fontSize,
                                ),
                                theme: TerminalTheme(
                                  cursor: AppColors.accent,
                                  selection:
                                      AppColors.listActiveSelectionBackground,
                                  foreground: AppColors.terminalForeground,
                                  background: AppColors.terminalBackground,
                                  black: const Color(0xFF000000),
                                  red: const Color(0xFFCD3131),
                                  green: const Color(0xFF0DBC79),
                                  yellow: const Color(0xFFE5E510),
                                  blue: const Color(0xFF2472C8),
                                  magenta: const Color(0xFFBC3FBC),
                                  cyan: const Color(0xFF11A8CD),
                                  white: const Color(0xFFE5E5E5),
                                  brightBlack: const Color(0xFF666666),
                                  brightRed: const Color(0xFFF14C4C),
                                  brightGreen: const Color(0xFF23D18B),
                                  brightYellow: const Color(0xFFF5F543),
                                  brightBlue: const Color(0xFF3B8EEA),
                                  brightMagenta: const Color(0xFFD670D6),
                                  brightCyan: const Color(0xFF29B8DB),
                                  brightWhite: const Color(0xFFFFFFFF),
                                  searchHitBackground:
                                      AppColors.listHoverBackground,
                                  searchHitBackgroundCurrent:
                                      AppColors.listActiveSelectionBackground,
                                  searchHitForeground:
                                      AppColors.terminalForeground,
                                ),
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 112,
                  decoration: BoxDecoration(
                    color: AppColors.panelBase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    itemCount: state.sessions.length,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(terminalProvider.notifier)
                          .reorderSessions(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final s = state.sessions[index];
                      final activeRow = s.id == state.activeSessionId;
                      return ReorderableDragStartListener(
                        key: ValueKey(s.id),
                        index: index,
                        child: _SessionTile(
                          icon: _profileIcon(s.profileId),
                          sessionName: s.name,
                          active: activeRow,
                          onTap:
                              () => ref
                                  .read(terminalProvider.notifier)
                                  .activateSession(s.id),
                          onClose:
                              () => ref
                                  .read(terminalProvider.notifier)
                                  .closeSession(s.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTerminalContextMenu(
    BuildContext context,
    Offset position,
    String output,
    WidgetRef ref,
    String? activeId,
  ) {
    final items = <ContextMenuItem>[
      ContextMenuItem(
        label: context.tr('terminal.copyOutput'),
        icon: Icons.content_copy_outlined,
        onTap:
            output.isEmpty
                ? null
                : () async {
                  await Clipboard.setData(ClipboardData(text: output));
                },
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('terminal.clearOutput'),
        icon: Icons.delete_outline,
        onTap: () {
          ref.read(terminalProvider.notifier).clearActiveOutput();
        },
      ),
      ContextMenuItem(
        label: context.tr('terminal.restartSession'),
        icon: Icons.refresh,
        onTap: () {
          ref.read(terminalProvider.notifier).restartActiveSession();
        },
      ),
    ];
    showAppContextMenu(context, position, items);
  }

  IconData _profileIcon(String profileId) {
    return Icons.terminal;
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.icon,
    required this.sessionName,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final IconData icon;
  final String sessionName;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        height: 24,
        decoration: BoxDecoration(
          color:
              active
                  ? AppColors.listActiveSelectionBackground
                  : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: AppColors.secondaryForeground),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                sessionName,
                style: AppTextStyles.uiSmall.copyWith(fontSize: 10.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 16,
                height: 16,
                child: Icon(
                  Icons.close,
                  size: 11,
                  color: AppColors.secondaryForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
