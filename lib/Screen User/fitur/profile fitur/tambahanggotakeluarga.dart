// add_family_member_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FamilyMember {
  final String name;
  final String relationship;
  final String phone;
  final String? photoUrl;

  FamilyMember({
    required this.name,
    required this.relationship,
    required this.phone,
    this.photoUrl,
  });
}

class AddFamilyMemberScreen extends StatefulWidget {
  final FamilyMember? memberToEdit; // For edit mode

  const AddFamilyMemberScreen({
    super.key,
    this.memberToEdit,
  });

  @override
  _AddFamilyMemberScreenState createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();

  // Form state
  String _selectedRelationship = '';
  bool _isLoading = false;

  // Relationship options for family
  final List<String> _relationships = [
    'Ayah',
    'Ibu',
    'Kakak',
    'Adik',
    'Suami',
    'Istri',
    'Anak',
    'Kakek',
    'Nenek',
    'Paman',
    'Bibi',
    'Sepupu',
    'Mertua',
    'Menantu',
    'Cucu',
    'Keponakan',
  ];

  bool get isEditMode => widget.memberToEdit != null;

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
    // If edit mode, populate fields
    if (isEditMode) {
      _populateEditData();
    }

    _controller.forward();
  }

  void _populateEditData() {
    if (widget.memberToEdit != null) {
      final member = widget.memberToEdit!;
      _nameController.text = member.name;
      _phoneController.text = member.phone;
      _selectedRelationship = member.relationship;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdateController.dispose();
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

  String? _validateRelationship(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pilih hubungan keluarga';
    }
    return null;
  }

  Future<void> _selectBirthdate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 365 * 20)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF007AFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdateController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _saveFamilyMember() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      await Future.delayed(Duration(seconds: 2));

      setState(() {
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text(isEditMode
                  ? 'Anggota keluarga berhasil diperbarui'
                  : 'Anggota keluarga berhasil ditambahkan'),
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
                isEditMode ? Icons.edit : Icons.family_restroom,
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
          isEditMode ? 'Edit Anggota Keluarga' : 'Tambah Anggota Keluarga',
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildSectionHeader(
                  isEditMode
                      ? 'Edit Anggota Keluarga'
                      : 'Anggota Keluarga Baru',
                  isEditMode
                      ? 'Perbarui informasi anggota keluarga'
                      : 'Tambahkan informasi anggota keluarga Anda',
                ),

                // Nama Lengkap
                _buildFormField(
                  title: 'Nama Lengkap',
                  description: 'Masukkan nama lengkap anggota keluarga',
                  child: TextFormField(
                    controller: _nameController,
                    decoration: _buildModernInputDecoration(
                      labelText: 'Nama Lengkap',
                      hintText: 'Contoh: Ahmad Baharudin',
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

                // Hubungan Keluarga
                _buildFormField(
                  title: 'Hubungan Keluarga',
                  description: 'Pilih hubungan keluarga dengan Anda',
                  child: DropdownButtonFormField<String>(
                    value: _selectedRelationship.isEmpty
                        ? null
                        : _selectedRelationship,
                    decoration: _buildModernInputDecoration(
                      labelText: 'Hubungan Keluarga',
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
                  description: 'Nomor telepon aktif anggota keluarga',
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

                // Tanggal Lahir
                _buildFormField(
                  title: 'Tanggal Lahir (Opsional)',
                  description: 'Tanggal lahir anggota keluarga',
                  child: TextFormField(
                    controller: _birthdateController,
                    decoration: _buildModernInputDecoration(
                      labelText: 'Tanggal Lahir',
                      hintText: 'DD/MM/YYYY',
                      prefixIcon: Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.date_range,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        onPressed: _selectBirthdate,
                      ),
                    ),
                    readOnly: true,
                    onTap: _selectBirthdate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Alamat
                _buildFormField(
                  title: 'Alamat (Opsional)',
                  description: 'Alamat tempat tinggal anggota keluarga',
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

                SizedBox(height: 8),

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
                      onPressed: _isLoading ? null : _saveFamilyMember,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey[600]!,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Menyimpan...',
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
                                  Icons.save_outlined,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  isEditMode
                                      ? 'Simpan Perubahan'
                                      : 'Simpan Anggota Keluarga',
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
                          '• Pastikan informasi yang dimasukkan sesuai dengan data resmi\n'
                          '• Nomor telepon yang aktif memudahkan komunikasi keluarga\n'
                          '• Informasi ini akan digunakan untuk keperluan administrasi\n'
                          '• Update informasi jika ada perubahan data keluarga',
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
}