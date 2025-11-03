import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/core/app_state_manager.dart';
import '../../screens/network/network_error_screen.dart';
import '../../utils/logger.dart';

/// ویجت wrapper برای مدیریت خطاهای شبکه
class NetworkWrapper extends StatelessWidget {
  final Widget child;
  final String? currentRoute;

  const NetworkWrapper({super.key, required this.child, this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateManager>(
      builder: (context, appState, child) {
        // چک کن که AppStateManager initialize شده باشد
        if (!appState.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // اگر شبکه قطع است، NetworkErrorScreen را نمایش بده
        if (!appState.isNetworkConnected) {
          return NetworkErrorScreen(
            previousRoute: currentRoute,
            onRetry: () async {
              // تلاش مجدد برای اتصال
              final isConnected = await appState.networkService
                  .checkConnection();
              if (isConnected) {
                // اگر وصل شد، به صفحه قبلی برگرد
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          );
        }

        // اگر شبکه وصل است، child را نمایش بده
        return this.child;
      },
    );
  }
}

/// ویجت wrapper ساده برای تمام صفحات
class SimpleNetworkWrapper extends StatelessWidget {
  final Widget child;

  const SimpleNetworkWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Logger.debug('🔍 SimpleNetworkWrapper: build() called');

    return Consumer<AppStateManager>(
      builder: (context, appState, child) {
        // چک کن که AppStateManager initialize شده باشد
        if (!appState.isInitialized) {
          Logger.debug(
            '⏳ SimpleNetworkWrapper: AppStateManager not initialized yet, showing loading',
          );
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final networkService = appState.networkService;
        final shouldShow = networkService.shouldShowErrorScreen;

        Logger.debug('🔍 SimpleNetworkWrapper: Consumer builder called');
        Logger.debug('🔍 SimpleNetworkWrapper: shouldShowErrorScreen: $shouldShow');

        // اگر باید صفحه خطا نمایش داده شود
        if (shouldShow) {
          Logger.debug('❌ SimpleNetworkWrapper: Should show error screen');
          // استفاده از addPostFrameCallback برای navigate کردن
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              // چک کن آیا NetworkErrorScreen در حال نمایش است یا نه
              final route = ModalRoute.of(context);
              if (route != null &&
                  !route.settings.name.toString().contains('NetworkError')) {
                Logger.debug(
                  '❌ SimpleNetworkWrapper: Navigating to NetworkErrorScreen',
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NetworkErrorScreen(
                      onRetry: () async {
                        Logger.info('🔄 SimpleNetworkWrapper: Retry button pressed');
                        final isConnected = await networkService
                            .checkConnection();
                        Logger.info(
                          '🔄 SimpleNetworkWrapper: Retry result: $isConnected',
                        );
                        if (isConnected && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    settings: const RouteSettings(name: 'NetworkErrorScreen'),
                  ),
                );
              }
            }
          });
        }

        // حالت عادی - child را نمایش بده
        Logger.debug('✅ SimpleNetworkWrapper: Showing child widget (normal state)');
        return this.child;
      },
    );
  }
}
