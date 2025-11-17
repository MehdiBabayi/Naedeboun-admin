/// مدل داده‌های فرم آپلود گام‌به‌گام
class StepByStepUploadFormData {
  int? gradeId; // پایه (۱ تا ۲۱)
  String? bookId; // شناسه کتاب از JSON (مثل "riazi", "olom")
  String? pdfTitle; // عنوان PDF
  String? author; // نویسنده/مؤلف
  String? pdfUrl; // لینک PDF
  double? size; // حجم فایل (MB)
  bool active = true; // فعال/غیرفعال

  /// اعتبارسنجی فرم
  String? validate() {
    if (gradeId == null) return 'پایه را انتخاب کنید';
    if (bookId == null || bookId!.isEmpty) return 'درس را انتخاب کنید';
    if (pdfTitle == null || pdfTitle!.trim().isEmpty) return 'عنوان را وارد کنید';
    if (author == null || author!.trim().isEmpty) return 'نویسنده را وارد کنید';
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
