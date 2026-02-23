/// Represents a recently opened file or folder.
class RecentEntry {
  const RecentEntry({
    required this.name,
    required this.path,
    required this.isFolder,
    required this.lastOpened,
  });

  final String name;
  final String path;
  final bool isFolder;
  final DateTime lastOpened;

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'isFolder': isFolder,
    'lastOpened': lastOpened.toIso8601String(),
  };

  factory RecentEntry.fromJson(Map<String, dynamic> json) {
    return RecentEntry(
      name: json['name'] as String,
      path: json['path'] as String,
      isFolder: json['isFolder'] as bool,
      lastOpened: DateTime.parse(json['lastOpened'] as String),
    );
  }
}
