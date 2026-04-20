// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileDisplay profileData;

  const EditProfileScreen({super.key, required this.profileData});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ==================== CONTROLLERS ====================
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _additionalPhoneController;
  late TextEditingController _addressController;
  late TextEditingController _citizenIdAddressController;
  late TextEditingController _residentialAddressController;
  late TextEditingController _postalCodeController;
  late TextEditingController _jobsController;
  late TextEditingController _placeOfBirthController;
  late TextEditingController _nikController;
  late TextEditingController _npwpController;
  late TextEditingController _passportNumberController;

  // ==================== STATE VARIABLES ====================
  String? _selectedGender;
  String? _selectedMaritalStatus;
  String? _selectedBloodType;
  String? _selectedReligion;
  DateTime? _selectedBirthDate;
  DateTime? _selectedPassportExpiry;
  Uint8List? _newProfilePhoto;

  bool _isLoading = false;
  String? _accessToken;

  // ==================== DROPDOWN OPTIONS ====================
  final List<String> _genderOptions = ['Laki-laki', 'Perempuan'];
  final List<String> _maritalStatusOptions = [
    'Belum Menikah',
    'Menikah',
    'Cerai Hidup',
    'Cerai Mati',
  ];
  final List<String> _bloodTypeOptions = ['A', 'B', 'AB', 'O'];
  final List<String> _religionOptions = [
    'Islam',
    'Kristen Protestan',
    'Kristen Katolik',
    'Hindu',
    'Buddha',
    'Konghucu',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _getToken();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.profileData.fullName);
    _phoneController = TextEditingController(
      text: widget.profileData.phoneNumber,
    );
    _additionalPhoneController = TextEditingController(
      text: widget.profileData.additionalPhone ?? '',
    );
    _addressController = TextEditingController(
      text: widget.profileData.address ?? '',
    );
    _citizenIdAddressController = TextEditingController(
      text: widget.profileData.citizenIdAddress ?? '',
    );
    _residentialAddressController = TextEditingController(
      text: widget.profileData.residentialAddress ?? '',
    );
    _postalCodeController = TextEditingController(
      text: widget.profileData.postalCode ?? '',
    );
    _jobsController = TextEditingController(
      text: widget.profileData.jobs ?? '',
    );
    _placeOfBirthController = TextEditingController(
      text: widget.profileData.placeOfBirth ?? '',
    );
    _nikController = TextEditingController(text: widget.profileData.nik ?? '');
    _npwpController = TextEditingController(
      text: widget.profileData.npwp ?? '',
    );
    _passportNumberController = TextEditingController(
      text: widget.profileData.passportNumber ?? '',
    );

    // Parse dates
    if (widget.profileData.birthDate != null &&
        widget.profileData.birthDate!.isNotEmpty) {
      _selectedBirthDate = DateTime.tryParse(widget.profileData.birthDate!);
    }

    if (widget.profileData.passportExpiry != null &&
        widget.profileData.passportExpiry!.isNotEmpty) {
      _selectedPassportExpiry = DateTime.tryParse(
        widget.profileData.passportExpiry!,
      );
    }

    // Set dropdown values - FIXED: removed null-aware operator on non-nullable
    _selectedGender =
        (widget.profileData.gender != null &&
            widget.profileData.gender!.isNotEmpty)
        ? widget.profileData.gender
        : 'Laki-laki';
    _selectedMaritalStatus =
        (widget.profileData.maritalStatus != null &&
            widget.profileData.maritalStatus!.isNotEmpty)
        ? widget.profileData.maritalStatus
        : 'Belum Menikah';
    _selectedBloodType =
        (widget.profileData.bloodType != null &&
            widget.profileData.bloodType!.isNotEmpty)
        ? widget.profileData.bloodType
        : 'A';
    _selectedReligion =
        (widget.profileData.religion != null &&
            widget.profileData.religion!.isNotEmpty)
        ? widget.profileData.religion
        : 'Islam';
  }

  Future<void> _getToken() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('access_token') && data['access_token'] != null) {
          setState(() {
            _accessToken = data['access_token'];
          });
        }
      }
    } catch (e) {
      // FIXED: removed print - use logging framework instead
      debugPrint('Error getting token: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (_accessToken == null) {
      _showSnackBar('Token tidak tersedia. Silakan coba lagi.', Colors.red);
      return;
    }

    // Validate required fields
    if (_nameController.text.isEmpty) {
      _showSnackBar('Nama lengkap harus diisi', Colors.orange);
      return;
    }

    if (_phoneController.text.isEmpty) {
      _showSnackBar('Nomor telepon harus diisi', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email');
      final userId = prefs.getString('UserID');

      if (email == null || userId == null) {
        _showSnackBar('Email atau UserID tidak ditemukan', Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      // Build request body sesuai dengan parameter C# method
      final requestBody = {
        'Mail': email,
        'UserId': userId,
        'Name': _nameController.text.trim(),
        'Phone': _phoneController.text.trim(),
        'AdditionalPhone': _additionalPhoneController.text.isEmpty
            ? null
            : _additionalPhoneController.text.trim(),
        'Gender': _selectedGender,
        'PlaceOfBirth': _placeOfBirthController.text.isEmpty
            ? null
            : _placeOfBirthController.text.trim(),
        'BirthDate': _selectedBirthDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
            : null,
        'MaritalStatus': _selectedMaritalStatus,
        'BloodType': _selectedBloodType,
        'Religion': _selectedReligion,
        'Address': _addressController.text.isEmpty
            ? null
            : _addressController.text.trim(),
        'CitizenIdAddress': _citizenIdAddressController.text.isEmpty
            ? null
            : _citizenIdAddressController.text.trim(),
        'ResidentialAddress': _residentialAddressController.text.isEmpty
            ? null
            : _residentialAddressController.text.trim(),
        'PostalCode': _postalCodeController.text.isEmpty
            ? null
            : _postalCodeController.text.trim(),
        'Jobs': _jobsController.text.isEmpty
            ? null
            : _jobsController.text.trim(),
        'Nik': _nikController.text.isEmpty ? null : _nikController.text.trim(),
        'Npwp': _npwpController.text.isEmpty
            ? null
            : _npwpController.text.trim(),
        'PassportNumber': _passportNumberController.text.isEmpty
            ? null
            : _passportNumberController.text.trim(),
        'PassportExpiry': _selectedPassportExpiry != null
            ? DateFormat('yyyy-MM-dd').format(_selectedPassportExpiry!)
            : null,
        if (_newProfilePhoto != null)
          'FotoProfil': base64Encode(_newProfilePhoto!),
      };
      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/updateProfile'),
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        _showSnackBar('Profil berhasil diperbarui!', Colors.green);
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, true); // Return true untuk refresh
        });
      } else {
        _showSnackBar('Gagal memperbarui profil: ${response.body}', Colors.red);
        // FIXED: replaced print with debugPrint
        debugPrint('Error Response: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', Colors.red);
      // FIXED: replaced print with debugPrint
      debugPrint('Save Error: $e');
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _newProfilePhoto = bytes;
        });
        _showSnackBar('Foto profil berhasil dipilih', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error memilih foto: $e', Colors.red);
    }
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007AFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedBirthDate = selected;
      });
    }
  }

  Future<void> _selectPassportExpiry() async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _selectedPassportExpiry ??
          DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007AFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedPassportExpiry = selected;
      });
    }
  }

  // ==================== UI BUILDERS ====================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: icon != null
                    ? Icon(icon, color: const Color(0xFF007AFF))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                hintStyle: TextStyle(color: Colors.grey[400]),
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  hint: Text(
                    'Pilih $label',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  icon: const Icon(Icons.expand_more, color: Color(0xFF007AFF)),
                  items: items.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                  underline: Container(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    IconData icon = Icons.calendar_today,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF007AFF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedDate != null
                          ? DateFormat(
                              'dd MMMM yyyy',
                              'id_ID',
                            ).format(selectedDate)
                          : 'Pilih tanggal',
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedDate != null
                            ? Colors.black87
                            : Colors.grey[400],
                        fontWeight: selectedDate != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF007AFF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: const Color(0xFF007AFF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Foto Profil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: _newProfilePhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_newProfilePhoto!, fit: BoxFit.cover),
                  )
                : widget.profileData.fotoProfil != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      widget.profileData.fotoProfil!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada foto',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickProfilePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Pilih Foto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: const Color(0xFF007AFF), width: 4),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF007AFF),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _additionalPhoneController.dispose();
    _addressController.dispose();
    _citizenIdAddressController.dispose();
    _residentialAddressController.dispose();
    _postalCodeController.dispose();
    _jobsController.dispose();
    _placeOfBirthController.dispose();
    _nikController.dispose();
    _npwpController.dispose();
    _passportNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto Section
            _buildPhotoSection(),

            // Personal Data Section
            _buildSectionHeader('Data Pribadi'),
            _buildTextField(
              controller: _nameController,
              label: 'Nama Lengkap',
              hintText: 'Masukkan nama lengkap',
              icon: Icons.person,
            ),
            _buildTextField(
              controller: _phoneController,
              label: 'Nomor Telepon',
              hintText: 'Masukkan nomor telepon',
              keyboardType: TextInputType.phone,
              icon: Icons.phone,
            ),
            _buildTextField(
              controller: _additionalPhoneController,
              label: 'Nomor Telepon Tambahan',
              hintText: 'Masukkan nomor telepon tambahan (opsional)',
              keyboardType: TextInputType.phone,
              icon: Icons.phone,
            ),
            _buildDropdownField(
              label: 'Jenis Kelamin',
              value: _selectedGender,
              items: _genderOptions,
              onChanged: (value) {
                setState(() => _selectedGender = value);
              },
            ),
            _buildTextField(
              controller: _placeOfBirthController,
              label: 'Tempat Lahir',
              hintText: 'Masukkan tempat lahir',
              icon: Icons.location_on,
            ),
            _buildDatePickerField(
              label: 'Tanggal Lahir',
              selectedDate: _selectedBirthDate,
              onTap: _selectBirthDate,
            ),
            _buildDropdownField(
              label: 'Status Pernikahan',
              value: _selectedMaritalStatus,
              items: _maritalStatusOptions,
              onChanged: (value) {
                setState(() => _selectedMaritalStatus = value);
              },
            ),
            _buildDropdownField(
              label: 'Golongan Darah',
              value: _selectedBloodType,
              items: _bloodTypeOptions,
              onChanged: (value) {
                setState(() => _selectedBloodType = value);
              },
            ),
            _buildDropdownField(
              label: 'Agama',
              value: _selectedReligion,
              items: _religionOptions,
              onChanged: (value) {
                setState(() => _selectedReligion = value);
              },
            ),

            // Address Section
            _buildSectionHeader('Alamat & Identitas'),
            _buildTextField(
              controller: _addressController,
              label: 'Alamat Rumah',
              hintText: 'Masukkan alamat rumah',
              maxLines: 3,
              icon: Icons.home,
            ),
            _buildTextField(
              controller: _citizenIdAddressController,
              label: 'Alamat KTP',
              hintText: 'Masukkan alamat sesuai KTP',
              maxLines: 3,
              icon: Icons.credit_card,
            ),
            _buildTextField(
              controller: _residentialAddressController,
              label: 'Alamat Domisili',
              hintText: 'Masukkan alamat domisili',
              maxLines: 3,
              icon: Icons.apartment,
            ),
            _buildTextField(
              controller: _postalCodeController,
              label: 'Kode Pos',
              hintText: 'Masukkan kode pos',
              keyboardType: TextInputType.number,
              icon: Icons.markunread_mailbox,
            ),

            // Identity Section
            _buildSectionHeader('Identitas & Dokumen'),
            _buildTextField(
              controller: _nikController,
              label: 'NIK (Nomor Induk Kependudukan)',
              hintText: 'Masukkan nomor NIK',
              keyboardType: TextInputType.number,
              icon: Icons.credit_card,
            ),
            _buildTextField(
              controller: _npwpController,
              label: 'NPWP',
              hintText: 'Masukkan nomor NPWP',
              keyboardType: TextInputType.number,
              icon: Icons.credit_card,
            ),
            _buildTextField(
              controller: _passportNumberController,
              label: 'Nomor Paspor',
              hintText: 'Masukkan nomor paspor',
              icon: Icons.card_travel,
            ),
            _buildDatePickerField(
              label: 'Tanggal Kedaluwarsa Paspor',
              selectedDate: _selectedPassportExpiry,
              onTap: _selectPassportExpiry,
            ),

            // Job Section
            _buildSectionHeader('Pekerjaan'),
            _buildTextField(
              controller: _jobsController,
              label: 'Pekerjaan',
              hintText: 'Masukkan nama pekerjaan',
              icon: Icons.work,
            ),

            // Save Button
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
