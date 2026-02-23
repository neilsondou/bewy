import 'dart:convert';
import 'dart:io';

import 'package:bewy/l10n/strings_en_us.dart';
import 'package:bewy/l10n/strings_zh_cn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization integrity', () {
    test('zh file is valid UTF-8 and has no replacement marker', () {
      final file = File('lib/l10n/strings_zh_cn.dart');
      final bytes = file.readAsBytesSync();
      final decoded = utf8.decode(bytes, allowMalformed: false);
      expect(decoded.contains('\uFFFD'), isFalse);
    });

    test('zh localization sentinel strings stay correct', () {
      expect(stringsZhCn['menu.settings'], '设置');
      expect(stringsZhCn['settings.general'], '常规');
      expect(stringsZhCn['settings.fileIconColorThemeOption.muted'], '柔和');
      expect(stringsZhCn['explorer.openFolder'], '打开文件夹');
      expect(stringsZhCn['editor.openAsEmptyText'], '以空文本文件打开');
    });

    test('new settings keys exist in both en and zh maps', () {
      const requiredKeys = [
        'settings.editor.fileBehavior',
        'settings.editor.editingBehavior',
        'settings.editor.displayTypography',
        'settings.openLastFolderOnStartup',
        'settings.defaultFileEncoding',
        'settings.autoPairBracketsAndQuotes',
        'settings.codeFoldingMaxLines',
        'settings.showIndentGuides',
        'settings.editorFontFamily',
        'settings.editorFontSize',
        'settings.editorLetterSpacing',
        'settings.uiFontFamily',
        'settings.themeMode',
        'settings.themeModeOption.dark',
        'settings.themeModeOption.light',
        'settings.themeModeOption.darkBlue',
        'settings.themeModeOption.lightBlue',
        'settings.themeModeOption.darkPurple',
        'settings.themeModeOption.lightPurple',
        'about.link.personalWebsite',
      ];
      for (final key in requiredKeys) {
        expect(stringsEnUs[key], isNotNull, reason: 'missing en key: $key');
        expect(stringsZhCn[key], isNotNull, reason: 'missing zh key: $key');
      }
    });
  });
}
