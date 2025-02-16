import 'package:flutter/material.dart';
import 'theme_constants.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: ThemeConstants.primaryColor,
        secondary: ThemeConstants.secondaryColor,
        surface: ThemeConstants.surfaceColorLight,
        background: ThemeConstants.backgroundColorLight,
        error: ThemeConstants.errorColor,
      ),
      textTheme: _buildTextTheme(),
      buttonTheme: _buildButtonTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      cardTheme: _buildCardTheme(),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: ThemeConstants.primaryColorDark,
        secondary: ThemeConstants.secondaryColorDark,
        surface: ThemeConstants.surfaceColorDark,
        background: ThemeConstants.backgroundColorDark,
        error: ThemeConstants.errorColor,
      ),
      textTheme: _buildTextTheme(isDark: true),
      buttonTheme: _buildButtonTheme(isDark: true),
      inputDecorationTheme: _buildInputDecorationTheme(isDark: true),
      cardTheme: _buildCardTheme(isDark: true),
    );
  }

  static TextTheme _buildTextTheme({bool isDark = false}) {
    final Color textColor = isDark ? Colors.white : Colors.black;
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textColor.withOpacity(0.87),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textColor.withOpacity(0.87),
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    );
  }

  static ButtonThemeData _buildButtonTheme({bool isDark = false}) {
    return ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.buttonRadius),
      ),
      buttonColor: isDark
          ? ThemeConstants.primaryColorDark
          : ThemeConstants.primaryColor,
      textTheme: ButtonTextTheme.primary,
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme({bool isDark = false}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? ThemeConstants.surfaceColorDark
          : ThemeConstants.surfaceColorLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.inputRadius),
        borderSide: BorderSide(
          color: isDark
              ? ThemeConstants.borderColorDark
              : ThemeConstants.borderColorLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.inputRadius),
        borderSide: BorderSide(
          color: isDark
              ? ThemeConstants.primaryColorDark
              : ThemeConstants.primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.inputRadius),
        borderSide: BorderSide(
          color: ThemeConstants.errorColor,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  static CardTheme _buildCardTheme({bool isDark = false}) {
    return CardTheme(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardRadius),
      ),
      color: isDark
          ? ThemeConstants.surfaceColorDark
          : ThemeConstants.surfaceColorLight,
    );
  }
} 