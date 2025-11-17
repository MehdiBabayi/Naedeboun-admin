class ProvincialSamplePdf {
  final int id;
  final int gradeId; // پایه (۱ تا ۲۱)
  final String bookId; // شناسه کتاب از JSON (مثل "riazi", "olom")
  final String pdfTitle; // عنوان PDF
  final String type; // نوع امتحان: 'first_term' | 'second_term' | 'midterm_1' | 'midterm_2'
  final int? year; // سال برگزاری
  final String? author; // نویسنده/مؤلف
  final bool hasAnswer; // آیا پاسخنامه دارد؟
  final double? size; // حجم فایل (MB)
  final String pdfUrl; // لینک PDF
  final bool active; // وضعیت فعال/غیرفعال
  final DateTime createdAt;
  final DateTime updatedAt;

  ProvincialSamplePdf({
    required this.id,
    required this.gradeId,
    required this.bookId,
    required this.pdfTitle,
    required this.type,
    this.year,
    this.author,
    required this.hasAnswer,
    this.size,
    required this.pdfUrl,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProvincialSamplePdf.fromJson(Map<String, dynamic> json) {
    return ProvincialSamplePdf(
      id: json['id'] as int,
      gradeId: json['grade_id'] as int,
      bookId: json['book_id'] as String,
      pdfTitle: json['pdf_title'] as String,
      type: json['type'] as String,
      year: json['year'] as int?,
      author: json['author'] as String?,
      hasAnswer: (json['has_answer'] as bool?) ?? false,
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
      'type': type,
      'year': year,
      'author': author,
      'has_answer': hasAnswer,
      'size': size,
      'pdf_url': pdfUrl,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // برای سازگاری با کدهای قدیمی که هنوز از title استفاده می‌کنند
  String get title => pdfTitle;

  // برای سازگاری با کدهای قدیمی که هنوز از hasAnswerKey استفاده می‌کنند
  bool get hasAnswerKey => hasAnswer;

  // برای سازگاری با کدهای قدیمی که هنوز از publishYear استفاده می‌کنند
  int? get publishYear => year;

  // برای سازگاری با کدهای قدیمی که هنوز از designer استفاده می‌کنند
  String? get designer => author;

  // برای سازگاری با کدهای قدیمی که هنوز از fileSizeMb استفاده می‌کنند
  double? get fileSizeMb => size;

  // برای سازگاری با کدهای قدیمی
  dynamic get subjectId => bookId;
}
