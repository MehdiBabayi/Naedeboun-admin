import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/core/app_state_manager.dart';

/// صفحه نمایش خطای قطعی شبکه
class NetworkErrorScreen extends StatefulWidget {
  final String? previousRoute;
  final VoidCallback? onRetry;
  final String? customMessage;

  const NetworkErrorScreen({
    super.key,
    this.previousRoute,
    this.onRetry,
    this.customMessage,
  });

  @override
  State<NetworkErrorScreen> createState() => _NetworkErrorScreenState();
}

class _NetworkErrorScreenState extends State<NetworkErrorScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Consumer<AppStateManager>(
          builder: (context, appState, child) {
            // اگر شبکه وصل شد، برگرد به صفحه قبلی
            if (appState.isNetworkConnected) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pop();
              });
            }

            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // آیکون انیمیشن دار
                      _buildAnimatedIcon(context),
                      const SizedBox(height: 32),

                      // عنوان
                      _buildTitle(context),
                      const SizedBox(height: 16),

                      // پیام
                      _buildMessage(context, appState),
                      const SizedBox(height: 32),

                      // دکمه تلاش مجدد
                      _buildRetryButton(context, appState),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        Icons.wifi_off_rounded,
        size: 60,
        color: theme.colorScheme.error,
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'اتصال قطع است',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
        fontFamily: 'IRANSansXFaNum',
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMessage(BuildContext context, AppStateManager appState) {
    final theme = Theme.of(context);
    final details =
        appState.lastNetworkError?.details ??
        widget.customMessage ??
        'لطفاً اتصال اینترنت خود را بررسی کنید و دوباره تلاش کنید';

    return Text(
      details,
      style: TextStyle(
        fontSize: 14,
        color: theme.colorScheme.onSurfaceVariant,
        fontFamily: 'IRANSansXFaNum',
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRetryButton(BuildContext context, AppStateManager appState) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRetrying ? null : () => _handleRetry(appState),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isRetrying
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'در حال تلاش...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
                ],
              )
            : Text(
                'تلاش مجدد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IRANSansXFaNum',
                ),
              ),
      ),
    );
  }

  Future<void> _handleRetry(AppStateManager appState) async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      // تلاش برای بررسی اتصال
      final isConnected = await appState.networkService.checkConnection();

      if (isConnected && mounted) {
        // اگر اتصال برقرار شد، صفحه را ببند
        Navigator.of(context).pop();
      } else {
        // اگر هنوز اتصال نیست، پیام نمایش بده
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'هنوز اتصال برقرار نیست. لطفاً دوباره تلاش کنید.',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در بررسی اتصال: $e',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }

    // اگر onRetry callback وجود دارد، آن را هم اجرا کن
    if (widget.onRetry != null) {
      widget.onRetry!();
    }
  }
}
