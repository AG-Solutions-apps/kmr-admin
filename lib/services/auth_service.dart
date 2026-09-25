import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krm_admin/models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://kmrlive.in/public/api';
  static const String _tokenKey = 'auth_token';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _deviceIdKey = 'device_id';

  // Generate and persist a unique device ID
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(99999);
      deviceId = 'krm_${timestamp}_${random.toString().padLeft(5, '0')}';
      await prefs.setString(_deviceIdKey, deviceId);
      print('Generated new Device ID: $deviceId');
    } else {
      print('Using existing Device ID: $deviceId');
    }
    
    return deviceId;
  }

  // Login API call with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      String deviceId = await _getDeviceId();
      
      final requestBody = {
        'username': username.trim(),
        'password': password.trim(),
        'device_id': deviceId,
      };
      
      print('Login Request: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/panel-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Check if login was successful - response has code: 200 and UserInfo
        if (data['code'] == 200 && data['UserInfo'] != null) {
          final userInfo = data['UserInfo'];
          final user = userInfo['user'] ?? {}; // User data is nested inside UserInfo
          final token = userInfo['token'] ?? '';
          
          final int userType = int.tryParse((user['user_type'] ?? 0).toString()) ?? 0;
          
          // Access Control:
          // user_type == 1 or 2 => Block login ("Access denied, you cannot login here.")
          // user_type == 3 => Admin (Allowed)
          // user_type == 4 => Super Admin (Allowed)
          if (userType == 1 || userType == 2) {
            return {
              'success': false,
              'message': 'Access denied, you cannot login here.',
            };
          }

          if (userType != 3 && userType != 4) {
            return {
              'success': false,
              'message': 'Access denied, you cannot login here.',
            };
          }

          // Save user data and token only if Admin or Super Admin
          await _saveUserData(data);
          
          // Extract user info from response
          final userName = user['name'] ?? username;
          final userEmail = user['email'] ?? '';
          
          return {
            'success': true,
            'data': data,
            'user': {
              'name': userName,
              'email': userEmail,
              'mobile': user['mobile'] ?? '',
              'userType': userType,
              'status': user['status'] ?? '',
              'deviceId': user['device_id'] ?? deviceId,
              'id': user['id'] ?? 0,
              'token': token,
            },
            'message': 'Login successful',
          };
        } else {
          return {
            'success': false,
            'message': data['msg'] ?? 'Invalid username or password. Please try again.',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Login Error: $e');
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server. Please check your internet connection.',
      };
    }
  }

  // Save user data to SharedPreferences
  Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final userInfo = data['UserInfo'] ?? {};
    await prefs.setString(_tokenKey, userInfo['token'] ?? '');
    await prefs.setString(_userDataKey, jsonEncode(data));
    await prefs.setBool(_isLoggedInKey, true);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool loggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      if (!loggedIn) return false;

      final user = await getUserData();
      if (user == null || !user.hasAdminAccess) {
        await logout();
        return false;
      }
      return true;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  // Get user data
  Future<UserModel?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? userDataString = prefs.getString(_userDataKey);
    
    if (userDataString != null) {
      try {
        Map<String, dynamic> userData = jsonDecode(userDataString);
        return UserModel.fromJson(userData);
      } catch (e) {
        print('Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }

  // Get auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get device ID
  Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  // Fetch user profile from API
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/panel-fetch-profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      print('Profile response status: ${response.statusCode}');
      print('Profile response body: ${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Fetch profile error: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);
      await prefs.setBool(_isLoggedInKey, false);
      print('Logged out successfully');
    } catch (e) {
      print('Error during logout: $e');
    }
  }
}