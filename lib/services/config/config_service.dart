import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../utils/logger.dart';

/// سرویس مدیریت تنظیمات برنامه
class ConfigService {
  static ConfigService? _instance;
  static ConfigService get instance => _instance ??= ConfigService._();

  ConfigService._();

  Map<String, dynamic>? _config;

  /// بارگذاری تنظیمات از فایل config.json
  Future<void> loadConfig() async {
    try {
      final String configString = await rootBundle.loadString(
        'lib/config.json',
      );
      _config = json.decode(configString);
      Logger.info('✅ ConfigService: Config loaded successfully');
      Logger.info('📋 ConfigService: Theme mode: ${_config?['themeMode']}');
      Logger.info('📋 ConfigService: Dev mode: ${_config?['devMode']}');
    } catch (e, stackTrace) {
      // ❌ به جای استفاده از پیش‌فرض، خطا را throw کن
      Logger.error('❌ ConfigService: CRITICAL ERROR loading config', e, stackTrace);
      Logger.info('❌ ConfigService: Cannot continue without config.json!');
      
      // خطا را throw کن تا برنامه متوقف شود و مشکل مشخص شود
      throw Exception(
        'Failed to load config.json: $e\n'
        'This is a critical error. The app cannot function without config.json.\n'
        'Please ensure lib/config.json exists and is valid JSON.'
      );
    }
  }

  /// دریافت حالت تم
  ThemeMode get themeMode {
    final mode = _config?['themeMode'] as String?;
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  /// دریافت حالت توسعه
  bool get isDevMode => _config?['devMode'] as bool? ?? true;

  /// طول کد OTP (تعداد ارقام)
  int get otpLength => _config?['otpLength'] as int? ?? 4;

  /// حداکثر تعداد تلاش برای ارسال کد OTP قبل از بن
  int get otpMaxAttempts => _config?['otpMaxAttempts'] as int? ?? 5;

  /// مدت زمان بن به ساعت
  int get otpBanHours => _config?['otpBanHours'] as int? ?? 3;

  /// دریافت حالت قفل پرتره
  bool get isPortraitLocked => _config?['portraitLock'] as bool? ?? true;

  /// دریافت سرعت اسکرول PDF
  double get pdfScrollSpeed =>
      (_config?['pdfScrollSpeed'] as num?)?.toDouble() ?? 1.0;

  /// آیا Pull-to-Refresh فعال است؟
  bool get isPullToRefreshEnabled =>
      _config?['pullToRefreshEnabled'] as bool? ?? true;

  /// حداکثر تعداد رفرش مجاز
  int get maxRefreshCount => _config?['maxRefreshCount'] as int? ?? 10;

  /// تاخیر قبل از نمایش پیام قطع اینترنت بعد از disconnect
  int get networkErrorDelayAfterDisconnect =>
      _config?['networkErrorDelayAfterDisconnect'] as int? ?? 2;

  /// فاصله زمانی بررسی محتوای جدید توسط Mini-Request (ساعت)
  int get miniRequestIntervalHours =>
      _config?['miniRequestIntervalHours'] as int? ?? 1;

  /// فعال/غیرفعال بودن سیستم Mini-Request
  bool get miniRequestEnabled =>
      _config?['miniRequestEnabled'] as bool? ?? true;

  /// آیا در هنگام باز شدن برنامه Mini-Request اجرا شود؟
  bool get miniRequestOnLaunch =>
      _config?['miniRequestOnLaunch'] as bool? ?? true;

  /// دریافت تنظیمات کامل
  Map<String, dynamic>? get config => _config;

  /// به‌روزرسانی تنظیمات
  void updateConfig(String key, dynamic value) {
    if (_config != null) {
      _config![key] = value;
      Logger.info('📋 ConfigService: Updated $key to $value');
    }
  }

  /// بارگذاری مجدد تنظیمات از فایل config.json
  Future<void> reloadConfig() async {
    await loadConfig();
    Logger.info('🔄 ConfigService: Config reloaded');
  }

  /// دریافت مقدار تنظیمات
  T? getValue<T>(String key) {
    return _config?[key] as T?;
  }
}
