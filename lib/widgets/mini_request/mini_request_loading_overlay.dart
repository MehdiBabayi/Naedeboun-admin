import 'package:flutter/material.dart';
import '../../services/mini_request/mini_request_service.dart';
import '../../models/mini_request/mini_request_state.dart';

/// Overlay برای نمایش وضعیت دانلود Mini-Request
class MiniRequestLoadingOverlay extends StatelessWidget {
  final Widget child;

  const MiniRequestLoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MiniRequestState>(
      stream: MiniRequestService.instance.state,
      initialData: MiniRequestService.instance.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? MiniRequestState.idle;

        return Stack(
          children: [
            child,
            if (state == MiniRequestState.downloading ||
                state == MiniRequestState.storing)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            state == MiniRequestState.downloading
                                ? 'در حال دانلود محتوا...'
                                : 'در حال ذخیره‌سازی...',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<double>(
                            stream:
                                MiniRequestService.instance.downloadProgress,
                            builder: (context, progressSnapshot) {
                              final progress = progressSnapshot.data ?? 0.0;
                              return Column(
                                children: [
                                  LinearProgressIndicator(value: progress),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
