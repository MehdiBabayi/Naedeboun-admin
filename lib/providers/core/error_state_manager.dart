import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/network/network_error_model.dart';
import '../../exceptions/network/network_exceptions.dart';

/// State Manager مخصوص مدیریت خطاها
class ErrorStateManager extends ChangeNotifier {
  // Singleton pattern
  static final ErrorStateManager _instance = ErrorStateManager._internal();
  factory ErrorStateManager() => _instance;
  ErrorStateManager._internal();

  // State variables
  final List<NetworkErrorModel> _errorHistory = [];
  NetworkErrorModel? _currentError;
  bool _isErrorVisible = false;
  String? _lastErrorMessage;

  // Getters
  List<NetworkErrorModel> get errorHistory => List.unmodifiable(_errorHistory);
  NetworkErrorModel? get currentError => _currentError;
  bool get isErrorVisible => _isErrorVisible;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get hasError => _currentError != null;

  /// اضافه کردن خطای جدید
  void addError(NetworkErrorModel error) {
    _currentError = error;
    _errorHistory.add(error);
    _isErrorVisible = true;
    _lastErrorMessage = error.message;
    notifyListeners();
  }

  /// اضافه کردن خطای شبکه
  void addNetworkError(NetworkErrorType type, {String? message, String? details}) {
    final error = NetworkErrorModel(
      type: type,
      message: message ?? _getDefaultMessage(type),
      details: details ?? _getDefaultDetails(type),
      timestamp: DateTime.now(),
    );
    addError(error);
  }

  /// اضافه کردن خطای شبکه از Exception
  void addNetworkException(NetworkException exception) {
    final error = exception.toModel();
    addError(error);
  }

  /// پاک کردن خطای فعلی
  void clearCurrentError() {
    _currentError = null;
    _isErrorVisible = false;
    notifyListeners();
  }

  /// پاک کردن تمام خطاها
  void clearAllErrors() {
    _currentError = null;
    _errorHistory.clear();
    _isErrorVisible = false;
    _lastErrorMessage = null;
    notifyListeners();
  }

  /// مخفی کردن خطا
  void hideError() {
    _isErrorVisible = false;
    notifyListeners();
  }

  /// نمایش خطا
  void showError() {
    if (_currentError != null) {
      _isErrorVisible = true;
      notifyListeners();
    }
  }

  /// دریافت پیام پیش‌فرض بر اساس نوع خطا
  String _getDefaultMessage(NetworkErrorType type) {
    switch (type) {
      case NetworkErrorType.noConnection:
        return 'اتصال اینترنت شما قطع است';
      case NetworkErrorType.timeout:
        return 'زمان اتصال به پایان رسید';
      case NetworkErrorType.serverError:
        return 'خطای سرور';
      case NetworkErrorType.unknown:
        return 'خطای نامشخصی رخ داد';
    }
  }

  /// دریافت جزئیات پیش‌فرض بر اساس نوع خطا
  String _getDefaultDetails(NetworkErrorType type) {
    switch (type) {
      case NetworkErrorType.noConnection:
        return 'لطفاً اتصال اینترنت خود را بررسی کنید';
      case NetworkErrorType.timeout:
        return 'لطفاً دوباره تلاش کنید';
      case NetworkErrorType.serverError:
        return 'لطفاً بعداً تلاش کنید';
      case NetworkErrorType.unknown:
        return 'لطفاً دوباره تلاش کنید';
    }
  }

  /// دریافت آمار خطاها
  Map<NetworkErrorType, int> getErrorStatistics() {
    final stats = <NetworkErrorType, int>{};
    for (final error in _errorHistory) {
      stats[error.type] = (stats[error.type] ?? 0) + 1;
    }
    return stats;
  }

  /// دریافت آخرین خطا از نوع خاص
  NetworkErrorModel? getLastErrorOfType(NetworkErrorType type) {
    for (int i = _errorHistory.length - 1; i >= 0; i--) {
      if (_errorHistory[i].type == type) {
        return _errorHistory[i];
      }
    }
    return null;
  }
}

/// Provider برای دسترسی آسان به ErrorStateManager
class ErrorStateProvider extends StatelessWidget {
  final Widget child;

  const ErrorStateProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ErrorStateManager>(
      create: (context) => ErrorStateManager(),
      child: child,
    );
  }
}

/// Extension برای دسترسی آسان به ErrorStateManager
extension ErrorStateExtension on BuildContext {
  ErrorStateManager get errorState => Provider.of<ErrorStateManager>(this, listen: false);
  ErrorStateManager get errorStateWatch => Provider.of<ErrorStateManager>(this);
}
