/// Represents a node in the file tree.
class FileNode {
  const FileNode({
    required this.name,
    required this.path,
    this.isDirectory = false,
    this.children = const [],
    this.isExpanded = false,
    this.depth = 0,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final List<FileNode> children;
  final bool isExpanded;
  final int depth;

  FileNode copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    List<FileNode>? children,
    bool? isExpanded,
    int? depth,
  }) {
    return FileNode(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      depth: depth ?? this.depth,
    );
  }
}
