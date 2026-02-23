class AppFontCatalog {
  AppFontCatalog._();

  static const String uiSegoe = 'SegoeUI';
  static const String uiNotoSansSc = 'NotoSansSC';
  static const String uiCascadiaCode = 'CascadiaCode';

  static const String editorJetBrainsMono = 'JetBrainsMono';
  static const String editorCascadiaMono = 'CascadiaMono';
  static const String editorSourceCodePro = 'SourceCodePro';
  static const String editorCascadiaCode = 'CascadiaCode';

  static const List<String> uiFamilies = [
    uiSegoe,
    uiNotoSansSc,
    uiCascadiaCode,
  ];

  static const List<String> editorFamilies = [
    editorJetBrainsMono,
    editorCascadiaMono,
    editorSourceCodePro,
    editorCascadiaCode,
  ];

  static String resolveUiFontFamily(String key) {
    switch (key) {
      case uiNotoSansSc:
        return 'NotoSansSC';
      case uiCascadiaCode:
        return 'CascadiaCode';
      case uiSegoe:
      default:
        return 'Segoe UI';
    }
  }

  static String resolveEditorFontFamily(String key) {
    switch (key) {
      case editorCascadiaMono:
        return 'CascadiaMono';
      case editorSourceCodePro:
        return 'SourceCodePro';
      case editorCascadiaCode:
        return 'CascadiaCode';
      case editorJetBrainsMono:
      default:
        return 'JetBrainsMono';
    }
  }
}
