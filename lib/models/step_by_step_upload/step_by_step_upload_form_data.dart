/// مدل داده‌های فرم آپلود گام‌به‌گام
class StepByStepUploadFormData {
  String? branch; // ابتدایی / متوسطه اول / متوسطه دوم
  String? grade; // یکم ... دوازدهم
  String? track; // ریاضی / تجربی / انسانی / بدون رشته
  String? subject; // نام فارسی درس
  String? title; // عنوان PDF
  String? pdfUrl; // لینک PDF
  double? fileSizeMb; // حجم فایل (مگابایت) - اختیاری
  int? pageCount; // تعداد صفحات - اختیاری
  bool active = true; // فعال/غیرفعال

  /// تبدیل branch به level برای دیتابیس
  /// branch: 'ابتدایی' | 'متوسطه اول' | 'متوسطه دوم'
  /// level: 'ابتدایی' | 'متوسط اول' | 'متوسط دوم'
  String? get levelForDatabase {
    if (branch == null) return null;
    switch (branch) {
      case 'ابتدایی':
        return 'ابتدایی';
      case 'متوسطه اول':
        return 'متوسط اول';
      case 'متوسطه دوم':
        return 'متوسط دوم';
      default:
        return null;
    }
  }

  /// اعتبارسنجی فرم
  String? validate() {
    if (branch == null || branch!.isEmpty) return 'شاخه را انتخاب کنید';
    if (grade == null || grade!.isEmpty) return 'پایه را انتخاب کنید';
    if (subject == null || subject!.isEmpty) return 'درس را انتخاب کنید';
    if (title == null || title!.trim().isEmpty) return 'عنوان را وارد کنید';
    if (pdfUrl == null || pdfUrl!.trim().isEmpty) {
      return 'لینک PDF را وارد کنید';
    }

    // بررسی فرمت URL
    if (!pdfUrl!.startsWith('http://') && !pdfUrl!.startsWith('https://')) {
      return 'لینک PDF باید با http:// یا https:// شروع شود';
    }

    return null;
  }
}
