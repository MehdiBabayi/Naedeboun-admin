import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس ویرایش ویدیو
class VideoEditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// به‌روزرسانی ویدیو با استفاده از Edge Function update-content
  Future<Map<String, dynamic>> updateVideo({
    required int videoId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      Logger.info('🔍 [VIDEO-EDIT] شروع به‌روزرسانی ویدیو ID: $videoId');
      Logger.info('🔍 [VIDEO-EDIT] Updates: $updates');

      // اطمینان از اینکه book_id و chapter_id همیشه string هستند (نه int)
      final safeUpdates = Map<String, dynamic>.from(updates);
      if (safeUpdates.containsKey('book_id')) {
        safeUpdates['book_id'] = safeUpdates['book_id'].toString();
      }
      if (safeUpdates.containsKey('chapter_id')) {
        safeUpdates['chapter_id'] = safeUpdates['chapter_id'].toString();
      }

      final payload = {'video_id': videoId, 'updates': safeUpdates};

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
        Logger.info('🔍 [VIDEO-EDIT] Response data: $data');

        // بررسی موفقیت - حالا success: true را هم چک می‌کنیم
        if (data != null &&
            (data['success'] == true ||
                data['success'] == 'true' ||
                data['message'] != null)) {
          Logger.info('✅ [VIDEO-EDIT] ویدیو با موفقیت به‌روزرسانی شد');
          Logger.info('✅ [VIDEO-EDIT] Updated video: ${data['video']}');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [VIDEO-EDIT] شکست در به‌روزرسانی: $error');
        Logger.error('❌ [VIDEO-EDIT] Response data: $data');
        throw Exception(error);
      } else {
        Logger.error('❌ [VIDEO-EDIT] خطای HTTP: ${response.status}');
        Logger.error('❌ [VIDEO-EDIT] Response: ${response.data}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } on PostgrestException catch (e, s) {
      Logger.error(
        '❌ [VIDEO-EDIT] PostgrestException: ${e.message} | code: ${e.code}',
      );
      Logger.error('❌ [VIDEO-EDIT] Stack: $s');
      rethrow;
    } catch (e, s) {
      Logger.error('❌ [VIDEO-EDIT] خطا در به‌روزرسانی ویدیو: $e');
      Logger.error('❌ [VIDEO-EDIT] Stack: $s');
      rethrow;
    }
  }
}
