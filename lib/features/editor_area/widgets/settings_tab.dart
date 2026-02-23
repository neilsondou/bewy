import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../models/editor_tab_model.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.tab});

  final EditorTabModel tab;

  SettingsSection _resolveSection() {
    switch (tab.settingsSection) {
      case 'about':
        return SettingsSection.about;
      case 'language':
        return SettingsSection.appearance;
      case 'appearance':
        return SettingsSection.appearance;
      case 'formatter_support':
      case 'formatterSupport':
        return SettingsSection.openSource;
      case 'about_privacy':
      case 'privacy':
        return SettingsSection.privacy;
      case 'code_stats':
      case 'codeStats':
        return SettingsSection.codeStats;
      case 'language_server':
      case 'languageServer':
        return SettingsSection.languageServer;
      case 'open_source':
      case 'openSource':
        return SettingsSection.openSource;
      case 'shortcuts':
        return SettingsSection.shortcuts;
      case 'terminal':
        return SettingsSection.terminal;
      case 'editor':
      case 'general':
      default:
        return SettingsSection.editor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.editorBackground,
      child: SettingsPanel(
        key: ValueKey('settings_${tab.id}_${tab.settingsSection ?? 'editor'}'),
        initialSection: _resolveSection(),
      ),
    );
  }
}
