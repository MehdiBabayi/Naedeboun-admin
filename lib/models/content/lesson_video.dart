class LessonVideo {
  final int id;
  final int lessonId;
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
    required this.lessonId,
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
      lessonId: json['lesson_id'] as int,
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
      'lesson_id': lessonId,
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
