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

  const VideoEditScreen({super.key, required this.video});

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _form = VideoUploadFormData();
  final _service = VideoEditService();
  bool _submitting = false;
  bool _loading = true;
  DateTime? _createdAt;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadVideoData();
  }

  /// بارگذاری داده‌های ویدیو و پر کردن فرم
  Future<void> _loadVideoData() async {
    try {
      Logger.info(
        '📥 [VIDEO-EDIT] بارگذاری داده‌های ویدیو ID: ${widget.video.id}',
      );

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('lesson_videos')
          .select('*')
          .eq('video_id', widget.video.videoId)
          .single();

      final row = Map<String, dynamic>.from(response as Map);
      final duration = (row['duration'] as num?)?.toInt() ?? 0;

      setState(() {
        _form.gradeId = (row['grade_id'] as num?)?.toInt();
        // book_id و chapter_id در جدول از نوع text هستند - همیشه به string تبدیل می‌کنیم
        _form.bookId = row['book_id']?.toString().trim() ?? '';
        _form.chapterId = row['chapter_id']?.toString().trim() ?? '';
        _form.stepNumber = (row['step_number'] as num?)?.toInt();
        _form.title = row['title'] as String?;
        _form.type = row['type'] as String?;
        _form.teacher = row['teacher'] as String?;
        _form.embedUrl = row['embed_url'] as String?;
        _form.directUrl = row['direct_url'] as String?;
        _form.pdfUrl = row['pdf_url'] as String?;
        _form.thumbnailUrl = row['thumbnail_url'] as String?;
        _form.duration = duration;
        _form.durationHours = duration ~/ 3600;
        _form.durationMinutes = (duration % 3600) ~/ 60;
        _form.durationSeconds = duration % 60;
        _form.likesCount = (row['likes_count'] as num?)?.toInt();
        _form.viewsCount = (row['views_count'] as num?)?.toInt();
        _form.active = row['active'] as bool? ?? true;

        _createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
        _updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '');

        _loading = false;
      });

      Logger.info('✅ [VIDEO-EDIT] داده‌های lesson_videos بارگذاری شد');
    } catch (e) {
      Logger.error('❌ [VIDEO-EDIT] خطا در بارگذاری داده‌های ویدیو', e);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ خطا: ${e.toString()}',
              textDirection: TextDirection.rtl,
            ),
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
          body: const Center(child: CircularProgressIndicator()),
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
              _buildInfoCard('شناسه ویدیو', widget.video.videoId.toString()),
              if (_createdAt != null)
                _buildInfoCard('تاریخ ایجاد', _createdAt!.toIso8601String()),
              if (_updatedAt != null)
                _buildInfoCard(
                  'تاریخ بروزرسانی',
                  _updatedAt!.toIso8601String(),
                ),

              const Divider(height: 32),

              _buildNumberField(
                label: 'پایه (grade_id)',
                initialValue: _form.gradeId,
                onSaved: (v) => _form.gradeId = v,
                hint: 'مثال: 9',
                onChanged: (v) => _form.gradeId = v,
              ),

              _buildTextField(
                label: 'شناسه درس (book_id)',
                initialValue: _form.bookId,
                onSaved: (v) => _form.bookId = v?.toString().trim() ?? '',
                hint: 'مثال: riazi یا 1',
                maxLength: 50,
                onChanged: (v) => _form.bookId = v.toString().trim(),
              ),

              _buildTextField(
                label: 'شناسه فصل (chapter_id)',
                initialValue: _form.chapterId,
                onSaved: (v) => _form.chapterId = v?.toString().trim() ?? '',
                hint: 'مثال: 1',
                maxLength: 50,
                onChanged: (v) => _form.chapterId = v.toString().trim(),
              ),

              _buildNumberField(
                label: 'شماره مرحله (step_number)',
                initialValue: _form.stepNumber,
                onSaved: (v) => _form.stepNumber = v,
                hint: 'مثال: 1',
                onChanged: (v) => _form.stepNumber = v,
              ),

              _buildTextField(
                label: 'عنوان ویدیو (title)',
                initialValue: _form.title,
                onSaved: (v) => _form.title = v,
                hint: 'مثال: مجموعه‌ها - بخش اول',
                maxLength: 150,
                onChanged: (v) => _form.title = v,
              ),

              _buildTextField(
                label: 'نوع محتوا (type)',
                initialValue: _form.type,
                onSaved: (v) => _form.type = v?.trim(),
                hint: 'note / book / exam',
                maxLength: 50,
                onChanged: (v) => _form.type = v.trim(),
              ),

              _buildTextField(
                label: 'نام استاد (teacher)',
                initialValue: _form.teacher,
                onSaved: (v) => _form.teacher = v?.trim(),
                hint: 'مثال: استاد احمدی',
                maxLength: 80,
                onChanged: (v) => _form.teacher = v.trim(),
              ),

              _buildTextField(
                label: 'Embed URL',
                initialValue: _form.embedUrl,
                onSaved: (v) => _form.embedUrl = v,
                hint: 'https://www.aparat.com/v/....',
                maxLength: 2000,
                onChanged: (v) => _form.embedUrl = v,
              ),

              _buildTextField(
                label: 'Direct URL (اختیاری)',
                initialValue: _form.directUrl,
                onSaved: (v) => _form.directUrl = v,
                hint: 'https://cdn.example.com/video.mp4',
                maxLength: 500,
                onChanged: (v) => _form.directUrl = v,
              ),

              _buildTextField(
                label: 'PDF URL (اختیاری)',
                initialValue: _form.pdfUrl,
                onSaved: (v) => _form.pdfUrl = v,
                hint: 'https://example.com/file.pdf',
                maxLength: 500,
                onChanged: (v) => _form.pdfUrl = v,
              ),

              _buildTextField(
                label: 'Thumbnail URL (اختیاری)',
                initialValue: _form.thumbnailUrl,
                onSaved: (v) => _form.thumbnailUrl = v,
                hint: 'https://example.com/thumb.png',
                maxLength: 500,
                onChanged: (v) => _form.thumbnailUrl = v,
              ),

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
                      onChanged: (value) => _form.durationHours = value,
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
                      onChanged: (value) => _form.durationMinutes = value,
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
                      onChanged: (value) => _form.durationSeconds = value,
                    ),
                  ),
                ],
              ),

              _buildNumberField(
                label: 'تعداد لایک (likes_count)',
                initialValue: _form.likesCount ?? 0,
                onSaved: (v) => _form.likesCount = v,
                hint: 'مثال: 120',
                minValue: 0,
                isRequired: false,
                onChanged: (v) => _form.likesCount = v,
              ),

              _buildNumberField(
                label: 'تعداد بازدید (views_count)',
                initialValue: _form.viewsCount ?? 0,
                onSaved: (v) => _form.viewsCount = v,
                hint: 'مثال: 4500',
                minValue: 0,
                isRequired: false,
                onChanged: (v) => _form.viewsCount = v,
              ),

              SwitchListTile(
                title: const Text(
                  'فعال باشد؟',
                  style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                ),
                value: _form.active ?? true,
                onChanged: (value) => setState(() => _form.active = value),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
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
    void Function(String)? onChanged,
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
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required void Function(int?) onSaved,
    void Function(int?)? onChanged,
    String? hint,
    int? initialValue,
    int minValue = 1,
    bool isRequired = true,
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
            if (onChanged != null) onChanged(null);
          } else {
            final parsed = int.tryParse(cleaned);
            if (parsed != null) {
              onSaved(parsed);
              if (onChanged != null) onChanged(parsed);
            } else {
              Logger.error('❌ [VIDEO-EDIT] خطا در parse کردن عدد: $cleaned');
              onSaved(null);
              if (onChanged != null) onChanged(null);
            }
          }
        },
        validator: (v) {
          final cleaned = v?.trim() ?? '';
          if (cleaned.isEmpty) {
            return isRequired ? 'این فیلد الزامی است' : null;
          }
          final parsed = int.tryParse(cleaned);
          if (parsed == null) {
            return 'لطفاً یک عدد معتبر وارد کنید';
          }
          if (parsed < minValue) {
            return 'عدد باید بزرگتر یا مساوی $minValue باشد';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDurationField({
    required String label,
    required void Function(int?) onSaved,
    void Function(int)? onChanged,
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
            if (onChanged != null) onChanged(minValue);
          } else {
            final parsed = int.tryParse(cleaned);
            if (parsed != null) {
              onSaved(parsed);
              if (onChanged != null) onChanged(parsed);
            } else {
              Logger.error('❌ [VIDEO-EDIT] خطا در parse کردن عدد: $cleaned');
              onSaved(minValue);
              if (onChanged != null) onChanged(minValue);
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
    if (_form.gradeId == null || _form.gradeId! < 1) {
      err = 'پایه را وارد کنید';
    } else if (_form.bookId == null || _form.bookId!.isEmpty) {
      err = 'شناسه درس (book_id) را وارد کنید';
    } else if (_form.chapterId == null || _form.chapterId!.isEmpty) {
      err = 'شناسه فصل (chapter_id) را وارد کنید';
    } else if (_form.stepNumber == null || _form.stepNumber! < 1) {
      err = 'شماره مرحله (step_number) را وارد کنید (>=1)';
    } else if (_form.title == null || _form.title!.isEmpty) {
      err = 'عنوان ویدیو را وارد کنید';
    } else if (_form.type == null || _form.type!.isEmpty) {
      err = 'نوع محتوا را وارد کنید';
    } else if (_form.teacher == null || _form.teacher!.isEmpty) {
      err = 'نام استاد را وارد کنید';
    } else if (_form.embedUrl == null || _form.embedUrl!.isEmpty) {
      err = 'Embed URL را وارد کنید';
    } else if (_form.durationInSeconds <= 0) {
      err = 'مدت زمان باید بیشتر از صفر باشد';
    }

    if (err != null) {
      Logger.error('❌ [VIDEO-EDIT] Validation خطا: $err');
      Logger.error(
        '❌ [VIDEO-EDIT] chapterOrder: ${_form.chapterOrder}, lessonOrder: ${_form.lessonOrder}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err, textDirection: TextDirection.rtl)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      Logger.info(
        '🔄 [VIDEO-EDIT] شروع به‌روزرسانی ویدیو ID: ${widget.video.id}',
      );

      // تبدیل type به فرمت استاندارد
      final styleMap = {
        'note': 'note',
        'book': 'book',
        'exam': 'exam',
        'sample': 'exam',
        'جزوه': 'note',
        'کتاب درسی': 'book',
        'نمونه سوال': 'exam',
      };
      final normalizedType = styleMap[_form.type?.toLowerCase()] ?? 'note';

      // تبدیل book_id و chapter_id به string (مطابق schema جدول - text)
      // استفاده از toString() برای اطمینان از تبدیل به string حتی اگر عدد باشد
      final normalizedBookId = (_form.bookId?.toString() ?? '').trim();
      final normalizedChapterId = (_form.chapterId?.toString() ?? '').trim();

      // لاگ برای دیباگ - بررسی نوع داده
      Logger.info(
        '🔍 [VIDEO-EDIT] normalizedBookId: "$normalizedBookId" (type: ${normalizedBookId.runtimeType})',
      );
      Logger.info(
        '🔍 [VIDEO-EDIT] normalizedChapterId: "$normalizedChapterId" (type: ${normalizedChapterId.runtimeType})',
      );

      // آماده‌سازی updates (بدون video_id - video_id در root payload است)
      // اطمینان از اینکه book_id و chapter_id همیشه string هستند (نه int)
      final updates = <String, dynamic>{
        'grade_id': _form.gradeId,
        'book_id': normalizedBookId.isEmpty
            ? ''
            : normalizedBookId.toString(), // text در schema - اطمینان از string
        'chapter_id': normalizedChapterId.isEmpty
            ? ''
            : normalizedChapterId
                  .toString(), // text در schema - اطمینان از string
        'step_number': _form.stepNumber,
        'title': _form.title,
        'type': normalizedType,
        'teacher': _form.teacher,
        'embed_url': _form.embedUrl,
        'direct_url': _form.directUrl?.isNotEmpty == true
            ? _form.directUrl
            : null,
        'pdf_url': _form.pdfUrl?.isNotEmpty == true ? _form.pdfUrl : null,
        'thumbnail_url': _form.thumbnailUrl?.isNotEmpty == true
            ? _form.thumbnailUrl
            : null,
        'duration': _form.durationInSeconds,
        'likes_count': _form.likesCount ?? 0,
        'views_count': _form.viewsCount ?? 0,
        'active': _form.active ?? true,
      };

      await _service.updateVideo(
        videoId: widget.video.videoId,
        updates: updates,
      );

      if (!mounted) return;
      Logger.info('✅ [VIDEO-EDIT] ویدیو با موفقیت به‌روزرسانی شد');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ ویدیو با موفقیت به‌روزرسانی شد',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // بازگشت با نتیجه موفق
    } catch (e) {
      Logger.error('❌ [VIDEO-EDIT] خطا در به‌روزرسانی', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ خطا: ${e.toString()}',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
