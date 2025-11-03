// ignore_for_file: avoid_print
import 'dart:io';

/// Script برای کامنت کردن تمام print statements در پروژه
/// اجرا: dart run scripts/comment_prints.dart
void main() async {
  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    print('Error: lib directory not found');
    exit(1);
  }

  int totalCommented = 0;
  int filesProcessed = 0;

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip logger files
      if (entity.path.contains('logger.dart') ||
          entity.path.contains('mini_request_logger.dart')) {
        continue;
      }

      final content = await entity.readAsString();
      final lines = content.split('\n');
      final newLines = <String>[];
      int commentedInFile = 0;

      for (final line in lines) {
        // Check if line starts with print( (with optional whitespace)
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('print(') &&
            !trimmed.startsWith('// print(') &&
            !trimmed.startsWith('* print(')) {
          // Comment out the print
          final indent = line.substring(0, line.length - trimmed.length);
          newLines.add('$indent// $trimmed');
          commentedInFile++;
        } else {
          newLines.add(line);
        }
      }

      if (commentedInFile > 0) {
        await entity.writeAsString(newLines.join('\n'));
        print('✓ ${entity.path}: $commentedInFile print(s) commented');
        totalCommented += commentedInFile;
        filesProcessed++;
      }
    }
  }

  print('\n✅ Done!');
  print('   Files processed: $filesProcessed');
  print('   Total prints commented: $totalCommented');
}

