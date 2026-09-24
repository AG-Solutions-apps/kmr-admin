import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:krm_admin/models/news_model.dart';
import 'package:krm_admin/services/auth_service.dart';
import 'package:http_parser/http_parser.dart';

class NewsService {
  static const String baseUrl = 'https://kmrlive.in/public/api';
  final AuthService _authService = AuthService();

  /// Sanitizes text to convert unsupported/special Unicode characters and emojis
  /// into normal MySQL-safe text while preserving line breaks and paragraph formatting.
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

  // Fetch all news items
  Future<List<NewsModel>> fetchNewsList() async {
    try {
      String? token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/panel-fetch-news-list'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Fetch News List Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['news'] != null) {
          List<dynamic> newsJson = data['news'];
          List<NewsModel> newsList = [];
          for (var json in newsJson) {
            newsList.add(NewsModel.fromJson(json));
          }
          return newsList;
        }
      }
      return [];
    } catch (e) {
      print('Error fetching news list: $e');
      return [];
    }
  }

  // Create news (multipart)
  Future<Map<String, dynamic>> createNews({
    required String headlines,
    required String content,
    XFile? image,
  }) async {
    try {
      String? token = await _authService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-create-news'),
      );
      
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      final safeHeadlines = sanitizeText(headlines);
      final safeContent = sanitizeText(content);

      request.fields['news_headlines'] = safeHeadlines;
      request.fields['news_content'] = safeContent;

      if (image != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(image.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'news_image',
                  res.bodyBytes,
                  filename: 'upload.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
            }
          } catch (e) {
            print('Error loading web news image blob: $e');
          }
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'news_image',
              image.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Create News Response Status: ${response.statusCode}');
      print('Create News Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': data['code'] == 200 || data['status'] == 'success' || data['success'] == true,
          'message': data['msg'] ?? data['message'] ?? 'News created successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create news. Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error creating news: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Update news (multipart using _method=PUT)
  Future<Map<String, dynamic>> updateNews({
    required int id,
    required String headlines,
    required String content,
    required String status,
    XFile? image,
  }) async {
    try {
      String? token = await _authService.getToken();
      
      // Use Laravel _method override parameter
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-update-news/$id?_method=PUT'),
      );
      
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      final safeHeadlines = sanitizeText(headlines);
      final safeContent = sanitizeText(content);

      request.fields['news_headlines'] = safeHeadlines;
      request.fields['news_content'] = safeContent;
      request.fields['news_status'] = status;

      if (image != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(image.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'news_image',
                  res.bodyBytes,
                  filename: 'upload.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
            }
          } catch (e) {
            print('Error loading web news image blob: $e');
          }
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'news_image',
              image.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Update News Response Status: ${response.statusCode}');
      print('Update News Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': data['code'] == 200 || data['status'] == 'success' || data['success'] == true,
          'message': data['msg'] ?? data['message'] ?? 'News updated successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update news. Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error updating news: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}
