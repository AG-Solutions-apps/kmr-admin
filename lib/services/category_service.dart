import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:krm_admin/models/category_model.dart';
import 'package:krm_admin/services/auth_service.dart';

class CategoryService {
  static const String baseUrl = 'https://kmrlive.in/public/api';
  final AuthService _authService = AuthService();

  // Fetch all categories
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      String? token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/panel-fetch-category-list'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Fetch Categories Response: ${response.statusCode}');
      print('Fetch Categories Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['category'] != null) {
          List<dynamic> categoriesJson = data['category'];
          return categoriesJson.map((json) => CategoryModel.fromJson(json)).toList();
        } else if (data['data'] != null) {
          List<dynamic> categoriesJson = data['data'];
          return categoriesJson.map((json) => CategoryModel.fromJson(json)).toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  // Create new category with image upload
  Future<Map<String, dynamic>> createCategory(String categoryName, File? imageFile) async {
    try {
      String? token = await _authService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-create-category'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // Add fields
      request.fields['category_name'] = categoryName.trim();

      // Add image if selected
      if (imageFile != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(imageFile.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'categories_images',
                  res.bodyBytes,
                  filename: 'upload.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
              print('Web image attached to category request, size: ${res.bodyBytes.length}');
            }
          } catch (e) {
            print('Error loading web image blob: $e');
          }
        } else if (await imageFile.exists()) {
          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          var multipartFile = http.MultipartFile(
            'categories_images',
            stream,
            length,
            filename: imageFile.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          );
          request.files.add(multipartFile);
          print('Image added to request: ${imageFile.path}');
        }
      }

      print('Create Category Request Fields: ${request.fields}');
      print('Create Category Request Files: ${request.files.length}');

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print('Create Category Response: ${response.statusCode}');
      print('Create Category Body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        return {
          'success': data['code'] == 200 || data['status'] == 'success',
          'message': data['msg'] ?? data['message'] ?? 'Category created successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create category. Please try again.',
        };
      }
    } catch (e) {
      print('Error creating category: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Update category with image upload using PUT method
  Future<Map<String, dynamic>> updateCategory(int id, String categoryName, File? imageFile, String status) async {
    try {
      String? token = await _authService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-update-category/$id?_method=PUT'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // Add fields
      request.fields['category_name'] = categoryName.trim();
      request.fields['category_status'] = status;

      // Add image if selected
      if (imageFile != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(imageFile.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'categories_images',
                  res.bodyBytes,
                  filename: 'upload.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
              print('Web image attached to category update request, size: ${res.bodyBytes.length}');
            }
          } catch (e) {
            print('Error loading web image blob: $e');
          }
        } else if (await imageFile.exists()) {
          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          var multipartFile = http.MultipartFile(
            'categories_images',
            stream,
            length,
            filename: imageFile.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          );
          request.files.add(multipartFile);
          print('Image added to update request: ${imageFile.path}');
        }
      }

      print('Update Category Request Fields: ${request.fields}');
      print('Update Category Request Files: ${request.files.length}');

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print('Update Category Response: ${response.statusCode}');
      print('Update Category Body: $responseBody');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        return {
          'success': data['code'] == 200 || data['status'] == 'success',
          'message': data['msg'] ?? data['message'] ?? 'Category updated successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update category. Please try again.',
        };
      }
    } catch (e) {
      print('Error updating category: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Delete category
  Future<Map<String, dynamic>> deleteCategory(int id) async {
    try {
      String? token = await _authService.getToken();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/panel-delete-category/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Delete Category Response: ${response.statusCode}');
      print('Delete Category Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': data['code'] == 200 || data['status'] == 'success',
          'message': data['msg'] ?? data['message'] ?? 'Category deleted successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to delete category. Please try again.',
        };
      }
    } catch (e) {
      print('Error deleting category: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}