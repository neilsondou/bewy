import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/recent_entry.dart';
import '../../../core/providers/multi_window_provider.dart';
import '../../../core/providers/recent_files_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../../file_explorer/presentation/file_explorer_provider.dart';

class GlobalSearchBox extends ConsumerStatefulWidget {
  const GlobalSearchBox({super.key});

  @override
  ConsumerState<GlobalSearchBox> createState() => _GlobalSearchBoxState();
}

class _GlobalSearchBoxState extends ConsumerState<GlobalSearchBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  Timer? _blurCloseTimer;
  int _searchToken = 0;
  bool _isSearching = false;
  List<_SearchHit> _results = const [];
  double _overlayWidth = 560;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _blurCloseTimer?.cancel();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _blurCloseTimer?.cancel();
      _showOverlay();
      _scheduleSearch();
    } else {
      _blurCloseTimer?.cancel();
      _blurCloseTimer = Timer(
        const Duration(milliseconds: 120),
        _removeOverlay,
      );
    }
  }

  void _scheduleSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 120), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    final rootPath = ref.read(fileExplorerProvider).rootPath;
    final token = ++_searchToken;

    if (query.isEmpty || rootPath == null) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _isSearching = false;
        _results = const [];
      });
      _overlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {
      _isSearching = true;
    });
    _overlayEntry?.markNeedsBuild();

    final rawHits = await compute(_searchFilesInFolder, (
      rootPath,
      query.toLowerCase(),
      120,
    ));
    if (!mounted || token != _searchToken) return;

    setState(() {
      _isSearching = false;
      _results = rawHits
          .map(
            (item) =>
                _SearchHit(name: item['name'] ?? '', path: item['path'] ?? ''),
          )
          .where((item) => item.path.isNotEmpty)
          .toList(growable: false);
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _overlayWidth = renderBox.size.width;
    }

    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final recent = ref.read(recentFilesProvider).take(100).toList();
        final query = _controller.text.trim();
        final showNoResults =
            query.isNotEmpty && !_isSearching && _results.isEmpty;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _focusNode.unfocus();
                  _removeOverlay();
                },
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: _overlayWidth,
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      if (query.isNotEmpty)
                        _PanelHeader(label: context.tr('title.search.results')),
                      if (query.isNotEmpty && _isSearching)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Text(
                            context.tr('title.search.searching'),
                            style: AppTextStyles.uiSmall.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      if (showNoResults)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Text(
                            context.tr('title.search.noResults'),
                            style: AppTextStyles.uiSmall.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      if (_results.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final hit = _results[index];
                              return _SearchItem(
                                name: hit.name,
                                subtitle: hit.path,
                                icon: Icons.description_outlined,
                                onTap: () => _openFile(hit.name, hit.path),
                              );
                            },
                          ),
                        ),
                      _PanelHeader(label: context.tr('title.search.recent')),
                      Expanded(
                        child: ListView.builder(
                          itemCount: recent.length,
                          itemBuilder: (context, index) {
                            final entry = recent[index];
                            return _SearchItem(
                              name: entry.name,
                              subtitle: entry.path,
                              icon:
                                  entry.isFolder
                                      ? Icons.folder_outlined
                                      : Icons.description_outlined,
                              onTap: () => _openRecent(entry),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _blurCloseTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _openFile(String fileName, String filePath) async {
    final focused = await ref
        .read(multiWindowProvider.notifier)
        .focusChildWindowForFile(filePath);
    if (!focused) {
      await ref.read(editorAreaProvider.notifier).openTab(fileName, filePath);
    }
    ref.read(recentFilesProvider.notifier).addRecent(fileName, filePath, false);
    if (!mounted) return;
    _removeOverlay();
    _focusNode.unfocus();
  }

  Future<void> _openRecent(RecentEntry entry) async {
    if (entry.isFolder) {
      await ref.read(fileExplorerProvider.notifier).openFolder(entry.path);
      ref
          .read(recentFilesProvider.notifier)
          .addRecent(entry.name, entry.path, true);
      if (!mounted) return;
      _removeOverlay();
      _focusNode.unfocus();
      return;
    }
    await _openFile(entry.name, entry.path);
  }

  @override
  Widget build(BuildContext context) {
    final rootPath = ref.watch(fileExplorerProvider).rootPath;
    final folderSegments =
        rootPath == null
            ? const <String>[]
            : rootPath
                .split(Platform.pathSeparator)
                .where((segment) => segment.isNotEmpty)
                .toList(growable: false);
    final folderName = folderSegments.isEmpty ? null : folderSegments.last;
    final hintText =
        folderName == null
            ? context.tr('title.search.placeholder.noFolder')
            : context
                .tr('title.search.placeholder.folder')
                .replaceAll('{folder}', folderName);

    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        height: 24,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: AppTextStyles.uiSmall.copyWith(
            color: AppColors.titleBarForeground,
            fontSize: 12,
          ),
          textAlign: TextAlign.start,
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 12,
            ),
            isDense: true,
            filled: true,
            fillColor: AppColors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: (_) {
            _showOverlay();
            _scheduleSearch();
          },
          onTap: _showOverlay,
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: AppTextStyles.uiSmall.copyWith(
          color: AppColors.secondaryForeground,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _SearchItem extends StatefulWidget {
  const _SearchItem({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SearchItem> createState() => _SearchItemState();
}

class _SearchItemState extends State<_SearchItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: _hover ? AppColors.hoverHighlight : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: AppColors.secondaryForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.foreground,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.mutedForeground,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHit {
  const _SearchHit({required this.name, required this.path});

  final String name;
  final String path;
}

List<Map<String, String>> _searchFilesInFolder((String, String, int) args) {
  final (rootPath, query, maxResults) = args;
  final results = <Map<String, String>>[];
  final stack = <Directory>[Directory(rootPath)];
  while (stack.isNotEmpty && results.length < maxResults) {
    final dir = stack.removeLast();
    List<FileSystemEntity> entities;
    try {
      entities = dir.listSync(followLinks: false);
    } catch (_) {
      continue;
    }

    for (final entity in entities) {
      if (results.length >= maxResults) break;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.') && name != '.gitignore') continue;

      if (entity is Directory) {
        stack.add(entity);
        continue;
      }
      if (entity is File && name.toLowerCase().contains(query)) {
        results.add({'name': name, 'path': entity.path});
      }
    }
  }
  return results;
}
