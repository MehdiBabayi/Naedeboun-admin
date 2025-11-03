import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'const/api_keys.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/onboarding_step1_screen.dart';
import 'screens/onboarding/onboarding_step2_screen.dart';
import 'screens/onboarding/onboarding_success_screen.dart';
import 'screens/subject_screen.dart';
import 'screens/chapter_screen.dart';
import 'screens/auth/verify_otp_screen.dart';
import 'screens/provincial_sample_screen.dart';
import 'screens/step_by_step_screen.dart';
import 'screens/video_player_screen.dart';
import 'providers/core/app_state_manager.dart';
import 'services/config/config_service.dart';
import 'widgets/network/network_wrapper.dart';
import 'services/session_service.dart';
import 'services/device/device_id_service.dart';
import 'services/refresh/refresh_manager.dart';
import 'models/content/subject.dart';
import 'services/navigation/app_navigator.dart';
import 'widgets/dev/dev_settings_button.dart';
import 'package:nardeboun/screens/force_update_screen.dart';
import 'package:nardeboun/services/settings_service.dart';
import 'theme/app_theme.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/content/book_cover_service.dart';
import 'services/mini_request/mini_request_logger.dart';
import 'services/image_cache/smart_image_cache_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'utils/logger.dart';

/// تنظیم orientation بر اساس کانفیگ
Future<void> _setOrientationFromConfig() async {
  // بررسی تنظیمات قفل پرتره
  if (ConfigService.instance.isPortraitLocked) {
    // قفل کردن جهت عمودی
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Logger.info('📱 Orientation: Portrait Lock فعال (کنترل از کانفیگ)');
  } else {
    // مجاز کردن همه جهت‌گیری‌ها
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    Logger.info('📱 Orientation: چرخش آزاد فعال (کنترل از کانفیگ)');
  }
}

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FlutterDownloader safely (only non-web; catch other platforms)
  if (!kIsWeb) {
    try {
      await FlutterDownloader.initialize(debug: false, ignoreSsl: true);
    } catch (e) {
      debugPrint('FlutterDownloader init skipped: $e');
    }
  }

  // Load configuration from JSON
  try {
    await ConfigService.instance.loadConfig();
  } catch (e, stackTrace) {
    // خطا را لاگ کن و بعد throw کن تا برنامه متوقف شود
    debugPrint('❌ [MAIN] CRITICAL: Failed to load config.json');
    debugPrint('❌ [MAIN] Error: $e');
    debugPrint('❌ [MAIN] Stack trace: $stackTrace');
    // خطا را دوباره throw کن تا برنامه متوقف شود
    rethrow;
  }

  // تنظیم orientation بر اساس کانفیگ
  await _setOrientationFromConfig();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize Settings Service
  await SettingsService.instance.init();

  // Initialize Session Service
  await SessionService.instance.init();

  // Initialize Device ID Service
  await DeviceIdService.instance.init();

  // Initialize Refresh Manager
  await RefreshManager.instance.init();

  // Initialize Supabase
  await Supabase.initialize(
    url: APIKeys.supaBaseURL,
    anonKey: APIKeys.supaBaseAnonKey,
  );

  // 📸 Initialize Smart Image Cache System BEFORE Mini-Request to ensure listeners are ready
  MiniRequestLogger.instance.init();
  SmartImageCacheService.instance.init();

  // ⚙️ تنظیم imageCache برای جلوگیری از buffer overflow
  imageCache.maximumSize = 1000; // محدود کردن تعداد تصاویر در cache
  imageCache.maximumSizeBytes =
      150 << 20; // 150 MB (برای جلوگیری از ImageReader_JNI error)

  // 📚 Initialize BookCoverService
  await BookCoverService.instance.init();

  // ⚠️ MiniRequestService.init() moved to AppStateManager to prevent double execution

  final versionCheckResult = await SettingsService.instance.checkVersion();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateManager(),
      child: AppWrapper(versionCheckResult: versionCheckResult),
    ),
  );
}

class AppWrapper extends StatefulWidget {
  final VersionCheckResult versionCheckResult;

  const AppWrapper({super.key, required this.versionCheckResult});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    // Trigger app state initialization in the background without blocking first frame
    // Store AppStateManager reference before async gap to avoid BuildContext issues
    final appStateManager = context.read<AppStateManager>();
    Future.microtask(() => appStateManager.initialize());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.versionCheckResult.forceUpdate) {
      return const MaterialApp(
        home: ForceUpdateScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    // Render the app immediately; initialization continues in background
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateManager>(
      builder: (context, appState, child) {
        return MaterialApp(
          navigatorKey: AppNavigator.navigatorKey,
          title: 'Nardeboun',
          theme: AppTheme.lightTheme, // Using custom light theme
          darkTheme: AppTheme.darkTheme, // Using custom dark theme
          themeMode: appState.currentThemeMode,
          debugShowCheckedModeBanner:
              ConfigService.instance.getValue<bool>('debugCheckModeBanner') ??
              false,
          home: const AuthWrapper(),
          routes: {
            '/home': (context) =>
                const SimpleNetworkWrapper(child: HomeScreen()),
            '/auth': (context) =>
                const SimpleNetworkWrapper(child: AuthScreen()),
            '/verify-otp': (context) {
              final phoneNumber =
                  ModalRoute.of(context)?.settings.arguments as String? ?? '';
              return SimpleNetworkWrapper(
                child: VerifyOtpScreen(phoneNumber: phoneNumber),
              );
            },
            '/edit-profile': (context) =>
                const SimpleNetworkWrapper(child: EditProfileScreen()),
            '/video-player': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>? ??
                  {};
              return SimpleNetworkWrapper(
                child: VideoPlayerScreen(
                  embedHtml: args['embedHtml'] ?? args['videoUrl'],
                  allowLandscape: true,
                ),
              );
            },
            '/onboarding/step1': (context) =>
                const SimpleNetworkWrapper(child: OnboardingStep1Screen()),
            '/onboarding/step2': (context) =>
                const SimpleNetworkWrapper(child: OnboardingStep2Screen()),
            '/onboarding/success': (context) =>
                const SimpleNetworkWrapper(child: OnboardingSuccessScreen()),
            '/onboarding': (context) =>
                const SimpleNetworkWrapper(child: OnboardingScreen()),
            '/provincial-sample': (context) =>
                const SimpleNetworkWrapper(child: ProvincialSampleScreen()),
            '/step-by-step': (context) =>
                const SimpleNetworkWrapper(child: StepByStepScreen()),
            '/subject': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;

              // اگر آرگومان‌ها نباشند، از Hive بخون
              if (args == null) {
                final appState = context.read<AppStateManager>();
                final profile = appState.authService.currentProfile;

                if (profile == null) {
                  return const SimpleNetworkWrapper(
                    child: Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'خطا 404',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('چنین صفحه‌ای وجود ندارد'),
                            SizedBox(height: 16),
                            Text('لطفاً ابتدا وارد شوید'),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // بخوانید آخرین subject از Hive
                final subjectData = SessionService.instance
                    .getLastSelectedSubject();
                final trackId = SessionService.instance
                    .getLastSelectedTrackId();

                if (subjectData != null) {
                  return SimpleNetworkWrapper(
                    child: SubjectScreen(
                      subject: Subject.fromJson(subjectData),
                      gradeId: profile.grade ?? 7,
                      trackId: trackId,
                    ),
                  );
                }

                // اگر هیچ subject ذخیره نشده، برو به home
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
                return Container();
              }

              return SimpleNetworkWrapper(
                child: SubjectScreen(
                  subject: args['subject'],
                  gradeId: args['gradeId'],
                  trackId: args['trackId'],
                ),
              );
            },
            '/chapter': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              if (args == null) {
                return const SimpleNetworkWrapper(
                  child: Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'خطا 404',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('چنین صفحه‌ای وجود ندارد'),
                          SizedBox(height: 16),
                          Text('مسیر /chapter نیاز به آرگومان‌های معتبر دارد'),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SimpleNetworkWrapper(
                child: ChapterScreen(
                  chapter: args['chapter'],
                  subject: args['subject'],
                  gradeId: args['gradeId'],
                  trackId: args['trackId'],
                ),
              );
            },
          },
          builder: (context, child) {
            final content = Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const DevSettingsButton(), // دکمه تنظیمات موقت در همه صفحات
              ],
            );
            // نمایش سراسری صفحه قطع اینترنت در صورت عدم اتصال
            return SimpleNetworkWrapper(child: content);
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final configService = ConfigService.instance;
    final initialRouteForDev =
        configService.getValue<String>('initialRouteForDev') ?? '';
    final appState = context.read<AppStateManager>();

    String route;

    // اگر initialRouteForDev ست است، آن را احترام بگذار (بدون نیاز به devMode)
    if (initialRouteForDev.isNotEmpty) {
      // مسیرهایی که بدون لاگین هم مجازند
      const publicRoutes = <String>{
        '/onboarding',
        '/onboarding/step1',
        '/onboarding/step2',
        '/onboarding/success',
        '/auth',
      };

      final isPublic = publicRoutes.contains(initialRouteForDev);
      if (isPublic) {
        route = initialRouteForDev;
      } else {
        // برای مسیرهای غیرعمومی، اگر لاگین نیست → /onboarding، در غیر این صورت همان مسیر
        route = appState.authService.currentProfile == null
            ? '/onboarding'
            : initialRouteForDev;
      }
    } else {
      route = appState.appropriateRoute;
    }

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Center(child: CircularProgressIndicator()),
          const DevSettingsButton(), // دکمه تنظیمات موقت
        ],
      ),
    );
  }
}
