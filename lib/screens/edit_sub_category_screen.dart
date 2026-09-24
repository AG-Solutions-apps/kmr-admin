import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krm_admin/models/category_dropdown_model.dart';
import 'package:krm_admin/services/sub_category_service.dart';

class EditSubCategoryScreen extends StatefulWidget {
  final int subCategoryId;
  final String categoryName;
  final String subCategoryName;
  final String? subCategoryImage;
  final String subCategoryStatus;

  const EditSubCategoryScreen({
    super.key,
    required this.subCategoryId,
    required this.categoryName,
    required this.subCategoryName,
    this.subCategoryImage,
    required this.subCategoryStatus,
  });

  @override
  State<EditSubCategoryScreen> createState() => _EditSubCategoryScreenState();
}

class _EditSubCategoryScreenState extends State<EditSubCategoryScreen> {
  final SubCategoryService _subCategoryService = SubCategoryService();
  final TextEditingController _subCategoryNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<CategoryDropdownModel> _categories = [];
  int? _selectedCategoryId;
  File? _selectedImage;
  String _selectedStatus = 'Active';
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  String? _errorMessage;
  bool _isImageChanged = false;

  // Updated Base URL for sub-category images
  static const String imageBaseUrl = 'https://kmrlive.in/public/assets/images/sub_categories_images/';

  @override
  void initState() {
    super.initState();
    _subCategoryNameController.text = widget.subCategoryName;
    _selectedStatus = (widget.subCategoryStatus == 'Active' || widget.subCategoryStatus == 'Inactive')
        ? widget.subCategoryStatus
        : 'Active';
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    final categories = await _subCategoryService.fetchCategories();
    
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
      
      if (categories.isNotEmpty) {
        final matchedCategory = categories.firstWhere(
          (c) => c.categoryName.trim().toLowerCase() == widget.categoryName.trim().toLowerCase(),
          orElse: () => categories.first,
        );
        _selectedCategoryId = matchedCategory.id;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isImageChanged = true;
        });
        print('Image selected: ${image.path}');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateSubCategory() async {
    if (_selectedCategoryId == null) {
      setState(() {
        _errorMessage = 'Please select a category';
      });
      return;
    }

    if (_subCategoryNameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter sub-category name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _subCategoryService.updateSubCategory(
      widget.subCategoryId,
      _selectedCategoryId!,
      _subCategoryNameController.text,
      _isImageChanged ? _selectedImage : null,
      _selectedStatus,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        title: const Text(
          'Edit Sub-Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Category Selection Field
                    const Row(
                      children: [
                        Icon(Icons.list_alt_rounded, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Parent Category *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isLoadingCategories
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C3CE1)),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedCategoryId,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                                iconSize: 28,
                                elevation: 16,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                onChanged: (int? newValue) {
                                  setState(() {
                                    _selectedCategoryId = newValue;
                                  });
                                },
                                items: _categories
                                    .map<DropdownMenuItem<int>>((CategoryDropdownModel category) {
                                  return DropdownMenuItem<int>(
                                    value: category.id,
                                    child: Text(category.categoryName),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),

                    // Sub-Category Name Field
                    const Row(
                      children: [
                        Icon(Icons.category_outlined, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Sub-Category Name *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subCategoryNameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Enter sub-category name',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Image Field
                    const Row(
                      children: [
                        Icon(Icons.image_outlined, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Sub-Category Image',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 110,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.2,
                          ),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    kIsWeb
                                        ? Image.network(
                                            _selectedImage!.path,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return _buildImagePlaceholder();
                                            },
                                          )
                                        : Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return _buildImagePlaceholder();
                                            },
                                          ),
                                    Container(
                                      color: Colors.black.withOpacity(0.25),
                                    ),
                                    const Center(
                                      child: CircleAvatar(
                                        backgroundColor: Colors.white,
                                        radius: 18,
                                        child: Icon(Icons.edit_rounded, color: Color(0xFF6C3CE1), size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : widget.subCategoryImage != null && widget.subCategoryImage!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          '$imageBaseUrl${widget.subCategoryImage}',
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return _buildImagePlaceholder();
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildImagePlaceholder();
                                          },
                                        ),
                                        Container(
                                          color: Colors.black.withOpacity(0.25),
                                        ),
                                        const Center(
                                          child: CircleAvatar(
                                            backgroundColor: Colors.white,
                                            radius: 18,
                                            child: Icon(Icons.edit_rounded, color: Color(0xFF6C3CE1), size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _buildImagePlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to change image (PNG, JPG, WEBP formats supported)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Status Field
                    const Row(
                      children: [
                        Icon(Icons.toggle_on_outlined, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Status *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _selectedStatus == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(_selectedStatus, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                          Switch(
                            value: _selectedStatus == 'Active',
                            activeColor: const Color(0xFF6C3CE1),
                            activeTrackColor: const Color(0xFFE9DEFF),
                            onChanged: (bool value) {
                              setState(() {
                                _selectedStatus = value ? 'Active' : 'Inactive';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateSubCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C3CE1),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF6C3CE1).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Update Sub-Category',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_upload_outlined,
            size: 28,
            color: Color(0xFF6C3CE1),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Select Gallery Image',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Max size 800x800 px',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _subCategoryNameController.dispose();
    super.dispose();
  }
}