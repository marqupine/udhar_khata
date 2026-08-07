import 'package:flutter/material.dart';

class AppTheme {
  // Golden & Saffron Color Palette
  static const Color saffronPrimary = Color(0xFFFF8C00); // Deep Saffron / Dark Orange
  static const Color saffronLight = Color(0xFFFFA726);   // Warm Saffron Light
  static const Color saffronDark = Color(0xFFE65100);    // Deep Warm Saffron
  
  // Backward compatibility aliases for primary theme references
  static const Color primary = saffronPrimary;
  static const Color primaryDark = saffronDark;
  
  static const Color royalGold = Color(0xFFFFD700);      // Royal Pure Gold
  static const Color goldAccent = Color(0xFFFFC107);     // Amber Gold
  static const Color warmAmber = Color(0xFFFFB300);      // Warm Amber
  static const Color darkGold = Color(0xFFB8860B);       // Dark Goldenrod

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFFFBF5);     // Creamy Warm Background
  static const Color surface = Color(0xFFFFFFFF);        // Pure White Surface
  static const Color surfaceVariant = Color(0xFFFFF8F0); // Subtle Warm Tint
  static const Color cardBorder = Color(0xFFFFE8CC);     // Warm Gold Border Tint

  // Dark Elements & Text
  static const Color textPrimary = Color(0xFF2C1D11);    // Deep Warm Charcoal
  static const Color textSecondary = Color(0xFF6E5644);  // Warm Slate Brown
  static const Color textMuted = Color(0xFFA38C7A);      // Muted Warm Gray

  // Status Badge Colors (Tailored for Golden/Saffron theme)
  static const Color paidBg = Color(0xFFE8F5E9);        // Soft Green
  static const Color paidText = Color(0xFF2E7D32);      // Forest Green

  static const Color partialBg = Color(0xFFFFF3E0);     // Warm Saffron Tint
  static const Color partialText = Color(0xFFE65100);   // Deep Saffron

  static const Color pendingBg = Color(0xFFFFEBEE);     // Soft Warm Red
  static const Color pendingText = Color(0xFFC62828);   // Warm Red

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [saffronPrimary, goldAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldenGradient = LinearGradient(
    colors: [Color(0xFFFFA000), Color(0xFFFFD700)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardHeaderGradient = LinearGradient(
    colors: [Color(0xFFFFF8E7), Color(0xFFFFF3E0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: saffronPrimary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saffronPrimary,
        brightness: Brightness.light,
        primary: saffronPrimary,
        onPrimary: Colors.white,
        secondary: goldAccent,
        onSecondary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: saffronPrimary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cardBorder, width: 1.2),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: saffronPrimary,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: saffronPrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: pendingText, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: pendingText, width: 2.0),
        ),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: saffronPrimary,
        suffixIconColor: textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: saffronPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: saffronPrimary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: saffronPrimary,
          side: const BorderSide(color: saffronPrimary, width: 1.8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
    );
  }
}
