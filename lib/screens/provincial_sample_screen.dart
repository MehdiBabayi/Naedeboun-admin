import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content/provincial_sample_pdf.dart';
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

class ProvincialSampleScreen extends StatefulWidget {
  const ProvincialSampleScreen({super.key});

  @override
  State<ProvincialSampleScreen> createState() => _ProvincialSampleScreenState();
}

class _ProvincialSampleScreenState extends State<ProvincialSampleScreen> {
  List<ProvincialSamplePdf> _pdfs = [];
  List<ProvincialSamplePdf> _filteredPdfs = [];
  List<Subject> _subjects = [];
  bool _loading = true;
  int _selectedSubjectId = 0; // 0 = همه

  final List<Color> _colors = [
    Colors.green,
    Colors.red,
    Colors.amber,
    Colors.blue,
    Colors.purple,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppStateManager>();
    final gradeId = appState.authService.currentProfile?.grade ?? 7;
    final trackId = null;

    // بارگذاری دروس
    final subjects = await CachedContentService.getSubjectsForUser(
      gradeId: gradeId,
      trackId: trackId,
    );

    // بارگذاری PDFها
    final pdfs = await CachedContentService.getProvincialSamplePdfs(
      gradeId: gradeId,
      trackId: trackId,
    );

    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _pdfs = pdfs;
      _filteredPdfs = pdfs;
      _loading = false;
    });
  }

  void _filterBySubject(int subjectId) {
    setState(() {
      _selectedSubjectId = subjectId;
      if (subjectId == 0) {
        _filteredPdfs = _pdfs;
      } else {
        _filteredPdfs = _pdfs
            .where((pdf) => pdf.subjectId == subjectId)
            .toList();
      }
    });
  }

  Color _getColorForSubject(int subjectId) {
    return _colors[subjectId % _colors.length];
  }

  String _getSubjectName(int subjectId) {
    if (subjectId == 0) return 'همه';
    final subject = _subjects.firstWhere(
      (s) => s.id == subjectId,
      orElse: () => Subject(
        id: subjectId,
        name: 'نامشخص',
        slug: '',
        iconPath: '',
        bookCoverPath: '',
        active: true,
      ),
    );
    return subject.name;
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
                      'نمونه سوالات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
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
                      : Column(
                          children: [
                            // تب‌های دروس (فقط اگر PDF موجود باشد)
                            if (_pdfs.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildSubjectTab('همه', 0),
                                      ...() {
                                        final sortedSubjects = _subjects
                                            .toList();
                                        sortedSubjects.sort((a, b) {
                                          // ریاضی اول باشد
                                          if (a.name == 'ریاضی') return -1;
                                          if (b.name == 'ریاضی') return 1;
                                          return a.name.compareTo(b.name);
                                        });
                                        return sortedSubjects
                                            .map(
                                              (subject) => _buildSubjectTab(
                                                subject.name,
                                                subject.id,
                                              ),
                                            )
                                            .toList();
                                      }(),
                                    ],
                                  ),
                                ),
                              ),
                            // لیست PDFها
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  await CachedContentService.refreshProvincialSamplePdfs();
                                  await _load();
                                },
                                child: _filteredPdfs.isEmpty
                                    ? Center(
                                        child:
                                            EmptyStateWidgets.noProvincialSamples(
                                              context,
                                            ),
                                      )
                                    : ListView.builder(
                                        physics: AppScrollPhysics.smooth,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        itemCount: _filteredPdfs.length,
                                        itemBuilder: (ctx, i) {
                                          final pdf = _filteredPdfs[i];
                                          final color = _getColorForSubject(
                                            pdf.subjectId,
                                          );
                                          return _buildPdfCard(pdf, color);
                                        },
                                      ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BubbleNavBar(
          currentIndex: 1,
          onTap: (i) {
            if (i == 0) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            } else if (i == 1) {
              // در نمونه سوال هستیم
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

  Widget _buildSubjectTab(String name, int subjectId) {
    final isSelected = _selectedSubjectId == subjectId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _filterBySubject(subjectId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontFamily: 'IRANSansXFaNum',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfCard(ProvincialSamplePdf pdf, Color color) {
    return InkWell(
      onTap: () => _showPdfOptions(pdf),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // مربع رنگی سمت راست
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getSubjectName(pdf.subjectId),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'IRANSansXFaNum',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // محتوا
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pdf.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                        fontFamily: 'IRANSansXFaNum',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (pdf.hasAnswerKey) _buildTag('پاسخنامه'),
                          if (pdf.hasAnswerKey) const SizedBox(width: 8),
                          _buildTag('${pdf.publishYear}'),
                          const SizedBox(width: 8),
                          _buildTag(pdf.designer),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 8),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'IRANSansXFaNum',
            ),
          ),
        ],
      ),
    );
  }

  void _showPdfOptions(ProvincialSamplePdf pdf) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              pdf.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'IRANSansXFaNum',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'چه کاری می‌خواهید انجام دهید؟',
                  style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _readPdf(pdf);
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text(
                        'خواندن',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _downloadPdf(pdf);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text(
                        'دانلود',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _readPdf(ProvincialSamplePdf pdf) async {
    try {
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
            'خطا در خواندن PDF: $e',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
      );
    }
  }

  Future<void> _downloadPdf(ProvincialSamplePdf pdf) async {
    try {
      await PdfService.instance.downloadToDownloads(pdf.pdfUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF با موفقیت دانلود شد',
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
            'خطا در دانلود PDF: $e',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
        ),
      );
    }
  }
}
