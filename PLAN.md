# پلن: خواندن جزئیات ویدیو، ویرایش و حذف ویدیو

## 📋 قوانین و نکات مهم

### قوانین کلی:
1. ✅ **یک فایل واحد**: تمام تغییرات در این فایل `PLAN.md` ثبت می‌شود
2. ✅ **مرحله به مرحله**: هر مرحله نیاز به تایید کاربر دارد
3. ✅ **اجرا نکن**: تا زمانی که کاربر تایید نکرده، کد اجرا نمی‌شود
4. ✅ **Logger**: همه کدها باید `Logger.info` و `Logger.error` داشته باشند
5. ✅ **کد ساده**: کدها باید ساده، اصولی و حرفه‌ای باشند
6. ✅ **Flutter Analyze**: در آخر `flutter analyze` اجرا می‌شود
7. ✅ **MCP Supabase**: استفاده از MCP برای Supabase (یا `npx supabase`)
8. ✅ **کوئری چک**: هر کوئری SQL باید چک و استعلام داشته باشد
9. ✅ **بدون Mini-Request**: در ادمین از Mini-Request استفاده نمی‌شود (کد سنتی)

### محدوده کار:
1. **ویدیوها**: نمایش جزئیات، ویرایش، حذف
2. **PDF جزوه**: بعد از تایید ویدیو
3. **نمونه سوال استانی**: بعد از تایید ویدیو

---

## 📝 مراحل کار

### ✅ مرحله 1: نمایش جزئیات کامل ویدیو در صفحه چپتر

**هدف**: نمایش تمام فیلدهای ویدیو از جمله `embed_html` در پاپ‌آپ جزئیات

**فایل**: `lib/screens/chapter_screen.dart`

**تغییرات**:
- متد `_openVideoPopup` را به‌روزرسانی می‌کنیم تا تمام فیلدها نمایش داده شوند
- اضافه کردن نمایش `embed_html`, `chapter_id`, `chapter_order`, `chapter_title`, `allow_landscape`, `prereq_lesson_id` (اگر وجود داشته باشد)

**کد کامل متد `_openVideoPopup`**:

```dart
/// نمایش پاپ‌آپ جزئیات ویدیو با تمام فیلدها
void _openVideoPopup(LessonVideo video) {
  final teacherName = _teachersMap[video.teacherId.toString()] ?? 'نامشخص';

  Logger.info('📹 [VIDEO-DETAIL] نمایش جزئیات ویدیو ID: ${video.id}');

  showDialog(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text(
          'جزئیات ویدیو',
          style: TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // اطلاعات پایه
                _kv('شناسه ویدیو', video.id.toString()),
                _kv('شناسه فصل', video.chapterId.toString()),
                _kv('شماره فصل', video.chapterOrder.toString()),
                _kv('عنوان فصل', video.chapterTitle),
                _kv('شماره درس', video.lessonOrder.toString()),
                _kv('عنوان درس', video.lessonTitle),
                _kv('استاد', teacherName),
                _kv('شناسه استاد', video.teacherId.toString()),
                _kv('نوع محتوا', _getStyleName(video.style)),
                _kv('وضعیت محتوا', video.contentStatus),
                _kv('فعال', video.active ? 'بله' : 'خیر'),
                
                // لینک‌ها
                _kv(
                  'لینک آپارات',
                  video.aparatUrl.isNotEmpty ? video.aparatUrl : '-',
                ),
                
                // Embed HTML (کد کامل)
                if (video.embedHtml != null && video.embedHtml!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'کد Embed HTML:',
                          style: TextStyle(
                            fontFamily: 'IRANSansXFaNum',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SelectableText(
                            video.embedHtml!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // PDF ها
                if (video.notePdfUrl != null && video.notePdfUrl!.isNotEmpty)
                  _kv('لینک PDF جزوه', video.notePdfUrl!),
                if (video.exercisePdfUrl != null &&
                    video.exercisePdfUrl!.isNotEmpty)
                  _kv('لینک PDF نمونه سوال', video.exercisePdfUrl!),
                
                // سایر اطلاعات
                _kv('مدت زمان', _formatDuration(video.durationSec)),
                _kv('تعداد بازدید', video.viewCount.toString()),
                _kv(
                  'تگ‌ها',
                  video.tags.isNotEmpty ? video.tags.join(', ') : '-',
                ),
                _kv('اجازه چرخش', video.allowLandscape ? 'بله' : 'خیر'),
                if (video.prereqLessonId != null)
                  _kv('پیش‌نیاز درس', video.prereqLessonId.toString()),
              ],
            ),
          ),
        ),
        actions: [
          // دکمه ویرایش (سبز)
          ElevatedButton(
            onPressed: () {
              Logger.info('✏️ [VIDEO-DETAIL] باز کردن صفحه ویرایش برای ویدیو ID: ${video.id}');
              Navigator.of(context).pop();
              // TODO: بعد از ساخت صفحه ویرایش، اینجا navigation اضافه می‌شود
              // Navigator.of(context).push(
              //   MaterialPageRoute(
              //     builder: (context) => VideoEditScreen(video: video),
              //   ),
              // );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'ویرایش',
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
          ),
          // دکمه حذف (قرمز)
          ElevatedButton(
            onPressed: () {
              Logger.info('🗑️ [VIDEO-DETAIL] باز کردن تایید حذف برای ویدیو ID: ${video.id}');
              Navigator.of(context).pop();
              // TODO: بعد از ساخت فانکشن delete-content، اینجا تایید حذف اضافه می‌شود
              // _showDeleteConfirmation(video);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'حذف',
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
          ),
        ],
      ),
    ),
  );
}
```

**تغییرات در `_kv` (اگر SelectableText نیاز باشد)**:
```dart
Widget _kv(String key, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$key:',
            style: const TextStyle(
              fontFamily: 'IRANSansXFaNum',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
      ],
    ),
  );
}
```

**وضعیت**: ⏳ منتظر تایید

---

### ✅ مرحله 2: به‌روزرسانی Edge Function update-content

**هدف**: اضافه کردن پشتیبانی از فیلدهای `embed_html`, `note_pdf_url`, `exercise_pdf_url` در فانکشن `update-content`

**فایل**: `supabase/functions/update-content/index.ts`

**تغییرات**:
- اضافه کردن فیلدهای `embed_html`, `note_pdf_url`, `exercise_pdf_url` به interface `UpdateContentInput`
- اضافه کردن منطق به‌روزرسانی این فیلدها در فانکشن

**کد تغییرات در `update-content/index.ts`**:

```typescript
interface UpdateContentInput {
  lesson_video_id: number;
  updates: {
  aparat_url?: string;
    duration_sec?: number;
  tags?: string[];
  prereq_lesson_id?: number | null;
  active?: boolean;
  content_status?: 'draft' | 'published' | 'archived';
    teacher_name?: string;
    style?: 'note' | 'book' | 'sample';
    embed_html?: string | null;  // ← جدید
    note_pdf_url?: string | null;  // ← جدید
    exercise_pdf_url?: string | null;  // ← جدید
  };
}

// در بخش Handle other video updates:
if (input.updates.embed_html !== undefined) videoUpdates.embed_html = input.updates.embed_html;
if (input.updates.note_pdf_url !== undefined) videoUpdates.note_pdf_url = input.updates.note_pdf_url;
if (input.updates.exercise_pdf_url !== undefined) videoUpdates.exercise_pdf_url = input.updates.exercise_pdf_url;
```

**Deploy**: با استفاده از MCP Supabase یا `npx supabase functions deploy update-content --yes`

**وضعیت**: ⏳ منتظر تایید

---

### ✅ مرحله 3: ساخت صفحه ویرایش ویدیو

**هدف**: ساخت صفحه ویرایش ویدیو مشابه صفحه آپلود با داده‌های پیش‌فرض

**فایل جدید**: `lib/screens/video_edit/video_edit_screen.dart`

**سرویس جدید**: `lib/services/video_edit/video_edit_service.dart`

**تغییرات**:
1. ساخت صفحه `VideoEditScreen` مشابه `VideoUploadScreen`
2. دکمه بازگشت در همان موقعیت و شکل صفحه آپلود
3. تمام فیلدها با مقادیر پیش‌فرض از ویدیو موجود
4. دکمه "بروزرسانی" به جای "ارسال ویدیو"
5. استفاده از Edge Function `update-content` به‌روزرسانی شده

**کد کامل `lib/services/video_edit/video_edit_service.dart`**:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس ویرایش ویدیو
class VideoEditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// به‌روزرسانی ویدیو با استفاده از Edge Function update-content
  Future<Map<String, dynamic>> updateVideo({
    required int lessonVideoId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      Logger.info('🔍 [VIDEO-EDIT] شروع به‌روزرسانی ویدیو ID: $lessonVideoId');
      Logger.info('🔍 [VIDEO-EDIT] Updates: $updates');

      final payload = {
        'lesson_video_id': lessonVideoId,
        'updates': updates,
      };

      final response = await _supabase.functions.invoke(
        'update-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [VIDEO-EDIT] ویدیو با موفقیت به‌روزرسانی شد');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [VIDEO-EDIT] شکست در به‌روزرسانی: $error');
        throw Exception(error);
      } else {
        Logger.error('❌ [VIDEO-EDIT] خطای HTTP: ${response.status}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error('❌ [VIDEO-EDIT] خطا در به‌روزرسانی ویدیو', e);
      rethrow;
    }
  }
}
```

**کد کامل `lib/screens/video_edit/video_edit_screen.dart`**:

```dart
import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import '../../models/content/lesson_video.dart';
import '../../models/video_upload/video_upload_form_data.dart';
import '../../services/video_edit/video_edit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/content/content_service.dart';

/// صفحه ویرایش ویدیو
class VideoEditScreen extends StatefulWidget {
  final LessonVideo video;

  const VideoEditScreen({
    super.key,
    required this.video,
  });

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _form = VideoUploadFormData();
  final _service = VideoEditService();
  bool _submitting = false;
  bool _loading = true;
  String? _teacherName; // نام استاد برای نمایش

  // داده‌های Dropdown مشابه صفحه آپلود
  final Map<String, List<String>> _gradesData = const {
    'ابتدایی': ['یکم', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم'],
    'متوسطه اول': ['هفتم', 'هشتم', 'نهم'],
    'متوسطه دوم': ['دهم', 'یازدهم', 'دوازدهم'],
  };

  final List<String> _tracks = const ['بدون رشته', 'ریاضی', 'تجربی', 'انسانی'];

  final Map<String, String> _subjectOptions = const {
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

  @override
  void initState() {
    super.initState();
    _loadVideoData();
  }

  /// بارگذاری داده‌های ویدیو و پر کردن فرم
  Future<void> _loadVideoData() async {
    try {
      Logger.info('📥 [VIDEO-EDIT] بارگذاری داده‌های ویدیو ID: ${widget.video.id}');

      // دریافت اطلاعات کامل از Supabase
      final supabase = Supabase.instance.client;
      
      // دریافت chapter برای گرفتن اطلاعات بیشتر
      final chapterData = await supabase
        .from('chapters')
          .select('id, title, chapter_order, subject_offer_id')
          .eq('id', widget.video.chapterId)
        .single();
      
      if (chapterData == null) {
        Logger.error('❌ [VIDEO-EDIT] فصل یافت نشد');
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ خطا: فصل یافت نشد', textDirection: TextDirection.rtl),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // دریافت نام استاد
      final teacherData = await supabase
      .from('teachers')
          .select('name')
          .eq('id', widget.video.teacherId)
      .single();

      final teacherName = teacherData?['name'] as String? ?? 'نامشخص';

      setState(() {
        _teacherName = teacherName;
        // پر کردن فرم با داده‌های ویدیو
        _form.chapterTitle = widget.video.chapterTitle;
        _form.chapterOrder = widget.video.chapterOrder;
        _form.lessonTitle = widget.video.lessonTitle;
        _form.lessonOrder = widget.video.lessonOrder;
        _form.style = widget.video.style;
        _form.embedHtml = widget.video.embedHtml ?? '';
        _form.notePdfUrl = widget.video.notePdfUrl ?? '';
        _form.exercisePdfUrl = widget.video.exercisePdfUrl ?? '';
        
        // تبدیل duration_sec به ساعت، دقیقه، ثانیه
        final totalSeconds = widget.video.durationSec;
        _form.durationHours = totalSeconds ~/ 3600;
        _form.durationMinutes = (totalSeconds % 3600) ~/ 60;
        _form.durationSeconds = totalSeconds % 60;
        
        // تبدیل tags به string
        _form.tags = widget.video.tags.join(', ');
        
        _loading = false;
      });

      Logger.info('✅ [VIDEO-EDIT] داده‌های ویدیو بارگذاری شد');
    } catch (e) {
      Logger.error('❌ [VIDEO-EDIT] خطا در بارگذاری داده‌های ویدیو', e);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطا: ${e.toString()}', textDirection: TextDirection.rtl),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            title: const Text(
              'ویرایش ویدیو',
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
          ),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          // دکمه بازگشت در همان موقعیت و شکل صفحه آپلود
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: const Text(
            'ویرایش ویدیو',
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              // نمایش اطلاعات فعلی (read-only)
              _buildInfoCard('شناسه ویدیو', widget.video.id.toString()),
              _buildInfoCard('عنوان فصل', widget.video.chapterTitle),
              _buildInfoCard('شماره فصل', widget.video.chapterOrder.toString()),
              _buildInfoCard('عنوان درس', widget.video.lessonTitle),
              _buildInfoCard('شماره درس', widget.video.lessonOrder.toString()),
              
              const Divider(height: 32),
              
              // فیلدهای قابل ویرایش
              // نوع محتوا
              _buildTextField(
                label: 'نوع محتوا (جزوه/نمونه سوال/کتاب درسی)',
                initialValue: _form.style,
                onSaved: (v) => _form.style = v,
                hint: 'جزوه / کتاب درسی / نمونه سوال',
              ),

              // نام استاد (خواندنی)
              _buildInfoCard('نام استاد', _teacherName ?? 'در حال بارگذاری...'),

              // مدت زمان
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      label: 'ساعت',
                      initialValue: _form.durationHours,
                      onSaved: (v) => _form.durationHours = v,
                      hint: '0',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNumberField(
                      label: 'دقیقه',
                      initialValue: _form.durationMinutes,
                      onSaved: (v) => _form.durationMinutes = v,
                      hint: '0-59',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNumberField(
                      label: 'ثانیه',
                      initialValue: _form.durationSeconds,
                      onSaved: (v) => _form.durationSeconds = v,
                      hint: '0-59',
                    ),
                  ),
                ],
              ),

              // سایر فیلدها
              _buildTextField(
                label: 'تگ‌ها (با کاما جدا کنید)',
                initialValue: _form.tags,
                onSaved: (v) => _form.tags = v,
                hint: 'مثال: حد, پایه ۹, تابع',
              ),
              _buildTextField(
                label: 'Embed HTML آپارات (اختیاری)',
                initialValue: _form.embedHtml,
                onSaved: (v) => _form.embedHtml = v,
                hint: '<script src="https://www.aparat.com/embed/..." ></script>',
                maxLines: 3,
              ),
              _buildTextField(
                label: 'لینک PDF جزوه (اختیاری)',
                initialValue: _form.notePdfUrl,
                onSaved: (v) => _form.notePdfUrl = v,
                hint: 'https://...',
              ),
              _buildTextField(
                label: 'لینک PDF نمونه سوال (اختیاری)',
                initialValue: _form.exercisePdfUrl,
                onSaved: (v) => _form.exercisePdfUrl = v,
                hint: 'https://...',
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'بروزرسانی',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontFamily: 'IRANSansXFaNum',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required void Function(String?) onSaved,
    String? hint,
    String? initialValue,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          border: const OutlineInputBorder(),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        maxLines: maxLines,
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required void Function(int?) onSaved,
    String? hint,
    int? initialValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: initialValue?.toString(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onSaved: (v) => onSaved(int.tryParse(v ?? '')),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    // ذخیره مقادیر فرم
    _formKey.currentState?.save();

    // اعتبارسنجی حداقلی
    final err = _form.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err, textDirection: TextDirection.rtl)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      Logger.info('🔄 [VIDEO-EDIT] شروع به‌روزرسانی ویدیو ID: ${widget.video.id}');

      // تبدیل style به فرمت استاندارد
      final styleMap = {
        'note': 'note',
        'book': 'book',
        'sample': 'sample',
        'جزوه': 'note',
        'کتاب درسی': 'book',
        'نمونه سوال': 'sample',
      };
      final normalizedStyle = styleMap[_form.style] ?? 'note';

      // آماده‌سازی updates (بعد از به‌روزرسانی update-content در مرحله 2)
      final updates = <String, dynamic>{
        'style': normalizedStyle,
        'duration_sec': _form.durationInSeconds,
        'tags': _form.tagsList,
        'embed_html': _form.embedHtml?.isEmpty ?? true ? null : _form.embedHtml,
        'note_pdf_url': _form.notePdfUrl?.isEmpty ?? true ? null : _form.notePdfUrl,
        'exercise_pdf_url': _form.exercisePdfUrl?.isEmpty ?? true ? null : _form.exercisePdfUrl,
      };

      await _service.updateVideo(
        lessonVideoId: widget.video.id,
        updates: updates,
      );

      if (!mounted) return;
      Logger.info('✅ [VIDEO-EDIT] ویدیو با موفقیت به‌روزرسانی شد');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ویدیو با موفقیت به‌روزرسانی شد', textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // بازگشت با نتیجه موفق
  } catch (e) {
      Logger.error('❌ [VIDEO-EDIT] خطا در به‌روزرسانی', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطا: ${e.toString()}', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
```

**تغییرات در `chapter_screen.dart`**:
- اضافه کردن navigation به صفحه ویرایش در دکمه ویرایش پاپ‌آپ

```dart
// در متد _openVideoPopup، دکمه ویرایش:
ElevatedButton(
  onPressed: () {
    Logger.info('✏️ [VIDEO-DETAIL] باز کردن صفحه ویرایش برای ویدیو ID: ${video.id}');
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoEditScreen(video: video),
      ),
    );
  },
  // ...
),
```

**وضعیت**: ⏳ منتظر تایید

---

### ✅ مرحله 4: ساخت Edge Function delete-content

**هدف**: ساخت فانکشن برای حذف ویدیو و تمام وابستگی‌ها

**فایل جدید**: `supabase/functions/delete-content/index.ts`

**Deploy**: با استفاده از MCP Supabase (`mcp_supabase_deploy_edge_function`)

**منطق حذف**:
- بررسی وجود ویدیو
- حذف از `lesson_videos` (CASCADE به صورت خودکار وابستگی‌ها را حذف می‌کند)
- لاگ کردن عملیات

**کد کامل `supabase/functions/delete-content/index.ts`**:

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface DeleteContentInput {
  lesson_video_id: number;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const input: DeleteContentInput = await req.json();
    
    console.log('🗑️ [DELETE-CONTENT] شروع حذف ویدیو ID:', input.lesson_video_id);

    if (!input.lesson_video_id) {
      console.error('❌ [DELETE-CONTENT] lesson_video_id الزامی است');
      return new Response(
        JSON.stringify({ error: "lesson_video_id الزامی است" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    if (!supabaseUrl || !serviceRoleKey) {
      console.error('❌ [DELETE-CONTENT] ENV ناقص است');
      return new Response(
        JSON.stringify({ error: 'ENV ناقص است: SUPABASE_URL یا SUPABASE_SERVICE_ROLE_KEY تنظیم نشده' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // بررسی وجود ویدیو
    const { data: existingVideo, error: checkError } = await supabase
      .from('lesson_videos')
      .select('id, chapter_id, lesson_title, style')
      .eq('id', input.lesson_video_id)
      .single();

    if (checkError || !existingVideo) {
      console.error('❌ [DELETE-CONTENT] ویدیو یافت نشد:', checkError?.message);
      return new Response(
        JSON.stringify({ error: "ویدیو یافت نشد" }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ [DELETE-CONTENT] ویدیو یافت شد:', existingVideo);

    // حذف ویدیو (CASCADE به صورت خودکار وابستگی‌ها را حذف می‌کند)
    const { error: deleteError } = await supabase
            .from('lesson_videos')
      .delete()
      .eq('id', input.lesson_video_id);

    if (deleteError) {
      console.error('❌ [DELETE-CONTENT] خطا در حذف ویدیو:', deleteError.message);
      throw new Error(`خطا در حذف ویدیو: ${deleteError.message}`);
    }

    console.log('✅ [DELETE-CONTENT] ویدیو با موفقیت حذف شد');

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "ویدیو با موفقیت حذف شد",
        data: {
          deleted_video_id: input.lesson_video_id
        }
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("❌ [DELETE-CONTENT] Error in delete-content function:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

**کوئری چک برای بررسی CASCADE**:
```sql
-- بررسی Foreign Key Constraints برای lesson_videos
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
    ON rc.constraint_name = tc.constraint_name
WHERE tc.table_name = 'lesson_videos'
    AND tc.constraint_type = 'FOREIGN KEY';
```

**مراحل Deploy**:
1. ✅ نوشتن فایل `supabase/functions/delete-content/index.ts`
2. ✅ Deploy با MCP: استفاده از `mcp_supabase_deploy_edge_function`
   - Project ID: `jarkzyebfgpxywlxizeo` (Nardeboun-app)
   - Function Name: `delete-content`
   - Entrypoint: `index.ts`
   - Files: فقط `index.ts` (بدون import map)

**وضعیت**: ⏳ منتظر تایید

---

### ✅ مرحله 5: اضافه کردن سرویس حذف در Flutter

**هدف**: ساخت سرویس برای فراخوانی delete-content و استفاده در UI

**فایل جدید**: `lib/services/video_delete/video_delete_service.dart`

**کد کامل**:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../../const/api_keys.dart';

/// سرویس حذف ویدیو
class VideoDeleteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// حذف ویدیو با استفاده از Edge Function delete-content
  Future<Map<String, dynamic>> deleteVideo({
    required int lessonVideoId,
  }) async {
    try {
      Logger.info('🗑️ [VIDEO-DELETE] شروع حذف ویدیو ID: $lessonVideoId');

      final payload = {
        'lesson_video_id': lessonVideoId,
      };

      final response = await _supabase.functions.invoke(
        'delete-content',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${APIKeys.supaBaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && (data['success'] == true || data['success'] == 'true')) {
          Logger.info('✅ [VIDEO-DELETE] ویدیو با موفقیت حذف شد');
          return data;
        }
        final error = data?['error'] ?? 'خطای ناشناخته';
        Logger.error('❌ [VIDEO-DELETE] شکست در حذف: $error');
        throw Exception(error);
      } else {
        Logger.error('❌ [VIDEO-DELETE] خطای HTTP: ${response.status}');
        throw Exception('خطا در ارتباط با سرور - کد: ${response.status}');
      }
    } catch (e) {
      Logger.error('❌ [VIDEO-DELETE] خطا در حذف ویدیو', e);
      rethrow;
    }
  }
}
```

**تغییرات در `chapter_screen.dart`**:
- اضافه کردن متد `_showDeleteConfirmation` و استفاده از `VideoDeleteService`

```dart
import '../../services/video_delete/video_delete_service.dart';

// در کلاس _ChapterScreenState:
final _deleteService = VideoDeleteService();

// متد جدید برای نمایش تایید حذف:
void _showDeleteConfirmation(LessonVideo video) {
  Logger.info('🗑️ [VIDEO-DELETE] نمایش تایید حذف برای ویدیو ID: ${video.id}');
  
  showDialog(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text(
          'تایید حذف',
          style: TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید این ویدیو را حذف کنید؟\n\n'
          'عنوان: ${video.lessonTitle}\n'
          'این عملیات غیرقابل بازگشت است.',
          style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'انصراف',
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteVideo(video);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'حذف',
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
          ),
        ],
      ),
    ),
  );
}

// متد حذف ویدیو:
Future<void> _deleteVideo(LessonVideo video) async {
  try {
    Logger.info('🗑️ [VIDEO-DELETE] شروع حذف ویدیو ID: ${video.id}');

    await _deleteService.deleteVideo(lessonVideoId: video.id);

    if (!mounted) return;

    Logger.info('✅ [VIDEO-DELETE] ویدیو با موفقیت حذف شد');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ ویدیو با موفقیت حذف شد', textDirection: TextDirection.rtl),
        backgroundColor: Colors.green,
      ),
    );

    // رفرش لیست ویدیوها
    await _load();
  } catch (e) {
    Logger.error('❌ [VIDEO-DELETE] خطا در حذف ویدیو', e);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ خطا: ${e.toString()}', textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// در متد _openVideoPopup، دکمه حذف:
ElevatedButton(
  onPressed: () {
    Logger.info('🗑️ [VIDEO-DETAIL] باز کردن تایید حذف برای ویدیو ID: ${video.id}');
    Navigator.of(context).pop();
    _showDeleteConfirmation(video);
  },
  // ...
),
```

**وضعیت**: ⏳ منتظر تایید

---

### ⏳ مرحله 6: اعمال تغییرات برای PDF جزوه (بعد از تایید ویدیو)

**هدف**: بعد از تایید کامل تغییرات ویدیو، همین کارها برای PDF جزوه انجام می‌شود

**تغییرات مورد نیاز**:
1. نمایش جزئیات PDF جزوه در صفحه چپتر
2. صفحه ویرایش PDF جزوه
3. حذف PDF جزوه (استفاده از delete-content موجود)

**وضعیت**: 🔒 قفل شده - منتظر تایید مرحله 4

---

### ⏳ مرحله 7: اعمال تغییرات برای نمونه سوال استانی (بعد از تایید ویدیو)

**هدف**: بعد از تایید کامل تغییرات ویدیو، همین کارها برای نمونه سوال استانی انجام می‌شود

**تغییرات مورد نیاز**:
1. نمایش جزئیات نمونه سوال استانی
2. صفحه ویرایش نمونه سوال استانی
3. حذف نمونه سوال استانی

**وضعیت**: 🔒 قفل شده - منتظر تایید مرحله 4

---

## 📝 خلاصه مراحل

1. ✅ **مرحله 1**: نمایش جزئیات کامل ویدیو (شامل embed_html)
2. ✅ **مرحله 2**: به‌روزرسانی Edge Function update-content (اضافه کردن embed_html, note_pdf_url, exercise_pdf_url)
3. ✅ **مرحله 3**: ساخت صفحه ویرایش ویدیو
4. ✅ **مرحله 4**: ساخت Edge Function delete-content
5. ✅ **مرحله 5**: اضافه کردن سرویس حذف در Flutter
6. ⏳ **مرحله 6**: اعمال تغییرات برای PDF جزوه (بعد از تایید)
7. ⏳ **مرحله 7**: اعمال تغییرات برای نمونه سوال استانی (بعد از تایید)

---

## 🔍 بررسی نهایی

بعد از تایید تمام مراحل:
1. ✅ اجرای `flutter analyze`
2. ✅ تست تمام قابلیت‌ها
3. ✅ بررسی لاگ‌ها

---

**تاریخ ایجاد پلن**: 2025-01-11  
**وضعیت**: ⏳ منتظر تایید مرحله 1

