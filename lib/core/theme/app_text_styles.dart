import 'package:flutter/widgets.dart';
import 'app_colors.dart';

/// App text styles that follow the current [AppColors] palette.
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'JetBrainsMono';

  static TextStyle get uiSmall =>
      TextStyle(fontSize: 11, color: AppColors.foreground);
  static TextStyle get uiNormal =>
      TextStyle(fontSize: 13, color: AppColors.foreground);
  static TextStyle get uiBold => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.foreground,
  );

  static TextStyle get menuItem =>
      TextStyle(fontSize: 13, color: AppColors.titleBarForeground);
  static TextStyle get titleBar =>
      TextStyle(fontSize: 12, color: AppColors.titleBarForeground);
  static TextStyle get statusBar =>
      TextStyle(fontSize: 12, color: AppColors.statusBarForeground);

  static TextStyle get tabActive =>
      TextStyle(fontSize: 13, color: AppColors.tabActiveForeground);
  static TextStyle get tabInactive =>
      TextStyle(fontSize: 13, color: AppColors.tabInactiveForeground);

  static TextStyle get primaryTabActive => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.accent,
  );
  static TextStyle get primaryTabInactive => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryForeground,
  );

  static TextStyle get sideBarTitle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppColors.secondaryForeground,
  );
  static TextStyle get sideBarItem =>
      TextStyle(fontSize: 13, color: AppColors.sideBarForeground);

  static TextStyle get editorNormal => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 1.5,
    color: AppColors.editorForeground,
  );

  static TextStyle get breadcrumb =>
      TextStyle(fontSize: 12, color: AppColors.breadcrumbForeground);
  static TextStyle get panelTabActive =>
      TextStyle(fontSize: 12, color: AppColors.panelTitleActiveForeground);
  static TextStyle get panelTabInactive =>
      TextStyle(fontSize: 12, color: AppColors.panelTitleInactiveForeground);

  static TextStyle get terminal => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    height: 1.4,
    color: AppColors.terminalForeground,
  );

  static TextStyle get welcomeTitle => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w300,
    color: AppColors.foreground,
  );
  static TextStyle get welcomeSubtitle =>
      TextStyle(fontSize: 14, color: AppColors.secondaryForeground);
  static TextStyle get welcomeLink =>
      TextStyle(fontSize: 13, color: AppColors.welcomeLinkForeground);
}
