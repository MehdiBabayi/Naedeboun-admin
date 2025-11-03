import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../exceptions/auth_exceptions.dart';
import '../../exceptions/error_handler.dart';
import '../../providers/core/app_state_manager.dart';
import '../../widgets/auth/phone_keypad.dart';
import '../../utils/logger.dart';
import 'package:pinput/pinput.dart';
import '../../services/config/config_service.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String phoneNumber;
  const VerifyOtpScreen({super.key, required this.phoneNumber});
  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _pinController = TextEditingController();
  final _displayController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _displayController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    if (mounted) setState(() {});
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        if (mounted) setState(() => _timer?.cancel());
      }
    });
  }

  Future<void> _resendCode() async {
    final appState = context.read<AppStateManager>();
    final authService = appState.authService;
    try {
      await authService.sendOtp(widget.phoneNumber);
      _startTimer(); // Restart the timer
    } catch (e) {
      if (mounted) ErrorHandler.show(context, 'ارسال مجدد کد ناموفق بود');
    }
  }

  void _onNumberPressed(String number) {
    final latin = _mapPersianToLatin(number);
    final otpLength = ConfigService.instance.otpLength;
    if (_pinController.text.length < otpLength) {
      // اضافه کردن به controller انگلیسی (برای ارسال)
      _pinController.text += latin;
      // اضافه کردن به controller فارسی (برای نمایش)
      _displayController.text += number;
      if (_pinController.text.length == otpLength) {
        _verifyOtp();
      }
    }
  }

  // Normalize Persian digits to Latin
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
    if (digit.length == 1) return map[digit] ?? digit;
    return digit.split('').map((d) => map[d] ?? d).join();
  }

  // Convert Latin digits to Persian
  String _mapLatinToPersian(String text) {
    const map = {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    };
    return text.split('').map((char) => map[char] ?? char).join();
  }

  void _onBackspacePressed() {
    if (_pinController.text.isNotEmpty) {
      _pinController.text = _pinController.text.substring(
        0,
        _pinController.text.length - 1,
      );
      _displayController.text = _displayController.text.substring(
        0,
        _displayController.text.length - 1,
      );
    }
  }

  Future<void> _verifyOtp() async {
    final appState = context.read<AppStateManager>();
    final authService = appState.authService;
    // Ensure OTP is Latin digits
    final otp = _mapPersianToLatin(_pinController.text);
    final otpLength = ConfigService.instance.otpLength;
    if (otp.length != otpLength) {
      ErrorHandler.show(
        context,
        'لطفاً کد ${_mapLatinToPersian(otpLength.toString())} رقمی را کامل وارد کنید',
      );
      return;
    }
    try {
      await authService.verifyOtp(widget.phoneNumber, otp, context: context);
      if (!mounted) return;
      _timer?.cancel();

      // بعد از تأیید OTP، کاربر را به صفحه مناسب هدایت می‌کنیم
      final appState = context.read<AppStateManager>();
      final appropriateRoute = appState.appropriateRoute;
      Logger.info(
        "🔍 [DEBUG] Navigating to appropriate route: $appropriateRoute",
      );
      Navigator.of(context).pushReplacementNamed(appropriateRoute);
    } on AuthServiceException catch (e) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == '/verify-otp' && mounted) {
        ErrorHandler.show(context, e.message);
      }
    } catch (e) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == '/verify-otp' && mounted) {
        ErrorHandler.show(context, 'خطای نامشخصی رخ داد');
      }
    }
  }

  String _formatPhoneForDisplay(String phone) {
    // تبدیل +989123456789 به ۰۹۱۲۳۴۵۶۷۸۹ (بدون +98)
    if (phone.startsWith('+98')) {
      final digits = phone.substring(3);
      return _mapLatinToPersian('0$digits');
    }
    return _mapLatinToPersian(phone);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final authService = appState.authService;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
        fontFamily: 'IRANSansXFaNum',
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // سفید در هر دو تم
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'تایید کد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'IRANSansXFaNum',
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'کد ${_mapLatinToPersian(ConfigService.instance.otpLength.toString())} رقمی ارسال شده به شماره ${_formatPhoneForDisplay(widget.phoneNumber)} را وارد کنید',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'IRANSansXFaNum',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Pinput(
                controller: _displayController,
                length: ConfigService.instance.otpLength,
                enabled: false,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyDecorationWith(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  _pinController.text.length ==
                          ConfigService.instance.otpLength &&
                      !authService.isLoading
                  ? _verifyOtp
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: authService.isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      _pinController.text.length ==
                              ConfigService.instance.otpLength
                          ? 'تأیید کد'
                          : 'تایید کد',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            _pinController.text.length ==
                                ConfigService.instance.otpLength
                            ? Colors.white
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontFamily: 'IRANSansXFaNum',
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            _secondsRemaining > 0
                ? Text(
                    'ارسال مجدد کد تا $_secondsRemaining ثانیه دیگر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  )
                : TextButton(
                    onPressed: authService.isLoading ? null : _resendCode,
                    child: Text(
                      'ارسال مجدد کد',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'IRANSansXFaNum',
                      ),
                    ),
                  ),
            const SizedBox(height: 32),
            // ویجت پد فارسی برای وارد کردن OTP
            PhoneKeypad(
              onKeyTap: _onNumberPressed,
              onBackspace: _onBackspacePressed,
            ),
          ],
        ),
      ),
    );
  }
}
