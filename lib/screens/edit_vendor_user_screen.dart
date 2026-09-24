import 'package:flutter/material.dart';
import 'package:krm_admin/services/vendor_user_service.dart';

class EditVendorUserScreen extends StatefulWidget {
  final int userId;

  const EditVendorUserScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EditVendorUserScreen> createState() => _EditVendorUserScreenState();
}

class _EditVendorUserScreenState extends State<EditVendorUserScreen> {
  final VendorUserService _vendorUserService = VendorUserService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _selectedStatus = 'Active';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = await _vendorUserService.fetchVendorUserById(widget.userId);

    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      // Populate form fields
      _nameController.text = user.name;
      _mobileController.text = user.mobile;
      _emailController.text = user.email;
      _remarksController.text = user.remarks ?? '';
      _selectedStatus = (user.status == 'Active' || user.status == 'Inactive') ? user.status : 'Active';
    } else {
      setState(() {
        _errorMessage = 'Failed to load user data. Please try again.';
      });
    }
  }

  Future<void> _updateVendorUser() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await _vendorUserService.updateVendorUser(
      id: widget.userId,
      name: _nameController.text,
      mobile: _mobileController.text,
      email: _emailController.text,
      remarks: _remarksController.text,
      status: _selectedStatus,
    );

    setState(() {
      _isSaving = false;
    });

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        title: const Text(
          'Edit Vendor User',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C3CE1)),
                  SizedBox(height: 16),
                  Text('Loading user data...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Name Field
                        const Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'Name *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter Name',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // Mobile Field
                        const Row(
                          children: [
                            Icon(Icons.phone_iphone_rounded, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'Mobile *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter Mobile',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter mobile number';
                            }
                            if (value.length < 10) {
                              return 'Enter valid mobile number (minimum 10 digits)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // Email Field
                        const Row(
                          children: [
                            Icon(Icons.mail_outline_rounded, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'Email *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter Email',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Enter valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // Remarks Field
                        const Row(
                          children: [
                            Icon(Icons.notes_rounded, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'Remarks *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _remarksController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter Remarks',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter remarks';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // Status Field
                        const Row(
                          children: [
                            Icon(Icons.toggle_on_outlined, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'Status *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _selectedStatus == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(_selectedStatus, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                              Switch(
                                value: _selectedStatus == 'Active',
                                activeColor: const Color(0xFF6C3CE1),
                                activeTrackColor: const Color(0xFFE9DEFF),
                                onChanged: (bool value) {
                                  setState(() {
                                    _selectedStatus = value ? 'Active' : 'Inactive';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Update Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _updateVendorUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C3CE1),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: const Color(0xFF6C3CE1).withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Update Vendor User',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _remarksController.dispose();
    super.dispose();
  }
}