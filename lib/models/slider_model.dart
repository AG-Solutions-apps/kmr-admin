class SliderModel {
  final int id;
  final String? sliderUrl;
  final String? sliderType;
  final String? sliderCategory;
  final String? sliderImages;
  final dynamic sliderStatus; // 1 or '1' for active, 0 or '0' for inactive
  final String? createdAt;
  final String? updatedAt;

  SliderModel({
    required this.id,
    this.sliderUrl,
    this.sliderType,
    this.sliderCategory,
    this.sliderImages,
    required this.sliderStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory SliderModel.fromJson(Map<String, dynamic> json) {
    return SliderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      sliderUrl: json['slider_url'] ?? json['target_url'] ?? json['url'],
      sliderType: json['slider_type'] ?? json['type'] ?? 'Banner',
      sliderCategory: json['slider_category'] ?? json['category'] ?? 'General',
      sliderImages: json['slider_images'] ?? json['slider_image'] ?? json['image'] ?? json['image_url'],
      sliderStatus: json['slider_status'] ?? json['status'] ?? 1,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slider_url': sliderUrl,
      'slider_type': sliderType,
      'slider_category': sliderCategory,
      'slider_images': sliderImages,
      'slider_status': sliderStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isActive => sliderStatus.toString() == '1' || sliderStatus == 1 || sliderStatus == true;

  String? get formattedImageUrl {
    if (sliderImages == null || sliderImages!.trim().isEmpty) {
      return null;
    }
    final img = sliderImages!.trim();
    if (img.startsWith('http://') || img.startsWith('https://') || img.startsWith('blob:')) {
      return img;
    }
    return 'https://kmrlive.in/public/assets/images/slider_images/$img';
  }
}
