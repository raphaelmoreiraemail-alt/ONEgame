import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppFonts {
  static const display = 'Bungee';
  static const body = 'Inter';

  /// Tabular figures so scores and timers do not jitter.
  static const tabular = [FontFeature.tabularFigures()];
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.night : AppColors.bone;
    final foreground = isDark ? AppColors.bone : AppColors.night;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.alarmRed,
      onPrimary: Colors.white,
      secondary: AppColors.yellow,
      onSecondary: AppColors.night,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: background,
      onSurface: foreground,
      surfaceContainerHighest: isDark
          ? const Color(0xFF2A2223)
          : const Color(0xFFE8DDD2),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: AppFonts.body,
    );

    TextStyle? display(TextStyle? s) => s?.copyWith(
      fontFamily: AppFonts.display,
      fontFeatures: AppFonts.tabular,
      color: foreground,
    );

    final text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: display(text.displayLarge),
        displayMedium: display(text.displayMedium),
        displaySmall: display(text.displaySmall),
        headlineLarge: display(text.headlineLarge),
        headlineMedium: display(text.headlineMedium),
        headlineSmall: display(text.headlineSmall),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 20,
          color: foreground,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Accessibility: touch targets >= 44 pt (section 12).
          minimumSize: const Size(88, 52),
          textStyle: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
