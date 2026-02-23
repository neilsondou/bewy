import 'dart:ui';

enum AppThemeMode { dark, light, darkBlue, lightBlue, darkPurple, lightPurple }

extension AppThemeModeX on AppThemeMode {
  bool get isLightVariant =>
      this == AppThemeMode.light ||
      this == AppThemeMode.lightBlue ||
      this == AppThemeMode.lightPurple;
}

class AppColorPalette {
  const AppColorPalette({
    required this.deepBackground,
    required this.panelBase,
    required this.glassBackground,
    required this.surface,
    required this.hoverHighlight,
    required this.border,
    required this.glowBorder,
    required this.focusBorder,
    required this.accent,
    required this.accentSecondary,
    required this.accentMuted,
    required this.foreground,
    required this.secondaryForeground,
    required this.mutedForeground,
    required this.success,
    required this.warning,
    required this.error,
    required this.gradientStart,
    required this.gradientEnd,
    required this.editorBackground,
    required this.editorForeground,
    required this.editorLineHighlight,
    required this.editorCursorLine,
    required this.editorSelectionBackground,
    required this.editorInactiveSelection,
    required this.lineNumber,
    required this.indentGuide,
    required this.bracketMatchBackground,
    required this.bracketMatchBorder,
    required this.minimapBackground,
    required this.minimapForeground,
    required this.minimapViewport,
    required this.minimapViewportBorder,
    required this.sideBarBackground,
    required this.sideBarForeground,
    required this.sideBarSectionHeaderBackground,
    required this.titleBarBackground,
    required this.titleBarForeground,
    required this.statusBarBackground,
    required this.statusBarForeground,
    required this.tabActiveBackground,
    required this.tabActiveForeground,
    required this.tabInactiveBackground,
    required this.tabInactiveForeground,
    required this.tabBorder,
    required this.panelBackground,
    required this.panelBorder,
    required this.panelTitleActiveForeground,
    required this.panelTitleInactiveForeground,
    required this.listActiveSelectionBackground,
    required this.listActiveSelectionForeground,
    required this.listHoverBackground,
    required this.listInactiveSelectionBackground,
    required this.inputBackground,
    required this.inputForeground,
    required this.inputBorder,
    required this.scrollbarSliderBackground,
    required this.scrollbarSliderHoverBackground,
    required this.scrollbarSliderActiveBackground,
    required this.breadcrumbForeground,
    required this.breadcrumbBackground,
    required this.breadcrumbFocusForeground,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.buttonHoverBackground,
    required this.windowControlHover,
    required this.windowControlCloseHover,
    required this.modifiedIndicator,
    required this.terminalBackground,
    required this.terminalForeground,
    required this.welcomeBackground,
    required this.welcomeLinkForeground,
  });

  final Color deepBackground;
  final Color panelBase;
  final Color glassBackground;
  final Color surface;
  final Color hoverHighlight;
  final Color border;
  final Color glowBorder;
  final Color focusBorder;
  final Color accent;
  final Color accentSecondary;
  final Color accentMuted;
  final Color foreground;
  final Color secondaryForeground;
  final Color mutedForeground;
  final Color success;
  final Color warning;
  final Color error;
  final Color gradientStart;
  final Color gradientEnd;
  final Color editorBackground;
  final Color editorForeground;
  final Color editorLineHighlight;
  final Color editorCursorLine;
  final Color editorSelectionBackground;
  final Color editorInactiveSelection;
  final Color lineNumber;
  final Color indentGuide;
  final Color bracketMatchBackground;
  final Color bracketMatchBorder;
  final Color minimapBackground;
  final Color minimapForeground;
  final Color minimapViewport;
  final Color minimapViewportBorder;
  final Color sideBarBackground;
  final Color sideBarForeground;
  final Color sideBarSectionHeaderBackground;
  final Color titleBarBackground;
  final Color titleBarForeground;
  final Color statusBarBackground;
  final Color statusBarForeground;
  final Color tabActiveBackground;
  final Color tabActiveForeground;
  final Color tabInactiveBackground;
  final Color tabInactiveForeground;
  final Color tabBorder;
  final Color panelBackground;
  final Color panelBorder;
  final Color panelTitleActiveForeground;
  final Color panelTitleInactiveForeground;
  final Color listActiveSelectionBackground;
  final Color listActiveSelectionForeground;
  final Color listHoverBackground;
  final Color listInactiveSelectionBackground;
  final Color inputBackground;
  final Color inputForeground;
  final Color inputBorder;
  final Color scrollbarSliderBackground;
  final Color scrollbarSliderHoverBackground;
  final Color scrollbarSliderActiveBackground;
  final Color breadcrumbForeground;
  final Color breadcrumbBackground;
  final Color breadcrumbFocusForeground;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color buttonBackground;
  final Color buttonForeground;
  final Color buttonHoverBackground;
  final Color windowControlHover;
  final Color windowControlCloseHover;
  final Color modifiedIndicator;
  final Color terminalBackground;
  final Color terminalForeground;
  final Color welcomeBackground;
  final Color welcomeLinkForeground;
}

/// Central color tokens. Widgets should always use this class so theme changes
/// are applied globally without per-widget rework.
class AppColors {
  AppColors._();

  static AppThemeMode _mode = AppThemeMode.dark;

  static void setThemeMode(AppThemeMode mode) {
    _mode = mode;
  }

  static AppThemeMode get currentThemeMode => _mode;

  static AppColorPalette get _p {
    switch (_mode) {
      case AppThemeMode.dark:
        return _dark;
      case AppThemeMode.light:
        return _light;
      case AppThemeMode.darkBlue:
        return _darkBlue;
      case AppThemeMode.lightBlue:
        return _lightBlue;
      case AppThemeMode.darkPurple:
        return _darkPurple;
      case AppThemeMode.lightPurple:
        return _lightPurple;
    }
  }

  static Color get deepBackground => _p.deepBackground;
  static Color get panelBase => _p.panelBase;
  static Color get glassBackground => _p.glassBackground;
  static Color get surface => _p.surface;
  static Color get hoverHighlight => _p.hoverHighlight;
  static Color get border => _p.border;
  static Color get glowBorder => _p.glowBorder;
  static Color get focusBorder => _p.focusBorder;
  static Color get accent => _p.accent;
  static Color get accentSecondary => _p.accentSecondary;
  static Color get accentMuted => _p.accentMuted;
  static Color get foreground => _p.foreground;
  static Color get secondaryForeground => _p.secondaryForeground;
  static Color get mutedForeground => _p.mutedForeground;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get error => _p.error;
  static Color get gradientStart => _p.gradientStart;
  static Color get gradientEnd => _p.gradientEnd;
  static Color get editorBackground => _p.editorBackground;
  static Color get editorForeground => _p.editorForeground;
  static Color get editorLineHighlight => _p.editorLineHighlight;
  static Color get editorCursorLine => _p.editorCursorLine;
  static Color get editorSelectionBackground => _p.editorSelectionBackground;
  static Color get editorInactiveSelection => _p.editorInactiveSelection;
  static Color get lineNumber => _p.lineNumber;
  static Color get indentGuide => _p.indentGuide;
  static Color get bracketMatchBackground => _p.bracketMatchBackground;
  static Color get bracketMatchBorder => _p.bracketMatchBorder;
  static Color get minimapBackground => _p.minimapBackground;
  static Color get minimapForeground => _p.minimapForeground;
  static Color get minimapViewport => _p.minimapViewport;
  static Color get minimapViewportBorder => _p.minimapViewportBorder;
  static Color get sideBarBackground => _p.sideBarBackground;
  static Color get sideBarForeground => _p.sideBarForeground;
  static Color get sideBarSectionHeaderBackground =>
      _p.sideBarSectionHeaderBackground;
  static Color get titleBarBackground => _p.titleBarBackground;
  static Color get titleBarForeground => _p.titleBarForeground;
  static Color get statusBarBackground => _p.statusBarBackground;
  static Color get statusBarForeground => _p.statusBarForeground;
  static Color get tabActiveBackground => _p.tabActiveBackground;
  static Color get tabActiveForeground => _p.tabActiveForeground;
  static Color get tabInactiveBackground => _p.tabInactiveBackground;
  static Color get tabInactiveForeground => _p.tabInactiveForeground;
  static Color get tabBorder => _p.tabBorder;
  static Color get panelBackground => _p.panelBackground;
  static Color get panelBorder => _p.panelBorder;
  static Color get panelTitleActiveForeground => _p.panelTitleActiveForeground;
  static Color get panelTitleInactiveForeground =>
      _p.panelTitleInactiveForeground;
  static Color get listActiveSelectionBackground =>
      _p.listActiveSelectionBackground;
  static Color get listActiveSelectionForeground =>
      _p.listActiveSelectionForeground;
  static Color get listHoverBackground => _p.listHoverBackground;
  static Color get listInactiveSelectionBackground =>
      _p.listInactiveSelectionBackground;
  static Color get inputBackground => _p.inputBackground;
  static Color get inputForeground => _p.inputForeground;
  static Color get inputBorder => _p.inputBorder;
  static Color get scrollbarSliderBackground => _p.scrollbarSliderBackground;
  static Color get scrollbarSliderHoverBackground =>
      _p.scrollbarSliderHoverBackground;
  static Color get scrollbarSliderActiveBackground =>
      _p.scrollbarSliderActiveBackground;
  static Color get breadcrumbForeground => _p.breadcrumbForeground;
  static Color get breadcrumbBackground => _p.breadcrumbBackground;
  static Color get breadcrumbFocusForeground => _p.breadcrumbFocusForeground;
  static Color get badgeBackground => _p.badgeBackground;
  static Color get badgeForeground => _p.badgeForeground;
  static Color get buttonBackground => _p.buttonBackground;
  static Color get buttonForeground => _p.buttonForeground;
  static Color get buttonHoverBackground => _p.buttonHoverBackground;
  static Color get windowControlHover => _p.windowControlHover;
  static Color get windowControlCloseHover => _p.windowControlCloseHover;
  static Color get modifiedIndicator => _p.modifiedIndicator;
  static Color get terminalBackground => _p.terminalBackground;
  static Color get terminalForeground => _p.terminalForeground;
  static Color get welcomeBackground => _p.welcomeBackground;
  static Color get welcomeLinkForeground => _p.welcomeLinkForeground;

  static const AppColorPalette _dark = AppColorPalette(
    deepBackground: Color(0xFF0A0A0A),
    panelBase: Color(0xFF111111),
    glassBackground: Color(0xB3161616),
    surface: Color(0xFF1A1A1A),
    hoverHighlight: Color(0xFF222222),
    border: Color(0x66333333),
    glowBorder: Color(0x4DFFFFFF),
    focusBorder: Color(0xFFFFFFFF),
    accent: Color(0xFFFFFFFF),
    accentSecondary: Color(0xFFCCCCCC),
    accentMuted: Color(0x33FFFFFF),
    foreground: Color(0xFFE8E8E8),
    secondaryForeground: Color(0xFF888888),
    mutedForeground: Color(0xFF555555),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    gradientStart: Color(0xFF303030),
    gradientEnd: Color(0xFF1A1A1A),
    editorBackground: Color(0xFF111111),
    editorForeground: Color(0xFFE8E8E8),
    editorLineHighlight: Color(0xFF1A1A1A),
    editorCursorLine: Color(0x0CFFFFFF),
    editorSelectionBackground: Color(0x40FFFFFF),
    editorInactiveSelection: Color(0xFF222222),
    lineNumber: Color(0xFF444444),
    indentGuide: Color(0x18FFFFFF),
    bracketMatchBackground: Color(0x33FFFFFF),
    bracketMatchBorder: Color(0x55FFFFFF),
    minimapBackground: Color(0xFF0E0E0E),
    minimapForeground: Color(0xFFD0D0D0),
    minimapViewport: Color(0x20FFFFFF),
    minimapViewportBorder: Color(0x40FFFFFF),
    sideBarBackground: Color(0xB3161616),
    sideBarForeground: Color(0xFFD0D0D0),
    sideBarSectionHeaderBackground: Color(0x40161616),
    titleBarBackground: Color(0xB3161616),
    titleBarForeground: Color(0xFFD0D0D0),
    statusBarBackground: Color(0xFF222222),
    statusBarForeground: Color(0xFFAAAAAA),
    tabActiveBackground: Color(0xFF1A1A1A),
    tabActiveForeground: Color(0xFFE8E8E8),
    tabInactiveBackground: Color(0xFF111111),
    tabInactiveForeground: Color(0xFF777777),
    tabBorder: Color(0x66333333),
    panelBackground: Color(0xB3161616),
    panelBorder: Color(0x66333333),
    panelTitleActiveForeground: Color(0xFFE8E8E8),
    panelTitleInactiveForeground: Color(0xFF777777),
    listActiveSelectionBackground: Color(0x33FFFFFF),
    listActiveSelectionForeground: Color(0xFFE8E8E8),
    listHoverBackground: Color(0xFF222222),
    listInactiveSelectionBackground: Color(0xFF1A1A1A),
    inputBackground: Color(0xFF1A1A1A),
    inputForeground: Color(0xFFE8E8E8),
    inputBorder: Color(0x66333333),
    scrollbarSliderBackground: Color(0x33FFFFFF),
    scrollbarSliderHoverBackground: Color(0x55FFFFFF),
    scrollbarSliderActiveBackground: Color(0x77FFFFFF),
    breadcrumbForeground: Color(0xFF777777),
    breadcrumbBackground: Color(0xFF111111),
    breadcrumbFocusForeground: Color(0xFFE8E8E8),
    badgeBackground: Color(0xFFFFFFFF),
    badgeForeground: Color(0xFF000000),
    buttonBackground: Color(0xFF2D2D2D),
    buttonForeground: Color(0xFFD0D0D0),
    buttonHoverBackground: Color(0xFF3A3A3A),
    windowControlHover: Color(0x33FFFFFF),
    windowControlCloseHover: Color(0xFFE81123),
    modifiedIndicator: Color(0xFFE8E8E8),
    terminalBackground: Color(0xFF111111),
    terminalForeground: Color(0xFFD0D0D0),
    welcomeBackground: Color(0xFF111111),
    welcomeLinkForeground: Color(0xFFAAAAAA),
  );

  static const AppColorPalette _light = AppColorPalette(
    deepBackground: Color(0xFFE7E7E7),
    panelBase: Color(0xFFF0F0F0),
    glassBackground: Color(0xE6F0F0F0),
    surface: Color(0xFFE9E9E9),
    hoverHighlight: Color(0xFFDEDEDE),
    border: Color(0x33222222),
    glowBorder: Color(0x33222222),
    focusBorder: Color(0xFF111111),
    accent: Color(0xFF111111),
    accentSecondary: Color(0xFF444444),
    accentMuted: Color(0x22111111),
    foreground: Color(0xFF1F1F1F),
    secondaryForeground: Color(0xFF5A5A5A),
    mutedForeground: Color(0xFF777777),
    success: Color(0xFF0E9F6E),
    warning: Color(0xFFB7791F),
    error: Color(0xFFE53E3E),
    gradientStart: Color(0xFFEDEDED),
    gradientEnd: Color(0xFFE2E2E2),
    editorBackground: Color(0xFFF1F1F1),
    editorForeground: Color(0xFF1F1F1F),
    editorLineHighlight: Color(0xFFE7E7E7),
    editorCursorLine: Color(0x12000000),
    editorSelectionBackground: Color(0x33000000),
    editorInactiveSelection: Color(0xFFE1E1E1),
    lineNumber: Color(0xFF8A8A8A),
    indentGuide: Color(0x22000000),
    bracketMatchBackground: Color(0x22000000),
    bracketMatchBorder: Color(0x44000000),
    minimapBackground: Color(0xFFE6E6E6),
    minimapForeground: Color(0xFF707070),
    minimapViewport: Color(0x22000000),
    minimapViewportBorder: Color(0x33000000),
    sideBarBackground: Color(0xFFEDEDED),
    sideBarForeground: Color(0xFF2A2A2A),
    sideBarSectionHeaderBackground: Color(0xFFE3E3E3),
    titleBarBackground: Color(0xFFEDEDED),
    titleBarForeground: Color(0xFF2A2A2A),
    statusBarBackground: Color(0xFFDFDFDF),
    statusBarForeground: Color(0xFF4A4A4A),
    tabActiveBackground: Color(0xFFEFEFEF),
    tabActiveForeground: Color(0xFF1F1F1F),
    tabInactiveBackground: Color(0xFFE3E3E3),
    tabInactiveForeground: Color(0xFF6F6F6F),
    tabBorder: Color(0x33222222),
    panelBackground: Color(0xFFEDEDED),
    panelBorder: Color(0x33222222),
    panelTitleActiveForeground: Color(0xFF1F1F1F),
    panelTitleInactiveForeground: Color(0xFF6F6F6F),
    listActiveSelectionBackground: Color(0x22000000),
    listActiveSelectionForeground: Color(0xFF1F1F1F),
    listHoverBackground: Color(0xFFE3E3E3),
    listInactiveSelectionBackground: Color(0xFFE8E8E8),
    inputBackground: Color(0xFFEBEBEB),
    inputForeground: Color(0xFF1F1F1F),
    inputBorder: Color(0x33222222),
    scrollbarSliderBackground: Color(0x22000000),
    scrollbarSliderHoverBackground: Color(0x33000000),
    scrollbarSliderActiveBackground: Color(0x55000000),
    breadcrumbForeground: Color(0xFF6F6F6F),
    breadcrumbBackground: Color(0xFFE8E8E8),
    breadcrumbFocusForeground: Color(0xFF1F1F1F),
    badgeBackground: Color(0xFF1F1F1F),
    badgeForeground: Color(0xFFFFFFFF),
    buttonBackground: Color(0xFFE2E2E2),
    buttonForeground: Color(0xFF222222),
    buttonHoverBackground: Color(0xFFD8D8D8),
    windowControlHover: Color(0x22000000),
    windowControlCloseHover: Color(0xFFE81123),
    modifiedIndicator: Color(0xFF1F1F1F),
    terminalBackground: Color(0xFFEFEFEF),
    terminalForeground: Color(0xFF2A2A2A),
    welcomeBackground: Color(0xFFEFEFEF),
    welcomeLinkForeground: Color(0xFF4A4A4A),
  );

  static final AppColorPalette _darkBlue = _tinted(
    base: _dark,
    accent: const Color(0xFF73B4FF),
    accentSecondary: const Color(0xFFA7CCFF),
    focusBorder: const Color(0xFF9EC5FF),
    gradientStart: const Color(0xFF11263D),
    gradientEnd: const Color(0xFF0B1727),
    tabActiveBackground: const Color(0xFF102035),
    panelBase: const Color(0xFF0D1724),
    deepBackground: const Color(0xFF080F17),
  );

  static final AppColorPalette _lightBlue = _tinted(
    base: _light,
    accent: const Color(0xFF2D6FB8),
    accentSecondary: const Color(0xFF3F89DB),
    focusBorder: const Color(0xFF1D5CA8),
    gradientStart: const Color(0xFFDCEEFF),
    gradientEnd: const Color(0xFFD3E7FC),
    tabActiveBackground: const Color(0xFFE6F1FC),
    panelBase: const Color(0xFFE8F2FC),
    deepBackground: const Color(0xFFDCEAF8),
  );

  static final AppColorPalette _darkPurple = _tinted(
    base: _dark,
    accent: const Color(0xFFBE9EFF),
    accentSecondary: const Color(0xFFD5C0FF),
    focusBorder: const Color(0xFFCDB2FF),
    gradientStart: const Color(0xFF2A1E3A),
    gradientEnd: const Color(0xFF1A1326),
    tabActiveBackground: const Color(0xFF231834),
    panelBase: const Color(0xFF181124),
    deepBackground: const Color(0xFF100B18),
  );

  static final AppColorPalette _lightPurple = _tinted(
    base: _light,
    accent: const Color(0xFF7047B5),
    accentSecondary: const Color(0xFF8661C7),
    focusBorder: const Color(0xFF6640A9),
    gradientStart: const Color(0xFFF0E7FF),
    gradientEnd: const Color(0xFFE8DEFA),
    tabActiveBackground: const Color(0xFFF0E9FB),
    panelBase: const Color(0xFFF2EBFC),
    deepBackground: const Color(0xFFEAE1F8),
  );

  static AppColorPalette _tinted({
    required AppColorPalette base,
    required Color accent,
    required Color accentSecondary,
    required Color focusBorder,
    required Color gradientStart,
    required Color gradientEnd,
    required Color tabActiveBackground,
    required Color panelBase,
    required Color deepBackground,
  }) {
    final accentMuted = Color.lerp(accent, base.panelBase, 0.75)!;
    final selectedBg = Color.lerp(accent, base.panelBase, 0.82)!;
    final hoverBg = Color.lerp(accent, base.panelBase, 0.9)!;
    final statusBg = Color.lerp(base.statusBarBackground, accent, 0.08)!;
    final terminalBg = Color.lerp(base.terminalBackground, panelBase, 0.6)!;
    return AppColorPalette(
      deepBackground: deepBackground,
      panelBase: panelBase,
      glassBackground: base.glassBackground,
      surface: base.surface,
      hoverHighlight: hoverBg,
      border: base.border,
      glowBorder: base.glowBorder,
      focusBorder: focusBorder,
      accent: accent,
      accentSecondary: accentSecondary,
      accentMuted: accentMuted,
      foreground: base.foreground,
      secondaryForeground: base.secondaryForeground,
      mutedForeground: base.mutedForeground,
      success: base.success,
      warning: base.warning,
      error: base.error,
      gradientStart: gradientStart,
      gradientEnd: gradientEnd,
      editorBackground: panelBase,
      editorForeground: base.editorForeground,
      editorLineHighlight: Color.lerp(tabActiveBackground, base.surface, 0.5)!,
      editorCursorLine: base.editorCursorLine,
      editorSelectionBackground:
          Color.lerp(accent, base.editorSelectionBackground, 0.6)!,
      editorInactiveSelection: base.editorInactiveSelection,
      lineNumber: base.lineNumber,
      indentGuide: base.indentGuide,
      bracketMatchBackground: base.bracketMatchBackground,
      bracketMatchBorder: base.bracketMatchBorder,
      minimapBackground: Color.lerp(base.minimapBackground, panelBase, 0.7)!,
      minimapForeground: base.minimapForeground,
      minimapViewport: Color.lerp(accent, base.minimapViewport, 0.7)!,
      minimapViewportBorder:
          Color.lerp(accent, base.minimapViewportBorder, 0.7)!,
      sideBarBackground: Color.lerp(panelBase, base.sideBarBackground, 0.5)!,
      sideBarForeground: base.sideBarForeground,
      sideBarSectionHeaderBackground: base.sideBarSectionHeaderBackground,
      titleBarBackground: Color.lerp(panelBase, base.titleBarBackground, 0.4)!,
      titleBarForeground: base.titleBarForeground,
      statusBarBackground: statusBg,
      statusBarForeground: base.statusBarForeground,
      tabActiveBackground: tabActiveBackground,
      tabActiveForeground: base.tabActiveForeground,
      tabInactiveBackground: base.tabInactiveBackground,
      tabInactiveForeground: base.tabInactiveForeground,
      tabBorder: base.tabBorder,
      panelBackground: Color.lerp(panelBase, base.panelBackground, 0.5)!,
      panelBorder: base.panelBorder,
      panelTitleActiveForeground: base.panelTitleActiveForeground,
      panelTitleInactiveForeground: base.panelTitleInactiveForeground,
      listActiveSelectionBackground: selectedBg,
      listActiveSelectionForeground: base.listActiveSelectionForeground,
      listHoverBackground: hoverBg,
      listInactiveSelectionBackground: base.listInactiveSelectionBackground,
      inputBackground: Color.lerp(panelBase, base.inputBackground, 0.65)!,
      inputForeground: base.inputForeground,
      inputBorder: base.inputBorder,
      scrollbarSliderBackground: base.scrollbarSliderBackground,
      scrollbarSliderHoverBackground: base.scrollbarSliderHoverBackground,
      scrollbarSliderActiveBackground: base.scrollbarSliderActiveBackground,
      breadcrumbForeground: base.breadcrumbForeground,
      breadcrumbBackground:
          Color.lerp(base.breadcrumbBackground, panelBase, 0.6)!,
      breadcrumbFocusForeground: base.breadcrumbFocusForeground,
      badgeBackground: accent,
      badgeForeground: base.badgeForeground,
      buttonBackground: Color.lerp(base.buttonBackground, accent, 0.14)!,
      buttonForeground: base.buttonForeground,
      buttonHoverBackground:
          Color.lerp(base.buttonHoverBackground, accent, 0.18)!,
      windowControlHover: base.windowControlHover,
      windowControlCloseHover: base.windowControlCloseHover,
      modifiedIndicator: accent,
      terminalBackground: terminalBg,
      terminalForeground: base.terminalForeground,
      welcomeBackground: Color.lerp(base.welcomeBackground, panelBase, 0.5)!,
      welcomeLinkForeground:
          Color.lerp(accentSecondary, base.welcomeLinkForeground, 0.6)!,
    );
  }
}
