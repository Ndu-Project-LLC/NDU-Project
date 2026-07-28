import 'package:flutter/material.dart';

const String appFontFamily = 'Satoshi';
const String _appFontFamily = appFontFamily;

class LightModeColors {
  // Brand: yellow accent like the screenshot logo, neutral blue/green for UI
  static const lightPrimary = Color(0xFFFFC812); // Brand yellow
  static const lightOnPrimary = Color(0xFF1C1C1C);
  static const lightPrimaryContainer =
      Color(0xFFFFF4CC); // Soft yellow container
  static const lightOnPrimaryContainer = Color(0xFF3D2E00);
  static const lightSecondary =
      Color(0xFF2563EB); // Info blue (links, highlights)
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightTertiary = Color(0xFF16A34A); // Success green
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFE3E0);
  static const lightOnErrorContainer = Color(0xFF410002);
  static const lightInversePrimary = Color(0xFF0F172A);
  static const lightShadow = Color(0xFF000000);
  // Subtle bluish-white background like the screenshot (cards sit on it)
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF0F172A);
  static const lightAppBarBackground = Color(0xFFFFFFFF);
  static const accent = Color(0xFFFFC107); // Yellow/Gold accent color
}

class DarkModeColors {
  static const darkPrimary = Color(0xFFFFC812);
  static const darkOnPrimary = Color(0xFF141414);
  static const darkPrimaryContainer = Color(0xFF3A3000);
  static const darkOnPrimaryContainer = Color(0xFFFFF4CC);
  static const darkSecondary = Color(0xFF93C5FD); // Softer blue for dark mode
  static const darkOnSecondary = Color(0xFF0B1220);
  static const darkTertiary = Color(0xFF34D399); // Emerald 400
  static const darkOnTertiary = Color(0xFF0B1220);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  static const darkInversePrimary = Color(0xFFFFC812);
  static const darkShadow = Color(0xFF000000);
  static const darkSurface = Color(0xFF0F1115);
  static const darkOnSurface = Color(0xFFE5E7EB);
  static const darkAppBarBackground = Color(0xFF0F1115);
  static const accent = Color(0xFFFFC107); // Yellow/Gold accent color

  // Extended dark mode palette for adaptive UI elements
  static const cardBackground = Color(0xFF1A1D24);
  static const surfaceVariant = Color(0xFF242830);
  static const border = Color(0xFF2D3139);
  static const subtleBackground = Color(0xFF161922);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const successColor = Color(0xFF34D399);
  static const warningColor = Color(0xFFFBBF24);
  static const infoColor = Color(0xFF60A5FA);
  static const aiColor = Color(0xFFA78BFA);
}

/// Extension on BuildContext for easy access to adaptive colors
extension AdaptiveColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get adaptiveSurface => isDarkMode ? DarkModeColors.cardBackground : Colors.white;
  Color get adaptiveBackground => isDarkMode ? DarkModeColors.darkSurface : Colors.white;
  Color get adaptiveTextPrimary => isDarkMode ? DarkModeColors.textPrimary : const Color(0xFF0F172A);
  Color get adaptiveTextSecondary => isDarkMode ? DarkModeColors.textSecondary : const Color(0xFF64748B);
  Color get adaptiveBorder => isDarkMode ? DarkModeColors.border : const Color(0xFFE5E7EB);
  Color get adaptiveSubtle => isDarkMode ? DarkModeColors.subtleBackground : const Color(0xFFF8FAFC);
  Color get adaptiveAccent => isDarkMode ? DarkModeColors.accent : LightModeColors.accent;
  Color get adaptiveCard => isDarkMode ? DarkModeColors.cardBackground : Colors.white;
}

/// Semantic colors shared across light and dark themes
/// These are not bound to Material ColorScheme directly but provide
/// consistent tokens for success/info/warning surfaces and borders.
class AppSemanticColors {
  // Success
  static const success = Color(0xFF16A34A); // Green 600
  static const onSuccess = Color(0xFFFFFFFF);
  static const successSurface = Color(0xFFD1FAE5); // Emerald 100

  // Info
  static const info = Color(0xFF2563EB); // Indigo 600
  static const onInfo = Color(0xFFFFFFFF);
  static const infoSurface = Color(0xFFE6F0FF); // Soft blue

  // Warning
  static const warning = Color(0xFFF59E0B); // Amber 600
  static const onWarning = Color(0xFF1F2937);
  static const warningSurface = Color(0xFFFFF7E6);

  // Neutral / outlines
  static const border = Color(0xFFE5E7EB);
  static const subtle = Color(0xFFF9FAFB);

  // AI / Magic
  static const ai = Color(0xFF8B5CF6); // Violet 500
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      fontFamily: _appFontFamily,
      colorScheme: ColorScheme.light(
        primary: LightModeColors.lightPrimary,
        onPrimary: LightModeColors.lightOnPrimary,
        primaryContainer: LightModeColors.lightPrimaryContainer,
        onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
        secondary: LightModeColors.lightSecondary,
        onSecondary: LightModeColors.lightOnSecondary,
        tertiary: LightModeColors.lightTertiary,
        onTertiary: LightModeColors.lightOnTertiary,
        error: LightModeColors.lightError,
        onError: LightModeColors.lightOnError,
        errorContainer: LightModeColors.lightErrorContainer,
        onErrorContainer: LightModeColors.lightOnErrorContainer,
        inversePrimary: LightModeColors.lightInversePrimary,
        shadow: LightModeColors.lightShadow,
        surface: LightModeColors.lightSurface,
        onSurface: LightModeColors.lightOnSurface,
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightModeColors.lightSurface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: LightModeColors.lightAppBarBackground,
        foregroundColor: LightModeColors.lightOnPrimaryContainer,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppSemanticColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppSemanticColors.border,
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppSemanticColors.subtle,
        selectedColor: LightModeColors.lightPrimaryContainer,
        labelStyle: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelMedium,
          fontWeight: FontWeight.w600,
          color: LightModeColors.lightOnSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppSemanticColors.border)),
        iconTheme: const IconThemeData(color: Colors.grey),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
            fontFamily: _appFontFamily, color: Color(0xFF9CA3AF), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppSemanticColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFFFFD700), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LightModeColors.lightError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: LightModeColors.lightError, width: 1.5),
        ),
        prefixIconColor: const Color(0xFF94A3B8),
        suffixIconColor: const Color(0xFF94A3B8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(
              BorderSide(color: AppSemanticColors.border)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          foregroundColor: const WidgetStatePropertyAll(Color(0xFF0F172A)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor:
              const WidgetStatePropertyAll(LightModeColors.lightSecondary),
          textStyle: const WidgetStatePropertyAll(TextStyle(
              fontFamily: _appFontFamily, fontWeight: FontWeight.w600)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        iconColor: Color(0xFF64748B),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF5F8FC)),
        dataRowColor: WidgetStatePropertyAll(Colors.white),
        headingTextStyle: TextStyle(
          fontFamily: _appFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
          letterSpacing: 0.2,
        ),
        dataTextStyle: TextStyle(
          fontFamily: _appFontFamily,
          fontSize: 13,
          color: Color(0xFF0F172A),
          height: 1.45,
        ),
        dividerThickness: 0.8,
        columnSpacing: 18,
        horizontalMargin: 14,
        headingRowHeight: 52,
        dataRowMinHeight: 60,
        dataRowMaxHeight: 220,
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.displayLarge,
          fontWeight: FontWeight.w400,
        ),
        displayMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.displayMedium,
          fontWeight: FontWeight.w400,
        ),
        displaySmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.displaySmall,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.headlineLarge,
          fontWeight: FontWeight.w400,
        ),
        headlineMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.headlineMedium,
          fontWeight: FontWeight.w500,
        ),
        headlineSmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.headlineSmall,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.titleLarge,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.titleMedium,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.titleSmall,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelLarge,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelMedium,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelSmall,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.bodyLarge,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.bodyMedium,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.bodySmall,
          fontWeight: FontWeight.w400,
        ),
      ),
    );

ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      fontFamily: _appFontFamily,
      colorScheme: ColorScheme.dark(
        primary: DarkModeColors.darkPrimary,
        onPrimary: DarkModeColors.darkOnPrimary,
        primaryContainer: DarkModeColors.darkPrimaryContainer,
        onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
        secondary: DarkModeColors.darkSecondary,
        onSecondary: DarkModeColors.darkOnSecondary,
        tertiary: DarkModeColors.darkTertiary,
        onTertiary: DarkModeColors.darkOnTertiary,
        error: DarkModeColors.darkError,
        onError: DarkModeColors.darkOnError,
        errorContainer: DarkModeColors.darkErrorContainer,
        onErrorContainer: DarkModeColors.darkOnErrorContainer,
        inversePrimary: DarkModeColors.darkInversePrimary,
        shadow: DarkModeColors.darkShadow,
        surface: DarkModeColors.darkSurface,
        onSurface: DarkModeColors.darkOnSurface,
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkModeColors.darkSurface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: DarkModeColors.darkAppBarBackground,
        foregroundColor: DarkModeColors.darkOnPrimaryContainer,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111318),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08),
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF111318),
        selectedColor: const Color(0xFF1B1E25),
        labelStyle: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelMedium,
          fontWeight: FontWeight.w600,
          color: DarkModeColors.darkOnSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withOpacity(0.08))),
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.6)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0B0D11),
        hintStyle: TextStyle(
            fontFamily: _appFontFamily,
            color: Colors.white.withOpacity(0.6),
            fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFFFFD700), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DarkModeColors.darkError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: DarkModeColors.darkError, width: 1.5),
        ),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
              BorderSide(color: Colors.white.withOpacity(0.12))),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor:
              const WidgetStatePropertyAll(DarkModeColors.darkSecondary),
          textStyle: const WidgetStatePropertyAll(TextStyle(
              fontFamily: _appFontFamily, fontWeight: FontWeight.w600)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        iconColor: Colors.white.withOpacity(0.7),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStatePropertyAll(Colors.white.withOpacity(0.06)),
        dataRowColor: const WidgetStatePropertyAll(Color(0xFF111318)),
        headingTextStyle: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE2E8F0),
          letterSpacing: 0.2,
        ),
        dataTextStyle: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: 13,
          color: Color(0xFFCBD5E1),
          height: 1.45,
        ),
        dividerThickness: 0.8,
        columnSpacing: 18,
        horizontalMargin: 14,
        headingRowHeight: 52,
        dataRowMinHeight: 60,
        dataRowMaxHeight: 220,
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.displayLarge,
          fontWeight: FontWeight.w400,
        ),
        displayMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.displayMedium,
          fontWeight: FontWeight.w400,
        ),
        displaySmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.displaySmall,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.headlineLarge,
          fontWeight: FontWeight.w400,
        ),
        headlineMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.headlineMedium,
          fontWeight: FontWeight.w500,
        ),
        headlineSmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.headlineSmall,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.titleLarge,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.titleMedium,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.titleSmall,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelLarge,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelMedium,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.labelSmall,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.bodyLarge,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.bodyMedium,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: const TextStyle(
          fontFamily: _appFontFamily,
          fontSize: FontSizes.bodySmall,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
