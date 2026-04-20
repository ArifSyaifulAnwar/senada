// add_emergency_contact_screen.dart (Updated with API integration)
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/Services/emergencycontactservice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddEmergencyContactScreen extends StatefulWidget {
  final String userId;
  final EmergencyContact? contactToEdit; // For edit mode

  const AddEmergencyContactScreen({
    super.key,
    required this.userId,
    this.contactToEdit,
  });

  @override
  _AddEmergencyContactScreenState createState() =>
      _AddEmergencyContactScreenState();
}

class _AddEmergencyContactScreenState extends State<AddEmergencyContactScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Form state
  String _selectedRelationship = '';
  bool _isPrimary = false;
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  // Relationship options
  List<String> _relationships = [];

  bool get isEditMode => widget.contactToEdit != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load categories first
    await _loadCategories();

    // If edit mode, populate fields
    if (isEditMode) {
      _populateEditData();
    }

    _controller.forward();
  }

  Future<void> _loadCategories() async {
    try {
      final service = EmergencyContactService();
      final response = await service.getCategories();

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        setState(() {
          _relationships = response.data!
              .map((category) => category.name)
              .toList();
          _isLoadingCategories = false;
        });
      } else {
        // Show error if API fails
        setState(() {
          _isLoadingCategories = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      response.message.isNotEmpty
                          ? response.message
                          : 'Gagal memuat kategori hubungan',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Coba Lagi',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _isLoadingCategories = true;
                  });
                  _loadCategories();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Terjadi kesalahan saat memuat kategori: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _isLoadingCategories = true;
                });
                _loadCategories();
              },
            ),
          ),
        );
      }
    }
  }

  void _populateEditData() {
    if (widget.contactToEdit != null) {
      final contact = widget.contactToEdit!;
      _nameController.text = contact.name;
      _phoneController.text = contact.phoneNumber;
      _emailController.text = contact.email ?? '';
      _addressController.text = contact.address ?? '';
      _selectedRelationship = contact.relationship;
      _isPrimary = contact.isPrimary;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Modern Input Decoration
  InputDecoration _buildModernInputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: const Color(0xFF007AFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[400]!, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      errorStyle: TextStyle(
        color: Colors.red[600],
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    if (value.length < 2) {
      return 'Nama minimal 2 karakter';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }
    // Remove all non-digit characters for validation
    String digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Nomor telepon tidak valid';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value != null && value.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Format email tidak valid';
      }
    }
    return null;
  }

  String? _validateRelationship(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pilih hubungan dengan kontak';
    }
    return null;
  }

  Future<void> _saveContact() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        ApiResponse<EmergencyContact> response;

        if (isEditMode) {
          // Update existing contact
          final service = EmergencyContactService();
          response = await service.updateEmergencyContact(
            id: widget.contactToEdit!.id,
            userId: widget.userId,
            name: _nameController.text.trim(),
            relationship: _selectedRelationship,
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            isPrimary: _isPrimary,
          );
        } else {
          // Create new contact
          final service = EmergencyContactService();
          response = await service.createEmergencyContact(
            userId: widget.userId,
            name: _nameController.text.trim(),
            relationship: _selectedRelationship,
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            isPrimary: _isPrimary,
          );
        }

        setState(() {
          _isLoading = false;
        });

        if (response.success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text(response.message),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          // Return to previous screen with success indicator
          Navigator.pop(context, true);
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text(response.message)),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Terjadi kesalahan: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isEditMode ? Icons.edit : Icons.person_add,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String title,
    required Widget child,
    String? description,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (description != null) ...[
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Kontak Darurat' : 'Tambah Kontak Darurat',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoadingCategories
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : _relationships.isEmpty
            ? _buildErrorLoadingWidget()
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildSectionHeader(
                        isEditMode
                            ? 'Edit Kontak Darurat'
                            : 'Kontak Darurat Baru',
                        isEditMode
                            ? 'Perbarui informasi kontak darurat'
                            : 'Tambahkan informasi kontak yang dapat dihubungi dalam keadaan darurat',
                      ),

                      // Nama Lengkap
                      _buildFormField(
                        title: 'Nama Lengkap',
                        description: 'Masukkan nama lengkap kontak darurat',
                        child: TextFormField(
                          controller: _nameController,
                          decoration: _buildModernInputDecoration(
                            labelText: 'Nama Lengkap',
                            hintText: 'Contoh: Dr. Sarah Johnson',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          validator: _validateName,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Hubungan
                      _buildFormField(
                        title: 'Hubungan',
                        description: 'Pilih hubungan Anda dengan kontak ini',
                        child: DropdownButtonFormField<String>(
                          value: _selectedRelationship.isEmpty
                              ? null
                              : _selectedRelationship,
                          decoration: _buildModernInputDecoration(
                            labelText: 'Hubungan',
                            prefixIcon: Icon(
                              Icons.family_restroom_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          items: _relationships.map((String relationship) {
                            return DropdownMenuItem<String>(
                              value: relationship,
                              child: Text(
                                relationship,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedRelationship = newValue ?? '';
                            });
                          },
                          validator: _validateRelationship,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),

                      // Nomor Telepon
                      _buildFormField(
                        title: 'Nomor Telepon',
                        description: 'Pastikan nomor dapat dihubungi 24 jam',
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: _buildModernInputDecoration(
                            labelText: 'Nomor Telepon',
                            hintText: '+62 812-3456-7890',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          validator: _validatePhone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-\s()]'),
                            ),
                          ],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Email (Opsional)
                      _buildFormField(
                        title: 'Email (Opsional)',
                        description: 'Email untuk komunikasi alternatif',
                        child: TextFormField(
                          controller: _emailController,
                          decoration: _buildModernInputDecoration(
                            labelText: 'Alamat Email',
                            hintText: 'contoh@email.com',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          validator: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Alamat
                      _buildFormField(
                        title: 'Alamat',
                        description: 'Alamat lengkap kontak darurat',
                        child: TextFormField(
                          controller: _addressController,
                          decoration: _buildModernInputDecoration(
                            labelText: 'Alamat Lengkap',
                            hintText: 'Jl. Contoh No. 123, Kota, Provinsi',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                            ),
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Kontak Utama Switch
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 32),
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Color(0xFF007AFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.star_outline,
                                  color: Color(0xFF007AFF),
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jadikan Kontak Utama',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Kontak yang akan dihubungi pertama kali',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isPrimary,
                                onChanged: (value) {
                                  setState(() {
                                    _isPrimary = value;
                                  });
                                },
                                activeColor: Color(0xFF007AFF),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Save Button
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: _isLoading
                                ? null
                                : LinearGradient(
                                    colors: [
                                      const Color(0xFF007AFF),
                                      const Color(0xFF5856D6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: _isLoading ? Colors.grey[300] : null,
                            boxShadow: _isLoading
                                ? []
                                : [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF007AFF,
                                      ).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveContact,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.grey[600]!,
                                              ),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        isEditMode
                                            ? 'Menyimpan...'
                                            : 'Menyimpan...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isEditMode
                                            ? Icons.save_outlined
                                            : Icons.save_outlined,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        isEditMode
                                            ? 'Simpan Perubahan'
                                            : 'Simpan Kontak',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Info Tips
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[600],
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tips Penting',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                '• Pastikan nomor telepon selalu aktif dan dapat dihubungi\n'
                                '• Informasikan kepada kontak bahwa mereka terdaftar sebagai kontak darurat\n'
                                '• Update informasi jika ada perubahan\n'
                                '• Rekomendasikan menambah minimal 2 kontak darurat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildErrorLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Gagal memuat data kategori',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Periksa koneksi internet dan coba lagi',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoadingCategories = true;
              });
              _loadCategories();
            },
            icon: Icon(Icons.refresh),
            label: Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF007AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
