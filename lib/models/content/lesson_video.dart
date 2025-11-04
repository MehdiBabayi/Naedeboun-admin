class LessonVideo {
  final int id;
  final int chapterId;  // ← جدید
  final int chapterOrder;  // ← جدید
  final String chapterTitle;  // ← جدید
  final int lessonOrder;  // ← جدید
  final String lessonTitle;  // ← جدید
  final int teacherId;
  final String style;
  final String aparatUrl;
  final int durationSec;
  final int viewCount;
  final List<String> tags;
  final String contentStatus;
  final bool active;
  final String? embedHtml;
  final bool allowLandscape;
  final String? notePdfUrl; // PDF جزوه (اختیاری)
  final String? exercisePdfUrl; // PDF نمونه‌سوال آموزشی (اختیاری)

  LessonVideo({
    required this.id,
    required this.chapterId,
    required this.chapterOrder,
    required this.chapterTitle,
    required this.lessonOrder,
    required this.lessonTitle,
    required this.teacherId,
    required this.style,
    required this.aparatUrl,
    required this.durationSec,
    required this.viewCount,
    required this.tags,
    required this.contentStatus,
    required this.active,
    this.embedHtml,
    this.allowLandscape = true,
    this.notePdfUrl,
    this.exercisePdfUrl,
  });

  factory LessonVideo.fromJson(Map<String, dynamic> json) {
    return LessonVideo(
      id: json['id'] as int,
      chapterId: json['chapter_id'] as int,
      chapterOrder: json['chapter_order'] as int,
      chapterTitle: json['chapter_title'] as String,
      lessonOrder: json['lesson_order'] as int,
      lessonTitle: json['lesson_title'] as String,
      teacherId: json['teacher_id'] as int,
      style: json['style'] as String,
      aparatUrl: json['aparat_url'] as String,
      durationSec: (json['duration_sec'] as num).toInt(),
      viewCount: (json['view_count'] as num).toInt(),
      tags: ((json['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      contentStatus: json['content_status'] as String,
      active: (json['active'] as bool?) ?? true,
      embedHtml: json['embed_html'] as String?,
      allowLandscape: (json['allow_landscape'] as bool?) ?? true,
      notePdfUrl: json['note_pdf_url'] as String?,
      exercisePdfUrl: json['exercise_pdf_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'chapter_order': chapterOrder,
      'chapter_title': chapterTitle,
      'lesson_order': lessonOrder,
      'lesson_title': lessonTitle,
      'teacher_id': teacherId,
      'style': style,
      'aparat_url': aparatUrl,
      'duration_sec': durationSec,
      'view_count': viewCount,
      'tags': tags,
      'content_status': contentStatus,
      'active': active,
      'embed_html': embedHtml,
      'allow_landscape': allowLandscape,
      'note_pdf_url': notePdfUrl,
      'exercise_pdf_url': exercisePdfUrl,
    };
  }
}
