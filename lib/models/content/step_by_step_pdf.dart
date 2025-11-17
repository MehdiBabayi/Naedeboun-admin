class StepByStepPdf {
  final int id;
  final int gradeId; // پایه (۱ تا ۲۱)
  final String bookId; // شناسه کتاب از JSON (مثل "riazi", "olom")
  final String pdfTitle; // عنوان PDF
  final String author; // نویسنده/مؤلف - نه year
  final double? size; // حجم فایل (MB)
  final String pdfUrl; // لینک PDF
  final bool active; // وضعیت فعال/غیرفعال
  final DateTime createdAt;
  final DateTime updatedAt;

  StepByStepPdf({
    required this.id,
    required this.gradeId,
    required this.bookId,
    required this.pdfTitle,
    required this.author,
    this.size,
    required this.pdfUrl,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StepByStepPdf.fromJson(Map<String, dynamic> json) {
    return StepByStepPdf(
      id: json['id'] as int,
      gradeId: json['grade_id'] as int,
      bookId: json['book_id'] as String,
      pdfTitle: json['pdf_title'] as String,
      author: json['author'] as String,
      size: json['size'] != null ? (json['size'] as num).toDouble() : null,
      pdfUrl: json['pdf_url'] as String,
      active: (json['active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade_id': gradeId,
      'book_id': bookId,
      'pdf_title': pdfTitle,
      'author': author,
      'size': size,
      'pdf_url': pdfUrl,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // برای سازگاری با کدهای قدیمی که هنوز از title استفاده می‌کنند
  String get title => pdfTitle;

  // برای سازگاری با کدهای قدیمی
  String get subjectId => bookId;
  double? get fileSizeMb => size;
}
