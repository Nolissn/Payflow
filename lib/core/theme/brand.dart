import 'package:flutter/material.dart';

/// Payflow brand palette.
///
/// - **Jade** — primary. Calm, trustworthy, "money in motion". Not the
///   usual fintech blue/purple.
/// - **Ember** — accent. Used sparingly for things that need attention:
///   large payments, deadlines, the coin in the logo.
/// - **Paper / Ink** — warm neutral grounds instead of pure white/black.
abstract final class Brand {
  // Jade (primary)
  static const jade900 = Color(0xFF06332B);
  static const jade800 = Color(0xFF0A4A3F);
  static const jade700 = Color(0xFF0E6B5A);
  static const jade500 = Color(0xFF1E9C82);
  static const jade300 = Color(0xFF5ED3B4);
  static const jade100 = Color(0xFFD3F1E7);
  static const jade50 = Color(0xFFEAF7F2);

  // Ember (accent)
  static const ember600 = Color(0xFFE2572A);
  static const ember500 = Color(0xFFF26B3A);
  static const ember400 = Color(0xFFFF8A5C);
  static const ember100 = Color(0xFFFFE4D8);

  // Neutrals — light
  static const paper = Color(0xFFF4F3EE);
  static const paperDeep = Color(0xFFEAE8E1);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F1D1A);
  static const inkSoft = Color(0xFF55635F);
  static const inkMuted = Color(0xFF8A9692);
  static const line = Color(0xFFE3E1D9);

  // Neutrals — dark
  static const night = Color(0xFF090E0D);
  static const nightSurface = Color(0xFF111917);
  static const nightRaised = Color(0xFF18221F);
  static const nightHigh = Color(0xFF212D2A);
  static const nightLine = Color(0xFF243330);
  static const mist = Color(0xFFE6EEEB);
  static const mistSoft = Color(0xFF9DAEA9);
  static const mistMuted = Color(0xFF6D7F7A);

  // Semantic
  static const positive = Color(0xFF1E9C6B);
  static const warning = Color(0xFFD99A1E);
  static const danger = Color(0xFFD64545);

  // Shape language: soft, generous radii; pills for actions and chips.
  static const radiusS = 10.0;
  static const radiusM = 14.0;
  static const radiusL = 20.0;
  static const radiusXL = 28.0;

  static const fontFamily = 'Manrope';
}

/// Theme-dependent colours that Material's [ColorScheme] does not cover.
@immutable
class PayflowColors extends ThemeExtension<PayflowColors> {
  const PayflowColors({
    required this.background,
    required this.card,
    required this.cardRaised,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.heroBackground,
    required this.heroForeground,
    required this.heroMuted,
    required this.heroLine,
    required this.positive,
    required this.warning,
    required this.danger,
    required this.chartTrack,
  });

  final Color background;
  final Color card;
  final Color cardRaised;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color heroBackground;
  final Color heroForeground;
  final Color heroMuted;
  final Color heroLine;
  final Color positive;
  final Color warning;
  final Color danger;
  final Color chartTrack;

  static const light = PayflowColors(
    background: Brand.paper,
    card: Brand.white,
    cardRaised: Brand.white,
    hairline: Brand.line,
    textPrimary: Brand.ink,
    textSecondary: Brand.inkSoft,
    textMuted: Brand.inkMuted,
    accent: Brand.ember500,
    accentSoft: Brand.ember100,
    onAccentSoft: Color(0xFF9A3412),
    primarySoft: Brand.jade50,
    onPrimarySoft: Brand.jade800,
    heroBackground: Brand.jade900,
    heroForeground: Color(0xFFF4F3EE),
    heroMuted: Color(0xFF9CC3B8),
    heroLine: Color(0xFF1B5A4D),
    positive: Brand.positive,
    warning: Brand.warning,
    danger: Brand.danger,
    chartTrack: Brand.paperDeep,
  );

  static const dark = PayflowColors(
    background: Brand.night,
    card: Brand.nightSurface,
    cardRaised: Brand.nightRaised,
    hairline: Brand.nightLine,
    textPrimary: Brand.mist,
    textSecondary: Brand.mistSoft,
    textMuted: Brand.mistMuted,
    accent: Brand.ember400,
    accentSoft: Color(0xFF3A2219),
    onAccentSoft: Color(0xFFFFB797),
    primarySoft: Color(0xFF12302A),
    onPrimarySoft: Brand.jade300,
    heroBackground: Color(0xFF0D2A24),
    heroForeground: Brand.mist,
    heroMuted: Color(0xFF86B3A7),
    heroLine: Color(0xFF1C463D),
    positive: Color(0xFF4CC38A),
    warning: Color(0xFFF0B544),
    danger: Color(0xFFF07070),
    chartTrack: Brand.nightHigh,
  );

  @override
  PayflowColors copyWith() => this;

  @override
  PayflowColors lerp(PayflowColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PayflowColors(
      background: l(background, other.background),
      card: l(card, other.card),
      cardRaised: l(cardRaised, other.cardRaised),
      hairline: l(hairline, other.hairline),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccentSoft: l(onAccentSoft, other.onAccentSoft),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimarySoft: l(onPrimarySoft, other.onPrimarySoft),
      heroBackground: l(heroBackground, other.heroBackground),
      heroForeground: l(heroForeground, other.heroForeground),
      heroMuted: l(heroMuted, other.heroMuted),
      heroLine: l(heroLine, other.heroLine),
      positive: l(positive, other.positive),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      chartTrack: l(chartTrack, other.chartTrack),
    );
  }
}

extension PayflowThemeContext on BuildContext {
  PayflowColors get colors => Theme.of(this).extension<PayflowColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
