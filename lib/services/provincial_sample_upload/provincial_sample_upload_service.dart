import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس آپلود نمونه سوال استانی
class ProvincialSampleUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// آپلود نمونه سوال با استفاده از Edge Function create-provincial-sample-pdf
  Future<Map<String, dynamic>> uploadProvincialSample({
    required Map<String, dynamic> payload,
  }) async {
    try {
      Logger.info('📤 [PROVINCIAL-UPLOAD] شروع آپلود با payload: $payload');

      final response = await _supabase.functions.invoke(
        'create-provincial-sample-pdf',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [PROVINCIAL-UPLOAD] آپلود موفق');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [PROVINCIAL-UPLOAD] شکست: $error');
        throw Exception(error);
      } else {
        Logger.error('❌ [PROVINCIAL-UPLOAD] خطای HTTP: ${response.status}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error('❌ [PROVINCIAL-UPLOAD] خطا در آپلود', e);
      rethrow;
    }
  }
}

