import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../../utils/logger.dart';

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  Future<Directory> _getPdfCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  String _sanitizePath(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9._/-]'), '_');
  }

  Future<File> downloadAndCache(String remotePathOrUrl) async {
    // Notification permission is NOT required for caching/downloading PDF
    // so we do NOT request it here to avoid unnecessary prompts.

    final cacheDir = await _getPdfCacheDir();
    final fileName = _sanitizePath(remotePathOrUrl.split('/').last);
    final localPath = '${cacheDir.path}/$fileName';
    final file = File(localPath);
    if (await file.exists() && await file.length() > 0) {
      Logger.info('[PDF] Using cached file: $localPath');
      return file;
    }

    // فقط کش داخلی اپ برای خواندن (بدون DownloadManager)
    try {
      Logger.info('[PDF] Fallback HTTP download to cache...');
      Logger.info('[PDF] URL: $remotePathOrUrl');
      final resp = await _dio.get<List<int>>(
        remotePathOrUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      Logger.info('[PDF] HTTP status: ${resp.statusCode}');
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) throw Exception('Empty PDF download');
      await file.writeAsBytes(bytes, flush: true);
      final len = await file.length();
      Logger.info('[PDF] Cached file written: $localPath ($len bytes)');
      return file;
    } catch (e) {
      Logger.error('[PDF] Fallback download error', e);
      if (e.toString().contains('timeout')) {
        Logger.info('[PDF] Timeout error - check network connection');
      } else if (e.toString().contains('SocketException')) {
        Logger.info('[PDF] Network error - check internet connection');
      }
      rethrow;
    }
  }

  /// Force save to public Downloads via Android DownloadManager (no cache write)
  Future<void> downloadToDownloads(String remotePathOrUrl) async {
    if (!Platform.isAndroid) {
      Logger.info('[PDF] Download only supported on Android');
      throw Exception('دانلود فقط در اندروید پشتیبانی می‌شود');
    }

    // درخواست دسترسی به storage
    // در Android 13+ (API 33+) نیازی به storage permission نیست
    // در Android 10-12 باید از MANAGE_EXTERNAL_STORAGE استفاده کنیم
    // در Android 9 و پایین‌تر WRITE_EXTERNAL_STORAGE کافی است
    Logger.info('[PDF] Requesting storage permission...');
    var storageStatus = await Permission.storage.status;
    Logger.info('[PDF] Initial storage status: $storageStatus');

    if (!storageStatus.isGranted && !storageStatus.isLimited) {
      storageStatus = await Permission.storage.request();
      Logger.info('[PDF] After request storage status: $storageStatus');

      // اگر باز هم رد شد، از manageExternalStorage امتحان کن
      if (!storageStatus.isGranted) {
        Logger.info('[PDF] Trying manageExternalStorage...');
        final manageStatus = await Permission.manageExternalStorage.request();
        Logger.info('[PDF] ManageExternalStorage status: $manageStatus');
      }
    }

    // درخواست notification permission (فقط Android 13+)
    try {
      Logger.info('[PDF] Requesting notification permission...');
      final notifStatus = await Permission.notification.request();
      Logger.info('[PDF] Notification permission status: $notifStatus');
    } catch (e) {
      Logger.info('[PDF] Notification permission not available (Android < 13): $e');
    }

    final fileName = _sanitizePath(remotePathOrUrl.split('/').last);
    // Common downloads path on Android
    final downloadsDir = '/storage/emulated/0/Download';
    Logger.info(
      '[PDF] Force system download -> url=$remotePathOrUrl, savedDir=$downloadsDir, fileName=$fileName',
    );
    try {
      final taskId = await FlutterDownloader.enqueue(
        url: remotePathOrUrl,
        savedDir: downloadsDir,
        fileName: fileName,
        showNotification: true, // ✅ نمایش notification برای پیشرفت دانلود
        openFileFromNotification: true, // ✅ امکان باز کردن فایل از notification
        saveInPublicStorage: true,
      );
      Logger.info('[PDF] Downloader taskId=$taskId');
    } catch (e) {
      Logger.error('[PDF] downloadToDownloads error', e);
      rethrow;
    }
  }
}
