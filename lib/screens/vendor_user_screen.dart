import 'package:flutter/material.dart';
import 'package:krm_admin/models/vendor_user_model.dart';
import 'package:krm_admin/services/vendor_user_service.dart';
import 'package:krm_admin/screens/add_vendor_user_screen.dart';
import 'package:krm_admin/screens/edit_vendor_user_screen.dart';

class VendorUserScreen extends StatefulWidget {
  const VendorUserScreen({super.key});

  @override
  State<VendorUserScreen> createState() => _VendorUserScreenState();
}

class _VendorUserScreenState extends State<VendorUserScreen> {
  final VendorUserService _vendorUserService = VendorUserService();
  List<VendorUserModel> _users = [];
  List<VendorUserModel> _filteredUsers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterStatus = 'All';

  // Pagination parameters
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchVendorUsers();
  }

  Future<void> _fetchVendorUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _vendorUserService.fetchVendorUsers();
      if (mounted) {
        setState(() {
          _users = users;
          // Apply current search and filter status to the newly fetched list
          _filteredUsers = users.where((user) {
            bool matchesSearch = _searchQuery.isEmpty ||
                user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                user.mobile.contains(_searchQuery) ||
                user.email.toLowerCase().contains(_searchQuery.toLowerCase());
            
            bool matchesStatus = _filterStatus == 'All' ||
                user.status == _filterStatus;
            
            return matchesSearch && matchesStatus;
          }).toList();
          _isLoading = false;
          _isRefreshing = false;
          _currentPage = 1;
          if (users.isEmpty) {
            _errorMessage = 'No vendor users found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'Failed to load vendor users';
        });
      }
    }
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchVendorUsers();
  }

  void _applyFilter() {
    setState(() {
      _currentPage = 1; // Reset to page 1 on filter change
      _filteredUsers = _users.where((user) {
        bool matchesSearch = _searchQuery.isEmpty ||
            user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.mobile.contains(_searchQuery) ||
            user.email.toLowerCase().contains(_searchQuery.toLowerCase());
        
        bool matchesStatus = _filterStatus == 'All' ||
            user.status == _filterStatus;
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _filterStatus = 'All';
      _applyFilter();
    });
  }

  // Pagination helpers
  int get totalPages => (_filteredUsers.length / _itemsPerPage).ceil();

  List<VendorUserModel> get currentPagedVendorUsers {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredUsers.length) return [];
    if (endIndex > _filteredUsers.length) endIndex = _filteredUsers.length;
    return _filteredUsers.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
          : _errorMessage != null && _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchVendorUsers,
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
                  onRefresh: _refreshUsers,
                  color: const Color(0xFF6C3CE1),
                  child: Column(
                    children: [
                      // Top Statistics summaries
                      _buildSummaryCards(),

                      // Search and Filter Bar
                      _buildSearchAndFilterBar(),

                      // Vendor Users Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildContentHeader(context),
                              const SizedBox(height: 14),
                              if (_filteredUsers.isEmpty)
                                _buildEmptyState()
                              else if (screenWidth < 600)
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
    final total = _users.length;
    final active = _users.where((u) => u.status == 'Active').length;
    final inactive = _users.where((u) => u.status == 'Inactive').length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildSummaryCard('Total', total.toString(), const Color(0xFF6C3CE1), Icons.people_outline_rounded);
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
                      hintText: 'Search vendor users...',
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
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
                    onPressed: _clearSearch,
                  ),
              ],
            ),
          ),
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
                  '${_filteredUsers.length} users',
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
          'Vendor User List',
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
                builder: (context) => const AddVendorUserScreen(),
              ),
            );
            if (result == true) {
              _fetchVendorUsers();
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
                Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF6C3CE1)),
                SizedBox(width: 4),
                Text(
                  'Add User',
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
            'No vendor users found',
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
    final paged = currentPagedVendorUsers;
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: paged.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = paged[index];
        final globalIndex = startIndex + index;
        return _buildMobileCard(user, globalIndex);
      },
    );
  }

  Widget _buildMobileCard(VendorUserModel user, int globalIndex) {
    final isActive = user.status == 'Active';

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
              // User Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.name,
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
                            user.mobile,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.mail_outline_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _toggleVendorUserStatus(user),
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
                            user.status,
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
                        builder: (context) => EditVendorUserScreen(
                          userId: user.id,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchVendorUsers();
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
    final paged = currentPagedVendorUsers;
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
                _buildHeaderCell('Full Name', null, flex: 2),
                _buildHeaderCell('Mobile No', 140),
                _buildHeaderCell('Email Address', null, flex: 2),
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
              final user = paged[index];
              final globalIndex = startIndex + index;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    _buildCell('${globalIndex + 1}', 60),
                    _buildCell(user.name, null, flex: 2, isBold: true),
                    _buildCell(user.mobile, 140),
                    _buildCell(user.email, null, flex: 2),
                    _buildStatusCell(user),
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
                                  builder: (context) => EditVendorUserScreen(
                                    userId: user.id,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _fetchVendorUsers();
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

  Widget _buildStatusCell(VendorUserModel user) {
    final status = user.status;
    final isActive = status == 'Active';
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          InkWell(
            onTap: () => _toggleVendorUserStatus(user),
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

  Future<void> _toggleVendorUserStatus(VendorUserModel user) async {
    final originalStatus = user.status;
    final newStatus = originalStatus == 'Active' ? 'Inactive' : 'Active';

    setState(() {
      user.status = newStatus;
    });

    try {
      final result = await _vendorUserService.updateVendorUser(
        id: user.id,
        name: user.name,
        mobile: user.mobile,
        email: user.email,
        remarks: user.remarks ?? '',
        status: newStatus,
      );

      if (!result['success']) {
        setState(() {
          user.status = originalStatus;
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
              content: Text('${user.name} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        user.status = originalStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildPaginationFooter() {
    final total = _filteredUsers.length;
    if (total == 0) return const SizedBox.shrink();

    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    var endIndex = startIndex + _itemsPerPage - 1;
    if (endIndex > total) endIndex = total;

    final isMobile = MediaQuery.of(context).size.width < 500;

    final infoText = Text(
      'Showing $startIndex-$endIndex of $total users',
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