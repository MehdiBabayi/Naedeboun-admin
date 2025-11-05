import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

class PdfEditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> updatePdf({
    required String type, // 'step_by_step' | 'provincial'
    required int id,
    required Map<String, dynamic> updates,
  }) async {
    try {
      Logger.info('🔄 [PDF-EDIT] type=$type id=$id updates=$updates');
      final payload = {
        'type': type,
        'id': id,
        'updates': updates,
      };

      final response = await _supabase.functions.invoke(
        'update-pdf-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [PDF-EDIT] بروزرسانی موفق');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [PDF-EDIT] شکست: $error');
        throw Exception(error);
      }
      Logger.error('❌ [PDF-EDIT] HTTP: ${response.status}');
      throw Exception('HTTP ${response.status}');
    } catch (e) {
      Logger.error('❌ [PDF-EDIT] Exception', e);
      rethrow;
    }
  }
}
