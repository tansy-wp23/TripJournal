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
  late List<FocusNode> _focusNodes;
  late List<String> _digits;

  @override
  void initState() {
    super.initState();
    _digits = List.filled(widget.length, '');
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _digits.join();

  void _onChanged(int index, String value) {
    // Only keep the last character typed (in case of paste or fast typing).
    final digit = value.isEmpty ? '' : value[value.length - 1];
    if (digit.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(digit)) return;

    _digits[index] = digit;
    _controllers[index].text = digit;

    widget.onChanged?.call(_code);

    // Auto-advance to the next box.
    if (digit.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Check if all digits are entered.
    if (_code.length == widget.length && !_digits.contains('')) {
      widget.onCompleted?.call(_code);
      _focusNodes[index].unfocus();
    }
  }

  void _onKey(int index, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_digits[index].isEmpty && index > 0) {
        // Backspace on an empty box → clear the previous box and focus it.
        _digits[index - 1] = '';
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        widget.onChanged?.call(_code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = widget.error ? colorScheme.error : colorScheme.outline;
    final focusedBorder = widget.error
        ? BorderSide(color: colorScheme.error, width: 2)
        : BorderSide(color: colorScheme.primary, width: 2);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (i) {
        return Container(
          width: 48,
          height: 56,
          margin: EdgeInsets.only(right: i < widget.length - 1 ? 8 : 0),
          child: KeyboardListener(
            focusNode: _focusNodes[i],
            onKeyEvent: (e) => _onKey(i, e),
            child: TextField(
              key: Key('otp-digit-$i'),
              controller: _controllers[i],
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
  }
}