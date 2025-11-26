import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content/step_by_step_pdf.dart';
import '../models/content/subject.dart';
import '../services/content/content_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/pdf/pdf_service.dart';
import '../providers/core/app_state_manager.dart';
import 'pdf_reader_screen_pdfx.dart';
import '../widgets/bubble_nav_bar.dart';
import '../widgets/common/smooth_scroll_physics.dart';
import '../../utils/grade_utils.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/network/network_wrapper.dart';
import '../../utils/logger.dart';
import '../../services/pdf_edit/pdf_edit_service.dart';
import '../../services/pdf_delete/pdf_delete_service.dart';

class StepByStepScreen extends StatefulWidget {
  const StepByStepScreen({super.key});

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  List<Subject> _subjects = [];
  Map<String, List<StepByStepPdf>> _pdfsBySubject = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _showEditStepByStep(StepByStepPdf pdf) async {
    final titleCtrl = TextEditingController(text: pdf.title);
    final urlCtrl = TextEditingController(text: pdf.pdfUrl);
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ویرایش گام‌به‌گام', style: TextStyle(fontFamily: 'IRANSansXFaNum')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'عنوان'),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'لینک PDF'),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final service = PdfEditService();
                  await service.updatePdf(
                    type: 'step_by_step',
                    id: pdf.id,
                    updates: {
                      'title': titleCtrl.text.trim(),
                      'pdf_url': urlCtrl.text.trim(),
                    },
                  );
                  Logger.info('✅ [STEP-BY-STEP] ویرایش موفق');
                  await _load();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ بروزرسانی شد', textDirection: TextDirection.rtl),
                    backgroundColor: Colors.green,
                  ));
                } catch (e) {
                  Logger.error('❌ [STEP-BY-STEP] خطا در ویرایش', e);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('❌ خطا: $e', textDirection: TextDirection.rtl),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStepByStep(StepByStepPdf pdf) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تایید حذف', style: TextStyle(fontFamily: 'IRANSansXFaNum')),
          content: Text('حذف «${pdf.title}»؟', textDirection: TextDirection.rtl),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final service = PdfDeleteService();
      await service.deletePdf(type: 'step_by_step', id: pdf.id);
      Logger.info('✅ [STEP-BY-STEP] حذف موفق');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ حذف شد', textDirection: TextDirection.rtl),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      Logger.error('❌ [STEP-BY-STEP] خطا در حذف', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ خطا: $e', textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ));
    }
  }
  Future<void> _load() async {
    final appState = context.read<AppStateManager>();
    final gradeId = appState.authService.currentProfile?.grade ?? 7;
    // fieldOfStudy از نوع String است، فعلاً null می‌گذاریم
    final trackId = null;

    // در پنل ادمین: مستقیماً از Supabase و BookCovers برای لیست دروس استفاده می‌کنیم
    final contentService = ContentService(Supabase.instance.client);
    final subjects = await contentService.getSubjectsForUser(
      gradeId: gradeId,
      trackId: trackId,
    );

    // ✅ تغییر: مستقیماً از Supabase بخوان (بدون Mini-Request)
    final supabase = Supabase.instance.client;
    Logger.info('📚 [STEP-BY-STEP] بارگذاری PDF‌ها برای grade_id: $gradeId, track_id: $trackId');
    
    final pdfsData = await supabase
        .from('book_answer_pdfs')
        .select('*')
        .eq('grade_id', gradeId)
        .eq('active', true)
        .order('updated_at', ascending: false);
    
    final pdfs = (pdfsData as List<dynamic>)
        .map((j) => StepByStepPdf.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    
    Logger.info('✅ [STEP-BY-STEP] ${pdfs.length} PDF پیدا شد');

    // خواندن icon و cover از JSON - پشتیبانی از bookId عددی ("1", "2") و slug ("riazi", "arabi")
    final gradeJson = await contentService.loadGradeJson(gradeId);
    final Map<String, Map<String, String>> metaByBookId = {}; // bookId -> {icon, cover, title, slug}
    final Map<String, String> bookIdToSlug = {}; // bookId -> slug واقعی
    
    if (gradeJson != null) {
      final books = gradeJson['books'] as Map<String, dynamic>? ?? {};
      for (final entry in books.entries) {
        final bookIndex = entry.key; // مثل "1", "2"
        final bookMap = entry.value as Map<String, dynamic>;
        for (final subjectEntry in bookMap.entries) {
          final bookSlug = subjectEntry.key; // مثل "riazi", "arabi"
          final subjectMap = subjectEntry.value as Map<String, dynamic>;
          final icon = (subjectMap['icon'] as String? ?? '').trim();
          final cover = (subjectMap['cover'] as String? ?? '').trim();
          final title = (subjectMap['title'] as String? ?? '').trim();
          
          // ذخیره برای هر دو bookIndex و bookSlug
          final meta = {
            'icon': icon,
            'cover': cover,
            'title': title,
            'slug': bookSlug,
          };
          metaByBookId[bookIndex] = meta; // "1" -> meta
          metaByBookId[bookSlug] = meta;  // "riazi" -> meta
          
          // نگاشت bookId عددی به slug
          bookIdToSlug[bookIndex] = bookSlug; // "1" -> "riazi"
          bookIdToSlug[bookSlug] = bookSlug;   // "riazi" -> "riazi"
        }
      }
    }

    // گروه‌بندی PDF‌ها بر اساس slug واقعی (نه bookId عددی)
    final pdfsBySubject = <String, List<StepByStepPdf>>{};
    for (final pdf in pdfs) {
      // pdf.subjectId در واقع bookId (String) است که ممکن است عددی ("1") یا slug ("riazi") باشد
      final bookId = pdf.subjectId;
      // تبدیل bookId به slug واقعی
      final resolvedSlug = bookIdToSlug[bookId] ?? bookId;
      pdfsBySubject.putIfAbsent(resolvedSlug, () => []).add(pdf);
    }

    // اطمینان از حضور همه دروسی که PDF دارند در لیست subjects
    final pdfSlugs = pdfsBySubject.keys.toSet();
    final existingSlugs = subjects.map((s) => s.slug).where((s) => s.isNotEmpty).toSet();
    
    for (final slug in pdfSlugs) {
      if (!existingSlugs.contains(slug)) {
        // پیدا کردن meta از JSON با استفاده از slug
        final meta = metaByBookId[slug];
        final title = meta?['title'] ?? _getSubjectNameFromBookId(slug);
        final iconFromJson = meta?['icon'];
        final coverFromJson = meta?['cover'];
        
        // استفاده از icon از JSON اگر موجود باشد
        final iconPath = iconFromJson != null && iconFromJson.isNotEmpty
            ? iconFromJson
            : 'assets/images/icon-darsha/$slug.png';
        final coverPath = coverFromJson != null && coverFromJson.isNotEmpty
            ? coverFromJson
            : '';
        
        subjects.add(
          Subject(
            id: subjects.length + 1000, // یک id موقت
            name: title,
            slug: slug,
            iconPath: iconPath,
            bookCoverPath: coverPath,
            active: true,
          ),
        );
      }
    }

    // سورت کردن subjects: اولویت با موجود ها (با PDF)
    subjects.sort((a, b) {
      final aHasPdfs = pdfsBySubject[a.slug]?.isNotEmpty ?? false;
      final bHasPdfs = pdfsBySubject[b.slug]?.isNotEmpty ?? false;

      // اگر a موجود و b موجود نیست → a اول (بالا)
      if (aHasPdfs && !bHasPdfs) return -1;

      // اگر b موجود و a موجود نیست → b اول (بالا)
      if (!aHasPdfs && bHasPdfs) return 1;

      // اگر هر دو موجود یا هر دو ناموجود → ترتیب اصلی (حفظ id)
      return a.id.compareTo(b.id);
    });

    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _pdfsBySubject = pdfsBySubject;
      _loading = false;
    });
  }

  // نام‌های پیش‌فرض برای دروسی که در لیست subjects نبودند
  static const Map<int, String> _fallbackSubjectNames = {
    1: 'ریاضی',
    2: 'علوم',
    3: 'فارسی',
    4: 'قرآن',
    5: 'مطالعات اجتماعی',
    6: 'هدیه‌های آسمانی',
    7: 'نگارش',
    9: 'عربی',
    10: 'انگلیسی',
    14: 'دینی',
  };

  // تبدیل bookId به نام درس
  String _getSubjectNameFromBookId(String bookId) {
    const bookIdToName = {
      'riazi': 'ریاضی',
      'fizik': 'فیزیک',
      'shimi': 'شیمی',
      'zist': 'زیست',
      'olom': 'علوم',
      'arabi': 'عربی',
      'farsi': 'فارسی',
      'dini': 'دینی',
      'zaban': 'زبان',
      'englisi': 'انگلیسی',
      'hendese': 'هندسه',
      'gosaste': 'گسسته',
      'amar': 'آمار',
      'barname': 'برنامه‌نویسی',
      'mantegh': 'منطق',
      'payam': 'پیام',
      'quran': 'قرآن',
    };
    return bookIdToName[bookId] ?? bookId;
  }

  // آیکون‌های پیش‌فرض برای زمانی که iconPath/slug نداریم
  static const Map<int, String> _fallbackSubjectIcons = {
    1: 'riazi.png',
    2: 'olom.png',
    3: 'farsi.png',
    4: 'quran.png',
    5: 'motaleat.png',
    6: 'hediye.png',
    7: 'negaresh.png',
    9: 'arabi.png',
    10: 'englisi.png',
    14: 'dini.png',
  };

  String _getSubjectIconPath(Subject subject) {
    // اولویت با iconPath که از JSON آمده است
    if (subject.iconPath.isNotEmpty && subject.iconPath.startsWith('assets/')) {
      return subject.iconPath;
    }
    // اگر iconPath خالی است اما slug داریم، از slug استفاده کن
    if (subject.slug.isNotEmpty) {
      return 'assets/images/icon-darsha/${subject.slug}.png';
    }
    // fallback برای id (قدیمی)
    final fallback = _fallbackSubjectIcons[subject.id];
    if (fallback != null) {
      return 'assets/images/icon-darsha/$fallback';
    }
    // یک آیکون کلی؛ errorBuilder هم پوشش می‌دهد
    return 'assets/images/icon-darsha/riazi.png';
  }

  @override
  Widget build(BuildContext context) {
    final darkBlue = const Color(0xFF3629B7); // آبی جدید
    final appState = context.watch<AppStateManager>();
    final gradeString = (appState.authService.currentProfile?.grade != null)
        ? 'پایه ${mapGradeIntToString(appState.authService.currentProfile!.grade)}'
        : 'پایه ثبت نشده';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [darkBlue, Colors.white],
              stops: const [0.5, 0.5],
            ),
          ),
          child: Column(
            children: [
              // هدر
              Container(
                padding: EdgeInsets.only(
                  top: 65,
                  bottom: 40,
                  left: 16,
                  right: 20,
                ),
                color: darkBlue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'گام به گام',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'IRANSansXFaNum',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        gradeString,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IRANSansXFaNum',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // محتوا
              Expanded(
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
                      : RefreshIndicator(
                          onRefresh: () async {
                            // ✅ تغییر: فقط رفرش کن (بدون Mini-Request)
                            await _load();
                          },
                          child: _subjects.isEmpty
                              ? Center(
                                  child: EmptyStateWidgets.noStepByStepContent(
                                    context,
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio:
                                            1, // بازگشت به حالت عادی
                                      ),
                                  itemCount: _subjects.length,
                                  itemBuilder: (ctx, i) {
                                    final subject = _subjects[i];
                                    // استفاده از slug (bookId) به جای id
                                    final pdfs =
                                        _pdfsBySubject[subject.slug] ?? [];
                                    return _buildSubjectCard(subject, pdfs);
                                  },
                                ),
                        ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BubbleNavBar(
          currentIndex: 2,
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
              // در گام‌به‌گام هستیم
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

  Widget _buildSubjectCard(Subject subject, List<StepByStepPdf> pdfs) {
    final hasPdfs = pdfs.isNotEmpty;

    return InkWell(
      onTap: () {
        if (hasPdfs) {
          _showPdfList(subject, pdfs);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PDF موجود نیست',
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // آیکون درس
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  _getSubjectIconPath(subject),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  color: hasPdfs ? null : Colors.grey,
                  colorBlendMode: hasPdfs ? null : BlendMode.saturation,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.book, size: 40, color: Colors.grey.shade600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subject.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
                fontFamily: 'IRANSansXFaNum',
              ),
              textAlign: TextAlign.center,
            ),
            if (hasPdfs)
              Text(
                '${pdfs.length} فایل',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontFamily: 'IRANSansXFaNum',
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openPdf(StepByStepPdf pdf) async {
    try {
      // کش + PDF reader (مثل چپتر)
      final file = await PdfService.instance.downloadAndCache(pdf.pdfUrl);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SimpleNetworkWrapper(child: PdfReaderScreenPdfx(file: file)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا: $e',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
      );
    }
  }

  void _downloadPdf(StepByStepPdf pdf) async {
    try {
      // دانلود مستقیم بدون کش (مثل چپتر)
      await PdfService.instance.downloadToDownloads(pdf.pdfUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'دانلود شروع شد',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا در دانلود: $e',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
      );
    }
  }

  void _showPdfList(Subject subject, List<StepByStepPdf> pdfs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // هدر
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'گام‌به‌گام ${subject.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              // لیست PDFها
              Expanded(
                child: ListView.builder(
                  physics: AppScrollPhysics.smooth,
                  itemCount: pdfs.length,
                  itemBuilder: (context, index) {
                    final pdf = pdfs[index];
                    return _buildPdfListItem(pdf, ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfListItem(StepByStepPdf pdf, BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pdf.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                ),
                if (pdf.fileSizeMb != null)
                  Text(
                    '${pdf.fileSizeMb} مگابایت',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontFamily: 'IRANSansXFaNum',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // دکمه ویرایش (سبز)
          InkWell(
            onTap: () {
              Navigator.pop(ctx);
              _showEditStepByStep(pdf);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.edit,
                size: 20,
                color: Colors.green.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // دکمه حذف (قرمز)
          InkWell(
            onTap: () {
              Navigator.pop(ctx);
              _confirmDeleteStepByStep(pdf);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.delete,
                size: 20,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
