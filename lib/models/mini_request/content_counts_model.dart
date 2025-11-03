/// مدل برای نگهداری تعداد محتوا
/// استفاده: مقایسه با backend برای تشخیص محتوای جدید
class ContentCounts {
  final int lessonVideosCount;
  final int stepByStepPdfsCount;
  final int provincialSamplePdfsCount;
  final int chaptersCount;
  final int subjectsCount;
  final int lessonsCount;

  ContentCounts({
    required this.lessonVideosCount,
    required this.stepByStepPdfsCount,
    required this.provincialSamplePdfsCount,
    required this.chaptersCount,
    required this.subjectsCount,
    required this.lessonsCount,
  });

  factory ContentCounts.fromJson(Map<String, dynamic> json) {
    return ContentCounts(
      lessonVideosCount: json['lesson_videos_count'] as int? ?? 0,
      stepByStepPdfsCount: json['step_by_step_pdfs_count'] as int? ?? 0,
      provincialSamplePdfsCount:
          json['provincial_sample_pdfs_count'] as int? ?? 0,
      chaptersCount: json['chapters_count'] as int? ?? 0,
      subjectsCount: json['subjects_count'] as int? ?? 0,
      lessonsCount: json['lessons_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lesson_videos_count': lessonVideosCount,
      'step_by_step_pdfs_count': stepByStepPdfsCount,
      'provincial_sample_pdfs_count': provincialSamplePdfsCount,
      'chapters_count': chaptersCount,
      'subjects_count': subjectsCount,
      'lessons_count': lessonsCount,
    };
  }

  /// بررسی اینکه آیا تغییری نسبت به counts دیگر وجود دارد
  bool hasChanges(ContentCounts other) {
    return lessonVideosCount != other.lessonVideosCount ||
        stepByStepPdfsCount != other.stepByStepPdfsCount ||
        provincialSamplePdfsCount != other.provincialSamplePdfsCount ||
        chaptersCount != other.chaptersCount ||
        subjectsCount != other.subjectsCount ||
        lessonsCount != other.lessonsCount;
  }

  @override
  String toString() {
    return 'ContentCounts(videos: $lessonVideosCount, stepByStep: $stepByStepPdfsCount, '
        'provincial: $provincialSamplePdfsCount, chapters: $chaptersCount, '
        'subjects: $subjectsCount, lessons: $lessonsCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ContentCounts &&
        other.lessonVideosCount == lessonVideosCount &&
        other.stepByStepPdfsCount == stepByStepPdfsCount &&
        other.provincialSamplePdfsCount == provincialSamplePdfsCount &&
        other.chaptersCount == chaptersCount &&
        other.subjectsCount == subjectsCount &&
        other.lessonsCount == lessonsCount;
  }

  @override
  int get hashCode {
    return lessonVideosCount.hashCode ^
        stepByStepPdfsCount.hashCode ^
        provincialSamplePdfsCount.hashCode ^
        chaptersCount.hashCode ^
        subjectsCount.hashCode ^
        lessonsCount.hashCode;
  }
}
