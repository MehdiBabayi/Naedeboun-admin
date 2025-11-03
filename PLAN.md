# پلن کامل تبدیل اپلیکیشن محصول به اپلیکیشن ادمین

این فایل شامل پلن کامل، بررسی مشکلات، و کدهای نمونه برای اجرای پروژه است.

---

## 📋 فهرست مطالب

1. [مرحله 1: حذف فایل‌های گیت](#مرحله-1-حذف-فایلهای-گیت)
2. [مرحله 2: تحقیق ساختار دیتابیس و تبدیل کاربر به ادمین](#مرحله-2-تحقیق-ساختار-دیتابیس-و-تبدیل-کاربر-به-ادمین)
3. [مرحله 3: حذف کامل بخش بنر](#مرحله-3-حذف-کامل-بخش-بنر)
4. [مرحله 4: جایگزینی بنر با کانتینر آپلود ویدیو](#مرحله-4-جایگزینی-بنر-با-کانتینر-آپلود-ویدیو)
5. [مرحله 5: حذف onboarding و ثبت‌نام](#مرحله-5-حذف-onboarding-و-ثبتنام)

---

## مرحله 1: حذف فایل‌های گیت ✅

**وضعیت**: تکمیل شده

### اقدامات انجام شده:
- فولدر `.git` حذف شد
- فایل `.gitignore` نگه داشته شد (برای git init جدید لازم است)

### مشکل: ندارد

---

## مرحله 2: تحقیق ساختار دیتابیس و تبدیل کاربر به ادمین

### اقدامات:

#### 2.1. تحقیق ساختار جدول profiles
```powershell
npx supabase db inspect profiles
```

#### 2.2. تبدیل کاربر +989355053192 به ادمین
```powershell
npx supabase db execute "UPDATE profiles SET user_role = 'admin' WHERE phone_number = '+989355053192'"
```

### مشکلات شناسایی شده:

#### ⚠️ مشکل 2.1: چک ادمین در `auth_service.dart`
- **موقعیت**: بعد از خط 522 در `verifyOtp`
- **مشکل**: چک ادمین وجود ندارد
- **راه حل**: باید بعد از `_currentProfile = UserProfile.fromJson(profileJson)` چک شود

**کد اضافه شده در `lib/services/auth/auth_service.dart` بعد از خط 522:**

```dart
_currentUser = UserModel.fromJson(profileJson);
_currentProfile = UserProfile.fromJson(profileJson);

// چک کردن اینکه کاربر ادمین است یا نه
Logger.info("🔍 [AUTH] Checking user role: ${_currentProfile?.userRole}");
if (_currentProfile?.userRole != 'admin') {
  Logger.error("❌ [AUTH] User is not admin. Role: ${_currentProfile?.userRole}");
  // پاک کردن session و profile
  _currentUser = null;
  _currentProfile = null;
  await _clearSessionDataOnly();
  notifyListeners();
  throw AuthServiceException('شما اجازه دسترسی به پنل ادمین را ندارید. لطفا با شماره تلفن ادمین وارد شوید.');
}

Logger.info("✅ [AUTH] User is admin, access granted");
// notifyListeners() در خط 524 کد فعلی فراخوانی می‌شود - نیازی به فراخوانی دوباره نیست
```

#### ⚠️ مشکل 2.2: Navigation در `verify_otp_screen.dart`
- **موقعیت**: خط 144 - استفاده از `appropriateRoute`
- **مشکل**: بعد از چک ادمین، باید مستقیما به `/home` برود نه `appropriateRoute`
- **راه حل**: تغییر navigation به `/home` بعد از موفقیت لاگین

**تغییر در `lib/screens/auth/verify_otp_screen.dart`:**

**نکته مهم**: فقط بخش navigation را تغییر می‌دهیم، بقیه کد بدون تغییر باقی می‌ماند.

```dart
// در متد _verifyOtp، فقط این بخش را تغییر می‌دهیم (خطوط 138-148):

try {
  await authService.verifyOtp(widget.phoneNumber, otp, context: context);
  if (!mounted) return;
  _timer?.cancel();

  // تغییر: مستقیما به /home می‌رود (بدون استفاده از appropriateRoute)
  Logger.info("🔍 [OTP] Login successful, navigating to /home");
  Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
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
```

#### ⚠️ مشکل 2.3: `create-content` function
- **موقعیت**: `supabase/functions/create-content/index.ts` خط 20
- **مشکل**: style می‌تواند هم فارسی ('جزوه') و هم انگلیسی ('note') باشد
- **راه حل**: فقط از فارسی استفاده شود (طبق PHP)

---

## مرحله 3: حذف کامل بخش بنر

### فایل‌های حذف شونده:

1. ✅ `lib/services/content/banner_service.dart`
2. ✅ `lib/services/mini_request/mini_request_service.dart`
3. ✅ `lib/services/mini_request/mini_request_logger.dart`
4. ⚠️ `lib/services/image_cache/smart_image_cache_service.dart` (بررسی: اگر فقط برای بنر است)
5. ✅ `lib/models/content/banner.dart`
6. ✅ `lib/widgets/banner/cached_banner.dart`

### مشکلات شناسایی شده:

#### ⚠️ مشکل 3.1: وابستگی در `cached_content_service.dart`
- **خط 6**: import `banner_service.dart` - باید حذف شود
- **خط 11**: import `banner.dart` - باید حذف شود
- **خط 22**: `static final BannerService _bannerService` - باید حذف شود
- **خطوط 196-221**: متد `getActiveBannersForGrade` - باید حذف شود
- **خطوط 439-448**: متدهای `refreshBannersCache` و `refreshBannersForGrade` - باید بررسی و حذف شوند
- **خطوط 489-494**: متد `hasBannersCache` - باید بررسی و حذف شود

#### ⚠️ مشکل 3.2: تغییرات در `home_screen.dart`

**حذف موارد زیر:**
- خط 7: import `banner.dart`
- خط 12: import `cached_banner.dart`
- خط 34: `List<AppBanner> _banners`
- خط 35: `PageController _bannerController`
- خط 37: `int _bannerIndex`
- خط 38: `Timer? _bannerTimer`
- خط 47: `bool _isLoadingBanners`
- خط 54: استفاده از `_isLoadingBanners` در `_isAnyAsyncOperationRunning`
- خط 102: ایجاد `_bannerController`
- خط 105: فراخوانی `_loadBanners()`
- خط 106: فراخوانی `_startBannerTimer()`
- خط 146-148: متد `_startBannerTimer()`
- خط 173: `_bannerTimer?.cancel()`
- خط 175: `_bannerController.dispose()`
- خط 303-349: متد `_loadBanners()` کامل
- خط 420: استفاده از `_banners` در force reload
- خط 633-852: متد `_handleBannerTap()` کامل
- خط 854-910: متد `_handleExternalBannerTap()` کامل

**نکته مهم**: خط 237 استفاده از `SmartImageCacheService` برای book covers - **این باید نگه داشته شود** (برای book covers است نه بنر)

#### ⚠️ مشکل 3.3: استفاده از `MiniRequestService`
- **خط 429**: `MiniRequestService.instance.checkForUpdates()` - بررسی: اگر فقط برای بنر است حذف شود
- **خط 439**: `MiniRequestService.instance.prefetchBookCoversForGrade()` - این برای book covers است، باید نگه داشته شود

---

## مرحله 4: جایگزینی بنر با کانتینر آپلود ویدیو

### مشکلات شناسایی شده:

#### ⚠️ مشکل 4.1: Service Role Key
- **مشکل**: در `api_keys.dart` فیلد `supaBaseServiceRoleKey` وجود ندارد
- **راه حل**: از `supabase.functions.invoke` با anon key استفاده می‌شود (Supabase function خود از service role استفاده می‌کند)

#### ⚠️ مشکل 4.2: لیست دروس ناقص
- **مشکل**: لیست دروس در کد نمونه ناقص است (فقط 3 درس)
- **راه حل**: باید تمام 32 درس از PHP اضافه شود

#### ⚠️ مشکل 4.3: اعتبارسنجی PDF
- **مشکل**: در `VideoUploadFormData.validate()` PDF برای جزوه و نمونه سوال الزامی است
- **اما**: در PHP این الزامی نیست (فقط توصیه می‌شود)
- **راه حل**: اعتبارسنجی PDF را اختیاری می‌کنیم

### فایل جدید: `lib/services/video_upload/video_upload_service.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس آپلود ویدیو بر اساس منطق PHP
class VideoUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// ارسال ویدیو به سرور
  /// تمام اعتبارسنجی‌ها و محدودیت‌ها از PHP گرفته شده
  Future<Map<String, dynamic>> uploadVideo({
    required String branch, // ابتدایی، متوسطه اول، متوسطه دوم
    required String grade, // یکم، دوم، ...، دوازدهم
    String? track, // ریاضی، تجربی، انسانی یا null
    required String subject, // نام فارسی درس
    required String subjectSlug, // اسلاگ درس
    required String chapterTitle, // عنوان فصل
    required int chapterOrder, // شماره فصل
    required String style, // جزوه، نمونه سوال، کتاب درسی
    required String lessonTitle, // عنوان درس
    required int lessonOrder, // شماره درس
    required String teacherName, // نام استاد
    required int durationSec, // مدت زمان به ثانیه
    List<String>? tags, // تگ‌ها
    String? embedHtml, // کد embed آپارات
    String? notePdfUrl, // لینک PDF جزوه (فقط برای جزوه)
    String? exercisePdfUrl, // لینک PDF نمونه سوال (فقط برای نمونه سوال)
  }) async {
    try {
      Logger.info("🔍 [VIDEO-UPLOAD] Starting video upload");
      
      // اعتبارسنجی مدت زمان
      if (durationSec <= 0) {
        throw Exception('مدت زمان باید بیشتر از صفر باشد');
      }
      
      // مدیریت PDF بر اساس نوع محتوا
      String? finalNotePdfUrl;
      String? finalExercisePdfUrl;
      
      if (style == 'جزوه') {
        finalNotePdfUrl = notePdfUrl;
        finalExercisePdfUrl = null;
      } else if (style == 'نمونه سوال') {
        finalNotePdfUrl = null;
        finalExercisePdfUrl = exercisePdfUrl;
      } else {
        // کتاب درسی
        finalNotePdfUrl = null;
        finalExercisePdfUrl = null;
      }
      
      // تبدیل track به null اگر "بدون رشته" باشد
      String? finalTrack = (track == 'بدون رشته' || track == null || track.isEmpty) 
          ? null 
          : track;
      
      // ساخت payload بر اساس PHP
      final payload = {
        "branch": branch,
        "grade": grade,
        "track": finalTrack,
        "subject": subject,
        "subject_slug": subjectSlug,
        "chapter_title": chapterTitle,
        "chapter_order": chapterOrder,
        "lesson_title": lessonTitle,
        "lesson_order": lessonOrder,
        "teacher_name": teacherName,
        "style": style,
        "duration_sec": durationSec,
        "tags": tags ?? [],
        "embed_html": embedHtml,
        "allow_landscape": true,
        "note_pdf_url": finalNotePdfUrl,
        "exercise_pdf_url": finalExercisePdfUrl,
        "aparat_url": "", // رشته خالی طبق PHP
      };
      
      Logger.info("🔍 [VIDEO-UPLOAD] Payload: $payload");
      
      // ارسال به Supabase function با anon key
      final response = await _supabase.functions.invoke(
        'create-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info("✅ [VIDEO-UPLOAD] Video uploaded successfully");
          return data;
        } else {
          final error = data?['error'] ?? 'خطای ناشناخته';
          Logger.error("❌ [VIDEO-UPLOAD] Upload failed: $error");
          throw Exception(error);
        }
      } else {
        Logger.error("❌ [VIDEO-UPLOAD] HTTP error: ${response.status}");
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error("❌ [VIDEO-UPLOAD] Error uploading video", e);
      rethrow;
    }
  }
}
```

### فایل جدید: `lib/models/video_upload/video_upload_form_data.dart`

```dart
/// مدل داده فرم آپلود ویدیو
class VideoUploadFormData {
  String? branch;
  String? grade;
  String? track;
  String? subject;
  String? subjectSlug;
  String? chapterTitle;
  int? chapterOrder;
  String? style; // جزوه، نمونه سوال، کتاب درسی
  String? lessonTitle;
  int? lessonOrder;
  String? teacherName;
  int? durationHours;
  int? durationMinutes;
  int? durationSeconds;
  String? tags; // با کاما جدا شده
  String? embedHtml;
  String? notePdfUrl;
  String? exercisePdfUrl;
  
  VideoUploadFormData();
  
  /// تبدیل مدت زمان به ثانیه
  int get durationInSeconds {
    final hours = durationHours ?? 0;
    final minutes = durationMinutes ?? 0;
    final seconds = durationSeconds ?? 0;
    return (hours * 3600) + (minutes * 60) + seconds;
  }
  
  /// تبدیل تگ‌ها به لیست
  List<String> get tagsList {
    if (tags == null || tags!.isEmpty) return [];
    return tags!
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
  
  /// اعتبارسنجی فرم (PDF اختیاری است طبق PHP)
  String? validate() {
    if (branch == null || branch!.isEmpty) return 'شاخه را انتخاب کنید';
    if (grade == null || grade!.isEmpty) return 'پایه را انتخاب کنید';
    if (subject == null || subject!.isEmpty) return 'درس را انتخاب کنید';
    if (subjectSlug == null || subjectSlug!.isEmpty) return 'اسلاگ درس را انتخاب کنید';
    if (chapterTitle == null || chapterTitle!.isEmpty) return 'عنوان فصل را وارد کنید';
    if (chapterOrder == null || chapterOrder! < 1) return 'شماره فصل را وارد کنید';
    if (style == null || style!.isEmpty) return 'نوع محتوا را انتخاب کنید';
    if (lessonTitle == null || lessonTitle!.isEmpty) return 'عنوان درس را وارد کنید';
    if (lessonOrder == null || lessonOrder! < 1) return 'شماره درس را وارد کنید';
    if (teacherName == null || teacherName!.isEmpty) return 'نام استاد را وارد کنید';
    if (durationInSeconds <= 0) return 'مدت زمان باید بیشتر از صفر باشد';
    
    // PDF اختیاری است (طبق PHP فقط توصیه می‌شود)
    // اعتبارسنجی PDF حذف شد
    
    return null; // فرم معتبر است
  }
}
```

### فایل جدید: `lib/screens/video_upload/video_upload_screen.dart`

**نکته**: این فایل باید کامل شود با تمام 32 درس از PHP (خطوط 117-152 فایل PHP)

```dart
import 'package:flutter/material.dart';
import '../../services/video_upload/video_upload_service.dart';
import '../../models/video_upload/video_upload_form_data.dart';
import '../../utils/logger.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formData = VideoUploadFormData();
  final _uploadService = VideoUploadService();
  bool _isUploading = false;
  
  // لیست کامل دروس فارسی و اسلاگ‌ها (32 درس از PHP)
  final Map<String, String> _subjectOptions = {
    'ریاضی': 'riazi',
    'علوم': 'olom',
    'فارسی': 'farsi',
    'قرآن': 'quran',
    'مطالعات اجتماعی': 'motaleat',
    'هدیه های آسمانی': 'hediye',
    'نگارش': 'negaresh',
    'عربی': 'arabi',
    'انگلیسی': 'englisi',
    'دینی': 'dini',
    'فیزیک': 'fizik',
    'شیمی': 'shimi',
    'هندسه': 'hendese',
    'هنر': 'honar',
    'جغرافیا': 'joghrafia',
    'فناوری': 'fanavari',
    'تفکر و سبک زندگی': 'tafakor',
    'حسابان': 'hesaban',
    'زمین شناسی': 'zamin',
    'محیط زیست': 'mohit',
    'تاریخ': 'tarikh',
    'سلامت و بهداشت': 'salamat',
    'هویت اجتماعی': 'hoviat',
    'مدیریت خانواده': 'modiriat',
    'ریاضیات گسسته': 'gosaste',
    'آمادگی دفاعی': 'amadegi',
    'اقتصاد': 'eghtesad',
    'علوم و فنون ادبی': 'fonon',
    'جامعه شناسی': 'jameye',
    'کارگاه کارآفرینی': 'kargah',
    'منطق': 'mantegh',
    'فلسفه': 'falsafe',
    'روانشناسی': 'ravanshenasi',
    'زیست شناسی': 'zist',
  };
  
  // داده‌های پایه‌ها (از PHP)
  final Map<String, List<String>> _gradesData = {
    'ابتدایی': ['یکم', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم'],
    'متوسطه اول': ['هفتم', 'هشتم', 'نهم'],
    'متوسطه دوم': ['دهم', 'یازدهم', 'دوازدهم'],
  };
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'آپلود ویدیو',
          style: TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // فیلدهای فرم طبق PHP - باید کامل شود
            // شاخه، پایه، رشته، درس، فصل، درس، استاد، مدت زمان، تگ‌ها، embed، PDFها
            
            // دکمه ارسال
            ElevatedButton(
              onPressed: _isUploading ? null : _handleSubmit,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('ارسال ویدیو'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final error = _formData.validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      await _uploadService.uploadVideo(
        branch: _formData.branch!,
        grade: _formData.grade!,
        track: _formData.track,
        subject: _formData.subject!,
        subjectSlug: _formData.subjectSlug!,
        chapterTitle: _formData.chapterTitle!,
        chapterOrder: _formData.chapterOrder!,
        style: _formData.style!,
        lessonTitle: _formData.lessonTitle!,
        lessonOrder: _formData.lessonOrder!,
        teacherName: _formData.teacherName!,
        durationSec: _formData.durationInSeconds,
        tags: _formData.tagsList,
        embedHtml: _formData.embedHtml,
        notePdfUrl: _formData.notePdfUrl,
        exercisePdfUrl: _formData.exercisePdfUrl,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ ویدیو با موفقیت ثبت شد')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      Logger.error("❌ [VIDEO-UPLOAD] Error", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطا: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
```

### تغییرات در `lib/screens/home_screen.dart`:

**1. حذف متغیرها و متدهای مرتبط با بنر:**

```dart
// حذف از state class:
// - List<AppBanner> _banners
// - PageController _bannerController
// - int _bannerIndex
// - Timer? _bannerTimer
// - bool _isLoadingBanners

// حذف از initState:
// - _bannerController = PageController(viewportFraction: 0.92);
// - _loadBanners();
// - _startBannerTimer();

// حذف از dispose:
// - _bannerTimer?.cancel();
// - _bannerController.dispose();

// حذف متدها:
// - _loadBanners() (خطوط 303-349)
// - _startBannerTimer() (خطوط 146-148)
// - _handleBannerTap() (خطوط 633-852)
// - _handleExternalBannerTap() (خطوط 854-910)
// - _buildBannerSlider() (خطوط 1201-1272)
```

**2. تغییر در `_buildScrollableContent` (خط 1187):**

```dart
// از:
_buildBannerSlider(context),

// به:
_buildVideoUploadContainer(context),
```

**3. اضافه کردن متد جدید `_buildVideoUploadContainer`:**

```dart
Widget _buildVideoUploadContainer(BuildContext context) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    height: 180, // همان ارتفاع بنر قبلی
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed('/video-upload');
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'اضافه کردن ویدیو',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'IRANSansXFaNum',
                  ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    ),
  );
}
```

**4. حذف از `_isAnyAsyncOperationRunning` (خط 54):**

```dart
// از:
return _isProcessingGradeChange || _isLoadingSubjects || _isLoadingBanners;

// به:
return _isProcessingGradeChange || _isLoadingSubjects;
```

**5. حذف از force reload (خط 420):**

```dart
// حذف:
_banners = [];
```

### اضافه کردن route در `lib/main.dart`:

```dart
'/video-upload': (context) =>
    const SimpleNetworkWrapper(child: VideoUploadScreen()),
```

---

## مرحله 5: حذف onboarding و ثبت‌نام

### فایل‌های حذف شونده:

1. ✅ `lib/screens/onboarding/onboarding_screen.dart`
2. ✅ `lib/screens/onboarding/onboarding_step1_screen.dart`
3. ✅ `lib/screens/onboarding/onboarding_step2_screen.dart`
4. ✅ `lib/screens/onboarding/onboarding_success_screen.dart`

### مشکلات شناسایی شده:

#### ⚠️ مشکل 5.1: تغییرات در `app_state_manager.dart`

**تغییر متد `appropriateRoute`:**

```dart
String get appropriateRoute {
  try {
    Logger.debug('🔍 [ROUTE] Determining appropriate route...');
    
    if (!isUserAuthenticated) {
      Logger.debug('🔍 [ROUTE] User not authenticated -> /auth');
      return '/auth'; // به جای /onboarding
    }
    
    // ادمین نیازی به onboarding ندارد
    // مستقیما به home می‌رود
    Logger.debug('🔍 [ROUTE] User authenticated -> /home');
    return '/home';
  } catch (e) {
    Logger.error('❌ AppStateManager: Error in appropriateRoute', e);
    return '/auth'; // در صورت خطا به صفحه ورود
  }
}
```

**حذف یا ساده‌سازی متدهای زیر:**
- `isUserInOnboarding` - دیگر لازم نیست
- `currentRegistrationStage` - دیگر لازم نیست (یا ساده‌سازی شود)

#### ⚠️ مشکل 5.2: تغییرات در `main.dart`

**حذف import های onboarding:**
```dart
// حذف این خطوط:
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/onboarding_step1_screen.dart';
import 'screens/onboarding/onboarding_step2_screen.dart';
import 'screens/onboarding/onboarding_success_screen.dart';
```

**حذف route های onboarding:**
```dart
// حذف این route ها:
'/onboarding/step1': ...
'/onboarding/step2': ...
'/onboarding/success': ...
'/onboarding': ...
```

**تغییر در `AuthWrapper`:**
```dart
// تغییر خط 395-396:
// از: route = appState.authService.currentProfile == null ? '/onboarding' : initialRouteForDev;
// به: route = appState.authService.currentProfile == null ? '/auth' : initialRouteForDev;

// تغییر خط 383-386 publicRoutes:
const publicRoutes = <String>{
  '/auth', // فقط auth باقی بماند
};
```

#### ⚠️ مشکل 5.3: تغییرات در `home_screen.dart`

**تغییر متد `_checkAuthAndRedirect`:**

```dart
Future<void> _checkAuthAndRedirect() async {
  await Future.delayed(Duration.zero);
  if (!mounted) return;

  final appState = context.read<AppStateManager>();

  Logger.debug('🔍 [HOME] Checking auth...');
  
  // فقط چک احراز هویت - بدون چک registration stage
  if (!appState.isUserAuthenticated) {
    Logger.debug('🔍 [HOME] User not authenticated -> redirecting to /auth');
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
    return;
  }

  Logger.debug('🔍 [HOME] Auth OK -> staying in Home');
}
```

#### ⚠️ مشکل 5.4: تغییرات در `auth_screen.dart`

**حذف دکمه back به onboarding:**
```dart
// حذف یا تغییر خط 93-99:
// از: onPressed: () { Navigator.of(context).pushReplacement(...OnboardingScreen()); }
// به: onPressed: () => Navigator.of(context).pop(); // یا حذف کامل leading
```

---

## 📝 لیست کامل فایل‌های مورد تغییر

### فایل‌های حذف شونده (10 فایل):
1. `lib/services/content/banner_service.dart`
2. `lib/services/mini_request/mini_request_service.dart`
3. `lib/services/mini_request/mini_request_logger.dart`
4. `lib/services/image_cache/smart_image_cache_service.dart` (بررسی: اگر فقط برای بنر است)
5. `lib/models/content/banner.dart`
6. `lib/widgets/banner/cached_banner.dart`
7. `lib/screens/onboarding/onboarding_screen.dart`
8. `lib/screens/onboarding/onboarding_step1_screen.dart`
9. `lib/screens/onboarding/onboarding_step2_screen.dart`
10. `lib/screens/onboarding/onboarding_success_screen.dart`

### فایل‌های تغییر شونده (7 فایل):
1. `lib/services/auth/auth_service.dart` - اضافه کردن چک ادمین (بعد از خط 522)
2. `lib/screens/auth/verify_otp_screen.dart` - تغییر navigation (خطوط 138-148)
3. `lib/screens/home_screen.dart` - حذف بنر (حذف متغیرها، متدها، و جایگزینی _buildBannerSlider)
4. `lib/main.dart` - حذف route های onboarding، اضافه route آپلود
5. `lib/providers/core/app_state_manager.dart` - ساده‌سازی جریان احراز هویت (تغییر appropriateRoute)
6. `lib/services/content/cached_content_service.dart` - حذف وابستگی به بنر (حذف import ها، متدها)
7. `lib/screens/auth/auth_screen.dart` - حذف دکمه back به onboarding (خطوط 93-99)

### فایل‌های جدید (3 فایل):
1. `lib/services/video_upload/video_upload_service.dart`
2. `lib/models/video_upload/video_upload_form_data.dart`
3. `lib/screens/video_upload/video_upload_screen.dart`

---

## ⚠️ مشکلات کلی و پیشنهادات

### 1. وابستگی‌های پیچیده:
- `CachedContentService` به `BannerService` وابسته است - باید حذف شود
- `home_screen.dart` به چندین سرویس بنر وابسته است - باید حذف شود
- باید حذف مرحله به مرحله انجام شود

### 2. ترتیب اجرا:
1. ابتدا چک ادمین اضافه شود
2. سپس بنرها حذف شوند
3. سپس onboarding حذف شود
4. در آخر آپلود ویدیو اضافه شود

### 3. تست‌ها:
- بعد از هر مرحله باید `flutter analyze` اجرا شود
- باید مطمئن شویم که هیچ import یا استفاده از فایل‌های حذف شده باقی نمانده

### 4. کدهای ناقص:
- `video_upload_screen.dart` باید کامل شود با تمام فیلدهای فرم
- باید تمام 32 درس اضافه شود

---

## ✅ قوانین کلی اجرا

1. **لاگینگ**: استفاده از `Logger.info` و `Logger.error` در تمام مراحل
2. **سادگی**: کدها ساده و بدون پیچیدگی اضافی
3. **تست**: بعد از هر مرحله اجرای `flutter analyze`
4. **کامنت**: تمام کدهای جدید باید کامنت فارسی داشته باشند
5. **مرحله به مرحله**: منتظر تایید کاربر قبل از رفتن به مرحله بعد
6. **عدم استفاده از flutter run/build**: فقط `flutter analyze`

---

## 📊 نتیجه‌گیری

پلن به طور کلی صحیح است اما نیاز به اصلاحات زیر دارد:

1. ✅ مرحله 1 تکمیل شده
2. ⚠️ مرحله 2 نیاز به اصلاح کد چک ادمین دارد
3. ⚠️ مرحله 3 نیاز به بررسی دقیق وابستگی‌ها دارد
4. ⚠️ مرحله 4 نیاز به تکمیل کدها و لیست دروس دارد
5. ⚠️ مرحله 5 نیاز به حذف همه reference های onboarding دارد

**توصیه**: اجرا باید مرحله به مرحله و با دقت انجام شود تا وابستگی‌ها به درستی مدیریت شوند.

---

## ⚠️ هشدارهای مهم:

### 1. بررسی وابستگی‌ها قبل از حذف:
- قبل از حذف `SmartImageCacheService`، بررسی شود که آیا برای book covers استفاده می‌شود یا نه
- قبل از حذف `MiniRequestService`، بررسی شود که آیا برای محتوای دیگر استفاده می‌شود یا نه
- قبل از حذف `getActiveBannersForGrade`، بررسی شود که آیا در جای دیگری استفاده می‌شود یا نه

### 2. اصلاحات کدهای نمونه:
- ✅ notifyListeners() دو بار فراخوانی نمی‌شود (اصلاح شد)
- ✅ فقط بخش navigation در verify_otp تغییر می‌کند (اصلاح شد)
- ✅ جایگزینی _buildBannerSlider با _buildVideoUploadContainer (اصلاح شد)

### 3. بررسی نهایی:
- بعد از هر مرحله، `flutter analyze` باید اجرا شود
- باید مطمئن شویم که هیچ import یا استفاده از فایل‌های حذف شده باقی نمانده
- باید مطمئن شویم که هیچ خطای compile وجود ندارد

---

## 🔴 مشکلات بحرانی شناسایی شده و اصلاح شده:

### مشکل 1: notifyListeners() دو بار فراخوانی
**وضعیت**: ✅ اصلاح شد - در کد نمونه فقط یک بار فراخوانی می‌شود

### مشکل 2: بازنویسی کامل متد _verifyOtp
**وضعیت**: ✅ اصلاح شد - فقط بخش navigation تغییر می‌کند

### مشکل 3: جایگزینی _buildBannerSlider
**وضعیت**: ✅ اصلاح شد - راهنمای کامل اضافه شد

### مشکل 4: وابستگی‌های پیچیده در CachedContentService
**وضعیت**: ⚠️ نیاز به بررسی - متدهای مرتبط با بنر باید حذف شوند

### مشکل 5: استفاده از SmartImageCacheService
**وضعیت**: ⚠️ نیاز به بررسی - احتمالاً برای book covers است نه بنر

### مشکل 6: استفاده از MiniRequestService
**وضعیت**: ⚠️ نیاز به بررسی - احتمالاً برای محتوای دیگر هم استفاده می‌شود

