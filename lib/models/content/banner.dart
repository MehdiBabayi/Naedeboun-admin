import '../../utils/logger.dart';

class AppBanner {
  final int id;
  final String title;
  final String description;
  final String imageUrl;
  final int? videoId;
  final int gradeId;
  final int? trackId;
  final String? targetUrl;
  final int displayOrder;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String bannerType; // جدید - 'internal' یا 'external'
  final String? externalUrl; // جدید - URL خارجی

  AppBanner({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.videoId,
    required this.gradeId,
    this.trackId,
    this.targetUrl,
    required this.displayOrder,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.bannerType = 'internal', // پیش‌فرض
    this.externalUrl,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    Logger.debug(
      '🔍 [BANNER-MODEL] Parsing banner: id=${json['id']}, type=${json['banner_type'] ?? 'internal'}, videoId=${json['video_id']}, externalUrl=${json['external_url']}',
    );

    return AppBanner(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String,
      videoId: json['video_id'] as int?,
      gradeId: json['grade_id'] as int,
      trackId: json['track_id'] as int?,
      targetUrl: json['target_url'] as String?,
      displayOrder: json['display_order'] as int,
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      bannerType: json['banner_type'] as String? ?? 'internal', // جدید
      externalUrl: json['external_url'] as String?, // جدید
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'video_id': videoId,
      'grade_id': gradeId,
      'track_id': trackId,
      'target_url': targetUrl,
      'display_order': displayOrder,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'banner_type': bannerType, // جدید
      'external_url': externalUrl, // جدید
    };
  }
}
