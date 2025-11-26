/// مدل داده‌های فرم آپلود/ویرایش ویدیو
/// بخش «جدید» هم‌راستا با lesson_videos و بخش «قدیمی» برای سازگاری با صفحه ویرایش
class VideoUploadFormData {
  // ==== فیلدهای جدید مطابق lesson_videos ====
  int? gradeId; // پایه (۱ تا ۲۱ مطابق grades.json)
  String? bookId; // شناسه کتاب از JSON (مثل "riazi", "olom")
  String? chapterId; // شناسه فصل از JSON (مثل "1", "2")
  int? stepNumber; // شماره پله/مرحله در فصل
  String? title; // عنوان ویدیو
  String? type; // نوع محتوا: 'note' | 'book' | 'exam'
  String? teacher; // نام استاد
  String? embedUrl; // لینک embed ویدیو
  String? directUrl; // لینک مستقیم ویدیو (اختیاری)
  String? pdfUrl; // لینک PDF (یک فیلد واحد)
  int? duration; // مدت زمان به ثانیه
  bool? active; // وضعیت فعال/غیرفعال
  String? thumbnailUrl; // لینک تصویر بندانگشتی (اختیاری)
  int? likesCount;
  int? viewsCount;

  // ==== فیلدهای قدیمی برای سازگاری با video_edit_screen (فقط برای مسیر ویرایش) ====
  String? chapterTitle;
  int? chapterOrder;
  String? lessonTitle;
  int? lessonOrder;
  String? teacherName;
  String? style;
  String? embedHtml;
  String? notePdfUrl;
  String? exercisePdfUrl;
  String? tags;
  int? durationHours;
  int? durationMinutes;
  int? durationSeconds;

  /// تبدیل مدت زمان به ثانیه (برای استفاده در مسیر قدیمی ویرایش)
  int get durationInSeconds {
    final h = durationHours ?? 0;
    final m = durationMinutes ?? 0;
    final s = durationSeconds ?? 0;
    return h * 3600 + m * 60 + s;
  }

  /// تبدیل تگ‌ها به لیست (برای مسیر قدیمی ویرایش)
  List<String> get tagsList {
    if (tags == null || tags!.trim().isEmpty) return [];
    return tags!
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// اعتبارسنجی حداقلی فرم (برای مسیر جدید آپلود)
  String? validate() {
    if (gradeId == null || gradeId! < 1 || gradeId! > 21) return 'پایه را انتخاب کنید';
    if (bookId == null || bookId!.isEmpty) return 'درس را انتخاب کنید';
    if (chapterId == null || chapterId!.isEmpty) return 'فصل را انتخاب کنید';
    if (stepNumber == null || stepNumber! < 1) return 'شماره مرحله را وارد کنید';
    if (title == null || title!.isEmpty) return 'عنوان ویدیو را وارد کنید';
    if (type == null || type!.isEmpty) return 'نوع محتوا را انتخاب کنید';
    if (teacher == null || teacher!.isEmpty) return 'نام استاد را وارد کنید';
    if (embedUrl == null || embedUrl!.isEmpty) return 'لینک embed را وارد کنید';
    if (duration == null || duration! <= 0) return 'مدت زمان را وارد کنید';
    return null;
  }
}
