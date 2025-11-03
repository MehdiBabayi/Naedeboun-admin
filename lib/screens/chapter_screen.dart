import 'package:flutter/material.dart';
import 'package:nardeboun/models/content/chapter.dart';
import 'package:nardeboun/models/content/lesson.dart';
import 'package:nardeboun/models/content/lesson_video.dart';
import 'package:nardeboun/models/content/subject.dart';
import 'package:nardeboun/services/content/cached_content_service.dart';
import '../services/cache/cache_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import '../widgets/common/smooth_scroll_physics.dart';
import 'pdf_reader_screen_pdfx.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../services/pdf/pdf_service.dart';
import '../widgets/bubble_nav_bar.dart';
import '../widgets/common/empty_state_widget.dart';
import '../../utils/logger.dart';

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
  bool _loading = false; // ← شروع با false (بدون Loader برای Hive)
  List<Lesson>? _lessons; // ← null = هنوز لود نشده
  Map<int, List<LessonVideo>> _videosByLesson = {};
  String _selectedStyle = 'جزوه';
  WebViewController? _popupWebViewController;
  Map<String, String> _teachersMap = {};

  // call _loadTeachersMap from existing initState (append there if present)

  Future<void> _loadTeachersMap() async {
    try {
      final boxName =
          'grade_${widget.gradeId}_${widget.trackId ?? "null"}_content';
      final box = await Hive.openBox(boxName);
      final teachersJson = box.get('teachers') as String?;
      if (teachersJson != null && teachersJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(teachersJson);
        final Map<String, String> mapped = decoded.map(
          (key, value) => MapEntry(key.toString(), (value ?? '').toString()),
        );
        if (mounted) {
          setState(() {
            _teachersMap = mapped;
          });
        }
      }
    } catch (e) {
      // silent
    }
  }

  String _getAparatUrl(String raw) {
    if (raw.isEmpty) return '';
    final scriptMatch = RegExp(
      r'aparat\.com\/embed\/([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    final vMatch = RegExp(
      r'aparat\.com\/v\/([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    final hash = scriptMatch?.group(1) ?? vMatch?.group(1);
    if (hash == null) return '';
    return 'https://www.aparat.com/video/video/embed/videohash/$hash/vt/frame?autoplay=1&t=0';
  }

  String _buildIframeWrapperHtml(String videoUrl) {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0, user-scalable=no" />
    <style>
      html, body { height: 100%; margin: 0; padding: 0; overflow: hidden; background: #000; }
      iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
    </style>
  </head>
  <body>
    <iframe src="$videoUrl"
            allowfullscreen
            webkitallowfullscreen
            mozallowfullscreen
            allow="autoplay; fullscreen; picture-in-picture">
    </iframe>
  </body>
</html>
''';
  }

  String _buildScriptWrapperHtml(String rawEmbed) {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0, user-scalable=no" />
    <style>
      html, body { height: 100%; margin: 0; padding: 0; overflow: hidden; background: #000; }
      .plyr__controls, .controls, .control-bar, [class*="controls"], [class*="control"] { bottom: 0 !important; position: absolute !important; left: 0; right: 0; }
      .aparat-video-container, .video-container, .player-container, #player, .player { position: absolute !important; inset: 0 !important; }
      iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
      /* آیکون آپارات مخفی نمی‌شود - فقط کلیک‌ها مسدود می‌شوند */
    </style>
  </head>
  <body>
    $rawEmbed
    <script>
      // مسدود کردن کلیک راست
      document.addEventListener('contextmenu', function(e) {
        e.preventDefault();
        return false;
      });
    </script>
  </body>
</html>
''';
  }

  void _showUnauthorizedMessage() {
    // نمایش پیام خطا در WebView با تم مرکزی
    _popupWebViewController?.loadHtmlString('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <style>
      html, body {
        margin: 0;
        padding: 0;
        height: 100%;
        width: 100%;
        box-sizing: border-box;
        background: #ffffff;
        font-family: 'IRANSansXFaNum', Arial, sans-serif;
        direction: rtl;
        display: flex;
        align-items: center;
        justify-content: center;
        overflow: hidden;
      }

      .error-container {
        width: 90vw;
        max-width: 320px;
        padding: 16px;
        background: #ffffff;
        border-radius: 12px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.1);
        text-align: center;
        color: #1976D2;
        box-sizing: border-box;
        overflow-wrap: break-word;
        word-break: break-word;
      }

      .error-icon {
        font-size: 40px;
        margin-bottom: 12px;
        color: #D32F2F;
      }

      .error-title {
        font-size: 20px;
        font-weight: bold;
        color: #D32F2F;
      }
    </style>
  </head>
  <body>
    <div class="error-container">
      <div class="error-icon">⚠️</div>
      <div class="error-title">خطا در دسترسی</div>
    </div>
  </body>
</html>
''');
  }

  void _openVideoPopup(LessonVideo video) async {
    final raw = video.embedHtml ?? '';
    final url = _getAparatUrl(raw);
    _popupWebViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Fullscreen',
        onMessageReceived: (JavaScriptMessage msg) async {
          final value = msg.message;
          if (value == 'enter') {
            await SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else if (value == 'exit') {
            await SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            Logger.debug('🔍 [VIDEO] Navigation request: ${request.url}');

            final url = request.url.toLowerCase();

            // اجازه دسترسی به embed URL های آپارات (با آرگومان‌های متغیر)
            if (url.contains('aparat.com/embed/') ||
                url.contains('aparat.com/video/video/embed/videohash/') ||
                url.startsWith('data:text/html') ||
                url.startsWith('about:blank') ||
                url.startsWith('blob:') ||
                url.startsWith('javascript:') ||
                url.isEmpty ||
                (url.contains('aparat.com') && url.contains('embed'))) {
              Logger.debug('✅ [VIDEO] Allowing embed URL: ${request.url}');
              return NavigationDecision.navigate;
            }

            // اجازه منابع ضروری (CDN ها، فونت‌ها، فایل‌های استاتیک)
            if (url.startsWith('http://') || url.startsWith('https://')) {
              // اجازه CDN ها و منابع استاتیک آپارات
              if (url.contains('cdn.aparat.com') ||
                  url.contains('aparat.com/static/') ||
                  url.contains('aparat.com/assets/') ||
                  url.contains('.css') ||
                  url.contains('.js') ||
                  url.contains('.woff') ||
                  url.contains('.woff2') ||
                  url.contains('.ttf') ||
                  url.contains('.eot') ||
                  url.contains('.png') ||
                  url.contains('.jpg') ||
                  url.contains('.jpeg') ||
                  url.contains('.gif') ||
                  url.contains('.svg') ||
                  url.contains('.ico') ||
                  url.contains('fonts.googleapis.com') ||
                  url.contains('fonts.gstatic.com') ||
                  url.contains('ajax.googleapis.com')) {
                Logger.debug('✅ [VIDEO] Allowing resource URL: ${request.url}');
                return NavigationDecision.navigate;
              }

              // مسدود کردن همه لینک‌های خارجی (تبلیغات، سایت‌های دیگر)
              if (!url.contains('aparat.com')) {
                Logger.debug(
                  '❌ [VIDEO] Blocking external link (ad): ${request.url}',
                );
                _showUnauthorizedMessage();
                return NavigationDecision.prevent;
              }

              // مسدود کردن URL های خارجی آپارات (صفحه اصلی سایت، نه embed)
              if (url.contains('aparat.com') &&
                  !url.contains('embed') &&
                  !url.contains('videohash')) {
                Logger.debug(
                  '❌ [VIDEO] Blocking external aparat: ${request.url}',
                );
                _showUnauthorizedMessage();
                return NavigationDecision.prevent;
              }
            }

            // برای سایر URL ها هم اجازه نمی‌دهیم (ایمن‌تر است)
            Logger.debug('❌ [VIDEO] Blocking unknown URL: ${request.url}');
            _showUnauthorizedMessage();
            return NavigationDecision.prevent;
          },
          onPageFinished: (url) async {
            // Inject listeners for fullscreen changes and try to unmute the video if accessible
            await _popupWebViewController?.runJavaScript('''
              (function(){
                function notifyFS(){
                  var isFs = !!(document.fullscreenElement || document.webkitFullscreenElement);
                  if (isFs) { Fullscreen.postMessage('enter'); } else { Fullscreen.postMessage('exit'); }
                }
                document.addEventListener('fullscreenchange', notifyFS);
                document.addEventListener('webkitfullscreenchange', notifyFS);
                // Try unmute if the video is in same document (script embed case)
                setTimeout(function(){
                  var v = document.querySelector('video');
                  if (v) { try { v.muted = false; v.volume = 1.0; } catch(e){} }
                }, 200);
                
                // مسدود کردن کلیک‌ها روی لینک‌های تبلیغاتی (اطلاعات بیشتر)
                function blockAdLinks(e) {
                  var target = e.target;
                  // پیدا کردن لینک نزدیک‌ترین والد
                  while (target && target !== document) {
                    if (target.tagName === 'A' || target.tagName === 'BUTTON') {
                      var href = target.href || target.getAttribute('href') || target.getAttribute('onclick');
                      if (href && !href.includes('aparat.com') && !href.includes('embed')) {
                        e.preventDefault();
                        e.stopPropagation();
                        e.stopImmediatePropagation();
                        // ارسال پیام به Flutter برای نمایش خطا
                        if (window.Flutter) {
                          window.Flutter.postMessage(JSON.stringify({type: 'blocked_ad_link', url: href}));
                        }
                        return false;
                      }
                    }
                    target = target.parentElement;
                  }
                }
                // اضافه کردن listener برای کلیک‌ها (capture phase برای catch کردن همه)
                document.addEventListener('click', blockAdLinks, true);
                // مسدود کردن کلیک راست هم (قبلاً بود)
                document.addEventListener('contextmenu', function(e) {
                  e.preventDefault();
                  return false;
                });
              })();
            ''');
          },
        ),
      );

    if (raw.contains('<script') &&
        raw.toLowerCase().contains('aparat.com/embed')) {
      _popupWebViewController!.loadHtmlString(_buildScriptWrapperHtml(raw));
    } else if (url.isNotEmpty) {
      _popupWebViewController!.loadHtmlString(_buildIframeWrapperHtml(url));
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.black,
                              child: _popupWebViewController != null
                                  ? WebViewWidget(
                                      controller: _popupWebViewController!,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => Navigator.of(ctx).pop(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.close, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // دکمه های PDF بر اساس وجود URL
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        children: [
                          if (video.notePdfUrl != null &&
                              video.notePdfUrl!.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF3629B7),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final file = await PdfService.instance
                                          .downloadAndCache(video.notePdfUrl!);
                                      if (!ctx.mounted) return;
                                      Navigator.of(ctx).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PdfReaderScreenPdfx(file: file),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text(
                                      'خواندن جزوه',
                                      style: TextStyle(
                                        fontFamily: 'IRANSansXFaNum',
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF3629B7),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () async {
                                      try {
                                        await PdfService.instance
                                            .downloadToDownloads(
                                              video.notePdfUrl!,
                                            );
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.green,
                                              content: Text(
                                                'در حال دانلود...',
                                                textAlign: TextAlign.right,
                                                textDirection:
                                                    TextDirection.rtl,
                                                style: TextStyle(
                                                  fontFamily: 'IRANSansXFaNum',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'خطا در دانلود جزوه: $e',
                                                textAlign: TextAlign.right,
                                                textDirection:
                                                    TextDirection.rtl,
                                                style: TextStyle(
                                                  fontFamily: 'IRANSansXFaNum',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.download),
                                    label: const Text(
                                      'دانلود جزوه',
                                      style: TextStyle(
                                        fontFamily: 'IRANSansXFaNum',
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (video.exercisePdfUrl != null &&
                              video.exercisePdfUrl!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF3629B7),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final file = await PdfService.instance
                                          .downloadAndCache(
                                            video.exercisePdfUrl!,
                                          );
                                      if (!ctx.mounted) return;
                                      Navigator.of(ctx).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PdfReaderScreenPdfx(file: file),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text(
                                      'خواندن نمونه سوال',
                                      style: TextStyle(
                                        fontFamily: 'IRANSansXFaNum',
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF3629B7),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () async {
                                      try {
                                        await PdfService.instance
                                            .downloadToDownloads(
                                              video.exercisePdfUrl!,
                                            );
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.green,
                                              content: Text(
                                                'در حال دانلود...',
                                                textAlign: TextAlign.right,
                                                textDirection:
                                                    TextDirection.rtl,
                                                style: TextStyle(
                                                  fontFamily: 'IRANSansXFaNum',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'خطا در دانلود نمونه سوال: $e',
                                                textAlign: TextAlign.right,
                                                textDirection:
                                                    TextDirection.rtl,
                                                style: TextStyle(
                                                  fontFamily: 'IRANSansXFaNum',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.download),
                                    label: const Text(
                                      'دانلود نمونه سوال',
                                      style: TextStyle(
                                        fontFamily: 'IRANSansXFaNum',
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) async {
      // Ensure portrait restored when dialog closes
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadTeachersMap();
  }

  Future<void> _load() async {
    // دریافت نام شاخه اگر trackId موجود باشد
    if (widget.trackId != null) {
      try {
        // Track information is not used in this screen
      } catch (e) {
        Logger.error('Error fetching track name', e);
      }
    }

    // دریافت مسیر عکس فصل ازbook_covers

    // دریافت لیست درس‌ها و ویدیوها با Cache
    final lessons = await CachedContentService.getLessons(
      widget.chapter.id,
      gradeId: widget.gradeId,
      trackId: widget.trackId,
    );

    // بهینه‌سازی: parallel loading برای ویدیوها
    final map = <int, List<LessonVideo>>{};
    final futures = lessons.map((l) async {
      final videos = await CachedContentService.getLessonVideos(
        l.id,
        gradeId: widget.gradeId,
        trackId: widget.trackId,
      );
      return MapEntry(l.id, videos);
    });

    // اجرای موازی همه ویدیوها
    final results = await Future.wait(futures);
    for (final entry in results) {
      map[entry.key] = entry.value;
    }

    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _videosByLesson = map;
      _loading = false;
    });
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
                            // لیست درس‌ها
                            Expanded(
                              child: _lessons == null
                                  ? const SizedBox.shrink() // ← هنوز لود نشده
                                  : RefreshIndicator(
                                      onRefresh: () async {
                                        CachedContentService.refreshVideos();
                                        AppCacheManager.clearCache(
                                          'lessons_${widget.chapter.id}',
                                        );
                                        await _load();
                                      },
                                      child: _lessons!.isEmpty
                                          ? SingleChildScrollView(
                                              physics: AppScrollPhysics.smooth,
                                              child: Center(
                                                child: Padding(
                                                  padding: EdgeInsets.all(32.0),
                                                  child:
                                                      EmptyStateWidgets.noLessonContent(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            )
                                          : Builder(
                                              builder: (context) {
                                                // 1) یافتن بالاترین lesson_order که ویدیو برای style انتخابی دارد
                                                int maxLessonOrderWithVideo = 0;
                                                for (final lesson
                                                    in _lessons!) {
                                                  final videos =
                                                      _videosByLesson[lesson
                                                          .id] ??
                                                      const [];
                                                  final filteredVideos = videos
                                                      .where(
                                                        (v) =>
                                                            _getStyleName(
                                                              v.style,
                                                            ) ==
                                                            _selectedStyle,
                                                      )
                                                      .toList();
                                                  if (filteredVideos
                                                          .isNotEmpty &&
                                                      lesson.lessonOrder >
                                                          maxLessonOrderWithVideo) {
                                                    maxLessonOrderWithVideo =
                                                        lesson.lessonOrder;
                                                  }
                                                }

                                                // 2) اگر هیچ ویدیویی برای این سبک نیست: فقط یک EmptyState
                                                if (maxLessonOrderWithVideo ==
                                                    0) {
                                                  return SingleChildScrollView(
                                                    physics:
                                                        AppScrollPhysics.smooth,
                                                    child: Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              32.0,
                                                            ),
                                                        child:
                                                            EmptyStateWidgets.noEducationContent(
                                                              context,
                                                            ),
                                                      ),
                                                    ),
                                                  );
                                                }

                                                // 3) ساخت لیست lesson_order ها از 1 تا max (پر کردن gap ها)
                                                final lessonOrdersToShow =
                                                    List.generate(
                                                      maxLessonOrderWithVideo,
                                                      (i) => i + 1,
                                                    );

                                                // 4) رندر لیست با gap filling
                                                return ListView.builder(
                                                  physics:
                                                      AppScrollPhysics.gentle,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                  itemCount:
                                                      lessonOrdersToShow.length,
                                                  itemBuilder: (ctx, i) {
                                                    final lessonOrder =
                                                        lessonOrdersToShow[i];

                                                    // پیدا کردن lesson با این lessonOrder
                                                    final lesson = _lessons!
                                                        .firstWhere(
                                                          (l) =>
                                                              l.lessonOrder ==
                                                              lessonOrder,
                                                          orElse: () => Lesson(
                                                            id: 0,
                                                            chapterId: widget
                                                                .chapter
                                                                .id,
                                                            lessonOrder:
                                                                lessonOrder,
                                                            title:
                                                                'درس $lessonOrder',
                                                            active: true,
                                                          ),
                                                        );

                                                    final videos =
                                                        _videosByLesson[lesson
                                                            .id] ??
                                                        const [];
                                                    final filteredVideos = videos
                                                        .where(
                                                          (v) =>
                                                              _getStyleName(
                                                                v.style,
                                                              ) ==
                                                              _selectedStyle,
                                                        )
                                                        .toList();

                                                    // اگر ویدیو نداره: کارت خالی
                                                    if (filteredVideos
                                                        .isEmpty) {
                                                      return _buildEmptyLessonCard(
                                                        lesson,
                                                        theme,
                                                        darkBlue,
                                                      );
                                                    }

                                                    // اگر ویدیو داره: کارت معمولی
                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 16,
                                                          ),
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              border: Border.all(
                                                                color: Colors
                                                                    .green
                                                                    .shade300,
                                                                width: 2,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.15,
                                                                      ),
                                                                  blurRadius:
                                                                      12,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        6,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            padding:
                                                                const EdgeInsets.fromLTRB(
                                                                  8,
                                                                  16,
                                                                  8,
                                                                  8,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                const SizedBox(
                                                                  height: 32,
                                                                ),
                                                                ...List.generate(
                                                                  filteredVideos
                                                                      .length,
                                                                  (
                                                                    videoIndex,
                                                                  ) => _buildVideoCard(
                                                                    filteredVideos[videoIndex],
                                                                    theme,
                                                                    darkBlue,
                                                                    videoIndex +
                                                                        1,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Positioned(
                                                            right: 20,
                                                            top: -20,
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.surface,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                'پله ${_convertToPersian(lesson.lessonOrder)}',
                                                                style: theme.textTheme.bodySmall?.copyWith(
                                                                  color:
                                                                      darkBlue,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      ((theme.textTheme.bodySmall?.fontSize ??
                                                                                  12) *
                                                                              2.2)
                                                                          .clamp(
                                                                            18,
                                                                            28,
                                                                          ),
                                                                  fontFamily:
                                                                      'IRANSansXFaNum',
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .left,
                                                                softWrap: false,
                                                                overflow:
                                                                    TextOverflow
                                                                        .fade,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
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

  Widget _buildVideoCard(
    LessonVideo video,
    ThemeData theme,
    Color darkBlue,
    int rowNumber,
  ) {
    final lesson = _lessons!.firstWhere(
      (l) => l.id == video.lessonId,
      orElse: () => Lesson(
        id: video.lessonId,
        chapterId: 0,
        lessonOrder: 0,
        title: 'عنوان درس',
        active: true,
      ),
    );

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
                        _convertNumbersToPersian(lesson.title),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'IRANSansXFaNum',
                          fontSize: 13, // کاهش اندازه فونت
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1, // تغییر از 2 به 1
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
                                'استاد ${_teachersMap[video.teacherId.toString()] ?? 'نامشخص'}',
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
                  Icons.play_arrow,
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

  Widget _buildEmptyLessonCard(Lesson lesson, ThemeData theme, Color darkBlue) {
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
                'پله ${_convertToPersian(lesson.lessonOrder)}',
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
    switch (style) {
      case 'جزوه':
      case 'note':
        return 'جزوه';
      case 'کتاب درسی':
      case 'book':
        return 'کتاب درسی';
      case 'نمونه سوال':
      case 'sample':
        return 'نمونه سوال';
      default:
        return 'جزوه';
    }
  }
}
