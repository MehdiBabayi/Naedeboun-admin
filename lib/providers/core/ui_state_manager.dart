import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// State Manager مخصوص مدیریت وضعیت UI
class UIStateManager extends ChangeNotifier {
  // Singleton pattern
  static final UIStateManager _instance = UIStateManager._internal();
  factory UIStateManager() => _instance;
  UIStateManager._internal();

  // State variables
  bool _isLoading = false;
  String? _loadingMessage;
  bool _isBottomSheetVisible = false;
  bool _isDialogVisible = false;
  bool _isSnackBarVisible = false;
  String? _currentSnackBarMessage;
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('fa', 'IR');

  // Getters
  bool get isLoading => _isLoading;
  String? get loadingMessage => _loadingMessage;
  bool get isBottomSheetVisible => _isBottomSheetVisible;
  bool get isDialogVisible => _isDialogVisible;
  bool get isSnackBarVisible => _isSnackBarVisible;
  String? get currentSnackBarMessage => _currentSnackBarMessage;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  /// نمایش لودینگ
  void showLoading({String? message}) {
    _isLoading = true;
    _loadingMessage = message;
    notifyListeners();
  }

  /// مخفی کردن لودینگ
  void hideLoading() {
    _isLoading = false;
    _loadingMessage = null;
    notifyListeners();
  }

  /// نمایش Bottom Sheet
  void showBottomSheet() {
    _isBottomSheetVisible = true;
    notifyListeners();
  }

  /// مخفی کردن Bottom Sheet
  void hideBottomSheet() {
    _isBottomSheetVisible = false;
    notifyListeners();
  }

  /// نمایش Dialog
  void showDialog() {
    _isDialogVisible = true;
    notifyListeners();
  }

  /// مخفی کردن Dialog
  void hideDialog() {
    _isDialogVisible = false;
    notifyListeners();
  }

  /// نمایش SnackBar
  void showSnackBar(String message) {
    _isSnackBarVisible = true;
    _currentSnackBarMessage = message;
    notifyListeners();
  }

  /// مخفی کردن SnackBar
  void hideSnackBar() {
    _isSnackBarVisible = false;
    _currentSnackBarMessage = null;
    notifyListeners();
  }

  /// تغییر تم
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// تغییر زبان
  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  /// تغییر به تم روشن
  void setLightTheme() {
    _themeMode = ThemeMode.light;
    notifyListeners();
  }

  /// تغییر به تم تاریک
  void setDarkTheme() {
    _themeMode = ThemeMode.dark;
    notifyListeners();
  }

  /// تغییر به تم سیستم
  void setSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }

  /// بررسی اینکه آیا تم تاریک است
  bool isDarkTheme(BuildContext context) {
    switch (_themeMode) {
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }

  /// پاک کردن تمام state های UI
  void clearAllUIStates() {
    _isLoading = false;
    _loadingMessage = null;
    _isBottomSheetVisible = false;
    _isDialogVisible = false;
    _isSnackBarVisible = false;
    _currentSnackBarMessage = null;
    notifyListeners();
  }
}

/// Provider برای دسترسی آسان به UIStateManager
class UIStateProvider extends StatelessWidget {
  final Widget child;

  const UIStateProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UIStateManager>(
      create: (context) => UIStateManager(),
      child: child,
    );
  }
}

/// Extension برای دسترسی آسان به UIStateManager
extension UIStateExtension on BuildContext {
  UIStateManager get uiState => Provider.of<UIStateManager>(this, listen: false);
  UIStateManager get uiStateWatch => Provider.of<UIStateManager>(this);
}
