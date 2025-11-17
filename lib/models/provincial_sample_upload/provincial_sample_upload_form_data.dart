/// مدل داده‌های فرم آپلود نمونه سوال استانی
class ProvincialSampleUploadFormData {
  int? gradeId; // پایه (۱ تا ۲۱)
  String? bookId; // شناسه کتاب از JSON (مثل "riazi", "olom")
  String? pdfTitle; // عنوان PDF
  String? type; // نوع امتحان: 'first_term' | 'second_term' | 'midterm_1' | 'midterm_2'
  int? year; // سال برگزاری
  String? author; // نویسنده/مؤلف
  bool hasAnswer = false; // آیا پاسخنامه دارد؟
  String? pdfUrl; // لینک PDF
  double? size; // حجم فایل (MB)
  bool active = true; // فعال/غیرفعال

  // فیلدهای سازگاری برای کدهای قدیمی
  String? branch;
  String? grade;
  String? track;
  String? subject;
  int? publishYear;
  bool? hasAnswerKey;
  String? designer;
  double? fileSizeMb;
  int? pageCount;
  String? title;

  /// اعتبارسنجی فرم
  String? validate() {
    if (gradeId == null) return 'پایه را انتخاب کنید';
    if (bookId == null || bookId!.isEmpty) return 'درس را انتخاب کنید';
    if (pdfTitle == null || pdfTitle!.trim().isEmpty) return 'عنوان PDF را وارد کنید';
    if (type == null || type!.isEmpty) return 'نوع امتحان را انتخاب کنید';
    if (author == null || author!.trim().isEmpty) return 'نویسنده را وارد کنید';
    if (pdfUrl == null || pdfUrl!.trim().isEmpty) return 'لینک PDF را وارد کنید';

    // بررسی فرمت URL
    if (!pdfUrl!.startsWith('http://') && !pdfUrl!.startsWith('https://')) {
      return 'لینک PDF باید با http:// یا https:// شروع شود';
    }

    return null;
  }

  // getterهای سازگاری
  int get levelForDatabase => int.tryParse(branch ?? '1') ?? 1;
}

