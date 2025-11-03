import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content/step_by_step_pdf.dart';
import '../models/content/subject.dart';
import '../services/content/cached_content_service.dart';
import '../services/pdf/pdf_service.dart';
import '../providers/core/app_state_manager.dart';
import 'pdf_reader_screen_pdfx.dart';
import '../widgets/bubble_nav_bar.dart';
import '../widgets/common/smooth_scroll_physics.dart';
import '../../utils/grade_utils.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/network/network_wrapper.dart';

class StepByStepScreen extends StatefulWidget {
  const StepByStepScreen({super.key});

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  List<Subject> _subjects = [];
  Map<int, List<StepByStepPdf>> _pdfsBySubject = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppStateManager>();
    final gradeId = appState.authService.currentProfile?.grade ?? 7;
    // fieldOfStudy از نوع String است، فعلاً null می‌گذاریم
    final trackId = null;

    final subjects = await CachedContentService.getSubjectsForUser(
      gradeId: gradeId,
      trackId: trackId,
    );

    final pdfs = await CachedContentService.getStepByStepPdfs(
      gradeId: gradeId,
      trackId: trackId,
    );

    // گروه‌بندی PDF‌ها بر اساس درس
    final pdfsBySubject = <int, List<StepByStepPdf>>{};
    for (final pdf in pdfs) {
      pdfsBySubject.putIfAbsent(pdf.subjectId, () => []).add(pdf);
    }

    // سورت کردن subjects: اولویت با موجود ها (با PDF)
    subjects.sort((a, b) {
      final aHasPdfs = pdfsBySubject[a.id]?.isNotEmpty ?? false;
      final bHasPdfs = pdfsBySubject[b.id]?.isNotEmpty ?? false;

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
                            await CachedContentService.refreshStepByStepPdfs();
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
                                    final pdfs =
                                        _pdfsBySubject[subject.id] ?? [];
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
                  subject.iconPath.isNotEmpty &&
                          subject.iconPath.startsWith('assets/')
                      ? subject.iconPath
                      : subject.iconPath.isNotEmpty
                      ? 'assets/images/icon-darsha/${subject.iconPath}'
                      : 'assets/images/icon-darsha/${subject.slug}.png',
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
          // دکمه خواندن
          InkWell(
            onTap: () {
              Navigator.pop(ctx);
              _openPdf(pdf);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.visibility,
                size: 20,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // دکمه دانلود
          InkWell(
            onTap: () {
              Navigator.pop(ctx);
              _downloadPdf(pdf);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.download,
                size: 20,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
