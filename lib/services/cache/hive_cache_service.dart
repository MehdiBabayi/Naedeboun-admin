import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../utils/logger.dart';

/// مدیریت Cache با Hive برای ذخیره دائمی داده‌ها
class HiveCacheService {
  static const String _cacheBoxName = 'app_cache';
  static Box? _cacheBox;

  /// مقدار زمان‌های مختلف برای expire شدن cache
  static const Duration subjectsCacheTime = Duration(hours: 24);
  static const Duration chaptersCacheTime = Duration(hours: 6);
  static const Duration videosCacheTime = Duration(hours: 2);
  static const Duration bannersCacheTime = Duration(minutes: 30);
  static const Duration pdfsCacheTime = Duration(hours: 12);

  /// مقداردهی اولیه
  static Future<void> init() async {
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      _cacheBox = await Hive.openBox(_cacheBoxName);
      Logger.info('🔒 [HIVE CACHE] Initialized cache box: $_cacheBoxName');
    }
  }

  /// دریافت داده از Hive Cache یا null اگر موجود نیست
  static T? getCacheData<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final cachedData = _cacheBox?.get(key);
      if (cachedData == null) {
        Logger.info('🗓️ [HIVE CACHE] No cache found for key: $key');
        return null;
      }

      final data = jsonDecode(cachedData);
      return fromJson(data);
    } catch (e) {
      Logger.error('❌ [HIVE CACHE] Error reading cache for $key', e);
      return null;
    }
  }

  /// بررسی اینکه آیا cache معتبر است یا خیر
  static bool isCacheValid(String key, Duration maxAge) {
    try {
      final metadataKey = '${key}_metadata';
      final metadataStr = _cacheBox?.get(metadataKey);
      if (metadataStr == null) return false;

      final metadata = jsonDecode(metadataStr);
      final createdAt = DateTime.parse(metadata['created_at']);
      final isExpired = DateTime.now().difference(createdAt) > maxAge;

      Logger.info(
        isExpired
            ? '⏰ [HIVE CACHE] Cache expired for $key'
            : '✅ [HIVE CACHE] Cache valid for $key',
      );

      return !isExpired;
    } catch (e) {
      Logger.error('❌ [HIVE CACHE] Error checking cache validity for $key', e);
      return false;
    }
  }

  /// ذخیره داده در Hive Cache
  static Future<void> setCacheData<T>(
    String key,
    T data,
    Duration maxAge,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final dataJson = jsonEncode(toJson(data));
      final metadata = jsonEncode({
        'created_at': DateTime.now().toIso8601String(),
        'expires_in_minutes': maxAge.inMinutes,
        'data_type': T.toString(),
      });

      await _cacheBox?.put(key, dataJson);
      await _cacheBox?.put('${key}_metadata', metadata);

      Logger.info('💾 [HIVE CACHE] Cached $key (TTL: ${maxAge.inMinutes}m)');
    } catch (e) {
      Logger.error('❌ [HIVE CACHE] Error saving cache for $key', e);
    }
  }

  /// دریافت یا ایجاد cache - استراتژی اصلی
  static Future<T> getOrCreateCache<T>(
    String key,
    Future<T> Function() fetchFunction,
    Duration maxAge,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    await init();

    // چک کن که آیا cache معتبر است یا خیر
    if (isCacheValid(key, maxAge)) {
      final cachedData = getCacheData(key, fromJson);
      if (cachedData != null) {
        Logger.info('🚀 [HIVE CACHE] Fast Hive Hit: $key');
        return cachedData;
      }
    }

    // اگر cache موجود نیست یا منقضی شده، از سرور بگیر
    Logger.info('🌐 [HIVE CACHE] Cache miss, fetching from server: $key');
    final data = await fetchFunction();

    // ذخیره در Hive Cache
    await setCacheData(key, data, maxAge, toJson);

    return data;
  }

  /// پاک کردن cache خاص
  static Future<void> clearCache(String key) async {
    try {
      await _cacheBox?.delete(key);
      await _cacheBox?.delete('${key}_metadata');
      Logger.info('🗑️ [HIVE CACHE] Cleared cache: $key');
    } catch (e) {
      Logger.error('❌ [HIVE CACHE] Error clearing cache $key', e);
    }
  }

  /// پاک کردن همه cache ها
  static Future<void> clearAllCache() async {
    try {
      await _cacheBox?.clear();
      Logger.info('🔥 [HIVE CACHE] All cache cleared');
    } catch (e) {
      Logger.error('❌ [HIVE CACHE] Error clearing all cache', e);
    }
  }

  /// آمار cache
  static Map<String, dynamic> getCacheStats() {
    final keys =
        _cacheBox?.keys
            .where((k) => !k.toString().endsWith('_metadata'))
            .toList() ??
        [];
    final totalSize = keys.length;

    final stats = <String, dynamic>{
      'total_cached_items': totalSize,
      'cache_amount': '$totalSize آیتم کش شده',
      'keys': keys,
    };

    Logger.info('📊 [HIVE CACHE] Stats: $totalSize items cached');
    return stats;
  }

  /// پیدا کردن cache های منقضی و پاک کردنشان
  static Future<void> cleanupExpiredCache() async {
    try {
      final keys = _cacheBox?.keys.toList() ?? [];
      final expiredKeys = <String>[];

      for (final key in keys) {
        if (key.toString().endsWith('_metadata')) continue;

        final metadataKey = '${key}_metadata';
        final metadataStr = _cacheBox?.get(metadataKey);
        if (metadataStr == null) continue;

        final metadata = jsonDecode(metadataStr);
        final createdAt = DateTime.parse(metadata['created_at']);
        final expiresInMinutes = metadata['expires_in_minutes'] as int;
        final expireTime = createdAt.add(Duration(minutes: expiresInMinutes));

        if (DateTime.now().isAfter(expireTime)) {
          expiredKeys.add(key.toString());
        }
      }

      for (final key in expiredKeys) {
        await _cacheBox?.delete(key);
        await _cacheBox?.delete('${key}_metadata');
      }

      if (expiredKeys.isNotEmpty) {
        Logger.info('🧹 [HIVE CACHE] Cleaned up ${expiredKeys.length} expired items');
      }
    } catch (e) {
      Logger.error('❌ [HIVE CACHE] Error in cleanup', e);
    }
  }
}

/// کلاس کمکی برای cache entries با metadata
class CacheEntry {
  final dynamic data;
  final DateTime createdAt;
  final Duration maxAge;

  CacheEntry(this.data, this.createdAt, this.maxAge);

  bool get isExpired => DateTime.now().difference(createdAt) > maxAge;

  String get ageString {
    final age = DateTime.now().difference(createdAt);
    if (age.inDays > 0) return '${age.inDays} روز';
    if (age.inHours > 0) return '${age.inHours} ساعت';
    if (age.inMinutes > 0) return '${age.inMinutes} دقیقه';
    return 'حالا';
  }
}
