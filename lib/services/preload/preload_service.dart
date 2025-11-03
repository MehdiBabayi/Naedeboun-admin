import '../content/cached_content_service.dart';
import '../image_cache/smart_image_cache_service.dart';
import '../../utils/logger.dart';

/// 🚀 سرویس Preloading برای بهبود سرعت Navigation
class PreloadService {
  static final PreloadService _instance = PreloadService._internal();
  factory PreloadService() => _instance;
  PreloadService._internal();

  static PreloadService get instance => _instance;

  final Set<String> _preloadedSubjects = {};
  final Set<int> _preloadedBanners = {};

  /// Preload subjects برای grade مشخص
  Future<void> preloadSubjectsForGrade({
    required int gradeId,
    int? trackId,
  }) async {
    try {
      Logger.info('🚀 [PRELOAD] Preloading subjects for grade: $gradeId');

      // Preload subjects
      final subjects = await CachedContentService.getSubjectsForUser(
        gradeId: gradeId,
        trackId: trackId,
      );

      // Preload book covers
      for (final subject in subjects) {
        if (subject.bookCoverPath.isNotEmpty) {
          _preloadedSubjects.add(subject.bookCoverPath);
          SmartImageCacheService.instance.getBookCoverFromUrl(
            subject.bookCoverPath,
          );
        }
      }

      Logger.info('✅ [PRELOAD] Preloaded ${subjects.length} subjects');
    } catch (e) {
      Logger.error('❌ [PRELOAD] Error preloading subjects', e);
    }
  }

  /// Preload banners برای grade مشخص
  Future<void> preloadBannersForGrade({
    required int gradeId,
    int? trackId,
  }) async {
    try {
      Logger.info('🚀 [PRELOAD] Preloading banners for grade: $gradeId');

      // Preload banners
      final banners = await CachedContentService.getActiveBannersForGrade(
        gradeId: gradeId,
        trackId: trackId,
      );

      // Preload banner images
      for (final banner in banners) {
        _preloadedBanners.add(banner.id);
        SmartImageCacheService.instance.getBanner(banner.id, banner.imageUrl);
      }

      Logger.info('✅ [PRELOAD] Preloaded ${banners.length} banners');
    } catch (e) {
      Logger.error('❌ [PRELOAD] Error preloading banners', e);
    }
  }

  /// Preload content برای navigation بعدی
  Future<void> preloadForNextNavigation({
    required int currentGradeId,
    int? currentTrackId,
  }) async {
    // Preload subjects and banners for current grade
    await preloadSubjectsForGrade(
      gradeId: currentGradeId,
      trackId: currentTrackId,
    );

    await preloadBannersForGrade(
      gradeId: currentGradeId,
      trackId: currentTrackId,
    );
  }

  /// چک کردن اینکه آیا content قبلاً preload شده یا نه
  bool isSubjectPreloaded(String bookCoverPath) {
    return _preloadedSubjects.contains(bookCoverPath);
  }

  bool isBannerPreloaded(int bannerId) {
    return _preloadedBanners.contains(bannerId);
  }

  /// پاک کردن preload cache
  void clearPreloadCache() {
    _preloadedSubjects.clear();
    _preloadedBanners.clear();
    Logger.info('🧹 [PRELOAD] Preload cache cleared');
  }
}
