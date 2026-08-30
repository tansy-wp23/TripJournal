import 'package:flutter/material.dart';

@immutable
class AuroraTheme extends ThemeExtension<AuroraTheme> {
  const AuroraTheme({
    required this.heroStart,
    required this.heroMiddle,
    required this.heroEnd,
    required this.raisedSurface,
    required this.onHero,
  });

  final Color heroStart;
  final Color heroMiddle;
  final Color heroEnd;
  final Color raisedSurface;
  final Color onHero;

  static AuroraTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AuroraTheme>();
    if (extension != null) return extension;

    return theme.brightness == Brightness.dark
        ? const AuroraTheme(
            heroStart: Color(0xFF0E7490),
            heroMiddle: Color(0xFF3157B7),
            heroEnd: Color(0xFF6546A8),
            raisedSurface: Color(0xFF143247),
            onHero: Colors.white,
          )
        : const AuroraTheme(
            heroStart: Color(0xFF11B7D5),
            heroMiddle: Color(0xFF4475D8),
            heroEnd: Color(0xFF8865D0),
            raisedSurface: Color(0xFFE8F5FA),
            onHero: Colors.white,
          );
  }

  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroStart, heroMiddle, heroEnd],
  );

  @override
  AuroraTheme copyWith({
    Color? heroStart,
    Color? heroMiddle,
    Color? heroEnd,
    Color? raisedSurface,
    Color? onHero,
  }) {
    return AuroraTheme(
      heroStart: heroStart ?? this.heroStart,
      heroMiddle: heroMiddle ?? this.heroMiddle,
      heroEnd: heroEnd ?? this.heroEnd,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      onHero: onHero ?? this.onHero,
    );
  }

  @override
  AuroraTheme lerp(covariant AuroraTheme? other, double t) {
    if (other == null) return this;
    return AuroraTheme(
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroMiddle: Color.lerp(heroMiddle, other.heroMiddle, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      raisedSurface: Color.lerp(raisedSurface, other.raisedSurface, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
    );
  }
}
