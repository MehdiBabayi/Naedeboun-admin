import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس حذف ویدیو
class VideoDeleteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// حذف ویدیو با استفاده از Edge Function delete-content
  Future<Map<String, dynamic>> deleteVideo({
    required int lessonVideoId,
  }) async {
    try {
      Logger.info('🗑️ [VIDEO-DELETE] شروع حذف ویدیو ID: $lessonVideoId');

      final payload = {
        'lesson_video_id': lessonVideoId,
      };

      final response = await _supabase.functions.invoke(
        'delete-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [VIDEO-DELETE] ویدیو با موفقیت حذف شد');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [VIDEO-DELETE] شکست در حذف: $error');
        throw Exception(error);
      } else {
        Logger.error('❌ [VIDEO-DELETE] خطای HTTP: ${response.status}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error('❌ [VIDEO-DELETE] خطا در حذف ویدیو', e);
      rethrow;
    }
  }
}

