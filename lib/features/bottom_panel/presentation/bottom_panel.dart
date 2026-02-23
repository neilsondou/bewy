import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../shell/presentation/ide_shell_provider.dart';
import 'bottom_panel_provider.dart';
import '../presentation/terminal_provider.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/output_panel.dart';
import '../widgets/problems_panel.dart';

class BottomPanel extends ConsumerWidget {
  const BottomPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bottomPanelProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          // Minimal tab row
          GestureDetector(
            onSecondaryTapUp: (details) {
              showAppContextMenu(context, details.globalPosition, [
                ContextMenuItem(
                  label: context.tr('menu.hidePanel'),
                  icon: Icons.visibility_off_outlined,
                  shortcut: 'Ctrl+J',
                  onTap:
                      () =>
                          ref
                              .read(ideShellProvider.notifier)
                              .toggleBottomPanel(),
                ),
              ]);
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _MiniTab(
                    label: context.tr('panel.terminal'),
                    isActive: state.activeTab == 'terminal',
                    onTap:
                        () => ref
                            .read(bottomPanelProvider.notifier)
                            .setActiveTab('terminal'),
                  ),
                  _MiniTab(
                    label: context.tr('panel.output'),
                    isActive: state.activeTab == 'output',
                    onTap:
                        () => ref
                            .read(bottomPanelProvider.notifier)
                            .setActiveTab('output'),
                  ),
                  _MiniTab(
                    label: context.tr('panel.problems'),
                    isActive: state.activeTab == 'problems',
                    onTap:
                        () => ref
                            .read(bottomPanelProvider.notifier)
                            .setActiveTab('problems'),
                  ),
                  const Spacer(),
                  if (state.activeTab == 'terminal')
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: const _TerminalHeaderActions(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildContent(state.activeTab)),
        ],
      ),
    );
  }

  Widget _buildContent(String tab) {
    switch (tab) {
      case 'terminal':
        return const TerminalPanel();
      case 'output':
        return const OutputPanel();
      case 'problems':
        return const ProblemsPanel();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TerminalHeaderActions extends ConsumerWidget {
  const _TerminalHeaderActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderIcon(
          icon: Icons.add,
          tooltip: context.tr('terminal.newSession'),
          onTap:
              () => ref
                  .read(terminalProvider.notifier)
                  .createSession(),
        ),
        const SizedBox(width: 1),
        _HeaderIcon(
          icon: Icons.not_interested_outlined,
          tooltip: context.tr('terminal.interrupt'),
          onTap: () => ref.read(terminalProvider.notifier).sendCtrlCToActive(),
        ),
        const SizedBox(width: 1),
        _HeaderIcon(
          icon: Icons.restart_alt,
          tooltip: context.tr('terminal.restartSession'),
          onTap:
              () => ref.read(terminalProvider.notifier).restartActiveSession(),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          width: 18,
          height: 18,
          child: Icon(icon, size: 11, color: AppColors.secondaryForeground),
        ),
      ),
    );
  }
}

class _MiniTab extends StatefulWidget {
  const _MiniTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_MiniTab> createState() => _MiniTabState();
}

class _MiniTabState extends State<_MiniTab> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color:
                _isHovering && !widget.isActive
                    ? AppColors.hoverHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              color:
                  widget.isActive
                      ? AppColors.foreground
                      : AppColors.secondaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}
