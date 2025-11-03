import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nardeboun/models/auth/user_model.dart';
import 'package:nardeboun/models/auth/user_profile.dart';
import 'package:nardeboun/models/auth/registration_stage.dart';
import 'package:nardeboun/exceptions/auth_exceptions.dart';
import 'package:nardeboun/utils/logger.dart';
import 'package:nardeboun/const/api_keys.dart';
import 'package:nardeboun/services/config/config_service.dart';
import 'package:nardeboun/services/session_service.dart';
import 'package:nardeboun/services/device/device_id_service.dart';
import 'package:nardeboun/providers/core/app_state_manager.dart';
// import 'package:intl/intl.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient supaBase;
  UserModel? _currentUser;
  UserProfile? _currentProfile;
  bool _isLoading = false;
  bool _isExplicitLogout = false; // Flag برای تشخیص logout واقعی
  bool _handlingAuthEvent = false; // Mutex برای جلوگیری از race condition
  bool _isInitializing = false; // Mutex برای init

  AuthService({required this.supaBase}) {
    // مقداردهی اولیه را async نمی‌کنیم تا constructor مشکل نداشته باشد
    _initializeUserAsync();
    supaBase.auth.onAuthStateChange.listen((data) async {
      // Mutex: جلوگیری از handle کردن همزمان
      if (_handlingAuthEvent) {
        Logger.info('⏳ [AUTH LISTENER] Already handling event, skipping...');
        return;
      }

      // Ignore initialSession event
      if (data.event == AuthChangeEvent.initialSession) {
        Logger.info('🔁 [AUTH LISTENER] Ignoring initialSession event');
        return;
      }

      _handlingAuthEvent = true;
      try {
        await _handleAuthStateChange(data);
      } finally {
        _handlingAuthEvent = false;
      }
    });
  }

  /// Handle auth state changes with proper logic
  Future<void> _handleAuthStateChange(AuthState data) async {
    final session = data.session;
    final sessionData = SessionService.instance.getSessionData();
    final savedProfile = SessionService.instance.getUserProfile();

    Logger.info('🔁 [AUTH LISTENER] event: ${data.event}');
    Logger.info('🔁 [AUTH LISTENER] sessionExists: ${session != null}');
    Logger.info('🔁 [AUTH LISTENER] isExplicitLogout: $_isExplicitLogout');
    Logger.info('🔁 [AUTH LISTENER] sessionDataInHive: ${sessionData != null}');
    Logger.info('🔁 [AUTH LISTENER] savedProfileInHive: ${savedProfile != null}');

    if (session != null) {
      Logger.info('✅ [AUTH LISTENER] Session exists, saving and fetching profile...');
      await _saveSessionToStorage(session);
      await _fetchUserProfile(session.user.id);

      // 🚀 Trigger Mini-Request after successful login
      Logger.info(
        '🚀 [AUTH LISTENER] ===== TRIGGERING MINI-REQUEST AFTER LOGIN =====',
      );
      try {
        // Use AppStateManager singleton
        Logger.info(
          '🔍 [AUTH LISTENER] Calling AppStateManager.triggerMiniRequestAfterLogin...',
        );
        await AppStateManager().triggerMiniRequestAfterLogin();
        Logger.info('✅ [AUTH LISTENER] Mini-Request trigger completed');
      } catch (e) {
        Logger.error('❌ [AUTH LISTENER] Failed to trigger Mini-Request', e);
        Logger.info('❌ [AUTH LISTENER] Error type: ${e.runtimeType}');
      }

      return;
    }

    // Session == null
    Logger.info('⚠️ [AUTH LISTENER] Session is NULL');

    if (_isExplicitLogout) {
      Logger.info('🔍 [AUTH LISTENER] explicit logout -> clearing storage');
      await _clearSessionFromStorage();
      _currentUser = null;
      _currentProfile = null;
      _isExplicitLogout = false;
      notifyListeners();
      return;
    }

    // NOT explicit logout: فقط پروفایل را برای نمایش آفلاین restore کن؛ پاک‌سازی نکن
    Logger.info(
      '🔍 [AUTH LISTENER] session null and not explicit. savedProfileExists: ${savedProfile != null}',
    );
    if (savedProfile != null) {
      Logger.info(
        '✅ [AUTH LISTENER] Restoring profile from Hive (keeping _currentUser null)',
      );
      _currentProfile = UserProfile.fromJson(savedProfile);
      // نگه دار _currentUser null تا صفحات auth-only روی supabase.currentSession تکیه کنند
      _currentUser = null;

      // 🚀 حتی با session NULL، Mini-Request را trigger کن اگر profile داریم
      Logger.info(
        '🚀 [AUTH LISTENER] ===== TRIGGERING MINI-REQUEST WITH PROFILE ONLY =====',
      );
      try {
        Logger.info(
          '🔍 [AUTH LISTENER] Calling AppStateManager.triggerMiniRequestAfterLogin...',
        );
        await AppStateManager().triggerMiniRequestAfterLogin();
        Logger.info('✅ [AUTH LISTENER] Mini-Request trigger completed');
      } catch (e) {
        Logger.error('❌ [AUTH LISTENER] Failed to trigger Mini-Request', e);
        Logger.info('❌ [AUTH LISTENER] Error type: ${e.runtimeType}');
      }

      notifyListeners();
    } else {
      Logger.info('❌ [AUTH LISTENER] No profile in Hive to restore');
    }
  }

  UserModel? get currentUser => _currentUser;
  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;

  /// Getter امن برای تشخیص authentication واقعی (براساس session)
  bool get isAuthenticated {
    final hasSession = supaBase.auth.currentSession != null;
    Logger.info(
      '🔍 [AUTH] isAuthenticated check: session=$hasSession, profile=${_currentProfile != null}',
    );
    return hasSession;
  }

  /// آیا کاربر در مرحله ثبت‌نام است؟
  bool get isInOnboarding =>
      _currentProfile?.registrationStage.isCompleted == false;

  /// مرحله فعلی ثبت‌نام
  RegistrationStage get currentRegistrationStage =>
      _currentProfile?.registrationStage ?? RegistrationStage.step1;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _initializeUserAsync() {
    // Async initialization بدون await
    _initializeUser().catchError((e) {
      Logger.error("Error in async user initialization", e);
    });
  }

  /// Restore session from Hive storage
  Future<void> _restoreSessionFromStorage() async {
    try {
      Logger.info('🔍 [AUTH DEBUG] Attempting to restore session from Hive...');

      // Check if session is expired using SessionService
      if (SessionService.instance.isSessionExpired()) {
        Logger.info('🔍 [AUTH DEBUG] Session has expired, clearing...');
        await _clearSessionFromStorage();
        return;
      }

      Logger.info('🔍 [AUTH DEBUG] Session is NOT expired, continuing restore...');

      // Try to restore from Supabase first
      final session = supaBase.auth.currentSession;
      if (session != null) {
        Logger.info('🔍 [AUTH DEBUG] Session found in Supabase memory');
        Logger.info('🔍 [AUTH DEBUG] Session user ID: ${session.user.id}');

        // Update last activity timestamp
        await SessionService.instance.updateLastActivityTimestamp();
        return;
      }

      // If no session in memory, try to restore from Hive
      Logger.info(
        '🔍 [AUTH DEBUG] No session in memory, attempting to restore from Hive...',
      );

      final sessionData = SessionService.instance.getSessionData();
      if (sessionData != null) {
        Logger.info(
          '🔍 [AUTH DEBUG] Session data found in Hive, attempting to restore...',
        );

        try {
          // Check if this is a fake session (from our custom verify-otp flow)
          final accessToken = sessionData['access_token'] as String;
          if (accessToken.startsWith('fake_access_token_')) {
            Logger.info(
              '🔍 [AUTH DEBUG] Detected fake session, restoring profile only...',
            );

            // Update last activity timestamp
            await SessionService.instance.updateLastActivityTimestamp();

            // Try to restore profile from Hive
            final savedProfile = SessionService.instance.getUserProfile();
            if (savedProfile != null) {
              Logger.info(
                '🔍 [AUTH DEBUG] Restoring profile from Hive (fake session)...',
              );
              _currentProfile = UserProfile.fromJson(savedProfile);
              _currentUser = UserModel.fromJson(savedProfile);
              Logger.info(
                '🔍 [AUTH DEBUG] Profile restored from Hive: ${savedProfile['first_name']} ${savedProfile['last_name']}',
              );
              notifyListeners();
              return;
            } else {
              Logger.info(
                '🔍 [AUTH DEBUG] No profile found in Hive for fake session',
              );
            }
          } else {
            // Try to restore real session using Supabase
            final restoredSession = await supaBase.auth.setSession(accessToken);

            if (restoredSession.session != null) {
              Logger.info(
                '🔍 [AUTH DEBUG] Real session restored successfully from Hive',
              );
              Logger.info(
                '🔍 [AUTH DEBUG] Restored session user ID: ${restoredSession.session!.user.id}',
              );

              // Update last activity timestamp
              await SessionService.instance.updateLastActivityTimestamp();

              // Try to restore profile from Hive
              final savedProfile = SessionService.instance.getUserProfile();
              if (savedProfile != null) {
                Logger.info('🔍 [AUTH DEBUG] Restoring profile from Hive...');
                _currentProfile = UserProfile.fromJson(savedProfile);
                _currentUser = UserModel.fromJson(savedProfile);
                Logger.info(
                  '🔍 [AUTH DEBUG] Profile restored from Hive: ${savedProfile['first_name']} ${savedProfile['last_name']}',
                );
                notifyListeners();
              }

              return;
            } else {
              Logger.info('🔍 [AUTH DEBUG] Real session restore failed');
            }
          }
        } catch (e) {
          Logger.error('❌ [AUTH DEBUG] Error restoring session from Hive data', e);
          // DON'T clear session data - it might be a fake session that's still valid
          // Just log the error and continue
        }
      } else {
        Logger.info('🔍 [AUTH DEBUG] No session data in Hive');
      }

      // Note: We DON'T clear session here - profile might still be valid
    } catch (e) {
      Logger.error('❌ [AUTH DEBUG] Error restoring session from storage', e);
    }
  }

  /// Save session to Hive storage
  Future<void> _saveSessionToStorage(Session session) async {
    try {
      Logger.info('🔍 [AUTH DEBUG] Saving session to Hive...');

      // Save session data (access token, refresh token, etc.)
      await SessionService.instance.saveSessionData({
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'expires_at': session.expiresAt?.toString(),
        'user_id': session.user.id,
      });

      // Update last activity timestamp in Hive
      await SessionService.instance.updateLastActivityTimestamp();

      Logger.info(
        '🔍 [AUTH DEBUG] Session data and timestamp saved to Hive successfully',
      );
      Logger.info('🔍 [AUTH DEBUG] Session user ID: ${session.user.id}');
    } catch (e) {
      Logger.error('❌ [AUTH DEBUG] Error saving session to storage', e);
    }
  }

  /// Clear session from Hive storage
  Future<void> _clearSessionFromStorage() async {
    try {
      Logger.info('🔍 [AUTH DEBUG] ⚠️⚠️⚠️ Clearing session from Hive...');
      Logger.info('🔍 [AUTH DEBUG] ⚠️⚠️⚠️ Stack trace: ${StackTrace.current}');

      // Clear session data from Hive
      await SessionService.instance.clearSession();

      Logger.info('🔍 [AUTH DEBUG] Session cleared from Hive successfully');
    } catch (e) {
      Logger.error('❌ [AUTH DEBUG] Error clearing session from storage', e);
    }
  }

  /// Clear only session data (tokens) but keep profile
  Future<void> _clearSessionDataOnly() async {
    try {
      Logger.info('🔍 [AUTH DEBUG] Clearing session data only (keeping profile)...');

      // Clear only session data, keep profile
      await SessionService.instance.clearSessionDataOnly();

      Logger.info('🔍 [AUTH DEBUG] Session data cleared, profile preserved');
    } catch (e) {
      Logger.error('❌ [AUTH DEBUG] Error clearing session data', e);
    }
  }

  Future<void> _initializeUser() async {
    if (_isInitializing) {
      Logger.info('⏳ [AUTH DEBUG] Already initializing, skipping...');
      return;
    }

    _isInitializing = true;
    try {
      Logger.info('🔍 [AUTH DEBUG] _initializeUser called');

      // اول تلاش به restore از Hive
      await _restoreSessionFromStorage();

      // بعد از restore چک کن که آیا session واقعی داریم
      final session = supaBase.auth.currentSession;
      Logger.info(
        '🔍 [AUTH DEBUG] After restore, supabase.currentSession exists: ${session != null}',
      );

      final savedProfile = SessionService.instance.getUserProfile();
      Logger.info('🔍 [AUTH DEBUG] savedProfileExists: ${savedProfile != null}');

      // فقط اگر نه session و نه savedProfile داشتیم، کاربر باید لاگین شود
      if (session == null && savedProfile == null) {
        Logger.info(
          '🔍 [AUTH DEBUG] No session and no savedProfile found - user needs login',
        );
        // در این نقطه فقط یک لاگ بزن؛ پاک‌سازی کامل را خودکار انجام نده
        return;
      }

      // اگر savedProfile وجود داشت، restore کن (بدون override کردن _currentUser اگر session null باشد)
      if (savedProfile != null) {
        Logger.info('🔍 [AUTH DEBUG] Restoring profile from Hive...');
        _currentProfile = UserProfile.fromJson(savedProfile);

        if (session != null) {
          Logger.info('🔍 [AUTH DEBUG] Session exists, setting _currentUser');
          _currentUser = UserModel.fromJson(savedProfile);
          await _fetchUserProfile(session.user.id);
        } else {
          Logger.info(
            '🔍 [AUTH DEBUG] No session, keeping _currentUser null (offline mode)',
          );
          _currentUser = null; // آفلاین فقط profile برای نمایش
        }

        Logger.info(
          '🔍 [HIVE] Profile loaded: ${savedProfile['first_name']} ${savedProfile['last_name']}',
        );
        notifyListeners();
        return;
      }

      // اگر session وجود داشت، پروفایل را از سرور بارگذاری کن
      if (session != null) {
        Logger.info(
          '🔍 [AUTH DEBUG] Session exists, fetching profile from server...',
        );
        await _fetchUserProfile(session.user.id);
      }
    } catch (e) {
      Logger.error("Error initializing user", e);
      // در صورت خطا، فقط لاگ کن - پاک‌سازی خودکار نکن
    } finally {
      _isInitializing = false;
    }
  }

  // ارسال OTP واقعی با Supabase Function
  Future<void> sendOtp(String phoneNumber) async {
    _setLoading(true);
    try {
      Logger.info("Sending OTP to: $phoneNumber");

      // استفاده از Supabase Function - تمام rate limiting و ban checking در server انجام می‌شود
      final normalizedPhone = _normalizePhone(phoneNumber);
      await _sendOtpViaFunction(normalizedPhone);
      Logger.info("Real OTP sent successfully to: $phoneNumber");
    } catch (e) {
      Logger.error("Error in sendOtp", e);

      // بررسی نوع خطا
      if (e.toString().contains('Invalid phone number')) {
        throw AuthServiceException('شماره تلفن نامعتبر است');
      } else if (e.toString().contains('rate limit')) {
        throw AuthServiceException(
          'تعداد درخواست‌ها زیاد است. لطفاً کمی صبر کنید',
        );
      } else if (e is AuthServiceException) {
        // پیام سفارشی نرخ‌دهی یا بن
        rethrow;
      } else {
        throw AuthServiceException(
          'ارسال کد با خطا مواجه شد. لطفاً دوباره تلاش کنید.',
        );
      }
    } finally {
      _setLoading(false);
    }
  }

  // ارسال OTP از طریق Supabase Function
  Future<void> _sendOtpViaFunction(String phoneNumber) async {
    try {
      Logger.info("Calling Supabase Function for OTP to: $phoneNumber");

      final deviceId = await DeviceIdService.instance.getDeviceId();

      if (deviceId.isEmpty) {
        throw AuthServiceException('خطا در شناسایی دستگاه');
      }

      // ارسال از طریق Function با توکن احراز هویت
      final response = await supaBase.functions.invoke(
        'send-otp',
        body: {
          'phone': phoneNumber,
          'device_id': deviceId,
          'devMode': ConfigService.instance.isDevMode,
        },
        headers: {'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}'},
      );

      if (response.status == 403) {
        final error = response.data['error'] as String?;
        throw AuthServiceException(error ?? 'حساب شما مسدود شده است');
      }

      if (response.status == 429) {
        final error = response.data['error'] as String?;
        throw AuthServiceException(error ?? 'تعداد تلاش بیش از حد مجاز است');
      }

      if (response.status != 200) {
        throw AuthServiceException('خطا در ارسال کد تأیید');
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String?;
      final status = data['status'] as String?;

      Logger.info("OTP sent successfully. Code: $code, Status: $status");
    } catch (e) {
      Logger.error("Error in _sendOtpViaFunction", e);
      throw Exception('خطا در ارسال پیامک: $e');
    }
  }

  // تأیید OTP واقعی با بررسی انقضا
  Future<void> verifyOtp(
    String phoneNumber,
    String otp, {
    BuildContext? context,
  }) async {
    _setLoading(true);
    try {
      Logger.info("🔍 [DEBUG] Starting OTP verification");
      final normalizedPhone = _normalizePhone(phoneNumber);
      Logger.info("🔍 [DEBUG] Phone (normalized): $normalizedPhone");
      Logger.info("🔍 [DEBUG] OTP: $otp");
      Logger.info("🔍 [DEBUG] OTP Length: ${otp.length}");

      // اعتبارسنجی OTP و مدیریت پروفایل به‌صورت کامل در Edge Function انجام می‌شود
      Logger.info(
        "✅ [DEBUG] Delegating OTP verification to server-side function",
      );

      // Delegate profile creation/update to Edge Function (Service Role)
      Logger.info(
        "🔍 [DEBUG] Calling verify-otp function to upsert profile server-side...",
      );
      final fnResponse = await supaBase.functions.invoke(
        'verify-otp',
        body: {'phone': normalizedPhone, 'otp': otp},
        headers: {'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}'},
      );

      if (fnResponse.status != 200) {
        Logger.error(
          "❌ [DEBUG] verify-otp function failed: ${fnResponse.status}",
        );
        throw AuthServiceException('خطا در تأیید کد از سرور');
      }

      final fnData = (fnResponse.data as Map<String, dynamic>);
      final profileJson = fnData['user'] as Map<String, dynamic>?;
      if (profileJson == null) {
        throw AuthServiceException('پروفایل کاربر از سرور دریافت نشد');
      }

      _currentUser = UserModel.fromJson(profileJson);
      _currentProfile = UserProfile.fromJson(profileJson);

      // چک ادمین بودن کاربر برای دسترسی به پنل ادمین
      Logger.info("🔍 [AUTH] Checking user role: ${_currentProfile?.userRole}");
      if (_currentProfile?.userRole != 'admin') {
        Logger.error(
          "❌ [AUTH] User is not admin. Role: ${_currentProfile?.userRole}",
        );
        // فقط session data را پاک کن و profile را نگه دار
        await _clearSessionDataOnly();
        _currentUser = null;
        _currentProfile = null;
        notifyListeners();
        throw AuthServiceException(
          'شما اجازه دسترسی به پنل ادمین را ندارید. لطفا با شماره تلفن ادمین وارد شوید.',
        );
      }

      notifyListeners();
      Logger.info("✅ [DEBUG] OTP verification completed successfully");

      // Rate limiting حالا در Supabase انجام می‌شود - نیازی به پاک کردن client-side نیست
      Logger.info(
        "✅ [DEBUG] OTP verified successfully - rate limiting handled by Supabase",
      );

      // Since verify-otp function doesn't return session, we'll save a fake session data to Hive
      // This is needed for session restore functionality
      final userId = profileJson['user_id'] as String;
      final fakeSessionData = {
        'access_token': 'fake_access_token_$userId',
        'refresh_token': 'fake_refresh_token_$userId',
        'expires_at': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'user_id': userId,
      };

      // Save fake session data to Hive
      await SessionService.instance.saveSessionData(fakeSessionData);
      Logger.info('🔍 [LOGIN] Fake session data saved to Hive for user: $userId');

      // Save session and profile to Hive after successful login
      final session = supaBase.auth.currentSession;
      Logger.info(
        '🔍 [LOGIN] Session after verification: ${session != null ? "EXISTS" : "NULL"}',
      );

      if (session != null) {
        await _saveSessionToStorage(session);
        await SessionService.instance.saveUserProfile(profileJson);
        Logger.info(
          '🔍 [LOGIN] Profile saved to Hive: ${profileJson['first_name']} ${profileJson['last_name']}',
        );
      } else {
        Logger.info('🔍 [LOGIN] WARNING: Session is NULL, saving profile anyway!');
        await SessionService.instance.saveUserProfile(profileJson);
        Logger.info(
          '🔍 [LOGIN] Profile saved to Hive (no session): ${profileJson['first_name']} ${profileJson['last_name']}',
        );

        // 🚀 حتی با session NULL، Mini-Request را trigger کن
        Logger.info(
          '🚀 [LOGIN] ===== TRIGGERING MINI-REQUEST AFTER LOGIN (NO SESSION) =====',
        );
        try {
          Logger.info(
            '🔍 [LOGIN] Calling AppStateManager.triggerMiniRequestAfterLogin...',
          );
          await AppStateManager().triggerMiniRequestAfterLogin();
          Logger.info('✅ [LOGIN] Mini-Request trigger completed');
        } catch (e) {
          Logger.error('❌ [LOGIN] Failed to trigger Mini-Request', e);
          Logger.info('❌ [LOGIN] Error type: ${e.runtimeType}');
        }
      }
    } catch (e) {
      String? currentRoute;
      if (context != null && context.mounted) {
        currentRoute = ModalRoute.of(context)?.settings.name;
      }

      Logger.error('❌ [DEBUG] Error in verifyOtp', e);
      Logger.error('❌ [DEBUG] Error type: ${e.runtimeType}');
      Logger.error('❌ [DEBUG] Error message: ${e.toString()}');
      Logger.error('❌ [DEBUG] Current route: $currentRoute');

      // فقط در صفحه verify-otp error نشون بده
      if (currentRoute == '/verify-otp') {
        if (e.toString().contains('Invalid OTP') ||
            e.toString().contains('otp_expired')) {
          throw AuthServiceException('کد وارد شده نامعتبر یا منقضی شده است');
        } else if (e.toString().contains('multiple') ||
            e.toString().contains('406')) {
          throw AuthServiceException(
            'چند رکورد OTP یافت شد. لطفاً دوباره تلاش کنید',
          );
        } else {
          throw AuthServiceException('خطا در تأیید کد. لطفاً دوباره تلاش کنید');
        }
      } else {
        // در همه صفحات دیگه (شامل /home) error نشون نده
        Logger.info('🔍 [AUTH DEBUG] Ignoring error in route: $currentRoute');
        return; // بدون throw
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  String _normalizePhone(String raw) {
    var p = raw.trim().replaceAll(RegExp(r"\s+"), '');
    // Convert Persian digits to Latin
    const map = {
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    p = p.split('').map((c) => map[c] ?? c).join();
    if (p.startsWith('+')) return p;
    if (p.startsWith('0098')) return '+${p.substring(2)}';
    if (p.startsWith('98')) return '+$p';
    if (p.startsWith('0') && p.length == 11) return '+98${p.substring(1)}';
    return p;
  }

  // تبدیل اعداد لاتین به فارسی برای نمایش پیام‌ها

  Future<void> _fetchUserProfile(String userId) async {
    try {
      Logger.info('🔍 [AUTH DEBUG] _fetchUserProfile called for user: $userId');
      final response = await supaBase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      Logger.info(
        '🔍 [AUTH DEBUG] Profile response: ${response != null ? "FOUND" : "NOT_FOUND"}',
      );

      if (response != null) {
        Logger.info('🔍 [AUTH DEBUG] Profile data: ${response.toString()}');
        _currentUser = UserModel.fromJson(response);
        _currentProfile = UserProfile.fromJson(response);

        // Save profile to Hive for persistence
        await SessionService.instance.saveUserProfile(response);
        Logger.info('🔍 [AUTH DEBUG] Profile saved to Hive');

        Logger.info('🔍 [AUTH DEBUG] Profile loaded successfully');
        Logger.info(
          '🔍 [AUTH DEBUG] Registration stage: ${_currentProfile?.registrationStage.value}',
        );
      } else {
        Logger.info('🔍 [AUTH DEBUG] No profile found for user');
      }
      notifyListeners();
    } catch (e) {
      Logger.error("Error fetching or creating user profile", e);
      // فقط session data رو پاک کن، profile رو نگه دار
      await _clearSessionDataOnly();
      _currentUser = null;
      // _currentProfile رو پاک نکن
      notifyListeners();
    }
  }

  /// به‌روزرسانی پروفایل کاربر از دیتابیس
  Future<void> loadUserProfile() async {
    if (_currentUser == null) return;

    try {
      final response = await supaBase
          .from('profiles')
          .select()
          .eq('user_id', _currentUser!.id)
          .maybeSingle();

      if (response != null) {
        _currentProfile = UserProfile.fromJson(response);
        // Save profile to Hive for persistence
        await SessionService.instance.saveUserProfile(response);
        notifyListeners();
        Logger.info(
          "User profile loaded: ${_currentProfile!.registrationStage.value}",
        );
      }
    } catch (e) {
      Logger.error("Error loading user profile", e);
    }
  }

  /// بررسی وضعیت ثبت‌نام کاربر
  Future<RegistrationStage> checkRegistrationStatus(String phoneNumber) async {
    try {
      final response = await supaBase
          .from('profiles')
          .select('registration_stage')
          .eq('phone_number', phoneNumber)
          .maybeSingle();

      if (response != null) {
        return RegistrationStageExtension.fromString(
          response['registration_stage'] as String,
        );
      }

      return RegistrationStage.step1;
    } catch (e) {
      Logger.error("Error checking registration status", e);
      return RegistrationStage.step1;
    }
  }

  Future<void> signOut() async {
    Logger.info('🔍 [AUTH DEBUG] signOut called - setting explicit logout flag');
    _isExplicitLogout = true; // Set flag before signOut
    await supaBase.auth.signOut();
    // Listener will handle clearing based on _isExplicitLogout flag
  }

  /// بروزرسانی پروفایل کاربر
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      // اطمینان از داشتن پروفایل فعلی
      var profile = _currentProfile;
      if (profile == null) {
        final saved = SessionService.instance.getUserProfile();
        if (saved != null) {
          profile = UserProfile.fromJson(saved);
        }
      }
      if (profile == null) {
        throw AuthServiceException('پروفایل کاربر یافت نشد');
      }

      // payload نهایی
      final payload = Map<String, dynamic>.from(updates);
      payload['last_stage_update'] = DateTime.now().toIso8601String();

      // 🔍 Debug logging
      Logger.info('🔍 [UPDATE DEBUG] Updating profile:');
      Logger.info('   profile.id (user_id): ${profile.id}');
      Logger.info('   auth.currentUser?.id: ${supaBase.auth.currentUser?.id}');
      Logger.info(
        '   auth.currentSession: ${supaBase.auth.currentSession != null ? "EXISTS" : "NULL"}',
      );
      Logger.info('   payload: $payload');

      // 🔍 بررسی تطابق
      if (supaBase.auth.currentUser?.id != profile.id) {
        Logger.info('   ⚠️ WARNING: auth.uid != profile.id');
        Logger.info('   auth.uid: ${supaBase.auth.currentUser?.id}');
        Logger.info('   profile.id: ${profile.id}');
      }

      // 🔍 ابتدا چک کنیم که profile وجود دارد یا نه
      final existingProfile = await supaBase
          .from('profiles')
          .select('user_id, phone_number, grade')
          .eq('user_id', profile.id)
          .maybeSingle();

      Logger.info(
        '🔍 [UPDATE DEBUG] Existing profile check: ${existingProfile != null ? "FOUND" : "NOT FOUND"}',
      );
      if (existingProfile != null) {
        Logger.info('   Existing data: $existingProfile');
      } else {
        Logger.info('   ❌ Profile not found with user_id: ${profile.id}');
        throw AuthServiceException('پروفایل با این شناسه یافت نشد');
      }

      // اجرای بروزرسانی در جدول profiles
      final response = await supaBase
          .from('profiles')
          .update(payload)
          .eq('user_id', profile.id)
          .select()
          .single();

      // بروزرسانی state داخلی و ذخیره در Hive
      _currentProfile = UserProfile.fromJson(response);
      _currentUser = UserModel.fromJson(response);
      await SessionService.instance.saveUserProfile(response);

      notifyListeners();
    } catch (e) {
      if (e is AuthServiceException) rethrow;
      Logger.error('Error updating profile', e);
      throw AuthServiceException('خطا در به‌روزرسانی پروفایل');
    }
  }

  /// تکمیل مرحله اول ثبت‌نام (جنسیت و پایه)
  Future<void> completeStep1({
    required String gender,
    required int grade,
    String? fieldOfStudy,
  }) async {
    final updates = {
      'gender': gender,
      'grade': grade,
      if (fieldOfStudy != null) 'field_of_study': fieldOfStudy,
      'registration_stage': RegistrationStage.step2.value,
      'step1_completed_at': DateTime.now().toIso8601String(),
    };
    await updateProfile(updates);
  }

  /// تکمیل مرحله دوم ثبت‌نام (نام، استان، شهر)
  Future<void> completeStep2({
    required String firstName,
    required String lastName,
    required String province,
    required String city,
  }) async {
    final updates = {
      'first_name': firstName,
      'last_name': lastName,
      'province': province,
      'city': city,
      'registration_stage': RegistrationStage.completed.value,
      'step2_completed_at': DateTime.now().toIso8601String(),
    };
    await updateProfile(updates);
  }
}
