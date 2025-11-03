import 'package:hive/hive.dart';
import '../config/config_service.dart';
import '../../utils/logger.dart';

/// سرویس مدیریت Pull-to-Refresh
class RefreshManager {
  static RefreshManager? _instance;
  static RefreshManager get instance => _instance ??= RefreshManager._();

  RefreshManager._();

  static const String _refreshBoxName = 'refresh_data';
  static const String _refreshCountKey = 'refresh_count';

  Box? _refreshBox;

  /// مقداردهی اولیه
  Future<void> init() async {
    try {
      _refreshBox = await Hive.openBox(_refreshBoxName);
      Logger.info('✅ RefreshManager: Initialized');
    } catch (e) {
      Logger.error('❌ RefreshManager: Error initializing', e);
    }
  }

  /// دریافت تعداد رفرش‌های انجام شده
  int get refreshCount {
    return _refreshBox?.get(_refreshCountKey, defaultValue: 0) as int? ?? 0;
  }

  /// افزایش تعداد رفرش
  Future<void> incrementRefreshCount() async {
    final currentCount = refreshCount;
    await _refreshBox?.put(_refreshCountKey, currentCount + 1);
    Logger.info('🔄 RefreshManager: Refresh count: ${currentCount + 1}');
  }

  /// بررسی اینکه آیا رفرش مجاز است
  bool canRefresh() {
    final config = ConfigService.instance;

    // اگر Pull-to-Refresh غیرفعال است
    if (!config.isPullToRefreshEnabled) {
      Logger.info('⛔ RefreshManager: Pull-to-Refresh is disabled');
      return false;
    }

    // بررسی تعداد رفرش‌ها
    final currentCount = refreshCount;
    final maxCount = config.maxRefreshCount;

    if (currentCount >= maxCount) {
      Logger.info(
        '⛔ RefreshManager: Refresh limit reached ($currentCount/$maxCount)',
      );
      return false;
    }

    Logger.info('✅ RefreshManager: Refresh allowed ($currentCount/$maxCount)');
    return true;
  }

  /// ریست کردن شمارنده رفرش (برای تست یا ریست دوره‌ای)
  Future<void> resetRefreshCount() async {
    await _refreshBox?.put(_refreshCountKey, 0);
    Logger.info('🔄 RefreshManager: Refresh count reset');
  }

  /// دریافت تعداد رفرش‌های باقی‌مانده
  int get remainingRefreshes {
    final maxCount = ConfigService.instance.maxRefreshCount;
    final current = refreshCount;
    return (maxCount - current).clamp(0, maxCount);
  }
}
