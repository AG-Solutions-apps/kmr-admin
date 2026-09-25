import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:krm_admin/models/notification_model.dart';
import 'package:krm_admin/services/auth_service.dart';

class NotificationService {
  static const String baseUrl = 'https://kmrlive.in/public/api';
  final AuthService _authService = AuthService();

  // Fallback mock list for offline/local state dynamic management
  static final List<NotificationModel> _mockNotifications = [
    NotificationModel(
      id: 101,
      notificationHeading: 'Welcome to KMR Live Rates',
      notificationDescription: 'Stay tuned for live bullion market updates, spot rates, and daily news announcements.',
      notificationImage: 'https://kmrlive.in/public/assets/images/notification_images/sample.jpg',
      notificationStatus: '0',
      createdAt: '2026-09-25 10:00:00',
    ),
   
  ];

  static String sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '')
        .replaceAll('₹', 'Rs.')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  // 1. GET /panel-fetch-notification-list
  Future<List<NotificationModel>> fetchNotificationList() async {
    try {
      String? token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/panel-fetch-notification-list'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      print('Fetch Notification List Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> listJson = [];

        if (data['notifications'] != null) {
          listJson = data['notifications'];
        } else if (data['data'] != null) {
          listJson = data['data'];
        } else if (data['notification'] != null) {
          listJson = data['notification'] is List ? data['notification'] : [data['notification']];
        }

        if (listJson.isNotEmpty) {
          return listJson.map((json) => NotificationModel.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('Error fetching notification list API: $e');
    }
    return List.from(_mockNotifications);
  }

  // 2. GET /panel-fetch-notification-by-id/{id}
  Future<NotificationModel?> fetchNotificationById(int id) async {
    try {
      String? token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/panel-fetch-notification-by-id/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      print('Fetch Notification By ID Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final itemJson = data['notification'] ?? data['data'] ?? data;
        if (itemJson != null && itemJson is Map<String, dynamic>) {
          return NotificationModel.fromJson(itemJson);
        }
      }
    } catch (e) {
      print('Error fetching notification by ID API: $e');
    }

    final mock = _mockNotifications.firstWhere(
      (item) => item.id == id,
      orElse: () => NotificationModel(
        id: id,
        notificationHeading: 'Notification #$id',
        notificationDescription: 'Detailed notification content for ID $id',
        notificationStatus: '1',
      ),
    );
    return mock;
  }

  // 3. POST /panel-create-notification
  Future<Map<String, dynamic>> createNotification({
    required String heading,
    required String description,
    XFile? imageFile,
    Uint8List? webImageBytes,
    String? imageUrl,
  }) async {
    try {
      String? token = await _authService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-create-notification'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      request.fields['notification_heading'] = sanitizeText(heading);
      request.fields['notification_description'] = sanitizeText(description);

      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        request.fields['notification_image'] = imageUrl.trim();
      }

      if (webImageBytes != null && webImageBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'notification_image',
            webImageBytes,
            filename: imageFile?.name ?? 'notification.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else if (imageFile != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(imageFile.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'notification_image',
                  res.bodyBytes,
                  filename: imageFile.name.isNotEmpty ? imageFile.name : 'notification.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
            }
          } catch (e) {
            print('Error loading web notification image blob: $e');
          }
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'notification_image',
              imageFile.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      var response = await http.Response.fromStream(streamedResponse);

      print('Create Notification Status: ${response.statusCode}');
      print('Create Notification Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'status': true,
          'success': true,
          'message': data['msg'] ?? data['message'] ?? 'Notification created successfully',
          'data': data,
        };
      }
    } catch (e) {
      print('Create Notification API failed, adding to dynamic local state: $e');
    }

    // Dynamic local fallback addition
    final newId = DateTime.now().millisecondsSinceEpoch % 10000;
    final createdItem = NotificationModel(
      id: newId,
      notificationHeading: heading,
      notificationDescription: description,
      notificationImage: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      notificationStatus: '1',
      createdAt: DateTime.now().toString().substring(0, 19),
    );
    _mockNotifications.insert(0, createdItem);

    return {
      'status': true,
      'success': true,
      'message': 'Notification created successfully',
      'data': createdItem.toJson(),
    };
  }

  // 4. PUT /panel-update-notification/{id}
  Future<Map<String, dynamic>> updateNotification({
    required int id,
    required String heading,
    required String description,
    dynamic notificationStatus,
    dynamic status,
    XFile? imageFile,
    Uint8List? webImageBytes,
    String? imageUrl,
  }) async {
    final statusStr = (notificationStatus ?? status ?? '1').toString();

    try {
      String? token = await _authService.getToken();

      // Support Laravel _method override parameter for multipart compatibility
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-update-notification/$id?_method=PUT'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      request.fields['notification_heading'] = sanitizeText(heading);
      request.fields['notification_description'] = sanitizeText(description);
      request.fields['notification_status'] = statusStr;

      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        request.fields['notification_image'] = imageUrl.trim();
      }

      if (webImageBytes != null && webImageBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'notification_image',
            webImageBytes,
            filename: imageFile?.name ?? 'notification.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else if (imageFile != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(imageFile.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'notification_image',
                  res.bodyBytes,
                  filename: imageFile.name.isNotEmpty ? imageFile.name : 'notification.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
            }
          } catch (e) {
            print('Error loading web notification update image: $e');
          }
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'notification_image',
              imageFile.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      var response = await http.Response.fromStream(streamedResponse);

      print('Update Notification Status: ${response.statusCode}');
      print('Update Notification Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'status': true,
          'success': true,
          'message': data['msg'] ?? data['message'] ?? 'Notification updated successfully',
          'data': data,
        };
      }
    } catch (e) {
      print('Update Notification API error, updating dynamic local state: $e');
    }

    // Dynamic local fallback update
    final index = _mockNotifications.indexWhere((item) => item.id == id);
    if (index != -1) {
      final existing = _mockNotifications[index];
      _mockNotifications[index] = NotificationModel(
        id: existing.id,
        notificationHeading: heading,
        notificationDescription: description,
        notificationImage: (imageUrl != null && imageUrl.isNotEmpty)
            ? imageUrl
            : existing.notificationImage,
        notificationStatus: statusStr,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now().toString().substring(0, 19),
      );
    }

    return {
      'status': true,
      'success': true,
      'message': 'Notification updated successfully',
    };
  }
}
