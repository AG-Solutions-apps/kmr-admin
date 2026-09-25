import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krm_admin/models/category_model.dart';
import 'package:krm_admin/models/slider_model.dart';
import 'package:krm_admin/services/category_service.dart';
import 'package:krm_admin/services/slider_service.dart';

class AppSliderScreen extends StatefulWidget {
  const AppSliderScreen({super.key});

  @override
  State<AppSliderScreen> createState() => _AppSliderScreenState();
}

class _AppSliderScreenState extends State<AppSliderScreen> {
  final SliderService _sliderService = SliderService();
  final CategoryService _categoryService = CategoryService();
  final ImagePicker _picker = ImagePicker();

  List<SliderModel> _sliders = [];
  List<SliderModel> _filteredSliders = [];
  List<String> _categoryOptions = ['Gold Rates', 'Silver Rates', 'Bullion', 'General'];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedStatusFilter = 'All'; // 'All', 'Active', 'Inactive'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final slidersFuture = _sliderService.fetchSliderList();
      final categoriesFuture = _categoryService.fetchCategories();

      final results = await Future.wait([slidersFuture, categoriesFuture]);

      final sliders = results[0] as List<SliderModel>;
      final categories = results[1] as List<CategoryModel>;

      if (mounted) {
        setState(() {
          _sliders = sliders;
          if (categories.isNotEmpty) {
            _categoryOptions = categories
                .map((c) => c.categoryName.trim())
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList();
          }
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load app sliders: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredSliders = _sliders.where((item) {
        final matchesSearch = (item.sliderUrl ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (item.sliderType ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (item.sliderCategory ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesStatus = _selectedStatusFilter == 'All' ||
            (_selectedStatusFilter == 'Active' && item.isActive) ||
            (_selectedStatusFilter == 'Inactive' && !item.isActive);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  int get _activeCount => _sliders.where((s) => s.isActive).length;
  int get _inactiveCount => _sliders.where((s) => !s.isActive).length;

  // -------------------------------------------------------------
  // VIEW SLIDER DETAIL MODAL (panel-fetch-slider-by-id/{id})
  // -------------------------------------------------------------
  void _showSliderDetailModal(int id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C3CE1)),
      ),
    );

    final slider = await _sliderService.fetchSliderById(id);

    if (mounted) {
      Navigator.pop(context); // Close loading indicator

      if (slider == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load slider details.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) {
          final width = MediaQuery.of(context).size.width;
          final imgUrl = slider.formattedImageUrl;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: width > 650 ? 580 : width * 0.9,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header title with close icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'App Banner / Slider Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Slider Banner Image Header
                    if (imgUrl != null && imgUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imgUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(Icons.view_carousel_rounded, size: 48, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(Icons.view_carousel_rounded, size: 48, color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Category & Status Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slider.sliderType ?? 'Home Banner',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C3CE1).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Category: ${slider.sliderCategory ?? "N/A"}',
                                  style: const TextStyle(color: Color(0xFF6C3CE1), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: slider.isActive ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: slider.isActive ? Colors.green.shade200 : Colors.red.shade200,
                            ),
                          ),
                          child: Text(
                            slider.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: slider.isActive ? Colors.green.shade700 : Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    const Text(
                      'Target Link / Action URL:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      (slider.sliderUrl != null && slider.sliderUrl!.isNotEmpty)
                          ? slider.sliderUrl!
                          : 'No external URL attached',
                      style: TextStyle(
                        fontSize: 14,
                        color: (slider.sliderUrl != null && slider.sliderUrl!.isNotEmpty) ? Colors.blue.shade700 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Info Metadata Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Slider ID:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              Text('#${slider.id}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (slider.createdAt != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Created Timestamp:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Text(slider.createdAt!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }

  // -------------------------------------------------------------
  // CREATE SLIDER POPUP DIALOG (panel-create-slider)
  // -------------------------------------------------------------
  void _showCreateSliderModal() {
    final formKey = GlobalKey<FormState>();
    final urlController = TextEditingController();

    String selectedType = 'Home Banner';
    String selectedCategory = _categoryOptions.isNotEmpty ? _categoryOptions.first : 'General';

    XFile? selectedImageFile;
    Uint8List? webImageBytes;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final width = MediaQuery.of(context).size.width;
            final isCategoryBanner = selectedType == 'Category Banner';

            // Prepare categories list safely
            List<String> availableCategories = List.from(_categoryOptions);
            if (!availableCategories.contains(selectedCategory)) {
              availableCategories.insert(0, selectedCategory);
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 10,
              backgroundColor: Colors.white,
              child: Container(
                width: width > 650 ? 560 : width * 0.92,
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C3CE1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.view_carousel_rounded, color: Color(0xFF6C3CE1), size: 26),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create App Banner / Slider',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Broadcast banner slider on user mobile app',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Slider Type Dropdown (Home Banner / Category Banner)
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Slider Type *',
                            prefixIcon: const Icon(Icons.view_carousel_outlined, color: Color(0xFF6C3CE1)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Home Banner',
                              child: Text('Home Banner'),
                            ),
                            DropdownMenuItem(
                              value: 'Category Banner',
                              child: Text('Category Banner'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedType = val;
                              });
                            }
                          },
                          validator: (v) => (v == null || v.isEmpty) ? 'Please select slider type' : null,
                        ),
                        const SizedBox(height: 20),

                        // Slider Category Dropdown (Disabled when Home Banner, Enabled when Category Banner)
                        DropdownButtonFormField<String>(
                          initialValue: isCategoryBanner ? selectedCategory : null,
                          disabledHint: Row(
                            children: [
                              Icon(Icons.block_rounded, size: 18, color: Colors.grey.shade400),
                              const SizedBox(width: 8),
                              Text('Not Applicable for Home Banner', style: TextStyle(color: Colors.grey.shade500, fontSize: 13.5)),
                            ],
                          ),
                          hint: const Text('Select Category'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isCategoryBanner ? Colors.black87 : Colors.grey,
                          ),
                          decoration: InputDecoration(
                            labelText: isCategoryBanner ? 'Slider Category *' : 'Slider Category (Disabled for Home Banner)',
                            prefixIcon: Icon(
                              Icons.category_outlined,
                              color: isCategoryBanner ? const Color(0xFF6C3CE1) : Colors.grey.shade400,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 2),
                            ),
                            filled: !isCategoryBanner,
                            fillColor: isCategoryBanner ? Colors.transparent : Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: isCategoryBanner
                              ? availableCategories.map((catName) {
                                  return DropdownMenuItem<String>(
                                    value: catName,
                                    child: Text(catName),
                                  );
                                }).toList()
                              : null,
                          onChanged: isCategoryBanner
                              ? (val) {
                                  if (val != null) {
                                    setModalState(() => selectedCategory = val);
                                  }
                                }
                              : null, // Disables dropdown when Home Banner
                          validator: (v) {
                            if (isCategoryBanner && (v == null || v.isEmpty)) {
                              return 'Please select slider category';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Target Action URL Field
                        TextFormField(
                          controller: urlController,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            labelText: 'Target Action URL (Optional)',
                            hintText: 'https://kmrlive.in/rates',
                            prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF6C3CE1)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Direct Image File Upload Picker Area
                        const Text(
                          'Slider Banner Image File *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),

                        if (selectedImageFile == null)
                          InkWell(
                            onTap: () async {
                              final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                              if (picked != null) {
                                final bytes = kIsWeb ? await picked.readAsBytes() : null;
                                setModalState(() {
                                  selectedImageFile = picked;
                                  webImageBytes = bytes;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 130,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF6C3CE1).withValues(alpha: 0.3), width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C3CE1).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF6C3CE1), size: 28),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Click to Select Banner Image File',
                                    style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Supports PNG, JPG, JPEG',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: kIsWeb && webImageBytes != null
                                    ? Image.memory(webImageBytes!, height: 160, width: double.infinity, fit: BoxFit.cover)
                                    : Image.network(
                                        selectedImageFile!.path,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Container(
                                          height: 120,
                                          color: Colors.purple.shade50,
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.image_rounded, color: Color(0xFF6C3CE1)),
                                                const SizedBox(width: 8),
                                                Text(selectedImageFile!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      selectedImageFile = null;
                                      webImageBytes = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 28),

                        // Action Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;

                                    setModalState(() => isSubmitting = true);

                                    final finalCategory = isCategoryBanner ? selectedCategory : 'Home Banner';

                                    final result = await _sliderService.createSlider(
                                      sliderUrl: urlController.text.trim(),
                                      sliderType: selectedType,
                                      sliderCategory: finalCategory,
                                      imageFile: selectedImageFile,
                                      webImageBytes: webImageBytes,
                                    );

                                    if (context.mounted) {
                                      setModalState(() => isSubmitting = false);
                                      if (result['status'] == true) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(result['message'] ?? 'App Slider created successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _loadData();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(result['message'] ?? 'Failed to create app slider.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C3CE1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Publish App Slider',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // EDIT SLIDER POPUP DIALOG (panel-update-slider/{id})
  // -------------------------------------------------------------
  void _showEditSliderModal(SliderModel slider) {
    final formKey = GlobalKey<FormState>();
    final urlController = TextEditingController(text: slider.sliderUrl);

    String selectedType = (slider.sliderType == 'Category Banner') ? 'Category Banner' : 'Home Banner';
    String selectedCategory = slider.sliderCategory ?? (_categoryOptions.isNotEmpty ? _categoryOptions.first : 'General');
    bool isActive = slider.isActive;

    XFile? selectedImageFile;
    Uint8List? webImageBytes;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final width = MediaQuery.of(context).size.width;
            final imgUrl = slider.formattedImageUrl;
            final isCategoryBanner = selectedType == 'Category Banner';

            // Prepare categories list safely
            List<String> availableCategories = List.from(_categoryOptions);
            if (!availableCategories.contains(selectedCategory)) {
              availableCategories.insert(0, selectedCategory);
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 10,
              backgroundColor: Colors.white,
              child: Container(
                width: width > 650 ? 560 : width * 0.92,
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.blue, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit App Slider #${slider.id}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Update type, category, target URL, image file or status',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Slider Type Dropdown (Home Banner / Category Banner)
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Slider Type *',
                            prefixIcon: const Icon(Icons.view_carousel_outlined, color: Color(0xFF6C3CE1)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Home Banner',
                              child: Text('Home Banner'),
                            ),
                            DropdownMenuItem(
                              value: 'Category Banner',
                              child: Text('Category Banner'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedType = val;
                              });
                            }
                          },
                          validator: (v) => (v == null || v.isEmpty) ? 'Please select slider type' : null,
                        ),
                        const SizedBox(height: 20),

                        // Slider Category Dropdown (Disabled when Home Banner, Enabled when Category Banner)
                        DropdownButtonFormField<String>(
                          initialValue: isCategoryBanner ? selectedCategory : null,
                          disabledHint: Row(
                            children: [
                              Icon(Icons.block_rounded, size: 18, color: Colors.grey.shade400),
                              const SizedBox(width: 8),
                              Text('Not Applicable for Home Banner', style: TextStyle(color: Colors.grey.shade500, fontSize: 13.5)),
                            ],
                          ),
                          hint: const Text('Select Category'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isCategoryBanner ? Colors.black87 : Colors.grey,
                          ),
                          decoration: InputDecoration(
                            labelText: isCategoryBanner ? 'Slider Category *' : 'Slider Category (Disabled for Home Banner)',
                            prefixIcon: Icon(
                              Icons.category_outlined,
                              color: isCategoryBanner ? const Color(0xFF6C3CE1) : Colors.grey.shade400,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 2),
                            ),
                            filled: !isCategoryBanner,
                            fillColor: isCategoryBanner ? Colors.transparent : Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: isCategoryBanner
                              ? availableCategories.map((catName) {
                                  return DropdownMenuItem<String>(
                                    value: catName,
                                    child: Text(catName),
                                  );
                                }).toList()
                              : null,
                          onChanged: isCategoryBanner
                              ? (val) {
                                  if (val != null) {
                                    setModalState(() => selectedCategory = val);
                                  }
                                }
                              : null, // Disables dropdown when Home Banner
                          validator: (v) {
                            if (isCategoryBanner && (v == null || v.isEmpty)) {
                              return 'Please select slider category';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Target Action URL Field
                        TextFormField(
                          controller: urlController,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            labelText: 'Target Action URL (Optional)',
                            prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF6C3CE1)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6C3CE1), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Status Selection Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    isActive ? 'Status: Active Banner' : 'Status: Inactive / Disabled',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Switch(
                                value: isActive,
                                activeTrackColor: const Color(0xFF6C3CE1),
                                onChanged: (val) {
                                  setModalState(() => isActive = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Direct Image File Upload Picker Area
                        const Text(
                          'Slider Banner Image File',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),

                        if (selectedImageFile != null)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: kIsWeb && webImageBytes != null
                                    ? Image.memory(webImageBytes!, height: 160, width: double.infinity, fit: BoxFit.cover)
                                    : Image.network(selectedImageFile!.path, height: 160, width: double.infinity, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      selectedImageFile = null;
                                      webImageBytes = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (imgUrl != null && imgUrl.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  imgUrl,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    height: 100,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                  if (picked != null) {
                                    final bytes = kIsWeb ? await picked.readAsBytes() : null;
                                    setModalState(() {
                                      selectedImageFile = picked;
                                      webImageBytes = bytes;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF6C3CE1)),
                                label: const Text('Change Image File', style: TextStyle(color: Color(0xFF6C3CE1))),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: const BorderSide(color: Color(0xFF6C3CE1)),
                                ),
                              ),
                            ],
                          )
                        else
                          InkWell(
                            onTap: () async {
                              final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                              if (picked != null) {
                                final bytes = kIsWeb ? await picked.readAsBytes() : null;
                                setModalState(() {
                                  selectedImageFile = picked;
                                  webImageBytes = bytes;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF6C3CE1).withValues(alpha: 0.3), width: 1.5),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_outlined, color: Color(0xFF6C3CE1), size: 28),
                                  SizedBox(height: 6),
                                  Text(
                                    'Select New Image File',
                                    style: TextStyle(color: Color(0xFF6C3CE1), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),

                        // Action Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;

                                    setModalState(() => isSubmitting = true);

                                    final finalCategory = isCategoryBanner ? selectedCategory : 'Home Banner';

                                    final result = await _sliderService.updateSlider(
                                      id: slider.id,
                                      sliderUrl: urlController.text.trim(),
                                      sliderType: selectedType,
                                      sliderCategory: finalCategory,
                                      sliderStatus: isActive ? 1 : 0,
                                      imageFile: selectedImageFile,
                                      webImageBytes: webImageBytes,
                                    );

                                    if (context.mounted) {
                                      setModalState(() => isSubmitting = false);
                                      if (result['status'] == true) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(result['message'] ?? 'App Slider updated successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _loadData();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(result['message'] ?? 'Failed to update app slider.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C3CE1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Save Slider Changes',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Quick toggle status action
  void _toggleSliderStatus(SliderModel slider) async {
    final newStatus = slider.isActive ? 0 : 1;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newStatus == 1 ? 'Activating banner...' : 'Deactivating banner...'),
        duration: const Duration(seconds: 1),
      ),
    );

    final result = await _sliderService.updateSlider(
      id: slider.id,
      sliderUrl: slider.sliderUrl ?? '',
      sliderType: slider.sliderType ?? 'Home Banner',
      sliderCategory: slider.sliderCategory ?? 'Home Banner',
      sliderStatus: newStatus,
    );

    if (mounted) {
      if (result['status'] == true) {
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to change status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Responsive columns: Desktop 3, Tablet 2, Mobile 1
    int crossAxisCount = 3;
    if (width <= 650) {
      crossAxisCount = 1;
    } else if (width <= 1024) {
      crossAxisCount = 2;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(width > 600 ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and Create button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Sliders & Banners Hub',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage & dynamic publish image banners to mobile application',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateSliderModal,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Create App Slider', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top Stats Summary Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Sliders',
                    count: _sliders.length.toString(),
                    icon: Icons.view_carousel_rounded,
                    color: const Color(0xFF6C3CE1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Active Banners',
                    count: _activeCount.toString(),
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Inactive Banners',
                    count: _inactiveCount.toString(),
                    icon: Icons.pause_circle_rounded,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Toolbar Search & Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Search box
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        _searchQuery = val;
                        _applyFilter();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by type, category or action URL...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status Filter pills
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: ['All', 'Active', 'Inactive'].map((status) {
                        final isSelected = _selectedStatusFilter == status;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedStatusFilter = status;
                              _applyFilter();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF6C3CE1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.black54,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Refresh Button
                  IconButton(
                    onPressed: _loadData,
                    tooltip: 'Refresh Sliders',
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C3CE1)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content Body Area
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C3CE1)),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 15)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C3CE1)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredSliders.isEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  margin: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.view_carousel_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No App Sliders Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No result matching "$_searchQuery"'
                            : 'Click "Create App Slider" button above to add a new banner.',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Responsive Grid View of Slider Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: width > 1400 ? 1.25 : (width > 650 ? 1.15 : 1.10),
                ),
                itemCount: _filteredSliders.length,
                itemBuilder: (context, index) {
                  final slider = _filteredSliders[index];
                  return _buildSliderCard(slider);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Stat summary card
  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Individual App Slider Card
  Widget _buildSliderCard(SliderModel slider) {
    final imgUrl = slider.formattedImageUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image Header with Interactive Clickable Status Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: (imgUrl != null && imgUrl.isNotEmpty)
                    ? Image.network(
                        imgUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.view_carousel_rounded, size: 44, color: Colors.white),
                          ),
                        ),
                      )
                    : Container(
                        height: 140,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.view_carousel_rounded, size: 44, color: Colors.white),
                        ),
                      ),
              ),
              // Clickable Active / Inactive Status Badge Overlay
              Positioned(
                top: 12,
                right: 12,
                child: Tooltip(
                  message: 'Click to toggle Status',
                  child: InkWell(
                    onTap: () => _toggleSliderStatus(slider),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: slider.isActive ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slider.isActive ? 'Active' : 'Inactive',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // ID Tag Overlay
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${slider.id}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          // Compact Card Content Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          slider.sliderType ?? 'Home Banner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C3CE1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slider.sliderCategory ?? 'General',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6C3CE1)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (slider.sliderUrl != null && slider.sliderUrl!.isNotEmpty)
                        ? 'URL: ${slider.sliderUrl}'
                        : 'No action link attached',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  if (slider.createdAt != null)
                    Text(
                      'Created: ${slider.createdAt}',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Bottom Action Bar: ONLY 2 Buttons (View Details & Edit)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. View Details Button
                IconButton(
                  onPressed: () => _showSliderDetailModal(slider.id),
                  tooltip: 'View Banner Details',
                  icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF6C3CE1), size: 20),
                ),

                // 2. Edit Button
                ElevatedButton.icon(
                  onPressed: () => _showEditSliderModal(slider),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE1).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF6C3CE1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
