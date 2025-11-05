import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس آپلود گام‌به‌گام
class StepByStepUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// آپلود گام‌به‌گام با استفاده از Edge Function create-step-by-step-pdf
  Future<Map<String, dynamic>> uploadStepByStep({
    required Map<String, dynamic> payload,
  }) async {
    try {
      Logger.info('📤 [STEP-BY-STEP-UPLOAD] شروع آپلود با payload: $payload');

      final response = await _supabase.functions.invoke(
        'create-step-by-step-pdf',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [STEP-BY-STEP-UPLOAD] آپلود موفق');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [STEP-BY-STEP-UPLOAD] شکست: $error');
        throw Exception(error);
      } else {
        Logger.error('❌ [STEP-BY-STEP-UPLOAD] خطای HTTP: ${response.status}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error('❌ [STEP-BY-STEP-UPLOAD] خطا در آپلود', e);
      rethrow;
    }
  }
}

