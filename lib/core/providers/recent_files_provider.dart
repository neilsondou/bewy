import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recent_entry.dart';
import '../services/config_service.dart';

class RecentFilesNotifier extends StateNotifier<List<RecentEntry>> {
  RecentFilesNotifier() : super(const []) {
    _loadFromDisk();
  }

  static const int _maxEntries = 100;

  Future<void> _loadFromDisk() async {
    try {
      final data = await ConfigService.load();
      if (!mounted) return;
      final list = data['recentFiles'] as List<dynamic>?;
      if (list != null) {
        final loaded = <RecentEntry>[];
        for (final item in list) {
          try {
            if (item is Map<String, dynamic>) {
              loaded.add(RecentEntry.fromJson(item));
              continue;
            }
            if (item is Map) {
              loaded.add(RecentEntry.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (_) {}
        }
        if (loaded.length > _maxEntries) {
          loaded.removeRange(_maxEntries, loaded.length);
        }
        state = loaded;
      }
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    final entries = state.map((e) => e.toJson()).toList();
    try {
      final data = await ConfigService.load();
      if (!mounted) return;
      data['recentFiles'] = entries;
      await ConfigService.save(data);
    } catch (_) {}
  }

  void addRecent(String name, String path, bool isFolder) {
    // Remove existing entry with same path (dedup).
    final filtered = state.where((e) => e.path != path).toList();
    final entry = RecentEntry(
      name: name,
      path: path,
      isFolder: isFolder,
      lastOpened: DateTime.now(),
    );
    filtered.insert(0, entry);
    if (filtered.length > _maxEntries) {
      filtered.removeRange(_maxEntries, filtered.length);
    }
    state = filtered;
    _saveToDisk();
  }

  void removeRecent(String path) {
    state = state.where((e) => e.path != path).toList();
    _saveToDisk();
  }
}

final recentFilesProvider =
    StateNotifierProvider<RecentFilesNotifier, List<RecentEntry>>(
      (ref) => RecentFilesNotifier(),
    );
