import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utils/logger.dart';
import '../../models/step_by_step_upload/step_by_step_upload_form_data.dart';
import '../../services/step_by_step_upload/step_by_step_upload_service.dart';

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

  // Controllers برای حفظ مقادیر فیلدها هنگام scroll
  late final TextEditingController _pdfTitleController = TextEditingController();
  late final TextEditingController _authorController = TextEditingController();
  late final TextEditingController _pdfUrlController = TextEditingController();
  late final TextEditingController _sizeController = TextEditingController();

  // Keys ثابت برای حفظ identity TextFormField ها هنگام rebuild
  final _pdfTitleKey = GlobalKey();
  final _authorKey = GlobalKey();
  final _pdfUrlKey = GlobalKey();
  final _sizeKey = GlobalKey();

  // داده‌های dropdown از JSON
  Map<String, dynamic>? _gradesJson;
  Map<String, dynamic>? _currentGradeData;
  List<String> _gradeOptions = [];
  List<String> _subjectOptions = [];
  Map<String, String> _subjectSlugs = {};

  @override
  void initState() {
    super.initState();
    _loadGradesJson();
    // تنظیم مقادیر اولیه از _form
    _pdfTitleController.text = _form.pdfTitle ?? '';
    _authorController.text = _form.author ?? '';
    _pdfUrlController.text = _form.pdfUrl ?? '';
    _sizeController.text = _form.size?.toString() ?? '';

    // تنظیم مقدار پیش‌فرض برای active
    _form.active = _form.active;
  }

  @override
  void dispose() {
    _pdfTitleController.dispose();
    _authorController.dispose();
    _pdfUrlController.dispose();
    _sizeController.dispose();
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
      _subjectSlugs = books.map((k, v) => MapEntry(v['title'] as String, k));
    } else {
      _subjectOptions = [];
      _subjectSlugs = {};
    }
    setState(() {});
  }

  void _onSubjectChanged(String subjectName) {
    final bookId = _subjectSlugs[subjectName];
    _form.bookId = bookId;
  }

  @override
  Widget build(BuildContext context) {
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
            cacheExtent: 1000, // برای حفظ widgets هنگام scroll
            children: [
              // 1) پایه
              _buildDropdown<int>(
                label: 'پایه',
                value: _form.gradeId,
                items: _gradeOptions.map((g) => int.parse(g)).toList(),
                itemLabels: _gradeOptions,
                onChanged: (gradeId) {
                  if (gradeId != null) {
                    setState(() {
                      _form.gradeId = gradeId;
                      _form.bookId = null;
                      _onGradeChanged(gradeId);
                    });
                  }
                },
              ),

              // 2) درس (وابسته به پایه)
              _buildDropdown<String>(
                label: 'درس',
                value: _subjectOptions.isNotEmpty ? _subjectOptions.firstWhere(
                  (s) => _subjectSlugs[s] == _form.bookId,
                  orElse: () => '',
                ) : null,
                items: _subjectOptions,
                onChanged: (subjectName) {
                  if (subjectName != null) {
                    _onSubjectChanged(subjectName);
                  }
                },
                hint: _subjectOptions.isEmpty ? 'ابتدا پایه را انتخاب کنید' : null,
              ),

              // 3) عنوان PDF
              _buildTextField(
                label: 'عنوان PDF',
                controller: _pdfTitleController,
                onSaved: (v) => _form.pdfTitle = v?.trim(),
                onChanged: (v) => _form.pdfTitle = v?.trim(),
                fieldKey: _pdfTitleKey,
                hint: 'مثال: گام به گام ریاضی - فصل اول',
                maxLength: 200,
              ),

              // 4) نویسنده
              _buildTextField(
                label: 'نویسنده',
                controller: _authorController,
                onSaved: (v) => _form.author = v?.trim(),
                onChanged: (v) => _form.author = v?.trim(),
                fieldKey: _authorKey,
                hint: 'نام نویسنده یا مؤلف',
                maxLength: 100,
              ),

              // 5) لینک PDF
              _buildTextField(
                label: 'لینک PDF',
                controller: _pdfUrlController,
                onSaved: (v) => _form.pdfUrl = v?.trim(),
                onChanged: (v) => _form.pdfUrl = v?.trim(),
                fieldKey: _pdfUrlKey,
                hint: 'https://...',
                maxLength: 500,
              ),

              // 6) حجم فایل (اختیاری)
              _buildDoubleField(
                label: 'حجم فایل (مگابایت) - اختیاری',
                controller: _sizeController,
                onSaved: (v) => _form.size = v,
                onChanged: (v) => _form.size = v,
                fieldKey: _sizeKey,
                hint: 'مثال: 2.5',
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
    void Function(double?)? onChanged,
    TextEditingController? controller,
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
        onChanged: (value) {
          // همگام‌سازی با form هنگام تایپ (برای جلوگیری از پاک شدن هنگام scroll)
          final doubleValue = value.trim().isEmpty ? null : double.tryParse(value.trim());
          if (onChanged != null) {
            onChanged(doubleValue);
          } else {
            onSaved(doubleValue);
          }
        },
      ),
    );
  }

  // فیلد متنی ساده با controller و onChanged
  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    void Function(String?)? onSaved,
    void Function(String?)? onChanged,
    Key? fieldKey,
    String? hint,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
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
        onChanged: onChanged ?? (value) {
          // همگام‌سازی با form هنگام تایپ (برای جلوگیری از پاک شدن هنگام scroll)
          onSaved?.call(value);
        },
      ),
    );
  }

  // Dropdown عمومی RTL با پشتیبانی از itemLabels
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
        child: DropdownButtonFormField<T>(
          value: items.contains(value) ? value : null,
          items: items
              .asMap()
              .entries
              .map((entry) => DropdownMenuItem<T>(
                    value: entry.value,
                    child: Text(
                      itemLabels != null && entry.key < itemLabels.length
                          ? itemLabels[entry.key]
                          : entry.value.toString(),
                      style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            onChanged(v);
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
      final payload = {
        'grade_id': _form.gradeId,
        'book_id': _form.bookId,
        'pdf_title': _form.pdfTitle,
        'author': _form.author,
        'size': _form.size,
        'pdf_url': _form.pdfUrl,
        'active': _form.active,
      };

      Logger.info('📤 [STEP-BY-STEP-UPLOAD] ارسال به سرور: $payload');

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

