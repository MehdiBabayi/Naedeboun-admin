import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/logger.dart';

import '../../models/data/iran_provinces.dart';
import '../../providers/core/app_state_manager.dart';
import '../../widgets/bubble_nav_bar.dart';
import '../../utils/grade_utils.dart'; // وارد کردن فایل کمکی
import '../../services/config/config_service.dart';
import '../../services/session_service.dart';
import 'report_error_webview_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  /// دریافت شماره تلفن کاربر از SessionService
  Future<String> _getUserPhoneNumber() async {
    try {
      final profileData = SessionService.instance.getUserProfile();
      String phoneNumber = profileData?['phone_number'] as String? ?? '';

      // تبدیل +98 به 0
      if (phoneNumber.startsWith('+98')) {
        phoneNumber = '0${phoneNumber.substring(3)}';
      }

      return phoneNumber;
    } catch (e) {
      return '';
    }
  }

  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  // Selected values for dropdowns
  String? _selectedGender;
  String? _selectedGrade;
  String? _selectedProvince;
  String? _selectedCity;

  List<String> _cities = [];

  // لیست پایه‌ها با رشته برای دهم، یازدهم و دوازدهم (مثل هوم)
  final List<String> _allGrades = [
    'اول',
    'دوم',
    'سوم',
    'چهارم',
    'پنجم',
    'ششم',
    'هفتم',
    'هشتم',
    'نهم',
    'دهم - ریاضی',
    'دهم - تجربی',
    'دهم - انسانی',
    'یازدهم - ریاضی',
    'یازدهم - تجربی',
    'یازدهم - انسانی',
    'دوازدهم - ریاضی',
    'دوازدهم - تجربی',
    'دوازدهم - انسانی',
  ];

  // Future for loading profile data
  late Future<void> _loadProfileFuture;

  bool _isUpdating = false;

  /// بررسی اینکه آیا رشته باید نمایش داده بشه یا نه
  /// فقط پایه دهم تا دوازدهم رشته دارن
  bool _shouldShowTrack(String? grade) {
    if (grade == null) return false;

    // پایه اول تا نهم رشته ندارن
    final gradesWithoutTrack = [
      'اول',
      'دوم',
      'سوم',
      'چهارم',
      'پنجم',
      'ششم',
      'هفتم',
      'هشتم',
      'نهم',
    ];

    // اگر پایه اول تا نهم بود، رشته نمایش نده
    return !gradesWithoutTrack.contains(grade);
  }

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    // Start loading profile data and update the state upon completion
    _loadProfileFuture = _loadUserProfile().then((_) {
      if (context.mounted) {
        setState(() {
          // This will rebuild the widget with the loaded data
        });
      }
    });
  }

  Future<void> _loadUserProfile() async {
    // This method now only fetches and sets the data.
    // The setState in initState's `then` block will handle the rebuild.
    final profile = context.read<AppStateManager>().authService.currentProfile;
    if (profile == null) return;

    _firstNameController.text = profile.firstName ?? '';
    _lastNameController.text = profile.lastName ?? '';

    // Convert gender from 'male'/'female' to Persian for display
    if (profile.gender == 'male') {
      _selectedGender = 'آقا';
    } else if (profile.gender == 'female') {
      _selectedGender = 'خانم';
    } else {
      _selectedGender = null;
    }

    // Convert grade from int to Persian String with field of study
    final gradeName = mapGradeIntToString(profile.grade);
    if (gradeName != null) {
      final fieldOfStudy = profile.fieldOfStudy;

      if (fieldOfStudy != null && _shouldShowTrack(gradeName)) {
        // تبدیل نام کامل به نام کوتاه
        String shortTrack;
        switch (fieldOfStudy) {
          case 'ریاضی و فیزیک':
            shortTrack = 'ریاضی';
            break;
          case 'علوم تجربی':
            shortTrack = 'تجربی';
            break;
          case 'ادبیات و علوم انسانی':
            shortTrack = 'انسانی';
            break;
          default:
            shortTrack = fieldOfStudy;
        }
        _selectedGrade = '$gradeName - $shortTrack';
      } else {
        _selectedGrade = gradeName;
      }
    } else {
      _selectedGrade = null;
    }

    _selectedProvince =
        (profile.province != null &&
            IranProvinces.provinces.containsKey(profile.province))
        ? profile.province
        : null;

    if (_selectedProvince != null) {
      _cities = IranProvinces.provinces[_selectedProvince!] ?? [];
      _selectedCity = (profile.city != null && _cities.contains(profile.city))
          ? profile.city
          : null;
    } else {
      _cities = [];
      _selectedCity = null;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkBlue = const Color(0xFF3629B7); // آبی از تم مرکزی

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _getUserPhoneNumber(),
          builder: (context, snapshot) {
            final phoneNumber = snapshot.data ?? '';

            // تبدیل اعداد انگلیسی به فارسی
            String convertToPersianNumbers(String text) {
              const persianDigits = [
                '۰',
                '۱',
                '۲',
                '۳',
                '۴',
                '۵',
                '۶',
                '۷',
                '۸',
                '۹',
              ];
              const latinDigits = [
                '0',
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
              ];

              for (int i = 0; i < latinDigits.length; i++) {
                text = text.replaceAll(latinDigits[i], persianDigits[i]);
              }
              return text;
            }

            final persianPhone = convertToPersianNumbers(phoneNumber);

            return Text(
              phoneNumber.isNotEmpty
                  ? 'حساب کاربری ($persianPhone)'
                  : 'حساب کاربری',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'IRANSansXFaNum',
                fontSize: 16, // کاهش اندازه فونت
              ),
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Transform.flip(flipX: true, child: Icon(Icons.logout_rounded)),
          tooltip: 'خروج از حساب کاربری',
          onPressed: () async {
            // نمایش دیالوگ تایید
            final shouldLogout = await showDialog<bool>(
              context: context,
              builder: (context) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  title: Text(
                    'خروج از حساب کاربری',
                    style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                  ),
                  content: Text(
                    'آیا مطمئن هستید که می‌خواهید از حساب کاربری خود خارج شوید؟',
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('انصراف'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('خروج'),
                    ),
                  ],
                ),
              ),
            );

            if (!context.mounted) return;
            if (shouldLogout == true) {
              // خروج از حساب کاربری
              final authService = context.read<AppStateManager>().authService;
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamedAndRemoveUntil('/auth', (route) => false);
              }
            }
          },
        ),
        actions: [],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkBlue, Colors.white],
            stops: const [0.5, 0.5],
          ),
        ),
        child: Column(
          children: [
            // هدر با عکس
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              color: darkBlue,
              child: Center(
                child: Image.asset(
                  'assets/images/headers/profile-header.png',
                  height: 140, // بزرگ‌تر کردم از 120 به 140
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.person_pin_rounded,
                    size: 140, // آیکون هم بزرگ‌تر کردم
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            // محتوای اصلی
            Expanded(
              child: Container(
                color: darkBlue,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: FutureBuilder<void>(
                    future: _loadProfileFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'خطا در بارگذاری اطلاعات: ${snapshot.error}',
                          ),
                        );
                      }
                      // After data is loaded, build the main content
                      return SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _lastNameController,
                                        label: 'نام خانوادگی',
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _firstNameController,
                                        label: 'نام',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField(
                                        label: 'جنسیت',
                                        value: _selectedGender,
                                        items: ['آقا', 'خانم'],
                                        onChanged: (value) => setState(
                                          () => _selectedGender = value,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildDropdownField(
                                        label: 'پایه',
                                        value: _selectedGrade,
                                        items: _allGrades,
                                        onChanged: (value) {
                                          setState(
                                            () => _selectedGrade = value,
                                          );
                                          // فقط state محلی رو آپدیت می‌کنیم
                                          // آپدیت واقعی با دکمه "ویرایش" انجام میشه
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField(
                                        label: 'شهر',
                                        value: _selectedCity,
                                        items: _cities,
                                        onChanged: (value) => setState(
                                          () => _selectedCity = value,
                                        ),
                                        disabled: _selectedProvince == null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildDropdownField(
                                        label: 'استان',
                                        value: _selectedProvince,
                                        items: IranProvinces.provinces.keys
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedProvince = value;
                                            _selectedCity = null;
                                            _cities =
                                                IranProvinces
                                                    .provinces[value!] ??
                                                [];
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(context),
          _buildContactButtons(context),
          BubbleNavBar(
            currentIndex: 3,
            onTap: (i) {
              if (i == 0) {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
              } else if (i == 1) {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/provincial-sample');
              } else if (i == 2) {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/step-by-step');
              } else if (i == 3) {
                // در پروفایل هستیم
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final darkBlue = const Color(0xFF3629B7); // آبی از تم مرکزی

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _handleUpdateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: darkBlue, // همان رنگ هدر
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 4,
        ),
        child: _isUpdating
            ? CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'ویرایش',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildContactButtons(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24,
      ), // فاصله از بالا و پایین بیشتر
      child: Row(
        children: [
          // دکمه سبز - ارتباط با ما (واتساپ)
          Expanded(
            child: Container(
              height: 56,
              margin: const EdgeInsets.only(left: 6), // فاصله بین دکمه‌ها کمتر
              child: ElevatedButton(
                onPressed: _openWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: Colors.green.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // متن اول (سمت راست)
                    Expanded(
                      child: Text(
                        'ارتباط با ما (واتساپ)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IRANSansXFaNum',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // آیکون بعد (سمت چپ)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.phone, color: Colors.green, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12), // فاصله بین دکمه‌ها
          // دکمه قرمز - گزارش خطا
          Expanded(
            child: Container(
              height: 56,
              margin: const EdgeInsets.only(right: 6), // فاصله بین دکمه‌ها کمتر
              child: ElevatedButton(
                onPressed: _reportError,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: Colors.red.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // متن اول (سمت راست)
                    Expanded(
                      child: Text(
                        'گزارش خطا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IRANSansXFaNum',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // آیکون بعد (سمت چپ)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    try {
      final whatsappNumber =
          ConfigService.instance.getValue<String>('whatsappNumber') ??
          '+989981654321';

      Logger.info('📱 Opening WhatsApp app directly: $whatsappNumber');

      // حذف + و فاصه‌ها از شماره
      final cleanNumber = whatsappNumber
          .replaceAll('+', '')
          .replaceAll(' ', '');

      Logger.debug('🔍 Clean number: $cleanNumber');

      // استفاده از url_launcher برای باز کردن واتساپ
      final whatsappUrl = Uri.parse('https://wa.me/$cleanNumber');

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        Logger.info('✅ WhatsApp opened successfully!');
      } else {
        throw Exception('Cannot launch WhatsApp');
      }
    } catch (e) {
      Logger.error('❌ Error opening WhatsApp', e);
      if (!context.mounted) return;

      // اگه واتساپ نصب نبود یا خطا داد
      if (context.mounted) {
        // شماره رو کپی کن
        final whatsappNumber =
            ConfigService.instance.getValue<String>('whatsappNumber') ??
            '+989981654321';
        await Clipboard.setData(ClipboardData(text: whatsappNumber));
        if (!context.mounted) return;

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'واتساپ نصب نیست یا باز نشد.\nشماره کپی شد: $whatsappNumber',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'دانلود واتساپ',
              textColor: Colors.white,
              onPressed: () => _openWhatsAppDownload(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsAppDownload() async {
    try {
      final playStoreUrl =
          'https://play.google.com/store/apps/details?id=com.whatsapp';
      final uri = Uri.parse(playStoreUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // اگه play store هم باز نشد، URL رو کپی کن
        await Clipboard.setData(ClipboardData(text: playStoreUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لینک دانلود واتساپ کپی شد',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('❌ Error opening WhatsApp download', e);
    }
  }

  /// باز کردن صفحه گزارش خطا با WebView جدید که از آپلود فایل پشتیبانی می‌کند
  Future<void> _reportError() async {
    try {
      Logger.info('🔍 Opening report error page in-app');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ReportErrorWebViewScreen(),
        ),
      );
    } catch (e) {
      Logger.error('❌ Error opening in-app browser', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در باز کردن صفحه: $e',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Map Persian gender to English before sending
      String? genderInEnglish;
      if (_selectedGender == 'آقا') {
        genderInEnglish = 'male';
      } else if (_selectedGender == 'خانم') {
        genderInEnglish = 'female';
      }

      // پردازش پایه و رشته
      int? gradeInt;
      String? fieldOfStudy;

      if (_selectedGrade != null) {
        if (_selectedGrade!.contains(' - ')) {
          // پایه با رشته (مثل 'دهم - ریاضی')
          final parts = _selectedGrade!.split(' - ');
          gradeInt = mapGradeStringToInt(parts[0]);
          final shortTrack = parts[1];

          // تبدیل نام کوتاه به نام کامل
          switch (shortTrack) {
            case 'ریاضی':
              fieldOfStudy = 'ریاضی و فیزیک';
              break;
            case 'تجربی':
              fieldOfStudy = 'علوم تجربی';
              break;
            case 'انسانی':
              fieldOfStudy = 'ادبیات و علوم انسانی';
              break;
          }
        } else {
          // فقط پایه (مثل 'اول')
          gradeInt = mapGradeStringToInt(_selectedGrade!);
        }
      }

      final updates = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'gender': genderInEnglish,
        'grade': gradeInt,
        if (fieldOfStudy != null) 'field_of_study': fieldOfStudy,
        'province': _selectedProvince,
        'city': _selectedCity,
      };

      // Remove null values to avoid overwriting existing data with null
      updates.removeWhere((key, value) => value == null);

      await context.read<AppStateManager>().authService.updateProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'پروفایل با موفقیت به‌روز شد!',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در به‌روزرسانی: $e',
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
        setState(() => _isUpdating = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.right, // راست‌چین کردن متن
        decoration: _inputDecoration(label),
        keyboardType: TextInputType.text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontFamily: 'IRANSansXFaNum',
        ), // رنگ متن ورودی
        maxLength: 15,
        inputFormatters: [
          LengthLimitingTextInputFormatter(15),
          FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]')),
        ],
        validator: (value) {
          final v = (value ?? '').trim();
          if (v.length > 15) return 'بیشتر از ۱۵ حرف غیرمجاز است';
          if (!RegExp(r'^[\u0600-\u06FF\s-]*$').hasMatch(v)) {
            return 'فقط حروف فارسی و فاصله مجاز است';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool disabled = false,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        hint: Text(
          label,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontFamily: 'IRANSansXFaNum',
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    item,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: disabled ? null : onChanged,
        decoration: _inputDecoration(label),
        isExpanded: true,
        menuMaxHeight: 200, // کمتر از 300 تا از کادر نزنه بیرون
        validator: (value) {
          if (value == null) {
            return '$label را انتخاب کنید';
          }
          return null;
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: primaryColor,
        textBaseline: TextBaseline.alphabetic,
        fontFamily: 'IRANSansXFaNum',
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: BorderSide(
          color: primaryColor.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: BorderSide(
          color: primaryColor.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      alignLabelWithHint: true,
    );
  }
}
