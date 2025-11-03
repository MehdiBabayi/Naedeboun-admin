class Lesson {
  final int id;
  final int chapterId;
  final int lessonOrder;
  final String title;
  final bool active;

  Lesson({
    required this.id,
    required this.chapterId,
    required this.lessonOrder,
    required this.title,
    required this.active,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int,
      chapterId: json['chapter_id'] as int,
      lessonOrder: json['lesson_order'] as int,
      title: json['title'] as String,
      active: (json['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'lesson_order': lessonOrder,
      'title': title,
      'active': active,
    };
  }
}
