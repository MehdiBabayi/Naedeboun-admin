class Chapter {
  final int id;
  final int subjectOfferId;
  final int chapterOrder;
  final String title;
  final String chapterImagePath;
  final bool active;

  Chapter({
    required this.id,
    required this.subjectOfferId,
    required this.chapterOrder,
    required this.title,
    required this.chapterImagePath,
    required this.active,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as int,
      subjectOfferId: json['subject_offer_id'] as int,
      chapterOrder: json['chapter_order'] as int,
      title: json['title'] as String,
      chapterImagePath: (json['chapter_image_path'] ?? '') as String,
      active: (json['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_offer_id': subjectOfferId,
      'chapter_order': chapterOrder,
      'title': title,
      'chapter_image_path': chapterImagePath,
      'active': active,
    };
  }
}
