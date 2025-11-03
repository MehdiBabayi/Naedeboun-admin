import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_state_manager.dart';
import 'core/error_state_manager.dart';
import 'core/ui_state_manager.dart';
import '../utils/logger.dart';

/// Provider مرکزی برای تمام State Manager های برنامه
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core State Managers
        ChangeNotifierProvider<AppStateManager>(
          create: (context) => AppStateManager(),
        ),
        ChangeNotifierProvider<ErrorStateManager>(
          create: (context) => ErrorStateManager(),
        ),
        ChangeNotifierProvider<UIStateManager>(
          create: (context) => UIStateManager(),
        ),

        // AuthService is now managed by AppStateManager
      ],
      child: child,
    );
  }
}

/// Widget برای مقداردهی اولیه State Managers
class AppStateInitializer extends StatefulWidget {
  final Widget child;

  const AppStateInitializer({super.key, required this.child});

  @override
  State<AppStateInitializer> createState() => _AppStateInitializerState();
}

class _AppStateInitializerState extends State<AppStateInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAppState();
  }

  Future<void> _initializeAppState() async {
    try {
      Logger.info('🚀 AppStateInitializer: Starting initialization...');
      final appStateManager = context.read<AppStateManager>();
      await appStateManager.initialize();

      Logger.info('✅ AppStateInitializer: Initialization completed');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      Logger.error('❌ AppStateInitializer: Error during initialization', e);
      // Handle initialization error
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}

/// Extension برای دسترسی آسان به تمام State Managers
extension AllStateManagersExtension on BuildContext {
  // Core State Managers
  AppStateManager get appState =>
      Provider.of<AppStateManager>(this, listen: false);
  AppStateManager get appStateWatch => Provider.of<AppStateManager>(this);

  ErrorStateManager get errorState =>
      Provider.of<ErrorStateManager>(this, listen: false);
  ErrorStateManager get errorStateWatch => Provider.of<ErrorStateManager>(this);

  UIStateManager get uiState =>
      Provider.of<UIStateManager>(this, listen: false);
  UIStateManager get uiStateWatch => Provider.of<UIStateManager>(this);

  // AuthService is now accessed through AppStateManager
}
