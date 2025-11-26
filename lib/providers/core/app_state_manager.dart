import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_service.dart';
import '../../services/network/network_monitor_service.dart';
import '../../models/network/network_error_model.dart';
import '../../models/network/network_status_model.dart';
import '../../models/auth/registration_stage.dart';
import '../../services/config/config_service.dart';
import '../../services/session_service.dart';
// Mini-Request در پنل ادمین غیرفعال شده است
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';

/// State Manager مرکزی برای کل برنامه
/// این کلاس تمام state های برنامه را مدیریت می‌کند
class AppStateManager extends ChangeNotifier {
  // Singleton pattern
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  // Services
  late AuthService _authService;
  late NetworkMonitorService _networkService;

  // State variables
  bool _isInitialized = false;
  String? _currentRoute;
  final Map<String, dynamic> _globalState = {};
  NetworkStatusModel _networkStatus = NetworkStatusModel(
    status: NetworkStatus.unknown,
    lastChecked: DateTime.now(),
  );
  NetworkErrorModel? _lastNetworkError;
  ThemeMode _currentThemeMode = ThemeMode.light;

  // Getters
  bool get isInitialized => _isInitialized;
  String? get currentRoute => _currentRoute;
  AuthService get authService => _authService;
  NetworkMonitorService get networkService {
    if (!_isInitialized) {
      throw StateError(
        'AppStateManager not initialized. Call initialize() first.',
      );
    }
    return _networkService;
  }

  NetworkStatusModel get networkStatus => _networkStatus;
  NetworkErrorModel? get lastNetworkError => _lastNetworkError;
  ThemeMode get currentThemeMode => _currentThemeMode;

  /// وضعیت احراز هویت و ثبت‌نام کاربر
  bool get isUserAuthenticated {
    try {
      // استفاده از getter امن isAuthenticated از AuthService
      // که session واقعی را چک می‌کند نه فقط profile
      final isAuth = _authService.isAuthenticated;
      final hasProfile = _authService.currentProfile != null;

      Logger.debug('🔍 [AUTH DEBUG] isUserAuthenticated: $isAuth (session-based)');
      Logger.debug('🔍 [AUTH DEBUG] hasProfile: $hasProfile');

      // اگر session داریم، authenticated هستیم
      // اگر session نداریم ولی profile داریم، هنوز authenticated حساب می‌شویم
      // (برای حالت آفلاین یا بعد از minimize)
      return isAuth || hasProfile;
    } catch (e) {
      Logger.error('❌ AppStateManager: Error in isUserAuthenticated', e);
      return false;
    }
  }

  bool get isUserInOnboarding {
    try {
      return _authService.isInOnboarding;
    } catch (e) {
      Logger.error('❌ AppStateManager: Error in isUserInOnboarding', e);
      return false;
    }
  }

  RegistrationStage get currentRegistrationStage {
    try {
      return _authService.currentRegistrationStage;
    } catch (e) {
      Logger.error('❌ AppStateManager: Error in currentRegistrationStage', e);
      return RegistrationStage.step1;
    }
  }

  /// مسیر مناسب برای کاربر بر اساس وضعیت احراز هویت (بدون onboarding)
  String get appropriateRoute {
    try {
      Logger.debug('🔍 [ROUTE] Determining simple route...');
      if (!isUserAuthenticated) {
        Logger.debug('🔍 [ROUTE] Not authenticated -> /auth');
        return '/auth';
      }
      Logger.debug('🔍 [ROUTE] Authenticated -> /home');
      return '/home';
    } catch (e) {
      Logger.error('❌ AppStateManager: Error in appropriateRoute', e);
      return '/auth';
    }
  }

  /// مقداردهی اولیه
  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.info('⚠️ AppStateManager: Already initialized, skipping...');
      return;
    }

    Logger.info('🚀 [APP-STATE] ===== STARTING INITIALIZATION =====');

    // مقداردهی services
    _authService = AuthService(supaBase: Supabase.instance.client);
    _networkService = NetworkMonitorService();

    // بارگذاری تم از Hive (prioritize user preference over config)
    await _loadThemeFromHive();
    Logger.info('🎨 AppStateManager: Initial theme mode: $_currentThemeMode');

    Logger.info('🌐 AppStateManager: Starting network monitoring...');

    // شروع نظارت بر شبکه
    await _networkService.startMonitoring();

    // گوش دادن به تغییرات شبکه
    _networkService.statusStream.listen((status) {
      Logger.debug('🔄 AppStateManager: Received network status: ${status.status}');
      _networkStatus = status;
      Logger.debug('🌐 Network Status Changed: ${status.status}');
      Logger.debug('🌐 Network Details: ${status.toString()}');
      notifyListeners();
    });

    _isInitialized = true;
    Logger.info('✅ [APP-STATE] Initialization completed');


    Logger.info('✅ [APP-STATE] ===== INITIALIZATION COMPLETED =====');
    notifyListeners();
  }

  /// تنظیم مسیر فعلی
  void setCurrentRoute(String route) {
    _currentRoute = route;
    notifyListeners();
  }

  /// 🚀 Trigger Mini-Request manually (برای استفاده بعد از login)
  /// این متد برای سازگاری با کدهای قدیمی باقی مانده است اما هیچ کاری انجام نمی‌دهد.
  Future<void> triggerMiniRequestAfterLogin() async {
    // Mini-Request حذف شده است - این متد فقط برای سازگاری باقی مانده
  }

  /// تنظیم state سراسری
  void setGlobalState(String key, dynamic value) {
    _globalState[key] = value;
    notifyListeners();
  }

  /// دریافت state سراسری
  T? getGlobalState<T>(String key) {
    return _globalState[key] as T?;
  }

  /// پاک کردن state سراسری
  void clearGlobalState(String key) {
    _globalState.remove(key);
    notifyListeners();
  }

  /// پاک کردن تمام state ها
  void clearAllStates() {
    _globalState.clear();
    _currentRoute = null;
    notifyListeners();
  }

  /// بررسی وضعیت کلی برنامه
  bool get isAppReady => _isInitialized && isUserAuthenticated;

  /// بررسی وضعیت شبکه
  bool get isNetworkConnected {
    // اگر باید صفحه خطا نمایش داده بشه، نباید بگیم connected است
    if (_networkService.shouldShowErrorScreen) {
      Logger.debug(
        '🔍 AppStateManager: isNetworkConnected = false (shouldShowErrorScreen is true)',
      );
      return false;
    }

    // در ابتدا (unknown status) یا وقتی منتظر تایمر هستیم، به عنوان connected در نظر بگیر
    final connected =
        _networkStatus.isConnected ||
        _networkStatus.status == NetworkStatus.unknown;
    Logger.debug(
      '🔍 AppStateManager: isNetworkConnected = $connected (status: ${_networkStatus.status})',
    );
    return connected;
  }

  /// Load theme mode from Hive (user preference)
  Future<void> _loadThemeFromHive() async {
    try {
      final themeMode = SessionService.instance.getThemeMode();
      _currentThemeMode = _stringToThemeMode(themeMode);
      Logger.debug(
        '🔧 [HIVE THEME] Loaded theme from Hive: $themeMode → $_currentThemeMode',
      );
    } catch (e) {
      Logger.error('🔧 [HIVE THEME] Error loading theme from Hive, using config', e);
      _currentThemeMode = ConfigService.instance.themeMode;
    }
  }

  /// Convert string to ThemeMode
  ThemeMode _stringToThemeMode(String themeString) {
    switch (themeString.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  /// به‌روزرسانی تم (از UI و Hive)
  Future<void> updateThemeMode(ThemeMode mode) async {
    Logger.info(
      '🎨 AppStateManager: Updating theme mode from $_currentThemeMode to $mode',
    );
    _currentThemeMode = mode;

    // ذخیره در Hive (اولویت کاربر)
    await SessionService.instance.saveThemeMode(mode.name);

    // به‌روزرسانی در ConfigService (fallback)
    ConfigService.instance.updateConfig('themeMode', mode.name);

    // اطلاع‌رسانی به listeners
    notifyListeners();
    Logger.info('🎨 AppStateManager: Theme mode updated successfully');
  }

  @override
  void dispose() {
    _networkService.dispose();
    super.dispose();
  }
}

/// Provider برای دسترسی آسان به AppStateManager
class AppStateProvider extends StatelessWidget {
  final Widget child;

  const AppStateProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStateManager>(
      create: (context) => AppStateManager(),
      child: child,
    );
  }
}

/// Extension برای دسترسی آسان به AppStateManager
extension AppStateExtension on BuildContext {
  AppStateManager get appState =>
      Provider.of<AppStateManager>(this, listen: false);
  AppStateManager get appStateWatch => Provider.of<AppStateManager>(this);
}
