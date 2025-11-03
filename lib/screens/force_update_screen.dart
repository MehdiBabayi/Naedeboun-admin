import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _launchStore() async {
    final String url = Platform.isAndroid
        ? 'https://play.google.com/store/apps/details?id=com.example.nardeboun' // Google Play
        : 'https://apps.apple.com/app/your-app-id'; // App Store

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Handle error, e.g., show a snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 80,
                color: const Color(0xFF3629B7),
              ),
              const SizedBox(height: 24),
              Text(
                'نسخه جدید رسید',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'IRANSansXFaNum',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'برای ادامه استفاده از نردبون و دسترسی به آخرین امکانات، لطفاً برنامه را به آخرین نسخه بروزرسانی کنید.',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'IRANSansXFaNum',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _launchStore,
                icon: const Icon(Icons.download_for_offline_rounded),
                label: const Text(
                  'بروزرسانی',
                  style: TextStyle(fontFamily: 'IRANSansXFaNum'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3629B7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
