import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/config/config_service.dart';

/// صفحه وب‌ویو برای گزارش خطا با پشتیبانی از آپلود فایل
/// - فقط لینک استاندارد از config.json را مجاز می‌کند
/// - خطاهای HTML و JavaScript را نمایش می‌دهد
/// - از آپلود فایل پشتیبانی می‌کند (با استفاده از AndroidWebViewController)
class ReportErrorWebViewScreen extends StatefulWidget {
  const ReportErrorWebViewScreen({super.key});

  @override
  State<ReportErrorWebViewScreen> createState() => _ReportErrorWebViewScreenState();
}

class _ReportErrorWebViewScreenState extends State<ReportErrorWebViewScreen> {
  late final WebViewController _controller;
  late final Uri _allowedUri;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final url = ConfigService.instance.getValue<String>('reportErrorUrl') ??
        'https://nardeboun.ir/';
    _allowedUri = Uri.parse(url);

    // ساخت کنترلر WebView
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress >= 80 && _loading) {
              setState(() {
                _loading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _loading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _loading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red,
                  content: Text(
                    'خطا در بارگذاری صفحه: ${error.description}',
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            if (!_isAllowed(uri)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.orange,
                    content: Text(
                      'این لینک مجاز نیست: ${request.url}',
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_allowedUri.toString()));

    // تنظیم AndroidWebViewController برای پشتیبانی از آپلود فایل
    if (Platform.isAndroid) {
      (_controller.platform as AndroidWebViewController)
          .setOnShowFileSelector(_androidFilePicker);
    }

    // تایم‌اوت: اگر 15 ثانیه در حالت لود ماند، لودر را خاموش کن
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'بارگذاری بیش از حد طولانی شد. لطفاً اتصال اینترنت را بررسی کنید.',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  /// هندلر انتخاب فایل برای Android
  /// بر اساس راه حل Stack Overflow: https://stackoverflow.com/questions/65890138/file-upload-does-not-work-inside-webview-flutter
  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      // باز کردن file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        // کپی فایل به cache directory برای دسترسی WebView
        final cacheDir = await getTemporaryDirectory();
        final cacheFile = File('${cacheDir.path}/$fileName');
        
        // کپی فایل
        await File(filePath).copy(cacheFile.path);

        // برگرداندن URI فایل برای WebView
        return [cacheFile.uri.toString()];
      }

      return [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'خطا در انتخاب فایل: $e',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
          ),
        );
      }
      return [];
    }
  }

  /// بررسی می‌کند که آیا URL مجاز است یا نه
  /// فقط همان دامنه و scheme که در config.json تعریف شده مجاز است
  bool _isAllowed(Uri uri) {
    // اجازه به about:blank برای برخی فلوی انتخاب فایل
    if (uri.scheme == 'about' && uri.host.isEmpty) return true;
    // اجازه به data و blob برای داده‌های درون‌صفحه‌ای
    if (uri.scheme == 'data' || uri.scheme == 'blob') return true;
    // اجازه به file:// برای فایل‌های محلی (مثلاً فایل‌های انتخاب شده)
    if (uri.scheme == 'file') return true;
    
    if (uri.scheme != _allowedUri.scheme) return false;
    
    final allowedHost = _allowedUri.host; // مثلا nardeboun.ir
    if (uri.host == allowedHost) return true;
    if (uri.host.endsWith('.$allowedHost')) return true; // مثلا www.nardeboun.ir
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'گزارش خطا',
            style: TextStyle(
              fontFamily: 'IRANSansXFaNum',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF3629B7),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              } else {
                if (mounted) {
                  navigator.pop();
                }
              }
            },
            tooltip: 'بازگشت',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تازه‌سازی',
              onPressed: () {
                _controller.reload();
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'بستن',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
