import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/network/network_error_model.dart';
import '../../models/network/network_status_model.dart';
import '../config/config_service.dart';
import '../../utils/logger.dart';

/// سرویس تشخیص وضعیت شبکه و اتصال
class NetworkMonitorService {
  static final NetworkMonitorService _instance =
      NetworkMonitorService._internal();
  factory NetworkMonitorService() => _instance;
  NetworkMonitorService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  NetworkStatusModel _currentStatus = NetworkStatusModel(
    status: NetworkStatus.unknown,
    lastChecked: DateTime.now(),
  );

  /// استریم وضعیت شبکه
  final StreamController<NetworkStatusModel> _statusController =
      StreamController<NetworkStatusModel>.broadcast();

  /// تایمر برای تاخیر اولیه چک connectivity
  Timer? _initialDelayTimer;

  /// آیا تاخیر اولیه تمام شده؟
  bool _initialDelayCompleted = false;

  /// آیا در حال انتظار برای تایمر قطع اتصال هستیم؟
  bool _isWaitingForDelayTimer = false;

  /// تایمر برای تاخیر قبل از نمایش پیام قطع اینترنت
  Timer? _disconnectDelayTimer;

  /// دریافت استریم وضعیت شبکه
  Stream<NetworkStatusModel> get statusStream => _statusController.stream;

  /// وضعیت فعلی شبکه
  NetworkStatusModel get currentStatus => _currentStatus;

  /// شروع نظارت بر شبکه
  Future<void> startMonitoring() async {
    try {
      Logger.info('🌐 NetworkMonitorService: Starting monitoring...');

      // دریافت تاخیر از config
      final delaySeconds =
          ConfigService.instance.getValue<int>('connectivityCheckDelay') ?? 10;
      Logger.info(
        '⏰ NetworkMonitorService: Initial delay set to $delaySeconds seconds',
      );

      // تنظیم تایمر تاخیر اولیه
      _initialDelayTimer = Timer(Duration(seconds: delaySeconds), () {
        Logger.info(
          '⏰ NetworkMonitorService: Initial delay completed, starting connectivity check',
        );
        _initialDelayCompleted = true;
        _checkInitialConnectivity();
      });

      // گوش دادن به تغییرات اتصال (اما فقط بعد از تاخیر اولیه)
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          Logger.error('❌ NetworkMonitorService: Connectivity error', error);
          if (_initialDelayCompleted) {
            _updateStatus(
              NetworkStatusModel(
                status: NetworkStatus.unknown,
                lastChecked: DateTime.now(),
              ),
            );
          }
        },
      );

      Logger.info(
        '✅ NetworkMonitorService: Monitoring started successfully with ${delaySeconds}s delay',
      );
    } catch (e) {
      Logger.error('❌ NetworkMonitorService: Failed to start monitoring', e);
      _updateStatus(
        NetworkStatusModel(
          status: NetworkStatus.unknown,
          lastChecked: DateTime.now(),
        ),
      );
    }
  }

  /// توقف نظارت بر شبکه
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _initialDelayTimer?.cancel();
    _initialDelayTimer = null;
  }

  /// بررسی اولیه وضعیت اتصال
  Future<void> _checkInitialConnectivity() async {
    try {
      Logger.info('🔍 NetworkMonitorService: Checking initial connectivity...');
      final result = await _connectivity.checkConnectivity();
      Logger.info(
        '🔍 NetworkMonitorService: Initial connectivity result: $result',
      );
      await _onConnectivityChanged(result);
    } catch (e) {
      Logger.error(
        '❌ NetworkMonitorService: Error in initial connectivity check',
        e,
      );
      _updateStatus(
        NetworkStatusModel(
          status: NetworkStatus.unknown,
          lastChecked: DateTime.now(),
        ),
      );
    }
  }

  /// پردازش تغییرات اتصال
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    try {
      Logger.info('🔄 NetworkMonitorService: Connectivity changed: $results');

      // اگر تاخیر اولیه تمام نشده، تغییرات اتصال را نادیده بگیر
      if (!_initialDelayCompleted) {
        Logger.info(
          '⏰ NetworkMonitorService: Ignoring connectivity change during initial delay',
        );
        return;
      }

      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (hasConnection) {
        // بررسی واقعی اتصال به اینترنت
        final hasInternet = await _hasInternetConnection();
        Logger.info('🌐 NetworkMonitorService: Has internet: $hasInternet');

        _updateStatus(
          NetworkStatusModel(
            status: hasInternet
                ? NetworkStatus.connected
                : NetworkStatus.disconnected,
            lastChecked: DateTime.now(),
            connectionType: _getConnectionType(results),
          ),
        );
      } else {
        Logger.info('❌ NetworkMonitorService: No connection detected');
        _updateStatus(
          NetworkStatusModel(
            status: NetworkStatus.disconnected,
            lastChecked: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      Logger.error('❌ NetworkMonitorService: Error processing connectivity', e);
      _updateStatus(
        NetworkStatusModel(
          status: NetworkStatus.unknown,
          lastChecked: DateTime.now(),
        ),
      );
    }
  }

  /// بررسی واقعی اتصال به اینترنت
  /// به جای DNS lookup از درخواست HTTP سبک استفاده می‌کنیم تا وضعیت واقعی اینترنت مشخص شود
  Future<bool> _hasInternetConnection() async {
    try {
      // استفاده از سرویس کمکی برای تست چند URL قابل اعتماد
      final hasInternet = await ConnectivityService()
          .testDefaultConnections()
          .timeout(const Duration(seconds: 4));
      return hasInternet;
    } catch (_) {
      return false;
    }
  }

  /// دریافت نوع اتصال
  String? _getConnectionType(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (results.contains(ConnectivityResult.mobile)) return 'Mobile';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    return null;
  }

  /// به‌روزرسانی وضعیت
  void _updateStatus(NetworkStatusModel status) {
    _currentStatus = status;

    // اگر وضعیت به disconnected تغییر کرد، تایمر تاخیر را شروع کن
    // فقط اگر initial delay تمام شده باشد (برای جلوگیری از فلش خطا در launch)
    if (status.status == NetworkStatus.disconnected) {
      if (_initialDelayCompleted) {
        _startDisconnectDelayTimer();
      }
    }
    // اگر وضعیت به connected تغییر کرد، تایمرها را لغو کن
    else if (status.status == NetworkStatus.connected) {
      _cancelDisconnectDelayTimer();
      _isWaitingForDelayTimer = false;
    }

    _statusController.add(status);
  }

  /// بررسی دستی وضعیت شبکه
  Future<bool> checkConnection() async {
    try {
      await _checkInitialConnectivity();
      return _currentStatus.isConnected;
    } catch (e) {
      return false;
    }
  }

  /// ایجاد خطای شبکه بر اساس وضعیت فعلی
  NetworkErrorModel createNetworkError({String? previousRoute}) {
    if (!_currentStatus.isConnected) {
      return NetworkErrorModel.noConnection(previousRoute: previousRoute);
    }
    return NetworkErrorModel.unknown(previousRoute: previousRoute);
  }

  /// شروع تایمر تاخیر قبل از نمایش پیام قطع اینترنت
  void _startDisconnectDelayTimer() {
    _cancelDisconnectDelayTimer();
    _isWaitingForDelayTimer = true; // شروع انتظار برای تایمر

    final delaySeconds =
        ConfigService.instance.networkErrorDelayAfterDisconnect;
    Logger.info(
      '⏰ NetworkMonitorService: Starting disconnect delay timer ($delaySeconds seconds)',
    );

    _disconnectDelayTimer = Timer(Duration(seconds: delaySeconds), () {
      Logger.info(
        '⏰ NetworkMonitorService: Disconnect delay completed, showing error screen',
      );
      _isWaitingForDelayTimer = false; // تایمر تمام شد
      _statusController.add(_currentStatus);
    });
  }

  /// لغو تایمر تاخیر قطع اینترنت
  void _cancelDisconnectDelayTimer() {
    _disconnectDelayTimer?.cancel();
    _disconnectDelayTimer = null;
  }

  /// آیا باید صفحه خطا نمایش داده شود؟
  bool get shouldShowErrorScreen =>
      !_currentStatus.isConnected &&
      !_isWaitingForDelayTimer && // نباید در حین انتظار برای تایمر باشیم
      _initialDelayCompleted;

  /// پاک کردن منابع
  void dispose() {
    stopMonitoring();
    _cancelDisconnectDelayTimer();
    _statusController.close();
  }
}

/// سرویس اتصال برای تست اتصال به سرورهای خاص
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  /// تست اتصال به یک URL خاص
  Future<bool> testConnection(String url) async {
    try {
      final uri = Uri.parse(url);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// تست اتصال به چندین URL
  Future<bool> testMultipleConnections(List<String> urls) async {
    for (final url in urls) {
      if (await testConnection(url)) {
        return true;
      }
    }
    return false;
  }

  /// تست اتصال به سرورهای پیش‌فرض
  Future<bool> testDefaultConnections() async {
    const defaultUrls = [
      'https://www.google.com',
      'https://www.cloudflare.com',
      'https://httpbin.org/status/200',
    ];
    return await testMultipleConnections(defaultUrls);
  }
}
