import 'package:flutter/material.dart';

import '../../../validation/profile_validation.dart';

/// Tap-to-open date picker for date of birth, styled like a text field so it
/// sits naturally among the other onboarding/edit-screen fields. Optional —
/// [value] may stay null indefinitely; see [validateDateOfBirth].
class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? errorText;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) onChanged(picked);
  }

  String _format(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('date-of-birth-field'),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth',
          border: const OutlineInputBorder(),
          errorText: errorText,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  key: const Key('date-of-birth-clear-button'),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear date of birth',
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          value == null ? 'Not set' : _format(value!),
          style: value == null
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}
