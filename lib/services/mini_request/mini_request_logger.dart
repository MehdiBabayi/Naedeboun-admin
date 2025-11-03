// ignore_for_file: avoid_print
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Logger مخصوص Mini-Request با قابلیت ذخیره در فایل
class MiniRequestLogger {
  static final MiniRequestLogger _instance = MiniRequestLogger._internal();
  static MiniRequestLogger get instance => _instance;
  MiniRequestLogger._internal();

  File? _logFile;
  bool _isEnabled = true;
  final List<String> _memoryLogs = [];
  static const int _maxMemoryLogs = 1000;

  /// فعال/غیرفعال کردن logging
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// مقداردهی اولیه با مسیر فایل
  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/mini_request_logs.txt');

      // پاک کردن لاگ های قدیمی (بیشتر از 7 روز)
      if (await _logFile!.exists()) {
        final stat = await _logFile!.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age.inDays > 7) {
          await _logFile!.delete();
          _logFile = File('${dir.path}/mini_request_logs.txt');
        }
      }

      log('📝 Logger initialized', LogLevel.info);
    } catch (e) {
      print('❌ Failed to initialize logger: $e');
    }
  }

  /// ثبت لاگ
  void log(String message, LogLevel level, {Map<String, dynamic>? data}) {
    if (!_isEnabled) return;

    final timestamp = DateTime.now().toIso8601String();
    final emoji = _getEmojiForLevel(level);
    final logMessage =
        '[$timestamp] $emoji [${level.name.toUpperCase()}] $message';

    // Print به console
    print(logMessage);

    // ذخیره در memory
    _memoryLogs.add(logMessage);
    if (_memoryLogs.length > _maxMemoryLogs) {
      _memoryLogs.removeAt(0);
    }

    // اگر داده اضافی داشت، print کن
    if (data != null && data.isNotEmpty) {
      final dataStr = '    📊 Data: $data';
      print(dataStr);
      _memoryLogs.add(dataStr);
    }

    // ذخیره در فایل (async)
    _writeToFile(logMessage, data);
  }

  /// نوشتن در فایل
  Future<void> _writeToFile(String message, Map<String, dynamic>? data) async {
    try {
      if (_logFile == null) return;

      final buffer = StringBuffer(message);
      buffer.writeln();

      if (data != null && data.isNotEmpty) {
        buffer.writeln('    Data: $data');
      }

      await _logFile!.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (e) {
      // Silent fail for logging (don't spam console)
    }
  }

  /// دریافت emoji برای level
  String _getEmojiForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return '📘';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
    }
  }

  /// دریافت لاگ‌های memory
  List<String> getMemoryLogs() => List.from(_memoryLogs);

  /// دریافت محتوای فایل لاگ
  Future<String?> getLogFileContent() async {
    try {
      if (_logFile == null || !await _logFile!.exists()) return null;
      return await _logFile!.readAsString();
    } catch (e) {
      print('❌ Failed to read log file: $e');
      return null;
    }
  }

  /// پاک کردن لاگ‌ها
  Future<void> clearLogs() async {
    _memoryLogs.clear();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.delete();
    }
    log('🗑️ Logs cleared', LogLevel.info);
  }

  /// Export لاگ‌ها (برای گزارش باگ)
  Future<File?> exportLogs() async {
    try {
      if (_logFile == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final exportFile = File(
        '${dir.path}/mini_request_export_${DateTime.now().millisecondsSinceEpoch}.txt',
      );

      final content = await getLogFileContent();
      if (content != null) {
        await exportFile.writeAsString(content);
        log('📤 Logs exported to ${exportFile.path}', LogLevel.success);
        return exportFile;
      }

      return null;
    } catch (e) {
      log('❌ Failed to export logs: $e', LogLevel.error);
      return null;
    }
  }
}

/// سطح لاگ
enum LogLevel { debug, info, warning, error, success }
