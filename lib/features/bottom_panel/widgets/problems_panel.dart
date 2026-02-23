import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import 'dart:async';
import '../../../l10n/app_localizations.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProblemsPanel extends ConsumerStatefulWidget {
  const ProblemsPanel({super.key});

  @override
  ConsumerState<ProblemsPanel> createState() => _ProblemsPanelState();
}

class _ProblemsPanelState extends ConsumerState<ProblemsPanel> {
  bool _showErrors = true;
  bool _showWarnings = true;
  bool _showInfo = true;

  @override
  Widget build(BuildContext context) {
    ref.watch(editorAreaProvider);
    final diagnostics =
        ref.read(editorAreaProvider.notifier).collectDiagnostics();

    final filtered = diagnostics.where((item) {
      switch (item.diagnostic.severity) {
        case 1:
          return _showErrors;
        case 2:
          return _showWarnings;
        case 3:
          return _showInfo;
        default:
          return _showInfo;
      }
    }).toList();

    return Container(
      color: AppColors.panelBase,
      child: Column(
        children: [
          _buildFilterBar(context, diagnostics),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      context.tr('panel.problems.empty'),
                      style: AppTextStyles.terminal.copyWith(
                        color: AppColors.secondaryForeground,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 4,
                    ),
                    children: _buildFileGroups(context, ref, filtered),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    List<EditorDiagnosticItem> allDiagnostics,
  ) {
    int errors = 0;
    int warnings = 0;
    int infos = 0;
    for (final item in allDiagnostics) {
      switch (item.diagnostic.severity) {
        case 1:
          errors++;
          break;
        case 2:
          warnings++;
          break;
        case 3:
          infos++;
          break;
        default:
          infos++;
      }
    }
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _FilterChip(
            icon: Icons.error_outline,
            label: '$errors',
            color: Colors.redAccent,
            active: _showErrors,
            onTap: () => setState(() => _showErrors = !_showErrors),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            icon: Icons.warning_amber_outlined,
            label: '$warnings',
            color: Colors.amber,
            active: _showWarnings,
            onTap: () => setState(() => _showWarnings = !_showWarnings),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            icon: Icons.info_outline,
            label: '$infos',
            color: Colors.lightBlueAccent,
            active: _showInfo,
            onTap: () => setState(() => _showInfo = !_showInfo),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFileGroups(
    BuildContext context,
    WidgetRef ref,
    List<EditorDiagnosticItem> diagnostics,
  ) {
    final grouped = <String, List<EditorDiagnosticItem>>{};
    for (final item in diagnostics) {
      grouped.putIfAbsent(item.fileName, () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final fileName in keys) {
      final entries = grouped[fileName]!;
      entries.sort((a, b) {
        final sa = a.diagnostic.severity;
        final sb = b.diagnostic.severity;
        if (sa != sb) return sa.compareTo(sb);
        return a.diagnostic.startLine.compareTo(b.diagnostic.startLine);
      });
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 12,
                      color: AppColors.secondaryForeground,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        fileName,
                        style: AppTextStyles.uiSmall.copyWith(
                          color: AppColors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entries.length}',
                      style: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.secondaryForeground,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              ...entries.map((item) {
                final diagnostic = item.diagnostic;
                final severityColor = _severityColor(diagnostic.severity);
                final location =
                    '${diagnostic.startLine + 1}:${diagnostic.startCharacter + 1}';
                return InkWell(
                  onTap: () {
                    final notifier = ref.read(editorAreaProvider.notifier);
                    if (item.tabId.isNotEmpty) {
                      notifier.activateTab(item.tabId);
                      final controller = notifier.getController(item.tabId);
                      if (controller == null) return;
                      controller.selection = CodeLineSelection.collapsed(
                        index: diagnostic.startLine,
                        offset: diagnostic.startCharacter,
                      );
                      controller.makeCursorCenterIfInvisible();
                      return;
                    }
                    if (item.filePath == null) return;
                    unawaited(() async {
                      final name = item.filePath!.split(RegExp(r'[\\/]')).last;
                      await notifier.openTab(name, item.filePath!);
                      final activeId = notifier.state.tabGroup.activeTabId;
                      if (activeId == null) return;
                      final controller = notifier.getController(activeId);
                      if (controller == null) return;
                      controller.selection = CodeLineSelection.collapsed(
                        index: diagnostic.startLine,
                        offset: diagnostic.startCharacter,
                      );
                      controller.makeCursorCenterIfInvisible();
                    }());
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 3, 8, 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _severityIcon(diagnostic.severity),
                          size: 12,
                          color: severityColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            diagnostic.message,
                            style: AppTextStyles.uiSmall.copyWith(
                              color: AppColors.foreground,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          location,
                          style: AppTextStyles.uiSmall.copyWith(
                            color: AppColors.secondaryForeground,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static Color _severityColor(int severity) {
    switch (severity) {
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.lightBlueAccent;
      default:
        return AppColors.secondaryForeground;
    }
  }

  static IconData _severityIcon(int severity) {
    switch (severity) {
      case 1:
        return Icons.error_outline;
      case 2:
        return Icons.warning_amber_outlined;
      case 3:
        return Icons.info_outline;
      default:
        return Icons.lightbulb_outline;
    }
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: widget.active
                ? widget.color.withValues(alpha: 0.18)
                : _hovering
                    ? AppColors.listHoverBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 11,
                color: widget.active
                    ? widget.color
                    : AppColors.secondaryForeground,
              ),
              const SizedBox(width: 3),
              Text(
                widget.label,
                style: AppTextStyles.uiSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: widget.active
                      ? widget.color
                      : AppColors.secondaryForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
