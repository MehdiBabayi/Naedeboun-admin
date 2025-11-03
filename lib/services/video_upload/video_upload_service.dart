import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس آپلود ویدیو (ساده و شفاف)
/// منطق فراخوانی به تابع Edge (create-content) منتقل شده است
class VideoUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// ارسال ویدیو به سرور بر اساس منطق موجود در PHP
  /// نکته: تمام صحت‌سنجی‌های امنیتی سمت سرور انجام می‌شود
  Future<Map<String, dynamic>> uploadVideo({
    required Map<String, dynamic> payload,
  }) async {
    try {
      Logger.info('🔍 [VIDEO-UPLOAD] شروع ارسال ویدیو به سرور');
      Logger.info('🔍 [VIDEO-UPLOAD] Payload: $payload');

      final response = await _supabase.functions.invoke(
        'create-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [VIDEO-UPLOAD] ویدیو با موفقیت ثبت شد');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [VIDEO-UPLOAD] شکست در ثبت: $error');
        throw Exception(error);
      } else {
        Logger.error('❌ [VIDEO-UPLOAD] خطای HTTP: ${response.status}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error('❌ [VIDEO-UPLOAD] خطا در آپلود ویدیو', e);
      rethrow;
    }
  }
}
