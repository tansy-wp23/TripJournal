import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_logo.dart';

/// Branded launch screen, shown while the app works out who is signed in.
///
/// This is the second half of the splash, not a decoration. The native launch
/// screen (`android/app/src/main/res/drawable-v21/launch_background.xml`, and
/// the Android 12+ system splash in `values-v31/styles.xml`) draws this same
/// artwork on this same background, then hands over the moment Flutter paints
/// its first frame. Before this widget existed that handover landed on a bare
/// spinner over an empty [Scaffold], so the logo visibly flashed away and came
/// back once Home loaded its own content.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('app-splash'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Driven off the window rather than fixed: a phone in landscape
            // has roughly 320 logical pixels of height to spend on the logo,
            // the label and the indicator together.
            final logo = math.max(
              56.0,
              math.min(
                160.0,
                math.min(constraints.maxHeight * 0.3, constraints.maxWidth * 0.45),
              ),
            );

            return Center(
              // Scrolls rather than overflows in the corner cases the fixed
              // sizing above can't cover -- a very short window with the OS
              // font size turned right up.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLogo(size: logo),
                    const SizedBox(height: 24),
                    Text(
                      'TripJournal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
