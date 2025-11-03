import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nardeboun/utils/logger.dart';

/// سرویس مدیریت اساتید برای دریافت نام اساتید از دیتابیس
class TeacherService {
  TeacherService._();
  static final TeacherService _instance = TeacherService._();
  static TeacherService get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// دریافت نام استاد بر اساس teacher_id
  Future<String> getTeacherNameById(int teacherId) async {
    try {
      Logger.info('🔍 [TEACHER] Loading teacher: $teacherId');

      final response = await _supabase
          .from('teachers')
          .select('name')
          .eq('id', teacherId)
          .maybeSingle();

      if (response != null && response['name'] != null) {
        final teacherName = response['name'] as String;
        Logger.info('✅ [TEACHER] Teacher name: $teacherName');
        return teacherName;
      } else {
        Logger.info('⚠️ [TEACHER] Teacher not found for ID: $teacherId');
        return 'استاد نامشخص';
      }
    } catch (e) {
      Logger.error('Error fetching teacher name for ID $teacherId', e);
      Logger.error('❌ [TEACHER] Error loading teacher $teacherId', e);
      return 'استاد نامشخص';
    }
  }

  /// دریافت نام‌های چندین استاد به صورت batch
  Future<Map<int, String>> getTeacherNamesByIds(List<int> teacherIds) async {
    if (teacherIds.isEmpty) return {};

    try {
      Logger.info('🔍 [TEACHER] Loading multiple teachers: ${teacherIds.join(", ")}');

      final response = await _supabase
          .from('teachers')
          .select('id, name')
          .inFilter('id', teacherIds);

      final Map<int, String> teacherNames = {};

      for (final teacher in response) {
        final id = teacher['id'] as int;
        final name = teacher['name'] as String;
        teacherNames[id] = name;
        Logger.info('✅ [TEACHER] Teacher $id: $name');
      }

      // برای teacher_id هایی که پیدا نشدند، نامشخص قرار بده
      for (final id in teacherIds) {
        if (!teacherNames.containsKey(id)) {
          teacherNames[id] = 'استاد نامشخص';
          Logger.info('⚠️ [TEACHER] Teacher $id not found, using default name');
        }
      }

      return teacherNames;
    } catch (e) {
      Logger.error('Error fetching multiple teacher names', e);
      Logger.error('❌ [TEACHER] Error loading multiple teachers', e);

      // در صورت خطا، همه را نامشخص قرار بده
      final Map<int, String> fallback = {};
      for (final id in teacherIds) {
        fallback[id] = 'استاد نامشخص';
      }
      return fallback;
    }
  }
}
