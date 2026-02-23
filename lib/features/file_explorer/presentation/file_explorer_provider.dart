import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/app_log_service.dart';
import '../models/file_node.dart';

class FileExplorerState {
  const FileExplorerState({
    this.rootNodes = const [],
    this.selectedPath,
    this.rootPath,
    this.filterQuery = '',
    this.canUndo = false,
  });

  final List<FileNode> rootNodes;
  final String? selectedPath;
  final String? rootPath;
  final String filterQuery;
  final bool canUndo;

  FileExplorerState copyWith({
    List<FileNode>? rootNodes,
    String? selectedPath,
    String? rootPath,
    String? filterQuery,
    bool? canUndo,
  }) {
    return FileExplorerState(
      rootNodes: rootNodes ?? this.rootNodes,
      selectedPath: selectedPath ?? this.selectedPath,
      rootPath: rootPath ?? this.rootPath,
      filterQuery: filterQuery ?? this.filterQuery,
      canUndo: canUndo ?? this.canUndo,
    );
  }
}

enum _FileOpType { move, rename, createFile, createFolder }

class _FileOp {
  _FileOp({required this.type, required this.path, this.targetPath});
  final _FileOpType type;
  final String path;
  final String? targetPath;
}

class FileExplorerNotifier extends StateNotifier<FileExplorerState> {
  FileExplorerNotifier() : super(const FileExplorerState());

  StreamSubscription<FileSystemEvent>? _watchSubscription;
  Timer? _debounceTimer;
  final Set<String> _expandedPaths = {};
  final List<_FileOp> _undoStack = [];

  Future<void> openFolder(String path) async {
    _watchSubscription?.cancel();
    _debounceTimer?.cancel();
    _expandedPaths.clear();
    _undoStack.clear();

    final nodes = await compute(_scanDirectoryIsolate, (path, 0));
    if (!mounted) return;

    state = FileExplorerState(rootNodes: nodes, rootPath: path);
    AppLogService.instance.info('explorer', 'openFolder path=$path');
    _startWatching(path);
  }

  void _startWatching(String path) {
    _watchSubscription?.cancel();
    try {
      _watchSubscription = Directory(path).watch(recursive: true).listen((_) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) refreshTree();
        });
      });
    } catch (_) {
      // Fallback: some platforms may not support recursive watch
    }
  }

  Future<void> refreshTree() async {
    final rootPath = state.rootPath;
    if (rootPath == null) return;

    // Collect currently expanded paths before rescan.
    _expandedPaths.clear();
    _collectExpandedPaths(state.rootNodes);

    final nodes = await compute(_scanDirectoryIsolate, (rootPath, 0));
    if (!mounted) return;

    // Restore expanded state.
    _restoreExpandedState(nodes);
    state = state.copyWith(rootNodes: nodes);
  }

  void _collectExpandedPaths(List<FileNode> nodes) {
    for (final node in nodes) {
      if (node.isDirectory && node.isExpanded) {
        _expandedPaths.add(node.path);
        _collectExpandedPaths(node.children);
      }
    }
  }

  void _restoreExpandedState(List<FileNode> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].isDirectory && _expandedPaths.contains(nodes[i].path)) {
        final children = _scanDirectorySync(
          Directory(nodes[i].path),
          nodes[i].depth + 1,
        );
        nodes[i] = nodes[i].copyWith(isExpanded: true, children: children);
        _restoreExpandedState(nodes[i].children);
      }
    }
  }

  void toggleExpand(String path) {
    final newNodes = _toggleInList(state.rootNodes, path);
    state = state.copyWith(rootNodes: newNodes);
  }

  void selectFile(String path) {
    state = state.copyWith(selectedPath: path);
  }

  void setFilterQuery(String query) {
    state = state.copyWith(filterQuery: query);
  }

  List<FileNode> getFilteredNodes() {
    if (state.filterQuery.isEmpty || state.rootPath == null) return [];
    final query = state.filterQuery.toLowerCase();
    final results = <FileNode>[];
    _scanAndFilter(Directory(state.rootPath!), query, results, 0);
    return results;
  }

  void _scanAndFilter(
    Directory dir,
    String query,
    List<FileNode> results,
    int depth,
  ) {
    try {
      for (final entity in dir.listSync()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.') && name != '.gitignore') continue;

        if (entity is File) {
          if (name.toLowerCase().contains(query)) {
            results.add(FileNode(name: name, path: entity.path, depth: depth));
          }
        } else if (entity is Directory) {
          if (name.toLowerCase().contains(query)) {
            results.add(
              FileNode(
                name: name,
                path: entity.path,
                isDirectory: true,
                depth: depth,
              ),
            );
          }
          _scanAndFilter(entity, query, results, depth + 1);
        }
      }
    } catch (_) {}
  }

  Future<void> moveNode(String sourcePath, String targetDirPath) async {
    if (sourcePath == targetDirPath) return;
    if (targetDirPath.startsWith('$sourcePath${Platform.pathSeparator}'))
      return;

    try {
      final name = sourcePath.split(Platform.pathSeparator).last;
      final newPath = '$targetDirPath${Platform.pathSeparator}$name';

      final type = FileSystemEntity.typeSync(sourcePath);
      if (type == FileSystemEntityType.directory) {
        await Directory(sourcePath).rename(newPath);
      } else if (type == FileSystemEntityType.file) {
        await File(sourcePath).rename(newPath);
      }
      AppLogService.instance.info(
        'explorer',
        'move source=$sourcePath target=$newPath',
      );
      _pushUndo(
        _FileOp(type: _FileOpType.move, path: sourcePath, targetPath: newPath),
      );
    } catch (_) {}
    await refreshTree();
  }

  Future<void> renameNode(String oldPath, String newName) async {
    try {
      final entity =
          FileSystemEntity.typeSync(oldPath) == FileSystemEntityType.directory
              ? Directory(oldPath)
              : File(oldPath) as FileSystemEntity;
      final parent =
          entity is Directory
              ? entity.parent.path
              : (entity as File).parent.path;
      final newPath = '$parent${Platform.pathSeparator}$newName';
      await (entity as dynamic).rename(newPath);
      AppLogService.instance.info(
        'explorer',
        'rename from=$oldPath to=$newPath',
      );
      _pushUndo(
        _FileOp(type: _FileOpType.rename, path: oldPath, targetPath: newPath),
      );
    } catch (_) {}
    await refreshTree();
  }

  Future<void> deleteNode(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      final escapedPath = path.replaceAll("'", "''");
      if (type == FileSystemEntityType.directory) {
        await Process.run('powershell', [
          '-Command',
          "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('$escapedPath', 'OnlyErrorDialogs', 'SendToRecycleBin')",
        ]);
      } else if (type == FileSystemEntityType.file) {
        await Process.run('powershell', [
          '-Command',
          "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('$escapedPath', 'OnlyErrorDialogs', 'SendToRecycleBin')",
        ]);
      }
      AppLogService.instance.info('explorer', 'delete path=$path');
    } catch (_) {}
    await refreshTree();
  }

  Future<void> createFileInDir(String dirPath, String fileName) async {
    try {
      final filePath = '$dirPath${Platform.pathSeparator}$fileName';
      await File(filePath).create(recursive: true);
      AppLogService.instance.info('explorer', 'createFile path=$filePath');
      _pushUndo(_FileOp(type: _FileOpType.createFile, path: filePath));
    } catch (_) {}
    await refreshTree();
  }

  Future<void> createSubFolder(String dirPath, String folderName) async {
    try {
      final folderPath = '$dirPath${Platform.pathSeparator}$folderName';
      await Directory(folderPath).create(recursive: true);
      AppLogService.instance.info('explorer', 'createFolder path=$folderPath');
      _pushUndo(_FileOp(type: _FileOpType.createFolder, path: folderPath));
    } catch (_) {}
    await refreshTree();
  }

  void _pushUndo(_FileOp op) {
    _undoStack.add(op);
    if (_undoStack.length > 20) _undoStack.removeAt(0);
    state = state.copyWith(canUndo: true);
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final op = _undoStack.removeLast();

    try {
      switch (op.type) {
        case _FileOpType.move:
        case _FileOpType.rename:
          final type = FileSystemEntity.typeSync(op.targetPath!);
          if (type == FileSystemEntityType.directory) {
            await Directory(op.targetPath!).rename(op.path);
          } else if (type == FileSystemEntityType.file) {
            await File(op.targetPath!).rename(op.path);
          }
          AppLogService.instance.info(
            'explorer',
            'undoMoveOrRename from=${op.targetPath} to=${op.path}',
          );
        case _FileOpType.createFile:
          if (await File(op.path).exists()) {
            await File(op.path).delete();
          }
          AppLogService.instance.info(
            'explorer',
            'undoCreateFile path=${op.path}',
          );
        case _FileOpType.createFolder:
          if (await Directory(op.path).exists()) {
            await Directory(op.path).delete(recursive: true);
          }
          AppLogService.instance.info(
            'explorer',
            'undoCreateFolder path=${op.path}',
          );
      }
    } catch (_) {}

    state = state.copyWith(canUndo: _undoStack.isNotEmpty);
    await refreshTree();
  }

  List<FileNode> _toggleInList(List<FileNode> nodes, String path) {
    return nodes.map((node) {
      if (node.path == path) {
        if (node.isDirectory && !node.isExpanded && node.children.isEmpty) {
          final children = _scanDirectorySync(Directory(path), node.depth + 1);
          return node.copyWith(isExpanded: true, children: children);
        }
        return node.copyWith(isExpanded: !node.isExpanded);
      }
      if (node.children.isNotEmpty) {
        return node.copyWith(children: _toggleInList(node.children, path));
      }
      return node;
    }).toList();
  }

  static List<FileNode> _scanDirectoryIsolate((String, int) args) {
    final (path, depth) = args;
    return _scanDirectorySync(Directory(path), depth);
  }

  static List<FileNode> _scanDirectorySync(Directory dir, int depth) {
    try {
      final entities = dir.listSync();
      final dirs = <FileNode>[];
      final files = <FileNode>[];

      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.') && name != '.gitignore') continue;

        if (entity is Directory) {
          dirs.add(
            FileNode(
              name: name,
              path: entity.path,
              isDirectory: true,
              depth: depth,
            ),
          );
        } else if (entity is File) {
          files.add(FileNode(name: name, path: entity.path, depth: depth));
        }
      }

      dirs.sort((a, b) => _naturalCompare(a.name, b.name));
      files.sort((a, b) => _naturalCompare(a.name, b.name));

      return [...dirs, ...files];
    } catch (_) {
      return [];
    }
  }

  static final RegExp _naturalToken = RegExp(r'\d+|\D+');

  static int _naturalCompare(String a, String b) {
    final at = _naturalToken.allMatches(a).map((m) => m.group(0)!).toList();
    final bt = _naturalToken.allMatches(b).map((m) => m.group(0)!).toList();
    final len = at.length < bt.length ? at.length : bt.length;
    for (int i = 0; i < len; i++) {
      final x = at[i];
      final y = bt[i];
      final xn = int.tryParse(x);
      final yn = int.tryParse(y);
      if (xn != null && yn != null) {
        if (xn != yn) return xn.compareTo(yn);
        continue;
      }
      final c = x.toLowerCase().compareTo(y.toLowerCase());
      if (c != 0) return c;
    }
    return at.length.compareTo(bt.length);
  }

  @override
  void dispose() {
    _watchSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final fileExplorerProvider =
    StateNotifierProvider<FileExplorerNotifier, FileExplorerState>(
      (ref) => FileExplorerNotifier(),
    );
