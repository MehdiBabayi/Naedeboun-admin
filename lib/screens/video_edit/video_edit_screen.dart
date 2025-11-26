import 'dart:convert';

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
  bool _dropdownsInitialized = false;
  bool _gradesLoading = true;
  bool _booksLoading = false;
  bool _chaptersLoading = false;
  Map<int, _GradeConfig> _gradesConfig = {};
  List<_DropdownOption<int>> _gradeOptions = [];
  List<_DropdownOption<String>> _bookOptions = [];
  List<_DropdownOption<String>> _chapterOptions = [];
  Map<String, Map<String, String>> _chaptersByBookId = {};
  int? _selectedGradeId;
  String? _selectedBookId;
  String? _selectedChapterId;
  String? _selectedType;
  static const List<_DropdownOption<String>> _contentTypeOptions = [
    _DropdownOption<String>(value: 'note', label: 'جزوه'),
    _DropdownOption<String>(value: 'book', label: 'کتاب درسی'),
    _DropdownOption<String>(value: 'exam', label: 'نمونه سوال'),
  ];

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
        _selectedType = _form.type;

        _loading = false;
      });

      if (mounted) {
        await _initializeDropdowns();
      }

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

  Future<void> _initializeDropdowns() async {
    if (_dropdownsInitialized) return;
    await _loadGradeOptions();
    final initialGradeId = _form.gradeId;
    final initialBookId = _form.bookId?.isNotEmpty == true ? _form.bookId : null;
    final initialChapterId =
        _form.chapterId?.isNotEmpty == true ? _form.chapterId : null;

    if (initialGradeId != null &&
        _gradesConfig.containsKey(initialGradeId)) {
      await _handleGradeChange(
        initialGradeId,
        isInitial: true,
        initialBookId: initialBookId,
        initialChapterId: initialChapterId,
      );
    } else {
      setState(() {
        _gradesLoading = false;
      });
    }

    _dropdownsInitialized = true;
  }

  Future<void> _loadGradeOptions() async {
    if (_gradeOptions.isNotEmpty) {
      setState(() {
        _gradesLoading = false;
      });
      return;
    }
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/grades.json');
      final Map<String, dynamic> gradesMap = jsonDecode(jsonString);
      final List<_DropdownOption<int>> options = [];
      final Map<int, _GradeConfig> configs = {};

      gradesMap.forEach((idString, value) {
        final gradeId = int.tryParse(idString);
        if (gradeId == null) return;
        if (value is! Map<String, dynamic>) return;
        final title = (value['title'] as String? ?? '').trim();
        final path = (value['path'] as String? ?? '').trim();
        if (path.isEmpty) return;
        configs[gradeId] = _GradeConfig(title: title, path: path);
        options.add(
          _DropdownOption<int>(
            value: gradeId,
            label: title.isNotEmpty ? title : 'پایه $gradeId',
          ),
        );
      });

      options.sort((a, b) => a.value.compareTo(b.value));

      setState(() {
        _gradesConfig = configs;
        _gradeOptions = options;
        _gradesLoading = false;
      });
    } catch (e) {
      Logger.error('❌ [VIDEO-EDIT] خطا در خواندن grades.json', e);
      setState(() {
        _gradesLoading = false;
      });
    }
  }

  Future<void> _handleGradeChange(
    int gradeId, {
    bool isInitial = false,
    String? initialBookId,
    String? initialChapterId,
  }) async {
    if (!_gradesConfig.containsKey(gradeId)) {
      Logger.error('❌ [VIDEO-EDIT] gradeId $gradeId در فایل grades.json پیدا نشد');
      return;
    }

    setState(() {
      _selectedGradeId = gradeId;
      _form.gradeId = gradeId;
      _booksLoading = true;
      if (!isInitial) {
        _selectedBookId = null;
        _form.bookId = '';
        _selectedChapterId = null;
        _form.chapterId = '';
        _chapterOptions = [];
      }
    });

    final gradeConfig = _gradesConfig[gradeId]!;
    final bookResult = await _loadBooksForGrade(gradeConfig.path);

    if (!mounted) return;

    setState(() {
      _booksLoading = false;
    });

    if (bookResult == null) {
      return;
    }

    final nextBookId = isInitial ? initialBookId : null;
    if (nextBookId != null &&
        bookResult.chaptersByBookId.containsKey(nextBookId)) {
      await _handleBookChange(
        nextBookId,
        isInitial: true,
        initialChapterId: initialChapterId,
        chaptersByBookId: bookResult.chaptersByBookId,
      );
    }
  }

  Future<_BookLoadResult?> _loadBooksForGrade(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> gradeJson = jsonDecode(jsonString);
      final books = gradeJson['books'] as Map<String, dynamic>? ?? {};
      final List<_DropdownOption<String>> bookOptions = [];
      final Map<String, Map<String, String>> chaptersByBookId = {};

      for (final bookEntry in books.entries) {
        final bookId = bookEntry.key;
        final bookValue = bookEntry.value;
        if (bookValue is! Map<String, dynamic>) continue;

        for (final slugEntry in bookValue.entries) {
          final Map<String, dynamic> bookMeta =
              Map<String, dynamic>.from(slugEntry.value as Map);
          final title = (bookMeta['title'] as String? ?? '').trim();
          final displayTitle =
              title.isNotEmpty ? title : slugEntry.key.toString();

          bookOptions.add(
            _DropdownOption<String>(
              value: bookId,
              label: displayTitle,
            ),
          );

          final Map<String, String> chapterMap = {};
          final chapters = bookMeta['chapters'] as Map<String, dynamic>? ?? {};
          for (final chapterEntry in chapters.entries) {
            final chapterTitle = chapterEntry.value is Map
                ? (chapterEntry.value['title'] as String? ??
                    chapterEntry.value.toString())
                : chapterEntry.value.toString();
            chapterMap[chapterEntry.key.toString()] =
                chapterTitle.trim().isEmpty
                    ? 'فصل ${chapterEntry.key}'
                    : chapterTitle.trim();
          }
          chaptersByBookId[bookId] = chapterMap;
        }
      }

      bookOptions.sort(
        (a, b) => a.label.compareTo(b.label),
      );

      setState(() {
        _bookOptions = bookOptions;
        _chaptersByBookId = chaptersByBookId;
      });

      return _BookLoadResult(
        options: bookOptions,
        chaptersByBookId: chaptersByBookId,
      );
    } catch (e) {
      Logger.error(
        '❌ [VIDEO-EDIT] خطا در خواندن فایل ویدیوهای پایه: $assetPath',
        e,
      );
      setState(() {
        _bookOptions = [];
        _chaptersByBookId = {};
      });
      return null;
    }
  }

  Future<void> _handleBookChange(
    String bookId, {
    bool isInitial = false,
    String? initialChapterId,
    Map<String, Map<String, String>>? chaptersByBookId,
  }) async {
    if (chaptersByBookId != null) {
      _chaptersByBookId = chaptersByBookId;
    }
    final chaptersMap = _chaptersByBookId[bookId] ?? {};

    setState(() {
      _selectedBookId = bookId;
      _form.bookId = bookId;
      _chaptersLoading = true;
    });

    final options = chaptersMap.entries
        .map(
          (entry) => _DropdownOption<String>(
            value: entry.key,
            label: entry.value,
          ),
        )
        .toList();

    options.sort((a, b) => a.value.compareTo(b.value));

    setState(() {
      _chapterOptions = options;
      _chaptersLoading = false;
    });

    final targetChapterId = isInitial ? initialChapterId : null;
    if (targetChapterId != null &&
        chaptersMap.containsKey(targetChapterId)) {
      _handleChapterChange(targetChapterId, isInitial: true);
    } else if (!isInitial) {
      _handleChapterChange('', clearOnly: true);
    }
  }

  void _handleChapterChange(
    String chapterId, {
    bool isInitial = false,
    bool clearOnly = false,
  }) {
    if (clearOnly) {
      setState(() {
        _selectedChapterId = null;
        _form.chapterId = '';
      });
      return;
    }
    if (chapterId.isEmpty) return;
    setState(() {
      _selectedChapterId = chapterId;
      _form.chapterId = chapterId;
    });
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

              _buildGradeDropdown(),

              _buildBookDropdown(),

              _buildChapterDropdown(),

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

              _buildTypeDropdown(),

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

  Widget _buildGradeDropdown() {
    if (_gradesLoading) {
      return _buildLoadingField('پایه (grade_id)');
    }
    if (_gradeOptions.isEmpty) {
      return _buildDisabledField(
        'پایه (grade_id)',
        'اطلاعات پایه‌ها در دسترس نیست',
      );
    }
    final currentValue = _gradeOptions.any((opt) => opt.value == _selectedGradeId)
        ? _selectedGradeId
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<int>(
        value: currentValue,
        decoration: _dropdownDecoration('پایه (grade_id)'),
        isExpanded: true,
        items: _gradeOptions
            .map(
              (option) => DropdownMenuItem<int>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            _handleGradeChange(value);
          }
        },
      ),
    );
  }

  Widget _buildBookDropdown() {
    if (_selectedGradeId == null) {
      return _buildDisabledField(
        'درس (book_id)',
        'ابتدا پایه را انتخاب کنید',
      );
    }
    if (_booksLoading) {
      return _buildLoadingField('درس (book_id)');
    }
    if (_bookOptions.isEmpty) {
      return _buildDisabledField(
        'درس (book_id)',
        'هیچ درسی برای این پایه یافت نشد',
      );
    }
    final currentValue = _bookOptions.any((opt) => opt.value == _selectedBookId)
        ? _selectedBookId
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: _dropdownDecoration('درس (book_id)'),
        isExpanded: true,
        items: _bookOptions
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            _handleBookChange(value);
          }
        },
      ),
    );
  }

  Widget _buildChapterDropdown() {
    if (_selectedBookId == null || _selectedBookId!.isEmpty) {
      return _buildDisabledField(
        'شناسه فصل (chapter_id)',
        'ابتدا درس را انتخاب کنید',
      );
    }
    if (_chaptersLoading) {
      return _buildLoadingField('شناسه فصل (chapter_id)');
    }
    if (_chapterOptions.isEmpty) {
      return _buildDisabledField(
        'شناسه فصل (chapter_id)',
        'فصلی برای این درس ثبت نشده است',
      );
    }
    final currentValue =
        _chapterOptions.any((opt) => opt.value == _selectedChapterId)
            ? _selectedChapterId
            : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: _dropdownDecoration('شناسه فصل (chapter_id)'),
        isExpanded: true,
        items: _chapterOptions
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            _handleChapterChange(value);
          }
        },
      ),
    );
  }

  Widget _buildTypeDropdown() {
    final currentValue = _contentTypeOptions
            .any((option) => option.value == _selectedType)
        ? _selectedType
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: _dropdownDecoration('نوع محتوا (type)'),
        isExpanded: true,
        items: _contentTypeOptions
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedType = value;
              _form.type = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildLoadingField(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InputDecorator(
        decoration: _dropdownDecoration(label),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('در حال بارگذاری...'),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledField(String label, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InputDecorator(
        decoration: _dropdownDecoration(label),
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'IRANSansXFaNum',
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'IRANSansXFaNum'),
      border: const OutlineInputBorder(),
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

      final trimmedEmbedUrl = _form.embedUrl?.trim() ?? '';
      if (trimmedEmbedUrl.isNotEmpty) {
        updates['embed_url'] = trimmedEmbedUrl;
      }

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

class _GradeConfig {
  final String title;
  final String path;

  const _GradeConfig({required this.title, required this.path});
}

class _DropdownOption<T> {
  final T value;
  final String label;

  const _DropdownOption({required this.value, required this.label});
}

class _BookLoadResult {
  final List<_DropdownOption<String>> options;
  final Map<String, Map<String, String>> chaptersByBookId;

  const _BookLoadResult({
    required this.options,
    required this.chaptersByBookId,
  });
}
