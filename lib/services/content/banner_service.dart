import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/content/banner.dart';
import '../../utils/logger.dart';

class BannerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache для performance
  static final Map<String, List<AppBanner>> _cache = {};
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 30);

  /// دریافت بنرهای پایه با cache
  Future<List<AppBanner>> getBanners({required int gradeId, int? trackId}) async {
    final cacheKey = 'banners_${gradeId}_${trackId ?? 'all'}';
    final now = DateTime.now();

    // چک cache
    if (_cache.containsKey(cacheKey) &&
        _lastCacheTime != null &&
        now.difference(_lastCacheTime!).compareTo(_cacheTimeout) < 0) {
      Logger.info('🔧 [BANNER] Cache hit for grade: $gradeId, track: ${trackId ?? 'all'}');
      return _cache[cacheKey]!;
    }

    try {
      Logger.info('🔧 [BANNER] Loading banners for grade: $gradeId, track: ${trackId ?? 'all'}');

      var query = _supabase
          .from('banners')
          .select()
          .eq('active', true)
          .eq('grade_id', gradeId);

      if (trackId != null) {
        query = query.or('track_id.is.null,track_id.eq.$trackId');
      } else {
        query = query.isFilter('track_id', null);
      }

      final response = await query.order('display_order');

      final banners = (response as List)
          .map((json) => AppBanner.fromJson(json))
          .toList();

      // اگر برای رشته خاص بنری نبود، بنرهای عمومی همان پایه را نمایش بده
      if (banners.isEmpty && trackId != null) {
        Logger.info('🔧 [BANNER] No specific banners found, falling back to general banners for grade $gradeId');
        return getBanners(gradeId: gradeId);
      }

      // ذخیره در cache
      _cache[cacheKey] = banners;
      _lastCacheTime = now;

      Logger.info('🔧 [BANNER] Found ${banners.length} banners for grade $gradeId, track: ${trackId ?? 'all'}');
      return banners;
    } catch (e) {
      Logger.error('❌ [BANNER] Error loading banners', e);
      return [];
    }
  }

  /// دریافت ویدیو با cache
  static final Map<int, Map<String, dynamic>> _videoCache = {};

  Future<Map<String, dynamic>?> getVideoById(int videoId) async {
    // چک cache
    if (_videoCache.containsKey(videoId)) {
      Logger.info('🔧 [BANNER] Video cache hit: $videoId');
      return _videoCache[videoId];
    }

    try {
      Logger.info('🔧 [BANNER] Loading video: $videoId');

      final response = await _supabase
          .from('lesson_videos')
          .select()
          .eq('id', videoId)
          .single();

      // ذخیره در cache
      _videoCache[videoId] = response;

      return response;
    } catch (e) {
      Logger.error('❌ [BANNER] Error loading video', e);
      return null;
    }
  }

  /// پاک کردن cache
  static void clearCache() {
    _cache.clear();
    _videoCache.clear();
    _lastCacheTime = null;
    Logger.info('🔧 [BANNER] Cache cleared');
  }
}
