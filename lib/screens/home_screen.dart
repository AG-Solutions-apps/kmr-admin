import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krm_admin/services/auth_service.dart';
import 'package:krm_admin/models/user_model.dart';
import 'package:krm_admin/screens/login_screen.dart';
import 'package:krm_admin/screens/category_screen.dart';
import 'package:krm_admin/screens/subcategory_screen.dart';
import 'package:krm_admin/screens/vendor_screen.dart';
import 'package:krm_admin/screens/vendor_user_screen.dart';
import 'package:krm_admin/screens/notification_screen.dart';
import 'package:krm_admin/screens/live_screen.dart';
import 'package:krm_admin/screens/rates_screen.dart';
import 'package:krm_admin/screens/spot_screen.dart';
import 'package:krm_admin/screens/news_screen.dart';
import 'package:krm_admin/services/category_service.dart';
import 'package:krm_admin/services/sub_category_service.dart';
import 'package:krm_admin/services/vendor_service.dart';
import 'package:krm_admin/services/news_service.dart';
import 'package:krm_admin/models/category_model.dart';
import 'package:krm_admin/models/sub_category_model.dart';
import 'package:krm_admin/models/vendor_model.dart';
import 'package:krm_admin/models/vendor_spot_rate_model.dart';
import 'package:krm_admin/models/news_model.dart';
import 'package:krm_admin/screens/profile_screen.dart';
import 'package:krm_admin/screens/slider_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  UserModel? _userData;
  int _selectedIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _titles = [
    'Dashboard',
    'Category',
    'SubCategory',
    'Vendor',
    'Vendor User',
    'Notification',
    'Live',
    'Rates',
    'Spot',
    'News',
    'App Slider',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    UserModel? user = await _authService.getUserData();
    setState(() {
      _userData = user;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 240,
              child: _buildPremiumDrawerContent(isDesktop: true),
            ),
            Expanded(
              child: Scaffold(
                backgroundColor: Colors.grey.shade50,
                appBar: _buildPremiumAppBar(isDesktop: true),
                body: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildPremiumAppBar(isDesktop: false),
        drawer: _buildPremiumDrawer(),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildBody(),
        ),
        bottomNavigationBar: _buildPremiumBottomBar(),
      ),
    );
  }

  Widget? _buildPremiumBottomBar() {
    final items = [
      {'title': 'Live', 'icon': Icons.live_tv_rounded, 'index': 6},
      {'title': 'Rates', 'icon': Icons.attach_money_rounded, 'index': 7},
      {'title': 'Spot', 'icon': Icons.bolt_rounded, 'index': 8},
      {'title': 'News', 'icon': Icons.newspaper_rounded, 'index': 9},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final idx = item['index'] as int;
            final isSelected = _selectedIndex == idx;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = idx;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF5F0FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade500,
                      size: 20,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: Color(0xFF6C3CE1),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar({bool isDesktop = false}) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6C3CE1),
              Color(0xFF8B5CF6),
              Color(0xFFA78BFA),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C3CE1).withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                if (!isDesktop) ...[
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _titles[_selectedIndex],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Welcome back, ${(_userData?.name != null && _userData!.name.isNotEmpty) ? _userData!.name.split(' ').first : 'Admin'}!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    color: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'logout') {
                        _logout();
                      } else if (value == 'profile') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded, color: Colors.grey),
                            SizedBox(width: 12),
                            Text('Profile'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.red.shade400),
                            const SizedBox(width: 12),
                            Text(
                              'Logout',
                              style: TextStyle(color: Colors.red.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumDrawer() {
    return Drawer(
      elevation: 0,
      child: _buildPremiumDrawerContent(isDesktop: false),
    );
  }

  Widget _buildPremiumDrawerContent({bool isDesktop = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header matching top navbar gradient and height
          Container(
            width: double.infinity,
            height: isDesktop ? 80 : null,
            padding: isDesktop
                ? const EdgeInsets.symmetric(horizontal: 16)
                : const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6C3CE1),
                  Color(0xFF8B5CF6),
                  Color(0xFFA78BFA),
                ],
              ),
            ),
            child: isDesktop
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Text(
                            (_userData?.name != null && _userData!.name.isNotEmpty)
                                ? _userData!.name[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C3CE1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _userData?.name ?? 'Admin User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _userData?.email ?? 'admin@mail.com',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: Text(
                            (_userData?.name != null && _userData!.name.isNotEmpty)
                                ? _userData!.name[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C3CE1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userData?.name ?? 'Admin User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userData?.email ?? 'admin@mail.com',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          // Menu Items - Always open sections (No dropdowns)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                _buildPremiumMenuItem(
                  'Dashboard',
                  Icons.grid_view_rounded,
                  0,
                  isSelected: _selectedIndex == 0,
                  isDesktop: isDesktop,
                ),
                const SizedBox(height: 8),
                
                // Master Section (Always Open)
                _buildSectionHeader('Master', Icons.dashboard_customize_rounded),
                _buildPremiumMenuItem('Category', Icons.category_rounded, 1, isChild: true, isSelected: _selectedIndex == 1, isDesktop: isDesktop),
                _buildPremiumMenuItem('SubCategory', Icons.list_alt_rounded, 2, isChild: true, isSelected: _selectedIndex == 2, isDesktop: isDesktop),
                _buildPremiumMenuItem('Vendor', Icons.storefront_rounded, 3, isChild: true, isSelected: _selectedIndex == 3, isDesktop: isDesktop),
                _buildPremiumMenuItem('Vendor User', Icons.people_alt_rounded, 4, isChild: true, isSelected: _selectedIndex == 4, isDesktop: isDesktop),
                
                // Super Admin Exclusive Section (user_type == 4)
                if (_userData?.isSuperAdmin == true) ...[
                  const SizedBox(height: 8),
                  _buildSectionHeader('Super Admin Tools', Icons.admin_panel_settings_rounded),
                  _buildPremiumMenuItem('Notification', Icons.notifications_active_rounded, 5, isChild: true, isSelected: _selectedIndex == 5, isDesktop: isDesktop),
                  _buildPremiumMenuItem('App Slider', Icons.view_carousel_rounded, 10, isChild: true, isSelected: _selectedIndex == 10, isDesktop: isDesktop),
                ],

                const SizedBox(height: 8),
                
                // App Update Section (Always Open)
                _buildSectionHeader('App Update', Icons.system_update_rounded),
                _buildPremiumMenuItem('Live', Icons.live_tv_rounded, 6, isChild: true, isSelected: _selectedIndex == 6, isDesktop: isDesktop),
                _buildPremiumMenuItem('Rates', Icons.attach_money_rounded, 7, isChild: true, isSelected: _selectedIndex == 7, isDesktop: isDesktop),
                _buildPremiumMenuItem('Spot', Icons.bolt_rounded, 8, isChild: true, isSelected: _selectedIndex == 8, isDesktop: isDesktop),
                _buildPremiumMenuItem('News', Icons.newspaper_rounded, 9, isChild: true, isSelected: _selectedIndex == 9, isDesktop: isDesktop),
                
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                _buildPremiumMenuItem(
                  'Logout',
                  Icons.logout_rounded,
                  -1,
                  isLogout: true,
                  isDesktop: isDesktop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFF6C3CE1),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C3CE1),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumMenuItem(
    String title,
    IconData icon,
    int index, {
    bool isChild = false,
    bool isSelected = false,
    bool isLogout = false,
    bool isDesktop = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFFF5F0FF) : Colors.transparent,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C3CE1).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isLogout
                ? Colors.red.shade400
                : (isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade600),
            size: isChild ? 20 : 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isLogout
                ? Colors.red.shade400
                : (isSelected ? const Color(0xFF6C3CE1) : Colors.grey.shade700),
            fontSize: isChild ? 14 : 15,
            letterSpacing: 0.2,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C3CE1),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: () {
          if (isLogout) {
            _logout();
          } else {
            setState(() {
              _selectedIndex = index;
            });
            if (!isDesktop) {
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    final bool isSuperAdmin = _userData?.isSuperAdmin ?? false;

    switch (_selectedIndex) {
      case 0:
        return DashboardContent(
          onNavigate: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          isSuperAdmin: isSuperAdmin,
        );
      case 1:
        return const CategoryScreen();
      case 2:
        return const SubCategoryScreen();
      case 3:
        return const VendorScreen();
      case 4:
        return const VendorUserScreen();
      case 5:
        return isSuperAdmin
            ? const NotificationScreen()
            : _buildAccessDeniedView('Notification Management');
      case 6:
        return const LiveScreen();
      case 7:
        return const RatesScreen();
      case 8:
        return const SpotScreen();
      case 9:
        return const NewsScreen();
      case 10:
        return isSuperAdmin
            ? const AppSliderScreen()
            : _buildAccessDeniedView('App Slider Banner Management');
      default:
        return DashboardContent(
          onNavigate: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          isSuperAdmin: isSuperAdmin,
        );
    }
  }

  Widget _buildAccessDeniedView(String featureName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded, size: 50, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              'Access Denied',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Only Super Admin (user_type: 4) can access $featureName.',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3CE1),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _selectedIndex = 0;
                });
              },
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

// Premium Dashboard Content
class DashboardContent extends StatefulWidget {
  final Function(int) onNavigate;
  final bool isSuperAdmin;
  const DashboardContent({super.key, required this.onNavigate, this.isSuperAdmin = false});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> with SingleTickerProviderStateMixin {
  final CategoryService _categoryService = CategoryService();
  final SubCategoryService _subCategoryService = SubCategoryService();
  final VendorService _vendorService = VendorService();
  final NewsService _newsService = NewsService();

  List<CategoryModel> _categories = [];
  List<SubCategoryModel> _subcategories = [];
  List<VendorModel> _vendors = [];
  List<VendorSpotRateModel> _spotRates = [];
  List<NewsModel> _news = [];

  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _categoryService.fetchCategories(),
        _subCategoryService.fetchSubCategories(),
        _vendorService.fetchVendors(),
        _vendorService.fetchVendorSpotRatesList(),
        _newsService.fetchNewsList(),
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0] as List<CategoryModel>;
          _subcategories = results[1] as List<SubCategoryModel>;
          _vendors = results[2] as List<VendorModel>;
          _spotRates = results[3] as List<VendorSpotRateModel>;
          _news = results[4] as List<NewsModel>;
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load dashboard data: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: const Color(0xFF6C3CE1),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading dashboard...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadDashboardData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C3CE1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Grid
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildStatsGrid(),
                          ),
                          const SizedBox(height: 28),

                          // Quick Actions
                          _buildQuickActions(),
                          const SizedBox(height: 28),

                          // Recent News & Vendors
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth >= 700) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 6, child: _buildRecentNews()),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 5, child: _buildRecentVendors()),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    _buildRecentNews(),
                                    const SizedBox(height: 24),
                                    _buildRecentVendors(),
                                  ],
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'title': 'Categories', 'count': _categories.length.toString(), 'icon': Icons.category_rounded, 'color': const Color(0xFF6C3CE1), 'index': 1},
      {'title': 'SubCategories', 'count': _subcategories.length.toString(), 'icon': Icons.list_alt_rounded, 'color': const Color(0xFFF59E0B), 'index': 2},
      {'title': 'Vendors', 'count': _vendors.length.toString(), 'icon': Icons.storefront_rounded, 'color': const Color(0xFF10B981), 'index': 3},
      
      {'title': 'News', 'count': _news.length.toString(), 'icon': Icons.newspaper_rounded, 'color': const Color(0xFF06B6D4), 'index': 9},
    ];

    final screenWidth = MediaQuery.of(context).size.width;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: screenWidth < 450 ? 2 : stats.length,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: screenWidth < 450 ? 1.0 : 1.15,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(
          stat['title'] as String,
          stat['count'] as String,
          stat['icon'] as IconData,
          stat['color'] as Color,
          stat['index'] as int,
        );
      },
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, int index) {
    return InkWell(
      onTap: () => widget.onNavigate(index),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(
                  Icons.arrow_outward_rounded,
                  color: Colors.grey.shade300,
                  size: 16,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'Add Category', 'subtitle': 'Create new categories', 'icon': Icons.add_circle_outline_rounded, 'color': const Color(0xFF6C3CE1), 'index': 1},
      {'title': 'Add Vendor', 'subtitle': 'Register new partner', 'icon': Icons.storefront_rounded, 'color': const Color(0xFF10B981), 'index': 3},
      if (widget.isSuperAdmin) ...[
        {'title': 'Notification', 'subtitle': 'Broadcast to users', 'icon': Icons.notifications_active_rounded, 'color': const Color(0xFFEC4899), 'index': 5},
        {'title': 'App Sliders', 'subtitle': 'Manage app banners', 'icon': Icons.view_carousel_rounded, 'color': const Color(0xFF8B5CF6), 'index': 10},
      ],
      {'title': 'Publish News', 'subtitle': 'Write live announcements', 'icon': Icons.campaign_outlined, 'color': const Color(0xFF06B6D4), 'index': 9},
      {'title': 'View Live', 'subtitle': 'Check live rates status', 'icon': Icons.sensors_rounded, 'color': const Color(0xFFF59E0B), 'index': 6},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final action = actions[index];
              final color = action['color'] as Color;
              return InkWell(
                onTap: () => widget.onNavigate(action['index'] as int),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action['title'] as String,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              action['subtitle'] as String,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentNews() {
    final recentNews = _news.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent News',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(9),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6C3CE1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentNews.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.newspaper_outlined, color: Colors.grey.shade300, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No news stories yet',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentNews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = recentNews[index];
                return _buildNewsItem(item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(NewsModel item) {
    final isActive = item.newsStatus.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: item.newsImage != null && item.newsImage!.isNotEmpty
                  ? Image.network(
                      item.newsImage!.startsWith('http')
                          ? item.newsImage!
                          : 'https://kmrlive.in/public/assets/images/News/${item.newsImage}',
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 68,
                        height: 68,
                        color: Colors.grey.shade100,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    )
                  : Container(
                      width: 68,
                      height: 68,
                      color: Colors.grey.shade100,
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.newsHeadlines,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item.newsStatus,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isActive ? const Color(0xFF047857) : const Color(0xFFC2410C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.grey.shade400,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.newsCreatedDate,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

  Widget _buildRecentVendors() {
    final recentVendors = _vendors.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Vendors',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(3),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6C3CE1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentVendors.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.storefront_outlined, color: Colors.grey.shade300, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No vendors registered',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentVendors.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vendor = recentVendors[index];
                return _buildVendorItem(vendor);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVendorItem(VendorModel vendor) {
    final isActive = vendor.vendorStatus.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF2FF) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: isActive ? const Color(0xFF4F46E5) : const Color(0xFFEA580C),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.vendorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vendor.vendorCategory,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                width: 1,
              ),
            ),
            child: Text(
              vendor.vendorStatus,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF047857) : const Color(0xFFBE123C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}