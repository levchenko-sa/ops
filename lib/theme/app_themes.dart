import 'package:flutter/material.dart';

enum AppThemeChoice {
  light,
  dark,
  black,
}

extension AppThemeChoiceX on AppThemeChoice {
  String get storageValue => name;

  String get title {
    switch (this) {
      case AppThemeChoice.light:
        return 'Светлая';
      case AppThemeChoice.dark:
        return 'Тёмная';
      case AppThemeChoice.black:
        return 'Чёрная AMOLED';
    }
  }

  String get description {
    switch (this) {
      case AppThemeChoice.light:
        return 'Светлый фон, мягкий контраст';
      case AppThemeChoice.dark:
        return 'Тёмно-серый фон, комфортно вечером';
      case AppThemeChoice.black:
        return 'Чистый чёрный фон, минимум свечения экрана';
    }
  }

  static AppThemeChoice fromStorage(String? value) {
    switch (value) {
      case 'dark':
        return AppThemeChoice.dark;
      case 'black':
        return AppThemeChoice.black;
      default:
        return AppThemeChoice.light;
    }
  }
}

class AppThemes {
  static const _lightPrimary = Color(0xFF275EA8);
  static const _darkPrimary = Color(0xFF83B4FF);
  static const _blackPrimary = Color(0xFF8AB8FF);

  static ThemeData forChoice(AppThemeChoice choice) {
    switch (choice) {
      case AppThemeChoice.light:
        return light();
      case AppThemeChoice.dark:
        return dark();
      case AppThemeChoice.black:
        return black();
    }
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD9E7FF),
      onPrimaryContainer: Color(0xFF102A4C),
      secondary: Color(0xFF49627F),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDCE7F4),
      onSecondaryContainer: Color(0xFF1D2E42),
      tertiary: Color(0xFF476B5A),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD4EBDD),
      onTertiaryContainer: Color(0xFF17382A),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFF8FAFC),
      onSurface: Color(0xFF1A1D21),
      surfaceContainerHighest: Color(0xFFE8EDF2),
      onSurfaceVariant: Color(0xFF46515C),
      outline: Color(0xFF7B8792),
      outlineVariant: Color(0xFFC6CDD4),
      shadow: Color(0x33000000),
      scrim: Color(0x66000000),
      inverseSurface: Color(0xFF2D3136),
      onInverseSurface: Color(0xFFF2F4F6),
      inversePrimary: Color(0xFFAFCBFF),
    );

    return _base(
      scheme: scheme,
      scaffold: const Color(0xFFF3F6F9),
      appBar: const Color(0xFFF8FAFC),
      card: const Color(0xFFFFFFFF),
      divider: const Color(0xFFD9E0E6),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: Color(0xFF082B56),
      primaryContainer: Color(0xFF173D68),
      onPrimaryContainer: Color(0xFFD9E8FF),
      secondary: Color(0xFFAEC7E4),
      onSecondary: Color(0xFF173049),
      secondaryContainer: Color(0xFF2A435B),
      onSecondaryContainer: Color(0xFFD9E8F5),
      tertiary: Color(0xFFA7D0BA),
      onTertiary: Color(0xFF153729),
      tertiaryContainer: Color(0xFF294D3C),
      onTertiaryContainer: Color(0xFFD0EDDE),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF6E2724),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF182027),
      onSurface: Color(0xFFE7EBEF),
      surfaceContainerHighest: Color(0xFF27323B),
      onSurfaceVariant: Color(0xFFBCC6CF),
      outline: Color(0xFF87939D),
      outlineVariant: Color(0xFF3E4A54),
      shadow: Color(0x99000000),
      scrim: Color(0x99000000),
      inverseSurface: Color(0xFFE7EBEF),
      onInverseSurface: Color(0xFF242B31),
      inversePrimary: Color(0xFF275EA8),
    );

    return _base(
      scheme: scheme,
      scaffold: const Color(0xFF11171C),
      appBar: const Color(0xFF151D24),
      card: const Color(0xFF1A232A),
      divider: const Color(0xFF35414A),
    );
  }

  static ThemeData black() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _blackPrimary,
      onPrimary: Color(0xFF0B2E58),
      primaryContainer: Color(0xFF15375D),
      onPrimaryContainer: Color(0xFFDCEAFF),
      secondary: Color(0xFFB4C9E1),
      onSecondary: Color(0xFF1C3045),
      secondaryContainer: Color(0xFF202D39),
      onSecondaryContainer: Color(0xFFDCE7F1),
      tertiary: Color(0xFFA9D2BC),
      onTertiary: Color(0xFF17392A),
      tertiaryContainer: Color(0xFF1B3329),
      onTertiaryContainer: Color(0xFFD1EDDE),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF54201E),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF080A0C),
      onSurface: Color(0xFFE8EAED),
      surfaceContainerHighest: Color(0xFF171B1F),
      onSurfaceVariant: Color(0xFFB9C0C7),
      outline: Color(0xFF7F8992),
      outlineVariant: Color(0xFF30363C),
      shadow: Colors.black,
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFE8EAED),
      onInverseSurface: Color(0xFF17191C),
      inversePrimary: Color(0xFF275EA8),
    );

    return _base(
      scheme: scheme,
      scaffold: Colors.black,
      appBar: const Color(0xFF050607),
      card: const Color(0xFF0B0D0F),
      divider: const Color(0xFF2B3035),
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffold,
    required Color appBar,
    required Color card,
    required Color divider,
  }) {
    final baseText = ThemeData(
      brightness: scheme.brightness,
      useMaterial3: true,
    ).textTheme;

    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        height: 1.32,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        height: 1.30,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: card,
      dividerColor: divider,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: appBar,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 19,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          height: 1.28,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.8,
        space: 1,
      ),
    );
  }
}
