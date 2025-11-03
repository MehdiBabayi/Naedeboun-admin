import 'package:flutter/material.dart';
import 'dev_settings_button.dart';
import '../../utils/logger.dart';

/// Wrapper برای اضافه کردن دکمه تنظیمات موقت به تمام صفحات
class DevSettingsWrapper extends StatelessWidget {
  final Widget child;

  const DevSettingsWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
    Logger.debug('🔧 DevSettingsWrapper: Building for route: $currentRoute');
    
    return Stack(
      children: [
        child,
        const DevSettingsButton(), // دکمه تنظیمات موقت
      ],
    );
  }
}
