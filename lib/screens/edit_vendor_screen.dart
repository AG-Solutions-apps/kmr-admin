import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:krm_admin/services/auth_service.dart';
import 'package:krm_admin/services/vendor_service.dart';

class EditVendorScreen extends StatefulWidget {
  final int vendorId;

  const EditVendorScreen({super.key, required this.vendorId});

  @override
  State<EditVendorScreen> createState() => _EditVendorScreenState();
}

class _EditVendorScreenState extends State<EditVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final VendorService _vendorService = VendorService();
  final AuthService _authService = AuthService();

  bool _isLoadingData = true;     // loading vendor + categories
  bool _isSubmitting = false;
  bool _isLoadingSubCategories = false;
  String? _errorMessage;

  // Primary form controllers
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Dropdown state
  String? _selectedCategoryName;
  String? _selectedTraderId;
  String _selectedStatus = 'Active';

  // Data
  List<dynamic> _categories = [];
  List<dynamic> _currentSubCategories = [];

  final List<Map<String, String>> _traders = [
    {"id": "1", "name": "Live Rate"},
    {"id": "2", "name": "Spot Rate"},
    {"id": "3", "name": "Rates"},
  ];

  // Dynamic product rows — each row: {id: int?, subCategory: String?, productName: ctrl, size: ctrl, rate: ctrl}
  final List<Map<String, dynamic>> _productRows = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        _fetchVendorDetail(),
        _fetchCategories(),
      ]);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchVendorDetail() async {
    final token = await _authService.getToken();
    final res = await http.get(
      Uri.parse('https://kmrlive.in/public/api/panel-fetch-vendor-by-id/${widget.vendorId}'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final vendor = data['vendor'] ?? {};
      final List<dynamic> subs = data['vendorSub'] ?? [];

      // Populate primary fields
      _nameCtrl.text = vendor['vendor_name'] ?? '';
      _mobileCtrl.text = vendor['vendor_mobile'] ?? '';
      _emailCtrl.text = vendor['vendor_email'] ?? '';
      _addressCtrl.text = vendor['vendor_address'] ?? '';
      _cityCtrl.text = vendor['vendor_city'] ?? '';
      _selectedCategoryName = vendor['vendor_category'];
      _selectedTraderId = vendor['vendor_trader']?.toString();
      final rawStatus = vendor['vendor_status']?.toString();
      _selectedStatus = (rawStatus == 'Active' || rawStatus == 'Inactive') ? rawStatus! : 'Active';

      // Populate dynamic product rows from vendorSub
      _productRows.clear();
      for (var sub in subs) {
        _productRows.add({
          'id': sub['id'],   // keep existing product ID for update
          'subCategory': sub['vendor_product_category_sub']?.toString(),
          'productName': TextEditingController(text: sub['vendor_product']?.toString() ?? ''),
          'size': TextEditingController(text: sub['vendor_product_size']?.toString() ?? ''),
          'rate': TextEditingController(text: sub['vendor_product_rate']?.toString() ?? ''),
        });
      }

      // If no products found, add an empty row
      if (_productRows.isEmpty) {
        _productRows.add({
          'id': null,
          'subCategory': null,
          'productName': TextEditingController(),
          'size': TextEditingController(),
          'rate': TextEditingController(),
        });
      }

      // Fetch sub-categories for the pre-selected category
      if (_selectedCategoryName != null) {
        await _fetchSubCategories(_selectedCategoryName!);
      }
    } else {
      throw Exception('Vendor fetch failed: ${res.statusCode}');
    }
  }

  Future<void> _fetchCategories() async {
    final token = await _authService.getToken();
    final res = await http.get(
      Uri.parse('https://kmrlive.in/public/api/panel-fetch-category'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (mounted) _categories = data['category'] ?? [];
    }
  }

  Future<void> _fetchSubCategories(String categoryName) async {
    if (mounted) setState(() => _isLoadingSubCategories = true);
    try {
      final token = await _authService.getToken();
      final encoded = Uri.encodeComponent(categoryName);
      final res = await http.get(
        Uri.parse('https://kmrlive.in/public/api/panel-fetch-sub-category/$encoded'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _currentSubCategories = data['categorySub'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching sub-categories: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSubCategories = false);
    }
  }

  void _onCategoryChanged(String? categoryName) {
    if (categoryName == null) return;
    setState(() {
      _selectedCategoryName = categoryName;
      _currentSubCategories = [];
      _isLoadingSubCategories = true;
      for (var row in _productRows) {
        row['subCategory'] = null;
      }
    });
    _fetchSubCategories(categoryName);
  }

  void _addProductRow() {
    setState(() {
      _productRows.add({
        'id': null,
        'subCategory': null,
        'productName': TextEditingController(),
        'size': TextEditingController(),
        'rate': TextEditingController(),
      });
    });
  }

  void _removeProductRow(int index) {
    if (_productRows.length > 1) {
      final ctrl = _productRows[index];
      (ctrl['productName'] as TextEditingController).dispose();
      (ctrl['size'] as TextEditingController).dispose();
      (ctrl['rate'] as TextEditingController).dispose();
      setState(() => _productRows.removeAt(index));
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

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Category'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_selectedTraderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Trader'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final productsPayload = _productRows.map((row) {
      return <String, dynamic>{
        if (row['id'] != null) 'id': row['id'],
        'vendor_product_category_sub': row['subCategory'] ?? '',
        'vendor_product': (row['productName'] as TextEditingController).text.trim(),
        'vendor_product_size': (row['size'] as TextEditingController).text.trim(),
        'vendor_product_rate': (row['rate'] as TextEditingController).text.trim(),
        'vendor_product_status': 'Active',
        'vendor_trader': _selectedTraderId ?? '1',
      };
    }).toList();

    final payload = <String, dynamic>{
      'vendor_name': _nameCtrl.text.trim(),
      'vendor_mobile': _mobileCtrl.text.trim(),
      'vendor_email': _emailCtrl.text.trim(),
      'vendor_address': _addressCtrl.text.trim(),
      'vendor_city': _cityCtrl.text.trim(),
      'vendor_category': _selectedCategoryName,
      'vendor_trader': _selectedTraderId,
      'vendor_no_of_products': _productRows.length,
      'vendor_status': _selectedStatus,
      'vendorProduct_sub_data': productsPayload,
    };

    final result = await _vendorService.updateVendor(widget.vendorId, payload);

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor updated successfully!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Update failed', style: const TextStyle(color: Colors.white)),
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
    for (var row in _productRows) {
      (row['productName'] as TextEditingController?)?.dispose();
      (row['size'] as TextEditingController?)?.dispose();
      (row['rate'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  // ─── UI Helpers ──────────────────────────────────────────────────────────────

  Widget _textField(String label, TextEditingController controller, {bool isNumber = false, bool isEmail = false, int maxLines = 1, bool isRequired = true}) {
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
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : (isEmail ? TextInputType.emailAddress : TextInputType.text),
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

  Widget _dropdown(String label, String? selectedValue, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
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

  Widget _buildStatusToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.toggle_on_outlined, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Text('Status *', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
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
      ],
    );
  }

  Widget _subCatWidget(Map<String, dynamic> row) {
    if (_isLoadingSubCategories) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 56,
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
          child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C3CE1)))),
        ),
      );
    }
    if (_selectedCategoryName == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 56,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
          child: Center(child: Text('Select a Category first in Vendor Details tab', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold))),
        ),
      );
    }
    final items = _currentSubCategories.map((sub) => DropdownMenuItem<String>(
      value: sub['category_sub_name'].toString(),
      child: Text(sub['category_sub_name'].toString()),
    )).toList();

    final subCategoryValue = row['subCategory'] as String?;
    if (subCategoryValue != null && !_currentSubCategories.any((sub) => sub['category_sub_name'].toString() == subCategoryValue)) {
      items.add(DropdownMenuItem<String>(
        value: subCategoryValue,
        child: Text(subCategoryValue),
      ));
    }

    return _dropdown(
      'Sub Category',
      subCategoryValue,
      items,
      (val) => setState(() => row['subCategory'] = val),
    );
  }

  // Beautiful Product Card matching screenshot
  Widget _buildProductCard(int index) {
    final row = _productRows[index];
    final subCategoryName = row['subCategory'] as String? ?? 'General SubCategory';
    final nameCtrl = row['productName'] as TextEditingController;
    final sizeCtrl = row['size'] as TextEditingController;
    final rateCtrl = row['rate'] as TextEditingController;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Subcategory pill tag & Delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    subCategoryName,
                    style: const TextStyle(
                      color: Color(0xFF6C3CE1),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_productRows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    tooltip: 'Remove product',
                    onPressed: () => _removeProductRow(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // SubCategory dropdown if editing subcategory
            _subCatWidget(row),
            const SizedBox(height: 8),

            // Product Name & Size Fields
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _textField('Product Name', nameCtrl)),
                const SizedBox(width: 14),
                Expanded(child: _textField('Size', sizeCtrl)),
              ],
            ),

            const Divider(height: 20, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 4),

            // Rate Field (Number Keyboard) matching screenshot
            _textField('Rate (₹)', rateCtrl, isNumber: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    final categoryItems = _categories.map((c) => DropdownMenuItem<String>(
      value: c['category_name'].toString(),
      child: Text(c['category_name'].toString()),
    )).toList();

    if (_selectedCategoryName != null && !_categories.any((c) => c['category_name'].toString() == _selectedCategoryName)) {
      categoryItems.add(DropdownMenuItem<String>(
        value: _selectedCategoryName,
        child: Text(_selectedCategoryName!),
      ));
    }

    final traderItems = _traders.map((t) => DropdownMenuItem<String>(
      value: t['id'],
      child: Text(t['name']!),
    )).toList();

    if (_selectedTraderId != null && !_traders.any((t) => t['id'] == _selectedTraderId)) {
      traderItems.add(DropdownMenuItem<String>(
        value: _selectedTraderId,
        child: Text('Trader $_selectedTraderId'),
      ));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            'Edit Vendor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Vendor Products'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Business & Personal Info'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _isLoadingData
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF6C3CE1)),
                          SizedBox(height: 16),
                          Text('Loading vendor data...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _isSubmitting
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
                          : Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        // ── TAB 1: Vendor Products ───────────────────
                                        ListView(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.edit_note_rounded, color: Color(0xFF6C3CE1), size: 22),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Vendor Products',
                                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                                                    ),
                                                  ],
                                                ),
                                                GestureDetector(
                                                  onTap: _addProductRow,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF5F0FF),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: const Color(0xFFE9DEFF)),
                                                    ),
                                                    child: const Row(
                                                      children: [
                                                        Icon(Icons.add_rounded, size: 18, color: Color(0xFF6C3CE1)),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Add Product',
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
                                            const SizedBox(height: 16),
                                            ...List.generate(_productRows.length, (i) => _buildProductCard(i)),
                                          ],
                                        ),

                                        // ── TAB 2: Business, Personal & Location Info ───
                                        ListView(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                          children: [
                                            const Text(
                                              'Business & Personal Information',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                            const SizedBox(height: 14),
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
                                                  ),
                                                ],
                                                border: Border.all(color: Colors.grey.shade200),
                                              ),
                                              child: isWide
                                                  ? Column(
                                                      children: [
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Expanded(child: _textField('Vendor Name', _nameCtrl)),
                                                            const SizedBox(width: 16),
                                                            Expanded(child: _textField('Mobile', _mobileCtrl, isNumber: true)),
                                                          ],
                                                        ),
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Expanded(child: _textField('Email', _emailCtrl, isEmail: true)),
                                                            const SizedBox(width: 16),
                                                            Expanded(child: _textField('City', _cityCtrl)),
                                                          ],
                                                        ),
                                                        _textField('Address', _addressCtrl, maxLines: 2),
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Expanded(child: _dropdown('Category', _selectedCategoryName, categoryItems, _onCategoryChanged)),
                                                            const SizedBox(width: 16),
                                                            Expanded(child: _dropdown('Trader', _selectedTraderId, traderItems, (v) => setState(() => _selectedTraderId = v))),
                                                            const SizedBox(width: 16),
                                                            Expanded(child: _buildStatusToggle()),
                                                          ],
                                                        ),
                                                      ],
                                                    )
                                                  : Column(
                                                      children: [
                                                        _textField('Vendor Name', _nameCtrl),
                                                        _textField('Mobile', _mobileCtrl, isNumber: true),
                                                        _textField('Email', _emailCtrl, isEmail: true),
                                                        _textField('City', _cityCtrl),
                                                        _textField('Address', _addressCtrl, maxLines: 2),
                                                        _dropdown('Category', _selectedCategoryName, categoryItems, _onCategoryChanged),
                                                        _dropdown('Trader', _selectedTraderId, traderItems, (v) => setState(() => _selectedTraderId = v)),
                                                        _buildStatusToggle(),
                                                      ],
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ── Bottom Persistent Save Button ─────────────────
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, -4),
                                        ),
                                      ],
                                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _submitUpdate,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF6C3CE1),
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shadowColor: const Color(0xFF6C3CE1).withOpacity(0.3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
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
}