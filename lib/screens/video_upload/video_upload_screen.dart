import 'package:flutter/material.dart';
import 'dart:convert';
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

  // Controllers برای حفظ مقادیر فیلدها هنگام scroll
  late final TextEditingController _titleController = TextEditingController();
  late final TextEditingController _chapterIdController = TextEditingController();
  late final TextEditingController _stepNumberController = TextEditingController();
  late final TextEditingController _teacherController = TextEditingController();
  late final TextEditingController _embedUrlController = TextEditingController();
  late final TextEditingController _directUrlController = TextEditingController();
  late final TextEditingController _pdfUrlController = TextEditingController();
  late final TextEditingController _durationController = TextEditingController();
  late final TextEditingController _thumbnailUrlController = TextEditingController();

  // Keys ثابت برای حفظ identity TextFormField ها هنگام rebuild
  final _titleKey = GlobalKey();
  final _chapterIdKey = GlobalKey();
  final _stepNumberKey = GlobalKey();
  final _teacherKey = GlobalKey();
  final _embedUrlKey = GlobalKey();
  final _directUrlKey = GlobalKey();
  final _pdfUrlKey = GlobalKey();
  final _durationKey = GlobalKey();
  final _thumbnailUrlKey = GlobalKey();

  // داده‌های dropdown از JSON
  Map<String, dynamic>? _gradesJson;
  Map<String, dynamic>? _currentGradeData;
  List<String> _gradeOptions = [];
  List<String> _subjectOptions = [];
  Map<String, String> _subjectSlugs = {};
  List<String> _chapterOptions = [];
  List<String> _typeOptions = ['note', 'book', 'exam'];

  @override
  void initState() {
    super.initState();
    _loadGradesJson();
    // تنظیم مقادیر اولیه از _form
    _titleController.text = _form.title ?? '';
    _chapterIdController.text = _form.chapterId ?? '';
    _stepNumberController.text = _form.stepNumber?.toString() ?? '';
    _teacherController.text = _form.teacher ?? '';
    _embedUrlController.text = _form.embedUrl ?? '';
    _directUrlController.text = _form.directUrl ?? '';
    _pdfUrlController.text = _form.pdfUrl ?? '';
    _durationController.text = _form.duration?.toString() ?? '';
    _thumbnailUrlController.text = _form.thumbnailUrl ?? '';

    // تنظیم مقدار پیش‌فرض برای active
    _form.active = _form.active ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _chapterIdController.dispose();
    _stepNumberController.dispose();
    _teacherController.dispose();
    _embedUrlController.dispose();
    _directUrlController.dispose();
    _pdfUrlController.dispose();
    _durationController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadGradesJson() async {
    try {
      final gradesData = await DefaultAssetBundle.of(context).loadString('assets/data/grades.json');
      _gradesJson = json.decode(gradesData);
      _gradeOptions = _gradesJson!.keys.map((k) => k.toString()).toList()..sort();
      setState(() {});
    } catch (e) {
      Logger.error('Failed to load grades.json', e);
    }
  }

  void _onGradeChanged(int gradeId) {
    if (_gradesJson == null) return;

    final gradeKey = gradeId.toString();
    _currentGradeData = _gradesJson![gradeKey];
    if (_currentGradeData != null && _currentGradeData!['books'] != null) {
      final books = _currentGradeData!['books'] as Map<String, dynamic>;
      _subjectOptions = books.keys.map((k) => books[k]['title'] as String).toList();
      _subjectSlugs = Map.fromEntries(
        books.entries.map((e) => MapEntry(e.value['title'] as String, e.key))
      );
    } else {
      _subjectOptions = [];
      _subjectSlugs = {};
    }
    _chapterOptions = [];
    _form.gradeId = gradeId;
    _form.bookId = null;
    _form.chapterId = null;
    setState(() {});
  }

  void _onSubjectChanged(String subjectTitle) {
    if (_currentGradeData == null) return;

    final books = _currentGradeData!['books'] as Map<String, dynamic>;
    final bookId = _subjectSlugs[subjectTitle];
    if (bookId != null && books[bookId] != null) {
      final bookData = books[bookId] as Map<String, dynamic>;
      final chapters = bookData['chapters'] as Map<String, dynamic>?;
      if (chapters != null) {
        _chapterOptions = chapters.keys.map((k) => k).toList()..sort();
      } else {
        _chapterOptions = [];
      }
    }
    _form.bookId = bookId;
    _form.chapterId = null;
    setState(() {});
  }

  // داده‌های Dropdown مطابق PHP



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            cacheExtent: 1000, // افزایش cache برای حفظ widget ها هنگام scroll
            children: [
              // 1) پایه
              _buildDropdown<int>(
                label: 'پایه',
                value: _form.gradeId,
                items: _gradeOptions.map((e) => int.parse(e)).toList(),
                itemLabels: _gradeOptions.map((e) => 'پایه $e').toList(),
                onChanged: (v) {
                  if (v != null) _onGradeChanged(v);
                },
                hint: 'پایه را انتخاب کنید',
              ),

              // 2) درس (وابسته به پایه)
              _buildDropdown<String>(
                label: 'درس',
                value: _subjectOptions.isNotEmpty && _form.bookId != null
                    ? _subjectOptions.firstWhere(
                        (title) => _subjectSlugs[title] == _form.bookId,
                        orElse: () => '')
                    : null,
                items: _subjectOptions,
                onChanged: (v) {
                  if (v != null) _onSubjectChanged(v);
                },
                hint: _subjectOptions.isEmpty ? 'ابتدا پایه را انتخاب کنید' : null,
              ),

              // 3) فصل (وابسته به درس)
              _buildDropdown<String>(
                label: 'فصل',
                value: _form.chapterId,
                items: _chapterOptions,
                onChanged: (v) => setState(() => _form.chapterId = v),
                hint: _chapterOptions.isEmpty ? 'ابتدا درس را انتخاب کنید' : null,
              ),

              // 4) شماره مرحله
              _buildNumberField(
                label: 'شماره مرحله',
                controller: _stepNumberController,
                fieldKey: _stepNumberKey,
                onSaved: (v) => _form.stepNumber = v,
                onChanged: (v) {
                  _form.stepNumber = v;
                },
                hint: 'مثال: 1',
              ),

              // 5) عنوان ویدیو
              _buildTextField(
                label: 'عنوان ویدیو',
                controller: _titleController,
                fieldKey: _titleKey,
                onSaved: (v) => _form.title = v,
                onChanged: (v) {
                  _form.title = v;
                },
                hint: 'مثال: جمع اعداد صحیح',
              ),

              // 6) نوع محتوا
              _buildDropdown<String>(
                label: 'نوع محتوا',
                value: _form.type,
                items: _typeOptions,
                itemLabels: const ['جزوه', 'کتاب درسی', 'نمونه سوال'],
                onChanged: (v) => setState(() => _form.type = v),
              ),

              // 7) نام استاد
              _buildTextField(
                label: 'نام استاد',
                controller: _teacherController,
                fieldKey: _teacherKey,
                onSaved: (v) => _form.teacher = v,
                onChanged: (v) {
                  _form.teacher = v;
                },
                hint: 'مثال: استاد احمدی',
              ),

              // 8) لینک embed ویدیو
              _buildTextField(
                label: 'لینک embed ویدیو',
                controller: _embedUrlController,
                fieldKey: _embedUrlKey,
                onSaved: (v) => _form.embedUrl = v,
                onChanged: (v) {
                  _form.embedUrl = v;
                },
                hint: 'لینک embed آپارات',
              ),

              // 9) لینک مستقیم ویدیو (اختیاری)
              _buildTextField(
                label: 'لینک مستقیم ویدیو (اختیاری)',
                controller: _directUrlController,
                fieldKey: _directUrlKey,
                onSaved: (v) => _form.directUrl = v,
                onChanged: (v) {
                  _form.directUrl = v;
                },
                hint: 'لینک مستقیم ویدیو',
              ),

              // 10) لینک PDF (یک فیلد واحد)
              _buildTextField(
                label: 'لینک PDF (اختیاری)',
                controller: _pdfUrlController,
                fieldKey: _pdfUrlKey,
                onSaved: (v) => _form.pdfUrl = v,
                onChanged: (v) {
                  _form.pdfUrl = v;
                },
                hint: 'لینک PDF جزوه یا نمونه سوال',
              ),

              // 11) مدت زمان (ثانیه)
              _buildNumberField(
                label: 'مدت زمان (ثانیه)',
                controller: _durationController,
                fieldKey: _durationKey,
                onSaved: (v) => _form.duration = v,
                onChanged: (v) {
                  _form.duration = v;
                },
                hint: 'مثال: 3600 برای ۱ ساعت',
              ),

              // 12) لینک تصویر بندانگشتی (اختیاری)
              _buildTextField(
                label: 'لینک تصویر بندانگشتی (اختیاری)',
                controller: _thumbnailUrlController,
                fieldKey: _thumbnailUrlKey,
                onSaved: (v) => _form.thumbnailUrl = v,
                onChanged: (v) {
                  _form.thumbnailUrl = v;
                },
                hint: 'لینک تصویر بندانگشتی',
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
    List<String>? itemLabels,
    required void Function(T?) onChanged,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDropdownState) {
            return DropdownButtonFormField<T>(
              value: items.contains(value) ? value : null,
              items: items
                  .asMap()
                  .entries
                  .map((entry) => DropdownMenuItem<T>(
                        value: entry.value,
                        child: Text(
                          itemLabels != null && itemLabels.length > entry.key
                              ? itemLabels[entry.key]
                              : '${entry.value}',
                          style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                // فقط dropdown rebuild می‌شود، نه کل صفحه
                setDropdownState(() {
                  onChanged(v);
                });
                // فقط برای به‌روزرسانی dropdown های وابسته setState صدا بزن
                if (label == 'شاخه' || label == 'پایه' || label == 'رشته') {
                  setState(() {});
                }
              },
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
                border: const OutlineInputBorder(),
              ),
              isExpanded: true,
            );
          },
        ),
      ),
    );
  }

  // فیلد متنی RTL با فونت ایرانسنس
  Widget _buildTextField({
    required String label,
    required void Function(String?) onSaved,
    TextEditingController? controller,
    void Function(String?)? onChanged,
    Key? fieldKey,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          border: const OutlineInputBorder(),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onSaved: onSaved,
        onChanged: onChanged ?? (value) {
          // همگام‌سازی با form هنگام تایپ (برای جلوگیری از پاک شدن هنگام scroll)
          onSaved(value);
        },
      ),
    );
  }

  // فیلد عددی ساده
  Widget _buildNumberField({
    required String label,
    required void Function(int?) onSaved,
    TextEditingController? controller,
    void Function(int?)? onChanged,
    Key? fieldKey,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
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
        onChanged: (value) {
          // همگام‌سازی با form هنگام تایپ (برای جلوگیری از پاک شدن هنگام scroll)
          final intValue = int.tryParse(value.trim());
          if (onChanged != null) {
            onChanged(intValue);
          } else {
            onSaved(intValue);
          }
        },
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // ذخیره مقادیر فرم از controller ها به _form
    _formKey.currentState?.save();

    // همچنین مقادیر را مستقیماً از controller ها بگیر (برای اطمینان)
    _form.title = _titleController.text.trim().isEmpty ? null : _titleController.text.trim();
    _form.chapterId = _chapterIdController.text.trim().isEmpty ? null : _chapterIdController.text.trim();
    _form.stepNumber = int.tryParse(_stepNumberController.text.trim());
    _form.teacher = _teacherController.text.trim().isEmpty ? null : _teacherController.text.trim();
    _form.embedUrl = _embedUrlController.text.trim().isEmpty ? null : _embedUrlController.text.trim();
    _form.directUrl = _directUrlController.text.trim().isEmpty ? null : _directUrlController.text.trim();
    _form.pdfUrl = _pdfUrlController.text.trim().isEmpty ? null : _pdfUrlController.text.trim();
    _form.duration = int.tryParse(_durationController.text.trim());
    _form.thumbnailUrl = _thumbnailUrlController.text.trim().isEmpty ? null : _thumbnailUrlController.text.trim();

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
        'grade_id': _form.gradeId,
        'book_id': _form.bookId,
        'chapter_id': _form.chapterId,
        'step_number': _form.stepNumber,
        'title': _form.title,
        'type': _form.type,
        'teacher': _form.teacher,
        'embed_url': _form.embedUrl,
        'direct_url': _form.directUrl,
        'pdf_url': _form.pdfUrl,
        'duration': _form.duration,
        'thumbnail_url': _form.thumbnailUrl,
        'active': _form.active ?? true,
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
