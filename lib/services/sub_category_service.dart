import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:krm_admin/models/sub_category_model.dart';
import 'package:krm_admin/models/category_dropdown_model.dart';
import 'package:krm_admin/services/auth_service.dart';

class SubCategoryService {
  static const String baseUrl = 'https://kmrlive.in/public/api';
  final AuthService _authService = AuthService();

  // Fetch all sub-categories
  Future<List<SubCategoryModel>> fetchSubCategories() async {
    try {
      String? token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/panel-fetch-sub-category-list'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Fetch SubCategories Response: ${response.statusCode}');
      print('Fetch SubCategories Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Check for 'categorySub' key (from your API response)
        if (data['categorySub'] != null) {
          List<dynamic> subCategoriesJson = data['categorySub'];
          print('Found ${subCategoriesJson.length} sub-categories in categorySub');
          
          // Properly map the list
          List<SubCategoryModel> subCategories = [];
          for (var json in subCategoriesJson) {
            subCategories.add(SubCategoryModel.fromJson(json));
          }
          return subCategories;
        } 
        // Fallback for 'data' key
        else if (data['data'] != null) {
          List<dynamic> subCategoriesJson = data['data'];
          print('Found ${subCategoriesJson.length} sub-categories in data');
          
          List<SubCategoryModel> subCategories = [];
          for (var json in subCategoriesJson) {
            subCategories.add(SubCategoryModel.fromJson(json));
          }
          return subCategories;
        } 
        else {
          print('No sub-categories found in response');
          return [];
        }
      } else {
        print('Failed to fetch sub-categories: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching sub-categories: $e');
      return [];
    }
  }

  // Fetch categories for dropdown
  Future<List<CategoryDropdownModel>> fetchCategories() async {
    try {
      String? token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/panel-fetch-category'),
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
          List<CategoryDropdownModel> categories = [];
          for (var json in categoriesJson) {
            categories.add(CategoryDropdownModel.fromJson(json));
          }
          return categories;
        } else if (data['data'] != null) {
          List<dynamic> categoriesJson = data['data'];
          List<CategoryDropdownModel> categories = [];
          for (var json in categoriesJson) {
            categories.add(CategoryDropdownModel.fromJson(json));
          }
          return categories;
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

  // Create new sub-category with image upload
  Future<Map<String, dynamic>> createSubCategory(
    int categoryId,
    String subCategoryName,
    File? imageFile,
  ) async {
    try {
      String? token = await _authService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-create-sub-category'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields['category_id'] = categoryId.toString();
      request.fields['category_sub_name'] = subCategoryName.trim();

      if (imageFile != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(imageFile.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'categories_sub_images',
                  res.bodyBytes,
                  filename: 'upload.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
              print('Web image attached to sub-category request, size: ${res.bodyBytes.length}');
            }
          } catch (e) {
            print('Error loading web image blob: $e');
          }
        } else if (await imageFile.exists()) {
          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          var multipartFile = http.MultipartFile(
            'categories_sub_images',
            stream,
            length,
            filename: imageFile.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          );
          request.files.add(multipartFile);
          print('Image added to request: ${imageFile.path}');
        }
      }

      print('Create SubCategory Request Fields: ${request.fields}');
      print('Create SubCategory Request Files: ${request.files.length}');

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print('Create SubCategory Response: ${response.statusCode}');
      print('Create SubCategory Body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        return {
          'success': data['code'] == 200 || data['status'] == 'success' || data['success'] == true,
          'message': data['msg'] ?? data['message'] ?? 'Sub-category created successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create sub-category. Please try again.',
        };
      }
    } catch (e) {
      print('Error creating sub-category: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Update sub-category with image upload using PUT method
  Future<Map<String, dynamic>> updateSubCategory(
    int id,
    int categoryId,
    String subCategoryName,
    File? imageFile,
    String status,
  ) async {
    try {
      String? token = await _authService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/panel-update-sub-category/$id?_method=PUT'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields['category_id'] = categoryId.toString();
      request.fields['category_sub_name'] = subCategoryName.trim();
      request.fields['category_sub_status'] = status;

      if (imageFile != null) {
        if (kIsWeb) {
          try {
            final res = await http.get(Uri.parse(imageFile.path));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'categories_sub_images',
                  res.bodyBytes,
                  filename: 'upload.jpg',
                  contentType: MediaType('image', 'jpeg'),
                ),
              );
              print('Web image attached to sub-category update request, size: ${res.bodyBytes.length}');
            }
          } catch (e) {
            print('Error loading web image blob: $e');
          }
        } else if (await imageFile.exists()) {
          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          var multipartFile = http.MultipartFile(
            'categories_sub_images',
            stream,
            length,
            filename: imageFile.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          );
          request.files.add(multipartFile);
          print('Image added to update request: ${imageFile.path}');
        }
      }

      print('Update SubCategory Request Fields: ${request.fields}');
      print('Update SubCategory Request Files: ${request.files.length}');

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print('Update SubCategory Response: ${response.statusCode}');
      print('Update SubCategory Body: $responseBody');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        return {
          'success': data['code'] == 200 || data['status'] == 'success' || data['success'] == true,
          'message': data['msg'] ?? data['message'] ?? 'Sub-category updated successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update sub-category. Please try again.',
        };
      }
    } catch (e) {
      print('Error updating sub-category: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}