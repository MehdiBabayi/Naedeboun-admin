class Teacher {
  final int id;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final bool active;

  Teacher({
    required this.id,
    required this.name,
    this.bio,
    this.avatarUrl,
    required this.active,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as int,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      active: (json['active'] as bool?) ?? true,
    );
  }
}


