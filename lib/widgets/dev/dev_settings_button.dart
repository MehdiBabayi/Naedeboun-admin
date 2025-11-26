import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/core/app_state_manager.dart';
import '../../services/config/config_service.dart';
import '../../services/navigation/app_navigator.dart';
import '../../models/auth/registration_stage.dart';
import '../../services/session_service.dart';
import '../../services/cache/hive_cache_service.dart';
import '../../services/cache/cache_manager.dart';
// Mini-Request و کش Hive در نسخه جدید پنل ادمین استفاده نمی‌شوند
import '../../utils/logger.dart';

/// دکمه تنظیمات موقت برای حالت توسعه
class DevSettingsButton extends StatelessWidget {
  const DevSettingsButton({super.key});

  // Flag برای جلوگیری از باز شدن چند Dialog پشت سر هم
  static bool _isDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
    Logger.debug('🔧 DevSettingsButton: Building for route: $currentRoute');

    // فقط در حالت توسعه نمایش داده می‌شود
    if (!ConfigService.instance.isDevMode) {
      Logger.debug('🔧 DevSettingsButton: DevMode is false, hiding button');
      return const SizedBox.shrink();
    }

    Logger.debug('🔧 DevSettingsButton: DevMode is true, showing button');
    return Positioned(
      top: 50, // فاصله از بالا
      right: 16, // فاصله از راست
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () => _showDevSettings(context),
        child: const Icon(Icons.settings),
      ),
    );
  }

  /// نمایش Dialog تنظیمات موقت
  void _showDevSettings(BuildContext context) {
    // اگر Dialog قبلاً باز است، دوباره باز نکن
    if (_isDialogOpen) {
      Logger.debug('🔧 DevSettingsButton: Dialog already open, ignoring request');
      return;
    }

    final navigator = AppNavigator.navigatorKey.currentState;
    final dialogContext = navigator?.overlay?.context ?? context;
    
    // علامت‌گذاری که Dialog باز است
    _isDialogOpen = true;
    
    showDialog(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (context) => const DevSettingsDialog(),
    ).then((_) {
      // وقتی Dialog بسته می‌شود، flag را reset کن
      _isDialogOpen = false;
      Logger.debug('🔧 DevSettingsButton: Dialog closed, flag reset');
    });
  }
}

/// Dialog تنظیمات موقت
class DevSettingsDialog extends StatefulWidget {
  const DevSettingsDialog({super.key});

  @override
  State<DevSettingsDialog> createState() => _DevSettingsDialogState();
}

class _DevSettingsDialogState extends State<DevSettingsDialog> {
  ThemeMode _currentThemeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _currentThemeMode = ConfigService.instance.themeMode;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text(
          '🔧 تنظیمات توسعه',
          style: TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.75,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // بخش تم
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎨 تم برنامه',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ThemeMode.values.map((mode) {
                          final isSelected = _currentThemeMode == mode;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentThemeMode = mode;
                                });
                                _updateTheme(mode);
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline
                                              .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  mode == ThemeMode.light
                                      ? '☀️ روشن'
                                      : mode == ThemeMode.dark
                                      ? '🌙 تاریک'
                                      : '⚙️ سیستم',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // بخش وضعیت‌ها
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 وضعیت‌ها',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showStatusDialog(context),
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('مشاهده وضعیت‌ها'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // (Logout به انتهای پنل منتقل می‌شود)

                // بخش نمایش داده‌های Hive
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🗄️ داده‌های Hive',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showHiveDataDialog(context),
                          icon: const Icon(Icons.storage, size: 16),
                          label: const Text('مشاهده تمام داده‌های Cache'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // بخش Mini-Request Debug
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mini-Request Debug',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _runFullManualDownload(context),
                          icon: const Icon(Icons.system_update_alt, size: 16),
                          label: const Text('بروزرسانی Mini‑Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // دکمه جدید: دانلود دستی همهٔ دیتاها و ذخیره در Hive
                      // دکمه دانلود کامل حذف شد؛ دکمه بالا ادغام شده است
                      const SizedBox(height: 8),
                      // دکمه جدید: پاک کردن دیتای Mini-Request برای پایه/رشته فعلی
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Mini-Request حذف شده است
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'ℹ️ Mini‑Request حذف شده است',
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_sweep, size: 16),
                          label: const Text('پاک کردن دیتای Mini‑Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // بخش گزینه‌های بیشتر حذف شد

                // بخش Logout (انتهای پنل)
                if (_shouldShowLogout(context)) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🚪 خروج',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleLogout(context),
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('خروج از حساب'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onError,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'بستن',
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
          ),
        ],
      ),
    );
  }

  /// به‌روزرسانی فوری تم
  void _updateTheme(ThemeMode mode) {
    Logger.info('🎨 DevSettingsButton: Updating theme to $mode');

    // به‌روزرسانی در AppStateManager (این کار اصلی است)
    final appState = context.read<AppStateManager>();
    appState.updateThemeMode(mode);

    Logger.info('🎨 DevSettingsButton: Theme updated successfully');
  }

  /// بررسی اینکه آیا باید دکمه Logout نمایش داده شود
  bool _shouldShowLogout(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // اگر کاربر لاگین نیست، گزینه خروج نمایش داده نشود
    final isAuthenticated = context.read<AppStateManager>().isUserAuthenticated;
    if (!isAuthenticated) return false;

    // صفحاتی که Logout نباید نمایش داده شود (صرف‌نظر از وضعیت)
    const noLogoutRoutes = [
      '/auth',
      '/verify-otp',
      '/onboarding/step1',
      '/onboarding/step2',
      '/onboarding/success',
    ];

    return !noLogoutRoutes.contains(currentRoute);
  }

  /// مدیریت Logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      final appState = context.read<AppStateManager>();
      await appState.authService.signOut();

      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    } catch (e) {
      Logger.error('❌ DevSettingsButton: Logout error', e);
    }
  }

  /// دانلود دستی همهٔ دیتاها و ذخیره در Hive (در نسخهٔ جدید ادمین غیرفعال شده)
  Future<void> _runFullManualDownload(BuildContext context) async {
    // در پنل ادمین جدید Mini‑Request و ذخیره در Hive کاملاً حذف شده است.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ℹ️ Mini‑Request در پنل ادمین غیرفعال شده است و دانلود سراسری انجام نمی‌شود',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }


  /// نمایش Dialog وضعیت‌ها
  void _showStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => const StatusDialog(),
    );
  }

  /// نمایش Dialog داده‌های Hive
  void _showHiveDataDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => const HiveDataDialog(),
    );
  }
}

/// Dialog نمایش وضعیت‌ها
class StatusDialog extends StatelessWidget {
  const StatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📊 وضعیت‌های سیستم',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status List
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: _buildStatusItems(context)),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // Clear button inside content
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.clear_all, color: Colors.red),
                label: const Text('پاک کردن همه تنظیمات'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  clearAllHiveData(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusItems(BuildContext context) {
    final appState = context.read<AppStateManager>();
    final authService = appState.authService;

    return [
      _buildStatusItem(
        context,
        '🔐 احراز هویت',
        authService.currentUser != null ? 'لاگین شده' : 'لاگین نشده',
        authService.currentUser != null ? Colors.green : Colors.orange,
      ),
      _buildStatusItem(
        context,
        '👤 پروفایل کاربر',
        authService.currentUser != null
            ? (authService.currentProfile?.fullName.isNotEmpty == true
                  ? authService.currentProfile!.fullName
                  : 'تکمیل نشده')
            : 'لاگین نشده',
        authService.currentUser != null
            ? (authService.currentProfile?.fullName.isNotEmpty == true
                  ? Colors.green
                  : Colors.orange)
            : Colors.grey,
      ),
      _buildStatusItem(
        context,
        '📱 شماره تلفن',
        authService.currentUser?.phoneNumber ?? 'لاگین نشده',
        authService.currentUser != null ? Colors.blue : Colors.grey,
      ),
      _buildStatusItem(
        context,
        '🎯 مرحله ثبت‌نام',
        authService.currentUser != null
            ? _getRegistrationStageText(authService.currentRegistrationStage)
            : 'لاگین نشده',
        authService.currentUser != null
            ? _getRegistrationStageColor(authService.currentRegistrationStage)
            : Colors.grey,
      ),
      _buildStatusItem(
        context,
        '🌐 وضعیت شبکه',
        appState.isNetworkConnected ? 'متصل' : 'قطع',
        appState.isNetworkConnected ? Colors.green : Colors.red,
      ),
      _buildStatusItem(
        context,
        '🎨 تم فعلی',
        _getThemeModeText(ConfigService.instance.themeMode),
        Colors.purple,
      ),
      _buildStatusItem(
        context,
        '🔧 حالت توسعه',
        ConfigService.instance.isDevMode ? 'فعال' : 'غیرفعال',
        ConfigService.instance.isDevMode ? Colors.orange : Colors.grey,
      ),
      _buildStatusItem(
        context,
        '📊 وضعیت برنامه',
        appState.isInitialized ? 'آماده' : 'در حال بارگذاری',
        appState.isInitialized ? Colors.green : Colors.orange,
      ),
      _buildStatusItem(
        context,
        '🕒 آخرین به‌روزرسانی',
        DateTime.now().toString().substring(0, 19),
        Colors.grey,
      ),
      // Hive Session Status
      _buildStatusItem(
        context,
        '💾 وضعیت Session',
        SessionService.instance.isSessionExpired() ? 'منقضی شده' : 'معتبر',
        SessionService.instance.isSessionExpired() ? Colors.red : Colors.green,
      ),
      // Last Selected Subject
      _buildHiveStatusItem(
        context,
        '📚 آخرین درس انتخاب شده',
        SessionService.instance.getLastSelectedSubject(),
      ),
      // Last Selected Track
      _buildHiveStatusItem(
        context,
        '🎯 آخرین Track انتخاب شده',
        SessionService.instance.getLastSelectedTrackId(),
      ),
      // User Profile in Hive
      _buildHiveStatusItem(
        context,
        '👤 پروفایل در Hive',
        SessionService.instance.getUserProfile(),
      ),

      // ==================== NEW HIVE PREFERENCES ====================

      // User Theme Preferences
      _buildHiveStatusItem(
        context,
        '🎨 تنظیمات تم کاربر',
        SessionService.instance.getUserPreferences(),
      ),

      // Filter Preferences
      _buildHiveStatusItem(
        context,
        '🔍 فیلترهای ذخیره شده',
        SessionService.instance.getFilterPreferences(),
      ),

      // PDF Preferences
      _buildHiveStatusItem(
        context,
        '📄 تنظیمات PDF',
        SessionService.instance.getPdfPreferences(),
      ),

      // View State
      _buildHiveStatusItem(
        context,
        '📱 وضعیت مشاهده',
        SessionService.instance.getViewState(),
      ),

      // ==================== CACHING PERFORMANCE STATS ====================

      // Cache Performance Stats
      _buildCacheStatusItem(
        context,
        '⚡ Memory Cache Stats',
        _getMemoryCacheStats(),
      ),

      // Hive Cache Performance Stats
      _buildCacheStatusItem(
        context,
        '🔒 Hive Cache Stats',
        _getHiveCacheStats(),
      ),
    ];
  }

  /// Get Memory Cache Statistics
  String _getMemoryCacheStats() {
    final stats = AppCacheManager.getCacheStats();
    final totalItems = stats['total_items'] as int;
    final oldestAge = stats['oldest_item_age_minutes'] as int;

    return '$totalItems آیتم در رم (قدیمی‌ترین: $oldestAge دقیقه)';
  }

  /// Get Hive Cache Statistics
  String _getHiveCacheStats() {
    final stats = HiveCacheService.getCacheStats();
    return stats['cache_amount'] as String;
  }

  /// Build cache status item instead of Hive
  Widget _buildCacheStatusItem(
    BuildContext context,
    String title,
    String value,
  ) {
    Logger.debug('🔧 [CACHE DEBUG] TITLE: $title: VALUE = $value');

    Color color;
    if (value.contains('0 آیتم') || value.contains('آیتم')) {
      color = Colors.blue; // Good - has cache
    } else {
      color = Colors.grey; // Unknown/empty
    }

    return _buildStatusItem(context, title, value, color);
  }

  Widget _buildStatusItem(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRegistrationStageText(RegistrationStage stage) {
    switch (stage) {
      case RegistrationStage.step1:
        return 'مرحله ۱ - اطلاعات پایه';
      case RegistrationStage.step2:
        return 'مرحله ۲ - تکمیل اطلاعات';
      case RegistrationStage.completed:
        return 'تکمیل شده';
    }
  }

  Color _getRegistrationStageColor(RegistrationStage stage) {
    switch (stage) {
      case RegistrationStage.step1:
        return Colors.orange;
      case RegistrationStage.step2:
        return Colors.blue;
      case RegistrationStage.completed:
        return Colors.green;
    }
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'روشن';
      case ThemeMode.dark:
        return 'تاریک';
      case ThemeMode.system:
        return 'سیستم';
    }
  }

  Widget _buildHiveStatusItem(
    BuildContext context,
    String title,
    dynamic data,
  ) {
    Logger.debug(
      '🔧 [HIVE DEBUG] $title: Raw data = $data (type: ${data.runtimeType})',
    );

    String value;
    Color color;

    if (data == null) {
      value = 'خالی';
      color = Colors.grey;
    } else if (data is Map<String, dynamic>) {
      if (data.containsKey('name')) {
        // Subject data
        value = data['name'] ?? 'نامشخص';
        color = Colors.blue;
      } else if (data.containsKey('firstName')) {
        // User profile data
        final firstName = data['first_name'] ?? '';
        final lastName = data['last_name'] ?? '';
        value = '$firstName $lastName'.trim().isEmpty
            ? 'تکمیل نشده'
            : '$firstName $lastName'.trim();
        color = Colors.green;
      } else {
        // Show key count and sample keys for maps
        final keyCount = data.length;
        final sampleKeys = data.keys.take(3).join(', ');
        value = keyCount > 0
            ? '$keyCount آیتم ($sampleKeys${keyCount > 3 ? '...' : ''})'
            : 'خالی';
        color = keyCount > 0 ? Colors.blue : Colors.grey;
      }
    } else if (data is int) {
      value = 'Track ID: $data';
      color = Colors.purple;
    } else {
      value = data.toString();
      color = Colors.blue;
    }

    return _buildStatusItem(context, title, value, color);
  }

  /// Clear all Hive preferences data
  Future<void> clearAllHiveData(BuildContext context) async {
    try {
      await SessionService.instance.clearUserPreferences();

      // Check if widget is still mounted before using context
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ همه تنظیمات Hive پاک شد!',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the dialog to show updated status
      Navigator.of(context).pop(); // Close current dialog

      // Show success message instead of reopening dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ همه تنظیمات پاک شد - برای مشاهده تغییرات دوباره باز کنید',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ خطا در پاک کردن تنظیمات: $e',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Dialog نمایش داده‌های Hive
class HiveDataDialog extends StatefulWidget {
  const HiveDataDialog({super.key});

  @override
  State<HiveDataDialog> createState() => _HiveDataDialogState();
}

class _HiveDataDialogState extends State<HiveDataDialog> {
  Map<String, dynamic> _hiveData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHiveData();
  }

  /// بارگذاری تمام داده‌های Hive
  Future<void> _loadHiveData() async {
    try {
      setState(() => _isLoading = true);

      final Map<String, dynamic> allData = {};

      // لیست تمام box های Hive
      final boxNames = [
        'user_profile',
        'session',
        'settings',
        'content_cache',
        'image_cache',
        'banner_cache',
        'pdf_cache',
        'teacher_cache',
        'mini_request_cache',
        'network_cache',
        'app_cache',
      ];

      // اضافه کردن Mini-Request box فعلی کاربر (grade_{grade}_{track}_content)
      try {
        final appState = context.read<AppStateManager>();
        final profile = appState.authService.currentProfile;
        final int grade = profile?.grade ?? 7;
        final int? trackId = null; // پایه‌های 1-9 رشته ندارند
        final currentBox = 'grade_${grade}_${trackId ?? "null"}_content';
        if (!boxNames.contains(currentBox)) {
          boxNames.add(currentBox);
        }
      } catch (e) {
        Logger.error('⚠️ [HIVE DEBUG] Error adding current Mini-Request box', e);
      }

      for (final boxName in boxNames) {
        try {
          final box = await Hive.openBox(boxName);
          final Map<String, dynamic> boxData = {};

          for (final key in box.keys) {
            final value = box.get(key);
            boxData[key.toString()] = value;
          }

          if (boxData.isNotEmpty) {
            allData[boxName] = boxData;
          }
        } catch (e) {
          Logger.error('⚠️ [HIVE DEBUG] Error loading box $boxName', e);
        }
      }

      setState(() {
        _hiveData = allData;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('❌ [HIVE DEBUG] Error loading Hive data', e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '🗄️ داده‌های Hive Cache',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _loadHiveData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'تازه‌سازی',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('در حال بارگذاری داده‌ها...'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: _hiveData.isEmpty
                    ? const Center(child: Text('هیچ داده‌ای در Hive یافت نشد'))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildHiveDataWidgets(),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  /// ساخت ویجت‌های نمایش داده‌های Hive
  List<Widget> _buildHiveDataWidgets() {
    final List<Widget> widgets = [];

    _hiveData.forEach((boxName, boxData) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getBoxIcon(boxName),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getBoxTitle(boxName),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${boxData.length} آیتم',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...boxData.entries.map(
                (entry) => _buildDataItem(entry.key, entry.value),
              ),
            ],
          ),
        ),
      );
    });

    return widgets;
  }

  /// ساخت آیتم داده
  Widget _buildDataItem(String key, dynamic value) {
    final String displayValue = _formatValue(value);
    final bool isLongValue = displayValue.length > 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔑 $key',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            maxLines: isLongValue ? 3 : null,
            overflow: isLongValue ? TextOverflow.ellipsis : null,
          ),
        ],
      ),
    );
  }

  /// فرمت کردن مقدار
  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) {
      if (value.length > 200) {
        return '${value.substring(0, 200)}... (${value.length} کاراکتر)';
      }
      return value;
    }
    if (value is Map || value is List) {
      return value.toString().length > 200
          ? '${value.toString().substring(0, 200)}... (${value.toString().length} کاراکتر)'
          : value.toString();
    }
    return value.toString();
  }

  /// آیکون box
  IconData _getBoxIcon(String boxName) {
    switch (boxName) {
      case 'user_profile':
        return Icons.person;
      case 'session':
        return Icons.login;
      case 'settings':
        return Icons.settings;
      case 'content_cache':
        return Icons.folder;
      case 'image_cache':
        return Icons.image;
      case 'banner_cache':
        return Icons.campaign;
      case 'pdf_cache':
        return Icons.picture_as_pdf;
      case 'teacher_cache':
        return Icons.school;
      case 'mini_request_cache':
        return Icons.sync;
      case 'network_cache':
        return Icons.wifi;
      case 'app_cache':
        return Icons.apps;
      default:
        return Icons.storage;
    }
  }

  /// عنوان box
  String _getBoxTitle(String boxName) {
    switch (boxName) {
      case 'user_profile':
        return '👤 پروفایل کاربر';
      case 'session':
        return '🔐 نشست';
      case 'settings':
        return '⚙️ تنظیمات';
      case 'content_cache':
        return '📁 محتوای کش شده';
      case 'image_cache':
        return '🖼️ تصاویر کش شده';
      case 'banner_cache':
        return '📢 بنرها';
      case 'pdf_cache':
        return '📄 فایل‌های PDF';
      case 'teacher_cache':
        return '👨‍🏫 اساتید';
      case 'mini_request_cache':
        return '🔄 Mini-Request';
      case 'network_cache':
        return '🌐 شبکه';
      case 'app_cache':
        return '📱 اپلیکیشن';
      default:
        return '🗄️ $boxName';
    }
  }
}
