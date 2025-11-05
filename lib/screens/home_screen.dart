import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/core/app_state_manager.dart';
import 'package:nardeboun/services/content/content_service.dart';
import 'package:nardeboun/models/content/subject.dart';
import 'package:nardeboun/utils/grade_utils.dart';
import 'dart:async';
import '../widgets/bubble_nav_bar.dart';
import '../services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/preload/preload_service.dart';
import '../exceptions/error_handler.dart';
import '../widgets/common/empty_state_widget.dart';
import '../../utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Subject> _subjects = const [];

  // کش برای چک کردن حد مجاز تغییر پایه
  bool? _isGradeChangeAllowed;
  DateTime? _lastGradeChangeCheck;

  // مدیریت async operations برای جلوگیری از تداخل navigation
  bool _isProcessingGradeChange = false;
  bool _isLoadingSubjects = false;

  // تاخیر برای نمایش ویجیت خالی محتوا
  bool _showEmptyState = false;
  Timer? _emptyStateTimer;

  bool _isAnyAsyncOperationRunning() {
    return _isProcessingGradeChange || _isLoadingSubjects;
  }

  Future<bool> _checkGradeChangeLimit() async {
    if (_isGradeChangeAllowed != null &&
        _lastGradeChangeCheck != null &&
        DateTime.now().difference(_lastGradeChangeCheck!) <
            const Duration(minutes: 5)) {
      return _isGradeChangeAllowed!;
    }

    // به صورت موقت اجازه تغییر پایه داده می‌شود؛ در صورت نیاز منطق واقعی را در SessionService پیاده‌سازی کنید
    final isAllowed = true;
    if (mounted) {
      setState(() {
        _isGradeChangeAllowed = isAllowed;
        _lastGradeChangeCheck = DateTime.now();
      });
    }
    return isAllowed;
  }

  // لیست پایه‌ها با رشته برای دهم، یازدهم و دوازدهم
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

  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubjects();
      _startPreloading();
    });
  }

  /// بررسی احراز هویت و هدایت به صفحه مناسب
  Future<void> _checkAuthAndRedirect() async {
    // کمی تاخیر برای اطمینان از init شدن context
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final appState = context.read<AppStateManager>();

    Logger.debug('🔍 [HOME] Checking auth...');
    Logger.debug(
      '🔍 [HOME] isUserAuthenticated: ${appState.isUserAuthenticated}',
    );

    if (!appState.isUserAuthenticated) {
      Logger.debug('🔍 [HOME] User not authenticated -> redirecting to /auth');
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
      return;
    }

    Logger.debug('🔍 [HOME] Auth OK -> staying in Home');
  }

  /// شروع Preloading برای بهبود سرعت navigation
  void _startPreloading() {
    // Preloading در background اجرا می‌شود
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        if (!mounted) return;
        final appState = context.read<AppStateManager>();
        final profile = appState.authService.currentProfile;

        if (profile?.grade != null) {
          await PreloadService.instance.preloadForNextNavigation(
            currentGradeId: profile!.grade!,
            currentTrackId: _mapFieldOfStudyToTrackId(profile.fieldOfStudy),
          );
        }
      } catch (e) {
        Logger.error('⚠️ [PRELOAD] Error in background preloading', e);
      }
    });
  }

  @override
  void dispose() {
    _emptyStateTimer?.cancel();
    super.dispose();
  }

  /// بررسی اینکه آیا رشته باید نمایش داده بشه یا نه
  /// فقط پایه دهم تا دوازدهم رشته دارن
  bool _shouldShowTrack(String? grade) {
    if (grade == null) return false;

    // پایه اول تا نهم رشته ندارن
    final gradesWithoutTrack = [
      'پایه اول',
      'پایه دوم',
      'پایه سوم',
      'پایه چهارم',
      'پایه پنجم',
      'پایه ششم',
      'پایه هفتم',
      'پایه هشتم',
      'پایه نهم',
    ];

    // اگر پایه اول تا نهم بود، رشته نمایش نده
    return !gradesWithoutTrack.any(
      (gradeWithoutTrack) => grade.contains(gradeWithoutTrack),
    );
  }

  // Pull-to-refresh removed - data managed by Mini-Request system

  Future<void> _loadSubjects() async {
    // اگر قبلاً لود شده، دوباره لود نکن
    if (_subjects.isNotEmpty) {
      Logger.debug('🚀 [HOME] Subjects already loaded, skipping...');
      return;
    }

    try {
      setState(() => _isLoadingSubjects = true);
      final appState = context.read<AppStateManager>();
      final profile = appState.authService.currentProfile;
      final gradeId = profile?.grade ?? 7;
      final int? trackId = null;

      // ✅ تغییر: مستقیماً از Supabase بخوان (بدون cache)
      final contentService = ContentService(Supabase.instance.client);
      final subjects = await contentService.getSubjectsForUser(
        gradeId: gradeId,
        trackId: trackId,
      );

      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _showEmptyState = subjects.isEmpty;
      });

      if (subjects.isEmpty && mounted) {
        _startEmptyStateTimer();
      } else {
        _emptyStateTimer?.cancel();
      }

      Logger.debug(
        '✅ [HOME] Subjects loaded from Supabase: ${subjects.length}',
      );
    } catch (e) {
      Logger.error('❌ [HOME] Error loading subjects', e);
      if (mounted) {
        _startEmptyStateTimer();
      }
    } finally {
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  /// شروع تایمر برای نمایش ویجیت خالی محتوا
  void _startEmptyStateTimer() {
    _emptyStateTimer?.cancel(); // تایمر قبلی را لغو کن
    _emptyStateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _subjects.isEmpty) {
        setState(() {
          _showEmptyState = true;
        });
        Logger.debug(
          '⏰ [HOME] Empty state timer triggered - showing empty widget',
        );
      }
    });
    Logger.debug('⏰ [HOME] Empty state timer started (2 seconds)');
  }

  int? _mapFieldOfStudyToTrackId(String? fieldOfStudy) {
    if (fieldOfStudy == null) return null;
    switch (fieldOfStudy) {
      case 'ریاضی':
        return 1;
      case 'تجربی':
        return 2;
      case 'انسانی':
        return 3;
      default:
        return null;
    }
  }

  String _truncatePersian(String text, int maxChars) {
    if (text.runes.length <= maxChars) return text;
    final itr = text.runes.take(maxChars);
    return '${String.fromCharCodes(itr)}…';
  }

  void _updateUserGrade(String selectedGrade) async {
    // اول چک کن آیا مجاز هست یا نه
    final isAllowed = await _checkGradeChangeLimit();

    if (!isAllowed) {
      if (mounted) {
        ErrorHandler.show(
          context,
          'درخواست تغییر پایه شما بیش از حد مجاز است.\nلطفاً فردا اقدام کنید.',
        );
      }
      return;
    }

    // چک کن آیا عملیات async در حال انجام هست
    if (_isAnyAsyncOperationRunning()) {
      if (mounted) {
        ErrorHandler.show(context, 'لطفاً صبر کنید تا عملیات قبلی تمام شود.');
      }
      return;
    }

    // اگر مجاز بود، عملیات اصلی رو انجام بده
    _isProcessingGradeChange = true; // شروع عملیات

    try {
      if (!mounted) {
        _isProcessingGradeChange = false;
        return;
      }
      final appState = context.read<AppStateManager>();
      final profile = appState.authService.currentProfile;
      if (profile == null || !mounted) {
        _isProcessingGradeChange = false;
        return;
      }

      // selectedGrade حالا شامل پایه و رشته هست (مثل 'دهم - ریاضی')
      final gradeInt = mapGradeStringToInt(selectedGrade.split(' - ')[0]);
      String? fieldOfStudy;

      if (selectedGrade.contains(' - ')) {
        final shortTrack = selectedGrade.split(' - ')[1];
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
      }

      // پایه و رشته رو آپدیت کن
      final updates = {
        'grade': gradeInt,
        if (fieldOfStudy != null) 'field_of_study': fieldOfStudy,
      };
      await appState.authService.updateProfile(updates);
      if (!mounted) return;

      // ✅ تغییر: دیگر cache وجود ندارد، مستقیماً از Supabase استفاده می‌کنیم

      // پاک کردن subjects برای force reload
      setState(() {
        _subjects = [];
      });

      // ✅ تغییر: Mini-Request حذف شد، مستقیماً از Supabase استفاده می‌کنیم

      // بارگذاری مجدد محتوا
      await _loadSubjects();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'پایه با موفقیت تغییر کرد',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(
          context,
          'خطا در تغییر پایه: لطفاً دوباره تلاش کنید.',
        );
      }
    } finally {
      // پایان عملیات
      _isProcessingGradeChange = false;
    }
  }

  /// نمایش دیالوگ انتخاب پایه
  void _showGradeSelectionDialog(BuildContext context) {
    final appState = context.read<AppStateManager>();
    final profile = appState.authService.currentProfile;

    // پایه و رشته فعلی
    String currentGrade = 'اول';
    if (profile?.grade != null) {
      final gradeName = mapGradeIntToString(profile!.grade);
      final fieldOfStudy = profile.fieldOfStudy;

      if (gradeName != null) {
        if (fieldOfStudy != null &&
            ['دهم', 'یازدهم', 'دوازدهم'].contains(gradeName)) {
          // تبدیل نام کامل به نام کوتاه برای نمایش
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
          currentGrade = '$gradeName - $shortTrack';
        } else {
          currentGrade = gradeName;
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // عنوان دیالوگ
                Text(
                  'انتخاب پایه تحصیلی',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // لیست اسکرولی فقط پایه‌ها
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: ListView.separated(
                      itemCount: _allGrades.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final grade = _allGrades[index];
                        final isSelected = grade == currentGrade;

                        return ListTile(
                          title: Text(
                            grade,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontFamily: 'IRANSansXFaNum',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          selected: isSelected,
                          selectedTileColor: Theme.of(
                            context,
                            // ignore: deprecated_member_use
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          onTap: () {
                            // چک کن آیا عملیات async دیگری در حال انجام هست
                            if (_isAnyAsyncOperationRunning()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'لطفاً صبر کنید تا عملیات قبلی تمام شود.',
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                      fontFamily: 'IRANSansXFaNum',
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            Navigator.of(context).pop();
                            if (grade != currentGrade) {
                              // استفاده از addPostFrameCallback برای جلوگیری از Navigator Lock
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _updateUserGrade(grade);
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // دکمه بستن
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text(
                      'بستن',
                      style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final userProfile = appState.authService.currentProfile;

    // Convert grade to string for display (فقط پایه)
    String gradeString = 'پایه ثبت نشده';
    String? trackString;
    if (userProfile?.grade != null) {
      final gradeName = mapGradeIntToString(userProfile!.grade);
      final trackName = userProfile.fieldOfStudy;
      gradeString = 'پایه $gradeName';
      if (trackName != null) {
        trackString = 'رشته $trackName';
      }
    }

    final darkBlue = const Color(0xFF3629B7); // آبی جدید

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // نمایش دیالوگ خروج
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text(
                'خروج از برنامه',
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
              content: const Text(
                'آیا مطمئن هستید که می‌خواهید از برنامه خارج شوید؟',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'خروج',
                    style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                  ),
                ),
              ],
            ),
          ),
        );

        if (shouldExit == true) {
          // فقط برنامه رو به background می‌فرستیم
          // بدون اینکه session clear بشه
          try {
            await SystemChannels.platform.invokeMethod(
              'SystemNavigator.pop',
              false,
            );
          } catch (e) {
            // fallback: minimize کردن برنامه
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                darkBlue, // نصف بالا آبی
                Colors.white, // نصف پایین سفید
              ],
              stops: const [0.5, 0.5], // خط تقسیم دقیقاً وسط
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                // ١. هدر آبی در بالا
                _buildTopBar(
                  context,
                  userProfile?.firstName ?? 'کاربر',
                  userProfile?.lastName ?? '',
                  userProfile?.gender ?? '',
                  gradeString,
                  trackString,
                ),

                // ٢. بخش اصلی که ظاهر همپوشانی را ایجاد می‌کند
                Expanded(child: _buildScrollableContent(darkBlue)),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BubbleNavBar(
          currentIndex: 0,
          onTap: (i) {
            if (i == 0) {
              // در خانه هستیم
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
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/edit-profile');
            }
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    String firstName,
    String lastName,
    String gender,
    String? grade,
    String? track,
  ) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 16, left: 16, bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // لوگو + نام برند در سمت راست (ترتیب صحیح برای RTL)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/icon/nardeboun.png', height: 40),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'نردبون - پنل مدیریت',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'IRANSansXFaNum',
                      ),
                    ),
                    const SizedBox(height: 4),
                    // فقط پایه کلیک پذیر
                    GestureDetector(
                      onTap: () => _showGradeSelectionDialog(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            grade ?? 'پایه ثبت نشده',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    // رشته فقط نمایشی (فقط برای پایه دهم تا دوازدهم)
                    if (track != null && _shouldShowTrack(grade)) ...{
                      const SizedBox(height: 2),
                      Text(
                        track,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    },
                  ],
                ),
              ],
            ),

            const Spacer(),

            // پروفایل کاربر در سمت چپ (ترتیب صحیح برای RTL)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _truncatePersian('$firstName $lastName', 40),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: ClipOval(
                        child: Image.asset(
                          _avatarPathForGender(gender),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/images/avatars/male.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableContent(Color darkBlue) {
    return Container(
      color: darkBlue,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // کانتینر اضافه کردن ویدیو (به‌جای بنر سابق)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () =>
                          Navigator.of(context).pushNamed('/video-upload'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'اضافه کردن ویدیو',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'IRANSansXFaNum',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            Icons.add_circle_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSubjectsGrid(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsGrid(BuildContext context) {
    // اگر در حال لودینگ است، loading indicator نمایش بده
    if (_isLoadingSubjects) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // اگر لیست خالی باشد و تایمر تمام شده، Empty State Widget نمایش بده
    if (_subjects.isEmpty && _showEmptyState) {
      return EmptyStateWidgets.noGradeContent(context);
    }

    // اگر لیست خالی باشد اما تایمر هنوز تمام نشده، loading indicator نمایش بده
    if (_subjects.isEmpty && !_showEmptyState) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    Theme.of(context);
    return GridView.builder(
      shrinkWrap: true, // برای کار کردن داخل SingleChildScrollView
      physics:
          const NeverScrollableScrollPhysics(), // برای جلوگیری از اسکرول تو در تو
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final s = _subjects[index];
        return _SubjectCard(
          subject: s,
          onTap: () async {
            // Resolve gradeId from name for now (simple):
            final appState = context.read<AppStateManager>();
            final profile = appState.authService.currentProfile;
            final gradeId = profile?.grade ?? 7;
            final trackId = null;

            // ذخیره آخرین درس انتخاب شده در Hive
            await SessionService.instance.saveLastSelectedSubject(s.toJson());
            await SessionService.instance.saveLastSelectedTrackId(trackId);

            // Check if widget is still mounted before navigation
            if (!context.mounted) return;

            Navigator.of(context).pushNamed(
              '/subject',
              arguments: {'subject': s, 'gradeId': gradeId, 'trackId': trackId},
            );
          },
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback? onTap;
  const _SubjectCard({required this.subject, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    context.read<AppStateManager>();

    String buildIconAssetPath() {
      // ساده: مستقیماً از iconPath دیتابیس استفاده کن
      if (subject.iconPath.isNotEmpty) {
        // اگر iconPath کامل است، مستقیماً استفاده کن
        if (subject.iconPath.startsWith('assets/')) {
          return subject.iconPath;
        }
        // اگر فقط نام فایل است، مسیر کامل بساز
        final path = 'assets/images/icon-darsha/${subject.iconPath}';
        return path;
      }

      // Fallback: اگر iconPath خالی بود، از slug استفاده کن
      final fallbackPath = 'assets/images/icon-darsha/${subject.slug}.png';
      return fallbackPath;
    }

    final iconAsset = buildIconAssetPath();
    return Container(
      decoration: BoxDecoration(
        color: const Color(
          0xFFF9FAFB,
        ), // هماهنگ‌سازی رنگ با پس‌زمینه نوار ناوبری
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Image.asset(
                  iconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // اگر عکس پیدا نشد، یک آیکون پیش‌فرض نمایش بده
                    return const Icon(
                      Icons.book_rounded,
                      size: 48,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subject.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _avatarPathForGender(String gender) {
  final g = gender.toLowerCase();
  if (g == 'male' || g == 'm' || g == 'آقا' || g == 'مرد' || g == 'پسر') {
    return 'assets/images/avatars/male.png';
  }
  if (g == 'female' || g == 'f' || g == 'خانم' || g == 'زن' || g == 'دختر') {
    return 'assets/images/avatars/female.png';
  }
  // پیش‌فرض: مرد
  return 'assets/images/avatars/male.png';
}
