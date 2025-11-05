import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس ویرایش ویدیو
class VideoEditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// به‌روزرسانی ویدیو با استفاده از Edge Function update-content
  Future<Map<String, dynamic>> updateVideo({
    required int lessonVideoId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      Logger.info('🔍 [VIDEO-EDIT] شروع به‌روزرسانی ویدیو ID: $lessonVideoId');
      Logger.info('🔍 [VIDEO-EDIT] Updates: $updates');

      final payload = {
        'lesson_video_id': lessonVideoId,
        'updates': updates,
      };

      final response = await _supabase.functions.invoke(
        'update-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [VIDEO-EDIT] ویدیو با موفقیت به‌روزرسانی شد');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [VIDEO-EDIT] شکست در به‌روزرسانی: $error');
        throw Exception(error);
      } else {
        Logger.error('❌ [VIDEO-EDIT] خطای HTTP: ${response.status}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error('❌ [VIDEO-EDIT] خطا در به‌روزرسانی ویدیو', e);
      rethrow;
    }
  }
}

