import 'package:flutter/material.dart';
import '../theme/color_schemes.dart';
import 'network/network_exceptions.dart';
import '../models/network/network_error_model.dart';

class ErrorHandler {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: AppColorSchemes.white,
            fontFamily: 'IRANSansXFaNum',
          ),
        ),
        backgroundColor: AppColorSchemes.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// نمایش خطای شبکه
  static void showNetworkError(BuildContext context, NetworkErrorModel error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.message,
              style: const TextStyle(
                fontFamily: 'IRANSansXFaNum',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (error.details != null) ...[
              const SizedBox(height: 4),
              Text(
                error.details!,
                style: const TextStyle(
                  fontFamily: 'IRANSansXFaNum',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'تلاش مجدد',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// نمایش خطای شبکه از Exception
  static void showNetworkException(
    BuildContext context,
    NetworkException exception,
  ) {
    final error = exception.toModel();
    showNetworkError(context, error);
  }

  /// نمایش خطای اتصال
  static void showConnectivityException(
    BuildContext context,
    ConnectivityException exception,
  ) {
    final error = exception.toModel();
    showNetworkError(context, error);
  }

  /// دریافت رنگ بر اساس نوع خطا
  static Color _getErrorColor(NetworkErrorType type) {
    switch (type) {
      case NetworkErrorType.noConnection:
        return AppColorSchemes.error;
      case NetworkErrorType.timeout:
        return AppColorSchemes.warning;
      case NetworkErrorType.serverError:
        return AppColorSchemes.error;
      case NetworkErrorType.unknown:
        return AppColorSchemes.primaryGrey;
    }
  }

  /// نمایش دیالوگ خطا
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'IRANSansXFaNum',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'تأیید',
              style: TextStyle(
                fontFamily: 'IRANSansXFaNum',
                color: AppColorSchemes.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// نمایش دیالوگ خطای شبکه با دکمه تلاش مجدد
  static void showNetworkErrorDialog(
    BuildContext context,
    NetworkErrorModel error,
    VoidCallback? onRetry,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: AppColorSchemes.error),
            const SizedBox(width: 8),
            Text(
              'خطای شبکه',
              style: const TextStyle(
                fontFamily: 'IRANSansXFaNum',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.message,
              style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            if (error.details != null) ...[
              const SizedBox(height: 8),
              Text(
                error.details!,
                style: const TextStyle(
                  fontFamily: 'IRANSansXFaNum',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'بستن',
              style: TextStyle(
                fontFamily: 'IRANSansXFaNum',
                color: AppColorSchemes.textSecondary,
              ),
            ),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColorSchemes.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'تلاش مجدد',
                style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
            ),
        ],
      ),
    );
  }
}
