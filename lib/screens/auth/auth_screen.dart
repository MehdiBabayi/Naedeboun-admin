import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../exceptions/auth_exceptions.dart';
import '../../exceptions/error_handler.dart';
import '../../providers/core/app_state_manager.dart';
// import '../onboarding/onboarding_screen.dart';
import '../../widgets/auth/phone_keypad.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _displayController = TextEditingController();
  bool _acceptTerms = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _displayController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      return '+98${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _handleSubmit() async {
    final appState = context.read<AppStateManager>();
    final authService = appState.authService;
    try {
      if (_phoneController.text.length != 11 ||
          !_phoneController.text.startsWith('09')) {
        if (!mounted) return;
        ErrorHandler.show(
          context,
          AuthServiceException.invalidPhoneNumber().message,
        );
        return;
      }
      if (!_acceptTerms) {
        if (!mounted) return;
        ErrorHandler.show(context, 'لطفاً قوانین و مقررات را بپذیرید');
        return;
      }

      final formattedPhone = _formatPhoneNumber(_phoneController.text);
      await authService.sendOtp(formattedPhone);

      // فقط در صورت موفقیت به صفحه verify می‌رویم
      if (!mounted) return;
      Navigator.pushNamed(context, '/verify-otp', arguments: formattedPhone);
    } on AuthServiceException catch (e) {
      // اگر خطا بیاید (مثل non-admin)، به صفحه verify نمی‌رویم
      if (!mounted) return;
      ErrorHandler.show(context, e.message);
      return; // مطمئن می‌شویم که navigation انجام نمی‌شود
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, 'خطای نامشخصی رخ داد');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final authService = appState.authService;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'ورود شماره موبایل',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontFamily: 'IRANSansXFaNum',
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Header illustration section - extends to edges
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.zero,
            ),
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            child: SizedBox(
              height: 120,
              child: Image.asset(
                'assets/images/auth/auth_header.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(38),
                  topRight: Radius.circular(38),
                ),
              ),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 200,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'شماره خود را وارد کنید',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'IRANSansXFaNum',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: TextField(
                                  controller: _displayController,
                                  readOnly: true,
                                  enabled: false,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                    fontFamily: 'IRANSansXFaNum',
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '09121234567',
                                    hintStyle: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                      fontFamily: 'IRANSansXFaNum',
                                    ),
                                    prefixIcon: Icon(
                                      Icons.phone,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Wrap the button with AnimatedBuilder to react to AuthService loading changes
                            AnimatedBuilder(
                              animation: authService,
                              builder: (context, _) {
                                return SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: authService.isLoading
                                        ? null
                                        : _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                    ),
                                    child: authService.isLoading
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                          )
                                        : const Text('ادامه'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'قوانین و مقررات را می‌پذیرم',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface,
                                    fontFamily: 'IRANSansXFaNum',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Checkbox(
                                value: _acceptTerms,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _acceptTerms = value ?? false;
                                  });
                                },
                                activeColor: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32), // فاصله مثل صفحه verify-otp
                        // PhoneKeypad داخل Column
                        // Wrap PhoneKeypad with AnimatedBuilder so onSubmit reacts to loading state
                        AnimatedBuilder(
                          animation: authService,
                          builder: (context, _) {
                            return PhoneKeypad(
                              onKeyTap: (digit) {
                                if (_phoneController.text.length >= 11) return;
                                // اضافه کردن به controller انگلیسی (برای ارسال)
                                _phoneController.text =
                                    _phoneController.text +
                                    _mapPersianToLatin(digit);
                                // اضافه کردن به controller فارسی (برای نمایش)
                                _displayController.text =
                                    _displayController.text + digit;
                              },
                              onBackspace: () {
                                final t = _phoneController.text;
                                if (t.isNotEmpty) {
                                  _phoneController.text = t.substring(
                                    0,
                                    t.length - 1,
                                  );
                                  _displayController.text = _displayController
                                      .text
                                      .substring(
                                        0,
                                        _displayController.text.length - 1,
                                      );
                                }
                              },
                              onSubmit: authService.isLoading
                                  ? null
                                  : _handleSubmit,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mapPersianToLatin(String digit) {
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
    return map[digit] ?? digit;
  }
}
