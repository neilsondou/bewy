/// Represents an editor tab.
class EditorTabModel {
  const EditorTabModel({
    required this.id,
    required this.fileName,
    this.filePath,
    this.isPinned = false,
    this.isBinary = false,
    this.settingsSection,
  });

  final String id;
  final String fileName;
  final String? filePath;
  final bool isPinned;
  final bool isBinary;
  final String? settingsSection;

  bool get isSettings => settingsSection != null;
  bool get isUntitled => filePath == null && !isSettings;

  EditorTabModel copyWith({
    String? id,
    String? fileName,
    String? filePath,
    bool clearFilePath = false,
    bool? isPinned,
    bool? isBinary,
    String? settingsSection,
    bool clearSettingsSection = false,
  }) {
    return EditorTabModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      isPinned: isPinned ?? this.isPinned,
      isBinary: isBinary ?? this.isBinary,
      settingsSection:
          clearSettingsSection
              ? null
              : (settingsSection ?? this.settingsSection),
    );
  }
}
