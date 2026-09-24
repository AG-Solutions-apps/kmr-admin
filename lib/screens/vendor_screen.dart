import 'package:flutter/material.dart';
import 'package:krm_admin/models/vendor_model.dart';
import 'package:krm_admin/services/vendor_service.dart';
import 'package:krm_admin/screens/add_vendor_screen.dart';
import 'package:krm_admin/screens/edit_vendor_screen.dart';

class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  final VendorService _vendorService = VendorService();
  List<VendorModel> _vendors = [];
  List<VendorModel> _filteredVendors = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _selectedCategoryFilter = 'All';
  String _selectedTraderFilter = 'All';
  bool _showFilters = false;

  List<String> get uniqueCategories {
    final categories = _vendors.map((v) => v.vendorCategory).toSet().where((c) => c.isNotEmpty).toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<String> get uniqueTraders {
    final traders = _vendors.map((v) => v.vendorTrader).toSet().where((t) => t.isNotEmpty).toList();
    traders.sort();
    return ['All', ...traders];
  }

  // Pagination parameters
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

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

    try {
      final vendors = await _vendorService.fetchVendors();
      if (mounted) {
        setState(() {
          _vendors = vendors;
          // Apply current search and filter status to the newly fetched list
          _filteredVendors = vendors.where((vendor) {
            bool matchesSearch = _searchQuery.isEmpty ||
                vendor.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                vendor.vendorMobile.contains(_searchQuery) ||
                vendor.vendorCategory.toLowerCase().contains(_searchQuery.toLowerCase());
            
            bool matchesStatus = _filterStatus == 'All' ||
                vendor.vendorStatus == _filterStatus;
            
            bool matchesCategory = _selectedCategoryFilter == 'All' ||
                vendor.vendorCategory == _selectedCategoryFilter;

            bool matchesTrader = _selectedTraderFilter == 'All' ||
                vendor.vendorTrader == _selectedTraderFilter;

            return matchesSearch && matchesStatus && matchesCategory && matchesTrader;
          }).toList();
          _isLoading = false;
          _isRefreshing = false;
          _currentPage = 1;
          if (vendors.isEmpty) {
            _errorMessage = 'No vendors found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'Failed to load vendors';
        });
      }
    }
  }

  Future<void> _refreshVendors() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchVendors();
  }

  void _applyFilter() {
    setState(() {
      _currentPage = 1; // Reset to page 1 on filter change
      _filteredVendors = _vendors.where((vendor) {
        bool matchesSearch = _searchQuery.isEmpty ||
            vendor.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            vendor.vendorMobile.contains(_searchQuery) ||
            vendor.vendorCategory.toLowerCase().contains(_searchQuery.toLowerCase());
        
        bool matchesStatus = _filterStatus == 'All' ||
            vendor.vendorStatus == _filterStatus;
        
        bool matchesCategory = _selectedCategoryFilter == 'All' ||
            vendor.vendorCategory == _selectedCategoryFilter;

        bool matchesTrader = _selectedTraderFilter == 'All' ||
            vendor.vendorTrader == _selectedTraderFilter;

        return matchesSearch && matchesStatus && matchesCategory && matchesTrader;
      }).toList();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _filterStatus = 'All';
      _selectedCategoryFilter = 'All';
      _selectedTraderFilter = 'All';
      _applyFilter();
    });
  }

  // Pagination helpers
  int get totalPages => (_filteredVendors.length / _itemsPerPage).ceil();

  List<VendorModel> get currentPagedVendors {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredVendors.length) return [];
    if (endIndex > _filteredVendors.length) endIndex = _filteredVendors.length;
    return _filteredVendors.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
          : _errorMessage != null && _vendors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchVendors,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C3CE1),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshVendors,
                  color: const Color(0xFF6C3CE1),
                  child: Column(
                    children: [
                      // Top Statistics summaries
                      _buildSummaryCards(),

                      // Search and Filter Bar
                      _buildSearchAndFilterBar(),

                      // Vendors Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildContentHeader(context),
                              const SizedBox(height: 14),
                              if (_filteredVendors.isEmpty)
                                _buildEmptyState()
                              else if (screenWidth < 700)
                                _buildMobileCardList()
                              else
                                _buildDesktopTable(),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // Pagination Footer
                      if (totalPages > 1) _buildPaginationFooter(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final total = _vendors.length;
    final active = _vendors.where((v) => v.vendorStatus == 'Active').length;
    final inactive = _vendors.where((v) => v.vendorStatus == 'Inactive').length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildSummaryCard('Total', total.toString(), const Color(0xFF6C3CE1), Icons.storefront_rounded);
    Widget card2 = _buildSummaryCard('Active', active.toString(), const Color(0xFF10B981), Icons.check_circle_rounded);
    Widget card3 = _buildSummaryCard('Inactive', inactive.toString(), const Color(0xFFEF4444), Icons.cancel_rounded);

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

  Widget _buildSummaryCard(String title, String count, Color color, IconData icon) {
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
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Search by vendor name, mobile, category...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilter();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                    color: _showFilters ? const Color(0xFF6C3CE1) : Colors.grey,
                  ),
                  tooltip: 'Filter options',
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_showFilters) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategoryFilter,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          border: InputBorder.none,
                        ),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategoryFilter = val;
                              _applyFilter();
                            });
                          }
                        },
                        items: uniqueCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedTraderFilter,
                        decoration: const InputDecoration(
                          labelText: 'Trader',
                          labelStyle: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          border: InputBorder.none,
                        ),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedTraderFilter = val;
                              _applyFilter();
                            });
                          }
                        },
                        items: uniqueTraders.map((t) => DropdownMenuItem(value: t, child: Text(t == 'All' ? 'All' : 'Trader $t'))).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Filter Chips
          Row(
            children: [
              _buildFilterChip('All', 'All'),
              const SizedBox(width: 8),
              _buildFilterChip('Active', 'Active'),
              const SizedBox(width: 8),
              _buildFilterChip('Inactive', 'Inactive'),
              const Spacer(),
              if (_isRefreshing)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C3CE1)),
                )
              else
                Text(
                  '${_filteredVendors.length} found',
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

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filterStatus == value;
    Color chipColor = isSelected ? const Color(0xFFF5F0FF) : Colors.white;
    Color borderAndTextColor = isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade300;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _applyFilter();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: chipColor,
      checkmarkColor: const Color(0xFF6C3CE1),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderAndTextColor,
          width: 1.2,
        ),
      ),
    );
  }

  Widget _buildContentHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Vendors Dashboard',
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
                builder: (context) => const AddVendorScreen(),
              ),
            );
            if (result == true) {
              _fetchVendors();
            }
          },
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
                  'Add Vendor',
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
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
            _errorMessage ?? 'No vendors match your search',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          if (_searchQuery.isNotEmpty || _filterStatus != 'All')
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Clear filters', style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileCardList() {
    final paged = currentPagedVendors;
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: paged.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final vendor = paged[index];
        final globalIndex = startIndex + index;
        return _buildMobileCard(vendor, globalIndex);
      },
    );
  }

  Widget _buildMobileCard(VendorModel vendor, int globalIndex) {
    final isActive = vendor.vendorStatus == 'Active';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status stripe on left
              Container(
                width: 5,
                color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 14),
              // Index number badge
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${globalIndex + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Vendor Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        vendor.vendorName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_iphone_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            vendor.vendorMobile,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F0FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE9DEFF)),
                            ),
                            child: Text(
                              vendor.vendorCategory,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C3CE1),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: Text(
                              'Trader ${vendor.vendorTrader}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              '${vendor.vendorNoOfProducts} Products',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _toggleVendorStatus(vendor),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                                ),
                              ),
                              child: Text(
                                vendor.vendorStatus,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? const Color(0xFF047857) : const Color(0xFFBE123C),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Action buttons on the right
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF6C3CE1), size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditVendorScreen(
                          vendorId: vendor.id,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchVendors();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    final paged = currentPagedVendors;
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('SL No', 60),
                _buildHeaderCell('Vendor Name', null, flex: 3),
                _buildHeaderCell('Mobile No', null, flex: 2),
                _buildHeaderCell('Category', null, flex: 2),
                _buildHeaderCell('Trader', null, flex: 2),
                _buildHeaderCell('No of Products', null, flex: 2),
                _buildHeaderCell('Status', 120),
                _buildHeaderCell('Actions', 80),
              ],
            ),
          ),
          // Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: paged.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final vendor = paged[index];
              final globalIndex = startIndex + index;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    _buildCell('${globalIndex + 1}', 60),
                    _buildCell(vendor.vendorName, null, flex: 3, isBold: true),
                    _buildCell(vendor.vendorMobile, null, flex: 2),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F0FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              vendor.vendorCategory, 
                              style: const TextStyle(color: Color(0xFF6C3CE1), fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildCell(vendor.vendorTrader, null, flex: 2),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${vendor.vendorNoOfProducts} items', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                     _buildStatusCell(vendor),
                    SizedBox(
                      width: 80,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF6C3CE1), size: 20),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditVendorScreen(
                                    vendorId: vendor.id,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _fetchVendors();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double? width, {int? flex}) {
    if (width != null) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      );
    }
    return Expanded(
      flex: flex ?? 1,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCell(String text, double? width, {int? flex, bool isBold = false}) {
    if (width != null) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Expanded(
      flex: flex ?? 1,
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusCell(VendorModel vendor) {
    final status = vendor.vendorStatus;
    final isActive = status == 'Active';
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          InkWell(
            onTap: () => _toggleVendorStatus(vendor),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? const Color(0xFF047857) : const Color(0xFFBE123C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVendorStatus(VendorModel vendor) async {
    final originalStatus = vendor.vendorStatus;
    final newStatus = originalStatus == 'Active' ? 'Inactive' : 'Active';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1))),
    );

    try {
      final vendorDetails = await _vendorService.fetchVendorById(vendor.id);
      
      if (vendorDetails == null || vendorDetails['vendor'] == null) {
        throw Exception('Failed to retrieve vendor details');
      }

      final vendorMap = vendorDetails['vendor'] as Map<String, dynamic>;
      final List<dynamic> rawSubs = vendorDetails['vendorSub'] ?? [];

      final productsPayload = rawSubs.map((sub) {
        return <String, dynamic>{
          'id': sub['id'],
          'vendor_product_category_sub': sub['vendor_product_category_sub'] ?? '',
          'vendor_product': sub['vendor_product'] ?? '',
          'vendor_product_size': sub['vendor_product_size'] ?? '',
          'vendor_product_rate': sub['vendor_product_rate'] ?? '',
          'vendor_product_status': sub['vendor_product_status'] ?? 'Active',
          'vendor_trader': sub['vendor_trader'] ?? '1',
        };
      }).toList();

      final payload = <String, dynamic>{
        'vendor_name': vendorMap['vendor_name'] ?? vendor.vendorName,
        'vendor_mobile': vendorMap['vendor_mobile'] ?? vendor.vendorMobile,
        'vendor_email': vendorMap['vendor_email'] ?? '',
        'vendor_address': vendorMap['vendor_address'] ?? '',
        'vendor_city': vendorMap['vendor_city'] ?? '',
        'vendor_category': vendorMap['vendor_category'] ?? vendor.vendorCategory,
        'vendor_trader': vendorMap['vendor_trader']?.toString() ?? vendor.vendorTrader,
        'vendor_no_of_products': productsPayload.length,
        'vendor_status': newStatus,
        'vendorProduct_sub_data': productsPayload,
      };

      final result = await _vendorService.updateVendor(vendor.id, payload);

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        setState(() {
          vendor.vendorStatus = newStatus;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${vendor.vendorName} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: ${result['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildPaginationFooter() {
    final total = _filteredVendors.length;
    if (total == 0) return const SizedBox.shrink();

    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    var endIndex = startIndex + _itemsPerPage - 1;
    if (endIndex > total) endIndex = total;

    final isMobile = MediaQuery.of(context).size.width < 500;

    final infoText = Text(
      'Showing $startIndex-$endIndex of $total vendors',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade500,
        fontWeight: FontWeight.w600,
      ),
    );

    final navControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous button
        _buildPageNavButton(
          Icons.arrow_back_ios_new_rounded,
          _currentPage > 1,
          () {
            setState(() {
              _currentPage--;
            });
          },
        ),
        const SizedBox(width: 12),
        Text(
          'Page $_currentPage of $totalPages',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 12),
        // Next button
        _buildPageNavButton(
          Icons.arrow_forward_ios_rounded,
          _currentPage < totalPages,
          () {
            setState(() {
              _currentPage++;
            });
          },
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: isMobile
          ? Column(
              children: [
                infoText,
                const SizedBox(height: 10),
                navControls,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                infoText,
                navControls,
              ],
            ),
    );
  }

  Widget _buildPageNavButton(IconData icon, bool enabled, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? Colors.grey.shade200 : Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            size: 14,
            color: enabled ? const Color(0xFF6C3CE1) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}