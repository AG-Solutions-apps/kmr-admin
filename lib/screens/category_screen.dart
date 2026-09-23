import 'package:flutter/material.dart';
import 'package:krm_admin/models/category_model.dart';
import 'package:krm_admin/services/category_service.dart';
import 'package:krm_admin/screens/add_category_screen.dart';
import 'package:krm_admin/screens/edit_category_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  // Base URL for category images
  static const String imageBaseUrl = 'https://kmrlive.in/public/assets/images/categories_images/';

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final CategoryService _categoryService = CategoryService();
  List<CategoryModel> _categories = [];
  List<CategoryModel> _filteredCategories = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterStatus = 'All'; // All, Active, Inactive

  // Pagination parameters
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categories = await _categoryService.fetchCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _filteredCategories = categories.where((category) {
            bool matchesSearch = _searchQuery.isEmpty ||
                category.categoryName.toLowerCase().contains(_searchQuery.toLowerCase());
            bool matchesStatus = _filterStatus == 'All' ||
                category.categoryStatus == _filterStatus;
            return matchesSearch && matchesStatus;
          }).toList();
          _isLoading = false;
          _currentPage = 1;
          if (categories.isEmpty) {
            _errorMessage = 'No categories found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load categories';
        });
      }
    }
  }

  // Search and filter function
  void _applyFilter() {
    setState(() {
      _currentPage = 1; // Reset to page 1 on filter change
      _filteredCategories = _categories.where((category) {
        // Search filter
        bool matchesSearch = _searchQuery.isEmpty ||
            category.categoryName.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // Status filter
        bool matchesStatus = _filterStatus == 'All' ||
            category.categoryStatus == _filterStatus;
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  // Clear search
  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _filterStatus = 'All';
      _applyFilter();
    });
  }

  // Pagination helpers
  int get totalPages => (_filteredCategories.length / _itemsPerPage).ceil();

  List<CategoryModel> get currentPagedCategories {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredCategories.length) return [];
    if (endIndex > _filteredCategories.length) endIndex = _filteredCategories.length;
    return _filteredCategories.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
          : _errorMessage != null && _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchCategories,
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
                  onRefresh: _fetchCategories,
                  color: const Color(0xFF6C3CE1),
                  child: Column(
                    children: [
                      // Top Statistics summaries
                      _buildSummaryCards(),

                      // Search and Filter Bar
                      _buildSearchAndFilterBar(),

                      // Categories Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildContentHeader(context),
                              const SizedBox(height: 14),
                              if (_filteredCategories.isEmpty)
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
    final total = _categories.length;
    final active = _categories.where((c) => c.categoryStatus == 'Active').length;
    final inactive = _categories.where((c) => c.categoryStatus == 'Inactive').length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildSummaryCard('Total', total.toString(), const Color(0xFF6C3CE1), Icons.category_rounded);
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
                      hintText: 'Search categories...',
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
              Text(
                '${_filteredCategories.length} items',
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
          'Category List',
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
                builder: (context) => const AddCategoryScreen(),
              ),
            );
            if (result == true) {
              _fetchCategories();
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
                  'Add Category',
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
            'No categories found',
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
    final paged = currentPagedCategories;
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: paged.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = paged[index];
        final globalIndex = startIndex + index;
        return _buildMobileCard(category, globalIndex);
      },
    );
  }

  Widget _buildMobileCard(CategoryModel category, int globalIndex) {
    final isActive = category.categoryStatus == 'Active';
    String imageUrl = '';
    if (category.categoriesImages != null && category.categoriesImages!.isNotEmpty) {
      if (category.categoriesImages!.startsWith('http')) {
        imageUrl = category.categoriesImages!;
      } else {
        imageUrl = '${CategoryScreen.imageBaseUrl}${category.categoriesImages}';
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
              // Category name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.categoryName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _toggleCategoryStatus(category),
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
                          category.categoryStatus,
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
                        builder: (context) => EditCategoryScreen(
                          categoryId: category.id,
                          categoryName: category.categoryName,
                          categoryImage: category.categoriesImages,
                          categoryStatus: category.categoryStatus,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchCategories();
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
    final paged = currentPagedCategories;
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
                _buildHeaderCell('Category Name', null, flex: 1),
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
              final category = paged[index];
              final globalIndex = startIndex + index;
              String imageUrl = '';
              if (category.categoriesImages != null && category.categoriesImages!.isNotEmpty) {
                if (category.categoriesImages!.startsWith('http')) {
                  imageUrl = category.categoriesImages!;
                } else {
                  imageUrl = '${CategoryScreen.imageBaseUrl}${category.categoriesImages}';
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    _buildCell('${globalIndex + 1}', 60),
                    _buildImageCell(imageUrl, 80),
                    _buildCell(category.categoryName, null, flex: 1, isBold: true),
                    _buildStatusCell(category),
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
                                  builder: (context) => EditCategoryScreen(
                                    categoryId: category.id,
                                    categoryName: category.categoryName,
                                    categoryImage: category.categoriesImages,
                                    categoryStatus: category.categoryStatus,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _fetchCategories();
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

  Widget _buildStatusCell(CategoryModel category) {
    final status = category.categoryStatus;
    final isActive = status == 'Active';
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          InkWell(
            onTap: () => _toggleCategoryStatus(category),
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

  Future<void> _toggleCategoryStatus(CategoryModel category) async {
    final originalStatus = category.categoryStatus;
    final newStatus = originalStatus == 'Active' ? 'Inactive' : 'Active';

    setState(() {
      category.categoryStatus = newStatus;
    });

    try {
      final result = await _categoryService.updateCategory(
        category.id,
        category.categoryName,
        null,
        newStatus,
      );

      if (!result['success']) {
        setState(() {
          category.categoryStatus = originalStatus;
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
              content: Text('${category.categoryName} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        category.categoryStatus = originalStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildPaginationFooter() {
    final total = _filteredCategories.length;
    if (total == 0) return const SizedBox.shrink();

    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    var endIndex = startIndex + _itemsPerPage - 1;
    if (endIndex > total) endIndex = total;

    final isMobile = MediaQuery.of(context).size.width < 500;

    final infoText = Text(
      'Showing $startIndex-$endIndex of $total categories',
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
