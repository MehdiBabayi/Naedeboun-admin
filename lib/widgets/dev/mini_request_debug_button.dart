import 'package:flutter/material.dart';
import '../../services/mini_request/mini_request_service.dart';

/// دکمه Debug برای تست دستی Mini-Request
class MiniRequestDebugButton extends StatelessWidget {
  const MiniRequestDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🔄 Mini-Request در حال اجرا...',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'IRANSansXFaNum'),
            ),
            duration: Duration(seconds: 2),
          ),
        );

        try {
          await MiniRequestService.instance.manualRefresh();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '✅ Mini-Request تکمیل شد!',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '❌ خطا: $e',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'IRANSansXFaNum'),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('🔄 Mini-Request Refresh'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
