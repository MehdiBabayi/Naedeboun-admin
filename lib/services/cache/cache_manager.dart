import '../../utils/logger.dart';

/// مدیرییت Cache حرفه‌ای برای اپلیکیشن آموزشی
class AppCacheManager {
  // زمان‌های Cache مختلف برای هر نوع داده
  static const Duration subjectsCacheTime = Duration(
    hours: 24,
  ); // درس‌ها - تغییرات کم
  static const Duration chaptersCacheTime = Duration(
    hours: 6,
  ); // فصول - تغییرات متوسط
  static const Duration videosCacheTime = Duration(
    hours: 2,
  ); // ویدیوها - تغییرات بالا
  static const Duration bannersCacheTime = Duration(
    minutes: 30,
  ); // بنرها - تغییرات خیلی بالا
  static const Duration userCacheTime = Duration(minutes: 15); // اطلاعات کاربر

  // ذخیره Cache با تاریخ و metadata
  static final Map<String, CachedData> _cache = {};

  /// دریافت داده از Cache یا سرور
  static Future<T> getCachedData<T>(
    String key,
    Future<T> Function() fetchFunction,
    Duration cacheDuration,
  ) async {
    final cached = _cache[key];

    if (cached != null && !cached.isExpired(cacheDuration)) {
      Logger.info(
        '✅ Cache Hit: $key (Age: ${DateTime.now().difference(cached.createdAt).inMinutes}m)',
      );
      return cached.data as T;
    }

    Logger.info('🌐 Cache Miss: $key - Fetching from server...');
    final data = await fetchFunction();

    _cache[key] = CachedData(data, DateTime.now());
    Logger.info(
      '💾 Cache Updated: $key (Expires in: ${cacheDuration.inMinutes}m)',
    );

    return data;
  }

  /// چک کردن اینکه آیا داده در Cache موجود است و معتبر است
  static bool hasValidCache(String key, Duration cacheDuration) {
    final cached = _cache[key];
    return cached != null && !cached.isExpired(cacheDuration);
  }

  /// گرفتن سن Cache (چند دقیقه پیش ذخیره شده)
  static int getCacheAgeMinutes(String key) {
    final cached = _cache[key];
    if (cached == null) return -1;
    return DateTime.now().difference(cached.createdAt).inMinutes;
  }

  /// پاک کردن Cache خاص
  static void clearCache(String? key) {
    if (key != null) {
      _cache.remove(key);
      Logger.info('🗑️ Cache Cleared: $key');
    } else {
      _cache.clear();
      Logger.info('🗑️ All Cache Cleared');
    }
  }

  /// پاک کردن Cache های منقضی شده
  static void clearExpiredCache() {
    final expiredKeys = <String>[];

    _cache.forEach((key, cachedData) {
      // تعیین زمان expiration بر اساس نوع داده
      Duration maxAge;
      if (key.startsWith('subjects_')) {
        maxAge = subjectsCacheTime;
      } else if (key.startsWith('chapters_')) {
        maxAge = chaptersCacheTime;
      } else if (key.startsWith('videos_')) {
        maxAge = videosCacheTime;
      } else if (key.startsWith('banners')) {
        maxAge = bannersCacheTime;
      } else {
        maxAge = const Duration(hours: 1); // default
      }

      if (cachedData.isExpired(maxAge)) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      Logger.info('🧹 Expired Cache Cleared: ${expiredKeys.length} items');
    }
  }

  /// دریافت آمار Cache
  static Map<String, dynamic> getCacheStats() {
    return {
      'total_items': _cache.length,
      'cache_keys': _cache.keys.toList(),
      'memory_usage_estimate': '${_cache.length * 50}KB', // تخمینی
      'oldest_item_age_minutes': _getOldestCacheAge(),
    };
  }

  static int _getOldestCacheAge() {
    if (_cache.isEmpty) return 0;

    final now = DateTime.now();
    final oldest = _cache.values
        .map((cached) => now.difference(cached.createdAt).inMinutes)
        .reduce((a, b) => a > b ? a : b);

    return oldest;
  }

  /// ذخیره Cache با خاتمه خودکار (Auto TTL)
  static Future<T> getCachedDataWithAutoTTL<T>(
    String key,
    Future<T> Function() fetchFunction,
    Duration cacheDuration,
  ) async {
    // پاک کردن cache های منقضی قبل از استفاده
    clearExpiredCache();

    return await getCachedData<T>(key, fetchFunction, cacheDuration);
  }
}

/// کلاس ذخیره Cache با timestamp
class CachedData {
  final dynamic data;
  final DateTime createdAt;

  CachedData(this.data, this.createdAt);

  /// چک کردن اینکه آیا Cache منقضی شده است
  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(createdAt) > maxAge;
  }

  /// دریافت سن Cache به صورت متن انسان‌خوان
  String getAgeString() {
    final age = DateTime.now().difference(createdAt);

    if (age.inDays > 0) {
      return '${age.inDays} روز پیش';
    } else if (age.inHours > 0) {
      return '${age.inHours} ساعت پیش';
    } else if (age.inMinutes > 0) {
      return '${age.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  /// Serialization برای مستندات یا دیباگ
  Map<String, dynamic> toJson() {
    return {
      'data': data.toString(),
      'created_at': createdAt.toIso8601String(),
      'age_string': getAgeString(),
    };
  }
}
