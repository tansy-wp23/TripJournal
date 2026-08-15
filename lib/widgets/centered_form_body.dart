import 'package:flutter/material.dart';

/// Body wrapper for the app's single-column, centred screens — sign-in, admin
/// sign-in, verification-code entry and the like.
///
/// Replaces the `SafeArea > Center > Padding > Column` those screens each had
/// inline, which broke in two directions:
///
/// * **Too short.** A phone in landscape leaves roughly 320 logical pixels of
///   height, and a plain [Center] gives its child unbounded vertical space, so
///   the column simply overflowed and the primary button became unreachable.
///   Scrolling is what fixes that — and because the scroll view sizes itself to
///   its content, the column still sits centred whenever it does fit.
/// * **Too wide.** On a tablet the same column stretched the full width, so a
///   sign-in button ran the entire span of the screen. [maxWidth] caps it;
///   [Center] keeps it in the middle of whatever is left over.
class CenteredFormBody extends StatelessWidget {
  const CenteredFormBody({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding = const EdgeInsets.all(32),
  });

  final Widget child;

  /// Widest the content is allowed to get, regardless of the window. Roughly a
  /// comfortable reading measure — beyond this a form stops looking like a form.
  final double maxWidth;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
