import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';
import 'config/config_service.dart';
import 'cache/hive_cache_service.dart';
import 'image_cache/smart_image_cache_service.dart';

class SessionService {
  SessionService._();
  static final instance = SessionService._();

  late final Box _sessionBox;
  static const String _boxName = 'session';
  static const String _lastActivityKey = 'last_activity_timestamp';
  static const String _sessionDataKey = 'session_data';
  static const String _userProfileKey = 'user_profile';
  static const String _lastSelectedSubjectKey = 'last_selected_subject';
  static const String _lastSelectedTrackIdKey = 'last_selected_track_id';
  static const String _userPreferencesKey = '/user_preferences';
  static const String _filterPreferencesKey = 'filter_preferences';
  static const String _pdfPreferencesKey = 'pdf_preferences';
  static const String _viewStateKey = 'view_state';
  // _otpRateLimitKey حذف شد - rate limiting حالا در Supabase انجام می‌شود

  /// Reads session timeout (in days) from config.json, defaults to 30
  int get _sessionTimeoutDays =>
      ConfigService.instance.getValue<int>('sessionTimeoutDays') ?? 30;

  /// Initializes the session service and opens the Hive box.
  Future<void> init() async {
    _sessionBox = await Hive.openBox(_boxName);
    Logger.info(' Hive session box initialized.');

    // Initialize Hive Cache Service for content caching
    await HiveCacheService.init();
  }

  /// Updates the last activity timestamp to the current time.
  /// This should be called every time a logged-in user opens the app.
  Future<void> updateLastActivityTimestamp() async {
    final now = DateTime.now().toIso8601String();
    await _sessionBox.put(_lastActivityKey, now);
    Logger.info('Last activity timestamp updated to: $now');
  }

  /// Checks if the session has expired based on the last activity timestamp.
  /// Returns `true` if more than configured days have passed, `false` otherwise.
  bool isSessionExpired() {
    final lastActivityString = _sessionBox.get(_lastActivityKey) as String?;

    if (lastActivityString == null) {
      // No activity recorded yet, so session is not expired.
      return false;
    }

    try {
      final lastActivity = DateTime.parse(lastActivityString);
      final now = DateTime.now();
      final difference = now.difference(lastActivity);

      if (difference.inDays >= _sessionTimeoutDays) {
        Logger.info(
          'Session has expired. Last activity was ${difference.inDays} days ago. Timeout: $_sessionTimeoutDays days',
        );
        return true;
      }

      Logger.info(
        'Session is still valid. Last activity was ${difference.inDays} days ago. Timeout: $_sessionTimeoutDays days',
      );
      return false;
    } catch (e) {
      Logger.error('Error parsing last activity date: $e');
      // In case of a parsing error, assume the session is not expired.
      return false;
    }
  }

  /// Saves user profile to Hive storage
  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    await _sessionBox.put(_userProfileKey, profileData);
    Logger.info(
      '🔍 [HIVE SAVE] Saved profile: ${profileData['first_name']} ${profileData['last_name']}',
    );
    Logger.debug('🔍 [HIVE SAVE] Full profile data: $profileData');
  }

  /// Retrieves user profile from Hive storage
  Map<String, dynamic>? getUserProfile() {
    try {
      final rawProfile = _sessionBox.get(_userProfileKey);
      if (rawProfile == null) {
        Logger.info('🔍 [HIVE GET] No profile found in Hive');
        return null;
      }

      final profileData = Map<String, dynamic>.from(rawProfile as Map);
      Logger.info(
        '🔍 [HIVE GET] Retrieved profile: ${profileData['first_name']} ${profileData['last_name']}',
      );
      Logger.debug('🔍 [HIVE GET] Full profile data: $profileData');
      return profileData;
    } catch (e) {
      Logger.error('🔍 [HIVE GET] Error reading profile', e);
      return null;
    }
  }

  /// Save last selected subject (full object)
  Future<void> saveLastSelectedSubject(Map<String, dynamic> subjectData) async {
    await _sessionBox.put(_lastSelectedSubjectKey, subjectData);
    Logger.info('Last selected subject saved to Hive.');
  }

  /// Get last selected subject
  Map<String, dynamic>? getLastSelectedSubject() {
    try {
      final rawSubject = _sessionBox.get(_lastSelectedSubjectKey);
      if (rawSubject == null) return null;
      return Map<String, dynamic>.from(rawSubject as Map);
    } catch (e) {
      Logger.error('🔧 [HIVE] Error reading subject', e);
      return null;
    }
  }

  /// Save last selected track ID
  Future<void> saveLastSelectedTrackId(int? trackId) async {
    await _sessionBox.put(_lastSelectedTrackIdKey, trackId);
    Logger.info('Last selected track ID saved to Hive.');
  }

  /// Get last selected track ID
  int? getLastSelectedTrackId() {
    return _sessionBox.get(_lastSelectedTrackIdKey) as int?;
  }

  // =============================== USER PREFERENCES ===============================

  /// Save user theme preference
  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    await _sessionBox.put(_userPreferencesKey, preferences);
    Logger.info('🔧 [HIVE THEME] Saved user preferences: $preferences');
  }

  /// Get user preferences (theme, font, language, etc.)
  Map<String, dynamic>? getUserPreferences() {
    try {
      final rawPrefs = _sessionBox.get(_userPreferencesKey);
      if (rawPrefs == null) {
        Logger.info('🔧 [HIVE THEME] No user preferences found, using defaults');
        return null;
      }

      final preferences = Map<String, dynamic>.from(rawPrefs as Map);
      Logger.info('🔧 [HIVE THEME] Retrieved user preferences: $preferences');
      return preferences;
    } catch (e) {
      Logger.error('🔧 [HIVE THEME] Error reading preferences', e);
      return null;
    }
  }

  /// Save theme mode (light/dark/system)
  Future<void> saveThemeMode(String themeMode) async {
    final currentPrefs = getUserPreferences() ?? {};
    currentPrefs['theme_mode'] = themeMode;
    await saveUserPreferences(currentPrefs);
  }

  /// Get theme mode
  String getThemeMode() {
    final prefs = getUserPreferences();
    final theme = prefs?['theme_mode'] ?? 'light';
    Logger.info('🔧 [HIVE THEME] Current theme: $theme');
    return theme;
  }

  // =============================== FILTER PREFERENCES ===============================

  /// Save filter preferences (grade, track, subject, year filters)
  Future<void> saveFilterPreferences(Map<String, dynamic> filters) async {
    await _sessionBox.put(_filterPreferencesKey, filters);
    Logger.info('🔧 [HIVE FILTERS] Saved filter preferences: $filters');
  }

  /// Get filter preferences
  Map<String, dynamic>? getFilterPreferences() {
    try {
      final rawFilters = _sessionBox.get(_filterPreferencesKey);
      if (rawFilters == null) {
        Logger.info('🔧 [HIVE FILTERS] No filters found, using defaults');
        return null;
      }

      // Safely convert from dynamic Map to Map<String, dynamic>
      final filters = Map<String, dynamic>.from(rawFilters as Map);
      Logger.info('🔧 [HIVE FILTERS] Retrieved filters: $filters');
      return filters;
    } catch (e) {
      Logger.error('🔧 [HIVE FILTERS] Error reading filters', e);
      return null;
    }
  }

  /// Save current filter state (called from screens)
  Future<void> saveCurrentFilters({
    int? grade,
    int? track,
    String? subject,
    int? year,
    bool? hasAnswerKey,
  }) async {
    final currentFilters = getFilterPreferences() ?? {};

    if (grade != null) currentFilters['last_grade_filter'] = grade;
    if (track != null) currentFilters['last_track_filter'] = track;
    if (subject != null) currentFilters['last_subject_filter'] = subject;
    if (year != null) currentFilters['provincial_year_filter'] = year;
    if (hasAnswerKey != null) {
      currentFilters['has_answer_key_filter'] = hasAnswerKey;
    }

    await saveFilterPreferences(currentFilters);
  }

  // =============================== PDF PREFERENCES ===============================

  /// Save PDF preferences
  Future<void> savePdfPreferences(Map<String, dynamic> pdfPrefs) async {
    await _sessionBox.put(_pdfPreferencesKey, pdfPrefs);
    Logger.info('🔧 [HIVE PDF] Saved PDF preferences: $pdfPrefs');
  }

  /// Get PDF preferences
  Map<String, dynamic>? getPdfPreferences() {
    try {
      final rawPrefs = _sessionBox.get(_pdfPreferencesKey);
      if (rawPrefs == null) {
        Logger.info('🔧 [HIVE PDF] No PDF preferences found, using defaults');
        return null;
      }

      final pdfPrefs = Map<String, dynamic>.from(rawPrefs as Map);
      Logger.info('🔧 [HIVE PDF] Retrieved PDF preferences: $pdfPrefs');
      return pdfPrefs;
    } catch (e) {
      Logger.error('🔧 [HIVE PDF] Error reading PDF preferences', e);
      return null;
    }
  }

  /// Get default PDF view mode
  String getDefaultPdfViewMode() {
    final prefs = getPdfPreferences();
    return prefs?['default_view_mode'] ?? 'cache';
  }

  // =============================== VIEW STATE ===============================

  /// Save view state (current tab, video positions, etc.)
  Future<void> saveViewState(Map<String, dynamic> viewState) async {
    await _sessionBox.put(_viewStateKey, viewState);
    Logger.info('🔧 [HIVE VIEW] Saved view state: $viewState');
  }

  /// Get view state
  Map<String, dynamic>? getViewState() {
    try {
      final rawState = _sessionBox.get(_viewStateKey);
      if (rawState == null) {
        Logger.info('🔧 [HIVE VIEW] No view state found, using defaults');
        return null;
      }

      final viewState = Map<String, dynamic>.from(rawState as Map);
      Logger.info('🔧 [HIVE VIEW] Retrieved view state: $viewState');
      return viewState;
    } catch (e) {
      Logger.error('🔧 [HIVE VIEW] Error reading view state', e);
      return null;
    }
  }

  /// Save current tab index
  Future<void> saveCurrentTab(String screen, int tabIndex) async {
    final currentState = getViewState() ?? {};
    currentState['${screen}_current_tab'] = tabIndex;
    await saveViewState(currentState);
  }

  /// Get current tab index
  int getCurrentTab(String screen, {int defaultValue = 0}) {
    final state = getViewState();
    return state?['${screen}_current_tab'] ?? defaultValue;
  }

  // =============================== SESSION DATA ===============================

  /// Save session data (access token, refresh token, etc.)
  Future<void> saveSessionData(Map<String, dynamic> sessionData) async {
    await _sessionBox.put(_sessionDataKey, sessionData);
    Logger.info('Session data saved to Hive.');
  }

  /// Get session data
  Map<String, dynamic>? getSessionData() {
    try {
      final rawSession = _sessionBox.get(_sessionDataKey);
      if (rawSession == null) {
        Logger.info('🔍 [HIVE GET] No session data found');
        return null;
      }
      final sessionData = Map<String, dynamic>.from(rawSession as Map);
      Logger.info('🔍 [HIVE GET] Session data retrieved: ${sessionData.keys}');
      return sessionData;
    } catch (e) {
      Logger.error('🔧 [HIVE] Error reading session data', e);
      return null;
    }
  }

  /// Clears the session data upon logout.
  Future<void> clearSession() async {
    await _sessionBox.delete(_lastActivityKey);
    await _sessionBox.delete(_sessionDataKey);
    await _sessionBox.delete(_userProfileKey);
    await _sessionBox.delete(_lastSelectedSubjectKey);
    await _sessionBox.delete(_lastSelectedTrackIdKey);

    // پاک کردن تمام کش تصاویر
    try {
      await SmartImageCacheService.instance.clearAll();
      Logger.info('🔧 [HIVE CLEAR] Image cache cleared');
    } catch (e) {
      Logger.error('❌ [HIVE CLEAR] Error clearing image cache', e);
    }

    // Note: User preferences and filters are NOT cleared on logout
    // so they persist across sessions for better UX
    // OTP rate limit is also NOT cleared to maintain device-based blocking
    Logger.info('Session data and image cache cleared.');
  }

  /// Clear only session data (tokens) but keep profile and preferences
  Future<void> clearSessionDataOnly() async {
    await _sessionBox.delete(_lastActivityKey);
    await _sessionBox.delete(_sessionDataKey);
    Logger.info('Session data cleared (profile preserved).');
  }

  /// Clear user preferences (theme, filters, etc.) - for app reset
  Future<void> clearUserPreferences() async {
    await _sessionBox.delete(_userPreferencesKey);
    await _sessionBox.delete(_filterPreferencesKey);
    await _sessionBox.delete(_pdfPreferencesKey);
    await _sessionBox.delete(_viewStateKey);
    Logger.info('🔧 [HIVE CLEAR] User preferences cleared');
  }

  /// =============================== OTP RATE LIMIT ===============================
  // ========== OTP Rate Limiting حذف شد ==========
  // تمام rate limiting و ban checking حالا در Supabase Edge Functions انجام می‌شود
  // نیازی به client-side rate limiting نیست
}
