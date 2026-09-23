import 'package:flutter/material.dart';
import 'package:krm_admin/models/sub_category_model.dart';
import 'package:krm_admin/services/sub_category_service.dart';
import 'package:krm_admin/screens/add_sub_category_screen.dart';
import 'package:krm_admin/screens/edit_sub_category_screen.dart';

class SubCategoryScreen extends StatefulWidget {
  const SubCategoryScreen({super.key});

  // Base URL for sub-category images
  static const String imageBaseUrl = 'https://kmrlive.in/public/assets/images/sub_categories_images/';

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  final SubCategoryService _subCategoryService = SubCategoryService();
  List<SubCategoryModel> _subCategories = [];
  List<SubCategoryModel> _filteredSubCategories = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _selectedCategoryFilter = 'All';
  bool _showFilters = false;

  List<String> get uniqueCategories {
    final categories = _subCategories.map((sub) => sub.categoryName).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  // Pagination parameters
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchSubCategories();
  }

  Future<void> _fetchSubCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subCategories = await _subCategoryService.fetchSubCategories();
      if (mounted) {
        setState(() {
          _subCategories = subCategories;
          // Apply current search and filter status to the newly fetched list
          _filteredSubCategories = subCategories.where((subCategory) {
            bool matchesSearch = _searchQuery.isEmpty ||
                subCategory.categorySubName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                subCategory.categoryName.toLowerCase().contains(_searchQuery.toLowerCase());
            
            bool matchesStatus = _filterStatus == 'All' ||
                subCategory.categorySubStatus == _filterStatus;
            
            bool matchesCategoryFilter = _selectedCategoryFilter == 'All' ||
                subCategory.categoryName == _selectedCategoryFilter;

            return matchesSearch && matchesStatus && matchesCategoryFilter;
          }).toList();
          _isLoading = false;
          _isRefreshing = false;
          _currentPage = 1;
          if (subCategories.isEmpty) {
            _errorMessage = 'No sub-categories found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'Failed to load sub-categories';
        });
      }
    }
  }

  Future<void> _refreshCategories() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchSubCategories();
  }

  void _applyFilter() {
    setState(() {
      _currentPage = 1; // Reset to page 1 on filter change
      _filteredSubCategories = _subCategories.where((subCategory) {
        bool matchesSearch = _searchQuery.isEmpty ||
            subCategory.categorySubName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            subCategory.categoryName.toLowerCase().contains(_searchQuery.toLowerCase());
        
        bool matchesStatus = _filterStatus == 'All' ||
            subCategory.categorySubStatus == _filterStatus;
        
        bool matchesCategoryFilter = _selectedCategoryFilter == 'All' ||
            subCategory.categoryName == _selectedCategoryFilter;

        return matchesSearch && matchesStatus && matchesCategoryFilter;
      }).toList();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _filterStatus = 'All';
      _selectedCategoryFilter = 'All';
      _applyFilter();
    });
  }

  // Pagination helpers
  int get totalPages => (_filteredSubCategories.length / _itemsPerPage).ceil();

  List<SubCategoryModel> get currentPagedSubCategories {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredSubCategories.length) return [];
    if (endIndex > _filteredSubCategories.length) endIndex = _filteredSubCategories.length;
    return _filteredSubCategories.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
          : _errorMessage != null && _subCategories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchSubCategories,
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
                  onRefresh: _refreshCategories,
                  color: const Color(0xFF6C3CE1),
                  child: Column(
                    children: [
                      // Top Statistics summaries
                      _buildSummaryCards(),

                      // Search and Filter Bar
                      _buildSearchAndFilterBar(),

                      // Sub-Categories Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildContentHeader(context),
                              const SizedBox(height: 14),
                              if (_filteredSubCategories.isEmpty)
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
    final total = _subCategories.length;
    final active = _subCategories.where((c) => c.categorySubStatus == 'Active').length;
    final inactive = _subCategories.where((c) => c.categorySubStatus == 'Inactive').length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildSummaryCard('Total', total.toString(), const Color(0xFF6C3CE1), Icons.list_alt_rounded);
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
                    decoration: const InputDecoration(
                      hintText: 'Search sub-categories...',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategoryFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Category',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF6C3CE1), size: 18),
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                  iconSize: 28,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (String? val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategoryFilter = val;
                        _applyFilter();
                      });
                    }
                  },
                  items: uniqueCategories.map((cat) {
                    final count = cat == 'All'
                        ? _subCategories.length
                        : _subCategories.where((sub) => sub.categoryName == cat).length;
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat == 'All' ? 'All Categories ($count)' : '$cat ($count)'),
                    );
                  }).toList(),
                ),
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
                    '${_filteredSubCategories.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
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
          'Sub-Category List',
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
                builder: (context) => const AddSubCategoryScreen(),
              ),
            );
            if (result == true) {
              _fetchSubCategories();
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
                  'Add Sub-Category',
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
            'No sub-categories found',
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
    final paged = currentPagedSubCategories;
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: paged.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final subCategory = paged[index];
        final globalIndex = startIndex + index;
        return _buildMobileCard(subCategory, globalIndex);
      },
    );
  }

  Widget _buildMobileCard(SubCategoryModel subCategory, int globalIndex) {
    final isActive = subCategory.categorySubStatus == 'Active';
    String imageUrl = '';
    if (subCategory.categoriesSubImages != null && subCategory.categoriesSubImages!.isNotEmpty) {
      if (subCategory.categoriesSubImages!.startsWith('http')) {
        imageUrl = subCategory.categoriesSubImages!;
      } else {
        imageUrl = '${SubCategoryScreen.imageBaseUrl}${subCategory.categoriesSubImages}';
      }
    }

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
              // Image view
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 50,
                          width: 50,
                          color: Colors.grey.shade100,
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 20),
                        ),
                      )
                    : Container(
                        height: 50,
                        width: 50,
                        color: Colors.grey.shade100,
                        child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 20),
                      ),
              ),
              const SizedBox(width: 14),
              // Subcategory name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      subCategory.categorySubName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Category: ${subCategory.categoryName}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _toggleSubCategoryStatus(subCategory),
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
                          subCategory.categorySubStatus,
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
              // Action buttons on the right
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF6C3CE1), size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditSubCategoryScreen(
                          subCategoryId: subCategory.id,
                          categoryName: subCategory.categoryName,
                          subCategoryName: subCategory.categorySubName,
                          subCategoryImage: subCategory.categoriesSubImages,
                          subCategoryStatus: subCategory.categorySubStatus,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchSubCategories();
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
    final paged = currentPagedSubCategories;
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
                _buildHeaderCell('Image', 80),
                _buildHeaderCell('Sub-Category Name', null, flex: 1),
                _buildHeaderCell('Parent Category', null, flex: 1),
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
              final subCategory = paged[index];
              final globalIndex = startIndex + index;
              String imageUrl = '';
              if (subCategory.categoriesSubImages != null && subCategory.categoriesSubImages!.isNotEmpty) {
                if (subCategory.categoriesSubImages!.startsWith('http')) {
                  imageUrl = subCategory.categoriesSubImages!;
                } else {
                  imageUrl = '${SubCategoryScreen.imageBaseUrl}${subCategory.categoriesSubImages}';
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    _buildCell('${globalIndex + 1}', 60),
                    _buildImageCell(imageUrl, 80),
                    _buildCell(subCategory.categorySubName, null, flex: 1, isBold: true),
                    _buildCell(subCategory.categoryName, null, flex: 1),
                    _buildStatusCell(subCategory),
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
                                  builder: (context) => EditSubCategoryScreen(
                                    subCategoryId: subCategory.id,
                                    categoryName: subCategory.categoryName,
                                    subCategoryName: subCategory.categorySubName,
                                    subCategoryImage: subCategory.categoriesSubImages,
                                    subCategoryStatus: subCategory.categorySubStatus,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _fetchSubCategories();
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

  Widget _buildImageCell(String imageUrl, double width) {
    return SizedBox(
      width: width,
      child: imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                height: 44,
                width: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 22),
                ),
              ),
            )
          : Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 22),
            ),
    );
  }

  Widget _buildStatusCell(SubCategoryModel subCategory) {
    final status = subCategory.categorySubStatus;
    final isActive = status == 'Active';
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          InkWell(
            onTap: () => _toggleSubCategoryStatus(subCategory),
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

  Future<void> _toggleSubCategoryStatus(SubCategoryModel subCategory) async {
    final originalStatus = subCategory.categorySubStatus;
    final newStatus = originalStatus == 'Active' ? 'Inactive' : 'Active';

    setState(() {
      subCategory.categorySubStatus = newStatus;
    });

    try {
      final catId = subCategory.categoryId ?? 0;
      final result = await _subCategoryService.updateSubCategory(
        subCategory.id,
        catId,
        subCategory.categorySubName,
        null,
        newStatus,
      );

      if (!result['success']) {
        setState(() {
          subCategory.categorySubStatus = originalStatus;
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
              content: Text('${subCategory.categorySubName} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        subCategory.categorySubStatus = originalStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildPaginationFooter() {
    final total = _filteredSubCategories.length;
    if (total == 0) return const SizedBox.shrink();

    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    var endIndex = startIndex + _itemsPerPage - 1;
    if (endIndex > total) endIndex = total;

    final isMobile = MediaQuery.of(context).size.width < 500;

    final infoText = Text(
      'Showing $startIndex-$endIndex of $total sub-categories',
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