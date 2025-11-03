/// مراحل ثبت‌نام کاربر
enum RegistrationStage {
  /// مرحله اول: انتخاب جنسیت و پایه تحصیلی
  step1,
  
  /// مرحله دوم: تکمیل اطلاعات شخصی (نام، استان، شهر)
  step2,
  
  /// تکمیل شده: کاربر به صفحه اصلی می‌رود
  completed,
}

extension RegistrationStageExtension on RegistrationStage {
  /// تبدیل به string برای ذخیره در دیتابیس
  String get value {
    switch (this) {
      case RegistrationStage.step1:
        return 'step1';
      case RegistrationStage.step2:
        return 'step2';
      case RegistrationStage.completed:
        return 'completed';
    }
  }

  /// تبدیل از string دیتابیس به enum
  static RegistrationStage fromString(String value) {
    switch (value) {
      case 'step1':
        return RegistrationStage.step1;
      case 'step2':
        return RegistrationStage.step2;
      case 'completed':
        return RegistrationStage.completed;
      default:
        return RegistrationStage.step1;
    }
  }

  /// آیا مرحله تکمیل شده است؟
  bool get isCompleted => this == RegistrationStage.completed;

  /// آیا در مرحله اول است؟
  bool get isStep1 => this == RegistrationStage.step1;

  /// آیا در مرحله دوم است؟
  bool get isStep2 => this == RegistrationStage.step2;

  /// مرحله بعدی
  RegistrationStage get nextStage {
    switch (this) {
      case RegistrationStage.step1:
        return RegistrationStage.step2;
      case RegistrationStage.step2:
        return RegistrationStage.completed;
      case RegistrationStage.completed:
        return RegistrationStage.completed;
    }
  }
}
