const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String formatDate(DateTime dt) {
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatWeekday(DateTime dt) => _weekdays[dt.weekday - 1];

String formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Path-separator-agnostic basename — real device photo paths (Windows) use
/// `\`, mock/asset paths use `/`.
String basename(String path) => path.replaceAll('\\', '/').split('/').last;
