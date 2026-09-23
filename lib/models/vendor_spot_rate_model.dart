class VendorSpotRateModel {
  final int id;
  final String vendorName;
  final int vendorId;
  final String vendorCategory;
  final String vendorSpotHeading;
  final String vendorSpotDetails;
  String vendorSpotStatus;
  final String vendorSpotCreatedDate;
  final String vendorSpotCreatedTime;

  VendorSpotRateModel({
    required this.id,
    required this.vendorName,
    required this.vendorId,
    required this.vendorCategory,
    required this.vendorSpotHeading,
    required this.vendorSpotDetails,
    required this.vendorSpotStatus,
    required this.vendorSpotCreatedDate,
    required this.vendorSpotCreatedTime,
  });

  factory VendorSpotRateModel.fromJson(Map<String, dynamic> json) {
    return VendorSpotRateModel(
      id: json['id'] is int 
          ? json['id'] 
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      vendorId: json['vendor_id'] is int 
          ? json['vendor_id'] 
          : int.tryParse(json['vendor_id']?.toString() ?? '') ?? 0,
      vendorName: json['vendor_name']?.toString() ?? '',
      vendorCategory: json['vendor_category']?.toString() ?? json['category']?.toString() ?? '',
      vendorSpotHeading: json['vendor_spot_heading']?.toString() ?? '',
      vendorSpotDetails: json['vendor_spot_details']?.toString() ?? '',
      vendorSpotStatus: json['vendor_spot_status']?.toString() ?? 'Active',
      vendorSpotCreatedDate: json['vendor_spot_created_date']?.toString() ?? '',
      vendorSpotCreatedTime: json['vendor_spot_created_time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'vendor_category': vendorCategory,
      'vendor_spot_heading': vendorSpotHeading,
      'vendor_spot_details': vendorSpotDetails,
      'vendor_spot_status': vendorSpotStatus,
      'vendor_spot_created_date': vendorSpotCreatedDate,
      'vendor_spot_created_time': vendorSpotCreatedTime,
    };
  }
}
