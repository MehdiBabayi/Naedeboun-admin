import 'package:nardeboun/models/auth/registration_stage.dart';

/// مدل پروفایل کاربر با تمام فیلدهای مورد نیاز
class UserProfile {
  final String id;
  final String phoneNumber;
  final String userRole;
  final DateTime createdAt;

  // فیلدهای مرحله ثبت‌نام
  final RegistrationStage registrationStage;
  final DateTime lastStageUpdate;

  // فیلدهای مرحله اول
  final String? gender; // 'male' یا 'female'
  final int? grade; // 1 تا 9
  final DateTime? step1CompletedAt;

  // فیلدهای مرحله دوم
  final String? firstName;
  final String? lastName;
  final String? province;
  final String? city;
  final DateTime? step2CompletedAt;

  // آواتار (فعلاً ثابت)
  final String? avatarUrl;
  final String? fieldOfStudy; // <-- اضافه شد

  const UserProfile({
    required this.id,
    required this.phoneNumber,
    required this.userRole,
    required this.createdAt,
    required this.registrationStage,
    required this.lastStageUpdate,
    this.gender,
    this.grade,
    this.step1CompletedAt,
    this.firstName,
    this.lastName,
    this.province,
    this.city,
    this.step2CompletedAt,
    this.avatarUrl,
    this.fieldOfStudy, // <-- اضافه شد
  });

  /// ایجاد از JSON (دیتابیس)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['user_id'] as String,
      phoneNumber: json['phone_number'] as String,
      userRole: json['user_role'] as String? ?? 'student',
      createdAt: DateTime.parse(json['created_at'] as String),
      registrationStage: RegistrationStageExtension.fromString(
        json['registration_stage'] as String? ?? 'step1',
      ),
      lastStageUpdate: DateTime.parse(
        json['last_stage_update'] as String? ?? json['created_at'] as String,
      ),
      gender: json['gender'] as String?,
      grade: json['grade'] != null ? (json['grade'] as num).toInt() : null,
      step1CompletedAt: json['step1_completed_at'] != null
          ? DateTime.parse(json['step1_completed_at'] as String)
          : null,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      province: json['province'] as String?,
      city: json['city'] as String?,
      step2CompletedAt: json['step2_completed_at'] != null
          ? DateTime.parse(json['step2_completed_at'] as String)
          : null,
      avatarUrl: json['avatar_url'] as String?,
      fieldOfStudy: json['field_of_study'] as String?, // <-- اضافه شد
    );
  }

  /// تبدیل به JSON (دیتابیس)
  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'phone_number': phoneNumber,
      'user_role': userRole,
      'created_at': createdAt.toIso8601String(),
      'registration_stage': registrationStage.value,
      'last_stage_update': lastStageUpdate.toIso8601String(),
      'gender': gender,
      'grade': grade,
      'step1_completed_at': step1CompletedAt?.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'province': province,
      'city': city,
      'step2_completed_at': step2CompletedAt?.toIso8601String(),
      'avatar_url': avatarUrl,
      'field_of_study': fieldOfStudy, // <-- اضافه شد
    };
  }

  /// کپی با تغییرات
  UserProfile copyWith({
    String? id,
    String? phoneNumber,
    String? userRole,
    DateTime? createdAt,
    RegistrationStage? registrationStage,
    DateTime? lastStageUpdate,
    String? gender,
    int? grade,
    DateTime? step1CompletedAt,
    String? firstName,
    String? lastName,
    String? province,
    String? city,
    DateTime? step2CompletedAt,
    String? avatarUrl,
    String? fieldOfStudy, // <-- اضافه شد
  }) {
    return UserProfile(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userRole: userRole ?? this.userRole,
      createdAt: createdAt ?? this.createdAt,
      registrationStage: registrationStage ?? this.registrationStage,
      lastStageUpdate: lastStageUpdate ?? this.lastStageUpdate,
      gender: gender ?? this.gender,
      grade: grade ?? this.grade,
      step1CompletedAt: step1CompletedAt ?? this.step1CompletedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      province: province ?? this.province,
      city: city ?? this.city,
      step2CompletedAt: step2CompletedAt ?? this.step2CompletedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy, // <-- اضافه شد
    );
  }

  /// آیا مرحله اول تکمیل شده؟
  bool get isStep1Completed => step1CompletedAt != null;

  /// آیا مرحله دوم تکمیل شده؟
  bool get isStep2Completed => step2CompletedAt != null;

  /// آیا پروفایل کامل است؟
  bool get isProfileComplete => registrationStage.isCompleted;

  /// نام کامل کاربر
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return phoneNumber;
  }

  /// آدرس کامل
  String get fullAddress {
    if (province != null && city != null) {
      return '$province، $city';
    } else if (province != null) {
      return province!;
    } else if (city != null) {
      return city!;
    }
    return '';
  }

  /// مسیر آواتار بر اساس جنسیت
  String get avatarPath {
    if (gender == 'male') {
      return 'assets/images/avatars/male.png';
    } else if (gender == 'female') {
      return 'assets/images/avatars/female.png';
    }
    return 'assets/images/avatars/male.png'; // پیش‌فرض
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, phone: $phoneNumber, stage: ${registrationStage.value}, name: $fullName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
