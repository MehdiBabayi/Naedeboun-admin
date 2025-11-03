/// مدل وضعیت شبکه
/// 
/// این فایل شامل مدل‌ها و enum های مربوط به وضعیت شبکه است
library;

/// وضعیت‌های مختلف شبکه
enum NetworkStatus {
  /// متصل به اینترنت
  connected,
  
  /// قطع اتصال
  disconnected,
  
  /// وضعیت نامشخص
  unknown,
}

/// مدل وضعیت شبکه
class NetworkStatusModel {
  /// وضعیت فعلی شبکه
  final NetworkStatus status;
  
  /// زمان آخرین بررسی
  final DateTime lastChecked;
  
  /// سرعت اتصال (اختیاری)
  final double? connectionSpeed;
  
  /// نوع اتصال (WiFi, Mobile, etc.)
  final String? connectionType;
  
  /// قدرت سیگنال (0-100)
  final int? signalStrength;
  
  /// آیا اتصال پایدار است؟
  final bool isStable;

  const NetworkStatusModel({
    required this.status,
    required this.lastChecked,
    this.connectionSpeed,
    this.connectionType,
    this.signalStrength,
    this.isStable = true,
  });

  /// سازنده پیش‌فرض برای وضعیت نامشخص
  factory NetworkStatusModel.unknown() {
    return NetworkStatusModel(
      status: NetworkStatus.unknown,
      lastChecked: DateTime.now(),
      isStable: false,
    );
  }

  /// سازنده برای وضعیت متصل
  factory NetworkStatusModel.connected({
    double? speed,
    String? type,
    int? signalStrength,
    bool isStable = true,
  }) {
    return NetworkStatusModel(
      status: NetworkStatus.connected,
      lastChecked: DateTime.now(),
      connectionSpeed: speed,
      connectionType: type,
      signalStrength: signalStrength,
      isStable: isStable,
    );
  }

  /// سازنده برای وضعیت قطع اتصال
  factory NetworkStatusModel.disconnected() {
    return NetworkStatusModel(
      status: NetworkStatus.disconnected,
      lastChecked: DateTime.now(),
      isStable: false,
    );
  }

  /// آیا به اینترنت متصل است؟
  bool get isConnected => status == NetworkStatus.connected;

  /// آیا اتصال قطع است؟
  bool get isDisconnected => status == NetworkStatus.disconnected;

  /// آیا وضعیت نامشخص است؟
  bool get isUnknown => status == NetworkStatus.unknown;

  /// آیا اتصال سریع است؟ (بیش از 1 مگابیت بر ثانیه)
  bool get isFastConnection => connectionSpeed != null && connectionSpeed! > 1.0;

  /// آیا اتصال کند است؟ (کمتر از 0.5 مگابیت بر ثانیه)
  bool get isSlowConnection => connectionSpeed != null && connectionSpeed! < 0.5;

  /// آیا سیگنال قوی است؟ (بیش از 70%)
  bool get hasStrongSignal => signalStrength != null && signalStrength! > 70;

  /// آیا سیگنال ضعیف است؟ (کمتر از 30%)
  bool get hasWeakSignal => signalStrength != null && signalStrength! < 30;

  /// تبدیل به Map
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'lastChecked': lastChecked.toIso8601String(),
      'connectionSpeed': connectionSpeed,
      'connectionType': connectionType,
      'signalStrength': signalStrength,
      'isStable': isStable,
    };
  }

  /// ساخت از Map
  factory NetworkStatusModel.fromMap(Map<String, dynamic> map) {
    return NetworkStatusModel(
      status: NetworkStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => NetworkStatus.unknown,
      ),
      lastChecked: DateTime.parse(map['lastChecked']),
      connectionSpeed: map['connectionSpeed']?.toDouble(),
      connectionType: map['connectionType'],
      signalStrength: map['signalStrength']?.toInt(),
      isStable: map['isStable'] ?? true,
    );
  }

  /// کپی با تغییرات
  NetworkStatusModel copyWith({
    NetworkStatus? status,
    DateTime? lastChecked,
    double? connectionSpeed,
    String? connectionType,
    int? signalStrength,
    bool? isStable,
  }) {
    return NetworkStatusModel(
      status: status ?? this.status,
      lastChecked: lastChecked ?? this.lastChecked,
      connectionSpeed: connectionSpeed ?? this.connectionSpeed,
      connectionType: connectionType ?? this.connectionType,
      signalStrength: signalStrength ?? this.signalStrength,
      isStable: isStable ?? this.isStable,
    );
  }

  /// به‌روزرسانی زمان آخرین بررسی
  NetworkStatusModel updateLastChecked() {
    return copyWith(lastChecked: DateTime.now());
  }

  @override
  String toString() {
    return 'NetworkStatusModel(status: $status, lastChecked: $lastChecked, connectionSpeed: $connectionSpeed, connectionType: $connectionType, signalStrength: $signalStrength, isStable: $isStable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is NetworkStatusModel &&
      other.status == status &&
      other.lastChecked == lastChecked &&
      other.connectionSpeed == connectionSpeed &&
      other.connectionType == connectionType &&
      other.signalStrength == signalStrength &&
      other.isStable == isStable;
  }

  @override
  int get hashCode {
    return status.hashCode ^
      lastChecked.hashCode ^
      connectionSpeed.hashCode ^
      connectionType.hashCode ^
      signalStrength.hashCode ^
      isStable.hashCode;
  }
}