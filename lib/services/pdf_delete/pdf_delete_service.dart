import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

class PdfDeleteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> deletePdf({
    required String type, // 'step_by_step' | 'provincial'
    required int id,
  }) async {
    try {
      Logger.info('🗑️ [PDF-DELETE] type=$type id=$id');
      final payload = {
        'type': type,
        'id': id,
      };

      final response = await _supabase.functions.invoke(
        'delete-pdf-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [PDF-DELETE] حذف موفق');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [PDF-DELETE] شکست: $error');
        throw Exception(error);
      }
      Logger.error('❌ [PDF-DELETE] HTTP: ${response.status}');
      throw Exception('HTTP ${response.status}');
    } catch (e) {
      Logger.error('❌ [PDF-DELETE] Exception', e);
      rethrow;
    }
  }
}
