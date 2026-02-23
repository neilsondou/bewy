import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Builds app ThemeData for both dark and light modes.
class AppTheme {
  AppTheme._();

  static const _buttonRadius = 6.0;
  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_buttonRadius),
  );

  static ThemeData dark({required String uiFontFamily}) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.deepBackground,
      canvasColor: AppColors.panelBase,
      primaryColor: AppColors.accent,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentSecondary,
        surface: AppColors.panelBase,
        onSurface: AppColors.foreground,
      ),
      fontFamily: uiFontFamily,
      dividerColor: AppColors.border,
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(shape: WidgetStateProperty.all(_buttonShape)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return AppColors.scrollbarSliderActiveBackground;
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.scrollbarSliderHoverBackground;
          }
          return AppColors.scrollbarSliderBackground;
        }),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: AppColors.listHoverBackground,
    );
  }

  static ThemeData light({required String uiFontFamily}) {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.deepBackground,
      canvasColor: AppColors.panelBase,
      primaryColor: AppColors.accent,
      colorScheme: ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentSecondary,
        surface: AppColors.panelBase,
        onSurface: AppColors.foreground,
      ),
      fontFamily: uiFontFamily,
      dividerColor: AppColors.border,
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_buttonShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(shape: WidgetStateProperty.all(_buttonShape)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return AppColors.scrollbarSliderActiveBackground;
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.scrollbarSliderHoverBackground;
          }
          return AppColors.scrollbarSliderBackground;
        }),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: AppColors.listHoverBackground,
    );
  }
}
