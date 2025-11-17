import '../../utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// سرویس آپلود بنر
class BannerUploadService {
  /// آپلود بنر جدید
  Future<void> uploadBanner(Map<String, dynamic> payload) async {
    Logger.info('📤 [BANNER-UPLOAD] ارسال به سرور: $payload');

    final response = await Supabase.instance.client.functions.invoke(
      'create-banner',
      body: payload,
    );

    if (response.status != 200) {
      Logger.error('❌ [BANNER-UPLOAD] خطا در آپلود بنر: ${response.status} - ${response.data}');
      throw Exception('خطا در آپلود بنر: ${response.data}');
    }

    Logger.info('✅ [BANNER-UPLOAD] بنر با موفقیت ثبت شد');
  }
}
