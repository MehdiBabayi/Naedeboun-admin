import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Custom scroll physics با شدت کم برای PDF
class GentleBouncingScrollPhysics extends BouncingScrollPhysics {
  const GentleBouncingScrollPhysics({super.parent});

  @override
  GentleBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return GentleBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // کاهش شدت bounce با ضریب 0.3
    return super.applyPhysicsToUserOffset(position, offset * 0.3);
  }
}

/// 📄 PDF Reader با pdfrx - تنها راه برای scroll physics کامل!
class PdfReaderScreenPdfx extends StatefulWidget {
  final File file;
  const PdfReaderScreenPdfx({super.key, required this.file});

  @override
  State<PdfReaderScreenPdfx> createState() => _PdfReaderScreenPdfxState();
}

class _PdfReaderScreenPdfxState extends State<PdfReaderScreenPdfx> {
  final _controller = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'نمایش PDF',
          style: TextStyle(fontFamily: 'IRANSansXFaNum'),
        ),
      ),
      body: PdfViewer.file(
        widget.file.path,
        controller: _controller,
        params: PdfViewerParams(
          // 🚀 کلید طلایی: scroll physics ملایم!
          scrollPhysics: const GentleBouncingScrollPhysics(),

          // Zoom
          maxScale: 3.0,
          minScale: 0.5,

          // Loading
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    totalBytes != null
                        ? 'بارگذاری: ${(bytesDownloaded / totalBytes * 100).toStringAsFixed(0)}%'
                        : 'در حال بارگذاری...',
                    style: const TextStyle(
                      fontFamily: 'IRANSansXFaNum',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },

          // Error
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'خطا در بارگذاری PDF',
                      style: TextStyle(
                        fontFamily: 'IRANSansXFaNum',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                        fontFamily: 'IRANSansXFaNum',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'بازگشت',
                        style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 🚀 Ultra Fling Scroll Physics - 15x momentum!
class UltraFlingScrollPhysics extends BouncingScrollPhysics {
  const UltraFlingScrollPhysics({super.parent});

  @override
  UltraFlingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return UltraFlingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double carriedMomentum(double existingVelocity) {
    return super.carriedMomentum(existingVelocity) * 15.0; // 🔥
  }

  @override
  double get minFlingVelocity => 3.0;

  @override
  double get maxFlingVelocity => 100000.0;

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.05,
    stiffness: 30.0,
    ratio: 0.1,
  );

  @override
  double get dragStartDistanceMotionThreshold => 2.0;
}
