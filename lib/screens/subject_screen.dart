import 'package:flutter/material.dart';
import 'package:nardeboun/models/content/subject.dart';
import 'package:nardeboun/services/content/cached_content_service.dart';
import 'package:nardeboun/services/content/book_cover_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nardeboun/models/content/chapter.dart';
import '../widgets/bubble_nav_bar.dart';
import '../../utils/grade_utils.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/subject/cached_book_cover.dart';
import '../../utils/logger.dart';

class SubjectScreen extends StatefulWidget {
  final Subject? subject;
  final int gradeId;
  final int? trackId;
  const SubjectScreen({
    super.key,
    this.subject,
    required this.gradeId,
    this.trackId,
  });

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  late final BookCoverService _bookCoverService;
  List<Chapter>? _chapters; // ← null = هنوز لود نشده
  bool _loading = false; // ← شروع با false (بدون Loader)
  String _bookCoverPath = '';
  String? _trackName;
  final Map<int, List<String>> _chapterTeachers = {}; // فصل ID -> لیست نام اساتید

  @override
  void initState() {
    super.initState();
    _bookCoverService = BookCoverService.instance;
    _bookCoverService.init(); // Initialize Hive
    // مسیر کاور را اگر در خود subject موجود است، بلافاصله ست کن تا هیچ فریم آیکون نمایش داده نشود
    _bookCoverPath = widget.subject?.bookCoverPath ?? '';
    _load();
  }

  Future<void> _load() async {
    if (widget.subject == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    // اگر قبلاً لود شده، دوباره لود نکن
    if (_chapters != null && _chapters!.isNotEmpty) {
      Logger.info('🚀 [SUBJECT] Chapters already loaded, skipping...');
      return;
    }

    if (widget.trackId != null) {
      try {
        final trackResult = await Supabase.instance.client
            .from('tracks')
            .select('name')
            .eq('id', widget.trackId!)
            .single();
        _trackName = trackResult['name'] as String?;
      } catch (e) {
        Logger.error('Error getting track name', e);
        _trackName = null;
      }
    }

    try {
      Logger.debug('🎯 SubjectScreen Debug:');
      Logger.debug('   - Subject name: "${widget.subject?.name ?? 'NULL'}"');
      Logger.debug('   - Subject slug: "${widget.subject?.slug ?? 'NULL'}"');
      Logger.debug('   - Grade ID: ${widget.gradeId}');
      Logger.debug('   - Track name: "$_trackName"');

      // دریافت track name اگر موجود است
      if (widget.trackId != null) {
        try {
          final trackResult = await Supabase.instance.client
              .from('tracks')
              .select('name')
              .eq('id', widget.trackId!)
              .single();
          _trackName = trackResult['name'] as String?;
          Logger.debug('🔍 [SUBJECT] Track name: $_trackName');
        } catch (e) {
          Logger.error('❌ [SUBJECT] Error getting track name', e);
          _trackName = null;
        }
      } else {
        // برای پایه‌های 1-9، track name همیشه null است
        _trackName = null;
        Logger.debug('🔍 [SUBJECT] No track ID, setting track name to null');
      }

      // اگر در خود subject نبود، از سرویس بگیر
      if (_bookCoverPath.isEmpty) {
        final coverPath = await _bookCoverService.getBookCoverPath(
          subjectName: widget.subject!.name,
          grade: widget.gradeId,
          trackName: _trackName,
        );

        if (coverPath != null && coverPath.isNotEmpty) {
          _bookCoverPath = coverPath;
          Logger.info('✅ [SUBJECT] Book cover (via service): $_bookCoverPath');
        } else {
          Logger.info('⚠️ [SUBJECT] No book cover found');
          _bookCoverPath = '';
        }
      }

      Logger.debug('📖 Final book cover path: "$_bookCoverPath"');
    } catch (e) {
      Logger.error('❌ Error getting book cover path', e);
      _bookCoverPath = '';
    }

    // 🚀 استفاده از subjectOfferId ذخیره شده (بدون request!)
    int? offerId = widget.subject!.subjectOfferId;

    // اگر null بود (کد قدیمی)، از سرور بگیر
    if (offerId == null) {
      Logger.info('⚠️ subjectOfferId is null, fetching from server...');
      offerId = await CachedContentService.getSubjectOfferId(
        subjectId: widget.subject!.id,
        gradeId: widget.gradeId,
        trackId: widget.trackId,
      );
    } else {
      Logger.info('✅ Using cached subjectOfferId: $offerId');
    }

    if (offerId != null) {
      // ابتدا از کش بخوان
      try {
        final cachedChapters = await CachedContentService.getChapters(
          offerId,
          gradeId: widget.gradeId,
          trackId: widget.trackId,
        );

        if (cachedChapters.isNotEmpty) {
          // لود کردن ویدیوهای هر فصل برای گرفتن نام واقعی اساتید
          await _loadChapterTeachers(cachedChapters);

          if (!mounted) return;
          setState(() {
            _chapters = cachedChapters;
            _loading = false;
          });
          Logger.info('🚀 [SUBJECT] Chapters loaded from cache');
          return;
        }
      } catch (e) {
        Logger.info('⚠️ [SUBJECT] Chapter cache miss, falling back to server: $e');
      }

      // اگر کش خالی بود، از سرور بگیر
      final chapters = await CachedContentService.getChapters(
        offerId,
        gradeId: widget.gradeId,
        trackId: widget.trackId,
      );

      // لود کردن ویدیوهای هر فصل برای گرفتن نام واقعی اساتید
      await _loadChapterTeachers(chapters);

      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _chapters = const [];
        _loading = false;
      });
    }
  }

  // لود کردن ویدیوهای هر فصل برای گرفتن نام واقعی اساتید
  Future<void> _loadChapterTeachers(List<Chapter> chapters) async {
    _chapterTeachers.clear();

    for (final chapter in chapters) {
      try {
        // لود کردن درس‌های این فصل
        final lessons = await CachedContentService.getLessons(
          chapter.id,
          gradeId: widget.gradeId,
          trackId: widget.trackId,
        );

        // استخراج نام‌های منحصر به فرد اساتید
        final Set<String> teacherNames = {};

        for (final lesson in lessons) {
          // لود کردن ویدیوهای این درس
          final videos = await CachedContentService.getLessonVideos(
            lesson.id,
            gradeId: widget.gradeId,
            trackId: widget.trackId,
          );

          for (final video in videos) {
            // استفاده از teacherId برای گرفتن نام استاد
            final teacherName = _getTeacherNameById(video.teacherId);
            if (teacherName.isNotEmpty) {
              teacherNames.add(teacherName);
            }
          }
        }

        _chapterTeachers[chapter.id] = teacherNames.toList();
      } catch (e) {
        Logger.error('❌ Error loading teachers for chapter ${chapter.id}', e);
        _chapterTeachers[chapter.id] = [];
      }
    }
  }

  // تبدیل teacherId به نام استاد
  String _getTeacherNameById(int teacherId) {
    // فعلاً از نام‌های ثابت استفاده می‌کنیم
    // در آینده می‌توان از دیتابیس واقعی استفاده کرد
    final teacherNames = {
      1: 'بابایی',
      2: 'فخری',
      3: 'احمدی',
      4: 'رضایی',
      5: 'کریمی',
    };
    return teacherNames[teacherId] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkBlue = const Color(0xFF3629B7); // از کانفیگ مرکزی

    if (widget.subject == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: darkBlue,
          appBar: AppBar(
            backgroundColor: darkBlue,
            elevation: 0,
            title: const Text(
              'خطا',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'IRANSansXFaNum',
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
            automaticallyImplyLeading: false,
          ),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'خطا 404',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'چنین صفحه‌ای وجود ندارد',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'لطفاً ابتدا وارد شوید',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                      : _chapters == null
                      ? const SizedBox.shrink() // ← هنوز لود نشده، چیزی نشون نده
                      : _chapters!.isEmpty
                      ? SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: EmptyStateWidgets.noChapterContent(
                                context,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: _chapters!.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final ch = _chapters![i];
                            return _ChapterTile(
                              chapter: ch,
                              subject: widget.subject!,
                              gradeId: widget.gradeId,
                              trackId: widget.trackId,
                              teacherNames: _getRealTeacherNames(ch.id),
                            );
                          },
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
      height: 228,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(color: darkBlue),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.subject?.name ?? 'در حال بارگذاری...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'پایه ${mapGradeIntToString(widget.gradeId) ?? widget.gradeId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IRANSansXFaNum',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _bookCoverPath.isNotEmpty
              ? SizedBox(
                  width: 120,
                  height: 200, // کاهش ارتفاع از 180 به 160
                  child: CachedBookCover(
                    imageUrl: _bookCoverPath,
                    placeholder: Container(
                      width: 120,
                      height: 200, // هماهنگ با ارتفاع اصلی
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: darkBlue,
                      ),
                    ),
                  ),
                )
              : Container(
                  width: 120,
                  height: 200, // هماهنگ با ارتفاع اصلی
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // در صورت نداشتن مسیر کاور، ابتدا خالی نشان بده (بدون آیکون)
                ),
        ],
      ),
    );
  }

  String _getRealTeacherNames(int chapterId) {
    // گرفتن نام‌های واقعی اساتید از دیتا
    final teachers = _chapterTeachers[chapterId] ?? [];

    if (teachers.isEmpty) {
      return 'استاد نامشخص';
    } else if (teachers.length == 1) {
      return 'استاد ${teachers.first}';
    } else {
      // اگر چند استاد داره، همه رو نمایش بده
      return 'اساتید ${teachers.join(' و ')}';
    }
  }
}

class _ChapterTile extends StatelessWidget {
  final Chapter chapter;
  final Subject subject;
  final int gradeId;
  final int? trackId;
  final String teacherNames; // نام‌های واقعی اساتید

  const _ChapterTile({
    required this.chapter,
    required this.subject,
    required this.gradeId,
    this.trackId,
    required this.teacherNames,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/chapter',
            arguments: {
              'chapter': chapter,
              'subject': subject,
              'gradeId': gradeId,
              'trackId': trackId,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // محتوای اصلی کارت
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // برچسب سبز سمت چپ (مربعی)
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(12), // فاصله از لبه‌ها
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _convertNumbersToPersian('فصل ${chapter.chapterOrder}'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'IRANSansXFaNum',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // محتوای اصلی
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // عنوان اصلی
                        Text(
                          chapter.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'IRANSansXFaNum',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}
