/// مدل خطاهای شبکه
/// 
/// این فایل شامل مدل‌ها و enum های مربوط به خطاهای شبکه است
library;

/// انواع خطاهای شبکه
enum NetworkErrorType {
  /// عدم اتصال به اینترنت
  noConnection,
  
  /// تایم‌اوت اتصال
  timeout,
  
  /// خطای سرور
  serverError,
  
  /// خطای نامشخص
  unknown,
}

/// مدل خطای شبکه
class NetworkErrorModel {
  /// نوع خطا
  final NetworkErrorType type;
  
  /// پیام خطا
  final String message;
  
  /// جزئیات خطا
  final String? details;
  
  /// زمان وقوع خطا
  final DateTime timestamp;
  
  /// مسیر قبلی که خطا در آن رخ داده
  final String? previousRoute;
  
  /// کد خطا (اختیاری)
  final int? errorCode;

  const NetworkErrorModel({
    required this.type,
    required this.message,
    this.details,
    required this.timestamp,
    this.previousRoute,
    this.errorCode,
  });

  /// سازنده برای خطای عدم اتصال
  factory NetworkErrorModel.noConnection({String? previousRoute}) {
    return NetworkErrorModel(
      type: NetworkErrorType.noConnection,
      message: 'اتصال به اینترنت برقرار نیست',
      details: 'لطفاً اتصال اینترنت خود را بررسی کنید',
      timestamp: DateTime.now(),
      previousRoute: previousRoute,
    );
  }

  /// سازنده برای خطای تایم‌اوت
  factory NetworkErrorModel.timeout({String? previousRoute}) {
    return NetworkErrorModel(
      type: NetworkErrorType.timeout,
      message: 'زمان اتصال به پایان رسید',
      details: 'درخواست شما در زمان مقرر پاسخ دریافت نکرد',
      timestamp: DateTime.now(),
      previousRoute: previousRoute,
    );
  }

  /// سازنده برای خطای سرور
  factory NetworkErrorModel.serverError({
    String? message,
    String? details,
    int? errorCode,
    String? previousRoute,
  }) {
    return NetworkErrorModel(
      type: NetworkErrorType.serverError,
      message: message ?? 'خطا در سرور',
      details: details ?? 'مشکلی در سرور رخ داده است',
      timestamp: DateTime.now(),
      previousRoute: previousRoute,
      errorCode: errorCode,
    );
  }

  /// سازنده برای خطای نامشخص
  factory NetworkErrorModel.unknown({
    String? message,
    String? details,
    String? previousRoute,
  }) {
    return NetworkErrorModel(
      type: NetworkErrorType.unknown,
      message: message ?? 'خطای نامشخص',
      details: details ?? 'خطای غیرمنتظره‌ای رخ داده است',
      timestamp: DateTime.now(),
      previousRoute: previousRoute,
    );
  }

  /// تبدیل به Map
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'message': message,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'previousRoute': previousRoute,
      'errorCode': errorCode,
    };
  }

  /// ساخت از Map
  factory NetworkErrorModel.fromMap(Map<String, dynamic> map) {
    return NetworkErrorModel(
      type: NetworkErrorType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NetworkErrorType.unknown,
      ),
      message: map['message'] ?? '',
      details: map['details'],
      timestamp: DateTime.parse(map['timestamp']),
      previousRoute: map['previousRoute'],
      errorCode: map['errorCode'],
    );
  }

  /// کپی با تغییرات
  NetworkErrorModel copyWith({
    NetworkErrorType? type,
    String? message,
    String? details,
    DateTime? timestamp,
    String? previousRoute,
    int? errorCode,
  }) {
    return NetworkErrorModel(
      type: type ?? this.type,
      message: message ?? this.message,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
      previousRoute: previousRoute ?? this.previousRoute,
      errorCode: errorCode ?? this.errorCode,
    );
  }

  @override
  String toString() {
    return 'NetworkErrorModel(type: $type, message: $message, details: $details, timestamp: $timestamp, previousRoute: $previousRoute, errorCode: $errorCode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is NetworkErrorModel &&
      other.type == type &&
      other.message == message &&
      other.details == details &&
      other.timestamp == timestamp &&
      other.previousRoute == previousRoute &&
      other.errorCode == errorCode;
  }

  @override
  int get hashCode {
    return type.hashCode ^
      message.hashCode ^
      details.hashCode ^
      timestamp.hashCode ^
      previousRoute.hashCode ^
      errorCode.hashCode;
  }
}