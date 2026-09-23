import 'package:flutter/material.dart';
import 'package:krm_admin/models/vendor_model.dart';
import 'package:krm_admin/screens/add_vendor_screen.dart';
import 'package:krm_admin/services/vendor_service.dart';

class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  final VendorService _vendorService = VendorService();
  
  List<VendorModel> _vendors = [];
  List<VendorModel> _filteredVendors = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  // Show ONLY categories present in vendors data
  List<String> get uniqueCategories {
    final categories = _vendors
        .map((v) => v.vendorCategory.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategoryFilter = 'All';
      _applyFilter();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchVendors();
  }

  Future<void> _fetchVendors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final vendors = await _vendorService.fetchVendors();
    // Sort latest updated / created items first
    vendors.sort((a, b) => b.id.compareTo(a.id));
    
    if (mounted) {
      setState(() {
        _vendors = vendors;
        _isLoading = false;
        _applyFilter();
        if (vendors.isEmpty) {
          _errorMessage = 'No vendors found';
        }
      });
    }
  }

  Future<void> _refreshVendors() async {
    await _fetchVendors();
  }

  void _applyFilter() {
    setState(() {
      _filteredVendors = _vendors.where((vendor) {
        bool matchesSearch = _searchQuery.isEmpty ||
            vendor.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            vendor.vendorMobile.contains(_searchQuery) ||
            vendor.vendorCategory.toLowerCase().contains(_searchQuery.toLowerCase());
        
        bool matchesCategory = _selectedCategoryFilter == 'All' ||
            vendor.vendorCategory.toLowerCase() == _selectedCategoryFilter.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _refreshVendors,
        color: const Color(0xFF6C3CE1),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C3CE1)),
                ),
              )
            : Column(
                children: [
                  // Top Summary Stats Cards
                  _buildSummaryCards(),

                  // Search and Category Filter Chips
                  _buildSearchAndFilterBar(),

                  // Content Section
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildContentHeader(context),
                          const SizedBox(height: 14),
                          if (_errorMessage != null && _filteredVendors.isEmpty)
                            _buildEmptyState()
                          else
                            _buildVendorCardsView(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalCount = _vendors.length;
    final activeCount = _vendors.where((v) => v.vendorStatus.toLowerCase() == 'active').length;
    final totalProducts = _vendors.fold<int>(0, (sum, v) => sum + v.vendorNoOfProducts);

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildStatCard('Total Vendors', totalCount.toString(), const Color(0xFF6C3CE1), Icons.storefront_rounded);
    Widget card2 = _buildStatCard('Active Vendors', activeCount.toString(), const Color(0xFF10B981), Icons.check_circle_outline_rounded);
    Widget card3 = _buildStatCard('Total Products', totalProducts.toString(), const Color(0xFFEF4444), Icons.inventory_2_outlined);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Row(
        children: [
          isDesktop ? SizedBox(width: 250, child: card1) : Expanded(child: card1),
          const SizedBox(width: 10),
          isDesktop ? SizedBox(width: 250, child: card2) : Expanded(child: card2),
          const SizedBox(width: 10),
          isDesktop ? SizedBox(width: 250, child: card3) : Expanded(child: card3),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.08), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.search_rounded, color: Colors.grey),
                ),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by vendor name, category, or mobile...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilter();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal Scrollable Category Filter Chips
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: uniqueCategories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = uniqueCategories[index];
                      return _buildCategoryChip(category);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_filteredVendors.length} vendors',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryName) {
    bool isSelected = (_selectedCategoryFilter == 'All' && categoryName == 'All') ||
        _selectedCategoryFilter.toLowerCase() == categoryName.toLowerCase();
    Color chipColor = isSelected ? const Color(0xFFF5F0FF) : Colors.white;
    Color borderAndTextColor = isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade300;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategoryFilter = categoryName;
          _applyFilter();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderAndTextColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 16, color: Color(0xFF6C3CE1)),
              const SizedBox(width: 6),
            ],
            Text(
              categoryName,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Vendor Rates Master',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.2,
          ),
        ),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddVendorScreen(title: 'Create Vendor Rate'),
              ),
            );
            if (result == true) {
              _fetchVendors();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_rounded, size: 18, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Add Rate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'No vendors found',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          if (_searchQuery.isNotEmpty || _selectedCategoryFilter != 'All')
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters', style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold)),
            )
          else if (_vendors.isEmpty)
            TextButton(
              onPressed: _fetchVendors,
              child: const Text('Retry Fetching', style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // Cards View for Web (3 cards per row) and Mobile (1 card per row)
  Widget _buildVendorCardsView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth >= 900 ? 3 : (screenWidth >= 600 ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 12;
        final double totalWidth = constraints.maxWidth;
        final double cardWidth = crossAxisCount == 1
            ? totalWidth
            : (totalWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(_filteredVendors.length, (index) {
            final vendor = _filteredVendors[index];
            return SizedBox(
              width: cardWidth,
              child: _buildVendorCardItem(vendor, index + 1),
            );
          }),
        );
      },
    );
  }

  Widget _buildVendorCardItem(VendorModel vendor, int displayIndex) {
    final traderName = vendor.vendorTrader == '1'
        ? 'Live Rate'
        : (vendor.vendorTrader == '2'
            ? 'Spot Rate'
            : (vendor.vendorTrader == '3' ? 'Rates' : 'Trader ${vendor.vendorTrader}'));
    final isActive = vendor.vendorStatus.toLowerCase() == 'active';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Left Accent Line for Status
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 17, right: 14, top: 14, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$displayIndex. ${vendor.vendorName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(vendor),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      vendor.vendorMobile.isEmpty ? 'N/A' : vendor.vendorMobile,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vendor.vendorCategory,
                        style: const TextStyle(
                          color: Color(0xFF6C3CE1),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        traderName,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${vendor.vendorNoOfProducts} products',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    _buildActionBtn(context, vendor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(VendorModel vendor) {
    final status = vendor.vendorStatus;
    final isActive = status.toLowerCase() == 'active';
    return InkWell(
      onTap: () => _toggleVendorStatus(vendor),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3), width: 0.5),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? const Color(0xFF047857) : const Color(0xFFBE123C),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _toggleVendorStatus(VendorModel vendor) async {
    final originalStatus = vendor.vendorStatus;
    final newStatus = originalStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';

    setState(() {
      vendor.vendorStatus = newStatus;
    });

    try {
      final result = await _vendorService.updateVendor(vendor.id, {
        'vendor_name': vendor.vendorName,
        'vendor_mobile': vendor.vendorMobile,
        'vendor_category': vendor.vendorCategory,
        'vendor_trader': vendor.vendorTrader,
        'vendor_status': newStatus,
      });

      if (result['success'] != true) {
        setState(() {
          vendor.vendorStatus = originalStatus;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: ${result['message']}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${vendor.vendorName} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        vendor.vendorStatus = originalStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildActionBtn(BuildContext context, VendorModel vendor) {
    return InkWell(
      onTap: () => _showEditRateDialog(context, vendor),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0FF),
          border: Border.all(color: const Color(0xFFE9DEFF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6C3CE1)),
            SizedBox(width: 4),
            Text(
              'Edit',
              style: TextStyle(
                color: Color(0xFF6C3CE1),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick Rate Edit Popup Dialog — shows only Rate (₹) field with number keyboard, leaves other details unaltered
  void _showEditRateDialog(BuildContext context, VendorModel vendor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoadingDetail = true;
        bool isSaving = false;
        Map<String, dynamic>? vendorDetail;
        List<Map<String, dynamic>> rateEditRows = [];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch vendor details on popup open
            if (isLoadingDetail && vendorDetail == null) {
              _vendorService.fetchVendorById(vendor.id).then((detail) {
                if (context.mounted) {
                  setDialogState(() {
                    vendorDetail = detail;
                    isLoadingDetail = false;
                    final List<dynamic> subs = detail?['vendorSub'] ?? [];
                    rateEditRows.clear();
                    for (var sub in subs) {
                      rateEditRows.add({
                        'id': sub['id'],
                        'vendor_product_category_sub': sub['vendor_product_category_sub']?.toString() ?? '',
                        'vendor_product': sub['vendor_product']?.toString() ?? '',
                        'vendor_product_size': sub['vendor_product_size']?.toString() ?? '',
                        'vendor_product_status': sub['vendor_product_status']?.toString() ?? 'Active',
                        'vendor_trader': sub['vendor_trader']?.toString() ?? vendor.vendorTrader,
                        'rateCtrl': TextEditingController(text: sub['vendor_product_rate']?.toString() ?? ''),
                      });
                    }
                    if (rateEditRows.isEmpty) {
                      rateEditRows.add({
                        'id': null,
                        'vendor_product_category_sub': vendor.vendorCategory,
                        'vendor_product': 'Default Product',
                        'vendor_product_size': 'Standard',
                        'vendor_product_status': 'Active',
                        'vendor_trader': vendor.vendorTrader,
                        'rateCtrl': TextEditingController(text: '0'),
                      });
                    }
                  });
                }
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Color(0xFF6C3CE1), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendor.vendorName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Update Rate Details',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 450,
                child: isLoadingDetail
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF6C3CE1)),
                              SizedBox(height: 14),
                              Text('Loading product rates...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, color: Color(0xFF6C3CE1), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Vendor Products',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...List.generate(rateEditRows.length, (index) {
                              final item = rateEditRows[index];
                              final subCat = item['vendor_product_category_sub'].toString();
                              final productName = item['vendor_product'].toString();
                              final size = item['vendor_product_size'].toString();
                              final rateCtrl = item['rateCtrl'] as TextEditingController;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Subcategory Pill Tag
                                    if (subCat.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F0FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          subCat,
                                          style: const TextStyle(
                                            color: Color(0xFF6C3CE1),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 10),

                                    // Product Name & Size Display
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Product Name', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                                              const SizedBox(height: 2),
                                              Text(
                                                productName,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('Size', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 2),
                                            Text(
                                              size.isEmpty ? 'N/A' : size,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                    const SizedBox(height: 12),

                                    // Editable Rate (₹) * Input Box ONLY
                                    const Row(
                                      children: [
                                        SizedBox(width: 4),
                                        Text(
                                          'Rate (₹) *',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: rateCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6C3CE1)),
                                      decoration: InputDecoration(
                                        hintText: 'Enter Rate',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF6C3CE1), size: 18),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
              ),
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isSaving || isLoadingDetail
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });

                          final vendorInfo = vendorDetail?['vendor'] ?? {};
                          final productsPayload = rateEditRows.map((row) {
                            return <String, dynamic>{
                              if (row['id'] != null) 'id': row['id'],
                              'vendor_product_category_sub': row['vendor_product_category_sub'],
                              'vendor_product': row['vendor_product'],
                              'vendor_product_size': row['vendor_product_size'],
                              'vendor_product_rate': (row['rateCtrl'] as TextEditingController).text.trim(),
                              'vendor_product_status': row['vendor_product_status'],
                              'vendor_trader': row['vendor_trader'],
                            };
                          }).toList();

                          final payload = <String, dynamic>{
                            'vendor_name': vendorInfo['vendor_name'] ?? vendor.vendorName,
                            'vendor_mobile': vendorInfo['vendor_mobile'] ?? vendor.vendorMobile,
                            'vendor_email': vendorInfo['vendor_email'] ?? '',
                            'vendor_address': vendorInfo['vendor_address'] ?? '',
                            'vendor_city': vendorInfo['vendor_city'] ?? '',
                            'vendor_category': vendorInfo['vendor_category'] ?? vendor.vendorCategory,
                            'vendor_trader': vendorInfo['vendor_trader'] ?? vendor.vendorTrader,
                            'vendor_no_of_products': productsPayload.length,
                            'vendor_status': vendorInfo['vendor_status'] ?? vendor.vendorStatus,
                            'vendorProduct_sub_data': productsPayload,
                          };

                          final result = await _vendorService.updateVendor(vendor.id, payload);

                          if (context.mounted) {
                            setDialogState(() {
                              isSaving = false;
                            });
                            Navigator.pop(context); // Close dialog

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? 'Rate updated successfully', style: const TextStyle(color: Colors.white)),
                                backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            if (result['success'] == true) {
                              _fetchVendors(); // Refresh list
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE1),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFF6C3CE1).withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}