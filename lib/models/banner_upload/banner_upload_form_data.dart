class BannerUploadFormData {
  String? title; // عنوان بنر
  String? description; // توضیحات بنر
  String? imageUrl; // لینک تصویر بنر
  String? linkUrl; // لینک مقصد (اختیاری)
  int? position; // موقعیت نمایش (۱ = بالاترین، بالاتر = پایین‌تر)
  bool isActive = true; // فعال/غیرفعال

  /// اعتبارسنجی فرم
  String? validate() {
    if (title == null || title!.trim().isEmpty) return 'عنوان بنر را وارد کنید';
    if (imageUrl == null || imageUrl!.trim().isEmpty) return 'لینک تصویر بنر را وارد کنید';

    // بررسی فرمت URL برای تصویر
    if (!imageUrl!.startsWith('http://') && !imageUrl!.startsWith('https://')) {
      return 'لینک تصویر باید با http:// یا https:// شروع شود';
    }

    // بررسی فرمت URL برای لینک مقصد (اگر وارد شده)
    if (linkUrl != null && linkUrl!.trim().isNotEmpty) {
      if (!linkUrl!.startsWith('http://') && !linkUrl!.startsWith('https://')) {
        return 'لینک مقصد باید با http:// یا https:// شروع شود';
      }
    }

    if (position == null || position! <= 0) return 'موقعیت نمایش را مشخص کنید';

    return null;
  }
}
