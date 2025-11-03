import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mini_request/mini_request_logger.dart';
import '../../services/mini_request/mini_request_service.dart';

/// پنل Debug برای نمایش لاگ‌های Mini-Request
class MiniRequestDebugPanel extends StatefulWidget {
  const MiniRequestDebugPanel({super.key});

  @override
  State<MiniRequestDebugPanel> createState() => _MiniRequestDebugPanelState();
}

class _MiniRequestDebugPanelState extends State<MiniRequestDebugPanel> {
  final _logger = MiniRequestLogger.instance;
  final _service = MiniRequestService.instance;
  List<String> _logs = [];
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _logs = _logger.getMemoryLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini-Request Debug Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh logs',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Card
          _buildStatsCard(),

          // Controls
          _buildControls(),

          // Logs List
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text('لاگی موجود نیست'))
                : ListView.builder(
                    reverse: _autoScroll,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return _buildLogItem(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'وضعیت: ${_service.currentState.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<double>(
              stream: _service.downloadProgress,
              builder: (context, snapshot) {
                final progress = snapshot.data ?? 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('پیشرفت: ${(progress * 100).toInt()}%'),
                    LinearProgressIndicator(value: progress),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text('تعداد لاگ‌ها: ${_logs.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _triggerManualRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('رفرش دستی'),
              ),
            ),
            const SizedBox(width: 8),
            Checkbox(
              value: _autoScroll,
              onChanged: (value) {
                setState(() {
                  _autoScroll = value ?? true;
                });
              },
            ),
            const Text('Auto scroll'),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(String log) {
    Color? backgroundColor;
    if (log.contains('❌') || log.contains('[ERROR]')) {
      backgroundColor = Colors.red.withValues(alpha: 0.1);
    } else if (log.contains('⚠️') || log.contains('[WARNING]')) {
      backgroundColor = Colors.orange.withValues(alpha: 0.1);
    } else if (log.contains('✅') || log.contains('[SUCCESS]')) {
      backgroundColor = Colors.green.withValues(alpha: 0.1);
    }

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SelectableText(
        log,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
    );
  }

  Future<void> _triggerManualRefresh() async {
    try {
      await _service.manualRefresh();
      _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ رفرش با موفقیت انجام شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ خطا: $e')));
      }
    }
  }

  Future<void> _copyLogs() async {
    final content = _logs.join('\n');
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('📋 لاگ‌ها کپی شدند')));
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'پاک کردن لاگ‌ها؟',
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
          content: const Text(
            'تمام لاگ‌ها به طور دائم حذف خواهند شد.',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'IRANSansXFaNum'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'لغو',
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'پاک کن',
                style: TextStyle(fontFamily: 'IRANSansXFaNum'),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _logger.clearLogs();
      _loadLogs();
    }
  }
}
