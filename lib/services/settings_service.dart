import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class VersionCheckResult {
  final bool forceUpdate;
  final String currentVersion;
  final String minimumVersion;

  VersionCheckResult({
    required this.forceUpdate,
    required this.currentVersion,
    required this.minimumVersion,
  });
}

class SettingsService {
  SettingsService._();
  static final instance = SettingsService._();

  late final Box _settingsBox;
  static const String _boxName = 'settings';
  static const String _minVersionKey = 'minimum_version';

  Future<void> init() async {
    _settingsBox = await Hive.openBox(_boxName);
    Logger.info(' Hive settings box initialized.');
  }

  Future<String> _getCurrentAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<String> _fetchMinimumVersionFromSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('settings')
          .select('value')
          .eq('key', _minVersionKey)
          .single();

      final minVersion = response['value'] as String;
      await _settingsBox.put(_minVersionKey, minVersion);
      Logger.info(
        ' Fetched and cached minimum version from Supabase: $minVersion',
      );
      return minVersion;
    } catch (e) {
      Logger.error(' Error fetching minimum version from Supabase: $e');
      throw Exception('Could not fetch remote settings.');
    }
  }

  String _getMinimumVersionFromCache() {
    return _settingsBox.get(_minVersionKey, defaultValue: '1.0.0') as String;
  }

  // Simple version comparison without external package
  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    final maxLength = v1Parts.length > v2Parts.length
        ? v1Parts.length
        : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }

    return 0;
  }

  Future<VersionCheckResult> checkVersion() async {
    final currentVersionStr = await _getCurrentAppVersion();
    String minimumVersionStr;

    try {
      minimumVersionStr = await _fetchMinimumVersionFromSupabase();
    } catch (e) {
      minimumVersionStr = _getMinimumVersionFromCache();
      Logger.info(
        ' Could not fetch from Supabase. Using cached minimum version: $minimumVersionStr',
      );
    }

    final bool needsUpdate =
        _compareVersions(currentVersionStr, minimumVersionStr) < 0;

    Logger.info(
      ' Version Check: Current=$currentVersionStr, Minimum=$minimumVersionStr, ForceUpdate=$needsUpdate',
    );

    return VersionCheckResult(
      forceUpdate: needsUpdate,
      currentVersion: currentVersionStr,
      minimumVersion: minimumVersionStr,
    );
  }
}
