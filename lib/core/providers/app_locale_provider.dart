import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../services/config_service.dart';

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier() : super(const Locale('zh', 'CN')) {
    _load();
    _configSub = ConfigService.watchChanges().listen((_) {
      final until = _ignoreExternalUntil;
      if (until != null && DateTime.now().isBefore(until)) return;
      _load();
    });
  }
  StreamSubscription<void>? _configSub;
  DateTime? _ignoreExternalUntil;

  Future<void> _load() async {
    try {
      final data = await ConfigService.load();
      if (!mounted) return;
      final raw = data['appLocale'] as String?;
      if (raw == null || raw.isEmpty) return;
      final parsed = _parseLocale(raw);
      if (parsed != null) {
        state = parsed;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final data = await ConfigService.load();
    if (!mounted) return;
    data['appLocale'] = '${locale.languageCode}_${locale.countryCode ?? ''}';
    _ignoreExternalUntil = DateTime.now().add(
      const Duration(milliseconds: 300),
    );
    await ConfigService.save(data);
  }

  Locale? _parseLocale(String value) {
    final normalized = value.replaceAll('-', '_');
    final parts = normalized.split('_');
    if (parts.isEmpty) return null;
    if (parts[0] == 'zh') return const Locale('zh', 'CN');
    if (parts[0] == 'en') return const Locale('en', 'US');
    return null;
  }
}

final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale>(
  (ref) => AppLocaleNotifier(),
);
