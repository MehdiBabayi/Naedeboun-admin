import '../../models/network/network_error_model.dart';

/// خطاهای مربوط به شبکه
class NetworkExceptions {
  NetworkExceptions._();

  /// خطای قطعی اتصال
  static NetworkException noConnection({String? message}) {
    return NetworkException(
      type: NetworkErrorType.noConnection,
      message: message ?? 'اتصال اینترنت شما قطع است',
      details: 'لطفاً اتصال اینترنت خود را بررسی کنید',
      timestamp: DateTime.now(),
    );
  }

  /// خطای timeout
  static NetworkException timeout({String? message}) {
    return NetworkException(
      type: NetworkErrorType.timeout,
      message: message ?? 'زمان اتصال به پایان رسید',
      details: 'لطفاً دوباره تلاش کنید',
      timestamp: DateTime.now(),
    );
  }

  /// خطای سرور
  static NetworkException serverError({String? message}) {
    return NetworkException(
      type: NetworkErrorType.serverError,
      message: message ?? 'خطای سرور',
      details: 'لطفاً بعداً تلاش کنید',
      timestamp: DateTime.now(),
    );
  }

  /// خطای نامشخص
  static NetworkException unknown({String? message}) {
    return NetworkException(
      type: NetworkErrorType.unknown,
      message: message ?? 'خطای نامشخصی رخ داد',
      details: 'لطفاً دوباره تلاش کنید',
      timestamp: DateTime.now(),
    );
  }
}

/// کلاس اصلی خطای شبکه
class NetworkException implements Exception {
  final NetworkErrorType type;
  final String message;
  final String? details;
  final DateTime timestamp;

  const NetworkException({
    required this.type,
    required this.message,
    this.details,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NetworkException(type: $type, message: $message, timestamp: $timestamp)';
  }

  /// تبدیل به NetworkErrorModel
  NetworkErrorModel toModel({String? previousRoute}) {
    return NetworkErrorModel(
      type: type,
      message: message,
      details: details,
      timestamp: timestamp,
      previousRoute: previousRoute,
    );
  }
}

/// خطاهای مربوط به اتصال
class ConnectivityExceptions {
  ConnectivityExceptions._();

  /// خطای عدم دسترسی به شبکه
  static ConnectivityException noNetworkAccess() {
    return ConnectivityException(
      message: 'دسترسی به شبکه امکان‌پذیر نیست',
      details: 'لطفاً تنظیمات شبکه خود را بررسی کنید',
      timestamp: DateTime.now(),
    );
  }

  /// خطای محدودیت شبکه
  static ConnectivityException networkRestricted() {
    return ConnectivityException(
      message: 'دسترسی به شبکه محدود است',
      details: 'لطفاً با مدیر سیستم تماس بگیرید',
      timestamp: DateTime.now(),
    );
  }

  /// خطای تنظیمات شبکه
  static ConnectivityException networkConfigurationError() {
    return ConnectivityException(
      message: 'خطا در تنظیمات شبکه',
      details: 'لطفاً تنظیمات شبکه خود را بررسی کنید',
      timestamp: DateTime.now(),
    );
  }
}

/// کلاس اصلی خطای اتصال
class ConnectivityException implements Exception {
  final String message;
  final String? details;
  final DateTime timestamp;

  const ConnectivityException({
    required this.message,
    this.details,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ConnectivityException(message: $message, timestamp: $timestamp)';
  }

  /// تبدیل به NetworkErrorModel
  NetworkErrorModel toModel({String? previousRoute}) {
    return NetworkErrorModel(
      type: NetworkErrorType.noConnection,
      message: message,
      details: details,
      timestamp: timestamp,
      previousRoute: previousRoute,
    );
  }
}
