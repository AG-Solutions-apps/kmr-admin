import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krm_admin/models/news_model.dart';
import 'package:krm_admin/services/news_service.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final NewsService _newsService = NewsService();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<NewsModel> _newsItems = [];
  List<NewsModel> _filteredItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  int _cacheBuster = DateTime.now().millisecondsSinceEpoch;

  List<String> get uniqueCategories {
    return const ['All', 'Active', 'Inactive'];
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
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _newsService.fetchNewsList();
      // Sort latest date and time first (fallback to ID)
      items.sort((a, b) {
        final dtA = _parseDateTime(a.newsCreatedDate, '');
        final dtB = _parseDateTime(b.newsCreatedDate, '');
        final cmp = dtB.compareTo(dtA);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });
      if (mounted) {
        setState(() {
          _newsItems = items;
          _cacheBuster = DateTime.now().millisecondsSinceEpoch;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load news stories: $e';
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredItems = _newsItems.where((item) {
        final matchesSearch = _searchQuery.isEmpty ||
            item.newsHeadlines.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.newsContent.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesCategory = true;
        if (_selectedCategoryFilter == 'All') {
          matchesCategory = true;
        } else if (_selectedCategoryFilter == 'Active') {
          matchesCategory = item.newsStatus.toLowerCase() == 'active';
        } else if (_selectedCategoryFilter == 'Inactive') {
          matchesCategory = item.newsStatus.toLowerCase() == 'inactive';
        } else {
          matchesCategory = item.newsHeadlines == _selectedCategoryFilter;
        }

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _refreshNews() async {
    await _fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _refreshNews,
        color: const Color(0xFF6C3CE1),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
            : Column(
                children: [
                  // Top Summary Stats Cards
                  _buildSummaryCards(),

                  // Search and Horizontal Category Chips Filter Bar
                  _buildSearchAndFilterBar(),

                  // News Cards Grid Content
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
                            _buildNewsCardsView(),
                          const SizedBox(height: 24),
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
    final totalCount = _newsItems.length;
    final activeCount = _newsItems.where((v) => v.newsStatus.toLowerCase() == 'active').length;
    final inactiveCount = _newsItems.where((v) => v.newsStatus.toLowerCase() == 'inactive').length;

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget card1 = _buildStatCard('Total Stories', totalCount.toString(), const Color(0xFF6C3CE1), Icons.newspaper_rounded);
    Widget card2 = _buildStatCard('Active Stories', activeCount.toString(), const Color(0xFF10B981), Icons.check_circle_outline_rounded);
    Widget card3 = _buildStatCard('Inactive Stories', inactiveCount.toString(), const Color(0xFFEF4444), Icons.cancel_outlined);

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
    final categories = uniqueCategories;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input (without filter funnel icon)
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
                      hintText: 'Search by headlines or content...',
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
                if (_searchQuery.isNotEmpty || _selectedCategoryFilter != 'All')
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal Scrollable Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildCategoryChip(category),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryName) {
    final isSelected = _selectedCategoryFilter == categoryName;
    final chipColor = isSelected ? const Color(0xFFF5F0FF) : Colors.white;
    final borderAndTextColor = isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade300;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryFilter = categoryName;
          _applyFilter();
        });
      },
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
        Row(
          children: [
            const Text(
              'News Feed',
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
                  'Add News',
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
            _errorMessage ?? 'No news stories found',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchNews,
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
            'No news stories match your criteria',
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

  Widget _buildStatusBadge(NewsModel item) {
    final status = item.newsStatus;
    final isActive = status.toLowerCase() == 'active';
    return InkWell(
      onTap: () => _toggleNewsStatus(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
            width: 0.5,
          ),
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

  Future<void> _toggleNewsStatus(NewsModel item) async {
    final originalStatus = item.newsStatus;
    final newStatus = originalStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';

    setState(() {
      item.newsStatus = newStatus;
    });

    try {
      final result = await _newsService.updateNews(
        id: item.id,
        headlines: item.newsHeadlines,
        content: item.newsContent,
        status: newStatus,
        image: null,
      );

      if (!result['success']) {
        setState(() {
          item.newsStatus = originalStatus;
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
              content: Text('${item.newsHeadlines} status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        item.newsStatus = originalStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Widget _buildNewsImage(String? imageUrl, {double size = 48, double borderRadius = 6}) {
    String? resolvedUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        resolvedUrl = imageUrl;
      } else {
        resolvedUrl = 'https://kmrlive.in/public/assets/images/News/$imageUrl';
      }
      resolvedUrl = '$resolvedUrl?t=$_cacheBuster';
    }

    if (resolvedUrl == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: size * 0.4),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: size * 0.4),
          );
        },
      ),
    );
  }

  // Cards View for Web (3 cards per row) and Mobile (1 card per row)
  Widget _buildNewsCardsView() {
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
              child: _buildNewsCardItem(item, index + 1),
            );
          }),
        );
      },
    );
  }

  Widget _buildNewsCardItem(NewsModel item, int displayIndex) {
    final isActive = item.newsStatus.toLowerCase() == 'active';

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNewsImage(item.newsImage, size: 56, borderRadius: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '$displayIndex. ${item.newsHeadlines}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildStatusBadge(item),
                            ],
                          ),
                          if (item.newsCreatedDate.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  item.newsCreatedDate,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.newsContent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                ),
                if (item.newsContent.length > 70) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showContentPopup(context, item.newsHeadlines, item.newsContent),
                    child: const Text(
                      'View Full story',
                      style: TextStyle(color: Color(0xFF6C3CE1), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditDialog(context, item),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F0FF),
                        foregroundColor: const Color(0xFF6C3CE1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContentPopup(BuildContext context, String headlines, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(headlines, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // "+ Add News" Dialog Flow
  void _showAddDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final headlinesCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    XFile? selectedImage;
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
                      child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF6C3CE1), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add News Story',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Define details for the news update',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Picker Box
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'News Image',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              setDialogState(() {
                                selectedImage = picked;
                              });
                            }
                          },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: selectedImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_upload_outlined, color: Color(0xFF6C3CE1), size: 36),
                                      const SizedBox(height: 8),
                                      Text('Click to upload image', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  )
                                : Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.file(
                                            File(selectedImage!.path),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withOpacity(0.6),
                                          radius: 16,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedImage = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Headlines input
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'Headlines *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: headlinesCtrl,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter News Headlines',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Headlines are required' : null,
                        ),
                        const SizedBox(height: 18),

                        // Content input
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'Content *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: contentCtrl,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter News Content Story...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Content is required' : null,
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
                            setDialogState(() => isSaving = true);

                            final res = await _newsService.createNews(
                              headlines: headlinesCtrl.text.trim(),
                              content: contentCtrl.text.trim(),
                              image: selectedImage,
                            );

                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              Navigator.pop(context); // Close dialog

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'News story created successfully', style: const TextStyle(color: Colors.white)),
                                  backgroundColor: res['success'] ? Colors.green : Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              if (res['success']) {
                                _fetchNews(); // Refresh screen
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
                      : const Text('Create News', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // "Edit News" Dialog Flow
  void _showEditDialog(BuildContext context, NewsModel item) {
    final formKey = GlobalKey<FormState>();
    final headlinesCtrl = TextEditingController(text: item.newsHeadlines);
    final contentCtrl = TextEditingController(text: item.newsContent);
    String newsStatus = item.newsStatus;
    XFile? selectedImage;
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
                          const Text(
                            'Edit News Story',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.newsHeadlines,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // News Status Master Card
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'News Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: newsStatus == 'Active' ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: newsStatus == 'Active' ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  newsStatus == 'Active' ? 'Status: Active' : 'Status: Inactive',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: newsStatus == 'Active' ? const Color(0xFF047857) : const Color(0xFFBE123C),
                                  ),
                                ),
                                Switch(
                                  value: newsStatus == 'Active',
                                  activeColor: const Color(0xFF10B981),
                                  activeTrackColor: const Color(0xFFD1FAE5),
                                  inactiveThumbColor: const Color(0xFFEF4444),
                                  inactiveTrackColor: const Color(0xFFFEE2E2),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      newsStatus = val ? 'Active' : 'Inactive';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Image Picker Box
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'News Image',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              setDialogState(() {
                                selectedImage = picked;
                              });
                            }
                          },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: selectedImage != null
                                ? Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.file(
                                            File(selectedImage!.path),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withOpacity(0.6),
                                          radius: 16,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedImage = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : item.newsImage != null && item.newsImage!.isNotEmpty
                                    ? Row(
                                        children: [
                                          const SizedBox(width: 12),
                                          _buildNewsImage(item.newsImage, size: 90, borderRadius: 12),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Has Current Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                const SizedBox(height: 4),
                                                Text('Tap to change...', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.cloud_upload_outlined, color: Color(0xFF6C3CE1), size: 36),
                                          const SizedBox(height: 8),
                                          Text('Click to upload image', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Headlines input
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'Headlines *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: headlinesCtrl,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter News Headlines',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Headlines are required' : null,
                        ),
                        const SizedBox(height: 18),

                        // Content input
                        const Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'Content *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: contentCtrl,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter News Content Story...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 1.5)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Content is required' : null,
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
                            setDialogState(() => isSaving = true);

                            final res = await _newsService.updateNews(
                              id: item.id,
                              headlines: headlinesCtrl.text.trim(),
                              content: contentCtrl.text.trim(),
                              status: newsStatus,
                              image: selectedImage,
                            );

                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                              Navigator.pop(context); // Close dialog

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'News story updated successfully', style: const TextStyle(color: Colors.white)),
                                  backgroundColor: res['success'] ? Colors.green : Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              if (res['success']) {
                                _fetchNews(); // Refresh screen
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