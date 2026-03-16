// Regenerates lib/build_info.dart with the current date.
// Usage:  dart run tool/update_build_info.dart

import 'dart:io';

void main() {
  final now = DateTime.now();
  final stamp =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final content = '''// Auto-generated — do not edit by hand.
// Regenerate:  dart run tool/update_build_info.dart
const String buildTimestamp = '$stamp';
''';

  File('lib/build_info.dart').writeAsStringSync(content);
  print('Updated lib/build_info.dart  →  $stamp');
}
