import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_boot_provider.dart';
import 'core/providers/app_locale_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_font_catalog.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/editor_area/presentation/editor_settings_provider.dart';
import 'package:bewy/features/shell/presentation/child_window_shell.dart';
import 'package:bewy/features/shell/presentation/ide_shell.dart';

class BewyApp extends ConsumerWidget {
  const BewyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    final settings = ref.watch(editorSettingsProvider);
    final boot = ref.watch(appBootProvider);
    AppColors.setThemeMode(settings.appThemeMode);
    return MaterialApp(
      title: 'Bewy',
      debugShowCheckedModeBanner: false,
      themeMode:
          settings.appThemeMode.isLightVariant
              ? ThemeMode.light
              : ThemeMode.dark,
      theme: AppTheme.light(
        uiFontFamily: AppFontCatalog.resolveUiFontFamily(settings.uiFontFamily),
      ),
      darkTheme: AppTheme.dark(
        uiFontFamily: AppFontCatalog.resolveUiFontFamily(settings.uiFontFamily),
      ),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: KeyedSubtree(
        key: ValueKey('shell_theme_${settings.appThemeMode.name}'),
        child: boot.isChildWindow ? const ChildWindowShell() : const IDEShell(),
      ),
    );
  }
}
