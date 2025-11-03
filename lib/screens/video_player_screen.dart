import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../utils/logger.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? embedHtml; // HTML آپارات (script یا iframe)
  final bool allowLandscape;

  const VideoPlayerScreen({
    super.key,
    this.embedHtml,
    this.allowLandscape = true,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;

  String _buildWrapperHtml(String videoUrl) {
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
      /* تلاش برای چسباندن کنترل‌ها به پایین در صورت امکان */
      .plyr__controls, .controls, .control-bar, [class*="controls"], [class*="control"] { bottom: 0 !important; position: absolute !important; left: 0; right: 0; }
      .aparat-video-container, .video-container, .player-container, #player, .player { position: absolute !important; inset: 0 !important; }
      iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
    </style>
  </head>
  <body>
    $rawEmbed
  </body>
  </html>
''';
  }

  String _getAparatUrl(String raw) {
    if (raw.isEmpty) return '';
    // استخراج video hash از embed HTML
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

  Future<void> _tryFullscreenWithJS() async {
    if (_webViewController == null) return;

    try {
      // تلاش برای فعال‌سازی فول‌اسکرین با JavaScript
      await _webViewController!.runJavaScript('''
        // تلاش برای پیدا کردن ویدیو و فعال‌سازی فول‌اسکرین
        function tryFullscreen() {
          // روش 1: تلاش برای پیدا کردن دکمه فول‌اسکرین آپارات
          const fullscreenBtn = document.querySelector('[aria-label*="تمام صفحه"], [title*="تمام صفحه"], .fullscreen-btn, .aparat-fullscreen');
          if (fullscreenBtn) {
            fullscreenBtn.click();
            return true;
          }
          
          // روش 2: تلاش برای پیدا کردن ویدیو و فعال‌سازی فول‌اسکرین
          const video = document.querySelector('video');
          if (video && video.requestFullscreen) {
            video.requestFullscreen();
            return true;
          }
          
          // روش 3: تلاش برای پیدا کردن iframe و فعال‌سازی فول‌اسکرین
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.requestFullscreen) {
            iframe.requestFullscreen();
            return true;
          }
          
          // روش 4: تلاش برای پیدا کردن container و فعال‌سازی فول‌اسکرین
          const container = document.querySelector('.aparat-video-container, .video-container, .player-container');
          if (container && container.requestFullscreen) {
            container.requestFullscreen();
            return true;
          }
          
          return false;
        }
        
        // اجرای تابع
        const result = tryFullscreen();
        console.log('Fullscreen attempt result:', result);
        
        // اگر موفق نشد، بعد از 1 ثانیه دوباره تلاش کن
        if (!result) {
          setTimeout(tryFullscreen, 1000);
        }
      ''');
    } catch (e) {
      Logger.error('خطا در اجرای JavaScript برای فول‌اسکرین', e);
    }
  }

  @override
  void initState() {
    super.initState();

    // قفل کردن orientation به landscape
    if (widget.allowLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // برای WebView/iframe بهتر است edgeToEdge فعال باشد تا inset ها خودکار کنترل شوند
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // ایجاد WebViewController با تنظیمات fullscreen (راه‌حل Issue #67791)
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'خطا در بارگذاری ویدیو: ${error.description}',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
                ),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      );

    // انتخاب روش بارگذاری: اگر اسکریپت امبدد است، همان را با CSS سفارشی لود کن؛ در غیر اینصورت iframe URL
    final raw = widget.embedHtml ?? '';
    final videoUrl = _getAparatUrl(raw);
    if (raw.contains('<script') &&
        raw.toLowerCase().contains('aparat.com/embed')) {
      _webViewController!.loadHtmlString(_buildScriptWrapperHtml(raw));
    } else if (videoUrl.isNotEmpty) {
      _webViewController!.loadHtmlString(_buildWrapperHtml(videoUrl));

      // تلاش برای فعال‌سازی فول‌اسکرین با JavaScript
      Future.delayed(const Duration(seconds: 2), () {
        _tryFullscreenWithJS();
      });
    }
  }

  @override
  void dispose() {
    // بازگشت به portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = _getAparatUrl(widget.embedHtml ?? '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: videoUrl.isNotEmpty && _webViewController != null
                ? WebViewWidget(controller: _webViewController!)
                : const Center(
                    child: Text(
                      'ویدیو در دسترس نیست',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'در حال بارگذاری ویدیو...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'خطا در بارگذاری ویدیو',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      final raw = widget.embedHtml ?? '';
                      final videoUrl = _getAparatUrl(raw);
                      if (raw.contains('<script') &&
                          raw.toLowerCase().contains('aparat.com/embed')) {
                        _webViewController?.loadHtmlString(
                          _buildScriptWrapperHtml(raw),
                        );
                      } else if (videoUrl.isNotEmpty) {
                        _webViewController?.loadHtmlString(
                          _buildWrapperHtml(videoUrl),
                        );
                      }
                    },
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            ),
          // دکمه برگشت شناور در گوشه بالا (چپ)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    color: Colors.black54,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
