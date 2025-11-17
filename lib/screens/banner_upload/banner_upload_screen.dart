import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import '../../models/banner_upload/banner_upload_form_data.dart';
import '../../services/banner_upload/banner_upload_service.dart';

/// صفحه آپلود بنر
class BannerUploadScreen extends StatefulWidget {
  const BannerUploadScreen({super.key});

  @override
  State<BannerUploadScreen> createState() => _BannerUploadScreenState();
}

class _BannerUploadScreenState extends State<BannerUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _form = BannerUploadFormData();
  final _service = BannerUploadService();
  bool _submitting = false;

  // Controllers برای حفظ مقادیر فیلدها هنگام scroll
  late final TextEditingController _titleController = TextEditingController();
  late final TextEditingController _descriptionController = TextEditingController();
  late final TextEditingController _imageUrlController = TextEditingController();
  late final TextEditingController _linkUrlController = TextEditingController();
  late final TextEditingController _positionController = TextEditingController();

  // Keys ثابت برای حفظ identity TextFormField ها هنگام rebuild
  final _titleKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _imageUrlKey = GlobalKey();
  final _linkUrlKey = GlobalKey();
  final _positionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // تنظیم مقادیر اولیه از _form
    _titleController.text = _form.title ?? '';
    _descriptionController.text = _form.description ?? '';
    _imageUrlController.text = _form.imageUrl ?? '';
    _linkUrlController.text = _form.linkUrl ?? '';
    _positionController.text = _form.position?.toString() ?? '';

    // تنظیم مقدار پیش‌فرض برای active
    _form.isActive = _form.isActive;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _linkUrlController.dispose();
    _positionController.dispose();
    super.dispose();
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
            'آپلود بنر',
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            cacheExtent: 1000, // برای حفظ widgets هنگام scroll
            children: [
              // 1) عنوان بنر
              _buildTextField(
                label: 'عنوان بنر',
                controller: _titleController,
                onSaved: (v) => _form.title = v?.trim(),
                onChanged: (v) => _form.title = v?.trim(),
                fieldKey: _titleKey,
                hint: 'مثال: دوره تابستانی ریاضی',
                maxLength: 200,
              ),

              // 2) توضیحات بنر
              _buildTextField(
                label: 'توضیحات بنر',
                controller: _descriptionController,
                onSaved: (v) => _form.description = v?.trim(),
                onChanged: (v) => _form.description = v?.trim(),
                fieldKey: _descriptionKey,
                hint: 'توضیح مختصر درباره بنر',
                maxLength: 500,
                maxLines: 3,
              ),

              // 3) لینک تصویر بنر
              _buildTextField(
                label: 'لینک تصویر بنر',
                controller: _imageUrlController,
                onSaved: (v) => _form.imageUrl = v?.trim(),
                onChanged: (v) => _form.imageUrl = v?.trim(),
                fieldKey: _imageUrlKey,
                hint: 'https://example.com/banner.jpg',
                maxLength: 500,
              ),

              // 4) لینک مقصد (اختیاری)
              _buildTextField(
                label: 'لینک مقصد (اختیاری)',
                controller: _linkUrlController,
                onSaved: (v) => _form.linkUrl = v?.trim().isEmpty == true ? null : v?.trim(),
                onChanged: (v) => _form.linkUrl = v?.trim().isEmpty == true ? null : v?.trim(),
                fieldKey: _linkUrlKey,
                hint: 'https://example.com/course',
                maxLength: 500,
              ),

              // 5) موقعیت نمایش
              _buildIntField(
                label: 'موقعیت نمایش',
                controller: _positionController,
                onSaved: (v) => _form.position = v,
                onChanged: (v) => _form.position = v,
                fieldKey: _positionKey,
                hint: '۱ = بالاترین، اعداد بالاتر = پایین‌تر',
              ),

              // 6) فعال/غیرفعال
              Row(
                children: [
                  Checkbox(
                    value: _form.isActive,
                    onChanged: (v) => setState(() => _form.isActive = v ?? true),
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
                        'ارسال بنر',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
              ),
            ],
          ),
        ),
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
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
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

  // فیلد عددی برای int
  Widget _buildIntField({
    required String label,
    TextEditingController? controller,
    required void Function(int?) onSaved,
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
        onSaved: (v) {
          if (v == null || v.trim().isEmpty) {
            onSaved(null);
            return;
          }
          onSaved(int.tryParse(v.trim()));
        },
        onChanged: (value) {
          // همگام‌سازی با form هنگام تایپ (برای جلوگیری از پاک شدن هنگام scroll)
          final intValue = value.trim().isEmpty ? null : int.tryParse(value.trim());
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
        'title': _form.title,
        'description': _form.description,
        'image_url': _form.imageUrl,
        'link_url': _form.linkUrl,
        'position': _form.position,
        'is_active': _form.isActive,
      };

      Logger.info('📤 [BANNER-UPLOAD] ارسال به سرور: $payload');

      await _service.uploadBanner(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ بنر با موفقیت ثبت شد', textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      Logger.error('❌ [BANNER-UPLOAD] Error', e);
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
