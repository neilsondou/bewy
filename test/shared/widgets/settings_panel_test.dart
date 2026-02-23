import 'package:bewy/features/editor_area/presentation/editor_settings_provider.dart';
import 'package:bewy/l10n/app_localizations.dart';
import 'package:bewy/shared/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(WidgetTester, ProviderContainer)> pumpSettings(
    WidgetTester tester, {
    SettingsSection section = SettingsSection.editor,
  }) async {
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsPanel(initialSection: section, showHeader: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (tester, container);
  }

  int textIndex(WidgetTester tester, String text) {
    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    for (var i = 0; i < texts.length; i++) {
      if (texts[i].data == text) return i;
    }
    return -1;
  }

  testWidgets('editor section shows new grouped settings in order', (
    tester,
  ) async {
    await pumpSettings(tester);

    final fileBehavior = textIndex(tester, 'File Behavior');
    final editingBehavior = textIndex(tester, 'Editing Behavior');
    final displayTypography = textIndex(tester, 'Display & Typography');

    expect(fileBehavior, greaterThanOrEqualTo(0));
    expect(editingBehavior, greaterThan(fileBehavior));
    expect(displayTypography, greaterThan(editingBehavior));
    expect(find.text('Default File Encoding'), findsOneWidget);
    expect(find.text('Open Last Folder on Startup'), findsOneWidget);
    final defaultEncoding = textIndex(tester, 'Default File Encoding');
    final startupRestore = textIndex(tester, 'Open Last Folder on Startup');
    expect(defaultEncoding, greaterThanOrEqualTo(0));
    expect(startupRestore, greaterThan(defaultEncoding));
    expect(find.text('Auto Pair Brackets and Quotes'), findsOneWidget);
    expect(find.text('Code Folding Max Lines'), findsOneWidget);
    expect(find.text('Show Indent Guides'), findsOneWidget);
  });

  testWidgets('toggling startup folder restore updates provider state', (
    tester,
  ) async {
    final (_, container) = await pumpSettings(tester);
    expect(
      container.read(editorSettingsProvider).openLastFolderOnStartup,
      isTrue,
    );

    await tester.tap(find.text('Open Last Folder on Startup'));
    await tester.pumpAndSettle();

    expect(
      container.read(editorSettingsProvider).openLastFolderOnStartup,
      isFalse,
    );
  });

  testWidgets('appearance section is pinned to top', (tester) async {
    await pumpSettings(tester, section: SettingsSection.appearance);

    expect(
      find.byKey(const ValueKey('settings_appearance_top_align')),
      findsOneWidget,
    );
    expect(find.text('Color Theme'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    final themeIndex = textIndex(tester, 'Color Theme');
    final zenIndex = textIndex(tester, 'Zen Mode');
    expect(themeIndex, greaterThanOrEqualTo(0));
    expect(zenIndex, greaterThan(themeIndex));
  });

  testWidgets('about section header is in upper-middle area', (tester) async {
    await pumpSettings(tester, section: SettingsSection.about);

    expect(
      find.byKey(const ValueKey('settings_about_upper_anchor')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings_about_scroll')), findsOneWidget);
  });
}
