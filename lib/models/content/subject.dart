class Subject {
  final int id;
  final String name;
  final String slug;
  final String iconPath; // مسیر کامل آیکون از دیتابیس
  final String bookCoverPath;
  final bool active;
  final int? subjectOfferId; // 🚀 برای Mini-Request (از سرور نمیاد)

  Subject({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconPath,
    required this.bookCoverPath,
    required this.active,
    this.subjectOfferId, // nullable چون از سرور نمیاد
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconPath: (json['icon_path'] ?? json['icon_slug'] ?? '') as String,
      bookCoverPath: (json['book_cover_path'] ?? '') as String,
      active: (json['active'] as bool?) ?? true,
      subjectOfferId: json['subject_offer_id'] as int?, // 🚀 Mini-Request
    );
  }

  // New factory for data from the RPC function
  factory Subject.fromRpc(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconPath: (json['icon_path'] ?? json['icon_slug'] ?? '') as String,
      bookCoverPath: (json['book_cover_path'] ?? '') as String,
      active: (json['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon_path': iconPath,
      'book_cover_path': bookCoverPath,
      'active': active,
      'subject_offer_id': subjectOfferId, // 🚀 Mini-Request
    };
  }

  // 🚀 copyWith برای اضافه کردن subjectOfferId
  Subject copyWith({
    int? id,
    String? name,
    String? slug,
    String? iconPath,
    String? bookCoverPath,
    bool? active,
    int? subjectOfferId,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      iconPath: iconPath ?? this.iconPath,
      bookCoverPath: bookCoverPath ?? this.bookCoverPath,
      active: active ?? this.active,
      subjectOfferId: subjectOfferId ?? this.subjectOfferId,
    );
  }
}
