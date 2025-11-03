import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/data/iran_provinces.dart';
import '../../providers/core/app_state_manager.dart';
import '../../exceptions/auth_exceptions.dart';

class OnboardingStep2Screen extends StatefulWidget {
  const OnboardingStep2Screen({super.key});

  @override
  State<OnboardingStep2Screen> createState() => _OnboardingStep2ScreenState();
}

// ========= Top-level input formatters =========
class _CollapseSpacesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\s+'), ' ');
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _TrimLeadingSpacesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceFirst(RegExp(r'^\s+'), '');
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _LimitRepeatedCharFormatter extends TextInputFormatter {
  final int maxRepeats;
  _LimitRepeatedCharFormatter({this.maxRepeats = 3});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    int run = 0;
    int? lastCode;
    for (final code in newValue.text.runes) {
      if (code == lastCode) {
        run += 1;
        if (run < maxRepeats) buffer.writeCharCode(code);
      } else {
        lastCode = code;
        run = 0;
        buffer.writeCharCode(code);
      }
    }
    final text = buffer.toString();
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _OnboardingStep2ScreenState extends State<OnboardingStep2Screen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  String _selectedProvince = 'تهران'; // پیش‌فرض: تهران
  late String _selectedCity; // پیش‌فرض: اولین شهر استان
  bool _isLoading = false;
  String? _firstNameError;
  String? _lastNameError;

  // لیست کامل استان‌ها و مراکز آن‌ها (مرتب شده به ترتیب الفبا)
  final Map<String, List<String>> _provincesAndCities = IranProvinces.provinces;

  @override
  void initState() {
    super.initState();
    // تنظیم شهر پیش‌فرض براساس استان پیش‌فرض
    _selectedCity = _provincesAndCities[_selectedProvince]?.first ?? 'تهران';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // بخش بالا و وسط
                    Column(
                      children: [
                        // Header Image (top)
                        SizedBox(
                          height: 140, // کاهش از 200 به 140
                          child: Center(
                            child: Image.asset(
                              'assets/images/headers/onboarding_step2.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Form Fields (middle)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'اطلاعات شخصی خود را تکمیل کنید',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontFamily: 'IRANSansXFaNum',
                                  ),
                            ),
                            const SizedBox(height: 32),

                            // Name Fields - Side by Side
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal:
                                    16, // کاهش از 32 به 16 برای عرض بیشتر
                              ),
                              child: Row(
                                children: [
                                  // First Name Field
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _firstNameController,
                                      focusNode: _firstNameFocusNode,
                                      label: 'نام',
                                      hint: 'نام',
                                      maxLength: 15,
                                      inputFormatters: _nameInputFormatters(
                                        maxLength: 15,
                                      ),
                                      errorText: _firstNameError,
                                      onChanged: (value) {
                                        setState(() {
                                          final trimmed = value.trim();
                                          if (trimmed.length > 15) {
                                            _firstNameError =
                                                'بیشتر از ۱۵ حرف غیرمجاز است';
                                          } else if (!RegExp(
                                            r'^[\u0600-\u06FF\u200c\s-]+$',
                                          ).hasMatch(trimmed)) {
                                            _firstNameError =
                                                'فقط حروف فارسی و فاصله مجاز است';
                                          } else {
                                            _firstNameError = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Last Name Field
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _lastNameController,
                                      focusNode: _lastNameFocusNode,
                                      label: 'نام خانوادگی',
                                      hint: 'نام خانوادگی',
                                      maxLength: 15,
                                      inputFormatters: _nameInputFormatters(
                                        maxLength: 15,
                                      ),
                                      errorText: _lastNameError,
                                      onChanged: (value) {
                                        setState(() {
                                          final trimmed = value.trim();
                                          if (trimmed.length > 15) {
                                            _lastNameError =
                                                'بیشتر از ۱۵ حرف غیرمجاز است';
                                          } else if (!RegExp(
                                            r'^[\u0600-\u06FF\u200c\s-]+$',
                                          ).hasMatch(trimmed)) {
                                            _lastNameError =
                                                'فقط حروف فارسی و فاصله مجاز است';
                                          } else {
                                            _lastNameError = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Province Dropdown
                            Text(
                              'انتخاب استان و شهر',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.black, // مشکی مطلق
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'IRANSansXFaNum',
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _buildProvinceDropdown(),
                            const SizedBox(height: 16),

                            // City Dropdown
                            _buildCityDropdown(),
                            const SizedBox(height: 60), // فاصله قبل از دکمه
                            // دکمه تکمیل ثبت‌نام
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ), // کوچک کردن دکمه
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _canComplete()
                                    ? _completeRegistration
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'تکمیل ثبت‌نام',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'IRANSansXFaNum',
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // بخش پایین (فقط تیک‌ها)
                    _buildProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    int maxLength = 60,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    Function(String)? onChanged,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (context, setState) {
          // گوش دادن به تغییرات فوکوس
          focusNode.addListener(() {
            setState(() {});
          });

          return TextField(
            controller: controller,
            focusNode: focusNode,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            textAlign: TextAlign.right,
            onChanged: onChanged,
            decoration: InputDecoration(
              // اگر فوکوس داره یا پر شده: label نشون بده
              // اگر فوکوس نداره و خالیه: فقط hint نشون بده
              labelText: (focusNode.hasFocus || controller.text.isNotEmpty)
                  ? label
                  : null,
              hintText: (!focusNode.hasFocus && controller.text.isEmpty)
                  ? hint
                  : null,
              errorText: errorText,
              labelStyle: TextStyle(
                fontFamily: 'IRANSansXFaNum',
                color: const Color(0xFF3629B7),
                fontWeight: FontWeight.bold,
              ),
              hintStyle: TextStyle(
                color: const Color(0xFF3629B7),
                fontFamily: 'IRANSansXFaNum',
              ),
              errorStyle: TextStyle(fontFamily: 'IRANSansXFaNum'),
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(
                  color: const Color(0xFF3629B7),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(
                  color: const Color(0xFF3629B7),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(
                  color: const Color(0xFF3629B7),
                  width: 2.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Colors.red, width: 2.5),
              ),
              counterText: '',
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF3629B7),
              fontFamily: 'IRANSansXFaNum',
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }

  // ========== Input Formatters ==========
  List<TextInputFormatter> _nameInputFormatters({required int maxLength}) {
    return <TextInputFormatter>[
      LengthLimitingTextInputFormatter(maxLength),
      FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\u200c\s-]')),
      _CollapseSpacesFormatter(),
      _LimitRepeatedCharFormatter(maxRepeats: 3),
      _TrimLeadingSpacesFormatter(),
    ];
  }

  Widget _buildProvinceDropdown() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16), // فاصله از کناره‌ها
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF3629B7), // رنگ آبی تم مرکزی
          width: 2,
        ),
        borderRadius: BorderRadius.circular(28), // نیم دایره (زاویه بیشتر)
      ),
      child: DropdownButtonHideUnderline(
        child: Directionality(
          textDirection: TextDirection.rtl, // <-- راست‌چین شد
          child: DropdownButton<String>(
            value: _selectedProvince,
            menuMaxHeight: 300.0, // <-- اضافه شد برای اسکرول
            hint: Text(
              'استان را انتخاب کنید',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: 'IRANSansXFaNum',
              ),
            ),
            isExpanded: true,
            alignment: AlignmentDirectional.centerEnd,
            selectedItemBuilder: (context) {
              return _provincesAndCities.keys.map((province) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    province,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'IRANSansXFaNum',
                      color: const Color(0xFF3629B7), // رنگ متن انتخاب شده آبی
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList();
            },
            items: _provincesAndCities.keys.map((province) {
              return DropdownMenuItem<String>(
                value: province,
                alignment: AlignmentDirectional.centerEnd,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    province,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                if (value != null) {
                  _selectedProvince = value;
                  // تنظیم شهر به اولین شهر استان جدید
                  _selectedCity = _provincesAndCities[value]?.first ?? '';
                }
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    final cities = _provincesAndCities[_selectedProvince] ?? ['تهران'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16), // فاصله از کناره‌ها
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF3629B7), // رنگ آبی تم مرکزی
          width: 2,
        ),
        borderRadius: BorderRadius.circular(28), // نیم دایره (زاویه بیشتر)
      ),
      child: DropdownButtonHideUnderline(
        child: Directionality(
          textDirection: TextDirection.rtl, // <-- راست‌چین شد
          child: DropdownButton<String>(
            value: _selectedCity,
            menuMaxHeight: 300.0, // <-- اضافه شد برای اسکرول
            hint: Text(
              'شهر را انتخاب کنید',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: 'IRANSansXFaNum',
              ),
            ),
            isExpanded: true,
            alignment: AlignmentDirectional.centerEnd,
            selectedItemBuilder: (context) {
              return cities.map((city) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    city,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'IRANSansXFaNum',
                      color: const Color(0xFF3629B7), // رنگ متن انتخاب شده آبی
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList();
            },
            items: cities.map((city) {
              return DropdownMenuItem<String>(
                value: city,
                alignment: AlignmentDirectional.centerEnd,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    city,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                if (value != null) {
                  _selectedCity = value;
                }
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildProgressStep('تکمیل اطلاعات', false),
        _buildProgressStep('اطلاعات پایه', true),
        _buildProgressStep('تایید شماره', true),
      ],
    );
  }

  Widget _buildProgressStep(String label, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted
                ? Theme.of(context).colorScheme.primary
                : Colors.white, // پس‌زمینه سفید برای تیک‌های نخورده
            border: Border.all(
              color: isCompleted
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey, // کادر خاکستری برای تیک‌های نخورده
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            color: isCompleted ? Colors.white : Colors.grey.shade400,
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isCompleted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontFamily: 'IRANSansXFaNum',
          ),
        ),
      ],
    );
  }

  bool _canComplete() {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _selectedProvince.isNotEmpty &&
        _selectedCity.isNotEmpty &&
        _firstNameError == null &&
        _lastNameError == null;
  }

  Future<void> _completeRegistration() async {
    if (!_canComplete()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = context.read<AppStateManager>();

      await appState.authService.completeStep2(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        province: _selectedProvince,
        city: _selectedCity,
      );

      if (mounted) {
        // بعد از تکمیل استپ 2، registration_stage میشه 'completed'
        // پس باید بره Home نه step3
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on AuthServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطای غیرمنتظره رخ داد',
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
          _isLoading = false;
        });
      }
    }
  }
}
