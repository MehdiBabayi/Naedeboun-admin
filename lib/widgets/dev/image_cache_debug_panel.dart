import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/image_cache/smart_image_cache_service.dart';

/// 🐛 Debug Panel برای Image Cache
class ImageCacheDebugPanel extends StatefulWidget {
  const ImageCacheDebugPanel({super.key});

  @override
  State<ImageCacheDebugPanel> createState() => _ImageCacheDebugPanelState();
}

class _ImageCacheDebugPanelState extends State<ImageCacheDebugPanel> {
  double _cacheSize = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final size = await SmartImageCacheService.instance.getCacheSizeMB();
    if (mounted) {
      setState(() {
        _cacheSize = size;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 Image Cache Debug'),
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '📸 Smart Image Cache System',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سیستم کش هوشمند برای Book Covers و Banners',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage, color: Colors.blue),
              title: const Text('حجم کش'),
              subtitle: _loading
                  ? const Text('در حال محاسبه...')
                  : Text(
                      '${_cacheSize.toStringAsFixed(2)} MB',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadStats,
                tooltip: 'بروزرسانی',
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ℹ️ اطلاعات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Book Covers: از Remote Server (CDN)'),
                  Text('• Banners: از Supabase Storage'),
                  Text('• یکبار دانلود، همیشه کش'),
                  Text('• Offline Support: ✅'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          const Text(
            'عملیات:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          title: const Text(
                            '⚠️ هشدار',
                            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                          ),
                          content: const Text(
                            'همه تصاویر کش شده پاک میشن!\nمطمئنی؟',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                'لغو',
                                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'بله، پاک کن',
                                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (confirm == true) {
                      await SmartImageCacheService.instance.clearAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✅ کش پاک شد',
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadStats();
                      }
                    }
                  },
            icon: const Icon(Icons.delete_forever),
            label: const Text('پاک کردن کامل کش'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),

          const SizedBox(height: 12),

          // پاک کردن Hive Cache
          ElevatedButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          title: const Text(
                            '⚠️ هشدار',
                            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                          ),
                          content: const Text(
                            'همه داده‌های کش شده (Subjects, Chapters, etc.) پاک میشن!\nمطمئنی؟',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                'لغو',
                                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'بله، پاک کن',
                                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (confirm == true) {
                      try {
                        // پاک کردن تمام Hive boxes
                        final boxes = Hive.box('app_cache');
                        await boxes.clear();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✅ Hive Cache پاک شد',
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('❌ خطا: $e')));
                        }
                      }
                    }
                  },
            icon: const Icon(Icons.storage),
            label: const Text('پاک کردن Hive Cache'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),

          const SizedBox(height: 24),

          // Guide
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '💡 راهنما:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. اولین بار: Placeholder → دانلود → نمایش'),
                  Text('2. بار دوم: فوری از Hive (0.01s)'),
                  Text('3. Offline: همه چیز کار می‌کنه'),
                  SizedBox(height: 8),
                  Text(
                    '📊 Logs رو در Console چک کن:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('  ✅ Banner hit: X'),
                  Text('  ⚠️ Banner miss: X'),
                  Text('  ⬇️ Downloading banner X'),
                  Text('  ✅ Banner cached: X (bytes)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
