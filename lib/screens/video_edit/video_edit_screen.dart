import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/logger.dart';
import '../../models/content/lesson_video.dart';
import '../../models/video_upload/video_upload_form_data.dart';
import '../../services/video_edit/video_edit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        _form.teacherName = teacherName; // پر کردن نام استاد در فرم
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
              
              const Divider(height: 32),
              
              // فیلدهای قابل ویرایش
              // عنوان فصل (100 کاراکتر - استاندارد برای عنوان)
              _buildTextField(
                label: 'عنوان فصل',
                initialValue: _form.chapterTitle,
                onSaved: (v) => _form.chapterTitle = v,
                hint: 'مثال: فصل اول - اعداد صحیح',
                maxLength: 100,
              ),
              
              // شماره فصل
              _buildNumberField(
                label: 'شماره فصل',
                initialValue: _form.chapterOrder,
                onSaved: (v) => _form.chapterOrder = v,
                hint: 'مثال: 1',
              ),
              
              // عنوان درس (100 کاراکتر - استاندارد برای عنوان)
              _buildTextField(
                label: 'عنوان درس',
                initialValue: _form.lessonTitle,
                onSaved: (v) => _form.lessonTitle = v,
                hint: 'مثال: درس اول - جمع اعداد',
                maxLength: 100,
              ),
              
              // شماره درس
              _buildNumberField(
                label: 'شماره درس',
                initialValue: _form.lessonOrder,
                onSaved: (v) => _form.lessonOrder = v,
                hint: 'مثال: 1',
              ),
              
              // نام استاد (50 کاراکتر - کافی برای نام)
              _buildTextField(
                label: 'نام استاد',
                initialValue: _teacherName ?? '',
                onSaved: (v) => _form.teacherName = v,
                hint: 'مثال: استاد احمدی',
                maxLength: 50,
              ),
              
              // نوع محتوا (50 کاراکتر - فقط چند کلمه)
              _buildTextField(
                label: 'نوع محتوا (جزوه/نمونه سوال/کتاب درسی)',
                initialValue: _form.style,
                onSaved: (v) => _form.style = v,
                hint: 'جزوه / کتاب درسی / نمونه سوال',
                maxLength: 50,
              ),

              // مدت زمان
              Row(
                children: [
                  Expanded(
                    child: _buildDurationField(
                      label: 'ساعت',
                      initialValue: _form.durationHours ?? 0,
                      onSaved: (v) => _form.durationHours = v ?? 0,
                      hint: '0',
                      minValue: 0,
                      maxValue: 23,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDurationField(
                      label: 'دقیقه',
                      initialValue: _form.durationMinutes ?? 0,
                      onSaved: (v) => _form.durationMinutes = v ?? 0,
                      hint: '0-59',
                      minValue: 0,
                      maxValue: 59,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDurationField(
                      label: 'ثانیه',
                      initialValue: _form.durationSeconds ?? 0,
                      onSaved: (v) => _form.durationSeconds = v ?? 0,
                      hint: '0-59',
                      minValue: 0,
                      maxValue: 59,
                    ),
                  ),
                ],
              ),

              // سایر فیلدها
              // تگ‌ها (200 کاراکتر - ممکنه چند تگ باشه)
              _buildTextField(
                label: 'تگ‌ها (با کاما جدا کنید)',
                initialValue: _form.tags,
                onSaved: (v) => _form.tags = v,
                hint: 'مثال: حد, پایه ۹, تابع',
                maxLength: 200,
              ),
              // Embed HTML (2000 کاراکتر - کد HTML ممکنه طولانی باشه)
              _buildTextField(
                label: 'Embed HTML آپارات (اختیاری)',
                initialValue: _form.embedHtml,
                onSaved: (v) => _form.embedHtml = v,
                hint: '<script src="https://www.aparat.com/embed/..." ></script>',
                maxLines: 3,
                maxLength: 2000,
              ),
              // لینک PDF (500 کاراکتر - URL ممکنه طولانی باشه)
              _buildTextField(
                label: 'لینک PDF جزوه (اختیاری)',
                initialValue: _form.notePdfUrl,
                onSaved: (v) => _form.notePdfUrl = v,
                hint: 'https://...',
                maxLength: 500,
              ),
              // لینک PDF (500 کاراکتر - URL ممکنه طولانی باشه)
              _buildTextField(
                label: 'لینک PDF نمونه سوال (اختیاری)',
                initialValue: _form.exercisePdfUrl,
                onSaved: (v) => _form.exercisePdfUrl = v,
                hint: 'https://...',
                maxLength: 500,
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
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: initialValue,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          border: const OutlineInputBorder(),
          counterText: '', // مخفی کردن شمارنده کاراکتر
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
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly, // فقط اعداد (0-9)
        ],
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onSaved: (v) {
          // تبدیل string به int با اطمینان
          final cleaned = v?.trim() ?? '';
          if (cleaned.isEmpty) {
            onSaved(null);
          } else {
            final parsed = int.tryParse(cleaned);
            if (parsed != null) {
              onSaved(parsed);
            } else {
              Logger.error('❌ [VIDEO-EDIT] خطا در parse کردن عدد: $cleaned');
              onSaved(null);
            }
          }
        },
        validator: (v) {
          // Validation برای اطمینان از اینکه عدد معتبر است
          final cleaned = v?.trim() ?? '';
          if (cleaned.isEmpty) {
            return 'این فیلد الزامی است';
          }
          final parsed = int.tryParse(cleaned);
          if (parsed == null) {
            return 'لطفاً یک عدد معتبر وارد کنید';
          }
          if (parsed < 1) {
            return 'عدد باید بزرگتر یا مساوی 1 باشد';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDurationField({
    required String label,
    required void Function(int?) onSaved,
    String? hint,
    required int initialValue,
    int minValue = 0,
    int? maxValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: initialValue.toString(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly, // فقط اعداد (0-9)
        ],
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onSaved: (v) {
          // تبدیل string به int با اطمینان
          final cleaned = v?.trim() ?? '';
          if (cleaned.isEmpty) {
            onSaved(minValue);
          } else {
            final parsed = int.tryParse(cleaned);
            if (parsed != null) {
              onSaved(parsed);
            } else {
              Logger.error('❌ [VIDEO-EDIT] خطا در parse کردن عدد: $cleaned');
              onSaved(minValue);
            }
          }
        },
        validator: (v) {
          // Validation برای مدت زمان
          final cleaned = v?.trim() ?? '';
          if (cleaned.isEmpty) {
            return null; // اختیاری است
          }
          final parsed = int.tryParse(cleaned);
          if (parsed == null) {
            return 'لطفاً یک عدد معتبر وارد کنید';
          }
          if (parsed < minValue) {
            return 'عدد باید بزرگتر یا مساوی $minValue باشد';
          }
          if (maxValue != null && parsed > maxValue) {
            return 'عدد باید کوچکتر یا مساوی $maxValue باشد';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _handleUpdate() async {
    // ابتدا validation فرم را بررسی کن (که شامل validator های TextFormField است)
    if (!_formKey.currentState!.validate()) {
      Logger.error('❌ [VIDEO-EDIT] Validation فرم نامعتبر است');
      return;
    }
    
    // ذخیره مقادیر فرم
    _formKey.currentState?.save();

    // اعتبارسنجی فیلدهای قابل ویرایش (بعد از save)
    String? err;
    if (_form.chapterTitle == null || _form.chapterTitle!.isEmpty) {
      err = 'عنوان فصل را وارد کنید';
    } else if (_form.chapterOrder == null || _form.chapterOrder! < 1) {
      err = 'شماره فصل را وارد کنید (باید >= 1 باشد)';
    } else if (_form.lessonTitle == null || _form.lessonTitle!.isEmpty) {
      err = 'عنوان درس را وارد کنید';
    } else if (_form.lessonOrder == null || _form.lessonOrder! < 1) {
      err = 'شماره درس را وارد کنید (باید >= 1 باشد)';
    } else if (_form.teacherName == null || _form.teacherName!.isEmpty) {
      err = 'نام استاد را وارد کنید';
    } else if (_form.style == null || _form.style!.isEmpty) {
      err = 'نوع محتوا را وارد کنید';
    } else if (_form.durationInSeconds <= 0) {
      err = 'مدت زمان باید بیشتر از صفر باشد';
    }
    
    if (err != null) {
      Logger.error('❌ [VIDEO-EDIT] Validation خطا: $err');
      Logger.error('❌ [VIDEO-EDIT] chapterOrder: ${_form.chapterOrder}, lessonOrder: ${_form.lessonOrder}');
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

      // آماده‌سازی updates
      final updates = <String, dynamic>{
        'chapter_title': _form.chapterTitle,
        'chapter_order': _form.chapterOrder,
        'lesson_title': _form.lessonTitle,
        'lesson_order': _form.lessonOrder,
        'teacher_name': _form.teacherName,
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

