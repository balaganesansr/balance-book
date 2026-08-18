import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Light and dark themes for the app.
///
/// The look is deliberately closer to a modern finance app than to accounting
/// software: flat surfaces, hairline borders instead of shadows, generous
/// spacing, and large tabular numbers wherever money appears.
class AppTheme {
  const AppTheme._();

  static const _radius = 16.0;
  static const _fieldRadius = 14.0;

  static const _primaryLight = Color(0xFF4F46E5);
  static const _primaryDark = Color(0xFF818CF8);

  /// Built once. ThemeData construction is not free, and this is read on
  /// every rebuild of the app root.
  static final ThemeData _light = _build(
    brightness: Brightness.light,
    colors: AppColors.light,
    scheme: const ColorScheme.light(
      primary: _primaryLight,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEEF2FF),
      onPrimaryContainer: Color(0xFF312E81),
      secondary: Color(0xFF0F766E),
      onSecondary: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0D1117),
      onSurfaceVariant: Color(0xFF656D79),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFAFAFB),
      surfaceContainer: Color(0xFFF5F6F8),
      surfaceContainerHigh: Color(0xFFF1F2F5),
      surfaceContainerHighest: Color(0xFFE9EBEF),
      outline: Color(0xFFD3D6DC),
      outlineVariant: Color(0xFFE5E7EB),
      error: Color(0xFFDC2626),
      onError: Colors.white,
      errorContainer: Color(0xFFFEF2F2),
      onErrorContainer: Color(0xFF991B1B),
    ),
    scaffold: const Color(0xFFF5F6F8),
  );

  static ThemeData light() => _light;

  static final ThemeData _dark = _build(
    brightness: Brightness.dark,
    colors: AppColors.dark,
    scheme: const ColorScheme.dark(
      primary: _primaryDark,
      onPrimary: Color(0xFF1E1B4B),
      primaryContainer: Color(0xFF1D1B45),
      onPrimaryContainer: Color(0xFFC7D2FE),
      secondary: Color(0xFF2DD4BF),
      onSecondary: Color(0xFF042F2E),
      surface: Color(0xFF141619),
      onSurface: Color(0xFFE9EAEE),
      onSurfaceVariant: Color(0xFF9AA1AD),
      surfaceContainerLowest: Color(0xFF0A0B0E),
      surfaceContainerLow: Color(0xFF141619),
      surfaceContainer: Color(0xFF191C20),
      surfaceContainerHigh: Color(0xFF21252B),
      surfaceContainerHighest: Color(0xFF2A2F36),
      outline: Color(0xFF363B44),
      outlineVariant: Color(0xFF262A31),
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF2A1111),
      onErrorContainer: Color(0xFFFCA5A5),
    ),
    scaffold: const Color(0xFF0A0B0E),
  );

  static ThemeData dark() => _dark;

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
    required ColorScheme scheme,
    required Color scaffold,
  }) {
    final isLight = brightness == Brightness.light;
    final base = ThemeData(brightness: brightness, colorScheme: scheme);
    final text = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
      extensions: [colors],
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffold,
                systemNavigationBarIconBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffold,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
      ),

      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: colors.hairline),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colors.hairline,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _fieldBorder(colors.hairline),
        enabledBorder: _fieldBorder(colors.hairline),
        focusedBorder: _fieldBorder(scheme.primary, width: 2),
        errorBorder: _fieldBorder(scheme.error),
        focusedErrorBorder: _fieldBorder(scheme.error, width: 2),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodySmall?.copyWith(color: scheme.primary),
        hintStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 52dp keeps primary actions comfortably thumb-sized one-handed.
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_fieldRadius),
          ),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_fieldRadius),
          ),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceSunken,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: colors.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        showCheckmark: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceRaised,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surfaceRaised,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? const Color(0xFF1F2328)
            : const Color(0xFF2A2F36),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: colors.surfaceSunken,
        circularTrackColor: colors.surfaceSunken,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFF1F2328) : const Color(0xFF2A2F36),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            fontSize: 20,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
          bodySmall: base.bodySmall?.copyWith(
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  /// Tabular figures, so a changing balance never shifts the digits around.
  static const tabularFigures = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
