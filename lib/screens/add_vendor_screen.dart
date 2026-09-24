import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:krm_admin/services/vendor_service.dart';
import 'package:krm_admin/services/category_service.dart';
import 'package:krm_admin/services/sub_category_service.dart';
import 'package:krm_admin/utils/capitalize_formatter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:krm_admin/services/auth_service.dart';

class AddVendorScreen extends StatefulWidget {
  final String? title;
  const AddVendorScreen({super.key, this.title});

  @override
  State<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends State<AddVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final VendorService _vendorService = VendorService();
  final CategoryService _categoryService = CategoryService();
  final SubCategoryService _subCategoryService = SubCategoryService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Primary form controllers
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Dropdown variables
  String? _selectedCategoryName;
  String? _selectedTraderId;
  String _selectedStatus = 'Active';
  
  // Data for Dropdowns
  List<dynamic> _categories = [];
  List<dynamic> _currentSubCategories = [];

  final List<Map<String, String>> _traders = [
    {"id": "1", "name": "Live Rate"},
    {"id": "2", "name": "Spot Rate"},
    {"id": "3", "name": "Rates"},
  ];

  bool _isLoadingSubCategories = false;
  final List<Map<String, dynamic>> _productControllers = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _addProduct();
  }
  
  Future<void> _fetchCategories() async {
    try {
      String? token = await _authService.getToken();
      final res = await http.get(
        Uri.parse('https://kmrlive.in/public/api/panel-fetch-category'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _categories = data['category'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }
  
  void _onCategoryChanged(String? categoryName) {
    if (categoryName == null) return;
    setState(() {
      _selectedCategoryName = categoryName;
      _currentSubCategories = [];
      _isLoadingSubCategories = true;
      // Reset all selected subcategories in products since parent category changed
      for (var product in _productControllers) {
        product['subCategory'] = null;
      }
    });
    _fetchSubCategories(categoryName);
  }

  Future<void> _fetchSubCategories(String categoryName) async {
    try {
      String? token = await _authService.getToken();
      final encodedName = Uri.encodeComponent(categoryName);
      final res = await http.get(
        Uri.parse('https://kmrlive.in/public/api/panel-fetch-sub-category/$encodedName'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _currentSubCategories = data['categorySub'] ?? [];
            _isLoadingSubCategories = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingSubCategories = false);
      }
    } catch (e) {
      debugPrint('Error fetching sub-categories: $e');
      if (mounted) setState(() => _isLoadingSubCategories = false);
    }
  }

  // --- Add Category Dialog Modal ---
  Future<void> _showAddCategoryDialog([String? initialName]) async {
    final categoryNameCtrl = TextEditingController(text: initialName ?? '');
    File? dialogImage;
    bool isSubmitting = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              try {
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (image != null) {
                  setDialogState(() {
                    dialogImage = File(image.path);
                  });
                }
              } catch (e) {
                debugPrint('Error picking image: $e');
              }
            }

            Future<void> saveCategory() async {
              final catName = categoryNameCtrl.text.trim();
              if (catName.isEmpty) {
                setDialogState(() {
                  dialogError = 'Please enter category name';
                });
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                dialogError = null;
              });

              final messenger = ScaffoldMessenger.of(context);
              final result = await _categoryService.createCategory(catName, dialogImage);

              if (result['success'] == true) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                await _fetchCategories();
                _onCategoryChanged(catName);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Category "$catName" added and selected successfully!', style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                setDialogState(() {
                  isSubmitting = false;
                  dialogError = result['message'] ?? 'Failed to create category';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.category_rounded, color: Color(0xFF6C3CE1)),
                  SizedBox(width: 10),
                  Text('Add New Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Text(
                        'Category Name *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: categoryNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [FirstLetterCapitalizeFormatter()],
                        decoration: InputDecoration(
                          hintText: 'Enter category name',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Category Image (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: dialogImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(
                                              dialogImage!.path,
                                              width: double.infinity,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              dialogImage!,
                                              width: double.infinity,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.black54,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                          onPressed: () => setDialogState(() => dialogImage = null),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade500, size: 28),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click to upload image',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : saveCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Category', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
    categoryNameCtrl.dispose();
  }

  // --- Add Sub Category Dialog Modal ---
  Future<void> _showAddSubCategoryDialog(int productIndex, [String? initialName]) async {
    if (_selectedCategoryName == null || _selectedCategoryName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a main Category first', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Find category object matching _selectedCategoryName
    dynamic selectedCatMap;
    for (var c in _categories) {
      if (c['category_name']?.toString() == _selectedCategoryName) {
        selectedCatMap = c;
        break;
      }
    }

    if (selectedCatMap == null || selectedCatMap['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resolve selected Category ID', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final int categoryId = int.tryParse(selectedCatMap['id'].toString()) ?? 0;
    if (categoryId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Category ID', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final subCategoryNameCtrl = TextEditingController(text: initialName ?? '');
    File? dialogImage;
    bool isSubmitting = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              try {
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (image != null) {
                  setDialogState(() {
                    dialogImage = File(image.path);
                  });
                }
              } catch (e) {
                debugPrint('Error picking image: $e');
              }
            }

            Future<void> saveSubCategory() async {
              final subName = subCategoryNameCtrl.text.trim();
              if (subName.isEmpty) {
                setDialogState(() {
                  dialogError = 'Please enter sub-category name';
                });
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                dialogError = null;
              });

              final messenger = ScaffoldMessenger.of(context);
              final result = await _subCategoryService.createSubCategory(
                categoryId,
                subName,
                dialogImage,
              );

              if (result['success'] == true) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                await _fetchSubCategories(_selectedCategoryName!);
                if (mounted) {
                  setState(() {
                    _productControllers[productIndex]['subCategory'] = subName;
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Sub Category "$subName" added and selected successfully!', style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                setDialogState(() {
                  isSubmitting = false;
                  dialogError = result['message'] ?? 'Failed to create sub-category';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF6C3CE1)),
                  SizedBox(width: 10),
                  Text('Add New Sub Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE9DEFF)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_outlined, color: Color(0xFF6C3CE1), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Category: $_selectedCategoryName',
                                style: const TextStyle(
                                  color: Color(0xFF6C3CE1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Text(
                        'Sub Category Name *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: subCategoryNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [FirstLetterCapitalizeFormatter()],
                        decoration: InputDecoration(
                          hintText: 'Enter sub category name',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sub Category Image (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: dialogImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(
                                              dialogImage!.path,
                                              width: double.infinity,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              dialogImage!,
                                              width: double.infinity,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.black54,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                          onPressed: () => setDialogState(() => dialogImage = null),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade500, size: 28),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click to upload image',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : saveSubCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Sub Category', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
    subCategoryNameCtrl.dispose();
  }

  // --- Search Dialog Modal for Dropdowns ---
  void _openSearchDialog({
    required String title,
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String?> onSelect,
    void Function(String initialText)? onAddNew,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        String filterQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredList = items
                .where((item) => item.toLowerCase().contains(filterQuery.toLowerCase()))
                .toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (onAddNew != null)
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onAddNew(filterQuery.trim());
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF6C3CE1)),
                            SizedBox(width: 4),
                            Text('Add New', style: TextStyle(color: Color(0xFF6C3CE1), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 380,
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [FirstLetterCapitalizeFormatter()],
                      decoration: InputDecoration(
                        hintText: 'Search $title...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6C3CE1)),
                        suffixIcon: filterQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setDialogState(() => filterQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          filterQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Filtered List
                    Expanded(
                      child: filteredList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No matching $title found',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  if (onAddNew != null) ...[
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        onAddNew(filterQuery.trim());
                                      },
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: Text(filterQuery.trim().isEmpty ? 'Add New $title' : 'Create "${filterQuery.trim()}"'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6C3CE1),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredList.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                              itemBuilder: (context, idx) {
                                final item = filteredList[idx];
                                final isSelected = item == selectedValue;
                                return ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  tileColor: isSelected ? const Color(0xFFF5F0FF) : null,
                                  title: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? const Color(0xFF6C3CE1) : Colors.black87,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6C3CE1), size: 20)
                                      : null,
                                  onTap: () {
                                    onSelect(item);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required String? selectedValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    void Function(String initialText)? onAddNew,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FormField<String>(
        initialValue: selectedValue,
        validator: isRequired
            ? (val) {
                if (selectedValue == null || selectedValue.isEmpty) {
                  return 'Please select $label';
                }
                return null;
              }
            : null,
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Text(
                        isRequired ? '$label *' : label,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                      ),
                    ],
                  ),
                  if (onAddNew != null)
                    InkWell(
                      onTap: () => onAddNew(''),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF6C3CE1)),
                            SizedBox(width: 4),
                            Text(
                              'Add New',
                              style: TextStyle(
                                color: Color(0xFF6C3CE1),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  _openSearchDialog(
                    title: label,
                    items: items,
                    selectedValue: selectedValue,
                    onSelect: (val) {
                      onChanged(val);
                      state.didChange(val);
                    },
                    onAddNew: onAddNew,
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: state.hasError ? Colors.red.shade400 : Colors.grey.shade200,
                      width: state.hasError ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedValue ?? 'Select $label',
                          style: TextStyle(
                            color: selectedValue != null ? Colors.black87 : Colors.grey.shade400,
                            fontSize: 14,
                            fontWeight: selectedValue != null ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey, size: 28),
                    ],
                  ),
                ),
              ),
              if (state.hasError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _addProduct() {
    setState(() {
      _productControllers.add({
        'subCategory': null,
        'productName': TextEditingController(),
        'size': TextEditingController(),
        'rate': TextEditingController(),
      });
    });
  }

  void _removeProduct(int index) {
    if (_productControllers.length > 1) {
      setState(() {
        _productControllers.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one product is required', style: TextStyle(color: Colors.white)), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    for (var controllers in _productControllers) {
      controllers['productName']?.dispose();
      controllers['size']?.dispose();
      controllers['rate']?.dispose();
    }
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Category', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (_selectedTraderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Trader', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Build sub products JSON
    List<Map<String, dynamic>> productsPayload = _productControllers.map((ctrls) {
      return <String, dynamic>{
        "vendor_product_category_sub": ctrls['subCategory'] ?? '',
        "vendor_product": (ctrls['productName'] as TextEditingController).text.trim(),
        "vendor_product_size": (ctrls['size'] as TextEditingController).text.trim(),
        "vendor_product_rate": (ctrls['rate'] as TextEditingController).text.trim(),
      };
    }).toList();

    // Build main payload
    Map<String, dynamic> payload = {
      "vendor_name": _nameCtrl.text.trim(),
      "vendor_mobile": _mobileCtrl.text.trim(),
      "vendor_email": _emailCtrl.text.trim(),
      "vendor_address": _addressCtrl.text.trim(),
      "vendor_city": _cityCtrl.text.trim(),
      "vendor_category": _selectedCategoryName,
      "vendor_trader": _selectedTraderId,
      "vendor_no_of_products": _productControllers.length,
      "vendor_status": _selectedStatus,
      "vendorProduct_sub_data": productsPayload,
    };

    final result = await _vendorService.createVendor(payload);

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor Created Successfully!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create vendor', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildTextField(
    String label, 
    TextEditingController controller, 
    {bool isNumber = false, bool isEmail = false, int maxLines = 1, bool isRequired = false}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              Text(
                isRequired ? '$label *' : label,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            textCapitalization: maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.words,
            inputFormatters: isNumber || isEmail ? null : [FirstLetterCapitalizeFormatter(capitalizeWords: maxLines <= 1)],
            keyboardType: isNumber ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: isRequired ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter $label';
              }
              return null;
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label, 
    String? selectedValue, 
    List<DropdownMenuItem<String>> items, 
    ValueChanged<String?> onChanged,
    {VoidCallback? onAddNew}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    '$label *',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                  ),
                ],
              ),
              if (onAddNew != null)
                InkWell(
                  onTap: onAddNew,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF6C3CE1)),
                        SizedBox(width: 4),
                        Text(
                          'Add New',
                          style: TextStyle(
                            color: Color(0xFF6C3CE1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedValue,
              items: items,
              onChanged: onChanged,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
              iconSize: 28,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select $label';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(int index) {
    final ctrls = _productControllers[index];
    
    List<String> subCategoryList = _currentSubCategories
        .map((sub) => sub['category_sub_name'].toString())
        .toList();

    // Sub Category widget: shows spinner while loading, message if no category selected, searchable dropdown once ready
    Widget subCatWidget;
    if (_isLoadingSubCategories) {
      subCatWidget = Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C3CE1)),
            ),
          ),
        ),
      );
    } else if (_selectedCategoryName == null) {
      subCatWidget = Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    SizedBox(width: 4),
                    Text(
                      'Sub Category *',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showAddSubCategoryDialog(index),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF6C3CE1)),
                        SizedBox(width: 4),
                        Text(
                          'Add New',
                          style: TextStyle(
                            color: Color(0xFF6C3CE1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  'Select a Category first',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      subCatWidget = _buildSearchableDropdown(
        label: 'Sub Category',
        selectedValue: ctrls['subCategory'] as String?,
        items: subCategoryList,
        onChanged: (val) => setState(() => ctrls['subCategory'] = val),
        onAddNew: (initialText) => _showAddSubCategoryDialog(index, initialText),
        isRequired: true,
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F0FF),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C3CE1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Product Details',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C3CE1), fontSize: 14),
                    ),
                  ],
                ),
                if (_productControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _removeProduct(index),
                    tooltip: 'Remove Product',
                  ),
              ],
            ),
          ),
          // Fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 600;
                if (isDesktop) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: subCatWidget),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Product Name', ctrls['productName']!, isRequired: true)),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTextField('Size', ctrls['size']!, isRequired: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Rate', ctrls['rate']!, isNumber: true, isRequired: true)),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      subCatWidget,
                      _buildTextField('Product Name', ctrls['productName']!, isRequired: true),
                      _buildTextField('Size', ctrls['size']!, isRequired: true),
                      _buildTextField('Rate', ctrls['rate']!, isNumber: true, isRequired: true),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    
    List<String> categoryList = _categories.map((c) => c['category_name'].toString()).toList();

    List<DropdownMenuItem<String>> traderItems = _traders.map((t) {
      return DropdownMenuItem<String>(
        value: t['id'],
        child: Text(t['name']!),
      );
    }).toList();

    List<DropdownMenuItem<String>> statusItems = const ['Active', 'Inactive'].map((s) {
      final isAct = s == 'Active';
      return DropdownMenuItem<String>(
        value: s,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isAct ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(s),
          ],
        ),
      );
    }).toList();

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
        title: Text(
          widget.title ?? 'Add New Vendor',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      children: [
                        // Primary Info Section
                        const Text(
                          'Primary Information',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ],
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: isDesktop
                              ? Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildTextField('Vendor Name', _nameCtrl, isRequired: true)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildTextField('Mobile', _mobileCtrl, isNumber: true, isRequired: false)),
                                      ],
                                    ),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildTextField('Email', _emailCtrl, isEmail: true, isRequired: false)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildTextField('City', _cityCtrl, isRequired: false)),
                                      ],
                                    ),
                                    _buildTextField('Address', _addressCtrl, maxLines: 2, isRequired: false),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildSearchableDropdown(
                                            label: 'Category', 
                                            selectedValue: _selectedCategoryName, 
                                            items: categoryList, 
                                            onChanged: _onCategoryChanged,
                                            onAddNew: (initialText) => _showAddCategoryDialog(initialText),
                                            isRequired: true,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildDropdown('Trader', _selectedTraderId, traderItems, (val) => setState(() => _selectedTraderId = val))),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildDropdown('Status', _selectedStatus, statusItems, (val) => setState(() => _selectedStatus = val ?? 'Active'))),
                                      ],
                                    ),
                                  ],
                                )
                               : Column(
                                  children: [
                                    _buildTextField('Vendor Name', _nameCtrl, isRequired: true),
                                    _buildTextField('Mobile', _mobileCtrl, isNumber: true, isRequired: false),
                                    _buildTextField('Email', _emailCtrl, isEmail: true, isRequired: false),
                                    _buildTextField('City', _cityCtrl, isRequired: false),
                                    _buildTextField('Address', _addressCtrl, maxLines: 2, isRequired: false),
                                    _buildSearchableDropdown(
                                      label: 'Category', 
                                      selectedValue: _selectedCategoryName, 
                                      items: categoryList, 
                                      onChanged: _onCategoryChanged,
                                      onAddNew: (initialText) => _showAddCategoryDialog(initialText),
                                      isRequired: true,
                                    ),
                                    _buildDropdown('Trader', _selectedTraderId, traderItems, (val) => setState(() => _selectedTraderId = val)),
                                    _buildDropdown('Status', _selectedStatus, statusItems, (val) => setState(() => _selectedStatus = val ?? 'Active')),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 32),

                        // Products Section Header
                        const Text(
                          'Vendor Products',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        
                        ...List.generate(
                          _productControllers.length, 
                          (index) => _buildProductCard(index)
                        ),

                        // Left-aligned compact Add Product button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF6C3CE1)),
                            label: const Text(
                              'Add Another Product',
                              style: TextStyle(
                                color: Color(0xFF6C3CE1),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF5F0FF),
                              side: const BorderSide(color: Color(0xFFE9DEFF)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                        
                        // Submit Button (Big full-width button)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C3CE1),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: const Color(0xFF6C3CE1).withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}