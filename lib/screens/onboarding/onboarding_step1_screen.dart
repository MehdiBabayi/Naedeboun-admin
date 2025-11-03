import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/core/app_state_manager.dart';
import '../../exceptions/auth_exceptions.dart';

class OnboardingStep1Screen extends StatefulWidget {
  const OnboardingStep1Screen({super.key});

  @override
  State<OnboardingStep1Screen> createState() => _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState extends State<OnboardingStep1Screen> {
  String? _selectedGender;
  int _selectedGrade = 1; // پیش‌فرض: پایه اول
  String _selectedFieldOfStudy = 'ریاضی و فیزیک'; // پیش‌فرض: ریاضی
  bool _isLoading = false;

  final List<int> _grades = List.generate(
    12,
    (index) => index + 1,
  ); // <-- اصلاح شد: ۱ تا ۱۲
  final List<String> _fieldsOfStudy = [
    'ریاضی و فیزیک',
    'علوم تجربی',
    'ادبیات و علوم انسانی',
  ]; // <-- لیست رشته‌ها

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
                // حداقل ارتفاع صفحه را برای چیدمان صحیح تضمین می‌کند
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween, // <-- اضافه شد
                  children: [
                    // این Column برای محتوای بالا و وسط است
                    Column(
                      children: [
                        // Header Image (top)
                        SizedBox(
                          height: 140, // کاهش از 200 به 140
                          child: Center(
                            child: Image.asset(
                              'assets/images/headers/onboarding_step1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Gender Selection (middle)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'جنسیت خود را انتخاب کنید',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontFamily: 'IRANSansXFaNum',
                                  ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildGenderCard(
                                  'male',
                                  'آقا',
                                  'assets/images/avatars/male.png',
                                ),
                                _buildGenderCard(
                                  'female',
                                  'خانم',
                                  'assets/images/avatars/female.png',
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'پایه تحصیلی خود را انتخاب کنید',
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
                            _buildGradeDropdown(),
                            _buildFieldOfStudyDropdown(),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24), // <-- فاصله اضافه شد
                    // این Column برای دکمه و تیک‌ها در پایین صفحه است
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _canProceed()
                                ? _proceedToNextStep
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'بعدی',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'IRANSansXFaNum',
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildProgressIndicator(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard(String gender, String label, String imagePath) {
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: Container(
        width: 120,
        height: 140,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Image.asset(imagePath, width: 60, height: 60),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'IRANSansXFaNum',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeDropdown() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 32), // فاصله از کناره‌ها
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF3629B7), // رنگ آبی تم مرکزی
          width: 2,
        ),
        borderRadius: BorderRadius.circular(28), // نیم دایره (زاویه بیشتر)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedGrade,
          isExpanded: true,
          alignment: AlignmentDirectional.centerEnd,
          selectedItemBuilder: (context) {
            return _grades.map((grade) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'پایه $grade',
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
          // افزایش ارتفاع منو برای نمایش همه آیتم‌ها
          menuMaxHeight: 300.0,
          items: _grades.map((grade) {
            return DropdownMenuItem<int>(
              value: grade,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                'پایه $grade',
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontFamily: 'IRANSansXFaNum'),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              if (value != null) {
                _selectedGrade = value;
                // اگر پایه کمتر از دهم انتخاب شد، رشته تحصیلی رو به پیش‌فرض برگردون
                if (value < 10) {
                  _selectedFieldOfStudy = 'ریاضی و فیزیک';
                }
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildFieldOfStudyDropdown() {
    // این ویجت فقط زمانی نمایش داده می‌شود که نیاز باشد
    if (_selectedGrade < 10) {
      return const SizedBox.shrink(); // اگر پایه کمتر از دهم است، چیزی نمایش نده
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24), // فاصله بین دو دراپ‌داون
        SizedBox(
          width: double.infinity, // <-- اضافه شد تا نوشته وسط‌چین شود
          child: Text(
            'رشته تحصیلی خود را انتخاب کنید',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.black, // مشکی مطلق
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'IRANSansXFaNum',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(
            horizontal: 32,
          ), // فاصله از کناره‌ها
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF3629B7), // رنگ آبی تم مرکزی
              width: 2,
            ),
            borderRadius: BorderRadius.circular(28), // نیم دایره (زاویه بیشتر)
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFieldOfStudy,
              isExpanded: true,
              alignment: AlignmentDirectional.centerEnd,
              selectedItemBuilder: (context) {
                return _fieldsOfStudy.map((field) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      field,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'IRANSansXFaNum',
                        color: const Color(
                          0xFF3629B7,
                        ), // رنگ متن انتخاب شده آبی
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList();
              },
              items: _fieldsOfStudy.map((field) {
                return DropdownMenuItem<String>(
                  value: field,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    field,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  if (value != null) {
                    _selectedFieldOfStudy = value;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildProgressStep('تکمیل اطلاعات', false),
        _buildProgressStep('اطلاعات پایه', false),
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
            color: isCompleted
                ? Colors.white
                : Colors.grey.shade400, // <-- اصلاح شد
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

  bool _canProceed() {
    // فقط جنسیت باید انتخاب بشه (پایه و رشته پیش‌فرض دارن)
    return _selectedGender != null && !_isLoading;
  }

  Future<void> _proceedToNextStep() async {
    if (!_canProceed()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = context.read<AppStateManager>();

      // اگه پایه کمتر از 10 بود، رشته رو null بفرست
      final fieldToSend = _selectedGrade >= 10 ? _selectedFieldOfStudy : null;

      await appState.authService.completeStep1(
        gender: _selectedGender!,
        grade: _selectedGrade,
        fieldOfStudy: fieldToSend,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding/step2');
      }
    } on AuthServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
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
