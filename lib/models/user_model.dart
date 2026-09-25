class UserModel {
  final int id;
  final String name;
  final String mobile;
  final String email;
  final String? city;
  final String? vendorId;
  final int userType;
  final String status;
  final String? emailVerifiedAt;
  final String cpassword;
  final String token;
  final String deviceId;
  final String trail;
  final String registerDate;
  final String lastLogin;
  final String validityDate;
  final String? remarks;
  final String createdAt;
  final String? createdBy;
  final String updatedAt;
  final String? updatedBy;
  final String msg;

  UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    this.city,
    this.vendorId,
    required this.userType,
    required this.status,
    this.emailVerifiedAt,
    required this.cpassword,
    required this.token,
    required this.deviceId,
    required this.trail,
    required this.registerDate,
    required this.lastLogin,
    required this.validityDate,
    this.remarks,
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.updatedBy,
    required this.msg,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle both response formats
    Map<String, dynamic> userData = {};
    String token = '';
    
    if (json['UserInfo'] != null) {
      // New response format with UserInfo
      final userInfo = json['UserInfo'];
      userData = userInfo['user'] ?? {};
      token = userInfo['token'] ?? '';
    } else if (json['user'] != null) {
      // Old response format
      userData = json['user'];
      token = json['token'] ?? '';
    } else {
      // Direct user data
      userData = json;
      token = json['token'] ?? '';
    }
    
    int parsedUserType = 0;
    if (userData['user_type'] != null) {
      parsedUserType = int.tryParse(userData['user_type'].toString()) ?? 0;
    }

    return UserModel(
      id: userData['id'] ?? 0,
      name: userData['name'] ?? '',
      mobile: userData['mobile'] ?? '',
      email: userData['email'] ?? '',
      city: userData['city'],
      vendorId: userData['vendor_id']?.toString(),
      userType: parsedUserType,
      status: userData['status'] ?? '',
      emailVerifiedAt: userData['email_verified_at'],
      cpassword: userData['cpassword'] ?? '',
      token: token,
      deviceId: userData['device_id'] ?? '',
      trail: userData['trail'] ?? '',
      registerDate: userData['register_date'] ?? '',
      lastLogin: userData['last_login'] ?? '',
      validityDate: userData['validity_date'] ?? '',
      remarks: userData['remarks'],
      createdAt: userData['created_at'] ?? '',
      createdBy: userData['created_by']?.toString(),
      updatedAt: userData['updated_at'] ?? '',
      updatedBy: userData['updated_by']?.toString(),
      msg: json['msg'] ?? '',
    );
  }

  // Helper Role Check Getters
  // user_type 3 = Admin
  bool get isAdmin => userType == 3;
  // user_type 4 = Super Admin
  bool get isSuperAdmin => userType == 4;
  // Panel Access (Only 3 or 4 allowed)
  bool get hasAdminAccess => userType == 3 || userType == 4;

  Map<String, dynamic> toJson() {
    return {
      'user': {
        'id': id,
        'name': name,
        'mobile': mobile,
        'email': email,
        'city': city,
        'vendor_id': vendorId,
        'user_type': userType,
        'status': status,
        'email_verified_at': emailVerifiedAt,
        'cpassword': cpassword,
        'device_id': deviceId,
        'trail': trail,
        'register_date': registerDate,
        'last_login': lastLogin,
        'validity_date': validityDate,
        'remarks': remarks,
        'created_at': createdAt,
        'created_by': createdBy,
        'updated_at': updatedAt,
        'updated_by': updatedBy,
      },
      'token': token,
      'msg': msg,
    };
  }
}