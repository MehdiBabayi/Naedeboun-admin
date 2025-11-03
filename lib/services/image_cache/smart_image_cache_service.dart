import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../mini_request/mini_request_service.dart';
import '../../models/content/banner.dart';
import '../../models/content/subject.dart';
import '../../utils/logger.dart';
// import '../../models/content/book_cover.dart';

/// 📸 سرویس کش هوشمند برای تصاویر (Book Covers & Banners)
/// Philosophy: Keep It Simple & Stupid (KISS)
class SmartImageCacheService {
  static final SmartImageCacheService _instance =
      SmartImageCacheService._internal();
  static SmartImageCacheService get instance => _instance;
  SmartImageCacheService._internal();

  static const String _boxName = 'image_cache';
  Box? _box;
  final Map<String, bool> _downloading = {}; // Track active downloads

  /// مقداردهی اولیه
  Future<void> init() async {
    try {
      Logger.info('📸 [IMG-CACHE] Initializing...');
      _box = await Hive.openBox(_boxName);

      // Listen to Mini-Request banner events
      MiniRequestService.instance.onNewBanners.listen(
        _onNewBanners,
        onError: (e) => Logger.error('❌ [IMG-CACHE] Event error', e),
      );

      Logger.info('🔧 [IMG-CACHE] Initialized');
    } catch (e) {
      Logger.error('❌ [IMG-CACHE] Initialization failed', e);
      rethrow;
    }
  }

  // ========== BOOK COVERS ==========

  /// دریافت عکس Book Cover از URL
  Future<Uint8List?> getBookCoverFromUrl(String imageUrl) async {
    final key = _bookCoverKeyFromUrl(imageUrl);

    // 1. چک Hive
    final cached = _box?.get(key) as Uint8List?;
    if (cached != null) {
      Logger.info('🔧 [IMG-CACHE] Book cover hit: ${key.hashCode}');
      return cached;
    }

    Logger.info('⚠️ [IMG-CACHE] Book cover miss: ${key.hashCode}');

    // 2. دانلود در پس‌زمینه
    _downloadBookCoverFromUrl(imageUrl, key);

    return null; // Widget باید placeholder نشون بده
  }

  /// نگاه همزمان به Hive: اگر بایت‌ها وجود داشته باشند بدون تاخیر برگردان
  Uint8List? peekBookCoverFromUrl(String imageUrl) {
    final key = _bookCoverKeyFromUrl(imageUrl);
    final cached = _box?.get(key) as Uint8List?;
    if (cached != null) {
      Logger.info('🔎 [IMG-CACHE] Peek hit: ${key.hashCode}');
    }
    return cached;
  }

  /// دانلود Book Cover از URL
  Future<void> _downloadBookCoverFromUrl(String imageUrl, String key) async {
    // Prevent duplicate downloads
    if (_downloading[key] == true) {
      Logger.info('⏳ [IMG-CACHE] Already downloading: ${key.hashCode}');
      return;
    }

    _downloading[key] = true;

    try {
      Logger.info('⬇️ [IMG-CACHE] Downloading book cover from: $imageUrl');

      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await _box?.put(key, response.bodyBytes);
        Logger.info(
          '🔧 [IMG-CACHE] Book cover cached: ${key.hashCode} (${response.bodyBytes.length} bytes)',
        );
      } else {
        Logger.info(
          '❌ [IMG-CACHE] Book cover download failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      Logger.error('❌ [IMG-CACHE] Book cover error', e);
    } finally {
      _downloading.remove(key);
    }
  }

  /// Legacy method - برای سازگاری با کد قدیمی
  Future<Uint8List?> getBookCover({
    required String subjectSlug,
    required int gradeId,
    int? trackId,
  }) async {
    // این متد دیگر استفاده نمی‌شود، از getBookCoverFromUrl استفاده کن
    Logger.info(
      '⚠️ [IMG-CACHE] Legacy getBookCover called - use getBookCoverFromUrl instead',
    );
    return null;
  }

  String _bookCoverKeyFromUrl(String imageUrl) {
    return 'book_covers/url_${imageUrl.hashCode}';
  }

  /// پیش‌دریافت Book Cover ها بر اساس لیست دروس (منتظر می‌ماند تا دانلود کامل شود)
  Future<void> prefetchBookCovers(List<Subject> subjects) async {
    Logger.info(
      '🚀 [IMG-CACHE] Prefetching book covers: ${subjects.length} subjects',
    );
    final futures = <Future<void>>[];
    
    for (final subject in subjects) {
      final url = subject.bookCoverPath;
      if (url.isEmpty) continue;

      final key = _bookCoverKeyFromUrl(url);
      final cached = _box?.get(key) as Uint8List?;
      
      if (cached != null) {
        Logger.info('✅ [IMG-CACHE] Book cover already cached: ${key.hashCode}');
      } else {
        // دانلود و منتظر ماندن تا کامل شود
        futures.add(_downloadBookCoverFromUrl(url, key));
      }
    }
    
    // دانلود همزمان همه (بدون delay برای سرعت بیشتر)
    await Future.wait(futures);
    Logger.info('✅ [IMG-CACHE] Prefetch completed: ${futures.length} downloads');
  }

  /// پس از prefetch، بلافاصله تصاویر را به memory cache فلاتر precache کن
  Future<void> precacheBookCovers(
    BuildContext context,
    List<Subject> subjects,
  ) async {
    try {
      final futures = <Future<void>>[];
      for (final subject in subjects) {
        final url = subject.bookCoverPath;
        if (url.isEmpty) continue;
        final key = _bookCoverKeyFromUrl(url);
        final bytes = _box?.get(key) as Uint8List?;
        if (bytes == null) continue; // فقط آن‌هایی که در Hive هستند
        final provider = MemoryImage(bytes);
        futures.add(precacheImage(provider, context));
      }
      await Future.wait(futures);
      Logger.info('✅ [IMG-CACHE] Precached ${futures.length} book covers to memory');
    } catch (e) {
      Logger.error('❌ [IMG-CACHE] Precache error', e);
    }
  }

  /// پیش‌دریافت Book Cover از URL (منتظر می‌ماند تا دانلود کامل شود)
  Future<Uint8List?> prefetchBookCoverFromUrl(String imageUrl) async {
    final key = _bookCoverKeyFromUrl(imageUrl);
    
    // 1. چک Hive
    final cached = _box?.get(key) as Uint8List?;
    if (cached != null) {
      Logger.info('✅ [IMG-CACHE] Book cover already cached: ${key.hashCode}');
      return cached;
    }
    
    // 2. دانلود و منتظر ماندن تا کامل شود
    await _downloadBookCoverFromUrl(imageUrl, key);
    
    // 3. بعد از دانلود، از Hive بخوان
    return _box?.get(key) as Uint8List?;
  }

  // ========== BANNERS ==========

  /// دریافت عکس Banner
  Future<Uint8List?> getBanner(int bannerId, String imageUrl) async {
    final key = 'banners/banner_$bannerId.jpg';

    // 1. چک Hive
    final cached = _box?.get(key) as Uint8List?;
    if (cached != null) {
      Logger.info('🔧 [IMG-CACHE] Banner hit: $bannerId');
      return cached;
    }

    Logger.info('⚠️ [IMG-CACHE] Banner miss: $bannerId');

    // 2. دانلود در پس‌زمینه
    _downloadBanner(bannerId, imageUrl);

    return null;
  }

  /// دانلود Banner
  Future<void> _downloadBanner(int bannerId, String imageUrl) async {
    final key = 'banners/banner_$bannerId.jpg';

    // Prevent duplicate downloads
    if (_downloading[key] == true) {
      Logger.info('⏳ [IMG-CACHE] Already downloading: $bannerId');
      return;
    }

    _downloading[key] = true;

    try {
      Logger.info('⬇️ [IMG-CACHE] Downloading banner $bannerId from: $imageUrl');

      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await _box?.put(key, response.bodyBytes);
        Logger.info(
          '🔧 [IMG-CACHE] Banner cached: $bannerId (${response.bodyBytes.length} bytes)',
        );
      } else {
        Logger.info('❌ [IMG-CACHE] Banner download failed: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('❌ [IMG-CACHE] Banner error', e);
    } finally {
      _downloading.remove(key);
    }
  }

  /// Event listener برای بنرهای جدید
  void _onNewBanners(List<AppBanner> banners) async {
    Logger.info('🎨 [IMG-CACHE] New banners event: ${banners.length}');

    for (final banner in banners) {
      final key = 'banners/banner_${banner.id}.jpg';

      // اگه کش نداریم، دانلود کن
      if (!(_box?.containsKey(key) ?? false)) {
        await _downloadBanner(banner.id, banner.imageUrl);
        // تأخیر کوچیک برای جلوگیری از فشار به سرور
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        Logger.info('✅ [IMG-CACHE] Banner already cached: ${banner.id}');
      }
    }
  }

  // ========== UTILITIES ==========

  /// حجم کش (MB)
  Future<double> getCacheSizeMB() async {
    try {
      int totalBytes = 0;
      final keys = _box?.keys ?? [];

      for (final key in keys) {
        final value = _box?.get(key);
        if (value is Uint8List) {
          totalBytes += value.length;
        }
      }

      return totalBytes / 1024 / 1024; // Convert to MB
    } catch (e) {
      Logger.error('❌ [IMG-CACHE] Error calculating size', e);
      return 0;
    }
  }

  /// پاک کردن کامل
  Future<void> clearAll() async {
    Logger.info('🗑️ [IMG-CACHE] Clearing all...');
    await _box?.clear();
    Logger.info('✅ [IMG-CACHE] Cleared');
  }

  void dispose() {
    _box?.close();
  }
}
