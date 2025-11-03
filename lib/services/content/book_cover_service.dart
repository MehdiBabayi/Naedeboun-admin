import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/content/book_cover.dart';
import '../hive/book_cover_hive_service.dart';
import '../../utils/logger.dart';

class BookCoverService {
  // Singleton pattern
  static final BookCoverService _instance = BookCoverService._internal();
  static BookCoverService get instance => _instance;
  BookCoverService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final BookCoverHiveService _hiveService = BookCoverHiveService.instance;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _hiveService.init();
    _isInitialized = true;
  }

  /// دریافت تمام book covers برای یک پایه
  Future<List<BookCover>> getBookCoversForGrade(int gradeId) async {
    Logger.info('🔍 [BOOK-COVER] Getting covers for grade: $gradeId');

    // 1. Check Hive cache
    final cachedCovers = _hiveService.getBookCovers(gradeId);
    if (cachedCovers.isNotEmpty) {
      Logger.info('✅ [BOOK-COVER] Loaded ${cachedCovers.length} covers from Hive');
      return cachedCovers;
    }

    // 2. Fetch from server
    try {
      Logger.info('🌐 [BOOK-COVER] Fetching from server for grade: $gradeId');

      final response = await _supabase
          .from('book_covers')
          .select('*')
          .eq('grade', gradeId)
          .order('subject_name');

      Logger.info('🔍 [BOOK-COVER] Raw response: ${response.length} items');
      if (response.isNotEmpty) {
        Logger.info('🔍 [BOOK-COVER] First item: ${response.first}');
        Logger.info(
          '🔍 [BOOK-COVER] Has track_name: ${response.first.containsKey('track_name')}',
        );
      }

      final bookCovers = (response as List)
          .map((json) => BookCover.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      Logger.info('✅ [BOOK-COVER] Fetched ${bookCovers.length} covers from server');

      // 3. Save to Hive
      _hiveService.saveBookCovers(gradeId, bookCovers);

      return bookCovers;
    } catch (e) {
      Logger.error('❌ [BOOK-COVER] Error fetching', e);
      return [];
    }
  }

  /// دریافت مسیر عکس کتاب با الگوریتم ساده
  Future<String?> getBookCoverPath({
    required String subjectName,
    required int grade,
    String? trackName,
  }) async {
    Logger.info('🔍 [BOOK-COVER] Getting path:');
    Logger.info('   - subject: $subjectName');
    Logger.info('   - grade: $grade');
    Logger.info('   - track: $trackName');

    final bookCovers = await getBookCoversForGrade(grade);

    if (bookCovers.isEmpty) {
      Logger.info('⚠️ [BOOK-COVER] No covers available for grade $grade');
      return null;
    }

    BookCover? cover;

    if (grade <= 9) {
      // ابتدایی (1-6) و متوسطه اول (7-9): track_name باید NULL باشد
      cover = bookCovers.where((bc) {
        return bc.subjectName == subjectName && bc.trackName == null;
      }).firstOrNull;

      Logger.info(
        '🔍 [BOOK-COVER] Elementary/First-Average search result: ${cover?.subjectPath ?? "NOT FOUND"}',
      );
    } else {
      // متوسطه دوم (10-12): باید track_name مطابقت داشته باشد
      if (trackName != null) {
        cover = bookCovers.where((bc) {
          return bc.subjectName == subjectName && bc.trackName == trackName;
        }).firstOrNull;

        Logger.info(
          '🔍 [BOOK-COVER] Secondary search result: ${cover?.subjectPath ?? "NOT FOUND"}',
        );
      }

      // اگر پیدا نشد یا trackName null بود، سعی کن بدون track پیدا کن
      if (cover == null) {
        cover = bookCovers.where((bc) {
          return bc.subjectName == subjectName && bc.trackName == null;
        }).firstOrNull;
        Logger.info(
          '🔍 [BOOK-COVER] Fallback search result: ${cover?.subjectPath ?? "NOT FOUND"}',
        );
      }
    }

    if (cover != null) {
      Logger.info('✅ [BOOK-COVER] Found: ${cover.subjectPath}');
      return cover.subjectPath;
    } else {
      Logger.info('❌ [BOOK-COVER] Not found for $subjectName');
      return null;
    }
  }

  /// Clear cache
  void clearCache() {
    _hiveService.clearCache();
  }

  void clearCacheForGrade(int gradeId) {
    _hiveService.clearCacheForGrade(gradeId);
  }
}
