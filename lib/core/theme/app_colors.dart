import 'package:flutter/material.dart';

import '../../models/enums.dart';

/// Semantic colours the balance UI needs beyond Material's [ColorScheme].
///
/// Widgets read these instead of hard-coding hex values, so light and dark are
/// defined once and the whole app can be re-tinted from here.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.charge,
    required this.chargeSurface,
    required this.payment,
    required this.paymentSurface,
    required this.outstanding,
    required this.outstandingSurface,
    required this.credit,
    required this.creditSurface,
    required this.settled,
    required this.settledSurface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.hairline,
    required this.heroGradient,
  });

  /// Money the client owes more of: charges and opening balances.
  final Color charge;
  final Color chargeSurface;

  /// Money received.
  final Color payment;
  final Color paymentSurface;

  final Color outstanding;
  final Color outstandingSurface;
  final Color credit;
  final Color creditSurface;
  final Color settled;
  final Color settledSurface;

  /// Card background, one step above the page.
  final Color surfaceRaised;

  /// Inset background for chips, fields and empty rows.
  final Color surfaceSunken;

  /// Hairline divider that stays subtle in both themes.
  final Color hairline;

  /// Gradient behind the dashboard's headline number.
  final List<Color> heroGradient;

  Color forState(BalanceState state) => switch (state) {
    BalanceState.outstanding => outstanding,
    BalanceState.credit => credit,
    BalanceState.settled => settled,
  };

  Color surfaceForState(BalanceState state) => switch (state) {
    BalanceState.outstanding => outstandingSurface,
    BalanceState.credit => creditSurface,
    BalanceState.settled => settledSurface,
  };

  /// Colour for a transaction based on which way it moved the balance.
  Color forDelta(int delta) => delta >= 0 ? charge : payment;

  Color surfaceForDelta(int delta) =>
      delta >= 0 ? chargeSurface : paymentSurface;

  static const light = AppColors(
    charge: Color(0xFFB45309),
    chargeSurface: Color(0xFFFEF6E7),
    payment: Color(0xFF047857),
    paymentSurface: Color(0xFFECFDF5),
    outstanding: Color(0xFFB45309),
    outstandingSurface: Color(0xFFFEF6E7),
    credit: Color(0xFF0369A1),
    creditSurface: Color(0xFFF0F9FF),
    settled: Color(0xFF047857),
    settledSurface: Color(0xFFECFDF5),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF1F2F5),
    hairline: Color(0xFFE5E7EB),
    heroGradient: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
  );

  static const dark = AppColors(
    charge: Color(0xFFFBBF24),
    chargeSurface: Color(0xFF2A1E05),
    payment: Color(0xFF34D399),
    paymentSurface: Color(0xFF06251C),
    outstanding: Color(0xFFFBBF24),
    outstandingSurface: Color(0xFF2A1E05),
    credit: Color(0xFF38BDF8),
    creditSurface: Color(0xFF071E2C),
    settled: Color(0xFF34D399),
    settledSurface: Color(0xFF06251C),
    surfaceRaised: Color(0xFF141619),
    surfaceSunken: Color(0xFF21252B),
    hairline: Color(0xFF262A31),
    heroGradient: [Color(0xFF4338CA), Color(0xFF5B21B6)],
  );

  @override
  AppColors copyWith({
    Color? charge,
    Color? chargeSurface,
    Color? payment,
    Color? paymentSurface,
    Color? outstanding,
    Color? outstandingSurface,
    Color? credit,
    Color? creditSurface,
    Color? settled,
    Color? settledSurface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? hairline,
    List<Color>? heroGradient,
  }) => AppColors(
    charge: charge ?? this.charge,
    chargeSurface: chargeSurface ?? this.chargeSurface,
    payment: payment ?? this.payment,
    paymentSurface: paymentSurface ?? this.paymentSurface,
    outstanding: outstanding ?? this.outstanding,
    outstandingSurface: outstandingSurface ?? this.outstandingSurface,
    credit: credit ?? this.credit,
    creditSurface: creditSurface ?? this.creditSurface,
    settled: settled ?? this.settled,
    settledSurface: settledSurface ?? this.settledSurface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceSunken: surfaceSunken ?? this.surfaceSunken,
    hairline: hairline ?? this.hairline,
    heroGradient: heroGradient ?? this.heroGradient,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      charge: Color.lerp(charge, other.charge, t)!,
      chargeSurface: Color.lerp(chargeSurface, other.chargeSurface, t)!,
      payment: Color.lerp(payment, other.payment, t)!,
      paymentSurface: Color.lerp(paymentSurface, other.paymentSurface, t)!,
      outstanding: Color.lerp(outstanding, other.outstanding, t)!,
      outstandingSurface:
          Color.lerp(outstandingSurface, other.outstandingSurface, t)!,
      credit: Color.lerp(credit, other.credit, t)!,
      creditSurface: Color.lerp(creditSurface, other.creditSurface, t)!,
      settled: Color.lerp(settled, other.settled, t)!,
      settledSurface: Color.lerp(settledSurface, other.settledSurface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      heroGradient: [
        Color.lerp(heroGradient.first, other.heroGradient.first, t)!,
        Color.lerp(heroGradient.last, other.heroGradient.last, t)!,
      ],
    );
  }
}

/// `context.colors.payment`, shorthand for the extension above.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  ColorScheme get scheme => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;
}

/// The palette offered when picking a client's avatar colour.
class AvatarPalette {
  const AvatarPalette._();

  static const colors = <String>[
    '#4F46E5', // indigo
    '#0EA5E9', // sky
    '#0D9488', // teal
    '#16A34A', // green
    '#CA8A04', // amber
    '#EA580C', // orange
    '#DC2626', // red
    '#DB2777', // pink
    '#9333EA', // purple
    '#475569', // slate
  ];

  static Color parse(String hex) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? const Color(0xFF4F46E5) : Color(parsed);
  }

  /// Deterministic colour for a client that has none set, so the same name
  /// always gets the same colour instead of changing between sessions.
  static String forSeed(String seed) {
    if (seed.isEmpty) return colors.first;
    final hash = seed.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7FFFFFFF);
    return colors[hash % colors.length];
  }
}
