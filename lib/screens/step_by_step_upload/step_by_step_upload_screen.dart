import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import '../../utils/grade_utils.dart';
import '../../models/step_by_step_upload/step_by_step_upload_form_data.dart';
import '../../services/step_by_step_upload/step_by_step_upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// صفحه آپلود گام‌به‌گام
class StepByStepUploadScreen extends StatefulWidget {
  const StepByStepUploadScreen({super.key});

  @override
  State<StepByStepUploadScreen> createState() => _StepByStepUploadScreenState();
}

class _StepByStepUploadScreenState extends State<StepByStepUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _form = StepByStepUploadFormData();
  final _service = StepByStepUploadService();
  bool _submitting = false;

  // داده‌های Dropdown مطابق video_upload
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

  // نگاشت نام درس به ID (از دیتابیس)
  final Map<String, int> _subjectNameToId = {
    'ریاضی': 1,
    'علوم': 2,
    'فارسی': 3,
    'قرآن': 4,
    'مطالعات اجتماعی': 5,
    'هدیه های آسمانی': 6,
    'نگارش': 7,
    'عربی': 9,
    'انگلیسی': 10,
    'دینی': 14,
  };

  @override
  Widget build(BuildContext context) {
    final isHighSchool = _form.branch == 'متوسطه دوم';
    final grades = _gradesData[_form.branch ?? ''] ?? <String>[];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/home', (route) => false),
            ),
          ],
          title: const Text(
            'آپلود گام‌به‌گام',
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              // 1) شاخه (هم محدود کننده پایه و هم برای دیتابیس)
              _buildDropdown<String>(
                label: 'شاخه',
                value: _form.branch,
                items: const ['ابتدایی', 'متوسطه اول', 'متوسطه دوم'],
                onChanged: (v) {
                  setState(() {
                    _form.branch = v;
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

              // 3) رشته (فقط برای متوسطه دوم)
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
                onChanged: (v) => setState(() => _form.subject = v),
              ),

              // 5) عنوان
              _buildTextField(
                label: 'عنوان',
                onSaved: (v) => _form.title = v,
                hint: 'مثال: گام به گام ریاضی - فصل اول',
                maxLength: 200,
              ),

              // 7) لینک PDF
              _buildTextField(
                label: 'لینک PDF',
                onSaved: (v) => _form.pdfUrl = v,
                hint: 'https://...',
                maxLength: 500,
              ),

              // 8) حجم فایل (اختیاری)
              _buildDoubleField(
                label: 'حجم فایل (مگابایت) - اختیاری',
                onSaved: (v) => _form.fileSizeMb = v,
                hint: 'مثال: 2.5',
              ),

              // 9) تعداد صفحات (اختیاری)
              _buildIntField(
                label: 'تعداد صفحات - اختیاری',
                onSaved: (v) => _form.pageCount = v,
                hint: 'مثال: 25',
              ),

              // 10) فعال/غیرفعال
              Row(
                children: [
                  Checkbox(
                    value: _form.active,
                    onChanged: (v) => setState(() => _form.active = v ?? true),
                  ),
                  const Text(
                    'فعال',
                    style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'ارسال گام‌به‌گام',
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
          value: items.contains(value) ? value : null,
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text('$e', style: const TextStyle(fontFamily: 'IRANSansXFaNum')),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() {
              onChanged(v);
            });
          },
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

  // فیلد متنی RTL
  Widget _buildTextField({
    required String label,
    required void Function(String?) onSaved,
    String? hint,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          border: const OutlineInputBorder(),
          counterText: '',
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onSaved: onSaved,
      ),
    );
  }

  // فیلد عددی برای int
  Widget _buildIntField({
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
        onSaved: (v) {
          if (v == null || v.trim().isEmpty) {
            onSaved(null);
            return;
          }
          onSaved(int.tryParse(v.trim()));
        },
      ),
    );
  }

  // فیلد عددی برای double
  Widget _buildDoubleField({
    required String label,
    required void Function(double?) onSaved,
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onSaved: (v) {
          if (v == null || v.trim().isEmpty) {
            onSaved(null);
            return;
          }
          onSaved(double.tryParse(v.trim()));
        },
      ),
    );
  }

  Future<void> _handleSubmit() async {
    _formKey.currentState?.save();

    final err = _form.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err, textDirection: TextDirection.rtl)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // تبدیل نام پایه به grade_id
      final gradeName = _form.grade!;
      final gradeId = mapGradeStringToInt(gradeName);
      if (gradeId == null) {
        throw Exception('خطا در تبدیل نام پایه به ID');
      }

      // تبدیل نام رشته به track_id
      int? trackId;
      final trackName = _form.track;
      if (trackName != null && trackName != 'بدون رشته') {
        final supabase = Supabase.instance.client;
        final tracks = await supabase
            .from('tracks')
            .select('id')
            .eq('name', trackName)
            .limit(1);
        if (tracks.isNotEmpty) {
          trackId = (tracks.first as Map<String, dynamic>)['id'] as int;
        }
      }

      // تبدیل نام درس به subject_id
      final subjectId = _subjectNameToId[_form.subject];
      if (subjectId == null) {
        throw Exception('خطا: درس انتخابی در لیست موجود نیست');
      }

      // تبدیل branch به level برای دیتابیس
      final levelForDb = _form.levelForDatabase;
      if (levelForDb == null) {
        throw Exception('خطا در تبدیل شاخه به مقطع');
      }

      final payload = {
        'branch': _form.branch,
        'grade_name': gradeName,
        'grade_id': gradeId,
        'track_id': trackId,
        'subject_name': _form.subject,
        'subject_id': subjectId,
        'level': levelForDb,
        'title': _form.title,
        'pdf_url': _form.pdfUrl,
        'file_size_mb': _form.fileSizeMb,
        'page_count': _form.pageCount,
        'active': _form.active,
      };

      Logger.info('📤 [STEP-BY-STEP-UPLOAD] ارسال با payload: $payload');
      await _service.uploadStepByStep(payload: payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ گام‌به‌گام با موفقیت ثبت شد', textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      Logger.error('❌ [STEP-BY-STEP-UPLOAD] Error', e);
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

