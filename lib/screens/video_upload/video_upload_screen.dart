import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import '../../models/video_upload/video_upload_form_data.dart';
import '../../services/video_upload/video_upload_service.dart';

/// صفحه آپلود ویدیو (نسخه ساده برای شروع تست)
class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _form = VideoUploadFormData();
  final _service = VideoUploadService();
  bool _submitting = false;

  // داده‌های Dropdown مطابق PHP
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighSchool = _form.branch == 'متوسطه دوم';

    // لیست پایه‌ها بر اساس شاخه انتخاب‌شده
    final grades = _gradesData[_form.branch ?? ''] ?? <String>[];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          // جابه‌جایی دکمه بازگشت به سمت مخالف (چپ در RTL)
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/home', (route) => false),
            ),
          ],
          title: const Text(
            'آپلود ویدیو',
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              // 1) شاخه
              _buildDropdown<String>(
                label: 'شاخه',
                value: _form.branch,
                items: const ['ابتدایی', 'متوسطه اول', 'متوسطه دوم'],
                onChanged: (v) {
                  setState(() {
                    _form.branch = v;
                    // ریست وابسته‌ها
                    _form.grade = null;
                    _form.track = 'بدون رشته';
                  });
                },
              ),

              // 2) پایه (وابسته به شاخه)
              _buildDropdown<String>(
                label: 'پایه',
                value: _form.grade,
                items: grades,
                onChanged: (v) => setState(() => _form.grade = v),
                hint: grades.isEmpty ? 'ابتدا شاخه را انتخاب کنید' : null,
              ),

              // 3) رشته (فقط برای متوسطه دوم نمایش بده)
              if (isHighSchool)
                _buildDropdown<String>(
                  label: 'رشته',
                  value: _form.track ?? 'بدون رشته',
                  items: _tracks,
                  onChanged: (v) => setState(() => _form.track = v),
                ),

              // 4) درس
              _buildDropdown<String>(
                label: 'درس',
                value: _form.subject,
                items: _subjectOptions.keys.toList(),
                onChanged: (v) {
                  setState(() {
                    _form.subject = v;
                    // همگام‌سازی اسلاگ با انتخاب درس
                    final slug = v == null ? null : _subjectOptions[v];
                    _form.subjectSlug = slug;
                  });
                },
              ),

              // 5) اسلاگ درس (قابل تغییر اما پیش‌فرض از درس)
              _buildDropdown<String>(
                label: 'اسلاگ درس',
                value: _form.subjectSlug,
                items: _subjectOptions.values.toList(),
                onChanged: (v) => setState(() => _form.subjectSlug = v),
                hint: 'با انتخاب درس به‌صورت خودکار پر می‌شود',
              ),

              // 6) عنوان فصل
              _buildTextField(
                label: 'عنوان فصل',
                onSaved: (v) => _form.chapterTitle = v,
                hint: 'مثال: فصل اول - اعداد صحیح',
              ),
              _buildNumberField(
                label: 'شماره فصل',
                onSaved: (v) => _form.chapterOrder = v,
                hint: 'مثال: 1',
              ),

              // 7) نوع محتوا (متنی ساده باقی می‌ماند تا فعلاً توسعه ندهیم)
              _buildTextField(
                label: 'نوع محتوا (جزوه/نمونه سوال/کتاب درسی)',
                onSaved: (v) => _form.style = v,
                hint: 'جزوه / کتاب درسی / نمونه سوال',
              ),

              // 8) عنوان درس و شماره درس
              _buildTextField(
                label: 'عنوان درس',
                onSaved: (v) => _form.lessonTitle = v,
                hint: 'مثال: درس اول - جمع اعداد',
              ),
              _buildNumberField(
                label: 'شماره درس',
                onSaved: (v) => _form.lessonOrder = v,
                hint: 'مثال: 1',
              ),

              // 9) نام استاد
              _buildTextField(
                label: 'نام استاد',
                onSaved: (v) => _form.teacherName = v,
                hint: 'مثال: استاد احمدی',
              ),

              // 10) مدت زمان
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      label: 'ساعت',
                      onSaved: (v) => _form.durationHours = v,
                      hint: '0',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNumberField(
                      label: 'دقیقه',
                      onSaved: (v) => _form.durationMinutes = v,
                      hint: '0-59',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNumberField(
                      label: 'ثانیه',
                      onSaved: (v) => _form.durationSeconds = v,
                      hint: '0-59',
                    ),
                  ),
                ],
              ),

              // 11) سایر فیلدها
              _buildTextField(
                label: 'تگ‌ها (با کاما جدا کنید)',
                onSaved: (v) => _form.tags = v,
                hint: 'مثال: حد, پایه ۹, تابع',
              ),
              _buildTextField(
                label: 'Embed HTML آپارات (اختیاری)',
                onSaved: (v) => _form.embedHtml = v,
                hint: '<script src="https://www.aparat.com/embed/..." ></script>',
              ),
              _buildTextField(
                label: 'لینک PDF جزوه (اختیاری)',
                onSaved: (v) => _form.notePdfUrl = v,
                hint: 'https://...',
              ),
              _buildTextField(
                label: 'لینک PDF نمونه سوال (اختیاری)',
                onSaved: (v) => _form.exercisePdfUrl = v,
                hint: 'https://...',
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _handleSubmit,
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
                        'ارسال ویدیو',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dropdown عمومی RTL
  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: DropdownButtonFormField<T>(
          initialValue: items.contains(value) ? value : null,
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text('$e', style: const TextStyle(fontFamily: 'IRANSansXFaNum')),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
            border: const OutlineInputBorder(),
          ),
          isExpanded: true,
        ),
      ),
    );
  }

  // فیلد متنی RTL با فونت ایرانسنس
  Widget _buildTextField({
    required String label,
    required void Function(String?) onSaved,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          border: const OutlineInputBorder(),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onSaved: onSaved,
      ),
    );
  }

  // فیلد عددی ساده
  Widget _buildNumberField({
    required String label,
    required void Function(int?) onSaved,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
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

  Future<void> _handleSubmit() async {
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
      final payload = {
        'branch': _form.branch,
        'grade': _form.grade,
        'track': (_form.track == null || _form.track!.isEmpty || _form.track == 'بدون رشته')
            ? null
            : _form.track,
        'subject': _form.subject,
        'subject_slug': _form.subjectSlug,
        'chapter_title': _form.chapterTitle,
        'chapter_order': _form.chapterOrder,
        'lesson_title': _form.lessonTitle,
        'lesson_order': _form.lessonOrder,
        'teacher_name': _form.teacherName,
        'style': _form.style,
        'duration_sec': _form.durationInSeconds,
        'tags': _form.tagsList,
        'embed_html': _form.embedHtml,
        'allow_landscape': true,
        'note_pdf_url': _form.notePdfUrl,
        'exercise_pdf_url': _form.exercisePdfUrl,
        'aparat_url': '',
      };

      await _service.uploadVideo(payload: payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ویدیو با موفقیت ثبت شد', textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      Logger.error('❌ [VIDEO-UPLOAD] Error', e);
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
