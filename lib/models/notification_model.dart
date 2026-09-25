class NotificationModel {
  final int id;
  final String notificationHeading;
  final String notificationDescription;
  final String? notificationImage;
  final String notificationStatus; // '1' or 'Active', '0' or 'Inactive'
  final String? createdAt;
  final String? updatedAt;

  NotificationModel({
    required this.id,
    required this.notificationHeading,
    required this.notificationDescription,
    this.notificationImage,
    required this.notificationStatus,
    this.createdAt,
    this.updatedAt,
  });

  static const String imageBaseUrl = 'https://kmrlive.in/public/assets/images/notification_images/';

  static String? formatImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    String fileName = trimmed;
    if (fileName.contains('/')) {
      fileName = fileName.split('/').last;
    }
    return '$imageBaseUrl$fileName';
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawImage = json['notification_image'] ?? json['image_url'] ?? json['image'];
    return NotificationModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      notificationHeading: json['notification_heading'] ?? json['heading'] ?? json['title'] ?? '',
      notificationDescription: json['notification_description'] ?? json['description'] ?? json['content'] ?? '',
      notificationImage: formatImageUrl(rawImage?.toString()),
      notificationStatus: (json['notification_status'] ?? json['status'] ?? '1').toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notification_heading': notificationHeading,
      'notification_description': notificationDescription,
      'notification_image': notificationImage,
      'notification_status': notificationStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isActive => notificationStatus == '1' || notificationStatus.toLowerCase() == 'active';
}
