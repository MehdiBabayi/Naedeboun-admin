import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/image_cache/smart_image_cache_service.dart';
import '../../utils/logger.dart';

/// 📚 Widget برای نمایش Book Cover با Progressive Loading
class CachedBookCover extends StatefulWidget {
  final String imageUrl; // URL کامل عکس
  final Widget placeholder;

  const CachedBookCover({
    super.key,
    required this.imageUrl,
    required this.placeholder,
  });

  @override
  State<CachedBookCover> createState() => _CachedBookCoverState();
}

class _CachedBookCoverState extends State<CachedBookCover> {
  Image? _image;
  Timer? _retryTimer;
  int _retries = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // 1) تلاش همزمان برای خواندن از Hive قبل از اولین فریم
    final bytes =
        SmartImageCacheService.instance.peekBookCoverFromUrl(widget.imageUrl);
    if (bytes != null) {
      final imageKey = ValueKey('book_cover_${widget.imageUrl.hashCode}');
      // بدون setState: قبل از اولین build هست، از چشمک placeholder جلوگیری می‌کند
      _image = Image.memory(
        bytes,
        key: imageKey,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('❌ [CACHED-BOOK-COVER] Image decode error', error);
          return widget.placeholder;
        },
      );
    }

    // 2) مسیر معمول async برای حالت miss
    _load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    // پاک کردن image از memory برای جلوگیری از leak
    _image = null;
    super.dispose();
  }

  Future<void> _load() async {
    final bytes = await SmartImageCacheService.instance.getBookCoverFromUrl(
      widget.imageUrl,
    );

    if (mounted) {
      if (bytes != null) {
        // استفاده از key منحصر به فرد برای جلوگیری از buffer leak
        final imageKey = ValueKey('book_cover_${widget.imageUrl.hashCode}');
        setState(
          () => _image = Image.memory(
            bytes,
            key: imageKey,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            // محدود کردن decode size برای کاهش memory usage
            errorBuilder: (context, error, stackTrace) {
              Logger.error('❌ [CACHED-BOOK-COVER] Image decode error', error);
              return widget.placeholder;
            },
          ),
        );
      } else if (_retries < _maxRetries) {
        _retries++;
        // کاهش زمان retry برای سرعت بیشتر
        _retryTimer = Timer(Duration(milliseconds: 500 * _retries), () {
          if (mounted) _load();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _image ?? widget.placeholder;
  }
}
