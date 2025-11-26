import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nardeboun/models/content/chapter.dart';
import 'package:nardeboun/models/content/lesson_video.dart';
import 'package:nardeboun/models/content/subject.dart';
import 'package:nardeboun/services/content/content_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/common/smooth_scroll_physics.dart';
import '../widgets/bubble_nav_bar.dart';
import '../widgets/common/empty_state_widget.dart';
import '../../utils/logger.dart';
import 'video_edit/video_edit_screen.dart';
import '../../services/video_delete/video_delete_service.dart';

class ChapterScreen extends StatefulWidget {
  final Chapter chapter;
  final Subject subject;
  final int gradeId;
  final int? trackId;

  const ChapterScreen({
    super.key,
    required this.chapter,
    required this.subject,
    required this.gradeId,
    this.trackId,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  bool _loading = false;
  List<LessonVideo> _allVideos = [];  // ← تغییر از _lessons و _videosByLesson
  String _selectedStyle = 'جزوه';
  // ✅ حذف شد: دیگر نیازی به جدول teachers نیست چون نام استاد مستقیماً در LessonVideo.teacher ذخیره می‌شود

  // کمک‌متد برای نمایش کلید/مقدار
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
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'IRANSansXFaNum',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'IRANSansXFaNum',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // ✅ _load() را به didChangeDependencies منتقل کردیم چون از context استفاده می‌کند
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ حالا که context آماده است، می‌توانیم _load() را صدا بزنیم
    if (_allVideos.isEmpty && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    try {
      final contentService = ContentService(Supabase.instance.client);
      
      // ✅ استراتژی جدید: استفاده از bookId و chapterId از arguments یا از JSON
      final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final String? bookId = arguments?['bookId'] as String?;
      final String? chapterId = arguments?['chapterId'] as String?;
      
      List<LessonVideo> videos;
      
      if (bookId != null && chapterId != null) {
        // استفاده از bookId و chapterId از arguments
        Logger.info('📹 [CHAPTER] Loading videos with bookId=$bookId, chapterId=$chapterId, gradeId=${widget.gradeId}');
        videos = await contentService.getLessonVideosByChapter(
          gradeId: widget.gradeId,
          bookId: bookId,
          chapterId: chapterId,
        );
        Logger.info('✅ [CHAPTER] Loaded ${videos.length} videos');
      } else {
        // Fallback: استفاده از chapter.id (برای سازگاری)
        Logger.info('⚠️ [CHAPTER] bookId/chapterId not found in arguments, using chapter.id=${widget.chapter.id} as fallback');
        Logger.debug('📋 [CHAPTER] Arguments: $arguments');
        videos = await contentService.getLessonVideosByChapterId(widget.chapter.id.toString());
        Logger.info('✅ [CHAPTER] Loaded ${videos.length} videos (fallback)');
      }

      if (!mounted) return;
      
      // لاگ برای دیباگ
      Logger.info('📊 [CHAPTER] Total videos loaded: ${videos.length}');
      for (final video in videos) {
        Logger.debug('  - Video ID: ${video.videoId}, type: ${video.type}, stepNumber: ${video.stepNumber}, title: ${video.title}');
      }
      
      setState(() {
        _allVideos = videos;
        _loading = false;
      });
    } catch (e) {
      Logger.error('Error loading videos', e);
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkBlue = const Color(0xFF3629B7); // آبی بنفش یکسان با نویگیشن

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: darkBlue,
          elevation: 0,
          title: const Text(''),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            _buildHeader(theme, darkBlue),
            Expanded(
              child: Container(
                color: darkBlue,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            // تب‌های سبک تدریس
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Text(
                                      'تدریس از:',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                        fontFamily: 'IRANSansXFaNum',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStyleTab('جزوه', theme),
                                    const SizedBox(width: 6),
                                    _buildStyleTab('کتاب درسی', theme),
                                    const SizedBox(width: 6),
                                    _buildStyleTab('نمونه سوال', theme),
                                  ],
                                ),
                              ),
                            ),
                            // لیست ویدیوها
                            Expanded(
                              child: RefreshIndicator(
                                      onRefresh: () async {
                                    // ✅ تغییر: فقط reload از Supabase (بدون cache)
                                    await _load();
                                      },
                                  child: _allVideos.isEmpty
                                          ? SingleChildScrollView(
                                              physics: AppScrollPhysics.smooth,
                                              child: Center(
                                                child: Padding(
                                              padding: const EdgeInsets.all(32.0),
                                              child: EmptyStateWidgets.noLessonContent(context),
                                                ),
                                              ),
                                            )
                                      : _buildVideosList(context, theme, darkBlue),
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BubbleNavBar(
          currentIndex: -1,
          onTap: (i) {
            if (i == 0) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            } else if (i == 1) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/provincial-sample');
            } else if (i == 2) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/step-by-step');
            } else if (i == 3) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/edit-profile');
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color darkBlue) {
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(color: darkBlue),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.chapter.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleTab(String title, ThemeData theme) {
    final isSelected = _selectedStyle == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3629B7) : Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'IRANSansXFaNum',
          ),
        ),
      ),
    );
  }

  // متد برای ساخت لیست ویدیوها با گروه‌بندی پله‌ها (با gap filling)
  Widget _buildVideosList(BuildContext context, ThemeData theme, Color darkBlue) {
    // 1) یافتن بالاترین lesson_order که ویدیو برای style انتخابی دارد
    int maxLessonOrderWithVideo = 0;
    final Map<int, List<LessonVideo>> videosByLessonOrder = {};
    
    Logger.info('🎨 [CHAPTER] Filtering videos for style: $_selectedStyle');
    Logger.info('📹 [CHAPTER] Total videos in _allVideos: ${_allVideos.length}');
    
    for (final video in _allVideos) {
      final styleName = _getStyleName(video.style);
      Logger.debug('  - Video ID: ${video.videoId}, type: ${video.type}, styleName: $styleName, selectedStyle: $_selectedStyle');
      
      if (styleName == _selectedStyle) {
        final order = video.lessonOrder;
        videosByLessonOrder.putIfAbsent(order, () => []).add(video);
        if (order > maxLessonOrderWithVideo) {
          maxLessonOrderWithVideo = order;
        }
      }
    }
    
    Logger.info('✅ [CHAPTER] Videos for style "$_selectedStyle": ${videosByLessonOrder.values.fold(0, (sum, list) => sum + list.length)}');
    Logger.info('📊 [CHAPTER] Max lesson order: $maxLessonOrderWithVideo');

    // 2) اگر هیچ ویدیویی برای این سبک نیست: فقط یک EmptyState
    if (maxLessonOrderWithVideo == 0) {
      return SingleChildScrollView(
        physics: AppScrollPhysics.smooth,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: EmptyStateWidgets.noEducationContent(context),
          ),
        ),
      );
    }

    // 3) ساخت لیست lesson_order ها از 1 تا max (پر کردن gap ها)
    final lessonOrdersToShow = List.generate(
      maxLessonOrderWithVideo,
      (i) => i + 1,
    );

    // 4) رندر لیست با gap filling
    return ListView.builder(
      physics: AppScrollPhysics.gentle,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: lessonOrdersToShow.length,
      itemBuilder: (ctx, i) {
        final lessonOrder = lessonOrdersToShow[i];
        final videos = videosByLessonOrder[lessonOrder] ?? [];
        final filteredVideos = videos
            .where((v) => _getStyleName(v.style) == _selectedStyle)
            .toList();

        // اگر ویدیو نداره: کارت خالی
        if (filteredVideos.isEmpty) {
          return _buildEmptyLessonCard(lessonOrder, theme, darkBlue);
        }

        // اگر ویدیو داره: کارت معمولی با برچسب پله
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.green.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    ...List.generate(
                      filteredVideos.length,
                      (videoIndex) => _buildVideoCard(
                        video: filteredVideos[videoIndex],
                        theme: theme,
                        darkBlue: darkBlue,
                        rowNumber: videoIndex + 1,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                top: -20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'پله ${_convertToPersian(lessonOrder)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: darkBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: ((theme.textTheme.bodySmall?.fontSize ?? 12) * 2.2)
                          .clamp(18, 28),
                      fontFamily: 'IRANSansXFaNum',
                    ),
                    textAlign: TextAlign.left,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoCard({
    required LessonVideo video,
    required ThemeData theme,
    required Color darkBlue,
    required int rowNumber,
  }) {
    return GestureDetector(
      onTap: () {
        if (video.embedHtml != null && video.embedHtml!.isNotEmpty) {
          _openVideoPopup(video);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ویدیو در دسترس نیست',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(60), // نیم‌دایره واقعی
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // شماره ردیف - سمت راست
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ), // کاهش پدینگ
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6), // کاهش border radius
                ),
                child: Text(
                  _convertToPersian(rowNumber).padLeft(2, '۰'),
                  style: const TextStyle(
                    fontSize: 16, // کاهش اندازه فونت از 18 به 14
                    color: Color(0xFF3629B7),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                ),
              ),
              const SizedBox(width: 4), // کاهش فاصله از 8 به 4
              // عنوان درس و استاد - وسط
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // عنوان درس - وسط بالا
                    Flexible(
                      child: Text(
                        _convertNumbersToPersian(video.lessonTitle),  // ← استفاده مستقیم از video.lessonTitle
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'IRANSansXFaNum',
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 2), // کاهش فاصله از 4 به 2
                    // نام استاد - وسط پایین
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                'استاد ${video.teacher.isNotEmpty ? video.teacher : 'نامشخص'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[600],
                                  fontSize: 11,
                                  fontFamily: 'IRANSansXFaNum',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ستون آیکون PDF و زمان ویدیو
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // آیکن PDF در صورت وجود (بالا)
                  if ((video.notePdfUrl != null &&
                          video.notePdfUrl!.isNotEmpty) ||
                      (video.exercisePdfUrl != null &&
                          video.exercisePdfUrl!.isNotEmpty))
                    Icon(Icons.picture_as_pdf, color: Colors.red[600], size: 20)
                  else
                    const SizedBox(height: 20), // فاصله برای هماهنگی
                  const SizedBox(height: 2), // کاهش فاصله از 4 به 2
                  // زمان ویدیو (پایین)
                  Text(
                    _formatDuration(video.durationSec),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.normal, // تغییر از bold به normal
                      fontFamily: 'IRANSansXFaNum',
                      fontSize: 10, // کاهش اندازه فونت از 12 به 10
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // دکمه پلی - سمت چپ
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3629B7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // کارت خالی برای پله‌های بدون ویدیو
  Widget _buildEmptyLessonCard(int lessonOrder, ThemeData theme, Color darkBlue) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // کادر خاکستری با رنگ آبی کم‌رنگ
          Container(
            decoration: BoxDecoration(
              color: darkBlue.withValues(alpha: 0.05),
              border: Border.all(color: Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'در دست انتشار...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontFamily: 'IRANSansXFaNum',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // برچسب پله
          Positioned(
            right: 20,
            top: -20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'پله ${_convertToPersian(lessonOrder)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: ((theme.textTheme.bodySmall?.fontSize ?? 12) * 2.2)
                      .clamp(18, 28),
                  fontFamily: 'IRANSansXFaNum',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _convertToPersian(int number) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return number.toString().split('').map((digit) {
      return persianDigits[int.parse(digit)];
    }).join();
  }

  /// تبدیل ثانیه به فرمت زمان مناسب (H:MM:SS یا M:SS)
  String _formatDuration(int? durationSec) {
    if (durationSec == null || durationSec <= 0) return '۰:۰۰';

    final hours = durationSec ~/ 3600;
    final minutes = (durationSec % 3600) ~/ 60;
    final seconds = durationSec % 60;

    String two(int n) => n.toString().padLeft(2, '0');

    // مثل پنل ادمین: 4800 => 1:20:00 ، 1225 => 20:25
    final en = hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '$minutes:${two(seconds)}';

    return _convertNumbersToPersian(en);
  }

  String _convertNumbersToPersian(String text) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const latinDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String result = text;
    for (int i = 0; i < latinDigits.length; i++) {
      result = result.replaceAll(latinDigits[i], persianDigits[i]);
    }
    return result;
  }

  String _getStyleName(String style) {
    switch (style.toLowerCase()) {
      case 'جزوه':
      case 'note':
        return 'جزوه';
      case 'کتاب درسی':
      case 'book':
        return 'کتاب درسی';
      case 'نمونه سوال':
      case 'sample':
      case 'exam': // ✅ اضافه شد: نوع exam در دیتابیس
        return 'نمونه سوال';
      default:
        Logger.info('⚠️ [CHAPTER] Unknown style: $style, defaulting to "جزوه"');
        return 'جزوه';
    }
  }

  String _translateLessonVideoField(String key) {
    const labels = {
      'video_id': 'شناسه ویدیو',
      'grade_id': 'شناسه پایه',
      'book_id': 'شناسه کتاب',
      'chapter_id': 'شناسه فصل',
      'step_number': 'شماره پله',
      'title': 'عنوان',
      'type': 'نوع محتوا',
      'teacher': 'استاد',
      'embed_url': 'لینک Embed',
      'direct_url': 'لینک مستقیم',
      'pdf_url': 'لینک PDF',
      'thumbnail_url': 'لینک تصویر',
      'duration': 'مدت زمان (ثانیه)',
      'likes_count': 'تعداد لایک',
      'views_count': 'تعداد بازدید',
      'active': 'وضعیت فعال',
      'created_at': 'تاریخ ایجاد',
      'updated_at': 'تاریخ بروزرسانی',
    };
    return labels[key] ?? key;
  }

  String _formatDynamicValue(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'true' : 'false';
    if (value is DateTime) return value.toIso8601String();
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }

  /// نمایش پاپ‌آپ جزئیات ویدیو با تمام فیلدها
  Future<void> _openVideoPopup(LessonVideo video) async {
    Map<String, dynamic> rawData = video.toJson();

    try {
      Logger.info('📡 [VIDEO-DETAIL] Fetching latest row for video_id=${video.videoId}');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('lesson_videos')
          .select('*')
          .eq('video_id', video.videoId)
          .single();

      rawData = Map<String, dynamic>.from(response as Map);
      Logger.info('✅ [VIDEO-DETAIL] Loaded raw row with ${rawData.length} columns');
    } catch (e, stack) {
      Logger.error('❌ [VIDEO-DETAIL] Failed to load raw row from lesson_videos', e);
      Logger.debug(stack.toString());
      // از داده‌های مدل به عنوان fallback استفاده می‌کنیم
    }
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
                  const Text(
                    'داده‌های خام جدول lesson_videos',
                    style: TextStyle(
                      fontFamily: 'IRANSansXFaNum',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...rawData.entries.map(
                    (entry) => _kv(
                      '${_translateLessonVideoField(entry.key)} (${entry.key})',
                      _formatDynamicValue(entry.value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Logger.info('✏️ [VIDEO-DETAIL] باز کردن صفحه ویرایش برای ویدیو ID: ${video.id}');
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VideoEditScreen(video: video),
                  ),
                ).then((result) {
                  if (result == true) {
                    Logger.info('🔄 [VIDEO-DETAIL] رفرش لیست ویدیوها بعد از ویرایش');
                    _load();
                  }
                });
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
            ElevatedButton(
              onPressed: () {
                Logger.info('🗑️ [VIDEO-DETAIL] باز کردن تایید حذف برای ویدیو ID: ${video.id}');
                Navigator.of(context).pop();
                _showDeleteConfirmation(video);
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

  /// نمایش dialog تایید حذف ویدیو
  void _showDeleteConfirmation(LessonVideo video) {
    final teacherName = video.teacher.isNotEmpty ? video.teacher : 'نامشخص';
    
    Logger.info('🗑️ [VIDEO-DELETE] نمایش dialog تایید حذف برای ویدیو ID: ${video.id}');

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'تایید حذف',
            style: TextStyle(fontFamily: 'IRANSansXFaNum', color: Colors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'آیا از حذف این ویدیو مطمئن هستید؟',
                style: TextStyle(fontFamily: 'IRANSansXFaNum', fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _kv('عنوان درس', video.lessonTitle),
              _kv('استاد', teacherName),
              _kv('نوع', _getStyleName(video.style)),
              const SizedBox(height: 8),
              const Text(
                '⚠️ این عمل غیرقابل بازگشت است!',
                style: TextStyle(
                  fontFamily: 'IRANSansXFaNum',
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Logger.info('❌ [VIDEO-DELETE] حذف لغو شد');
              },
              child: const Text(
                'لغو',
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteVideo(video);
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

  /// حذف ویدیو
  Future<void> _deleteVideo(LessonVideo video) async {
    try {
      Logger.info('🗑️ [VIDEO-DELETE] شروع حذف ویدیو ID: ${video.id}');

      final service = VideoDeleteService();
      await service.deleteVideo(lessonVideoId: video.id);

      if (!mounted) return;

      Logger.info('✅ [VIDEO-DELETE] ویدیو با موفقیت حذف شد');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ویدیو با موفقیت حذف شد', textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
        ),
      );

      // رفرش لیست ویدیوها
      _load();
    } catch (e) {
      Logger.error('❌ [VIDEO-DELETE] خطا در حذف ویدیو', e);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطا در حذف ویدیو: ${e.toString()}', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
