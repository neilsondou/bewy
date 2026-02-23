import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../core/models/shortcut_binding.dart';
import '../../core/providers/app_locale_provider.dart';
import '../../core/providers/app_log_provider.dart';
import '../../core/providers/file_icon_theme_provider.dart';
import '../../core/providers/shortcut_settings_provider.dart';
import '../../core/services/app_log_service.dart';
import '../../core/services/workspace_search_service.dart';
import '../../core/services/code_stats_service.dart';
import '../../core/services/language_server_install_service.dart';
import '../../core/services/config_service.dart';
import '../../core/theme/app_font_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/strings_en_us.dart';
import '../../l10n/strings_zh_cn.dart';
import '../../features/editor_area/presentation/editor_area_provider.dart';
import '../../features/editor_area/presentation/editor_settings_provider.dart';
import '../../features/file_explorer/presentation/file_explorer_provider.dart';
import '../../features/shell/presentation/ide_shell_provider.dart';
import '../../core/services/code_format_service.dart';
import '../../features/bottom_panel/presentation/terminal_provider.dart';
import '../../features/bottom_panel/presentation/terminal_settings_provider.dart';
import '../../core/services/tree_sitter_service.dart';
import '../../features/status_bar/presentation/status_notification_provider.dart';

enum SettingsSection {
  editor,
  terminal,
  languageServer,
  shortcuts,
  appearance,
  codeStats,
  openSource,
  privacy,
  about,
}

/// Reusable dark-themed dialog helpers.
class AppDialog {
  AppDialog._();

  static Future<String?> showConfirmSave(
    BuildContext context,
    String fileName,
  ) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _StyledDialog(
            title: AppLocalizations.of(ctx).t('dialog.unsaved.title'),
            content: Text(
              AppLocalizations.of(ctx)
                  .t('dialog.unsaved.saveChangesTo')
                  .replaceAll('{target}', '"$fileName"'),
              style: AppTextStyles.uiNormal,
            ),
            actions: [
              _DialogButton(
                label: AppLocalizations.of(ctx).t('dialog.unsaved.save'),
                onPressed: () => Navigator.of(ctx).pop('save'),
              ),
              _DialogButton(
                label: AppLocalizations.of(ctx).t('dialog.unsaved.dontSave'),
                onPressed: () => Navigator.of(ctx).pop('discard'),
              ),
              _DialogButton(
                label: AppLocalizations.of(ctx).t('dialog.unsaved.cancel'),
                onPressed: () => Navigator.of(ctx).pop('cancel'),
              ),
            ],
          ),
    );
  }

  static Future<String?> showInputDialog(
    BuildContext context, {
    required String title,
    String hintText = '',
    String initialValue = '',
    String confirmLabel = 'OK',
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => _StyledDialog(
            title: title,
            content: TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.uiNormal,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTextStyles.uiSmall.copyWith(
                  color: AppColors.mutedForeground,
                ),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onSubmitted: (value) => Navigator.of(ctx).pop(value),
            ),
            actions: [
              _DialogButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              _DialogButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(controller.text),
              ),
            ],
          ),
    );
  }

  static Future<bool?> showConfirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => _StyledDialog(
            title: 'Delete',
            content: Text(
              'Are you sure you want to delete "$name"?\nThe item will be moved to the Recycle Bin.',
              style: AppTextStyles.uiNormal,
            ),
            actions: [
              _DialogButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              _DialogButton(
                label: 'Delete',
                isDanger: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
    );
  }

  static Future<bool?> showConfirmOverwrite(
    BuildContext context, {
    required String name,
    required String path,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _StyledDialog(
            title: AppLocalizations.of(ctx).t('explorer.overwrite.title'),
            content: Text(
              AppLocalizations.of(ctx).t('explorer.overwrite.messagePrefix') +
                  '"$name"' +
                  AppLocalizations.of(
                    ctx,
                  ).t('explorer.overwrite.messageMiddle') +
                  '\n$path\n\n' +
                  AppLocalizations.of(
                    ctx,
                  ).t('explorer.overwrite.messageSuffix'),
              style: AppTextStyles.uiNormal,
            ),
            actions: [
              _DialogButton(
                label: AppLocalizations.of(ctx).t('explorer.overwrite.cancel'),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              _DialogButton(
                label: AppLocalizations.of(ctx).t('explorer.overwrite.confirm'),
                isDanger: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
    );
  }

  /// Shows a single dialog for all unsaved files when closing the app.
  /// Returns 'save' (save all), 'discard' (close without saving), or 'cancel'.
  static Future<String?> showConfirmSaveAll(
    BuildContext context,
    List<String> fileNames,
  ) {
    final listing =
        fileNames.length == 1
            ? '"${fileNames.first}"'
            : '${fileNames.length} files:\n${fileNames.map((n) => '  - $n').join('\n')}';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _StyledDialog(
            title: AppLocalizations.of(ctx).t('dialog.unsaved.title'),
            content: Text(
              AppLocalizations.of(ctx)
                  .t('dialog.unsaved.saveChangesTo')
                  .replaceAll('{target}', listing),
              style: AppTextStyles.uiNormal,
            ),
            actions: [
              _DialogButton(
                label:
                    fileNames.length == 1
                        ? AppLocalizations.of(ctx).t('dialog.unsaved.save')
                        : AppLocalizations.of(ctx).t('dialog.unsaved.saveAll'),
                onPressed: () => Navigator.of(ctx).pop('save'),
              ),
              _DialogButton(
                label: AppLocalizations.of(ctx).t('dialog.unsaved.dontSave'),
                onPressed: () => Navigator.of(ctx).pop('discard'),
              ),
              _DialogButton(
                label: AppLocalizations.of(ctx).t('dialog.unsaved.cancel'),
                onPressed: () => Navigator.of(ctx).pop('cancel'),
              ),
            ],
          ),
    );
  }

  static Future<void> showSettings(
    BuildContext context, {
    SettingsSection initialSection = SettingsSection.editor,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _SettingsDialog(initialSection: initialSection),
    );
  }

  static Future<void> showKeyboardShortcuts(BuildContext context) {
    return showSettings(context, initialSection: SettingsSection.shortcuts);
  }

  static Future<void> showAbout(BuildContext context) {
    return showSettings(context, initialSection: SettingsSection.about);
  }

  static Future<void> showRuntimeLogs(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => _InfoDialog(
            title: AppLocalizations.of(ctx).t('logs.title'),
            child: const _RuntimeLogsContent(),
          ),
    );
  }

  static Future<bool?> showPrivacyConsent(BuildContext context) {
    String zh(String key) => stringsZhCn[key] ?? stringsEnUs[key] ?? key;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _StyledDialog(
            title: zh('privacy.consent.title'),
            content: const _ChinesePrivacyConsentContent(),
            actions: [
              _DialogButton(
                label: zh('privacy.consent.disagree'),
                isDanger: true,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              _DialogButton(
                label: zh('privacy.consent.agree'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
    );
  }

  static Future<void> showPrivacyStatement(BuildContext context) {
    AppLogService.instance.info('privacy', 'open in about');
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => _InfoDialog(
            title: AppLocalizations.of(ctx).t('privacy.title'),
            child: const _PrivacyContent(),
          ),
    );
  }

  static Future<void> showWorkspaceSearchAndReplace(
    BuildContext context, {
    required String rootPath,
    required Future<void> Function(String filePath, int line) onOpenResult,
    bool initialReplaceMode = false,
  }) {
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => _InfoDialog(
            title:
                initialReplaceMode
                    ? AppLocalizations.of(ctx).t('menu.replaceInFiles')
                    : AppLocalizations.of(ctx).t('menu.findInFiles'),
            child: _WorkspaceSearchContent(
              rootPath: rootPath,
              onOpenResult: onOpenResult,
              initialReplaceMode: initialReplaceMode,
            ),
          ),
    );
  }
}

class _ChinesePrivacyConsentContent extends StatelessWidget {
  const _ChinesePrivacyConsentContent();

  String _zh(String key) => stringsZhCn[key] ?? stringsEnUs[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String body})>[
      (
        title: _zh('privacy.section.overview'),
        body: _zh('privacy.section.overview.body'),
      ),
      (
        title: _zh('privacy.section.dataCollected'),
        body: _zh('privacy.section.dataCollected.body'),
      ),
      (
        title: _zh('privacy.section.usage'),
        body: _zh('privacy.section.usage.body'),
      ),
      (
        title: _zh('privacy.section.legalBasis'),
        body: _zh('privacy.section.legalBasis.body'),
      ),
      (
        title: _zh('privacy.section.sharing'),
        body: _zh('privacy.section.sharing.body'),
      ),
      (
        title: _zh('privacy.section.products'),
        body: _zh('privacy.section.products.body'),
      ),
      (
        title: _zh('privacy.section.storage'),
        body: _zh('privacy.section.storage.body'),
      ),
      (
        title: _zh('privacy.section.transfers'),
        body: _zh('privacy.section.transfers.body'),
      ),
      (
        title: _zh('privacy.section.security'),
        body: _zh('privacy.section.security.body'),
      ),
      (
        title: _zh('privacy.section.children'),
        body: _zh('privacy.section.children.body'),
      ),
      (
        title: _zh('privacy.section.rights'),
        body: _zh('privacy.section.rights.body'),
      ),
      (
        title: _zh('privacy.section.changes'),
        body: _zh('privacy.section.changes.body'),
      ),
      (
        title: _zh('privacy.section.contact'),
        body: _zh('privacy.section.contact.body'),
      ),
    ];

    return SizedBox(
      width: 680,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _zh('privacy.updatedAt'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(_zh('privacy.summary'), style: AppTextStyles.uiNormal),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 360),
            decoration: BoxDecoration(
              color: AppColors.panelBase,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    Text(
                      sections[i].title,
                      style: AppTextStyles.uiBold.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sections[i].body,
                      style: AppTextStyles.uiSmall.copyWith(height: 1.45),
                    ),
                    if (i != sections.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings dialog
// ---------------------------------------------------------------------------

class SettingsPanel extends ConsumerStatefulWidget {
  const SettingsPanel({
    super.key,
    required this.initialSection,
    this.showHeader = false,
    this.onClose,
  });

  final SettingsSection initialSection;
  final bool showHeader;
  final VoidCallback? onClose;

  @override
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  late SettingsSection _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSection;
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _selected = widget.initialSection;
    }
  }

  Widget _buildContent() {
    switch (_selected) {
      case SettingsSection.editor:
        return _EditorSettingsContent();
      case SettingsSection.terminal:
        return const _TerminalSettingsContent();
      case SettingsSection.languageServer:
        return const _LanguageServerSettingsContent();
      case SettingsSection.shortcuts:
        return const _ShortcutsContent();
      case SettingsSection.appearance:
        return _AppearanceSettingsContent();
      case SettingsSection.codeStats:
        return const _CodeStatsContent();
      case SettingsSection.openSource:
        return const _OpenSourceContent();
      case SettingsSection.privacy:
        return const _AboutContent(showPrivacyOnBuild: true);
      case SettingsSection.about:
        return const _AboutContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text(
                  context.tr('settings.title'),
                  style: AppTextStyles.uiBold.copyWith(fontSize: 15),
                ),
                const Spacer(),
                _CloseIconButton(onPressed: widget.onClose ?? () {}),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
        Expanded(
          child: Row(
            children: [
              Container(
                width: 170,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 10, 4),
                      child: Text(
                        context.tr('settings.general'),
                        style: AppTextStyles.uiSmall.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SidebarItem(
                              label: context.tr('settings.editor'),
                              isActive: _selected == SettingsSection.editor,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () => _selected = SettingsSection.editor,
                                  ),
                            ),
                            _SidebarItem(
                              label: context.tr('settings.terminal'),
                              isActive: _selected == SettingsSection.terminal,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () => _selected = SettingsSection.terminal,
                                  ),
                            ),
                            _SidebarItem(
                              label: context.tr('settings.languageServer'),
                              isActive:
                                  _selected == SettingsSection.languageServer,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () =>
                                        _selected =
                                            SettingsSection.languageServer,
                                  ),
                            ),
                            _SidebarItem(
                              label: context.tr('settings.shortcuts'),
                              isActive: _selected == SettingsSection.shortcuts,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () => _selected = SettingsSection.shortcuts,
                                  ),
                            ),
                            _SidebarItem(
                              label: context.tr('settings.appearance'),
                              isActive: _selected == SettingsSection.appearance,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () =>
                                        _selected = SettingsSection.appearance,
                                  ),
                            ),
                            _SidebarItem(
                              label: context.tr('settings.codeStats'),
                              isActive: _selected == SettingsSection.codeStats,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () => _selected = SettingsSection.codeStats,
                                  ),
                            ),
                            _SidebarItem(
                              label: context.tr('settings.openSource'),
                              isActive: _selected == SettingsSection.openSource,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () =>
                                        _selected = SettingsSection.openSource,
                                  ),
                            ),
                            _SidebarItem(
                              label: context.tr('menu.about'),
                              isActive: _selected == SettingsSection.about,
                              dense: true,
                              onTap:
                                  () => setState(
                                    () => _selected = SettingsSection.about,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: AppColors.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({required this.initialSection});

  final SettingsSection initialSection;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 540,
        height: 420,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: SettingsPanel(
          initialSection: widget.initialSection,
          showHeader: true,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic info dialog (for About / Keyboard Shortcuts)
// ---------------------------------------------------------------------------

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 540,
        height: 420,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    title,
                    style: AppTextStyles.uiBold.copyWith(fontSize: 15),
                  ),
                  const Spacer(),
                  _CloseIconButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeLogsContent extends ConsumerWidget {
  const _RuntimeLogsContent();

  String _formatTs(DateTime ts) {
    final t = ts.toLocal();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLogProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('logs.description'),
                style: AppTextStyles.uiSmall.copyWith(
                  color: AppColors.secondaryForeground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _DialogButton(
              label: context.tr('logs.openFolder'),
              onPressed: () => AppLogService.instance.openLogDirectory(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.editorBackground,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                state.entries.isEmpty
                    ? Center(
                      child: Text(
                        context.tr('logs.empty'),
                        style: AppTextStyles.uiSmall.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemBuilder: (context, index) {
                        final e = state.entries[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '[${_formatTs(e.timestamp)}] [${e.level}] [${e.scope}] ${e.message}',
                            style: AppTextStyles.uiSmall.copyWith(
                              fontSize: 11,
                              color: AppColors.foreground,
                            ),
                          ),
                        );
                      },
                      separatorBuilder:
                          (_, __) =>
                              Divider(height: 8, color: AppColors.border),
                      itemCount: state.entries.length,
                    ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool dense;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
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
          height: widget.dense ? 30 : 32,
          margin: EdgeInsets.fromLTRB(widget.dense ? 14 : 6, 1, 6, 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                widget.isActive
                    ? AppColors.listActiveSelectionBackground
                    : _hovering
                    ? AppColors.listHoverBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.uiSmall.copyWith(
                    color:
                        widget.isActive
                            ? AppColors.foreground
                            : AppColors.secondaryForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Close icon button (top-right of settings)
// ---------------------------------------------------------------------------

class _CloseIconButton extends StatefulWidget {
  const _CloseIconButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_CloseIconButton> createState() => _CloseIconButtonState();
}

class _CloseIconButtonState extends State<_CloseIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovering ? AppColors.hoverHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.close,
            size: 14,
            color: AppColors.secondaryForeground,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section contents
// ---------------------------------------------------------------------------

class _EditorSettingsContent extends ConsumerWidget {
  String _formatDelay(BuildContext context, int ms) {
    switch (ms) {
      case 500:
        return context.tr('settings.autoSaveDelayOption.500ms');
      case 1000:
        return context.tr('settings.autoSaveDelayOption.1s');
      case 2000:
        return context.tr('settings.autoSaveDelayOption.2s');
      case 5000:
        return context.tr('settings.autoSaveDelayOption.5s');
      default:
        return '${ms}ms';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(editorSettingsProvider);
    final notifier = ref.read(editorSettingsProvider.notifier);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: context.tr('settings.editor.fileBehavior')),
          Text(
            context.tr('settings.defaultFileEncoding'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SettingsDropdown<FileEncodingOption>(
            value: settings.defaultFileEncoding,
            items: [
              (
                FileEncodingOption.utf8,
                context.tr('settings.defaultFileEncodingOption.utf8'),
              ),
              (
                FileEncodingOption.utf8bom,
                context.tr('settings.defaultFileEncodingOption.utf8bom'),
              ),
              (
                FileEncodingOption.gbk,
                context.tr('settings.defaultFileEncodingOption.gbk'),
              ),
              (
                FileEncodingOption.gb18030,
                context.tr('settings.defaultFileEncodingOption.gb18030'),
              ),
            ],
            onChanged: notifier.setDefaultFileEncoding,
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: context.tr('settings.openLastFolderOnStartup'),
            value: settings.openLastFolderOnStartup,
            onChanged: notifier.setOpenLastFolderOnStartup,
          ),
          const SizedBox(height: 14),
          _SectionLabel(title: context.tr('settings.editor.editingBehavior')),
          _SettingsToggle(
            label: context.tr('settings.autoPairBracketsAndQuotes'),
            value: settings.autoPairSymbols,
            onChanged: notifier.setAutoPairSymbols,
          ),
          const SizedBox(height: 8),
          _SettingsNumberField(
            label: context.tr('settings.codeFoldingMaxLines'),
            value: settings.codeFoldingMaxLines,
            suffix: context.tr('settings.unit.lines'),
            onSubmitted:
                (value) => notifier.setCodeFoldingMaxLines(value.toInt()),
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: context.tr('settings.editor.disableCodeForgeShortcuts'),
            value: settings.disableCodeForgeShortcuts,
            onChanged: notifier.setDisableCodeForgeShortcuts,
          ),
          const SizedBox(height: 14),
          _SectionLabel(title: context.tr('settings.editor.displayTypography')),
          _SettingsToggle(
            label: context.tr('settings.showIndentGuides'),
            value: settings.showIndentGuides,
            onChanged: notifier.setShowIndentGuides,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('settings.editorFontFamily'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SettingsDropdown<String>(
            value: settings.editorFontFamily,
            items:
                AppFontCatalog.editorFamilies
                    .map(
                      (key) => (
                        key,
                        context.tr('settings.editorFontOption.$key'),
                      ),
                    )
                    .toList(),
            onChanged: notifier.setEditorFontFamily,
          ),
          const SizedBox(height: 8),
          _SettingsNumberField(
            label: context.tr('settings.editorFontSize'),
            value: settings.fontSize,
            decimals: 1,
            suffix: context.tr('settings.unit.px'),
            onSubmitted:
                (value) => notifier.setEditorFontSize(value.toDouble()),
          ),
          const SizedBox(height: 8),
          _SettingsNumberField(
            label: context.tr('settings.editorLetterSpacing'),
            value: settings.editorLetterSpacing,
            decimals: 1,
            suffix: context.tr('settings.unit.px'),
            onSubmitted:
                (value) => notifier.setEditorLetterSpacing(value.toDouble()),
          ),
          const SizedBox(height: 14),
          _SectionLabel(title: context.tr('settings.autoSave')),
          Text(
            context.tr('settings.autoSave'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SettingsDropdown<AutoSaveMode>(
            value: settings.autoSaveMode,
            items: [
              (AutoSaveMode.off, context.tr('settings.autoSaveOption.off')),
              (
                AutoSaveMode.afterDelay,
                context.tr('settings.autoSaveOption.afterDelay'),
              ),
              (
                AutoSaveMode.onFocusLost,
                context.tr('settings.autoSaveOption.onFocusLost'),
              ),
            ],
            onChanged: (mode) {
              notifier.setAutoSaveMode(mode);
            },
          ),
          if (settings.autoSaveMode == AutoSaveMode.afterDelay) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('settings.autoSaveDelay'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _SettingsDropdown<int>(
              value: settings.autoSaveDelayMs,
              items: [
                (500, context.tr('settings.autoSaveDelayOption.500ms')),
                (1000, context.tr('settings.autoSaveDelayOption.1s')),
                (2000, context.tr('settings.autoSaveDelayOption.2s')),
                (5000, context.tr('settings.autoSaveDelayOption.5s')),
              ],
              onChanged: (ms) {
                notifier.setAutoSaveDelay(ms);
              },
            ),
          ],
          const SizedBox(height: 6),
          Text(
            settings.autoSaveMode == AutoSaveMode.off
                ? context.tr('settings.autoSaveDesc.off')
                : settings.autoSaveMode == AutoSaveMode.afterDelay
                ? context.tr('settings.autoSaveDesc.afterDelayPrefix') +
                    _formatDelay(context, settings.autoSaveDelayMs) +
                    context.tr('settings.autoSaveDesc.afterDelaySuffix')
                : context.tr('settings.autoSaveDesc.onFocusLost'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('settings.indentSize'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SettingsDropdown<int>(
            value: settings.indentSize,
            items: const [(2, '2'), (4, '4'), (8, '8')],
            onChanged: (size) {
              notifier.setIndentSize(size);
            },
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('settings.indentType'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SettingsDropdown<bool>(
            value: settings.useSpaces,
            items: [
              (true, context.tr('settings.indentTypeOption.spaces')),
              (false, context.tr('settings.indentTypeOption.tabs')),
            ],
            onChanged: (useSpaces) {
              notifier.setUseSpaces(useSpaces);
            },
          ),
          const SizedBox(height: 10),
          _SettingsToggle(
            label: context.tr('settings.trimTrailingWhitespaceOnSave'),
            value: settings.trimTrailingWhitespace,
            onChanged: notifier.setTrimTrailingWhitespace,
          ),
          const SizedBox(height: 10),
          _SettingsToggle(
            label: context.tr('settings.autoFormatOnSave'),
            value: settings.autoFormatOnSave,
            onChanged: notifier.setAutoFormatOnSave,
          ),
        ],
      ),
    );
  }
}

class _AppearanceSettingsContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileIconTheme = ref.watch(fileIconThemeProvider);
    final locale = ref.watch(appLocaleProvider);
    final settings = ref.watch(editorSettingsProvider);
    final settingsNotifier = ref.read(editorSettingsProvider.notifier);
    final shell = ref.watch(ideShellProvider);
    final shellNotifier = ref.read(ideShellProvider.notifier);
    return Align(
      key: const ValueKey('settings_appearance_top_align'),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('settings.themeMode'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _SettingsDropdown<AppThemeMode>(
              value: settings.appThemeMode,
              items: [
                (
                  AppThemeMode.dark,
                  context.tr('settings.themeModeOption.dark'),
                ),
                (
                  AppThemeMode.light,
                  context.tr('settings.themeModeOption.light'),
                ),
                (
                  AppThemeMode.darkBlue,
                  context.tr('settings.themeModeOption.darkBlue'),
                ),
                (
                  AppThemeMode.lightBlue,
                  context.tr('settings.themeModeOption.lightBlue'),
                ),
                (
                  AppThemeMode.darkPurple,
                  context.tr('settings.themeModeOption.darkPurple'),
                ),
                (
                  AppThemeMode.lightPurple,
                  context.tr('settings.themeModeOption.lightPurple'),
                ),
              ],
              onChanged: settingsNotifier.setAppThemeMode,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('settings.language'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _SettingsDropdown<Locale>(
              value: locale,
              items: [
                (
                  const Locale('en', 'US'),
                  context.tr('settings.languageOption.enUs'),
                ),
                (
                  const Locale('zh', 'CN'),
                  context.tr('settings.languageOption.zhCn'),
                ),
              ],
              onChanged: (nextLocale) {
                ref.read(appLocaleProvider.notifier).setLocale(nextLocale);
              },
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('settings.languageHelp'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.mutedForeground,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('settings.uiFontFamily'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _SettingsDropdown<String>(
              value: settings.uiFontFamily,
              items:
                  AppFontCatalog.uiFamilies
                      .map(
                        (key) => (
                          key,
                          context.tr('settings.uiFontOption.$key'),
                        ),
                      )
                      .toList(),
              onChanged: settingsNotifier.setUiFontFamily,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('settings.fileIconTheme'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _SettingsDropdown<FileIconThemeMode>(
              value: fileIconTheme.themeMode,
              items: [
                (
                  FileIconThemeMode.classic,
                  context.tr('settings.fileIconThemeOption.classic'),
                ),
                (
                  FileIconThemeMode.material,
                  context.tr('settings.fileIconThemeOption.material'),
                ),
                (
                  FileIconThemeMode.cupertino,
                  context.tr('settings.fileIconThemeOption.cupertino'),
                ),
                (
                  FileIconThemeMode.fontAwesome,
                  context.tr('settings.fileIconThemeOption.fontAwesome'),
                ),
                (
                  FileIconThemeMode.phosphor,
                  context.tr('settings.fileIconThemeOption.phosphor'),
                ),
              ],
              onChanged: (nextTheme) {
                ref
                    .read(fileIconThemeProvider.notifier)
                    .setThemeMode(nextTheme);
              },
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('settings.fileIconColorTheme'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _SettingsDropdown<FileIconColorTheme>(
              value: fileIconTheme.colorTheme,
              items: [
                (
                  FileIconColorTheme.muted,
                  context.tr('settings.fileIconColorThemeOption.muted'),
                ),
                (
                  FileIconColorTheme.vivid,
                  context.tr('settings.fileIconColorThemeOption.vivid'),
                ),
                (
                  FileIconColorTheme.monochrome,
                  context.tr('settings.fileIconColorThemeOption.monochrome'),
                ),
              ],
              onChanged: (nextColorTheme) {
                ref
                    .read(fileIconThemeProvider.notifier)
                    .setColorTheme(nextColorTheme);
              },
            ),
            const SizedBox(height: 10),
            _SettingsToggle(
              label: context.tr('settings.zenMode'),
              value: shell.isZenMode,
              onChanged: shellNotifier.setZenMode,
            ),
          ],
        ),
      ),
    );
  }
}

enum _LanguageServerInstallState {
  checking,
  installed,
  notInstalled,
  installing,
  failed,
}

class _LanguageServerPreset {
  const _LanguageServerPreset({
    required this.languageIds,
    required this.languageLabelKeys,
    required this.serverName,
    required this.executables,
    this.requireAnyExecutable = false,
    this.installCommandWindows = const [],
    this.installCommandUnix = const [],
    this.uninstallCommandWindows = const [],
    this.uninstallCommandUnix = const [],
    required this.docsUrl,
  });

  final List<String> languageIds;
  final List<String> languageLabelKeys;
  final String serverName;
  final List<String> executables;
  final bool requireAnyExecutable;
  final List<String> installCommandWindows;
  final List<String> installCommandUnix;
  final List<String> uninstallCommandWindows;
  final List<String> uninstallCommandUnix;
  final String docsUrl;
}

const List<_LanguageServerPreset> _commonLanguageServers = [
  _LanguageServerPreset(
    languageIds: ['dart'],
    languageLabelKeys: ['settings.lsp.language.dart'],
    serverName: 'Dart Analysis Server',
    executables: ['dart', 'dart.exe'],
    requireAnyExecutable: true,
    installCommandWindows: [
      'winget install --id Dart.DartSDK -e',
      'choco install dart-sdk -y',
      'scoop install dart',
      'winget install --id Google.Flutter -e',
    ],
    installCommandUnix: [
      'brew install dart-sdk',
      'sudo apt-get update && sudo apt-get install -y dart',
      'sudo snap install dart --classic',
    ],
    uninstallCommandWindows: [
      'winget uninstall --id Dart.DartSDK -e',
      'choco uninstall dart-sdk -y',
      'scoop uninstall dart',
      'winget uninstall --id Google.Flutter -e',
    ],
    uninstallCommandUnix: [
      'brew uninstall dart-sdk',
      'sudo apt-get remove -y dart',
      'sudo snap remove dart',
    ],
    docsUrl: 'https://dart.dev/get-dart',
  ),
  _LanguageServerPreset(
    languageIds: ['javascript', 'typescript'],
    languageLabelKeys: [
      'settings.lsp.language.javascript',
      'settings.lsp.language.typescript',
    ],
    serverName: 'typescript-language-server',
    executables: ['typescript-language-server', 'tsc'],
    installCommandWindows: [
      'npm i -g typescript-language-server typescript',
      'pnpm add -g typescript-language-server typescript',
      'yarn global add typescript-language-server typescript',
    ],
    installCommandUnix: [
      'npm i -g typescript-language-server typescript',
      'pnpm add -g typescript-language-server typescript',
      'yarn global add typescript-language-server typescript',
    ],
    uninstallCommandWindows: [
      'npm uninstall -g typescript-language-server typescript',
      'pnpm remove -g typescript-language-server typescript',
      'yarn global remove typescript-language-server typescript',
    ],
    uninstallCommandUnix: [
      'npm uninstall -g typescript-language-server typescript',
      'pnpm remove -g typescript-language-server typescript',
      'yarn global remove typescript-language-server typescript',
    ],
    docsUrl:
        'https://github.com/typescript-language-server/typescript-language-server',
  ),
  _LanguageServerPreset(
    languageIds: ['python'],
    languageLabelKeys: ['settings.lsp.language.python'],
    serverName: 'pyright / pylsp',
    executables: ['pyright-langserver', 'pylsp'],
    requireAnyExecutable: true,
    installCommandWindows: [
      'npm i -g pyright',
      'pip install python-lsp-server',
      'python -m pip install python-lsp-server',
    ],
    installCommandUnix: [
      'npm i -g pyright',
      'pip install python-lsp-server',
      'python3 -m pip install python-lsp-server',
    ],
    uninstallCommandWindows: [
      'npm uninstall -g pyright',
      'pip uninstall -y python-lsp-server',
      'python -m pip uninstall -y python-lsp-server',
    ],
    uninstallCommandUnix: [
      'npm uninstall -g pyright',
      'pip uninstall -y python-lsp-server',
      'python3 -m pip uninstall -y python-lsp-server',
    ],
    docsUrl: 'https://github.com/python-lsp/python-lsp-server',
  ),
  _LanguageServerPreset(
    languageIds: ['json'],
    languageLabelKeys: ['settings.lsp.language.json'],
    serverName: 'vscode-json-language-server',
    executables: ['vscode-json-language-server'],
    installCommandWindows: [
      'npm i -g vscode-langservers-extracted',
      'pnpm add -g vscode-langservers-extracted',
      'yarn global add vscode-langservers-extracted',
    ],
    installCommandUnix: [
      'npm i -g vscode-langservers-extracted',
      'pnpm add -g vscode-langservers-extracted',
      'yarn global add vscode-langservers-extracted',
    ],
    uninstallCommandWindows: [
      'npm uninstall -g vscode-langservers-extracted',
      'pnpm remove -g vscode-langservers-extracted',
      'yarn global remove vscode-langservers-extracted',
    ],
    uninstallCommandUnix: [
      'npm uninstall -g vscode-langservers-extracted',
      'pnpm remove -g vscode-langservers-extracted',
      'yarn global remove vscode-langservers-extracted',
    ],
    docsUrl: 'https://github.com/hrsh7th/vscode-langservers-extracted',
  ),
  _LanguageServerPreset(
    languageIds: ['yaml'],
    languageLabelKeys: ['settings.lsp.language.yaml'],
    serverName: 'yaml-language-server',
    executables: ['yaml-language-server'],
    installCommandWindows: [
      'npm i -g yaml-language-server',
      'pnpm add -g yaml-language-server',
      'yarn global add yaml-language-server',
    ],
    installCommandUnix: [
      'npm i -g yaml-language-server',
      'pnpm add -g yaml-language-server',
      'yarn global add yaml-language-server',
    ],
    uninstallCommandWindows: [
      'npm uninstall -g yaml-language-server',
      'pnpm remove -g yaml-language-server',
      'yarn global remove yaml-language-server',
    ],
    uninstallCommandUnix: [
      'npm uninstall -g yaml-language-server',
      'pnpm remove -g yaml-language-server',
      'yarn global remove yaml-language-server',
    ],
    docsUrl: 'https://github.com/redhat-developer/yaml-language-server',
  ),
  _LanguageServerPreset(
    languageIds: ['markdown'],
    languageLabelKeys: ['settings.lsp.language.markdown'],
    serverName: 'marksman',
    executables: ['marksman'],
    installCommandWindows: [
      'winget install --id Artempyanykh.Marksman -e',
      'choco install marksman -y',
      'scoop install marksman',
    ],
    installCommandUnix: ['brew install marksman'],
    uninstallCommandWindows: [
      'winget uninstall --id Artempyanykh.Marksman -e',
      'choco uninstall marksman -y',
      'scoop uninstall marksman',
    ],
    uninstallCommandUnix: ['brew uninstall marksman'],
    docsUrl: 'https://github.com/artempyanykh/marksman',
  ),
  _LanguageServerPreset(
    languageIds: ['c', 'cpp'],
    languageLabelKeys: ['settings.lsp.language.c', 'settings.lsp.language.cpp'],
    serverName: 'ccls / clangd',
    executables: ['ccls', 'clangd'],
    requireAnyExecutable: true,
    installCommandWindows: [
      'scoop install ccls',
      'winget install --id LLVM.LLVM -e',
      'choco install llvm -y',
      'scoop install llvm',
    ],
    installCommandUnix: ['brew install llvm'],
    uninstallCommandWindows: [
      'scoop uninstall ccls',
      'winget uninstall --id LLVM.LLVM -e',
      'choco uninstall llvm -y',
      'scoop uninstall llvm',
    ],
    uninstallCommandUnix: ['brew uninstall llvm'],
    docsUrl: 'https://clangd.llvm.org/installation',
  ),
  _LanguageServerPreset(
    languageIds: ['rust'],
    languageLabelKeys: ['settings.lsp.language.rust'],
    serverName: 'rust-analyzer',
    executables: ['rust-analyzer'],
    installCommandWindows: [
      'rustup component add rust-analyzer',
      'winget install --id Rustlang.Rustup -e',
    ],
    installCommandUnix: [
      'rustup component add rust-analyzer',
      'brew install rust-analyzer',
    ],
    uninstallCommandWindows: ['rustup component remove rust-analyzer'],
    uninstallCommandUnix: ['rustup component remove rust-analyzer'],
    docsUrl: 'https://rust-analyzer.github.io',
  ),
  _LanguageServerPreset(
    languageIds: ['go'],
    languageLabelKeys: ['settings.lsp.language.go'],
    serverName: 'gopls',
    executables: ['gopls'],
    installCommandWindows: ['go install golang.org/x/tools/gopls@latest'],
    installCommandUnix: ['go install golang.org/x/tools/gopls@latest'],
    uninstallCommandWindows: ['go clean -i golang.org/x/tools/gopls'],
    uninstallCommandUnix: ['go clean -i golang.org/x/tools/gopls'],
    docsUrl: 'https://pkg.go.dev/golang.org/x/tools/gopls',
  ),
  _LanguageServerPreset(
    languageIds: ['java'],
    languageLabelKeys: ['settings.lsp.language.java'],
    serverName: 'jdtls',
    executables: ['jdtls'],
    installCommandWindows: ['scoop install jdtls', 'choco install jdtls -y'],
    installCommandUnix: ['brew install jdtls'],
    uninstallCommandWindows: [
      'scoop uninstall jdtls',
      'choco uninstall jdtls -y',
    ],
    uninstallCommandUnix: ['brew uninstall jdtls'],
    docsUrl: 'https://github.com/eclipse-jdtls/eclipse.jdt.ls',
  ),
  _LanguageServerPreset(
    languageIds: ['kotlin'],
    languageLabelKeys: ['settings.lsp.language.kotlin'],
    serverName: 'kotlin-language-server',
    executables: ['kotlin-language-server'],
    installCommandWindows: [
      'npm i -g kotlin-language-server',
      'scoop install kotlin',
    ],
    installCommandUnix: ['npm i -g kotlin-language-server'],
    uninstallCommandWindows: [
      'npm uninstall -g kotlin-language-server',
      'scoop uninstall kotlin',
    ],
    uninstallCommandUnix: ['npm uninstall -g kotlin-language-server'],
    docsUrl: 'https://github.com/fwcd/kotlin-language-server',
  ),
  _LanguageServerPreset(
    languageIds: ['php'],
    languageLabelKeys: ['settings.lsp.language.php'],
    serverName: 'intelephense',
    executables: ['intelephense'],
    installCommandWindows: ['npm i -g intelephense'],
    installCommandUnix: ['npm i -g intelephense'],
    uninstallCommandWindows: ['npm uninstall -g intelephense'],
    uninstallCommandUnix: ['npm uninstall -g intelephense'],
    docsUrl: 'https://intelephense.com',
  ),
];

class _LanguageServerSettingsContent extends ConsumerStatefulWidget {
  const _LanguageServerSettingsContent();

  @override
  ConsumerState<_LanguageServerSettingsContent> createState() =>
      _LanguageServerSettingsContentState();
}

class _LanguageServerSettingsContentState
    extends ConsumerState<_LanguageServerSettingsContent> {
  final Map<String, _LanguageServerInstallState> _statusMap = {};
  final Map<String, String> _errorMap = {};
  Set<String> _disabledLanguageIds = {};
  bool _checkingAll = false;
  bool _installingAll = false;
  bool _switchingDiagnosticsEngine = false;

  @override
  void initState() {
    super.initState();
    () async {
      await _loadDisabledLanguages();
      await _refreshAll();
    }();
  }

  Future<void> _loadDisabledLanguages() async {
    final cfg = await ConfigService.load();
    final raw = cfg['lsp.disabledLanguages'];
    final parsed =
        raw is List
            ? raw.whereType<String>().map((e) => e.trim()).toSet()
            : <String>{};
    if (!mounted) return;
    setState(() => _disabledLanguageIds = parsed);
  }

  Future<void> _saveDisabledLanguages() async {
    final cfg = await ConfigService.load();
    cfg['lsp.disabledLanguages'] =
        _disabledLanguageIds.toList()..sort((a, b) => a.compareTo(b));
    await ConfigService.save(cfg);
  }

  Future<void> _refreshAll() async {
    setState(() => _checkingAll = true);
    for (final preset in _commonLanguageServers) {
      await _refreshPreset(preset);
    }
    if (mounted) {
      setState(() => _checkingAll = false);
    }
  }

  Future<void> _refreshPreset(_LanguageServerPreset preset) async {
    if (mounted) {
      setState(() {
        _statusMap[preset.serverName] = _LanguageServerInstallState.checking;
        _errorMap.remove(preset.serverName);
      });
    }
    final installed = await _isInstalled(preset);
    if (!mounted) return;
    setState(() {
      _statusMap[preset.serverName] =
          installed
              ? _LanguageServerInstallState.installed
              : _LanguageServerInstallState.notInstalled;
    });
  }

  Future<bool> _isInstalled(_LanguageServerPreset preset) async {
    if (preset.executables.isEmpty) return false;
    if (preset.requireAnyExecutable) {
      for (final executable in preset.executables) {
        final exists = await LanguageServerInstallService.isExecutableAvailable(
          executable,
        );
        if (exists) return true;
      }
      return false;
    }
    for (final executable in preset.executables) {
      final exists = await LanguageServerInstallService.isExecutableAvailable(
        executable,
      );
      if (!exists) return false;
    }
    return true;
  }

  Future<String?> _resolveInstallCommand(_LanguageServerPreset preset) async {
    final candidates =
        Platform.isWindows
            ? preset.installCommandWindows
            : preset.installCommandUnix;
    if (candidates.isEmpty) return null;
    if (!Platform.isWindows) return candidates.first;
    for (final cmd in candidates) {
      final executable = cmd.trim().split(RegExp(r'\s+')).first.toLowerCase();
      final available =
          await LanguageServerInstallService.isExecutableAvailable(executable);
      if (available) return cmd;
    }
    return candidates.first;
  }

  Future<void> _installPreset(_LanguageServerPreset preset) async {
    final cmd = await _resolveInstallCommand(preset);
    if (cmd == null || cmd.isEmpty) return;
    setState(() {
      _statusMap[preset.serverName] = _LanguageServerInstallState.installing;
      _errorMap.remove(preset.serverName);
    });
    AppLogService.instance.info(
      'lsp',
      'installRequested server=${preset.serverName} command="$cmd"',
    );
    final result = await LanguageServerInstallService.installByCommand(cmd);
    if (!mounted) return;
    if (!result.success) {
      final message =
          result.stderr.trim().isEmpty
              ? 'exitCode=${result.exitCode}'
              : result.stderr.trim();
      setState(() {
        _statusMap[preset.serverName] = _LanguageServerInstallState.failed;
        _errorMap[preset.serverName] = message;
      });
      AppLogService.instance.warn(
        'lsp',
        'installFailed server=${preset.serverName} code=${result.exitCode}',
      );
      return;
    }
    AppLogService.instance.info(
      'lsp',
      'installSucceeded server=${preset.serverName}',
    );
    await _refreshPreset(preset);
  }

  Future<String?> _resolveUninstallCommand(_LanguageServerPreset preset) async {
    final candidates =
        Platform.isWindows
            ? preset.uninstallCommandWindows
            : preset.uninstallCommandUnix;
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  Future<void> _uninstallPreset(_LanguageServerPreset preset) async {
    final cmd = await _resolveUninstallCommand(preset);
    if (cmd == null || cmd.isEmpty) return;
    setState(() {
      _statusMap[preset.serverName] = _LanguageServerInstallState.installing;
      _errorMap.remove(preset.serverName);
    });
    final result = await LanguageServerInstallService.installByCommand(cmd);
    if (!mounted) return;
    if (!result.success) {
      final message =
          result.stderr.trim().isEmpty
              ? 'exitCode=${result.exitCode}'
              : result.stderr.trim();
      setState(() {
        _statusMap[preset.serverName] = _LanguageServerInstallState.failed;
        _errorMap[preset.serverName] = message;
      });
      return;
    }
    await _refreshPreset(preset);
  }

  Future<void> _toggleDisabled(_LanguageServerPreset preset) async {
    final next = {..._disabledLanguageIds};
    final allDisabled = preset.languageIds.every(next.contains);
    if (allDisabled) {
      for (final id in preset.languageIds) {
        next.remove(id);
      }
    } else {
      next.addAll(preset.languageIds);
    }
    setState(() => _disabledLanguageIds = next);
    await _saveDisabledLanguages();
  }

  Future<void> _installAllPresets() async {
    if (_installingAll) return;
    setState(() => _installingAll = true);
    for (final preset in _commonLanguageServers) {
      final status =
          _statusMap[preset.serverName] ?? _LanguageServerInstallState.checking;
      if (status == _LanguageServerInstallState.installed) continue;
      await _installPreset(preset);
    }
    if (mounted) {
      setState(() => _installingAll = false);
    }
  }

  Future<void> _showExcludeRulesDialog(BuildContext context) async {
    final cfg = await ConfigService.load();
    final rawDirs = cfg['diagnostics.excludeDirs'];
    final rawPatterns = cfg['diagnostics.excludePatterns'];
    final dirsText =
        rawDirs is List
            ? rawDirs.whereType<String>().join('\n')
            : '';
    final patternsText =
        rawPatterns is List
            ? rawPatterns.whereType<String>().join('\n')
            : '';
    final dirsController = TextEditingController(text: dirsText);
    final patternsController = TextEditingController(text: patternsText);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: context.tr('settings.languageServer.editExcludeRules'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('settings.languageServer.excludeDirs'),
                style: AppTextStyles.uiSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: dirsController,
                    maxLines: null,
                    expands: true,
                    style: AppTextStyles.uiSmall,
                    decoration: InputDecoration(
                      hintText: '.git\nnode_modules\nbuild',
                      hintStyle: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('settings.languageServer.excludePatterns'),
                style: AppTextStyles.uiSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: patternsController,
                    maxLines: null,
                    expands: true,
                    style: AppTextStyles.uiSmall,
                    decoration: InputDecoration(
                      hintText: '*.min.js\n*.lock\n*.g.dart',
                      hintStyle: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          _DialogButton(
            label: context.tr('dialog.unsaved.cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          _DialogButton(
            label: context.tr('dialog.unsaved.save'),
            onPressed: () async {
              final dirs = dirsController.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final patterns = patternsController.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final newCfg = await ConfigService.load();
              newCfg['diagnostics.excludeDirs'] = dirs;
              newCfg['diagnostics.excludePatterns'] = patterns;
              await ConfigService.save(newCfg);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
    dirsController.dispose();
    patternsController.dispose();
  }

  String _statusText(BuildContext context, _LanguageServerInstallState status) {
    switch (status) {
      case _LanguageServerInstallState.checking:
        return context.tr('settings.languageServer.status.checking');
      case _LanguageServerInstallState.installed:
        return context.tr('settings.languageServer.status.installed');
      case _LanguageServerInstallState.notInstalled:
        return context.tr('settings.languageServer.status.notInstalled');
      case _LanguageServerInstallState.installing:
        return context.tr('settings.languageServer.status.installing');
      case _LanguageServerInstallState.failed:
        return context.tr('settings.languageServer.status.failed');
    }
  }

  Color _statusColor(_LanguageServerInstallState status) {
    switch (status) {
      case _LanguageServerInstallState.installed:
        return AppColors.success;
      case _LanguageServerInstallState.failed:
        return AppColors.warning;
      case _LanguageServerInstallState.checking:
      case _LanguageServerInstallState.installing:
        return AppColors.accent;
      case _LanguageServerInstallState.notInstalled:
        return AppColors.secondaryForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(editorAreaProvider);
    final settings = ref.watch(editorSettingsProvider);
    final settingsNotifier = ref.read(editorSettingsProvider.notifier);
    final editor = ref.read(editorAreaProvider.notifier);
    final diagnosticsSwitchLocked =
        _switchingDiagnosticsEngine ||
        editor.workspaceDiagnosticsProgress.isActive;
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: context.tr('settings.languageServer')),
          Text(
            context.tr('settings.languageServer.description'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SettingsDropdown<DiagnosticsEngine>(
                value: settings.diagnosticsEngine,
                items: [
                  (
                    DiagnosticsEngine.treeSitter,
                    context.tr('settings.languageServer.mode.treeSitter'),
                  ),
                  (
                    DiagnosticsEngine.languageServer,
                    context.tr('settings.languageServer.mode.languageServer'),
                  ),
                ],
                onChanged: (mode) async {
                  if (diagnosticsSwitchLocked ||
                      mode == settings.diagnosticsEngine) {
                    return;
                  }
                  setState(() => _switchingDiagnosticsEngine = true);
                  try {
                    settingsNotifier.setDiagnosticsEngine(mode);
                    await editor.refreshDiagnosticsEngineForOpenTabs();
                    await editor.restartWorkspaceDiagnosticsForCurrentRoot();
                  } finally {
                    if (mounted) {
                      setState(() => _switchingDiagnosticsEngine = false);
                    }
                  }
                },
              ),
              ),
              const SizedBox(width: 10),
              _SimpleActionButton(
                label: context.tr('settings.languageServer.editExcludeRules'),
                onPressed: () => _showExcludeRulesDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (settings.diagnosticsEngine == DiagnosticsEngine.languageServer) ...[
            Row(
              children: [
                _SimpleActionButton(
                  label: context.tr('settings.languageServer.recheckAll'),
                  onPressed: _checkingAll ? null : _refreshAll,
                ),
                const SizedBox(width: 8),
                _SimpleActionButton(
                  label: context.tr('settings.languageServer.installAll'),
                  onPressed:
                      _checkingAll || _installingAll ? null : _installAllPresets,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  _LanguageServerTableHeader(),
                  Divider(height: 1, thickness: 1, color: AppColors.border),
                  for (var i = 0; i < _commonLanguageServers.length; i++) ...[
                    _LanguageServerRow(
                      preset: _commonLanguageServers[i],
                      status:
                          _statusMap[_commonLanguageServers[i].serverName] ??
                          _LanguageServerInstallState.checking,
                      statusText: _statusText(
                        context,
                        _statusMap[_commonLanguageServers[i].serverName] ??
                            _LanguageServerInstallState.checking,
                      ),
                      statusColor: _statusColor(
                        _statusMap[_commonLanguageServers[i].serverName] ??
                            _LanguageServerInstallState.checking,
                      ),
                      errorMessage: _errorMap[_commonLanguageServers[i].serverName],
                      disabled: _commonLanguageServers[i].languageIds.every(_disabledLanguageIds.contains),
                      onInstall: () => _installPreset(_commonLanguageServers[i]),
                      onUninstall: () => _uninstallPreset(_commonLanguageServers[i]),
                      onToggleDisable: () => _toggleDisabled(_commonLanguageServers[i]),
                      onRecheck: () => _refreshPreset(_commonLanguageServers[i]),
                    ),
                    if (i != _commonLanguageServers.length - 1)
                      Divider(height: 1, thickness: 1, color: AppColors.border),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final langs = TreeSitterService.instance.supportedLanguages;
                if (langs.isEmpty) {
                  return Text(
                    context.tr('settings.languageServer.treeSitterUnavailable'),
                    style: AppTextStyles.uiSmall.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr('settings.languageServer.treeSitterSupported'),
                                style: AppTextStyles.uiSmall.copyWith(
                                  color: AppColors.secondaryForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: AppColors.border),
                      for (var i = 0; i < langs.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              langs[i],
                              style: AppTextStyles.uiSmall,
                            ),
                          ),
                        ),
                        if (i != langs.length - 1)
                          Divider(height: 1, thickness: 1, color: AppColors.border),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
    );
  }
}

class _LanguageServerTableHeader extends StatelessWidget {
  const _LanguageServerTableHeader();

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.uiSmall.copyWith(
      color: AppColors.secondaryForeground,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(context.tr('settings.languageServer.colServer'), style: base),
          ),
          SizedBox(
            width: 100,
            child: Text(context.tr('settings.languageServer.colLanguages'), style: base),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 90,
            child: Text(context.tr('settings.languageServer.colStatus'), style: base, textAlign: TextAlign.center),
          ),
          Expanded(child: Text(context.tr('settings.languageServer.colActions'), style: base, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _LanguageServerRow extends StatelessWidget {
  const _LanguageServerRow({
    required this.preset,
    required this.status,
    required this.statusText,
    required this.statusColor,
    required this.disabled,
    required this.onInstall,
    required this.onUninstall,
    required this.onToggleDisable,
    required this.onRecheck,
    this.errorMessage,
  });

  final _LanguageServerPreset preset;
  final _LanguageServerInstallState status;
  final String statusText;
  final Color statusColor;
  final bool disabled;
  final String? errorMessage;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onToggleDisable;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final installing = status == _LanguageServerInstallState.installing;
    final languageLabels =
        preset.languageLabelKeys.map((k) => context.tr(k)).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              preset.serverName,
              style: AppTextStyles.uiSmall.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              languageLabels,
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.mutedForeground,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 90,
            child: Text(
              statusText,
              style: AppTextStyles.uiSmall.copyWith(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (errorMessage != null && errorMessage!.trim().isNotEmpty)
            Expanded(
              child: Text(
                errorMessage!,
                style: AppTextStyles.uiSmall.copyWith(
                  color: AppColors.warning,
                  fontSize: 9.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          _SimpleActionButton(
            label: context.tr('settings.languageServer.install'),
            onPressed: installing ? null : onInstall,
          ),
          const SizedBox(width: 6),
          _SimpleActionButton(
            label: context.tr('settings.languageServer.uninstall'),
            onPressed: installing ? null : onUninstall,
          ),
          const SizedBox(width: 6),
          _SimpleActionButton(
            label:
                disabled
                    ? context.tr('settings.languageServer.enable')
                    : context.tr('settings.languageServer.disable'),
            onPressed: installing ? null : onToggleDisable,
          ),
          const SizedBox(width: 6),
          _SimpleActionButton(
            label: context.tr('settings.languageServer.recheck'),
            onPressed: installing ? null : onRecheck,
          ),
        ],
      ),
    );
  }
}

class _TerminalSettingsContent extends ConsumerWidget {
  const _TerminalSettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(terminalSettingsProvider);
    final notifier = ref.read(terminalSettingsProvider.notifier);
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsNumberField(
              label: context.tr('terminal.fontSize'),
              value: settings.fontSize,
              decimals: 0,
              onSubmitted: (v) => notifier.setFontSize(v.toDouble()),
            ),
            const SizedBox(height: 10),
            _SettingsNumberField(
              label: context.tr('terminal.letterSpacing'),
              value: settings.letterSpacing,
              decimals: 1,
              onSubmitted: (v) => notifier.setLetterSpacing(v.toDouble()),
            ),
            const SizedBox(height: 10),
            _SettingsNumberField(
              label: context.tr('terminal.lineHeight'),
              value: settings.lineHeight,
              decimals: 2,
              onSubmitted: (v) => notifier.setLineHeight(v.toDouble()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDropdown<T> extends StatefulWidget {
  const _SettingsDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final void Function(T) onChanged;

  @override
  State<_SettingsDropdown<T>> createState() => _SettingsDropdownState<T>();
}

class _SettingsDropdownState<T> extends State<_SettingsDropdown<T>> {
  bool _isOpen = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    _overlayEntry = OverlayEntry(
      builder:
          (ctx) => Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                offset: Offset(0, size.height + 2),
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  child: Container(
                    width: size.width,
                    decoration: BoxDecoration(
                      color: AppColors.panelBase,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              widget.items.map((item) {
                                final isSelected = item.$1 == widget.value;
                                return _DropdownItem(
                                  label: item.$2,
                                  isSelected: isSelected,
                                  onTap: () {
                                    widget.onChanged(item.$1);
                                    _close();
                                  },
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.items.where((i) => i.$1 == widget.value).firstOrNull;
    final label = (selected ?? widget.items.first).$2;
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppTextStyles.uiSmall)),
                Icon(
                  _isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.secondaryForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownItem extends StatefulWidget {
  const _DropdownItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
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
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color:
              _hovering
                  ? AppColors.listHoverBackground
                  : widget.isSelected
                  ? AppColors.listActiveSelectionBackground
                  : Colors.transparent,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.label, style: AppTextStyles.uiSmall),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings toggle (switch)
// ---------------------------------------------------------------------------

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: value ? AppColors.accent : AppColors.inputBackground,
                border: Border.all(
                  color: value ? AppColors.accent : AppColors.mutedForeground,
                  width: 1,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        value
                            ? AppColors.deepBackground
                            : AppColors.secondaryForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.uiSmall.copyWith(
          color: AppColors.mutedForeground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsNumberField extends StatefulWidget {
  const _SettingsNumberField({
    required this.label,
    required this.value,
    required this.onSubmitted,
    this.decimals = 0,
    this.suffix,
  });

  final String label;
  final num value;
  final ValueChanged<num> onSubmitted;
  final int decimals;
  final String? suffix;

  @override
  State<_SettingsNumberField> createState() => _SettingsNumberFieldState();
}

class _SettingsNumberFieldState extends State<_SettingsNumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant _SettingsNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = _formatValue(widget.value);
    }
  }

  String _formatValue(num value) {
    if (widget.decimals == 0) return value.toInt().toString();
    return value.toStringAsFixed(widget.decimals);
  }

  void _commit() {
    final text = _controller.text.trim();
    final parsed = num.tryParse(text);
    if (parsed == null) {
      _controller.text = _formatValue(widget.value);
      return;
    }
    widget.onSubmitted(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.uiSmall.copyWith(
            color: AppColors.secondaryForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  onSubmitted: (_) => _commit(),
                  onEditingComplete: _commit,
                  style: AppTextStyles.uiSmall,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (widget.suffix != null)
                Text(
                  widget.suffix!,
                  style: AppTextStyles.uiSmall.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section contents
// ---------------------------------------------------------------------------

class _ShortcutsContent extends StatelessWidget {
  const _ShortcutsContent();

  @override
  Widget build(BuildContext context) {
    return const _ShortcutsEditor();
  }
}

class _ShortcutsEditor extends ConsumerWidget {
  const _ShortcutsEditor();

  static const _actions = [
    ShortcutAction.undo,
    ShortcutAction.redo,
    ShortcutAction.cut,
    ShortcutAction.copy,
    ShortcutAction.paste,
    ShortcutAction.selectAll,
    ShortcutAction.save,
    ShortcutAction.saveAs,
    ShortcutAction.newFile,
    ShortcutAction.closeTab,
    ShortcutAction.openFile,
    ShortcutAction.find,
    ShortcutAction.replace,
    ShortcutAction.findInFiles,
    ShortcutAction.replaceInFiles,
    ShortcutAction.formatDocument,
    ShortcutAction.goToLine,
    ShortcutAction.nextTab,
    ShortcutAction.previousTab,
    ShortcutAction.toggleWordWrap,
    ShortcutAction.zoomIn,
    ShortcutAction.zoomOut,
    ShortcutAction.resetZoom,
    ShortcutAction.toggleSidebar,
    ShortcutAction.togglePanel,
    ShortcutAction.toggleEditor,
    ShortcutAction.toggleMinimap,
    ShortcutAction.duplicateLineUp,
    ShortcutAction.duplicateLineDown,
    ShortcutAction.showCodeActions,
    ShortcutAction.signatureHelp,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(shortcutSettingsProvider);
    final notifier = ref.read(shortcutSettingsProvider.notifier);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children:
                _actions.map((action) {
                  final binding = bindings[action]!;
                  return _ShortcutEditableRow(
                    action: action,
                    binding: binding,
                    onChanged: (next) {
                      final ok = notifier.setBinding(action, next);
                      if (!ok) {
                        ref
                            .read(statusNotificationProvider.notifier)
                            .show(
                              context.tr('settings.shortcutConflict'),
                              type: StatusNotificationType.error,
                            );
                      }
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SimpleActionButton(
                  label: context.tr('settings.shortcuts.resetDefault'),
                  onPressed: () {
                    notifier.resetToDefaults();
                  },
                ),
                _SimpleActionButton(
                  label: context.tr('settings.shortcuts.exportConfig'),
                  onPressed: () async {
                    final filePath = await FilePicker.platform.saveFile(
                      dialogTitle: context.tr(
                        'settings.shortcuts.exportConfig',
                      ),
                      fileName: 'shortcuts.json',
                    );
                    if (filePath == null) return;
                    final data = notifier.exportAsJsonMap();
                    await File(filePath).writeAsString(
                      const JsonEncoder.withIndent('  ').convert(data),
                    );
                    if (!context.mounted) return;
                    ref
                        .read(statusNotificationProvider.notifier)
                        .show(
                          context.tr('settings.shortcuts.exportSuccess'),
                          type: StatusNotificationType.success,
                        );
                  },
                ),
                _SimpleActionButton(
                  label: context.tr('settings.shortcuts.importConfig'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['json'],
                    );
                    final filePath = result?.files.single.path;
                    if (filePath == null) return;
                    try {
                      final raw = await File(filePath).readAsString();
                      final decoded = jsonDecode(raw);
                      if (decoded is! Map<String, dynamic>) {
                        throw const FormatException('Invalid json map');
                      }
                      final ok = notifier.importFromJsonMap(decoded);
                      if (!context.mounted) return;
                      ref
                          .read(statusNotificationProvider.notifier)
                          .show(
                            ok
                                ? context.tr('settings.shortcuts.importSuccess')
                                : context.tr('settings.shortcuts.importFailed'),
                            type: ok
                                ? StatusNotificationType.success
                                : StatusNotificationType.error,
                          );
                    } catch (_) {
                      if (!context.mounted) return;
                      ref
                          .read(statusNotificationProvider.notifier)
                          .show(
                            context.tr('settings.shortcuts.importFailed'),
                            type: StatusNotificationType.error,
                          );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ModifierPreset {
  none,
  primary,
  primaryShift,
  alt,
  altShift,
  primaryAlt,
  primaryAltShift,
}

class _ShortcutEditableRow extends StatelessWidget {
  const _ShortcutEditableRow({
    required this.action,
    required this.binding,
    required this.onChanged,
  });

  final ShortcutAction action;
  final ShortcutBinding binding;
  final ValueChanged<ShortcutBinding> onChanged;

  static const _keyOptions = [
    ('KeyA', 'A'),
    ('KeyB', 'B'),
    ('KeyC', 'C'),
    ('KeyD', 'D'),
    ('KeyE', 'E'),
    ('KeyF', 'F'),
    ('KeyG', 'G'),
    ('KeyH', 'H'),
    ('KeyI', 'I'),
    ('KeyJ', 'J'),
    ('KeyK', 'K'),
    ('KeyL', 'L'),
    ('KeyM', 'M'),
    ('KeyN', 'N'),
    ('KeyO', 'O'),
    ('KeyP', 'P'),
    ('KeyQ', 'Q'),
    ('KeyR', 'R'),
    ('KeyS', 'S'),
    ('KeyT', 'T'),
    ('KeyU', 'U'),
    ('KeyV', 'V'),
    ('KeyW', 'W'),
    ('KeyX', 'X'),
    ('KeyY', 'Y'),
    ('KeyZ', 'Z'),
    ('Tab', 'Tab'),
    ('ArrowUp', 'Up'),
    ('ArrowDown', 'Down'),
    ('Equal', '='),
    ('Minus', '-'),
    ('Digit0', '0'),
    ('Slash', '/'),
    ('Period', '.'),
  ];

  _ModifierPreset _presetFromBinding(ShortcutBinding b) {
    if (!b.primary && !b.alt && !b.shift) return _ModifierPreset.none;
    if (b.primary && !b.alt && !b.shift) return _ModifierPreset.primary;
    if (b.primary && !b.alt && b.shift) return _ModifierPreset.primaryShift;
    if (!b.primary && b.alt && !b.shift) return _ModifierPreset.alt;
    if (!b.primary && b.alt && b.shift) return _ModifierPreset.altShift;
    if (b.primary && b.alt && !b.shift) return _ModifierPreset.primaryAlt;
    return _ModifierPreset.primaryAltShift;
  }

  ShortcutBinding _bindingFromPreset(_ModifierPreset preset) {
    switch (preset) {
      case _ModifierPreset.none:
        return binding.copyWith(primary: false, alt: false, shift: false);
      case _ModifierPreset.primary:
        return binding.copyWith(primary: true, alt: false, shift: false);
      case _ModifierPreset.primaryShift:
        return binding.copyWith(primary: true, alt: false, shift: true);
      case _ModifierPreset.alt:
        return binding.copyWith(primary: false, alt: true, shift: false);
      case _ModifierPreset.altShift:
        return binding.copyWith(primary: false, alt: true, shift: true);
      case _ModifierPreset.primaryAlt:
        return binding.copyWith(primary: true, alt: true, shift: false);
      case _ModifierPreset.primaryAltShift:
        return binding.copyWith(primary: true, alt: true, shift: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = _presetFromBinding(binding);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('settings.shortcutAction.${action.name}'),
                  style: AppTextStyles.uiSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('settings.shortcutDesc.${action.name}'),
                  style: AppTextStyles.uiSmall.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: _SettingsDropdown<_ModifierPreset>(
              value: preset,
              items: [
                (_ModifierPreset.none, context.tr('settings.mod.none')),
                (_ModifierPreset.primary, context.tr('settings.mod.primary')),
                (
                  _ModifierPreset.primaryShift,
                  context.tr('settings.mod.primaryShift'),
                ),
                (_ModifierPreset.alt, context.tr('settings.mod.alt')),
                (_ModifierPreset.altShift, context.tr('settings.mod.altShift')),
                (
                  _ModifierPreset.primaryAlt,
                  context.tr('settings.mod.primaryAlt'),
                ),
                (
                  _ModifierPreset.primaryAltShift,
                  context.tr('settings.mod.primaryAltShift'),
                ),
              ],
              onChanged: (nextPreset) {
                onChanged(_bindingFromPreset(nextPreset));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: _SettingsDropdown<String>(
              value: binding.keyId,
              items: _keyOptions,
              onChanged: (nextKeyId) {
                onChanged(binding.copyWith(keyId: nextKeyId));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSearchContent extends StatefulWidget {
  const _WorkspaceSearchContent({
    required this.rootPath,
    required this.onOpenResult,
    required this.initialReplaceMode,
  });

  final String rootPath;
  final Future<void> Function(String filePath, int line) onOpenResult;
  final bool initialReplaceMode;

  @override
  State<_WorkspaceSearchContent> createState() =>
      _WorkspaceSearchContentState();
}

class _WorkspaceSearchContentState extends State<_WorkspaceSearchContent> {
  final _queryController = TextEditingController();
  final _replaceController = TextEditingController();
  final _service = const WorkspaceSearchService();
  bool _replaceMode = false;
  bool _running = false;
  double _progress = 0;
  String _progressText = '';
  String _summaryText = '';
  List<WorkspaceSearchMatch> _matches = const [];

  bool get _showProgress => _running || _summaryText.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _replaceMode = widget.initialReplaceMode;
  }

  @override
  void dispose() {
    _queryController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _queryController.text;
    if (query.isEmpty || _running) return;
    setState(() {
      _running = true;
      _progress = 0;
      _summaryText = '';
      _progressText = '';
      _matches = const [];
    });
    final result = await _service.search(
      rootPath: widget.rootPath,
      query: query,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p.ratio;
          _progressText = '${p.processedFiles}/${p.totalFiles}';
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _progress = 1;
      _matches = result.matches;
      _summaryText = context
          .tr('search.workspace.summary')
          .replaceAll('{matches}', '${result.matches.length}')
          .replaceAll('{files}', '${result.scannedFiles}');
    });
  }

  Future<void> _runReplace() async {
    final query = _queryController.text;
    if (query.isEmpty || _running) return;
    setState(() {
      _running = true;
      _progress = 0;
      _summaryText = '';
      _progressText = '';
      _matches = const [];
    });
    final result = await _service.replaceAll(
      rootPath: widget.rootPath,
      query: query,
      replacement: _replaceController.text,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p.ratio;
          _progressText = '${p.processedFiles}/${p.totalFiles}';
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _progress = 1;
      _summaryText = context
          .tr('search.workspace.replaceSummary')
          .replaceAll('{replacements}', '${result.replacements}')
          .replaceAll('{changedFiles}', '${result.changedFiles}')
          .replaceAll('{files}', '${result.scannedFiles}');
    });
    await _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context
                    .tr('search.workspace.root')
                    .replaceAll('{path}', widget.rootPath),
                style: AppTextStyles.uiSmall.copyWith(
                  color: AppColors.secondaryForeground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _SettingsToggle(
              label: context.tr('search.workspace.enableReplace'),
              value: _replaceMode,
              onChanged: (v) => setState(() => _replaceMode = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SearchInput(
                controller: _queryController,
                hint: context.tr('search.workspace.queryHint'),
              ),
            ),
            const SizedBox(width: 8),
            _SimpleActionButton(
              label: context.tr('menu.findInFiles'),
              onPressed: _running ? null : _runSearch,
            ),
          ],
        ),
        if (_replaceMode) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SearchInput(
                  controller: _replaceController,
                  hint: context.tr('search.workspace.replaceHint'),
                ),
              ),
              const SizedBox(width: 8),
              _SimpleActionButton(
                label: context.tr('menu.replaceInFiles'),
                onPressed: _running ? null : _runReplace,
              ),
            ],
          ),
        ],
        if (_showProgress) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _running ? _progress : 1,
            minHeight: 4,
            backgroundColor: AppColors.inputBackground,
            color: AppColors.accent,
          ),
          const SizedBox(height: 4),
          Text(
            _progressText,
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 10,
            ),
          ),
        ],
        if (_summaryText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _summaryText,
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final m = _matches[index];
              final fileName = m.filePath.split(RegExp(r'[\\/]')).last;
              return InkWell(
                onTap: () => widget.onOpenResult(m.filePath, m.line),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$fileName  (${m.line}:${m.column})',
                        style: AppTextStyles.uiSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.preview,
                        style: AppTextStyles.uiSmall.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        m.filePath,
                        style: AppTextStyles.uiSmall.copyWith(
                          color: AppColors.secondaryForeground,
                          fontSize: 9,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: controller,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        style: AppTextStyles.uiSmall,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.uiSmall.copyWith(
            color: AppColors.mutedForeground,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _AboutContent extends StatefulWidget {
  const _AboutContent({this.showPrivacyOnBuild = false});

  final bool showPrivacyOnBuild;

  @override
  State<_AboutContent> createState() => _AboutContentState();
}

class _AboutContentState extends State<_AboutContent> {
  bool _shownPrivacyDialog = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.showPrivacyOnBuild || _shownPrivacyDialog) {
      return;
    }
    _shownPrivacyDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppDialog.showPrivacyStatement(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const ValueKey('settings_about_scroll'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [_AboutHeader()],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('settings_about_upper_anchor'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/icons/logo.png', width: 54, height: 54),
        const SizedBox(height: 14),
        Text('Bewy', style: AppTextStyles.uiBold.copyWith(fontSize: 20)),
        const SizedBox(height: 6),
        Text(
          context.tr('about.author'),
          style: AppTextStyles.uiSmall.copyWith(
            color: AppColors.secondaryForeground,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _AboutCircleButton(
              icon: Icons.code,
              tooltipKey: 'about.link.personalWebsite',
              url: 'https://www.dou.asia/',
            ),
            SizedBox(width: 10),
            _AboutCircleButton(
              icon: Icons.menu_book_outlined,
              tooltipKey: 'about.link.zhihu',
              url: 'https://www.zhihu.com/people/qiumuu',
            ),
            SizedBox(width: 10),
            _AboutCircleButton(
              icon: Icons.mail_outline,
              tooltipKey: 'about.link.email',
              url: 'mailto:doutianyang@163.com',
            ),
            SizedBox(width: 10),
            _AboutPrivacyCircleButton(),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AboutUpdateMini extends StatefulWidget {
  const _AboutUpdateMini();

  @override
  State<_AboutUpdateMini> createState() => _AboutUpdateMiniState();
}

class _AboutUpdateMiniState extends State<_AboutUpdateMini> {
  static const _currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.0.2',
  );
  static const _channelVersionUrl = 'https://bewy.dou.asia/latest-version.txt';
  bool _checking = false;
  bool _hovering = false;
  String? _latestVersion;
  String? _error;

  Future<void> _checkUpdates() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final client =
          HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.getUrl(Uri.parse(_channelVersionUrl));
        request.followRedirects = true;
        request.headers.set(HttpHeaders.userAgentHeader, 'bewy-about-update/1');
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
        });
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
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

  @override
  Widget build(BuildContext context) {
    final hasUpdate =
        _latestVersion != null &&
        _isNewerVersion(_latestVersion!, _currentVersion);
    final status =
        _error != null
            ? context.tr('about.updateStatus.error')
            : _latestVersion == null
            ? context.tr('about.updateStatus.notChecked')
            : hasUpdate
            ? context.tr('about.updateStatus.available')
            : context.tr('about.updateStatus.latest');

    return SizedBox(
      width: 230,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.uiSmall.copyWith(
                color:
                    _error != null
                        ? AppColors.warning
                        : AppColors.mutedForeground,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 6),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              onTap: _checking ? null : _checkUpdates,
              child: Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color:
                      _hovering
                          ? AppColors.listActiveSelectionBackground
                          : AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Text(
                  _checking
                      ? context.tr('about.checkingUpdate')
                      : context.tr('settings.checkForUpdates'),
                  style: AppTextStyles.uiSmall.copyWith(fontSize: 8.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutPrivacyEntry extends StatefulWidget {
  const _AboutPrivacyEntry();

  @override
  State<_AboutPrivacyEntry> createState() => _AboutPrivacyEntryState();
}

class _AboutPrivacyEntryState extends State<_AboutPrivacyEntry> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Container(width: 220, height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: () => AppDialog.showPrivacyStatement(context),
            child: Text(
              context.tr('settings.privacy'),
              style: AppTextStyles.uiSmall.copyWith(
                fontSize: 11,
                color:
                    _hovering
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
                decoration:
                    _hovering ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenSourceContent extends StatelessWidget {
  const _OpenSourceContent();

  static const _items = <({String name, String url})>[
    (name: 'Flutter', url: 'https://flutter.dev'),
    (
      name: 'flutter_localizations',
      url:
          'https://api.flutter.dev/flutter/flutter_localizations/flutter_localizations-library.html',
    ),
    (name: 'cupertino_icons', url: 'https://pub.dev/packages/cupertino_icons'),
    (
      name: 'flutter_riverpod',
      url: 'https://pub.dev/packages/flutter_riverpod',
    ),
    (name: 'code_forge', url: 'https://pub.dev/packages/code_forge'),
    (name: 're_highlight', url: 'https://pub.dev/packages/re_highlight'),
    (name: 'window_manager', url: 'https://pub.dev/packages/window_manager'),
    (
      name: 'desktop_multi_window',
      url: 'https://pub.dev/packages/desktop_multi_window',
    ),
    (
      name: 'multi_split_view',
      url: 'https://pub.dev/packages/multi_split_view',
    ),
    (name: 'file_picker', url: 'https://pub.dev/packages/file_picker'),
    (name: 'desktop_drop', url: 'https://pub.dev/packages/desktop_drop'),
    (
      name: 'material_design_icons_flutter',
      url: 'https://pub.dev/packages/material_design_icons_flutter',
    ),
    (
      name: 'font_awesome_flutter',
      url: 'https://pub.dev/packages/font_awesome_flutter',
    ),
    (
      name: 'phosphor_flutter',
      url: 'https://pub.dev/packages/phosphor_flutter',
    ),
    (name: 'charset', url: 'https://pub.dev/packages/charset'),
    (name: 'dart_style', url: 'https://pub.dev/packages/dart_style'),
    (name: 'xterm', url: 'https://pub.dev/packages/xterm'),
    (name: 'flutter_pty', url: 'https://pub.dev/packages/flutter_pty'),
    (name: 'xml', url: 'https://pub.dev/packages/xml'),
    (name: 'url_launcher', url: 'https://pub.dev/packages/url_launcher'),
    (name: 'ffi', url: 'https://pub.dev/packages/ffi'),
    (name: 'tree-sitter', url: 'https://github.com/tree-sitter/tree-sitter'),
    (
      name: 'tree-sitter-c',
      url: 'https://github.com/tree-sitter/tree-sitter-c',
    ),
    (
      name: 'tree-sitter-cpp',
      url: 'https://github.com/tree-sitter/tree-sitter-cpp',
    ),
    (
      name: 'tree-sitter-javascript',
      url: 'https://github.com/tree-sitter/tree-sitter-javascript',
    ),
    (
      name: 'tree-sitter-typescript',
      url: 'https://github.com/tree-sitter/tree-sitter-typescript',
    ),
    (
      name: 'tree-sitter-python',
      url: 'https://github.com/tree-sitter/tree-sitter-python',
    ),
    (
      name: 'tree-sitter-dart',
      url: 'https://github.com/UserNobody14/tree-sitter-dart',
    ),
    (
      name: 'tree-sitter-json',
      url: 'https://github.com/tree-sitter/tree-sitter-json',
    ),
    (
      name: 'tree-sitter-yaml',
      url: 'https://github.com/tree-sitter-grammars/tree-sitter-yaml',
    ),
    (
      name: 'tree-sitter-markdown',
      url: 'https://github.com/tree-sitter-grammars/tree-sitter-markdown',
    ),
    (
      name: 'tree-sitter-html',
      url: 'https://github.com/tree-sitter/tree-sitter-html',
    ),
    (
      name: 'tree-sitter-xml',
      url: 'https://github.com/tree-sitter-grammars/tree-sitter-xml',
    ),
    (
      name: 'tree-sitter-css',
      url: 'https://github.com/tree-sitter/tree-sitter-css',
    ),
    (
      name: 'tree-sitter-java',
      url: 'https://github.com/tree-sitter/tree-sitter-java',
    ),
    (
      name: 'tree-sitter-kotlin',
      url: 'https://github.com/fwcd/tree-sitter-kotlin',
    ),
    (
      name: 'tree-sitter-go',
      url: 'https://github.com/tree-sitter/tree-sitter-go',
    ),
    (
      name: 'tree-sitter-rust',
      url: 'https://github.com/tree-sitter/tree-sitter-rust',
    ),
    (
      name: 'tree-sitter-ruby',
      url: 'https://github.com/tree-sitter/tree-sitter-ruby',
    ),
    (
      name: 'tree-sitter-php',
      url: 'https://github.com/tree-sitter/tree-sitter-php',
    ),
    (
      name: 'tree-sitter-lua',
      url: 'https://github.com/tree-sitter-grammars/tree-sitter-lua',
    ),
    (
      name: 'tree-sitter-bash',
      url: 'https://github.com/tree-sitter/tree-sitter-bash',
    ),
    (
      name: 'tree-sitter-c-sharp',
      url: 'https://github.com/tree-sitter/tree-sitter-c-sharp',
    ),
    (
      name: 'tree-sitter-r',
      url: 'https://github.com/r-lib/tree-sitter-r',
    ),
    (
      name: 'tree-sitter-toml',
      url: 'https://github.com/tree-sitter-grammars/tree-sitter-toml',
    ),
    (
      name: 'tree-sitter-powershell',
      url: 'https://github.com/airbus-cert/tree-sitter-powershell',
    ),
    (
      name: 'tree-sitter-dockerfile',
      url: 'https://github.com/camdencheek/tree-sitter-dockerfile',
    ),
    (name: 'JetBrains Mono', url: 'https://www.jetbrains.com/lp/mono'),
    (name: 'Cascadia Code', url: 'https://github.com/microsoft/cascadia-code'),
    (
      name: 'Source Code Pro',
      url: 'https://github.com/adobe-fonts/source-code-pro',
    ),
    (
      name: 'Noto Sans SC',
      url: 'https://fonts.google.com/noto/specimen/Noto+Sans+SC',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('settings_open_source_list'),
      padding: EdgeInsets.zero,
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _OssRow(name: item.name, url: item.url);
      },
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        title: context.tr('privacy.section.overview'),
        body: context.tr('privacy.section.overview.body'),
      ),
      (
        title: context.tr('privacy.section.dataCollected'),
        body: context.tr('privacy.section.dataCollected.body'),
      ),
      (
        title: context.tr('privacy.section.usage'),
        body: context.tr('privacy.section.usage.body'),
      ),
      (
        title: context.tr('privacy.section.legalBasis'),
        body: context.tr('privacy.section.legalBasis.body'),
      ),
      (
        title: context.tr('privacy.section.sharing'),
        body: context.tr('privacy.section.sharing.body'),
      ),
      (
        title: context.tr('privacy.section.products'),
        body: context.tr('privacy.section.products.body'),
      ),
      (
        title: context.tr('privacy.section.storage'),
        body: context.tr('privacy.section.storage.body'),
      ),
      (
        title: context.tr('privacy.section.transfers'),
        body: context.tr('privacy.section.transfers.body'),
      ),
      (
        title: context.tr('privacy.section.security'),
        body: context.tr('privacy.section.security.body'),
      ),
      (
        title: context.tr('privacy.section.children'),
        body: context.tr('privacy.section.children.body'),
      ),
      (
        title: context.tr('privacy.section.rights'),
        body: context.tr('privacy.section.rights.body'),
      ),
      (
        title: context.tr('privacy.section.changes'),
        body: context.tr('privacy.section.changes.body'),
      ),
      (
        title: context.tr('privacy.section.contact'),
        body: context.tr('privacy.section.contact.body'),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('privacy.title'),
            style: AppTextStyles.uiBold.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('privacy.updatedAt'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('privacy.summary'),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            Text(
              item.title,
              style: AppTextStyles.uiBold.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              item.body,
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FormatterSupportContent extends StatelessWidget {
  const _FormatterSupportContent();

  @override
  Widget build(BuildContext context) {
    final supports = CodeFormatService.supports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Text(
            context
                .tr('settings.formatterLibrariesCount')
                .replaceAll(
                  '{count}',
                  '${CodeFormatService.supportedToolCount}',
                ),
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('settings_formatter_support_list'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: supports.length,
            itemBuilder: (context, index) {
              final item = supports[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        item.tool,
                        style: AppTextStyles.uiSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.languages,
                        style: AppTextStyles.uiSmall.copyWith(
                          color: AppColors.secondaryForeground,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.mode,
                      style: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.mutedForeground,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CodeStatsContent extends ConsumerStatefulWidget {
  const _CodeStatsContent();

  @override
  ConsumerState<_CodeStatsContent> createState() => _CodeStatsContentState();
}

class _CodeStatsContentState extends ConsumerState<_CodeStatsContent> {
  final _service = const CodeStatsService();
  final _extFilterController = TextEditingController();
  CodeStatsResult? _result;
  bool _running = false;
  String _progressText = '';
  String? _lastRootPath;

  @override
  void dispose() {
    _extFilterController.dispose();
    super.dispose();
  }

  Set<String> _parseExtFilter() {
    final raw = _extFilterController.text.trim();
    if (raw.isEmpty) return const {};
    return raw
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim().toLowerCase().replaceFirst('.', ''))
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> _exportStats(String rootPath) async {
    final result = _result;
    if (result == null) {
      if (!mounted) return;
      ref.read(statusNotificationProvider.notifier).show(
        context.tr('settings.codeStats.noData'),
        type: StatusNotificationType.error,
      );
      return;
    }
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: context.tr('settings.codeStats.export'),
      fileName: 'code_stats.json',
    );
    if (savePath == null) return;

    final includeExtensions = _parseExtFilter().toList()..sort();
    final payload = <String, dynamic>{
      'rootPath': rootPath,
      'generatedAt': DateTime.now().toIso8601String(),
      'filters': <String, dynamic>{'extensions': includeExtensions},
      'summary': <String, dynamic>{
        'scannedFiles': result.scannedFiles,
        'totalLines': result.totalLines,
        'languageCount': result.languageStats.length,
      },
      'languages': result.languageStats
          .map(
            (s) => <String, dynamic>{
              'language': s.language,
              'lines': s.lines,
              'files': s.files,
            },
          )
          .toList(growable: false),
      'extensions': result.extensionStats
          .map(
            (s) => <String, dynamic>{
              'extension': s.extension,
              'lines': s.lines,
              'files': s.files,
            },
          )
          .toList(growable: false),
    };

    try {
      await File(
        savePath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      if (!mounted) return;
      ref.read(statusNotificationProvider.notifier).show(
        context.tr('settings.codeStats.exportSuccess'),
        type: StatusNotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      ref.read(statusNotificationProvider.notifier).show(
        context.tr('settings.codeStats.exportFailed'),
        type: StatusNotificationType.error,
      );
    }
  }

  Future<void> _runStats(String rootPath) async {
    if (_running) return;
    setState(() {
      _running = true;
      _progressText = '';
    });
    final include = _parseExtFilter();
    final result = await _service.analyzeWorkspace(
      rootPath: rootPath,
      includeExtensions: include.isEmpty ? null : include,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progressText = '${p.processedFiles}/${p.totalFiles}';
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rootPath = ref.watch(fileExplorerProvider.select((s) => s.rootPath));
    if (rootPath != _lastRootPath && !_running) {
      _lastRootPath = rootPath;
      if (rootPath != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _runStats(rootPath);
        });
      } else {
        _result = null;
      }
    }

    if (rootPath == null) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          context.tr('status.workspaceSearchFolderRequired'),
          style: AppTextStyles.uiSmall.copyWith(
            color: AppColors.secondaryForeground,
          ),
        ),
      );
    }

    final result = _result;
    final pieData = _buildPieData(result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('search.workspace.root').replaceAll('{path}', rootPath),
          style: AppTextStyles.uiSmall.copyWith(
            color: AppColors.secondaryForeground,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SearchInput(
                controller: _extFilterController,
                hint: context.tr('settings.codeStats.extFilterHint'),
              ),
            ),
            const SizedBox(width: 8),
            _SimpleActionButton(
              label: context.tr('settings.codeStats.analyze'),
              onPressed: _running ? null : () => _runStats(rootPath),
            ),
            const SizedBox(width: 8),
            _SimpleActionButton(
              label: context.tr('settings.codeStats.export'),
              onPressed: _running ? null : () => _exportStats(rootPath),
            ),
          ],
        ),
        if (_running || _progressText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _progressText,
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 10,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child:
              result == null
                  ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      context.tr('settings.codeStats.noData'),
                      style: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  )
                  : ListView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              width: null,
                              label: context.tr(
                                'settings.codeStats.scannedFiles',
                              ),
                              value: '${result.scannedFiles}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              width: null,
                              label: context.tr(
                                'settings.codeStats.totalLines',
                              ),
                              value: '${result.totalLines}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              width: null,
                              label: context.tr('settings.codeStats.languages'),
                              value: '${result.languageStats.length}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('settings.codeStats.languageComposition'),
                        style: AppTextStyles.uiBold.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: Row(
                          children: [
                            Expanded(
                              child: CustomPaint(
                                painter: _PieChartPainter(pieData),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ListView.builder(
                                itemCount: pieData.length,
                                itemBuilder: (context, index) {
                                  final d = pieData[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: d.color,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            d.label,
                                            style: AppTextStyles.uiSmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${d.percent.toStringAsFixed(1)}%',
                                          style: AppTextStyles.uiSmall.copyWith(
                                            color:
                                                AppColors.secondaryForeground,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('settings.codeStats.byLanguage'),
                        style: AppTextStyles.uiBold.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            _CodeStatsTableRow(
                              isHeader: true,
                              language: context.tr(
                                'settings.codeStats.colLanguage',
                              ),
                              lines: context.tr('settings.codeStats.colLines'),
                              files: context.tr('settings.codeStats.colFiles'),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.border,
                            ),
                            ...List.generate(result.languageStats.length, (
                              index,
                            ) {
                              final row = result.languageStats[index];
                              return Column(
                                children: [
                                  _CodeStatsTableRow(
                                    language: row.language,
                                    lines: '${row.lines}',
                                    files: '${row.files}',
                                  ),
                                  if (index != result.languageStats.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: AppColors.border,
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  List<_PieSliceData> _buildPieData(CodeStatsResult? result) {
    if (result == null ||
        result.totalLines == 0 ||
        result.languageStats.isEmpty) {
      return const [];
    }
    final palette = <Color>[
      const Color(0xFF5E9BFF),
      const Color(0xFF7BC47F),
      const Color(0xFFF4B66A),
      const Color(0xFFE67D7D),
      const Color(0xFFA58BFF),
      const Color(0xFF5CC9C9),
      const Color(0xFFD2C86A),
      const Color(0xFF9BA7B5),
    ];
    final top = result.languageStats.take(8).toList(growable: false);
    final accounted = top.fold<int>(0, (sum, e) => sum + e.lines);
    final list = <_PieSliceData>[];
    for (var i = 0; i < top.length; i++) {
      final item = top[i];
      list.add(
        _PieSliceData(
          label: item.language,
          value: item.lines.toDouble(),
          percent: (item.lines / result.totalLines) * 100,
          color: palette[i % palette.length],
        ),
      );
    }
    final rest = result.totalLines - accounted;
    if (rest > 0) {
      list.add(
        _PieSliceData(
          label: context.tr('settings.codeStats.other'),
          value: rest.toDouble(),
          percent: (rest / result.totalLines) * 100,
          color: AppColors.mutedForeground,
        ),
      );
    }
    return list;
  }
}

class _CodeStatsTableRow extends StatelessWidget {
  const _CodeStatsTableRow({
    required this.language,
    required this.lines,
    required this.files,
    this.isHeader = false,
  });

  final String language;
  final String lines;
  final String files;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.uiSmall.copyWith(
      color: isHeader ? AppColors.secondaryForeground : AppColors.foreground,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(language, style: base)),
          Expanded(
            flex: 2,
            child: Text(lines, style: base, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(files, style: base, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _PieSliceData {
  const _PieSliceData({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  final String label;
  final double value;
  final double percent;
  final Color color;
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter(this.slices);

  final List<_PieSliceData> slices;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;
    final shortest = math.min(size.width, size.height);
    final radius = shortest / 2 - 8;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2;
      final paint =
          Paint()
            ..color = slice.color
            ..style = PaintingStyle.fill;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }

    final ringPaint =
        Paint()
          ..color = AppColors.panelBase
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

class _AboutCircleButton extends StatefulWidget {
  const _AboutCircleButton({
    required this.icon,
    required this.tooltipKey,
    required this.url,
  });

  final IconData icon;
  final String tooltipKey;
  final String url;

  @override
  State<_AboutCircleButton> createState() => _AboutCircleButtonState();
}

class _AboutCircleButtonState extends State<_AboutCircleButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr(widget.tooltipKey),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: () => launchUrlString(widget.url),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _hovering
                      ? AppColors.listActiveSelectionBackground
                      : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: AppColors.secondaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutPrivacyCircleButton extends StatefulWidget {
  const _AboutPrivacyCircleButton();

  @override
  State<_AboutPrivacyCircleButton> createState() =>
      _AboutPrivacyCircleButtonState();
}

class _AboutPrivacyCircleButtonState extends State<_AboutPrivacyCircleButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr('settings.privacy'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: () => AppDialog.showPrivacyStatement(context),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _hovering
                      ? AppColors.listActiveSelectionBackground
                      : Colors.transparent,
            ),
            child: Icon(
              Icons.privacy_tip_outlined,
              size: 15,
              color: AppColors.secondaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.width = 245});

  final String label;
  final String value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.uiSmall.copyWith(
              color: AppColors.foreground,
              fontSize: 11,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SimpleActionButton extends StatefulWidget {
  const _SimpleActionButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_SimpleActionButton> createState() => _SimpleActionButtonState();
}

class _SimpleActionButtonState extends State<_SimpleActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovering && !disabled
                ? AppColors.listActiveSelectionBackground
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.uiSmall.copyWith(
              color: disabled
                  ? AppColors.mutedForeground
                  : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _OssRow extends StatelessWidget {
  const _OssRow({required this.name, required this.url});
  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrlString(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(
                name,
                style: AppTextStyles.uiSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                url,
                style: AppTextStyles.uiSmall.copyWith(
                  color: AppColors.mutedForeground,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// Generic styled dialog (for confirm / input dialogs)
// ---------------------------------------------------------------------------

class _StyledDialog extends StatelessWidget {
  const _StyledDialog({
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.uiBold.copyWith(fontSize: 15)),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children:
                  actions.expand((w) => [w, const SizedBox(width: 8)]).toList()
                    ..removeLast(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (widget.isDanger) {
      bg = _hovering ? AppColors.error.withValues(alpha: 0.8) : AppColors.error;
      fg = AppColors.foreground;
    } else {
      bg = _hovering
          ? AppColors.listActiveSelectionBackground
          : Colors.transparent;
      fg = AppColors.foreground;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.uiSmall.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
