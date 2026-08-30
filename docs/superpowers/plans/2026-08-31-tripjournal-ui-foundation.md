# TripJournal UI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the approved Sky & Aurora Light/Dark design foundation and reusable visual primitives without changing TripJournal business behavior.

**Architecture:** A centralized `AppTheme` owns both `ThemeData` trees, while an `AuroraTheme` `ThemeExtension` exposes the few brand values that Material `ColorScheme` does not represent. Small shared widgets consume only `Theme.of(context)` and the extension, allowing later screen plans to compose the same visuals without hard-coded palette values.

**Tech Stack:** Flutter 3.44.x, Dart 3.12.x, Material 3, Flutter widget tests

## Global Constraints

- Android phones are the primary target; Web must remain usable and free of overflow.
- Interface copy remains English.
- Preserve the existing logo, launcher icon, and splash artwork.
- Do not change controllers, repositories, models, Supabase calls, persistence formats, validation, or map behavior.
- Preserve existing widget keys used by tests and automation.
- Normal text contrast must be at least 4.5:1 in Light and Dark themes.
- Touch targets must be at least 44×44 logical pixels.
- Do not overwrite or stage the user's local `web/index.html` modification.

---

### Task 1: Semantic Sky & Aurora theme

**Files:**
- Create: `lib/theme/aurora_theme.dart`
- Create: `lib/theme/app_theme.dart`
- Modify: `lib/main.dart`
- Test: `test/app_theme_test.dart`

**Interfaces:**
- Consumes: Flutter `ThemeData`, `ColorScheme`, and `ThemeExtension<T>`.
- Produces: `AuroraTheme.of(BuildContext)`, `AppTheme.light`, and `AppTheme.dark`.

- [ ] **Step 1: Write the failing theme tests**

Create `test/app_theme_test.dart` with assertions for the public contract:

```dart
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
```

- [ ] **Step 2: Run the test and confirm the missing theme classes fail**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\app_theme_test.dart
```

Expected: compilation fails because `AppTheme` and `AuroraTheme` do not exist.

- [ ] **Step 3: Implement the theme extension**

Create `lib/theme/aurora_theme.dart` with an immutable extension containing:

```dart
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
  }) => AuroraTheme(
    heroStart: heroStart ?? this.heroStart,
    heroMiddle: heroMiddle ?? this.heroMiddle,
    heroEnd: heroEnd ?? this.heroEnd,
    raisedSurface: raisedSurface ?? this.raisedSurface,
    onHero: onHero ?? this.onHero,
  );

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
```

- [ ] **Step 4: Implement both Material themes**

Create `lib/theme/app_theme.dart`. Define exact Light and Dark `ColorScheme` values from the design spec, attach the matching `AuroraTheme`, and centralize the following component styles:

```dart
abstract final class AppTheme {
  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: const Color(0xFFF0F9FF),
    surface: const Color(0xFFFFFFFF),
    surfaceContainer: const Color(0xFFE8F5FA),
    primary: const Color(0xFF0369A1),
    onPrimary: Colors.white,
    secondary: const Color(0xFF0E7490),
    tertiary: const Color(0xFFC2410C),
    onTertiary: Colors.white,
    foreground: const Color(0xFF0C4A6E),
    muted: const Color(0xFF475569),
    outline: const Color(0xFFBAE6FD),
    error: const Color(0xFFB91C1C),
    aurora: const AuroraTheme(
      heroStart: Color(0xFF11B7D5),
      heroMiddle: Color(0xFF4475D8),
      heroEnd: Color(0xFF8865D0),
      raisedSurface: Color(0xFFE8F5FA),
      onHero: Colors.white,
    ),
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: const Color(0xFF071521),
    surface: const Color(0xFF0D2233),
    surfaceContainer: const Color(0xFF143247),
    primary: const Color(0xFF38BDF8),
    onPrimary: const Color(0xFF062638),
    secondary: const Color(0xFF67E8F9),
    tertiary: const Color(0xFFFB923C),
    onTertiary: const Color(0xFF321000),
    foreground: const Color(0xFFE6F6FF),
    muted: const Color(0xFFA9C4D4),
    outline: const Color(0xFF1C4057),
    error: const Color(0xFFFCA5A5),
    aurora: const AuroraTheme(
      heroStart: Color(0xFF0E7490),
      heroMiddle: Color(0xFF3157B7),
      heroEnd: Color(0xFF6546A8),
      raisedSurface: Color(0xFF143247),
      onHero: Colors.white,
    ),
  );
}
```

The private `_build` returns Material 3 `ThemeData` with:

- 18 px cards and dialogs
- 14 px text fields with filled surfaces and persistent outlines
- 14 px buttons with minimum height 48
- 14 px chips
- transparent/default AppBar using the scaffold background
- padded Material tap targets
- 180–300 ms platform transitions already supplied by Material where possible

- [ ] **Step 5: Wire the themes into the app**

In `lib/main.dart`, import `theme/app_theme.dart` and replace both seed-generated themes:

```dart
theme: AppTheme.light,
darkTheme: AppTheme.dark,
```

Keep the existing `themeMode` provider unchanged.

- [ ] **Step 6: Run focused and settings theme tests**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\app_theme_test.dart test\settings_screen_test.dart test\settings_controller_test.dart
```

Expected: all tests pass and System/Light/Dark selection still controls `MaterialApp.themeMode`.

- [ ] **Step 7: Commit the semantic theme**

```powershell
git add -- lib/theme/aurora_theme.dart lib/theme/app_theme.dart lib/main.dart test/app_theme_test.dart
git commit -m "feat(ui): add sky and aurora app themes"
```

### Task 2: Reusable aurora and section primitives

**Files:**
- Create: `lib/widgets/aurora_panel.dart`
- Create: `lib/widgets/app_section_header.dart`
- Test: `test/ui_foundation_widgets_test.dart`

**Interfaces:**
- Consumes: `AuroraTheme.of(context)` and normal themed text/icon widgets.
- Produces: `AuroraPanel({Key? key, required Widget child, EdgeInsetsGeometry padding, String? semanticLabel})` and `AppSectionHeader({required String title, String? actionLabel, VoidCallback? onAction})`.

- [ ] **Step 1: Write failing widget contract tests**

Create `test/ui_foundation_widgets_test.dart`:

```dart
testWidgets('AuroraPanel exposes semantics and renders in both themes', (tester) async {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: AuroraPanel(
          semanticLabel: 'Active trip',
          child: Text('Kuala Lumpur'),
        ),
      ),
    ));
    expect(find.bySemanticsLabel('Active trip'), findsOneWidget);
    expect(find.text('Kuala Lumpur'), findsOneWidget);
  }
});

testWidgets('AppSectionHeader action is omitted unless actionable', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: AppSectionHeader(title: 'Your trips')),
  ));
  expect(find.text('Your trips'), findsOneWidget);
  expect(find.byType(TextButton), findsNothing);
});
```

- [ ] **Step 2: Run the widget tests and verify missing-symbol failures**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\ui_foundation_widgets_test.dart
```

Expected: compilation fails because both widgets do not exist.

- [ ] **Step 3: Implement `AuroraPanel`**

Implement a single decorated `Semantics` + `Container`:

```dart
class AuroraPanel extends StatelessWidget {
  const AuroraPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final aurora = AuroraTheme.of(context);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: aurora.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          )],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: aurora.onHero),
          child: IconTheme.merge(
            data: IconThemeData(color: aurora.onHero),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `AppSectionHeader`**

Use a `Row`, an expanded `titleMedium` title, and an optional `TextButton` only when both `actionLabel` and `onAction` are non-null. Give the action a minimum 44×44 tap target through the global theme.

- [ ] **Step 5: Run the widget tests in Light and Dark**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\ui_foundation_widgets_test.dart test\responsive_layout_test.dart
```

Expected: all tests pass without overflow exceptions.

- [ ] **Step 6: Commit the shared primitives**

```powershell
git add -- lib/widgets/aurora_panel.dart lib/widgets/app_section_header.dart test/ui_foundation_widgets_test.dart
git commit -m "feat(ui): add aurora foundation widgets"
```

### Task 3: Foundation verification gate

**Files:**
- Modify only if verification reveals a foundation defect: `lib/theme/app_theme.dart`, `lib/theme/aurora_theme.dart`, `lib/widgets/aurora_panel.dart`, `lib/widgets/app_section_header.dart`
- Test: existing Flutter suite

**Interfaces:**
- Consumes: the complete Task 1 and Task 2 public contracts.
- Produces: a stable UI foundation ready for the root navigation plan.

- [ ] **Step 1: Format the changed Dart files**

Run:

```powershell
D:\Download\flutter-sdk\bin\dart.bat format lib\theme lib\widgets\aurora_panel.dart lib\widgets\app_section_header.dart test\app_theme_test.dart test\ui_foundation_widgets_test.dart
```

Expected: formatter exits successfully.

- [ ] **Step 2: Run static analysis**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
```

Expected: `No issues found!`.

- [ ] **Step 3: Run the complete Flutter test suite**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test
```

Expected: zero failures; existing platform-conditional skips remain allowed.

- [ ] **Step 4: Confirm protected local files remain untouched**

Run:

```powershell
git status --short
Get-FileHash -Algorithm SHA256 -LiteralPath 'web/index.html'
```

Expected: `web/index.html` remains unstaged with SHA-256 `DA5E56E066F95C40328B72A2B286E8BBBF630BA6B0BA92097645231AF0814BD2`; `.superpowers/` remains untracked and is not committed.

- [ ] **Step 5: Record any verification-only fix**

If Tasks 1 or 2 needed a correction during this gate, stage only the foundation source/test files and commit:

```powershell
git add -- lib/theme lib/widgets/aurora_panel.dart lib/widgets/app_section_header.dart test/app_theme_test.dart test/ui_foundation_widgets_test.dart
git commit -m "fix(ui): stabilize theme foundation"
```

If no correction was necessary, do not create an empty commit.
