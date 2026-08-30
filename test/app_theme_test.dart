import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/theme/app_theme.dart';
import 'package:tripjournal/theme/aurora_theme.dart';

void main() {
  test('light theme exposes the approved sky and orange semantics', () {
    final theme = AppTheme.light;
    final aurora = theme.extension<AuroraTheme>();

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF0F9FF));
    expect(theme.colorScheme.primary, const Color(0xFF0369A1));
    expect(theme.colorScheme.tertiary, const Color(0xFFC2410C));
    expect(aurora?.heroStart, const Color(0xFF11B7D5));
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
  });

  test('dark theme uses layered ocean surfaces rather than pure black', () {
    final theme = AppTheme.dark;
    final aurora = theme.extension<AuroraTheme>();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF071521));
    expect(theme.colorScheme.surface, const Color(0xFF0D2233));
    expect(theme.colorScheme.primary, const Color(0xFF38BDF8));
    expect(aurora?.raisedSurface, const Color(0xFF143247));
  });
}
