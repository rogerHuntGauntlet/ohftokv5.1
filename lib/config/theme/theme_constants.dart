import 'package:flutter/material.dart';

class ThemeConstants {
  // Primary Colors
  static const Color primaryColor = Color(0xFF6200EE);
  static const Color primaryColorDark = Color(0xFFBB86FC);
  
  // Secondary Colors
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color secondaryColorDark = Color(0xFF03DAC6);
  
  // Background Colors
  static const Color backgroundColorLight = Colors.white;
  static const Color backgroundColorDark = Color(0xFF121212);
  
  // Surface Colors
  static const Color surfaceColorLight = Colors.white;
  static const Color surfaceColorDark = Color(0xFF1E1E1E);
  
  // Border Colors
  static const Color borderColorLight = Color(0xFFE0E0E0);
  static const Color borderColorDark = Color(0xFF2C2C2C);
  
  // Error Colors
  static const Color errorColor = Color(0xFFB00020);
  static const Color errorColorDark = Color(0xFFCF6679);
  
  // Success Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color successColorDark = Color(0xFF81C784);
  
  // Warning Colors
  static const Color warningColor = Color(0xFFFFA000);
  static const Color warningColorDark = Color(0xFFFFB74D);
  
  // Text Colors
  static const Color textColorLight = Colors.black87;
  static const Color textColorDark = Colors.white;
  static const Color textColorLightSecondary = Colors.black54;
  static const Color textColorDarkSecondary = Colors.white70;
  
  // Psychedelic Colors
  static const List<Color> psychedelicGradient = [
    Color(0xFFFF1744),
    Color(0xFFD500F9),
    Color(0xFF2979FF),
    Color(0xFF00E676),
    Color(0xFFFFEA00),
  ];
  
  // Radii
  static const double buttonRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double inputRadius = 12.0;
  static const double modalRadius = 20.0;
  
  // Elevations
  static const double cardElevation = 4.0;
  static const double modalElevation = 8.0;
  static const double buttonElevation = 2.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [primaryColorDark, secondaryColorDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
  static List<BoxShadow> get defaultShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get darkShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];
} 