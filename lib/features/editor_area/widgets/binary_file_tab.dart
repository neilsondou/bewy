import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../models/editor_tab_model.dart';
import '../presentation/editor_area_provider.dart';

class BinaryFileTab extends ConsumerWidget {
  const BinaryFileTab({super.key, required this.tab});

  final EditorTabModel tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.editorBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('editor.binaryUnsupportedMessage'),
              style: AppTextStyles.uiSmall.copyWith(
                color: AppColors.secondaryForeground,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  label: context.tr('editor.forceOpen'),
                  onTap: () {
                    ref.read(editorAreaProvider.notifier).forceOpenTab(tab.id);
                  },
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  label: context.tr('editor.openWithDefaultApp'),
                  onTap: () {
                    if (tab.filePath != null) {
                      Process.run('cmd', ['/c', 'start', '', tab.filePath!]);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovering ? AppColors.hoverHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(widget.label, style: AppTextStyles.welcomeLink)],
          ),
        ),
      ),
    );
  }
}
