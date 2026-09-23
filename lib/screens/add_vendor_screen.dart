import 'package:flutter/material.dart';
import 'package:krm_admin/services/vendor_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final AuthService _authService = AuthService();
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

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, bool isEmail = false, int maxLines = 1, bool isRequired = true}) {
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

  Widget _buildDropdown(String label, String? selectedValue, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
    
    // Build subcategory items from live API data
    List<DropdownMenuItem<String>> subCategoryItems = _currentSubCategories.map((sub) {
      return DropdownMenuItem<String>(
        value: sub['category_sub_name'].toString(),
        child: Text(sub['category_sub_name'].toString()),
      );
    }).toList();

    // Sub Category widget: shows spinner while loading, dropdown once ready
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
        child: Container(
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
      );
    } else {
      subCatWidget = _buildDropdown(
        'Sub Category',
        ctrls['subCategory'] as String?,
        subCategoryItems,
        (val) => setState(() => ctrls['subCategory'] = val),
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
                          Expanded(child: _buildTextField('Product Name', ctrls['productName']!)),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTextField('Size', ctrls['size']!)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Rate', ctrls['rate']!, isNumber: true)),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      subCatWidget,
                      _buildTextField('Product Name', ctrls['productName']!),
                      _buildTextField('Size', ctrls['size']!),
                      _buildTextField('Rate', ctrls['rate']!, isNumber: true),
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
    
    List<DropdownMenuItem<String>> categoryItems = _categories.map((c) {
      return DropdownMenuItem<String>(
        value: c['category_name'].toString(),
        child: Text(c['category_name'].toString()),
      );
    }).toList();

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
                                        Expanded(child: _buildTextField('Vendor Name', _nameCtrl)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildTextField('Mobile', _mobileCtrl, isNumber: true)),
                                      ],
                                    ),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildTextField('Email', _emailCtrl, isEmail: true)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildTextField('City', _cityCtrl)),
                                      ],
                                    ),
                                    _buildTextField('Address', _addressCtrl, maxLines: 2),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildDropdown('Category', _selectedCategoryName, categoryItems, _onCategoryChanged)),
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
                                    _buildTextField('Vendor Name', _nameCtrl),
                                    _buildTextField('Mobile', _mobileCtrl, isNumber: true),
                                    _buildTextField('Email', _emailCtrl, isEmail: true),
                                    _buildTextField('City', _cityCtrl),
                                    _buildTextField('Address', _addressCtrl, maxLines: 2),
                                    _buildDropdown('Category', _selectedCategoryName, categoryItems, _onCategoryChanged),
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