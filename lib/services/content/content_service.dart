import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nardeboun/models/content/subject.dart';
import 'package:nardeboun/models/content/chapter.dart';
import 'package:nardeboun/models/content/lesson_video.dart';
import 'package:nardeboun/utils/grade_utils.dart';
import '../../utils/logger.dart';

class ContentService {
  final SupabaseClient supabase;

  ContentService(this.supabase);

  Future<List<Subject>> getSubjectsForUser({
    required int gradeId,
    int? trackId,
  }) async {
    // We must use an RPC call to efficiently filter subjects
    // that have at least one active video.
    try {
      final data =
          await supabase.rpc(
                'get_active_subjects_for_user',
                params: {'p_grade_id': gradeId, 'p_track_id': trackId},
              )
              as List<dynamic>;

      if (data.isEmpty) {
        return [];
      }

      return data
          .map((j) => Subject.fromRpc(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error("Error fetching subjects via RPC", e);
      // Fallback to a simpler query if RPC fails, for now
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

  Future<List<LessonVideo>> getLessonVideos(int chapterId) async {  // ← تغییر از lessonId
    final data = await supabase
        .from('lesson_videos')
        .select()
        .eq('chapter_id', chapterId)  // ← تغییر از lesson_id
        .eq('active', true)
        .order('lesson_order', ascending: true)
        .order('style', ascending: true);
    
    return data.map((j) => LessonVideo.fromJson(j as Map<String, dynamic>)).toList();
  }
}
