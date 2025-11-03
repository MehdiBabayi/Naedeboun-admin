// Moved user model under auth folder to have a single source of truth
class UserModel {
  final String id;
  final String phoneNumber;
  final String? firstName;
  final String? lastName;
  final DateTime createdAt;
  final String? userRole;
  final int? grade; // پایه تحصیلی
  final String? major; // رشته تحصیلی
  final String? province; // استان
  final String? city; // شهر

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.firstName,
    this.lastName,
    DateTime? createdAt,
    this.userRole,
    this.grade,
    this.major,
    this.province,
    this.city,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'],
      phoneNumber: json['phone_number'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      userRole: json['user_role'],
      grade: json['grade'] as int?, // <-- اصلاح شد: cast به int?
      major: json['major'],
      province: json['province'],
      city: json['city'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'created_at': createdAt.toIso8601String(),
      'user_role': userRole,
      'grade': grade,
      'major': major,
      'province': province,
      'city': city,
    };
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    int? grade, // <-- اصلاح شد: String? به int?
    String? major,
    String? province,
    String? city,
  }) {
    return UserModel(
      id: id,
      phoneNumber: phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      createdAt: createdAt,
      userRole: userRole,
      grade: grade ?? this.grade,
      major: major ?? this.major,
      province: province ?? this.province,
      city: city ?? this.city,
    );
  }
}
