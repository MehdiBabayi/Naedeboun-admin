class BookCover {
  final int id;
  final String subjectName;
  final String subjectPath;
  final int grade;
  final String? track;
  final String? trackName;

  BookCover({
    required this.id,
    required this.subjectName,
    required this.subjectPath,
    required this.grade,
    this.track,
    this.trackName,
  });

  factory BookCover.fromJson(Map<String, dynamic> json) {
    return BookCover(
      id: (json['id'] ?? 0) as int,
      subjectName: (json['subject_name'] ?? '') as String,
      subjectPath: (json['subject_path'] ?? '') as String,
      grade: (json['grade'] ?? 0) as int,
      track: json['track'] as String?,
      trackName: json['track_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_name': subjectName,
      'subject_path': subjectPath,
      'grade': grade,
      'track': track,
      'track_name': trackName,
    };
  }

  bool get isEmpty => id == 0;

  static BookCover empty() =>
      BookCover(id: 0, subjectName: '', subjectPath: '', grade: 0);
}
