import 'package:flutter/material.dart';
import 'package:krm_admin/models/vendor_spot_rate_model.dart';
import 'package:krm_admin/services/vendor_service.dart';

class SpotScreen extends StatefulWidget {
  const SpotScreen({super.key});

  @override
  State<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends State<SpotScreen> {
  final VendorService _vendorService = VendorService();
  List<VendorSpotRateModel> _spotItems = [];
  List<VendorSpotRateModel> _filteredItems = [];
  List<Map<String, dynamic>> _vendorsList = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  // Show ONLY categories present in spot items
  List<String> get uniqueCategories {
    final categories = _spotItems
        .map((item) => item.vendorCategory.trim().isNotEmpty ? item.vendorCategory.trim() : item.vendorName.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
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
    _fetchSpotRates();
    _getVendors();
  }

  Future<List<Map<String, dynamic>>> _getVendors() async {
    if (_vendorsList.isNotEmpty) return _vendorsList;
    try {
      var list = await _vendorService.fetchSpotEligibleVendors();
      if (list.isEmpty) {
        final vendors = await _vendorService.fetchVendors();
        list = vendors.map((v) => {'id': v.id, 'vendor_name': v.vendorName}).toList();
      }
      if (mounted) {
        setState(() {
          _vendorsList = list;
        });
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _fetchSpotRates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _vendorService.fetchVendorSpotRatesList();
      // Sort latest date and time first (fallback to ID)
      items.sort((a, b) {
        final dtA = _parseDateTime(a.vendorSpotCreatedDate, a.vendorSpotCreatedTime);
        final dtB = _parseDateTime(b.vendorSpotCreatedDate, b.vendorSpotCreatedTime);
        final cmp = dtB.compareTo(dtA);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });
      if (mounted) {
        setState(() {
          _spotItems = items;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load spot rates: $e';
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredItems = _spotItems.where((item) {
        final matchesSearch = _searchQuery.isEmpty ||
            item.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.vendorCategory.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.vendorSpotHeading.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.vendorSpotDetails.toLowerCase().contains(_searchQuery.toLowerCase());

        final itemCat = item.vendorCategory.trim().isNotEmpty ? item.vendorCategory.trim() : item.vendorName.trim();
        final matchesCategory = _selectedCategoryFilter == 'All' ||
            itemCat.toLowerCase() == _selectedCategoryFilter.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _refreshSpotRates() async {
    await _fetchSpotRates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _refreshSpotRates,
        color: const Color(0xFF6C3CE1),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
            : Column(
                children: [
                  // Top Summary Stats Cards
                  _buildSummaryCards(),

                  // Search and Filter Bar (Funnel icon removed)
                  _buildSearchAndFilterBar(),

                  // List Content
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
                          else if (_filteredItems.isEmpty)
                            _buildNoMatchState()
                          else
                            _buildSpotCardsView(),
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
    final totalCount = _spotItems.length;
    final activeCount = _spotItems.where((v) => v.vendorSpotStatus.toLowerCase() == 'active').length;
    final inactiveCount = _spotItems.where((v) => v.vendorSpotStatus.toLowerCase() == 'inactive').length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildStatCard('Total Spot', totalCount.toString(), const Color(0xFF6C3CE1), Icons.bolt_rounded);
    Widget card2 = _buildStatCard('Active Spot', activeCount.toString(), const Color(0xFF10B981), Icons.check_circle_outline_rounded);
    Widget card3 = _buildStatCard('Inactive Spot', inactiveCount.toString(), const Color(0xFFEF4444), Icons.cancel_outlined);

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
          // Search input
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
                      hintText: 'Search by vendor, heading, or details...',
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
          // Horizontal Category Filter Chips
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
          'Vendor Spot Rates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.2,
          ),
        ),
        GestureDetector(
          onTap: () => _showAddDialog(context),
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
                  'Add Spot',
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'No spot rates found',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchSpotRates,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C3CE1), foregroundColor: Colors.white),
            child: const Text('Retry Fetching'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchState() {
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
            'No spot rates match your criteria',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear filters', style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Cards View for Web (3 cards per row) and Mobile (1 card per row)
  Widget _buildSpotCardsView() {
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
              child: _buildSpotCardItem(item, index + 1),
            );
          }),
        );
      },
    );
  }

  Widget _buildSpotCardItem(VendorSpotRateModel item, int displayIndex) {
    final dateTimeStr = '${item.vendorSpotCreatedDate} ${item.vendorSpotCreatedTime}'.trim();
    final isActive = item.vendorSpotStatus.toLowerCase() == 'active';

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
                Text(
                  item.vendorSpotHeading,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.vendorCategory.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.vendorCategory,
                      style: const TextStyle(
                        color: Color(0xFF6C3CE1),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  item.vendorSpotDetails,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          dateTimeStr.isEmpty ? 'N/A' : dateTimeStr,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildStatusBadge(VendorSpotRateModel item) {
    final status = item.vendorSpotStatus;
    final isActive = status.toLowerCase() == 'active';
    return InkWell(
      onTap: () => _toggleSpotStatus(item),
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

  Future<void> _toggleSpotStatus(VendorSpotRateModel item) async {
    final originalStatus = item.vendorSpotStatus;
    final newStatus = originalStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';

    setState(() {
      item.vendorSpotStatus = newStatus;
    });

    try {
      final result = await _vendorService.updateVendorSpotRate(item.id, {
        'vendor_id': item.vendorId,
        'vendor_spot_heading': item.vendorSpotHeading,
        'vendor_spot_details': item.vendorSpotDetails,
        'vendor_spot_status': newStatus,
      });

      if (!result['success']) {
        setState(() {
          item.vendorSpotStatus = originalStatus;
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
              content: Text('${item.vendorSpotHeading} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        item.vendorSpotStatus = originalStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildActionBtn(BuildContext context, VendorSpotRateModel item) {
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

  void _showAddDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final headingCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    int? selectedVendorId;
    List<Map<String, dynamic>> vendors = List.from(_vendorsList);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (vendors.isEmpty) {
              _getVendors().then((list) {
                if (context.mounted) {
                  setDialogState(() {
                    vendors = List.from(list);
                  });
                }
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Vendor Spot Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Vendor *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedVendorId,
                        decoration: InputDecoration(
                          hintText: vendors.isEmpty ? 'Loading vendors...' : 'Select Vendor',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        isExpanded: true,
                        items: vendors.map((v) {
                          final id = v['id'] is int ? v['id'] as int : int.tryParse(v['id'].toString()) ?? 0;
                          final name = v['vendor_name']?.toString() ?? v['name']?.toString() ?? 'Vendor #$id';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedVendorId = val;
                          });
                        },
                        validator: (v) => v == null ? 'Vendor is required' : null,
                      ),
                      const SizedBox(height: 14),
                      const Text('Spot Heading *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: headingCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter spot heading...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Heading is required' : null,
                      ),
                      const SizedBox(height: 14),
                      const Text('Spot Details *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: detailsCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter spot details...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Details are required' : null,
                      ),
                    ],
                  ),
                ),
              ),
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
                            setDialogState(() => isSaving = true);
                            final res = await _vendorService.createVendorSpotRate({
                              'vendor_id': selectedVendorId,
                              'vendor_spot_heading': headingCtrl.text.trim(),
                              'vendor_spot_details': detailsCtrl.text.trim(),
                              'vendor_spot_status': 'Active',
                            });
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Spot rate created successfully'),
                                  backgroundColor: res['success'] ? Colors.green : Colors.red,
                                ),
                              );
                              if (res['success']) {
                                _fetchSpotRates();
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Spot Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, VendorSpotRateModel item) {
    final formKey = GlobalKey<FormState>();
    final headingCtrl = TextEditingController(text: item.vendorSpotHeading);
    final detailsCtrl = TextEditingController(text: item.vendorSpotDetails);
    int? selectedVendorId = item.vendorId > 0 ? item.vendorId : null;
    List<Map<String, dynamic>> vendors = List.from(_vendorsList);
    bool isSaving = false;

    if (selectedVendorId != null && !vendors.any((v) => (v['id'] is int ? v['id'] : int.tryParse(v['id'].toString())) == selectedVendorId)) {
      vendors.insert(0, {
        'id': item.vendorId,
        'vendor_name': item.vendorName,
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (vendors.isEmpty) {
              _getVendors().then((list) {
                if (context.mounted) {
                  setDialogState(() {
                    vendors = List.from(list);
                    if (selectedVendorId != null && !vendors.any((v) => (v['id'] is int ? v['id'] : int.tryParse(v['id'].toString())) == selectedVendorId)) {
                      vendors.insert(0, {
                        'id': item.vendorId,
                        'vendor_name': item.vendorName,
                      });
                    }
                  });
                }
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Spot Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Vendor *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedVendorId,
                        decoration: InputDecoration(
                          hintText: 'Select Vendor',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        isExpanded: true,
                        items: vendors.map((v) {
                          final id = v['id'] is int ? v['id'] as int : int.tryParse(v['id'].toString()) ?? 0;
                          final name = v['vendor_name']?.toString() ?? v['name']?.toString() ?? 'Vendor #$id';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedVendorId = val;
                          });
                        },
                        validator: (v) => v == null ? 'Vendor is required' : null,
                      ),
                      const SizedBox(height: 14),
                      const Text('Spot Heading *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: headingCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter heading...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Heading is required' : null,
                      ),
                      const SizedBox(height: 14),
                      const Text('Spot Details *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: detailsCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter details...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Details are required' : null,
                      ),
                    ],
                  ),
                ),
              ),
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
                            setDialogState(() => isSaving = true);
                            final res = await _vendorService.updateVendorSpotRate(item.id, {
                              'vendor_id': selectedVendorId,
                              'vendor_spot_heading': headingCtrl.text.trim(),
                              'vendor_spot_details': detailsCtrl.text.trim(),
                              'vendor_spot_status': item.vendorSpotStatus,
                            });
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Spot rate updated successfully'),
                                  backgroundColor: res['success'] ? Colors.green : Colors.red,
                                ),
                              );
                              if (res['success']) {
                                _fetchSpotRates();
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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