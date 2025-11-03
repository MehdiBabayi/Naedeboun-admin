import 'package:hive_flutter/hive_flutter.dart';
import '../../models/content/book_cover.dart';
import '../../utils/logger.dart';

class BookCoverHiveService {
  // Singleton pattern
  static final BookCoverHiveService _instance =
      BookCoverHiveService._internal();
  static BookCoverHiveService get instance => _instance;
  BookCoverHiveService._internal();

  static const String _boxName = 'book_covers_cache';
  Box? _box;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    _box = await Hive.openBox(_boxName);
    _isInitialized = true;
    Logger.info('📦 [BOOK-COVER-HIVE] Initialized');
  }

  void saveBookCovers(int gradeId, List<BookCover> covers) {
    final key = 'grade_$gradeId';
    final data = {
      'covers': covers.map((c) => c.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _box?.put(key, data);
    Logger.info(
      '💾 [BOOK-COVER-HIVE] Saved ${covers.length} covers for grade $gradeId',
    );
  }

  List<BookCover> getBookCovers(int gradeId) {
    final key = 'grade_$gradeId';
    final cached = _box?.get(key) as Map?;

    if (cached == null) {
      Logger.info('📦 [BOOK-COVER-HIVE] No cache for grade $gradeId');
      return [];
    }

    // Check expiry (24 hours)
    final timestamp = cached['timestamp'] as int;
    final hoursSinceCache =
        (DateTime.now().millisecondsSinceEpoch - timestamp) / (1000 * 60 * 60);

    if (hoursSinceCache > 24) {
      Logger.info('⏰ [BOOK-COVER-HIVE] Cache expired for grade $gradeId');
      _box?.delete(key);
      return [];
    }

    final coversData = cached['covers'] as List;
    final covers = coversData
        .map((json) => BookCover.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    Logger.info(
      '📦 [BOOK-COVER-HIVE] Loaded ${covers.length} covers from cache for grade $gradeId',
    );
    return covers;
  }

  void clearCache() {
    _box?.clear();
    Logger.info('🗑️ [BOOK-COVER-HIVE] Cache cleared');
  }

  void clearCacheForGrade(int gradeId) {
    final key = 'grade_$gradeId';
    _box?.delete(key);
    Logger.info('🗑️ [BOOK-COVER-HIVE] Cache cleared for grade $gradeId');
  }
}
