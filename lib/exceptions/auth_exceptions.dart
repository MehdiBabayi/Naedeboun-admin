class AuthServiceException implements Exception {
  final String message;
  AuthServiceException(this.message);

  factory AuthServiceException.loginFailed() {
    return AuthServiceException('ورود ناموفق بود. لطفاً دوباره تلاش کنید.');
  }

  factory AuthServiceException.registrationFailed() {
    return AuthServiceException('بررسی ثبت‌نام با خطا مواجه شد.');
  }
  
  factory AuthServiceException.verificationCodeFailed() {
    return AuthServiceException('ارسال کد تایید ناموفق بود.');
  }

  factory AuthServiceException.invalidPhoneNumber() {
    return AuthServiceException('شماره موبایل وارد شده معتبر نیست. (مثال: 09123456789)');
  }
}
