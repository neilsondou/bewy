import 'package:flutter/material.dart';

import 'strings_en_us.dart';
import 'strings_zh_cn.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en', 'US'),
    Locale('zh', 'CN'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations ?? const AppLocalizations(Locale('zh', 'CN'));
  }

  String t(String key) {
    final lang = locale.languageCode.toLowerCase();
    final map = lang == 'zh' ? stringsZhCn : stringsEnUs;
    return map[key] ?? stringsEnUs[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

extension AppLocalizationX on BuildContext {
  String tr(String key) => AppLocalizations.of(this).t(key);

  bool get isZh => AppLocalizations.of(this).locale.languageCode == 'zh';

  TextStyle trStyle(TextStyle base, {double zhDelta = -0.8}) {
    if (!isZh) return base;
    final size = base.fontSize;
    if (size == null) return base;
    final next = (size + zhDelta).clamp(8.0, 72.0);
    return base.copyWith(fontSize: next);
  }
}
