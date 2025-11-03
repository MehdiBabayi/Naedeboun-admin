import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/image_cache/smart_image_cache_service.dart';
import '../../models/content/banner.dart';

/// 🎨 Widget برای نمایش Banner با Progressive Loading
class CachedBanner extends StatefulWidget {
  final AppBanner banner;
  final VoidCallback? onTap;

  const CachedBanner({super.key, required this.banner, this.onTap});

  @override
  State<CachedBanner> createState() => _CachedBannerState();
}

class _CachedBannerState extends State<CachedBanner> {
  Image? _image;
  Timer? _retryTimer;
  int _retries = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final bytes = await SmartImageCacheService.instance.getBanner(
      widget.banner.id,
      widget.banner.imageUrl,
    );

    if (mounted) {
      if (bytes != null) {
        setState(
          () => _image = Image.memory(bytes, alignment: Alignment.center),
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.hardEdge,
          child: _image != null
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    alignment: Alignment.center,
                    child: _image!,
                  ),
                )
              : Center(
                  child: Icon(Icons.image, size: 48, color: Colors.grey[400]),
                ),
        ),
      ),
    );
  }
}
