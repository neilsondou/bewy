import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_log_service.dart';

class AppLogState {
  const AppLogState({this.entries = const [], this.loading = false});

  final List<AppLogEntry> entries;
  final bool loading;

  AppLogState copyWith({List<AppLogEntry>? entries, bool? loading}) {
    return AppLogState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
    );
  }
}

class AppLogNotifier extends StateNotifier<AppLogState> {
  AppLogNotifier() : super(const AppLogState()) {
    _init();
  }

  StreamSubscription<AppLogEntry>? _subscription;

  Future<void> _init() async {
    await AppLogService.instance.initialize();
    final entries = await AppLogService.instance.readRecentFromDisk();
    if (!mounted) return;
    state = state.copyWith(entries: entries);
    _subscription = AppLogService.instance.stream.listen((entry) {
      if (!mounted) return;
      final list = [...state.entries, entry];
      final clipped =
          list.length <= 600 ? list : list.sublist(list.length - 600);
      state = state.copyWith(entries: clipped);
    });
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    final entries = await AppLogService.instance.readRecentFromDisk();
    if (!mounted) return;
    state = state.copyWith(entries: entries, loading: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final appLogProvider = StateNotifierProvider<AppLogNotifier, AppLogState>(
  (ref) => AppLogNotifier(),
);
