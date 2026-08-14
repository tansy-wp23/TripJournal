import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A 6-digit one-time code input widget, displayed as 6 individual boxes
/// (the typical OTP/2FA UI pattern). The user types digits and they fill
/// left-to-right; backspace clears right-to-left. Auto-advances focus.
///
/// Used by the reactivation screen (Phase 2 stub / Phase 4 full) and will
/// be reused by the deactivation confirmation screen (Phase 5).
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.error = false,
  });

  /// Number of digits (default 6).
  final int length;

  /// Called whenever the code changes, with the current string.
  final ValueChanged<String>? onChanged;

  /// Called when all [length] digits are entered.
  final ValueChanged<String>? onCompleted;

  /// If true, the boxes show an error border color.
  final bool error;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late List<TextEditingController> _controllers;
  // Box focus nodes — ancestors of each TextField. They intercept backspace
  // events that bubble up AFTER the TextField has had its own chance to
  // consume them (e.g. backspace on an already-empty box, where the
  // TextField does nothing and `onChanged` never fires).
  late List<FocusNode> _boxFocusNodes;
  // TextField focus nodes — owned by the TextField itself so requestFocus()
  // actually moves the cursor (this was the original auto-advance bug, see
  // the implementation plan's "Known Issues" section).
  late List<FocusNode> _textFocusNodes;
  late List<String> _digits;

  // Set when the TextField itself cleared a filled box (via its own
  // backspace handling, observed through `onChanged`). The bubbling key
  // event that caused it will then reach this box's ancestor `Focus`
  // handler, which must NOT clear ANOTHER box — it should just swallow it.
  int? _boxClearedByTextField;

  @override
  void initState() {
    super.initState();
    _digits = List.filled(widget.length, '');
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _boxFocusNodes = List.generate(widget.length, (_) => FocusNode());
    _textFocusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _boxFocusNodes) {
      f.dispose();
    }
    for (final f in _textFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _digits.join();

  /// Handles backspace at the box level. This runs after the TextField's own
  /// key handling (Flutter dispatches key events to the focused node first,
  /// then bubbles to ancestor `Focus` widgets).
  ///
  /// Two cases reach here:
  /// - Backspace on an **empty** box → the TextField does nothing and
  ///   `onChanged` never fires, so we clear the PREVIOUS box and move focus.
  /// - Backspace on a **filled** box → the TextField already cleared it
  ///   (via `_onChanged`), so we must NOT clear yet another box; just
  ///   swallow the event so the key-up doesn't re-trigger.
  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        index > 0) {
      if (_boxClearedByTextField == index) {
        // The TextField already handled this backspace for this box.
        _boxClearedByTextField = null;
        return KeyEventResult.handled;
      }

      if (_digits[index].isEmpty) {
        // Backspace on an empty box → clear the previous box and focus it.
        _digits[index - 1] = '';
        _controllers[index - 1].clear();
        _textFocusNodes[index - 1].requestFocus();
        widget.onChanged?.call(_code);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onChanged(int index, String value) {
    final wasFilled = _digits[index].isNotEmpty;

    // Only keep the last character typed (in case of paste or fast typing).
    final digit = value.isEmpty ? '' : value[value.length - 1];
    if (digit.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(digit)) return;

    _digits[index] = digit;
    _controllers[index].text = digit;

    widget.onChanged?.call(_code);

    // The TextField cleared a digit that was previously filled (user pressed
    // backspace with the cursor in a filled box). Move focus back to the
    // previous box and remember that the TextField consumed this backspace,
    // so the bubbling key event doesn't also clear the previous box.
    if (digit.isEmpty && wasFilled && index > 0) {
      _textFocusNodes[index - 1].requestFocus();
      _boxClearedByTextField = index;
      return;
    }

    // Auto-advance to the next box.
    if (digit.isNotEmpty && index < widget.length - 1) {
      _textFocusNodes[index + 1].requestFocus();
    }

    // Check if all digits are entered.
    if (_code.length == widget.length && !_digits.contains('')) {
      widget.onCompleted?.call(_code);
      _textFocusNodes[index].unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = widget.error ? colorScheme.error : colorScheme.outline;
    final focusedBorder = widget.error
        ? BorderSide(color: colorScheme.error, width: 2)
        : BorderSide(color: colorScheme.primary, width: 2);

    // Six 48pt boxes plus their gaps need 328pt, but a 320pt-wide phone minus
    // the form's padding leaves ~256pt. Shrink the boxes to fit rather than
    // overflowing, keeping the 48:56 aspect so they stay square-ish instead of
    // becoming distorted slots.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const maxBoxWidth = 48.0;
        const aspect = 56 / 48;

        final totalGap = gap * (widget.length - 1);
        final available = constraints.maxWidth;
        final boxWidth = available.isFinite
            ? math.max(24.0, math.min(maxBoxWidth, (available - totalGap) / widget.length))
            : maxBoxWidth;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            return Container(
              width: boxWidth,
              height: boxWidth * aspect,
              margin: EdgeInsets.only(right: i < widget.length - 1 ? gap : 0),
          child: Focus(
            focusNode: _boxFocusNodes[i],
            onKeyEvent: (node, event) => _onKey(i, event),
            child: TextField(
              key: Key('otp-digit-$i'),
              controller: _controllers[i],
              // The TextField owns this node directly so requestFocus()
              // moves the actual cursor (fixes the auto-advance + backspace
              // navigation that the old KeyboardListener wrapping couldn't).
              focusNode: _textFocusNodes[i],
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: focusedBorder,
                ),
                contentPadding: EdgeInsets.zero,
              ),
                  style: Theme.of(context).textTheme.headlineSmall,
                  onChanged: (v) => _onChanged(i, v),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}