import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content/provincial_sample_pdf.dart';
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
  dynamic _selectedSubjectId = 0; // 0 = همه (یا '0')

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

    // بارگذاری دروس مستقیماً از Supabase از طریق ContentService (بدون Mini-Request)
    final contentService = ContentService(Supabase.instance.client);
    final subjects = await contentService.getSubjectsForUser(
      gradeId: gradeId,
      trackId: trackId,
    );

    // ✅ تغییر: مستقیماً از Supabase بخوان (بدون Mini-Request)
    final supabase = Supabase.instance.client;
    Logger.info('📄 [PROVINCIAL] بارگذاری PDF‌ها برای grade_id: $gradeId, track_id: $trackId');
    
    final pdfsData = await supabase
        .from('provincial_sample_pdfs')
        .select('*')
        .eq('grade_id', gradeId)
        .eq('active', true)
        .filter('track_id', trackId == null ? 'is' : 'eq', trackId)
        .order('updated_at', ascending: false);
    
    final pdfs = (pdfsData as List<dynamic>)
        .map((j) => ProvincialSamplePdf.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    
    Logger.info('✅ [PROVINCIAL] ${pdfs.length} PDF پیدا شد');

    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _pdfs = pdfs;
      _filteredPdfs = pdfs;
      _loading = false;
    });
  }

  void _filterBySubject(dynamic subjectId) {
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

  Color _getColorForSubject(dynamic subjectId) {
    int index;
    if (subjectId is int) {
      index = subjectId;
    } else if (subjectId is String) {
      index = subjectId.hashCode;
    } else {
      index = 0;
    }
    index = index.abs() % _colors.length;
    return _colors[index];
  }

  String _getSubjectName(dynamic subjectId) {
    if (subjectId == 0 || subjectId == '0') return 'همه';

    // اگر subjectId عدد است (قدیمی)
    if (subjectId is int) {
      final subject = _subjects.firstWhere(
        (s) => s.id == subjectId,
        orElse: () => Subject(
          id: subjectId,
          name: _fallbackSubjectNames[subjectId] ?? 'نامشخص',
          slug: '',
          iconPath: '',
          bookCoverPath: '',
          active: true,
        ),
      );
      return subject.name;
    }

    // اگر subjectId رشته است (جدید - bookId)
    if (subjectId is String) {
      // از _subjectNameToId استفاده کنیم اگر موجود باشد
      final subjectNames = _subjects.map((s) => s.name).toSet();
      // یا از یک mapping ساده استفاده کنیم
      final bookIdToName = {
        'riazi': 'ریاضی',
        'fizik': 'فیزیک',
        'shimi': 'شیمی',
        'zist': 'زیست',
        'olom': 'علوم',
        'arabi': 'عربی',
        'farsi': 'فارسی',
        'dini': 'دینی',
        'zaban': 'زبان',
        'hendese': 'هندسه',
        'gosaste': 'گسسته',
        'amar': 'آمار',
        'barname': 'برنامه‌نویسی',
        'mantegh': 'منطق',
        'payam': 'پیام',
      };
      return bookIdToName[subjectId] ?? subjectId;
    }

    return 'نامشخص';
  }

  // نام‌های پیش‌فرض در صورتی‌که درس در لیست subjects برنگردد
  static const Map<int, String> _fallbackSubjectNames = {
    1: 'ریاضی',
    2: 'علوم',
    3: 'فارسی',
    4: 'قرآن',
    5: 'مطالعات اجتماعی',
    6: 'هدیه‌های آسمانی',
    9: 'عربی',
    10: 'انگلیسی',
    14: 'دینی',
  };

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
                                        // تب‌ها بر اساس PDFهای موجود ساخته می‌شوند
                                        final ids = _pdfs
                                            .map((p) => p.subjectId)
                                            .toSet()
                                            .toList();
                                        // مرتب‌سازی: ریاضی اول سپس بر اساس نام موضوع
                                        ids.sort((a, b) {
                                          final an = _getSubjectName(a);
                                          final bn = _getSubjectName(b);
                                          if (an == 'ریاضی') return -1;
                                          if (bn == 'ریاضی') return 1;
                                          return an.compareTo(bn);
                                        });
                                        return ids
                                            .map((id) => _buildSubjectTab(
                                                  _getSubjectName(id),
                                                  id,
                                                ))
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
                                  // ✅ تغییر: فقط رفرش کن (بدون Mini-Request)
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

  Widget _buildSubjectTab(String name, dynamic subjectId) {
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
            // مربع رنگی سمت راست (با فاصله از لبه‌های کارت)
            Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _getSubjectName(pdf.subjectId),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
                          _buildTag(pdf.designer ?? ''),
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
                    // دکمه ویرایش (سبز)
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _showEditProvincial(pdf);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text(
                        'ویرایش',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    // دکمه حذف (قرمز)
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _confirmDeleteProvincial(pdf);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text(
                        'حذف',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
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

  Future<void> _showEditProvincial(ProvincialSamplePdf pdf) async {
    final titleCtrl = TextEditingController(text: pdf.title);
    final urlCtrl = TextEditingController(text: pdf.pdfUrl);
    final yearCtrl = TextEditingController(text: pdf.publishYear.toString());
    final designerCtrl = TextEditingController(text: pdf.designer);
    bool hasAnswer = pdf.hasAnswerKey;

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
          title: const Text('ویرایش نمونه سوال', style: TextStyle(fontFamily: 'IRANSansXFaNum')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'عنوان'), textDirection: TextDirection.rtl, textAlign: TextAlign.right),
                const SizedBox(height: 8),
                TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'لینک PDF'), textDirection: TextDirection.rtl, textAlign: TextAlign.right),
                const SizedBox(height: 8),
                TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'سال انتشار'), keyboardType: TextInputType.number, textDirection: TextDirection.rtl, textAlign: TextAlign.right),
                const SizedBox(height: 8),
                TextField(controller: designerCtrl, decoration: const InputDecoration(labelText: 'طراح'), textDirection: TextDirection.rtl, textAlign: TextAlign.right),
                const SizedBox(height: 8),
                Row(children:[
                  Checkbox(value: hasAnswer, onChanged: (v)=> setSt(()=> hasAnswer = v??false)),
                  const Text('پاسخنامه دارد', style: TextStyle(fontFamily: 'IRANSansXFaNum')),
                ])
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final service = PdfEditService();
                  await service.updatePdf(
                    type: 'provincial',
                    id: pdf.id,
                    updates: {
                      'title': titleCtrl.text.trim(),
                      'pdf_url': urlCtrl.text.trim(),
                      'publish_year': int.tryParse(yearCtrl.text.trim()) ?? pdf.publishYear,
                      'designer': designerCtrl.text.trim(),
                      'has_answer_key': hasAnswer,
                    },
                  );
                  Logger.info('✅ [PROVINCIAL] ویرایش موفق');
                  await _load();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ بروزرسانی شد', textDirection: TextDirection.rtl),
                    backgroundColor: Colors.green,
                  ));
                } catch (e) {
                  Logger.error('❌ [PROVINCIAL] خطا در ویرایش', e);
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
        )),
      ),
    );
  }

  Future<void> _confirmDeleteProvincial(ProvincialSamplePdf pdf) async {
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
      await service.deletePdf(type: 'provincial', id: pdf.id);
      Logger.info('✅ [PROVINCIAL] حذف موفق');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ حذف شد', textDirection: TextDirection.rtl),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      Logger.error('❌ [PROVINCIAL] خطا در حذف', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ خطا: $e', textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ));
    }
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
