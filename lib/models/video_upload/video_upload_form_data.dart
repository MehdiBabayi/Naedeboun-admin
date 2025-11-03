/// مدل ساده داده‌های فرم آپلود ویدیو
class VideoUploadFormData {
  String? branch; // ابتدایی / متوسطه اول / متوسطه دوم
  String? grade; // یکم ... دوازدهم
  String? track; // ریاضی / تجربی / انسانی / بدون رشته
  String? subject; // نام فارسی درس
  String? subjectSlug; // اسلاگ درس
  String? chapterTitle; // عنوان فصل
  int? chapterOrder; // شماره فصل
  String? style; // جزوه / نمونه سوال / کتاب درسی
  String? lessonTitle; // عنوان درس
  int? lessonOrder; // شماره درس
  String? teacherName; // نام استاد
  int? durationHours; // ساعت
  int? durationMinutes; // دقیقه
  int? durationSeconds; // ثانیه
  String? tags; // تگ‌ها با کاما
  String? embedHtml; // کد آپارات
  String? notePdfUrl; // لینک PDF جزوه (اختیاری)
  String? exercisePdfUrl; // لینک PDF نمونه سوال (اختیاری)

  /// تبدیل مدت زمان به ثانیه (برای ارسال به سرور)
  int get durationInSeconds {
    final h = durationHours ?? 0;
    final m = durationMinutes ?? 0;
    final s = durationSeconds ?? 0;
    return h * 3600 + m * 60 + s;
  }

  /// تبدیل تگ‌ها به لیست
  List<String> get tagsList {
    if (tags == null || tags!.trim().isEmpty) return [];
    return tags!
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// اعتبارسنجی حداقلی فرم (ساده)
  String? validate() {
    if (branch == null || branch!.isEmpty) return 'شاخه را انتخاب کنید';
    if (grade == null || grade!.isEmpty) return 'پایه را انتخاب کنید';
    if (subject == null || subject!.isEmpty) return 'درس را انتخاب کنید';
    if (subjectSlug == null || subjectSlug!.isEmpty) return 'اسلاگ درس را انتخاب کنید';
    if (chapterTitle == null || chapterTitle!.isEmpty) return 'عنوان فصل را وارد کنید';
    if ((chapterOrder ?? 0) < 1) return 'شماره فصل را وارد کنید';
    if (style == null || style!.isEmpty) return 'نوع محتوا را انتخاب کنید';
    if (lessonTitle == null || lessonTitle!.isEmpty) return 'عنوان درس را وارد کنید';
    if ((lessonOrder ?? 0) < 1) return 'شماره درس را وارد کنید';
    if (teacherName == null || teacherName!.isEmpty) return 'نام استاد را وارد کنید';
    if (durationInSeconds <= 0) return 'مدت زمان باید بیشتر از صفر باشد';
    return null;
  }
}
