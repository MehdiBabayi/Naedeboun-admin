import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cache/cache_manager.dart';
import 'content_service.dart';
import 'banner_service.dart';
import '../../models/content/subject.dart';
import '../../models/content/chapter.dart';
import '../../models/content/lesson.dart';
import '../../models/content/lesson_video.dart';
import '../../models/content/banner.dart';
import '../../models/content/step_by_step_pdf.dart';
import '../../models/content/provincial_sample_pdf.dart';
import '../../utils/logger.dart';
// Mini-Request triggers are handled at higher layers; this service is Hive-only

/// خدمت کش شده برای محتوا - استفاده از Mini-Request Hive boxes
class CachedContentService {
  static final ContentService _contentService = ContentService(
    Supabase.instance.client,
  );
  static final BannerService _bannerService = BannerService();
  static final _supabase = Supabase.instance.client;

  /// دریافت نام Box برای grade مشخص (Mini-Request)
  static String _getMiniRequestBoxName(int gradeId, int? trackId) {
    return 'grade_${gradeId}_${trackId ?? "null"}_content';
  }

  /// دریافت درس‌ها از Mini-Request Hive Box
  /// استراتژی جدید: فقط از Hive (Mini-Request مدیریت می‌کند)
  static Future<List<Subject>> getSubjectsForUser({
    required int gradeId,
    int? trackId,
  }) async {
    final boxName = _getMiniRequestBoxName(gradeId, trackId);

    Logger.info('🚀 [MINI-REQUEST] Loading subjects from Hive: $boxName');

    try {
      final box = await Hive.openBox(boxName);
      final subjectsJson = box.get('subjects');

      if (subjectsJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No subjects in Hive for grade $gradeId');
        return [];
      }

      final List<dynamic> decoded = jsonDecode(subjectsJson);
      Logger.info('✅ [MINI-REQUEST] Loaded ${decoded.length} subjects from Hive');
      return decoded.map((j) => Subject.fromJson(j)).toList();
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error reading subjects from Hive', e);
      return [];
    }
  }

  /// دریافت درس‌ها بر اساس نام پایه - Deprecated: Use getSubjectsForUser instead
  static Future<List<Subject>> getSubjectsByGradeName({
    required String gradeName,
    String? trackName,
  }) async {
    // Convert gradeName to gradeId
    // این متد deprecated است، بهتر است از getSubjectsForUser استفاده شود
    Logger.info(
      '⚠️ [DEPRECATED] getSubjectsByGradeName called - use getSubjectsForUser instead',
    );

    // برای سازگاری با کد قدیمی، از ContentService استفاده می‌کنیم
    return await _contentService.getSubjectsByGradeName(
      gradeName: gradeName,
      trackName: trackName,
    );
  }

  /// دریافت فصول از Mini-Request Hive Box
  static Future<List<Chapter>> getChapters(
    int subjectOfferId, {
    required int gradeId,
    int? trackId,
  }) async {
    final boxName = _getMiniRequestBoxName(gradeId, trackId);

    Logger.info(
      '🚀 [MINI-REQUEST] Loading chapters from Hive for subject offer: $subjectOfferId',
    );

    try {
      final box = await Hive.openBox(boxName);
      final chaptersJson = box.get('chapters');

      if (chaptersJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No chapters in Hive');
        return [];
      }

      final Map<String, dynamic> allChapters = jsonDecode(chaptersJson);
      List<dynamic>? chaptersList = allChapters[subjectOfferId.toString()];

      if (chaptersList == null || chaptersList.isEmpty) return [];

      return chaptersList.map((j) => Chapter.fromJson(j)).toList();
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error reading chapters from Hive', e);
      return [];
    }
  }

  /// دریافت درس‌ها از Mini-Request Hive Box
  static Future<List<Lesson>> getLessons(
    int chapterId, {
    required int gradeId,
    int? trackId,
  }) async {
    final boxName = _getMiniRequestBoxName(gradeId, trackId);

    Logger.info(
      '🚀 [MINI-REQUEST] Loading lessons from Hive for chapter: $chapterId',
    );

    try {
      final box = await Hive.openBox(boxName);
      final lessonsJson = box.get('lessons');

      if (lessonsJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No lessons in Hive');
        return [];
      }

      final Map<String, dynamic> allLessons = jsonDecode(lessonsJson);
      List<dynamic>? lessonsList = allLessons[chapterId.toString()];

      if (lessonsList == null || lessonsList.isEmpty) return [];

      return lessonsList.map((j) => Lesson.fromJson(j)).toList();
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error reading lessons from Hive', e);
      return [];
    }
  }

  /// دریافت ویدیوهای درس از Mini-Request Hive Box
  static Future<List<LessonVideo>> getLessonVideos(
    int lessonId, {
    required int gradeId,
    int? trackId,
  }) async {
    final boxName = _getMiniRequestBoxName(gradeId, trackId);

    Logger.info('🚀 [MINI-REQUEST] Loading videos from Hive for lesson: $lessonId');

    try {
      final box = await Hive.openBox(boxName);
      final videosJson = box.get('videos');

      if (videosJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No videos in Hive');
        return [];
      }

      final Map<String, dynamic> allVideos = jsonDecode(videosJson);
      List<dynamic>? videosList = allVideos[lessonId.toString()];

      if (videosList == null || videosList.isEmpty) return [];

      return videosList.map((j) => LessonVideo.fromJson(j)).toList();
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error reading videos from Hive', e);
      return [];
    }
  }

  /// دریافت Offer ID با Cache کوتاه (30 دقیقه)
  static Future<int?> getSubjectOfferId({
    required int subjectId,
    required int gradeId,
    int? trackId,
  }) async {
    final cacheKey = 'subject_offer_${subjectId}_${gradeId}_$trackId';

    Logger.info(
      '🎯 Loading SubjectOffer ID: Subject: $subjectId, Grade: $gradeId, Track: $trackId',
    );

    return await AppCacheManager.getCachedDataWithAutoTTL(
      cacheKey,
      () => _contentService.getSubjectOfferId(
        subjectId: subjectId,
        gradeId: gradeId,
        trackId: trackId,
      ),
      const Duration(minutes: 30), // کوتاه مدت برای آیدی‌ها
    );
  }

  /// دریافت بنرهای فعال از Mini-Request Hive Box
  static Future<List<AppBanner>> getActiveBannersForGrade({
    required int gradeId,
    int? trackId,
  }) async {
    final boxName = _getMiniRequestBoxName(gradeId, trackId);

    Logger.info('🚀 [MINI-REQUEST] Loading banners from Hive: $boxName');

    try {
      final box = await Hive.openBox(boxName);
      final bannersJson = box.get('banners');

      if (bannersJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No banners in Hive');
        return [];
      }

      final List<dynamic> decoded = jsonDecode(bannersJson);
      Logger.info('✅ [MINI-REQUEST] Loaded ${decoded.length} banners from Hive');
      return decoded.map((j) => AppBanner.fromJson(j)).toList();
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error reading banners from Hive', e);
      return [];
    }
  }

  /// دریافت ویدیو بر اساس ID با Cache کوتاه
  static Future<Map<String, dynamic>?> getVideoById(int videoId) async {
    final cacheKey = 'video_id_$videoId';

    return await AppCacheManager.getCachedDataWithAutoTTL(
      cacheKey,
      () => _bannerService.getVideoById(videoId),
      const Duration(minutes: 15), // کوتاه مدت برای ID ها
    );
  }

  // ========== STEP-BY-STEP PDF METHODS ==========

  /// دریافت PDF‌های گام‌به‌گام از Mini-Request Hive Box
  static Future<List<StepByStepPdf>> getStepByStepPdfs({
    required int gradeId,
    int? trackId,
    int? subjectId,
  }) async {
    final boxName = _getMiniRequestBoxName(gradeId, trackId);

    Logger.info('🚀 [MINI-REQUEST] Loading step-by-step PDFs from Hive');
    Logger.debug('🔍 [DEBUG] Box name: $boxName');
    Logger.debug('🔍 [DEBUG] Grade ID: $gradeId, Track ID: $trackId');

    try {
      final box = await Hive.openBox(boxName);
      final pdfsJson = box.get('step_by_step_pdfs');

      if (pdfsJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No step_by_step_pdfs in Hive');
        return [];
      }

      Logger.debug(
        '✅ [DEBUG] Found step_by_step_pdfs in Hive: ${pdfsJson.length} characters',
      );

      final List<dynamic> decoded = jsonDecode(pdfsJson);
      var pdfs = decoded.map((j) => StepByStepPdf.fromJson(j)).toList();

      // Filter by subjectId if provided
      if (subjectId != null) {
        pdfs = pdfs.where((p) => p.subjectId == subjectId).toList();
      }

      return pdfs;
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error reading step-by-step PDFs from Hive', e);
      return [];
    }
  }

  /// دریافت یک PDF گام‌به‌گام خاص
  static Future<StepByStepPdf?> getStepByStepPdfById(int id) async {
    final cacheKey = 'step_by_step_pdf_$id';

    return await AppCacheManager.getCachedDataWithAutoTTL(cacheKey, () async {
      final data = await _supabase
          .from('step_by_step_pdfs')
          .select()
          .eq('id', id)
          .eq('active', true)
          .single();

      return StepByStepPdf.fromJson(data);
    }, const Duration(hours: 1));
  }

  // ========== PROVINCIAL SAMPLE PDF METHODS ==========

  /// دریافت PDF‌های نمونه سوال استانی با Cache + Hive Filters
  static Future<List<ProvincialSamplePdf>> getProvincialSamplePdfs({
    required int gradeId,
    int? trackId,
    int? subjectId,
    int? publishYear,
    bool? hasAnswerKey,
  }) async {
    final boxName = _getMiniRequestBoxName(gradeId, trackId);

    Logger.info('🚀 [MINI-REQUEST] Loading provincial PDFs from Hive');
    Logger.debug('🔍 [DEBUG] Box name: $boxName');
    Logger.debug('🔍 [DEBUG] Grade ID: $gradeId, Track ID: $trackId');

    try {
      final box = await Hive.openBox(boxName);
      final pdfsJson = box.get('provincial_sample_pdfs');

      if (pdfsJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No provincial_sample_pdfs in Hive');
        return [];
      }

      Logger.debug(
        '✅ [DEBUG] Found provincial_sample_pdfs in Hive: ${pdfsJson.length} characters',
      );

      final List<dynamic> decoded = jsonDecode(pdfsJson);
      var pdfs = decoded.map((j) => ProvincialSamplePdf.fromJson(j)).toList();

      // Apply filters
      if (subjectId != null) {
        pdfs = pdfs.where((p) => p.subjectId == subjectId).toList();
      }
      if (publishYear != null) {
        pdfs = pdfs.where((p) => p.publishYear == publishYear).toList();
      }
      if (hasAnswerKey != null) {
        pdfs = pdfs.where((p) => p.hasAnswerKey == hasAnswerKey).toList();
      }

      // Sort by last upload date descending (newest first)
      pdfs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return pdfs;
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error reading provincial PDFs from Hive', e);
      return [];
    }
  }

  /// دریافت یک PDF نمونه سوال استانی خاص
  static Future<ProvincialSamplePdf?> getProvincialSamplePdfById(int id) async {
    final cacheKey = 'provincial_sample_pdf_$id';

    return await AppCacheManager.getCachedDataWithAutoTTL(cacheKey, () async {
      final data = await _supabase
          .from('provincial_sample_pdfs')
          .select()
          .eq('id', id)
          .eq('active', true)
          .single();

      return ProvincialSamplePdf.fromJson(data);
    }, const Duration(hours: 1));
  }

  /// دریافت لیست سال‌های انتشار موجود برای فیلتر
  static Future<List<int>> getAvailablePublishYears({
    required int gradeId,
    int? subjectId,
  }) async {
    final cacheKey = 'publish_years_${gradeId}_$subjectId';

    return await AppCacheManager.getCachedDataWithAutoTTL(cacheKey, () async {
      var query = _supabase
          .from('provincial_sample_pdfs')
          .select('publish_year')
          .eq('grade_id', gradeId)
          .eq('active', true);

      if (subjectId != null) {
        query = query.eq('subject_id', subjectId);
      }

      final data = await query as List<dynamic>;
      final years = data
          .map((e) => (e as Map<String, dynamic>)['publish_year'] as int)
          .toSet()
          .toList();
      years.sort((a, b) => b.compareTo(a)); // جدیدترین اول
      return years;
    }, const Duration(hours: 6));
  }

  // ========== CACHE MANAGEMENT METHODS ==========

  /// پاک کردن همه Cache ها
  static Future<void> refreshAll() async {
    Logger.info('🔄 Refreshing all cached data...');
    AppCacheManager.clearCache(null); // پاک کردن همه
  }

  /// پاک کردن Cache درس‌ها فقط
  static Future<void> refreshSubjects() async {
    Logger.info('🔄 Refreshing subjects cache...');
    AppCacheManager.clearCache('subjects');
  }

  /// پاک کردن Cache درس‌های خاص بر اساس پایه
  static Future<void> refreshSubjectsForGrade(int gradeId, int? trackId) async {
    final cacheKey = 'subjects_${gradeId}_$trackId';
    Logger.info('🔄 Refreshing subjects cache for Grade: $gradeId, Track: $trackId');
    AppCacheManager.clearCache(cacheKey);
  }

  /// پاک کردن Cache فصول
  static Future<void> refreshChapters() async {
    Logger.info('🔄 Refreshing chapters cache...');
    AppCacheManager.clearCache('chapters');
  }

  /// پاک کردن Cache فصول خاص
  static Future<void> refreshChaptersForSubject(int subjectOfferId) async {
    final cacheKey = 'chapters_$subjectOfferId';
    Logger.info('🔄 Refreshing chapters cache for SubjectOffer: $subjectOfferId');
    AppCacheManager.clearCache(cacheKey);
  }

  /// پاک کردن Cache ویدیوها
  static Future<void> refreshVideos() async {
    Logger.info('🔄 Refreshing videos cache...');
    AppCacheManager.clearCache('videos');
  }

  /// پاک کردن Cache ویدیوهای درس خاص
  static Future<void> refreshVideosForLesson(int lessonId) async {
    final cacheKey = 'videos_$lessonId';
    Logger.info('🔄 Refreshing videos cache for Lesson: $lessonId');
    AppCacheManager.clearCache(cacheKey);
  }

  /// پاک کردن Cache بنرها
  static Future<void> refreshBanners() async {
    Logger.info('🔄 Refreshing banners cache...');
    AppCacheManager.clearCache('banners_active');
    AppCacheManager.clearCache('banners_all');
  }

  /// پاک کردن Cache بنرهای خاص برای پایه و رشته
  static Future<void> refreshBannersForGrade(int gradeId, int? trackId) async {
    final cacheKey = 'banners_active_${gradeId}_$trackId';
    Logger.info('🔄 Refreshing banners cache for Grade: $gradeId, Track: $trackId');
    AppCacheManager.clearCache(cacheKey);
  }

  /// پاک کردن Cache PDF‌های گام‌به‌گام
  static Future<void> refreshStepByStepPdfs() async {
    Logger.info('🔄 Refreshing step-by-step PDFs cache...');
    AppCacheManager.clearCache('step_by_step');
  }

  /// پاک کردن Cache PDF‌های نمونه سوال استانی
  static Future<void> refreshProvincialSamplePdfs() async {
    Logger.info('🔄 Refreshing provincial sample PDFs cache...');
    AppCacheManager.clearCache('provincial_sample');
  }

  // ========== UTILITY METHODS ==========

  /// چک کردن اینکه آیا داده در Cache موجود است
  static bool hasSubjectsCache(int gradeId, int? trackId) {
    final cacheKey = 'subjects_${gradeId}_$trackId';
    return AppCacheManager.hasValidCache(
      cacheKey,
      AppCacheManager.subjectsCacheTime,
    );
  }

  static bool hasChaptersCache(int subjectOfferId) {
    final cacheKey = 'chapters_$subjectOfferId';
    return AppCacheManager.hasValidCache(
      cacheKey,
      AppCacheManager.chaptersCacheTime,
    );
  }

  static bool hasVideosCache(int lessonId) {
    final cacheKey = 'videos_$lessonId';
    return AppCacheManager.hasValidCache(
      cacheKey,
      AppCacheManager.videosCacheTime,
    );
  }

  static bool hasBannersCache() {
    return AppCacheManager.hasValidCache(
      'banners_active',
      AppCacheManager.bannersCacheTime,
    );
  }

  /// دریافت آمار و اطلاعات Cache
  static Map<String, dynamic> getCacheInfo() {
    return AppCacheManager.getCacheStats();
  }

  /// پاک کردن Cache های منقضی شده
  static void cleanupExpiredCache() {
    AppCacheManager.clearExpiredCache();
  }

  /// دریافت سن Cache برای debugging
  static String getCacheAgeInfo(String dataType, [int? id]) {
    final cacheKey = switch (dataType) {
      'subjects' => 'subjects_${id ?? 'unknown'}_unknown',
      'chapters' => 'chapters_${id ?? 'unknown'}',
      'videos' => 'videos_${id ?? 'unknown'}',
      'banners' => 'banners_active',
      _ => 'unknown',
    };

    final ageMinutes = AppCacheManager.getCacheAgeMinutes(cacheKey);

    if (ageMinutes == -1) {
      return 'Cache موجود نیست';
    } else if (ageMinutes == 0) {
      return 'همین الان';
    } else if (ageMinutes < 60) {
      return '$ageMinutes دقیقه پیش';
    } else {
      final hours = ageMinutes ~/ 60;
      return '$hours ساعت و ${ageMinutes % 60} دقیقه پیش';
    }
  }
}
