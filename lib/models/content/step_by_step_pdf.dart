class StepByStepPdf {
  final int id;
  final String title;
  final String level; // ابتدایی / متوسط اول / متوسط دوم
  final int gradeId;
  final int? trackId;
  final int subjectId;
  final String pdfUrl;
  final double? fileSizeMb;
  final int? pageCount;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  StepByStepPdf({
    required this.id,
    required this.title,
    required this.level,
    required this.gradeId,
    this.trackId,
    required this.subjectId,
    required this.pdfUrl,
    this.fileSizeMb,
    this.pageCount,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StepByStepPdf.fromJson(Map<String, dynamic> json) {
    return StepByStepPdf(
      id: json['id'] as int,
      title: json['title'] as String,
      level: json['level'] as String,
      gradeId: json['grade_id'] as int,
      trackId: json['track_id'] as int?,
      subjectId: json['subject_id'] as int,
      pdfUrl: json['pdf_url'] as String,
      fileSizeMb: json['file_size_mb'] != null
          ? (json['file_size_mb'] as num).toDouble()
          : null,
      pageCount: json['page_count'] as int?,
      active: (json['active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'level': level,
      'grade_id': gradeId,
      'track_id': trackId,
      'subject_id': subjectId,
      'pdf_url': pdfUrl,
      'file_size_mb': fileSizeMb,
      'page_count': pageCount,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
