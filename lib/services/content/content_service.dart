import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nardeboun/models/content/subject.dart';
import 'package:nardeboun/models/content/chapter.dart';
import 'package:nardeboun/models/content/lesson_video.dart';
import 'package:nardeboun/utils/grade_utils.dart';
import '../../utils/logger.dart';

class ContentService {
  final SupabaseClient supabase;

  ContentService(this.supabase);

  /// دریافت مسیر فایل JSON از grades.json بر اساس grade_id
  Future<String?> getJsonPathForGrade(int gradeId) async {
    try {
      final gradesJsonStr = await rootBundle.loadString('assets/data/grades.json');
      final gradesJson = json.decode(gradesJsonStr) as Map<String, dynamic>;
      final gradeData = gradesJson[gradeId.toString()] as Map<String, dynamic>?;
      if (gradeData != null) {
        return gradeData['path'] as String?;
      }
      return null;
    } catch (e) {
      Logger.error('❌ [CONTENT] Error loading grades.json', e);
      // Fallback: اگر grades.json پیدا نشد، مستقیماً از الگوی استاندارد استفاده کن
      if (gradeId <= 9) {
        return 'assets/data/videos/grade$gradeId.json';
      }
      // برای پایه‌های 10-21، باید track را هم در نظر بگیریم (فعلاً null می‌گذاریم)
      return null;
    }
  }

  /// خواندن ساختار کامل JSON برای یک پایه
  Future<Map<String, dynamic>?> loadGradeJson(int gradeId) async {
    try {
      final jsonPath = await getJsonPathForGrade(gradeId);
      if (jsonPath == null) {
        Logger.info('⚠️ [CONTENT] No JSON path found for gradeId=$gradeId');
        return null;
      }

      Logger.info('📄 [CONTENT] Loading JSON from $jsonPath for gradeId=$gradeId');
      final jsonStr = await rootBundle.loadString(jsonPath);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      Logger.error('❌ [CONTENT] Error loading JSON for gradeId=$gradeId', e);
      return null;
    }
  }

  /// استخراج bookId (slug) از JSON بر اساس subject title
  /// خروجی: map ای از عنوان درس به bookId
  Future<Map<String, String>> getBookIdMapForGrade(int gradeId) async {
    final Map<String, String> bookIdMap = {};
    final gradeJson = await loadGradeJson(gradeId);
    if (gradeJson == null) return bookIdMap;

    final books = gradeJson['books'] as Map<String, dynamic>? ?? {};
    for (final bookEntry in books.values) {
      final bookMap = bookEntry as Map<String, dynamic>;
      for (final entry in bookMap.entries) {
        final bookSlug = entry.key; // مثل "riazi", "olom"
        final subjectMap = entry.value as Map<String, dynamic>;
        final String? title = subjectMap['title'] as String?;
        if (title != null && title.trim().isNotEmpty) {
          bookIdMap[title.trim()] = bookSlug;
        }
      }
    }

    Logger.info('✅ [CONTENT] Built bookId map: ${bookIdMap.length} subjects');
    return bookIdMap;
  }

  /// دریافت اطلاعات کتاب از JSON (فصل‌ها و chapter_type)
  Future<BookJsonData?> getBookDataFromJson({
    required int gradeId,
    required String bookId,
  }) async {
    final Map<String, String> chapters = {};
    String chapterType = 'فصل';
    final gradeJson = await loadGradeJson(gradeId);
    if (gradeJson == null) return null;

    final books = gradeJson['books'] as Map<String, dynamic>? ?? {};
    for (final bookEntry in books.entries) {
      final bookIndex = bookEntry.key; // مثل "1", "2"
      final bookMap = bookEntry.value as Map<String, dynamic>;

      for (final subjectEntry in bookMap.entries) {
        final subjectSlug = subjectEntry.key;
        final subjectMap = subjectEntry.value as Map<String, dynamic>;

        if (subjectSlug == bookId || bookIndex == bookId) {
          chapterType = (subjectMap['chapter_type'] as String? ?? 'فصل').trim();

          final chaptersMap = subjectMap['chapters'] as Map<String, dynamic>? ?? {};
          for (final entry in chaptersMap.entries) {
            final chapterId = entry.key; // مثل "1", "2"
            final chapterData = entry.value as Map<String, dynamic>;
            final String? title = chapterData['title'] as String?;
            if (title != null && title.trim().isNotEmpty) {
              chapters[chapterId] = title.trim();
            }
          }

          Logger.info(
            '✅ [CONTENT] Found ${chapters.length} chapters for bookId=$bookId (chapter_type=$chapterType)',
          );
          return BookJsonData(
            chapters: chapters,
            chapterType: chapterType,
          );
        }
      }
    }

    Logger.info('⚠️ [CONTENT] No chapters found for bookId=$bookId in gradeId=$gradeId');
    return BookJsonData(chapters: chapters, chapterType: chapterType);
  }

  Future<List<Subject>> getSubjectsForUser({
    required int gradeId,
    int? trackId,
  }) async {
    // ✅ استراتژی جدید: مستقیماً از JSON استفاده می‌کنیم (بدون نیاز به book_covers از Supabase)
    // آدرس بوک کاورها در JSON است: "cover": "assets/images/book-covers/grade7/riazi.png"
    try {
      Logger.info(
          '📚 [CONTENT] Loading subjects for gradeId=$gradeId (trackId=$trackId) from JSON + lesson_videos');

      // مستقیماً از JSON + lesson_videos استفاده می‌کنیم
      return await _buildSubjectsFromJsonAndLessons(gradeId);
    } catch (e) {
      Logger.error('❌ [CONTENT] Error building subjects for user', e);
      return [];
    }
  }

  Future<List<Subject>> getSubjectsByGradeName({
    required String gradeName,
    String? trackName,
  }) async {
    Logger.debug('🔍 [DEBUG] Searching for grade: "$gradeName"');

    // لیست تمام نام‌های ممکن برای جستجو
    final List<String> possibleNames = [
      gradeName, // نام اصلی
    ];

    // اگر نام فارسی است، عدد معادل را هم اضافه کن
    final gradeInt = mapGradeStringToInt(gradeName);
    if (gradeInt != null) {
      possibleNames.add(gradeInt.toString());
    }

    // اگر عدد است، نام فارسی معادل را هم اضافه کن
    if (int.tryParse(gradeName) != null) {
      final persianName = mapGradeIntToString(int.parse(gradeName));
      if (persianName != null) {
        possibleNames.add(persianName);
      }
    }

    // با هر نام ممکن جستجو کن
    var grades = <dynamic>[];
    for (String name in possibleNames) {
      grades =
          await supabase.from('grades').select('id').eq('name', name)
              as List<dynamic>;

      if (grades.isNotEmpty) {
        Logger.debug('✅ [DEBUG] Found grade "$gradeName" as "$name"');
        break;
      }
    }

    if (grades.isEmpty) {
      Logger.info('❌ [DEBUG] No grade found for "$gradeName"');
      return [];
    }

    final int gradeId = (grades.first as Map<String, dynamic>)['id'] as int;

    int? trackId;
    if (trackName != null && trackName.trim().isNotEmpty) {
      final tracks =
          await supabase.from('tracks').select('id').eq('name', trackName)
              as List<dynamic>;
      if (tracks.isNotEmpty) {
        trackId = (tracks.first as Map<String, dynamic>)['id'] as int;
      }
    }

    return getSubjectsForUser(gradeId: gradeId, trackId: trackId);
  }

  Future<List<Chapter>> getChapters(int subjectOfferId) async {
    final data =
        await supabase
                .from('chapters')
                .select()
                .eq('subject_offer_id', subjectOfferId)
                .order('chapter_order', ascending: true)
            as List<dynamic>;
    return data
        .map((j) => Chapter.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<int?> getSubjectOfferId({
    required int subjectId,
    required int gradeId,
    int? trackId,
  }) async {
    Logger.debug('🔍 getSubjectOfferId called with:');
    Logger.debug('   - subjectId: $subjectId');
    Logger.debug('   - gradeId: $gradeId');
    Logger.debug('   - trackId: $trackId');

    PostgrestFilterBuilder query = supabase
        .from('subject_offers')
        .select()
        .filter('subject_id', 'eq', subjectId)
        .filter('grade_id', 'eq', gradeId);

    if (trackId == null) {
      query = query.filter('track_id', 'is', 'null');
    } else {
      query = query.filter('track_id', 'eq', trackId);
    }

    final rows = await query as List<dynamic>;
    Logger.debug('📊 Subject offers found: ${rows.length}');
    if (rows.isNotEmpty) {
      Logger.debug('📋 First offer: ${rows.first}');
    }

    if (rows.isEmpty) return null;
    return (rows.first as Map<String, dynamic>)['id'] as int;
  }

  /// دریافت ویدیوها بر اساس chapter_id (String) از lesson_videos
  Future<List<LessonVideo>> getLessonVideosByChapterId(String chapterId) async {
    final List<dynamic> data = await supabase
        .from('lesson_videos')
        .select()
        .eq('chapter_id', chapterId)  // chapter_id در تیبل از نوع text است
        .eq('active', true)
        .order('step_number', ascending: true);
    
    return data.map((j) => LessonVideo.fromJson(j)).toList();
  }

  /// دریافت ویدیوها بر اساس grade_id و book_id
  /// bookId می‌تواند slug (مثل "olom") یا index (مثل "2") باشد
  Future<List<LessonVideo>> getLessonVideosByBook({
    required int gradeId,
    required String bookId,
  }) async {
    // ابتدا با bookId اصلی جستجو کن
    List<dynamic> data = await supabase
        .from('lesson_videos')
        .select()
        .eq('grade_id', gradeId)
        .eq('book_id', bookId)
        .eq('active', true)
        .order('chapter_id', ascending: true)
        .order('step_number', ascending: true) as List<dynamic>;
    
    // اگر نتیجه‌ای پیدا نشد و bookId یک slug است، سعی کن index معادل را پیدا کنی
    if (data.isEmpty) {
      final gradeJson = await loadGradeJson(gradeId);
      if (gradeJson != null) {
        final books = gradeJson['books'] as Map<String, dynamic>? ?? {};
        for (final entry in books.entries) {
          final bookIndex = entry.key; // مثل "1", "2"
          final bookMap = entry.value as Map<String, dynamic>;
          if (bookMap.containsKey(bookId)) {
            // bookId یک slug است و bookIndex معادل آن را پیدا کردیم
            Logger.info('🔄 [CONTENT] bookId "$bookId" not found, trying index "$bookIndex"');
            data = await supabase
                .from('lesson_videos')
                .select()
                .eq('grade_id', gradeId)
                .eq('book_id', bookIndex)
                .eq('active', true)
                .order('chapter_id', ascending: true)
                .order('step_number', ascending: true) as List<dynamic>;
            break;
          }
        }
      }
    }
    
    Logger.info('📹 [CONTENT] Found ${data.length} videos for gradeId=$gradeId, bookId=$bookId');
    return data.map((j) => LessonVideo.fromJson(j)).toList();
  }

  /// دریافت ویدیوها بر اساس grade_id, book_id و chapter_id
  /// bookId می‌تواند slug (مثل "olom") یا index (مثل "2") باشد
  Future<List<LessonVideo>> getLessonVideosByChapter({
    required int gradeId,
    required String bookId,
    required String chapterId,
  }) async {
    // ابتدا با bookId اصلی جستجو کن
    List<dynamic> data = await supabase
        .from('lesson_videos')
        .select()
        .eq('grade_id', gradeId)
        .eq('book_id', bookId)
        .eq('chapter_id', chapterId)
        .eq('active', true)
        .order('step_number', ascending: true) as List<dynamic>;
    
    // اگر نتیجه‌ای پیدا نشد و bookId یک slug است، سعی کن index معادل را پیدا کنی
    if (data.isEmpty) {
      final gradeJson = await loadGradeJson(gradeId);
      if (gradeJson != null) {
        final books = gradeJson['books'] as Map<String, dynamic>? ?? {};
        for (final entry in books.entries) {
          final bookIndex = entry.key; // مثل "1", "2"
          final bookMap = entry.value as Map<String, dynamic>;
          if (bookMap.containsKey(bookId)) {
            // bookId یک slug است و bookIndex معادل آن را پیدا کردیم
            Logger.info('🔄 [CONTENT] bookId "$bookId" not found for chapter $chapterId, trying index "$bookIndex"');
            data = await supabase
                .from('lesson_videos')
                .select()
                .eq('grade_id', gradeId)
                .eq('book_id', bookIndex)
                .eq('chapter_id', chapterId)
                .eq('active', true)
                .order('step_number', ascending: true) as List<dynamic>;
            break;
          }
        }
      }
    }
    
    Logger.info('📹 [CONTENT] Found ${data.length} videos for gradeId=$gradeId, bookId=$bookId, chapterId=$chapterId');
    return data.map((j) => LessonVideo.fromJson(j)).toList();
  }

  /// متد قدیمی برای سازگاری (استفاده از chapter.id که int است)
  /// ⚠️ این متد دیگر استفاده نمی‌شود و باید از getLessonVideosByChapterId استفاده شود
  @Deprecated('Use getLessonVideosByChapterId instead')
  Future<List<LessonVideo>> getLessonVideos(int chapterId) async {
    // تبدیل int به String برای استفاده در query
    return getLessonVideosByChapterId(chapterId.toString());
  }

  /// ساخت لیست دروس فقط از روی JSON و lesson_videos (در صورت نبود book_covers)
  Future<List<Subject>> _buildSubjectsFromJsonAndLessons(int gradeId) async {
    try {
      Logger.info('📚 [CONTENT] Fallback: building subjects from JSON + lesson_videos for gradeId=$gradeId');

      final gradeJson = await loadGradeJson(gradeId);
      if (gradeJson == null) {
        Logger.error('❌ [CONTENT] Cannot build fallback subjects without grade JSON');
        return [];
      }

      // map bookId -> meta (title/icon/cover)
      final Map<String, Map<String, String>> metaByBookId = {};
      final books = gradeJson['books'] as Map<String, dynamic>? ?? {};
      for (final entry in books.entries) {
        final bookIndex = entry.key; // مثل "1", "2"
        final bookMap = entry.value as Map<String, dynamic>;
        for (final entry in bookMap.entries) {
          final bookSlug = entry.key;
          final subjectMap = entry.value as Map<String, dynamic>;
          final meta = {
            'bookId': bookSlug,
            'title': (subjectMap['title'] as String? ?? '').trim(),
            'icon': (subjectMap['icon'] as String? ?? '').trim(),
            'cover': (subjectMap['cover'] as String? ?? '').trim(),
          };
          metaByBookId[bookSlug] = meta;
          metaByBookId[bookIndex] = meta;
        }
      }

      final List<dynamic> lessonRows = await supabase
          .from('lesson_videos')
          .select('book_id')
          .eq('grade_id', gradeId)
          .eq('active', true) as List<dynamic>;

      final Set<String> bookIdsWithContent = {};
      for (final row in lessonRows) {
        final bookId = row['book_id'] as String?;
        if (bookId != null && bookId.trim().isNotEmpty) {
          bookIdsWithContent.add(bookId.trim());
        }
      }

      if (bookIdsWithContent.isEmpty) {
        Logger.info('⚠️ [CONTENT] No lesson_videos found for gradeId=$gradeId');
        return [];
      }

      final subjects = <Subject>[];
      for (final rawBookId in bookIdsWithContent) {
        final meta = metaByBookId[rawBookId];
        final resolvedBookId = meta?['bookId'] ?? rawBookId;
        final title = meta?['title'];
        final iconFromJson = meta?['icon'];
        final coverFromJson = meta?['cover'];

        final iconPath = (iconFromJson != null && iconFromJson.isNotEmpty)
            ? iconFromJson
            : 'assets/images/icon-darsha/$resolvedBookId.png';
        final coverPath = (coverFromJson != null && coverFromJson.isNotEmpty)
            ? coverFromJson
            : 'assets/images/book-covers/grade$gradeId/$resolvedBookId.png';

        subjects.add(
          Subject(
            id: subjects.length + 1,
            name: title != null && title.isNotEmpty ? title : resolvedBookId,
            slug: resolvedBookId,
            iconPath: iconPath,
            bookCoverPath: coverPath,
            active: true,
          ),
        );
      }

      Logger.info('✅ [CONTENT] Built ${subjects.length} fallback subjects for gradeId=$gradeId');
      return subjects;
    } catch (e) {
      Logger.error('❌ [CONTENT] Fallback subject builder failed', e);
      return [];
    }
  }
}

class BookJsonData {
  final Map<String, String> chapters;
  final String chapterType;

  BookJsonData({
    required this.chapters,
    required this.chapterType,
  });
}
