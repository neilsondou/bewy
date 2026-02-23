import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart' as charset;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../../editor_area/presentation/editor_settings_provider.dart';
import '../../bottom_panel/presentation/bottom_panel_provider.dart';
import '../../shell/presentation/ide_shell_provider.dart';
import '../widgets/status_bar_item.dart';
import 'status_info_provider.dart';
import 'status_notification_provider.dart';

const kEncodings = <(String, String)>[
  ('UTF-8', 'utf8'),
  ('UTF-8 with BOM', 'utf8bom'),
  ('UTF-16 LE', 'utf16le'),
  ('UTF-16 BE', 'utf16be'),
  ('ASCII', 'ascii'),
  ('ISO 8859-1 (Latin-1)', 'latin1'),
  ('ISO 8859-15 (Latin-9)', 'latin9'),
  ('Windows-1252', 'windows1252'),
  ('GBK', 'gbk'),
  ('GB2312', 'gb2312'),
  ('GB18030', 'gb18030'),
  ('Big5', 'big5'),
  ('Shift_JIS', 'shiftjis'),
  ('EUC-JP', 'eucjp'),
  ('EUC-KR', 'euckr'),
  ('Windows-1251', 'windows1251'),
  ('KOI8-R', 'koi8r'),
  ('ISO 8859-5', 'iso88595'),
];

Encoding? _codecForKey(String key) {
  switch (key) {
    case 'utf8':
    case 'utf8bom':
      return const Utf8Codec(allowMalformed: true);
    case 'utf16le':
    case 'utf16be':
      return charset.utf16;
    case 'ascii':
      return const AsciiCodec(allowInvalid: true);
    case 'latin1':
    case 'latin9':
    case 'windows1252':
      return latin1;
    case 'gbk':
    case 'gb2312':
    case 'gb18030':
      return charset.gbk;
    case 'big5':
      return charset.gbk;
    case 'shiftjis':
      return charset.shiftJis;
    case 'eucjp':
      return charset.eucJp;
    case 'euckr':
      return charset.eucKr;
    case 'windows1251':
      return charset.windows1251;
    case 'koi8r':
    case 'iso88595':
      return charset.latinCyrillic;
    default:
      return null;
  }
}

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(statusInfoProvider);
    final hasEditor = ref.watch(editorAreaProvider).tabGroup.tabs.isNotEmpty;
    final settings = ref.watch(editorSettingsProvider);
    final notification = ref.watch(statusNotificationProvider);
    final shell = ref.watch(ideShellProvider);
    final bottomPanel = ref.watch(bottomPanelProvider);
    final diagnosticsSummary =
        ref.read(editorAreaProvider.notifier).collectDiagnosticsSummary();
    final scanProgress =
        ref.read(editorAreaProvider.notifier).workspaceDiagnosticsProgress;
    final lspConnections =
        ref.read(editorAreaProvider.notifier).collectLspConnections();
    final lspModeEnabled =
        settings.diagnosticsEngine == DiagnosticsEngine.languageServer;
    final totalProblems =
        diagnosticsSummary.errorCount +
        diagnosticsSummary.warningCount +
        diagnosticsSummary.infoCount;

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showStatusBarContextMenu(context, ref, details.globalPosition, shell);
      },
      child: Container(
        height: LayoutConstants.statusBarHeight + 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 2),
        child: Row(
          children: [
            _PanelToggleButton(
              icon: Icons.view_sidebar_outlined,
              tooltip: context.tr('status.tooltip.toggleSidebar'),
              isActive: shell.sideBarWidth > 0,
              onTap: () => ref.read(ideShellProvider.notifier).toggleSidebar(),
            ),
            const SizedBox(width: 2),
            _PanelToggleButton(
              icon: Icons.web_asset_outlined,
              tooltip: context.tr('status.tooltip.toggleEditor'),
              isActive: shell.editorVisible,
              onTap: () => ref.read(ideShellProvider.notifier).toggleEditor(),
            ),
            const SizedBox(width: 2),
            _PanelToggleButton(
              icon: Icons.terminal_outlined,
              tooltip: context.tr('status.tooltip.togglePanel'),
              isActive: shell.bottomPanelVisible,
              onTap: () {
                final shellNotifier = ref.read(ideShellProvider.notifier);
                final panelNotifier = ref.read(bottomPanelProvider.notifier);
                if (!shell.bottomPanelVisible) {
                  panelNotifier.setActiveTab('problems');
                  shellNotifier.setBottomPanelVisible(true);
                  return;
                }
                if (bottomPanel.activeTab != 'problems') {
                  panelNotifier.setActiveTab('problems');
                  return;
                }
                shellNotifier.toggleBottomPanel();
              },
            ),
            const SizedBox(width: 8),
            _StatusIssueButton(
              icon: Icons.memory_outlined,
              label: 'LSP',
              count: lspConnections.length,
              onTap:
                  lspModeEnabled
                      ? () => _showLspConnectionsPanel(context, lspConnections)
                      : null,
            ),
            const SizedBox(width: 4),
            _StatusIssueButton(
              icon: Icons.bug_report_outlined,
              label: context.tr('status.problems'),
              count: totalProblems,
              onTap:
                  () => _jumpToNextDiagnostic(context, ref, 'problems', null),
            ),
            const SizedBox(width: 4),
            _StatusIssueButton(
              icon: Icons.error_outline,
              label: context.tr('status.errors'),
              count: diagnosticsSummary.errorCount,
              onTap: () => _jumpToNextDiagnostic(context, ref, 'errors', 1),
            ),
            const SizedBox(width: 4),
            _StatusIssueButton(
              icon: Icons.warning_amber_outlined,
              label: context.tr('status.warnings'),
              count: diagnosticsSummary.warningCount,
              onTap: () => _jumpToNextDiagnostic(context, ref, 'warnings', 2),
            ),
            if (scanProgress.isActive) ...[
              const SizedBox(width: 8),
              _WorkspaceScanProgressIndicator(progress: scanProgress),
            ],
            if (notification != null) ...[
              const SizedBox(width: 8),
              _StatusNotification(notification: notification),
            ],
            const Spacer(),
            if (hasEditor && info.hasActiveEditor) ...[
              StatusBarItem(
                label:
                    context.isZh
                        ? '行 ${info.line}, 列 ${info.column}'
                        : 'Ln ${info.line}, Col ${info.column}',
              ),
              if (info.hasSelection) ...[
                const SizedBox(width: 8),
                StatusBarItem(
                  label:
                      info.selectedLines > 1
                          ? '${info.selectedChars} ${context.tr('status.chars')} (${info.selectedLines} ${context.tr('status.lines')})'
                          : '${info.selectedChars} ${context.tr('status.selected')}',
                ),
              ],
              const SizedBox(width: 8),
              StatusBarItem(
                label:
                    settings.useSpaces
                        ? '${context.tr('status.spaces')}: ${settings.indentSize}'
                        : '${context.tr('status.tabSize')}: ${settings.indentSize}',
                tooltip: context.tr('status.tooltip.selectIndentation'),
                onTap: (itemCtx) => _showIndentMenu(itemCtx, ref, settings),
              ),
              const SizedBox(width: 8),
              StatusBarItem(
                label: info.lineEnding,
                tooltip: context.tr('status.tooltip.selectLineEnding'),
                onTap:
                    (itemCtx) =>
                        _showLineEndingMenu(itemCtx, ref, info.lineEnding),
              ),
              const SizedBox(width: 8),
              StatusBarItem(
                label: info.encoding,
                tooltip: context.tr('status.tooltip.selectEncoding'),
                onTap:
                    (itemCtx) =>
                        _showEncodingActionMenu(itemCtx, ref, info.encoding),
              ),
              const SizedBox(width: 8),
              StatusBarItem(label: info.language),
              const SizedBox(width: 8),
              StatusBarItem(
                label:
                    settings.wordWrap
                        ? context.tr('status.wrap')
                        : context.tr('status.noWrap'),
                tooltip: context.tr('status.tooltip.toggleWordWrap'),
                onTap:
                    (_) =>
                        ref
                            .read(editorSettingsProvider.notifier)
                            .toggleWordWrap(),
              ),
              const SizedBox(width: 8),
            ],
            _StatusBarUpdateButton(),
            const SizedBox(width: 2),
            _StatusBarIconButton(
              icon: Icons.receipt_long_outlined,
              tooltip: context.tr('status.tooltip.runtimeLogs'),
              onTap: () {
                final logDir = AppLogService.instance.logDirPath;
                final dir = Directory(logDir);
                if (!dir.existsSync()) {
                  dir.createSync(recursive: true);
                }
                if (Platform.isWindows) {
                  Process.run('explorer', [logDir]);
                } else if (Platform.isMacOS) {
                  Process.run('open', [logDir]);
                } else {
                  Process.run('xdg-open', [logDir]);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showIndentMenu(
    BuildContext itemContext,
    WidgetRef ref,
    EditorSettingsState settings,
  ) {
    showAppContextMenu(itemContext, _positionAboveItem(itemContext), [
      ContextMenuItem(
        label: itemContext.tr('status.spaces'),
        icon: settings.useSpaces ? Icons.check : null,
        onTap: () {
          ref.read(editorSettingsProvider.notifier).setUseSpaces(true);
        },
      ),
      ContextMenuItem(
        label: itemContext.tr('status.tabSize'),
        icon: !settings.useSpaces ? Icons.check : null,
        onTap: () {
          ref.read(editorSettingsProvider.notifier).setUseSpaces(false);
        },
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: '${itemContext.tr('status.tabSize')}: 2',
        icon: settings.indentSize == 2 ? Icons.check : null,
        onTap: () {
          ref.read(editorSettingsProvider.notifier).setIndentSize(2);
        },
      ),
      ContextMenuItem(
        label: '${itemContext.tr('status.tabSize')}: 4',
        icon: settings.indentSize == 4 ? Icons.check : null,
        onTap: () {
          ref.read(editorSettingsProvider.notifier).setIndentSize(4);
        },
      ),
      ContextMenuItem(
        label: '${itemContext.tr('status.tabSize')}: 8',
        icon: settings.indentSize == 8 ? Icons.check : null,
        onTap: () {
          ref.read(editorSettingsProvider.notifier).setIndentSize(8);
        },
      ),
    ]);
  }

  void _showLineEndingMenu(
    BuildContext itemContext,
    WidgetRef ref,
    String current,
  ) {
    showAppContextMenu(itemContext, _positionAboveItem(itemContext), [
      ContextMenuItem(
        label: 'LF',
        icon: current == 'LF' ? Icons.check : null,
        onTap: () {
          ref.read(statusInfoProvider.notifier).setLineEnding('LF');
          final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
          if (activeId != null) {
            ref
                .read(editorAreaProvider.notifier)
                .notifyContentChanged(activeId);
          }
        },
      ),
      ContextMenuItem(
        label: 'CRLF',
        icon: current == 'CRLF' ? Icons.check : null,
        onTap: () {
          ref.read(statusInfoProvider.notifier).setLineEnding('CRLF');
          final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
          if (activeId != null) {
            ref
                .read(editorAreaProvider.notifier)
                .notifyContentChanged(activeId);
          }
        },
      ),
    ]);
  }

  void _showEncodingActionMenu(
    BuildContext itemContext,
    WidgetRef ref,
    String current,
  ) {
    showAppContextMenu(itemContext, _positionAboveItem(itemContext), [
      ContextMenuItem(
        label: itemContext.tr('status.reopenWithEncoding'),
        icon: Icons.refresh_outlined,
        onTap: () {
          Future.microtask(() {
            if (itemContext.mounted) {
              _showEncodingList(
                itemContext,
                ref,
                current,
                _EncodingAction.reopen,
              );
            }
          });
        },
      ),
      ContextMenuItem(
        label: itemContext.tr('status.saveWithEncoding'),
        icon: Icons.save_outlined,
        onTap: () {
          Future.microtask(() {
            if (itemContext.mounted) {
              _showEncodingList(
                itemContext,
                ref,
                current,
                _EncodingAction.save,
              );
            }
          });
        },
      ),
    ]);
  }

  void _showEncodingList(
    BuildContext itemContext,
    WidgetRef ref,
    String current,
    _EncodingAction action,
  ) {
    final items =
        kEncodings.map((e) {
          return ContextMenuItem(
            label: e.$1,
            icon: current == e.$1 ? Icons.check : null,
            onTap: () {
              final activeId =
                  ref.read(editorAreaProvider).tabGroup.activeTabId;
              if (activeId == null) return;

              ref.read(statusInfoProvider.notifier).setEncoding(e.$1);
              final codec = _codecForKey(e.$2);
              if (codec == null) {
                ref
                    .read(statusNotificationProvider.notifier)
                    .show(
                      'Encoding ${e.$1} is not yet supported natively',
                      type: StatusNotificationType.info,
                    );
                return;
              }
              final isBom = e.$2 == 'utf8bom';
              if (action == _EncodingAction.reopen) {
                ref
                    .read(editorAreaProvider.notifier)
                    .reloadWithEncoding(activeId, codec, isBom: isBom);
              } else {
                ref
                    .read(editorAreaProvider.notifier)
                    .saveWithEncoding(activeId, codec, isBom: isBom);
              }
            },
          );
        }).toList();
    showAppContextMenu(itemContext, _positionAboveItem(itemContext), items);
  }

  void _showStatusBarContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    IDEShellState shell,
  ) {
    showAppContextMenu(context, position, [
      ContextMenuItem(
        label: context.tr('status.sidebar'),
        icon:
            shell.sideBarWidth > 0
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank,
        shortcut: 'Ctrl+B',
        onTap: () => ref.read(ideShellProvider.notifier).toggleSidebar(),
      ),
      ContextMenuItem(
        label: context.tr('status.editor'),
        icon:
            shell.editorVisible
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank,
        shortcut: 'Ctrl+Shift+E',
        onTap: () => ref.read(ideShellProvider.notifier).toggleEditor(),
      ),
      ContextMenuItem(
        label: context.tr('status.panel'),
        icon:
            shell.bottomPanelVisible
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank,
        shortcut: 'Ctrl+J',
        onTap: () => ref.read(ideShellProvider.notifier).toggleBottomPanel(),
      ),
    ]);
  }

  Offset _positionAboveItem(BuildContext itemContext) {
    final box = itemContext.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final pos = box.localToGlobal(Offset.zero);
    return Offset(pos.dx, pos.dy);
  }

  void _jumpToNextDiagnostic(
    BuildContext context,
    WidgetRef ref,
    String scope,
    int? severity,
  ) {
    () async {
      final shellNotifier = ref.read(ideShellProvider.notifier);
      final panelNotifier = ref.read(bottomPanelProvider.notifier);
      panelNotifier.setActiveTab('problems');
      shellNotifier.setBottomPanelVisible(true);

      final ok = await ref
          .read(editorAreaProvider.notifier)
          .jumpToNextDiagnostic(scopeKey: scope, severity: severity);
      if (!ok) {
        ref
            .read(statusNotificationProvider.notifier)
            .show(
              context.tr('panel.problems.empty'),
              type: StatusNotificationType.info,
            );
      }
    }();
  }

  void _showLspConnectionsPanel(
    BuildContext context,
    List<EditorLspConnectionItem> connections,
  ) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: AppColors.panelBase,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border),
            ),
            child: SizedBox(
              width: 540,
              height: 420,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Text(
                          context.tr('status.lspConnections'),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 14,
                            color: AppColors.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        _SquareDialogCloseButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, thickness: 1, color: AppColors.border),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child:
                          connections.isEmpty
                              ? Center(
                                child: Text(
                                  context.tr('status.lspConnections.empty'),
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 11,
                                    color: AppColors.secondaryForeground,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: connections.length,
                                itemBuilder: (context, index) {
                                  final item = connections[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.panelBackground,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.languageId,
                                          style: TextStyle(
                                            fontFamily: 'JetBrainsMono',
                                            fontSize: 12,
                                            color: AppColors.foreground,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'server: ${item.serverExecutable ?? 'unknown'}',
                                          style: TextStyle(
                                            fontFamily: 'JetBrainsMono',
                                            fontSize: 10,
                                            color:
                                                AppColors.secondaryForeground,
                                          ),
                                        ),
                                        Text(
                                          'workspace: ${item.workspacePath ?? 'unknown'}',
                                          style: TextStyle(
                                            fontFamily: 'JetBrainsMono',
                                            fontSize: 10,
                                            color:
                                                AppColors.secondaryForeground,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    AppLogService.instance.info(
      'lsp',
      'openConnectionsPanel count=${connections.length}',
    );
  }
}

class _SquareDialogCloseButton extends StatefulWidget {
  const _SquareDialogCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_SquareDialogCloseButton> createState() =>
      _SquareDialogCloseButtonState();
}

class _SquareDialogCloseButtonState extends State<_SquareDialogCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hover ? AppColors.hoverHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.close, size: 14, color: AppColors.foreground),
        ),
      ),
    );
  }
}

enum _EncodingAction { reopen, save }

class _PanelToggleButton extends StatefulWidget {
  const _PanelToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_PanelToggleButton> createState() => _PanelToggleButtonState();
}

class _PanelToggleButtonState extends State<_PanelToggleButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 22,
            height: 18,
            decoration: BoxDecoration(
              color:
                  _isHovering
                      ? AppColors.listActiveSelectionBackground
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 13,
              color:
                  widget.isActive
                      ? AppColors.statusBarForeground
                      : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusNotification extends StatelessWidget {
  const _StatusNotification({required this.notification});

  final StatusNotification notification;

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final IconData icon;
    switch (notification.type) {
      case StatusNotificationType.success:
        iconColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case StatusNotificationType.error:
        iconColor = AppColors.error;
        icon = Icons.error_outline;
        break;
      case StatusNotificationType.info:
        iconColor = AppColors.statusBarForeground;
        icon = Icons.info_outline;
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 4),
        Text(
          notification.message,
          style: context.trStyle(
            TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              color: AppColors.statusBarForeground,
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceScanProgressIndicator extends StatelessWidget {
  const _WorkspaceScanProgressIndicator({required this.progress});

  final WorkspaceDiagnosticsProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.inputBackground.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress.total > 0 ? progress.ratio : null,
          minHeight: 3,
          backgroundColor: AppColors.panelBackground,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _StatusIssueButton extends StatefulWidget {
  const _StatusIssueButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  State<_StatusIssueButton> createState() => _StatusIssueButtonState();
}

class _StatusIssueButtonState extends State<_StatusIssueButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color:
                _hover && widget.onTap != null
                    ? AppColors.listActiveSelectionBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 12,
                color:
                    widget.onTap == null
                        ? AppColors.mutedForeground
                        : AppColors.statusBarForeground,
              ),
              const SizedBox(width: 3),
              Text(
                '${widget.label} ${widget.count}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color:
                      widget.onTap == null
                          ? AppColors.mutedForeground
                          : AppColors.statusBarForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBarUpdateButton extends StatefulWidget {
  const _StatusBarUpdateButton();

  @override
  State<_StatusBarUpdateButton> createState() => _StatusBarUpdateButtonState();
}

class _StatusBarUpdateButtonState extends State<_StatusBarUpdateButton> {
  static const _currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.0.2',
  );
  static const _channelVersionUrl = 'https://bewy.dou.asia/latest-version.txt';
  bool _checking = false;
  bool _hovering = false;
  bool _done = false;
  String? _latestVersion;
  String? _error;

  Future<void> _checkUpdates() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _done = false;
      _error = null;
      _latestVersion = null;
    });
    try {
      final client =
          HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.getUrl(Uri.parse(_channelVersionUrl));
        request.followRedirects = true;
        request.headers.set(HttpHeaders.userAgentHeader, 'bewy-status-update/1');
        final response = await request.close().timeout(
          const Duration(seconds: 12),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final bytes = await response.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        final raw = utf8
            .decode(bytes, allowMalformed: true)
            .replaceFirst('\uFEFF', '');
        final matched = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(raw);
        final version = (matched?.group(1) ?? raw.trim());
        setState(() {
          _latestVersion = version;
          _done = true;
        });
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _done = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  bool _isNewerVersion(String candidate, String current) {
    List<int> parse(String s) =>
        s.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final c = parse(candidate);
    final p = parse(current);
    final len = c.length > p.length ? c.length : p.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final pv = i < p.length ? p[i] : 0;
      if (cv > pv) return true;
      if (cv < pv) return false;
    }
    return false;
  }

  String _tooltipText(BuildContext context) {
    if (_checking) return context.tr('about.checkingUpdate');
    if (_error != null) return context.tr('about.updateStatus.error');
    if (_latestVersion == null) {
      return context.tr('settings.checkForUpdates');
    }
    final hasUpdate = _isNewerVersion(_latestVersion!, _currentVersion);
    return hasUpdate
        ? context.tr('about.updateStatus.available')
        : context.tr('about.updateStatus.latest');
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate =
        _latestVersion != null &&
        _isNewerVersion(_latestVersion!, _currentVersion);

    IconData icon;
    if (_done && _error != null) {
      icon = Icons.error_outline;
    } else if (_done && _latestVersion != null && !hasUpdate) {
      icon = Icons.check_circle_outline;
    } else if (hasUpdate) {
      icon = Icons.system_update_alt;
    } else {
      icon = Icons.system_update_outlined;
    }
    final iconColor = AppColors.statusBarForeground;

    return Tooltip(
      message: _tooltipText(context),
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: _checking ? null : _checkUpdates,
          child: Container(
            width: 22,
            height: 18,
            decoration: BoxDecoration(
              color:
                  _hovering
                      ? AppColors.listActiveSelectionBackground
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: _checking
                ? SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.statusBarForeground,
                    ),
                  )
                : Icon(icon, size: 13, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _StatusBarIconButton extends StatefulWidget {
  const _StatusBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_StatusBarIconButton> createState() => _StatusBarIconButtonState();
}

class _StatusBarIconButtonState extends State<_StatusBarIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 22,
            height: 18,
            decoration: BoxDecoration(
              color:
                  _hovering
                      ? AppColors.listActiveSelectionBackground
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 13,
              color: AppColors.statusBarForeground,
            ),
          ),
        ),
      ),
    );
  }
}
