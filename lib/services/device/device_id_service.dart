import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nardeboun/utils/logger.dart';

/// سرویس مدیریت Device ID برای مسدودسازی OTP
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService _instance = DeviceIdService._();
  static DeviceIdService get instance => _instance;

  static const String _deviceIdKey = 'device_id';
  static const String _boxName = 'device_info';
  Box? _box;
  String? _cachedDeviceId;

  /// مقداردهی اولیه
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_boxName);
      Logger.info('Device ID service initialized');
    } catch (e) {
      Logger.error('Failed to initialize Device ID service', e);
    }
  }

  /// دریافت Device ID یکتا
  /// ابتدا از Hive چک می‌کند، اگر نبود از سیستم می‌گیرد و ذخیره می‌کند
  Future<String> getDeviceId() async {
    // اگر در حافظه cache شده، برگردان
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      // ابتدا از Hive چک کن
      final savedDeviceId = _box?.get(_deviceIdKey) as String?;
      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        _cachedDeviceId = savedDeviceId;
        Logger.info(
          'Device ID retrieved from Hive: ${savedDeviceId.substring(0, 8)}...',
        );
        return savedDeviceId;
      }

      // اگر در Hive نبود، از سیستم بگیر
      final deviceInfo = DeviceInfoPlugin();
      String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        Logger.info(
          'Android Device ID obtained: ${deviceId.substring(0, 8)}...',
        );
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
        Logger.info('iOS Device ID obtained: ${deviceId.substring(0, 8)}...');
      } else {
        // برای سایر پلتفرم‌ها، یک UUID تولید کن
        deviceId = 'unknown_platform_${DateTime.now().millisecondsSinceEpoch}';
        Logger.info('⚠️ [DEVICE-ID] Unknown platform, generated fallback device ID');
      }

      // در Hive ذخیره کن
      await _box?.put(_deviceIdKey, deviceId);
      _cachedDeviceId = deviceId;

      Logger.info('Device ID saved to Hive: ${deviceId.substring(0, 8)}...');
      return deviceId;
    } catch (e) {
      Logger.error('Failed to get device ID', e);
      // در صورت خطا، یک fallback ID برگردان
      final fallbackId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      _cachedDeviceId = fallbackId;
      return fallbackId;
    }
  }

  /// پاک کردن Device ID (برای تست یا reset)
  Future<void> clearDeviceId() async {
    try {
      await _box?.delete(_deviceIdKey);
      _cachedDeviceId = null;
      Logger.info('Device ID cleared');
    } catch (e) {
      Logger.error('Failed to clear device ID', e);
    }
  }

  /// بستن سرویس
  void dispose() {
    _box?.close();
  }
}
