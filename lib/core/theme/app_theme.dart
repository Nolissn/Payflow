import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        colors: PayflowColors.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Brand.jade700,
          onPrimary: Brand.white,
          primaryContainer: Brand.jade100,
          onPrimaryContainer: Brand.jade900,
          secondary: Brand.ember500,
          onSecondary: Brand.white,
          secondaryContainer: Brand.ember100,
          onSecondaryContainer: Color(0xFF7A2A0E),
          tertiary: Brand.jade500,
          onTertiary: Brand.white,
          error: Brand.danger,
          onError: Brand.white,
          surface: Brand.white,
          onSurface: Brand.ink,
          onSurfaceVariant: Brand.inkSoft,
          surfaceContainerLowest: Brand.white,
          surfaceContainerLow: Color(0xFFFAF9F6),
          surfaceContainer: Brand.paper,
          surfaceContainerHigh: Color(0xFFEFEEE8),
          surfaceContainerHighest: Brand.paperDeep,
          outline: Color(0xFFCFCCC2),
          outlineVariant: Brand.line,
          inverseSurface: Brand.ink,
          onInverseSurface: Brand.paper,
          inversePrimary: Brand.jade300,
          shadow: Color(0xFF0F1D1A),
          scrim: Color(0xFF0F1D1A),
        ),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        colors: PayflowColors.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Brand.jade300,
          onPrimary: Brand.jade900,
          primaryContainer: Color(0xFF12453B),
          onPrimaryContainer: Brand.jade100,
          secondary: Brand.ember400,
          onSecondary: Color(0xFF3A1406),
          secondaryContainer: Color(0xFF4A2616),
          onSecondaryContainer: Color(0xFFFFD2BF),
          tertiary: Brand.jade500,
          onTertiary: Brand.night,
          error: Color(0xFFF07070),
          onError: Color(0xFF3A0B0B),
          surface: Brand.nightSurface,
          onSurface: Brand.mist,
          onSurfaceVariant: Brand.mistSoft,
          surfaceContainerLowest: Brand.night,
          surfaceContainerLow: Color(0xFF0E1513),
          surfaceContainer: Brand.nightSurface,
          surfaceContainerHigh: Brand.nightRaised,
          surfaceContainerHighest: Brand.nightHigh,
          outline: Color(0xFF3A4A46),
          outlineVariant: Brand.nightLine,
          inverseSurface: Brand.mist,
          onInverseSurface: Brand.night,
          inversePrimary: Brand.jade700,
          shadow: Colors.black,
          scrim: Colors.black,
        ),
      );

  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle s(double size, FontWeight weight, double spacing,
            {double height = 1.25, Color? color}) =>
        TextStyle(
          fontFamily: Brand.fontFamily,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: height,
          color: color ?? primary,
        );
    return TextTheme(
      displayLarge: s(46, FontWeight.w800, -1.8, height: 1.05),
      displayMedium: s(36, FontWeight.w800, -1.2, height: 1.1),
      displaySmall: s(28, FontWeight.w800, -0.8, height: 1.15),
      headlineLarge: s(28, FontWeight.w800, -0.8),
      headlineMedium: s(24, FontWeight.w800, -0.6),
      headlineSmall: s(20, FontWeight.w700, -0.3),
      titleLarge: s(18, FontWeight.w700, -0.2),
      titleMedium: s(16, FontWeight.w700, -0.1),
      titleSmall: s(14, FontWeight.w700, 0),
      bodyLarge: s(16, FontWeight.w500, 0, height: 1.45),
      bodyMedium: s(14, FontWeight.w500, 0, height: 1.45),
      bodySmall: s(12.5, FontWeight.w500, 0.1, height: 1.4, color: secondary),
      labelLarge: s(14, FontWeight.w700, 0.1),
      labelMedium: s(12, FontWeight.w700, 0.2),
      labelSmall: s(11, FontWeight.w700, 0.8),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required PayflowColors colors,
    required ColorScheme scheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final text = _textTheme(colors.textPrimary, colors.textSecondary);
    final pill = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brand.radiusXL));
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Brand.radiusM),
      borderSide: BorderSide(color: colors.hairline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Brand.fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [colors],
      dividerTheme: DividerThemeData(color: colors.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Brand.nightSurface)
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Brand.white),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusL),
          side: isDark ? BorderSide.none : BorderSide(color: colors.hairline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primarySoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? colors.onPrimarySoft
                  : colors.textMuted,
              size: 24,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            text.labelMedium!.copyWith(
              color: states.contains(WidgetState.selected)
                  ? colors.textPrimary
                  : colors.textMuted,
            )),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        extendedTextStyle: text.labelLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: pill,
          textStyle: text.labelLarge!.copyWith(fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: pill,
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge!.copyWith(fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.card,
        selectedColor: scheme.primary,
        disabledColor: colors.chartTrack,
        side: BorderSide(color: colors.hairline),
        shape: pill,
        labelStyle: text.labelLarge!.copyWith(color: colors.textPrimary),
        secondaryLabelStyle: text.labelLarge!.copyWith(color: scheme.onPrimary),
        checkmarkColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          shape: WidgetStatePropertyAll(pill),
          side: WidgetStatePropertyAll(BorderSide(color: colors.hairline)),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? colors.primarySoft
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? colors.onPrimarySoft
                  : colors.textSecondary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Brand.nightRaised : Brand.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        errorBorder:
            inputBorder.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: scheme.error, width: 1.6)),
        labelStyle: text.bodyMedium!.copyWith(color: colors.textSecondary),
        floatingLabelStyle:
            text.labelLarge!.copyWith(color: scheme.primary),
        hintStyle: text.bodyMedium!.copyWith(color: colors.textMuted),
        prefixIconColor: colors.textMuted,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.background,
        showDragHandle: true,
        dragHandleColor: colors.textMuted.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Brand.radiusXL))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.cardRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusXL)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: colors.textSecondary),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.cardRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusXL)),
        headerBackgroundColor: colors.heroBackground,
        headerForegroundColor: colors.heroForeground,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? Brand.nightHigh : Brand.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: Brand.mist),
        actionTextColor: Brand.jade300,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusM)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.cardRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusM)),
        textStyle: text.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.onPrimary : colors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : colors.chartTrack),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: colors.chartTrack,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// Tabular figures keep columns of amounts aligned and stop numbers from
/// jittering during animations.
const tabularFigures = [FontFeature.tabularFigures()];

extension FiguresStyle on TextStyle {
  TextStyle get figures => copyWith(fontFeatures: tabularFigures);
}
