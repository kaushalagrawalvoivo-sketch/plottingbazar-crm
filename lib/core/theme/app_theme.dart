import 'package:flutter/material.dart';

/// Central place for the app's look and feel. To re-brand the whole app
/// (e.g. change the primary color for a different client/company), you
/// only need to edit the constants in this file -- every screen already
/// pulls its colors, shapes and text styles from [AppTheme.data].
class AppTheme {
  const AppTheme._();

  /// The single source of truth for the brand color. Change this one
  /// value to re-theme every button, chip, app bar accent, etc.
  static const Color brandColor = Color(0xFF4F46E5);

  static const Color _background = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFEAECF0);
  static const Color _inputBorder = Color(0xFFD0D5DD);

  static ThemeData get data {
    final colorScheme = ColorScheme.fromSeed(seedColor: brandColor);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _cardBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _cardBorder,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
