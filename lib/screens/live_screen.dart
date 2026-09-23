import 'package:flutter/material.dart';
import 'package:krm_admin/models/vendor_live_model.dart';
import 'package:krm_admin/services/vendor_service.dart';
import 'package:krm_admin/screens/add_vendor_screen.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final VendorService _vendorService = VendorService();
  
  List<VendorLiveModel> _liveItems = [];
  List<VendorLiveModel> _filteredItems = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  List<String> get uniqueVendors {
    final vendors = _liveItems.map((item) => item.vendorName).toSet().where((v) => v.isNotEmpty).toList();
    vendors.sort();
    return ['All', ...vendors];
  }

  // Show ONLY categories that have items in live data
  List<String> get uniqueCategories {
    final Set<String> categories = {};
    for (var item in _liveItems) {
      if (item.vendorProductCategory.trim().isNotEmpty) {
        categories.add(item.vendorProductCategory.trim());
      }
    }
    final sortedList = categories.toList()..sort();
    return ['All', ...sortedList];
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategoryFilter = 'All';
      _applyFilter();
    });
  }

  DateTime _parseDateTime(String dateStr, String timeStr) {
    if (dateStr.trim().isEmpty) return DateTime(1970);
    try {
      String cleanDate = dateStr.trim();
      if (cleanDate.contains('-') || cleanDate.contains('/')) {
        final parts = cleanDate.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            cleanDate = '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
          } else if (parts[2].length == 4) {
            cleanDate = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        }
      }

      String cleanTime = timeStr.trim();
      int hour = 0, minute = 0, second = 0;
      if (cleanTime.isNotEmpty) {
        bool isPm = cleanTime.toUpperCase().contains('PM');
        bool isAm = cleanTime.toUpperCase().contains('AM');
        String tOnly = cleanTime.replaceAll(RegExp(r'[^\d:]'), '');
        final tParts = tOnly.split(':');
        if (tParts.isNotEmpty) hour = int.tryParse(tParts[0]) ?? 0;
        if (tParts.length > 1) minute = int.tryParse(tParts[1]) ?? 0;
        if (tParts.length > 2) second = int.tryParse(tParts[2]) ?? 0;

        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
      }

      final parsedDate = DateTime.tryParse(cleanDate);
      if (parsedDate != null) {
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, hour, minute, second);
      }
    } catch (_) {}
    return DateTime(1970);
  }

  @override
  void initState() {
    super.initState();
    _fetchLiveItems();
  }

  Future<void> _fetchLiveItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final items = await _vendorService.fetchVendorLiveList();
    // Sort latest date and time first (fallback to ID)
    items.sort((a, b) {
      final dateA = a.vendorProductUpdatedDate.isNotEmpty ? a.vendorProductUpdatedDate : a.vendorProductCreatedDate;
      final timeA = a.vendorProductUpdatedTime.isNotEmpty ? a.vendorProductUpdatedTime : a.vendorProductCreatedTime;
      final dateB = b.vendorProductUpdatedDate.isNotEmpty ? b.vendorProductUpdatedDate : b.vendorProductCreatedDate;
      final timeB = b.vendorProductUpdatedTime.isNotEmpty ? b.vendorProductUpdatedTime : b.vendorProductCreatedTime;
      
      final dtA = _parseDateTime(dateA, timeA);
      final dtB = _parseDateTime(dateB, timeB);
      final cmp = dtB.compareTo(dtA);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    if (mounted) {
      setState(() {
        _liveItems = items;
        _applyFilter();
        _isLoading = false;
        if (items.isEmpty) {
          _errorMessage = 'No live updates found';
        }
      });
    }
  }

  Future<void> _refreshLiveItems() async {
    await _fetchLiveItems();
  }

  void _applyFilter() {
    setState(() {
      _filteredItems = _liveItems.where((item) {
        bool matchesSearch = _searchQuery.isEmpty ||
            item.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.vendorProductCategorySub.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.vendorProduct.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesCategory = _selectedCategoryFilter == 'All' ||
            item.vendorProductCategory.toLowerCase() == _selectedCategoryFilter.toLowerCase() ||
            item.vendorProductCategorySub.toLowerCase() == _selectedCategoryFilter.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _refreshLiveItems,
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

                  // Search and Category Filter Bar (Filter funnel icon removed)
                  _buildSearchAndFilterBar(),

                  // List Content Cards (Shows ALL items, no pagination)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildContentHeader(context),
                          const SizedBox(height: 14),
                          if (_errorMessage != null && _filteredItems.isEmpty)
                            _buildEmptyState()
                          else
                            _buildLiveCardsView(),
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
    final total = _liveItems.length;
    final active = _liveItems.where((v) => v.vendorProductStatus.toLowerCase() == 'active').length;
    final inactive = _liveItems.where((v) => v.vendorProductStatus.toLowerCase() == 'inactive').length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildStatCard('Total Products', total.toString(), const Color(0xFF6C3CE1), Icons.live_tv_rounded);
    Widget card2 = _buildStatCard('Active Rates', active.toString(), const Color(0xFF10B981), Icons.trending_up_rounded);
    Widget card3 = _buildStatCard('Inactive Rates', inactive.toString(), const Color(0xFFEF4444), Icons.trending_flat_rounded);

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
          // Search input (Filter funnel icon removed)
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
                      hintText: 'Search by vendor, subcategory, or product...',
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
          // Category Filter Chips
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
                '${_filteredItems.length} items',
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

  Widget _buildContentHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Live Rates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_filteredItems.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C3CE1),
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddVendorScreen(title: 'Add Vendor'),
              ),
            ).then((_) {
              _fetchLiveItems();
            });
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
                  'Add Live',
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'No live updates found',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          if (_searchQuery.isNotEmpty || _selectedCategoryFilter != 'All')
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters', style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold)),
            )
          else if (_liveItems.isEmpty)
            TextButton(
              onPressed: _fetchLiveItems,
              child: const Text('Retry Fetching', style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // Cards View for Web (3 cards per row) and Mobile (1 card per row)
  Widget _buildLiveCardsView() {
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
          children: List.generate(_filteredItems.length, (index) {
            final item = _filteredItems[index];
            return SizedBox(
              width: cardWidth,
              child: _buildLiveCardItem(item, index + 1),
            );
          }),
        );
      },
    );
  }

  Widget _buildLiveCardItem(VendorLiveModel item, int displayIndex) {
    final dateTimeStr = '${item.vendorProductUpdatedDate} ${item.vendorProductUpdatedTime}'.trim();
    final isActive = item.vendorProductStatus.toLowerCase() == 'active';

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
                // Header: Vendor Name & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$displayIndex. ${item.vendorName}',
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
                    _buildStatusBadge(item),
                  ],
                ),
                const SizedBox(height: 8),
                // Product Name
                Text(
                  item.vendorProduct,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Category Sub & Size Badges
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
                        item.vendorProductCategorySub,
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
                        'Size: ${item.vendorProductSize}',
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
                // Price Rate, Date & Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${item.vendorProductRate}',
                          style: const TextStyle(
                            color: Color(0xFF6C3CE1),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              dateTimeStr.isEmpty ? 'N/A' : dateTimeStr,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildActionBtn(context, item),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(VendorLiveModel item) {
    final status = item.vendorProductStatus;
    final isActive = status.toLowerCase() == 'active';
    return InkWell(
      onTap: () => _toggleLiveStatus(item),
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

  Future<void> _toggleLiveStatus(VendorLiveModel item) async {
    final originalStatus = item.vendorProductStatus;
    final newStatus = originalStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';

    setState(() {
      item.vendorProductStatus = newStatus;
    });

    try {
      final result = await _vendorService.updateVendorLive(item.id, {
        'vendor_product': item.vendorProduct,
        'vendor_product_size': item.vendorProductSize,
        'vendor_product_rate': item.vendorProductRate.toString(),
        'vendor_product_status': newStatus,
      });

      if (!result['success']) {
        setState(() {
          item.vendorProductStatus = originalStatus;
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
              content: Text('${item.vendorProduct} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        item.vendorProductStatus = originalStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildActionBtn(BuildContext context, VendorLiveModel item) {
    return InkWell(
      onTap: () => _showEditDialog(context, item),
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

  // Edit Rate Modal: Only shows Rate (₹) field with number keyboard, hides product/size/status fields visually, but sends all to backend.
  void _showEditDialog(BuildContext context, VendorLiveModel item) {
    final formKey = GlobalKey<FormState>();
    final rateCtrl = TextEditingController(text: item.vendorProductRate.toString());
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                            item.vendorName,
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
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Product: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      item.vendorProduct,
                                      style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('SubCat: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                                  Text(
                                    item.vendorProductCategorySub,
                                    style: const TextStyle(color: Color(0xFF6C3CE1), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Size: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                                  Text(
                                    item.vendorProductSize,
                                    style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Rate Field ONLY (Number Keyboard)
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'Rate (₹) *',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autofocus: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6C3CE1)),
                          decoration: InputDecoration(
                            hintText: 'Enter Rate',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF6C3CE1)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Rate is required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isSaving = true;
                            });

                            final result = await _vendorService.updateVendorLive(
                              item.id,
                              {
                                'vendor_product': item.vendorProduct,
                                'vendor_product_size': item.vendorProductSize,
                                'vendor_product_rate': rateCtrl.text.trim(),
                                'vendor_product_status': item.vendorProductStatus,
                              },
                            );

                            if (context.mounted) {
                              setDialogState(() {
                                isSaving = false;
                              });
                              Navigator.pop(context); // Close dialog

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'Rate updated successfully', style: const TextStyle(color: Colors.white)),
                                  backgroundColor: result['success'] ? Colors.green : Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              if (result['success']) {
                                _fetchLiveItems(); // Refresh the list
                              }
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