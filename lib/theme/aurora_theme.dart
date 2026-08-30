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
    return Theme.of(context).extension<AuroraTheme>()!;
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
