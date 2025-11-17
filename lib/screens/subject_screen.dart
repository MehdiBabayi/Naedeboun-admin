import 'package:flutter/material.dart';
import 'package:nardeboun/models/content/subject.dart';
import 'package:nardeboun/services/content/content_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nardeboun/services/content/book_cover_service.dart';
import 'package:nardeboun/models/content/json_chapter.dart';
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
  List<JsonChapter>? _jsonChapters; // ← فصل‌ها از JSON + lesson_videos
  bool _loading = false; // ← شروع با false (بدون Loader)
  String _bookCoverPath = '';
  String? _trackName;
  String? _bookId; // شناسه کتاب از JSON (مثل "riazi", "olom")
  final Map<String, List<String>> _chapterTeachers = {}; // chapterId -> اساتید ویدیوها
  final Map<String, bool> _chapterHasVideos = {}; // chapterId -> آیا ویدیو دارد؟
  String _chapterTypeLabel = 'فصل';

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
    if (_jsonChapters != null && _jsonChapters!.isNotEmpty) {
      Logger.info('🚀 [SUBJECT] Chapters already loaded, skipping...');
      return;
    }

    setState(() => _loading = true);

    try {
      Logger.debug('🎯 SubjectScreen Debug:');
      Logger.debug('   - Subject name: "${widget.subject?.name ?? 'NULL'}"');
      Logger.debug('   - Grade ID: ${widget.gradeId}');

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
        _trackName = null;
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
        }
      }

      // ✅ استراتژی جدید: ترکیب JSON و lesson_videos
      final contentService = ContentService(Supabase.instance.client);

      // 1. bookId را از خود subject (slug) بگیر؛ اگر نبود، از JSON map پیدا کن
      _bookId = widget.subject?.slug;
      if (_bookId == null || _bookId!.isEmpty) {
        final bookIdMap = await contentService.getBookIdMapForGrade(widget.gradeId);
        final subjectName = widget.subject?.name.trim();
        if (subjectName != null && subjectName.isNotEmpty) {
          _bookId = bookIdMap[subjectName];
        }
      }

      if (_bookId == null || _bookId!.isEmpty) {
        Logger.info('⚠️ [SUBJECT] No bookId found for subject: ${widget.subject!.name}');
        if (!mounted) return;
        setState(() {
          _jsonChapters = [];
          _loading = false;
        });
        return;
      }

      Logger.info('✅ [SUBJECT] Found bookId: $_bookId for subject: ${widget.subject!.name}');

      // 2. خواندن ساختار فصل‌ها و chapter_type از JSON
      final bookData = await contentService.getBookDataFromJson(
        gradeId: widget.gradeId,
        bookId: _bookId!,
      );
      final jsonChaptersMap = bookData?.chapters ?? {};
      _chapterTypeLabel = bookData?.chapterType ?? 'فصل';

      // 3. خواندن ویدیوها از lesson_videos برای این bookId
      final videos = await contentService.getLessonVideosByBook(
        gradeId: widget.gradeId,
        bookId: _bookId!,
      );

      Logger.info('📹 [SUBJECT] Found ${videos.length} videos for bookId=$_bookId');

      // 4. استخراج اطلاعات ویدیوها برای هر فصل
      _chapterTeachers.clear();
      _chapterHasVideos.clear();
      for (final video in videos) {
        _chapterHasVideos[video.chapterId] = true;
        final teacherSet = _chapterTeachers.putIfAbsent(video.chapterId, () => []);
        if (!teacherSet.contains(video.teacher)) {
          teacherSet.add(video.teacher);
        }
      }

      // 5. ساخت لیست JsonChapter فقط برای فصل‌هایی که ویدیو دارند
      final List<JsonChapter> chaptersForDisplay = [];
      for (final entry in jsonChaptersMap.entries) {
        final chapterId = entry.key;
        final chapterTitle = entry.value;

        final hasVideos = _chapterHasVideos[chapterId] ?? false;
        
        // فقط فصل‌هایی که ویدیو دارند را اضافه کن
        if (hasVideos) {
          chaptersForDisplay.add(
            JsonChapter(
              chapterId: chapterId,
              title: chapterTitle,
              bookId: _bookId!,
              gradeId: widget.gradeId,
            ),
          );
        }

        // اگر برای این فصل استادی ثبت نشده بود، مقدار پیش‌فرض بگذاریم
        _chapterTeachers.putIfAbsent(chapterId, () => []);
        _chapterHasVideos.putIfAbsent(chapterId, () => false);
      }
      
      // لاگ برای دیباگ
      Logger.info('📊 [SUBJECT] Chapters with videos: ${chaptersForDisplay.length} out of ${jsonChaptersMap.length} total chapters');
      for (final entry in jsonChaptersMap.entries) {
        final chapterId = entry.key;
        final hasVideos = _chapterHasVideos[chapterId] ?? false;
        Logger.debug('  - Chapter $chapterId: ${hasVideos ? "✅ has videos" : "❌ no videos"}');
      }

      // مرتب‌سازی بر اساس chapterId (عدد)
      chaptersForDisplay.sort((a, b) {
        final aNum = int.tryParse(a.chapterId) ?? 0;
        final bNum = int.tryParse(b.chapterId) ?? 0;
        return aNum.compareTo(bNum);
      });

      Logger.info('✅ [SUBJECT] Prepared ${chaptersForDisplay.length} chapters for display');

      if (!mounted) return;
      setState(() {
        _jsonChapters = chaptersForDisplay;
        _loading = false;
      });
    } catch (e) {
      Logger.error('❌ [SUBJECT] Error loading chapters', e);
      if (!mounted) return;
      setState(() {
        _jsonChapters = [];
        _loading = false;
      });
    }
  }

  String _getRealTeacherNames(String chapterId) {
    final teachers = _chapterTeachers[chapterId] ?? [];
    final hasVideos = _chapterHasVideos[chapterId] ?? false;

    if (!hasVideos) {
      return 'بدون محتوا';
    }

    if (teachers.isEmpty) {
      return 'استاد نامشخص';
    } else if (teachers.length == 1) {
      return 'استاد ${teachers.first}';
    } else {
      return 'اساتید ${teachers.join(' و ')}';
    }
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
                      : _jsonChapters == null
                      ? const SizedBox.shrink() // ← هنوز لود نشده، چیزی نشون نده
                      : _jsonChapters!.isEmpty
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
                          itemCount: _jsonChapters!.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final jsonChapter = _jsonChapters![i];
                            return _ChapterTile(
                              jsonChapter: jsonChapter,
                              subject: widget.subject!,
                              gradeId: widget.gradeId,
                              trackId: widget.trackId,
                              teacherNames: _getRealTeacherNames(jsonChapter.chapterId),
                              hasVideos: _chapterHasVideos[jsonChapter.chapterId] ?? false,
                              chapterTypeLabel: _chapterTypeLabel,
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

}

class _ChapterTile extends StatelessWidget {
  final JsonChapter jsonChapter;
  final Subject subject;
  final int gradeId;
  final int? trackId;
  final String teacherNames; // نام‌های واقعی اساتید
  final bool hasVideos;
  final String chapterTypeLabel;

  const _ChapterTile({
    required this.jsonChapter,
    required this.subject,
    required this.gradeId,
    this.trackId,
    required this.teacherNames,
    required this.hasVideos,
    required this.chapterTypeLabel,
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
          // ساخت Chapter قدیمی برای سازگاری با ChapterScreen
          final legacyChapter = jsonChapter.toLegacyChapter();
          Navigator.of(context).pushNamed(
            '/chapter',
            arguments: {
              'chapter': legacyChapter,
              'subject': subject,
              'gradeId': gradeId,
              'trackId': trackId,
              'bookId': jsonChapter.bookId,
              'chapterId': jsonChapter.chapterId,
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
                        _convertNumbersToPersian('$chapterTypeLabel ${jsonChapter.chapterId}'),
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
                          jsonChapter.title,
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
