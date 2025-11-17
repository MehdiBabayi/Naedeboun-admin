class LessonVideo {
  final int videoId; // PRIMARY KEY, AUTO INCREMENT
  final int gradeId; // پایه (۱ تا ۲۱)
  final String bookId; // شناسه کتاب از JSON (مثل "riazi", "olom")
  final String chapterId; // شناسه فصل از JSON (مثل "1", "2")
  final int stepNumber; // شماره پله/مرحله در فصل
  final String title; // عنوان ویدیو
  final String type; // نوع محتوا: 'note'|'book'|'exam'
  final String teacher; // نام استاد
  final String? embedUrl; // لینک embed ویدیو
  final String? directUrl; // لینک مستقیم ویدیو (اختیاری)
  final String? pdfUrl; // لینک PDF (یک فیلد واحد)
  final String? thumbnailUrl; // لینک تصویر بندانگشتی
  final int duration; // مدت زمان به ثانیه
  final int likesCount; // تعداد لایک‌ها
  final int viewsCount; // تعداد بازدیدها
  final bool active; // وضعیت فعال/غیرفعال
  final DateTime createdAt;
  final DateTime updatedAt;

  LessonVideo({
    required this.videoId,
    required this.gradeId,
    required this.bookId,
    required this.chapterId,
    required this.stepNumber,
    required this.title,
    required this.type,
    required this.teacher,
    this.embedUrl,
    this.directUrl,
    this.pdfUrl,
    this.thumbnailUrl,
    required this.duration,
    required this.likesCount,
    required this.viewsCount,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonVideo.fromJson(Map<String, dynamic> json) {
    return LessonVideo(
      videoId: json['video_id'] as int,
      gradeId: json['grade_id'] as int,
      bookId: json['book_id'] as String,
      chapterId: json['chapter_id'] as String,
      stepNumber: json['step_number'] as int,
      title: json['title'] as String,
      type: json['type'] as String,
      teacher: json['teacher'] as String,
      embedUrl: json['embed_url'] as String?,
      directUrl: json['direct_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: json['duration'] as int,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      active: (json['active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'grade_id': gradeId,
      'book_id': bookId,
      'chapter_id': chapterId,
      'step_number': stepNumber,
      'title': title,
      'type': type,
      'teacher': teacher,
      'embed_url': embedUrl,
      'direct_url': directUrl,
      'pdf_url': pdfUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'likes_count': likesCount,
      'views_count': viewsCount,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // برای سازگاری با کدهای قدیمی که هنوز از id استفاده می‌کنند
  int get id => videoId;

  // getterهای سازگاری برای فیلدهای قدیمی
  String get style => type;
  String get lessonTitle => title;
  int? get teacherId => null; // باید از جداول دیگر گرفته شود
  String? get notePdfUrl => pdfUrl;
  String? get exercisePdfUrl => pdfUrl;
  int get durationSec => duration;
  int? get chapterOrder => null; // باید از جداول دیگر گرفته شود
  String get chapterTitle => ""; // باید از جداول دیگر گرفته شود
  int get lessonOrder => stepNumber;
  String get contentStatus => "published";
  String? get aparatUrl => embedUrl;
  String? get embedHtml => embedUrl;
  int get viewCount => viewsCount;
  List<String> get tags => [];
  bool get allowLandscape => true;
}
