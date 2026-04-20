// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import '../../Screen User/fitur/profile fitur/bantuandandukungan.dart';
import '../../Screen User/fitur/profile fitur/hubungikami.dart';
import '../../Screen User/fitur/profile fitur/infoprofile.dart';
import '../../Screen User/fitur/profile fitur/keamanan.dart';
import '../../Screen User/fitur/profile fitur/kebijakanprivacy.dart';
import '../../Screen User/fitur/profile fitur/kontakdarurat.dart';
import '../../Screen User/home.dart';
import '../../Screen User/splash_screen.dart';
import '../../Services/config.dart';
import '../../Services/profile.dart';

class ProfileScreenAdmin extends StatefulWidget {
  const ProfileScreenAdmin({super.key});

  @override
  _ProfileScreenAdminState createState() => _ProfileScreenAdminState();
}

class _ProfileScreenAdminState extends State<ProfileScreenAdmin> {
  bool isDarkTheme = false;
  bool _isLoadingDisplay = true;
  bool _isUploadingPhoto = false;
  String _email = '';
  ProfileDisplay? _profileDisplay;
  final ImagePicker _picker = ImagePicker();
  String _selectedLanguage = 'system'; // 'system', 'id', 'en'

  // Localization Maps
  final Map<String, Map<String, String>> _localizedStrings = {
    'system': {
      'profile': 'Profil',
      'username': 'Nama Pengguna',
      'position': 'Jabatan',
      'myInfo': 'Informasi Saya',
      'personalInfo': 'Informasi Pribadi',
      'emergencyContact': 'Kontak Darurat',
      'familyInfo': 'Informasi Keluarga',
      'education': 'Pendidikan dan Pengalaman',
      'salaryInfo': 'Informasi Gaji',
      'additionalInfo': 'Informasi Tambahan',
      'reprimand': 'Teguran',
      'settings': 'Pengaturan',
      'changeSecurity': 'Ubah Keamanan',
      'attendanceReminder': 'Pengingat Absen Masuk/Keluar',
      'language': 'Bahasa',
      'deviceDefault': 'Bawaan Perangkat',
      'switchToUserMode': 'Masuk ke Mode User',
      'helpSupport': 'Bantuan & Dukungan',
      'privacyPolicy': 'Kebijakan Privasi',
      'contactUs': 'Hubungi Kami',
      'logout': 'Keluar',
      'logoutConfirm': 'Apakah Anda yakin ingin keluar?',
      'switchModeConfirm': 'Apakah Anda yakin ingin beralih ke mode user?',
      'cancel': 'Batal',
      'yes': 'Ya, Keluar',
      'yesSwitch': 'Ya, Beralih',
      'selectFromGallery': 'Pilih dari Galeri',
      'takePhoto': 'Ambil Foto Kamera',
      'selectLanguage': 'Pilih Bahasa',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
    },
    'id': {
      'profile': 'Profil',
      'username': 'Nama Pengguna',
      'position': 'Jabatan',
      'myInfo': 'Informasi Saya',
      'personalInfo': 'Informasi Pribadi',
      'emergencyContact': 'Kontak Darurat',
      'familyInfo': 'Informasi Keluarga',
      'education': 'Pendidikan dan Pengalaman',
      'salaryInfo': 'Informasi Gaji',
      'additionalInfo': 'Informasi Tambahan',
      'reprimand': 'Teguran',
      'settings': 'Pengaturan',
      'changeSecurity': 'Ubah Keamanan',
      'attendanceReminder': 'Pengingat Absen Masuk/Keluar',
      'language': 'Bahasa',
      'deviceDefault': 'Bawaan Perangkat',
      'switchToUserMode': 'Masuk ke Mode User',
      'helpSupport': 'Bantuan & Dukungan',
      'privacyPolicy': 'Kebijakan Privasi',
      'contactUs': 'Hubungi Kami',
      'logout': 'Keluar',
      'logoutConfirm': 'Apakah Anda yakin ingin keluar?',
      'switchModeConfirm': 'Apakah Anda yakin ingin beralih ke mode user?',
      'cancel': 'Batal',
      'yes': 'Ya, Keluar',
      'yesSwitch': 'Ya, Beralih',
      'selectFromGallery': 'Pilih dari Galeri',
      'takePhoto': 'Ambil Foto Kamera',
      'selectLanguage': 'Pilih Bahasa',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
    },
    'en': {
      'profile': 'Profile',
      'username': 'Username',
      'position': 'Position',
      'myInfo': 'My Information',
      'personalInfo': 'Personal Information',
      'emergencyContact': 'Emergency Contact',
      'familyInfo': 'Family Information',
      'education': 'Education and Experience',
      'salaryInfo': 'Salary Information',
      'additionalInfo': 'Additional Information',
      'reprimand': 'Reprimand',
      'settings': 'Settings',
      'changeSecurity': 'Change Security',
      'attendanceReminder': 'Attendance Reminder',
      'language': 'Language',
      'deviceDefault': 'Device Default',
      'switchToUserMode': 'Switch to User Mode',
      'helpSupport': 'Help & Support',
      'privacyPolicy': 'Privacy Policy',
      'contactUs': 'Contact Us',
      'logout': 'Logout',
      'logoutConfirm': 'Are you sure you want to logout?',
      'switchModeConfirm': 'Are you sure you want to switch to user mode?',
      'cancel': 'Cancel',
      'yes': 'Yes, Logout',
      'yesSwitch': 'Yes, Switch',
      'selectFromGallery': 'Select from Gallery',
      'takePhoto': 'Take Photo',
      'selectLanguage': 'Select Language',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _initializeUserInfo();
  }

  static Future<String?> _getToken() async {
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
          return data['access_token'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selected_language') ?? 'system';
    });
  }

  String _getLocalizedString(String key) {
    return _localizedStrings[_selectedLanguage]?[key] ?? key;
  }

  Future<void> _initializeUserInfo() async {
    setState(() {
      _isLoadingDisplay = true;
    });

    final token = await _getToken();
    if (token == null) {
      // Token gagal didapat
      setState(() {
        _isLoadingDisplay = false;
      });
      // Bisa tampilkan pesan error
      return;
    }

    await _loadProfileData(token);
  }

  Future<void> _loadProfileData(String token) async {
    setState(() {
      _isLoadingDisplay = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('Email');
    if (email == null) {
      setState(() {
        _isLoadingDisplay = false;
      });
      return;
    }

    setState(() {
      _email = email;
    });

    try {
      final userResponse = await http.post(
        Uri.parse('$baseURL/api/asn/getDataUser'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );

      if (!mounted) return;

      if (userResponse.statusCode == 200) {
        final data = json.decode(userResponse.body);
        setState(() {
          _profileDisplay = ProfileDisplay.fromJson(data);
          _isLoadingDisplay = false;
        });
      } else if (userResponse.statusCode == 401) {
        // Token mungkin expired → refresh dan coba lagi
        final newToken = await _getToken();
        if (newToken != null) {
          await _loadProfileData(newToken);
        } else {
          setState(() {
            _isLoadingDisplay = false;
          });
        }
      } else {
        setState(() {
          _isLoadingDisplay = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDisplay = false;
          // Bisa simpan error message juga
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final permission = await _checkGalleryPermission();
      if (!permission) {
        _showErrorSnackBar('Permission galeri tidak diberikan');
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        File imageFile = File(image.path);
        await _uploadProfilePhotoBase64(imageFile);
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memilih gambar dari galeri: ${e.toString()}');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final permission = await _checkCameraPermission();
      if (!permission) {
        _showErrorSnackBar('Permission kamera tidak diberikan');
        return;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (photo != null) {
        File imageFile = File(photo.path);
        await _uploadProfilePhotoBase64(imageFile);
      }
    } catch (e) {
      _showErrorSnackBar('Gagal mengambil foto dari kamera: ${e.toString()}');
    }
  }

  Future<bool> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDialog('Kamera', 'kamera');
      return false;
    }

    return status.isGranted;
  }

  Future<bool> _checkGalleryPermission() async {
    Permission permission;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        permission = Permission.photos;
      } else {
        permission = Permission.storage;
      }
    } else {
      permission = Permission.photos;
    }

    var status = await permission.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await permission.request();
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDialog('Galeri', 'mengakses galeri');
      return false;
    }

    return status.isGranted;
  }

  void _showPermissionDialog(String permissionName, String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission $permissionName Diperlukan'),
          content: Text(
            'Aplikasi memerlukan akses $action untuk mengubah foto profil. '
            'Silakan aktifkan permission di pengaturan aplikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_getLocalizedString('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadProfilePhotoBase64(File imageFile) async {
    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email') ?? '';
      if (email.isEmpty) {
        _showErrorSnackBar('Email tidak ditemukan');
        return;
      }

      final token = await _getToken();
      if (token == null) {
        _showErrorSnackBar('Gagal mendapatkan token akses');
        return;
      }

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/user/profile/photo/upload-base64'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email, 'FotoProfilBase64': base64Image}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success'] == true) {
          _showSuccessSnackBar(
            responseBody['message'] ?? 'Foto profil berhasil diperbarui',
          );
          // reload profile
          await _loadProfileData(token);
        } else {
          _showErrorSnackBar(
            responseBody['message'] ?? 'Gagal memperbarui foto profil',
          );
        }
      } else if (response.statusCode == 401) {
        // token expired, coba refresh dan upload ulang
        final newToken = await _getToken();
        if (newToken != null) {
          // ulangi upload
          await _uploadProfilePhotoBase64(imageFile);
        } else {
          _showErrorSnackBar('Authentication gagal');
        }
      } else {
        // error status lain
        final responseBody = json.decode(response.body);
        _showErrorSnackBar(
          responseBody['message'] ?? 'Gagal memperbarui foto profil',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
          'Terjadi kesalahan saat mengunggah foto: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLogoutBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: false,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  _getLocalizedString('logout'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red[600],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _getLocalizedString('logoutConfirm'),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _getLocalizedString('cancel'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _performLogout();
                      },
                      child: Text(
                        _getLocalizedString('yes'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSwitchModeBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: false,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  _getLocalizedString('switchToUserMode'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.orange[600],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _getLocalizedString('switchModeConfirm'),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.orange[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: Colors.orange[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _getLocalizedString('cancel'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _performSwitchToUserMode();
                      },
                      child: Text(
                        _getLocalizedString('yesSwitch'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Menghapus semua data tersimpan

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
  }

  void _performSwitchToUserMode() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;

    // Responsive values
    final double horizontalPadding = isSmallScreen
        ? 16
        : (isMediumScreen ? 24 : 32);
    final double verticalPadding = isSmallScreen ? 12 : 16;
    final double avatarRadius = isSmallScreen ? 40 : (isMediumScreen ? 50 : 60);
    final double titleFontSize = isSmallScreen
        ? 20
        : (isMediumScreen ? 24 : 28);
    final double sectionTitleFontSize = isSmallScreen
        ? 16
        : (isMediumScreen ? 18 : 20);
    final double menuItemFontSize = isSmallScreen
        ? 14
        : (isMediumScreen ? 16 : 18);
    final double iconSize = isSmallScreen ? 20 : (isMediumScreen ? 22 : 24);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding.toDouble(),
            vertical: verticalPadding.toDouble(),
          ),
          children: [
            // Header
            Center(
              child: Text(
                _getLocalizedString('profile'),
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 16 : 24),

            // Profile Picture dan Info
            if (_isLoadingDisplay)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _profileDisplay?.fotoProfil != null
                              ? MemoryImage(_profileDisplay!.fotoProfil!)
                              : null,
                          child: _profileDisplay?.fotoProfil == null
                              ? Icon(
                                  Icons.person,
                                  size: avatarRadius * 0.6,
                                  color: Colors.grey[600],
                                )
                              : null,
                        ),
                        if (_isUploadingPhoto)
                          Container(
                            width: avatarRadius * 2,
                            height: avatarRadius * 2,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: _isUploadingPhoto
                                ? null
                                : () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) {
                                        return SafeArea(
                                          child: Wrap(
                                            children: [
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.photo_library,
                                                ),
                                                title: Text(
                                                  _getLocalizedString(
                                                    'selectFromGallery',
                                                  ),
                                                ),
                                                onTap: () {
                                                  Navigator.of(context).pop();
                                                  _pickImageFromGallery();
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.camera_alt,
                                                ),
                                                title: Text(
                                                  _getLocalizedString(
                                                    'takePhoto',
                                                  ),
                                                ),
                                                onTap: () {
                                                  Navigator.of(context).pop();
                                                  _pickImageFromCamera();
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                            child: CircleAvatar(
                              radius: isSmallScreen ? 12 : 14,
                              backgroundColor: _isUploadingPhoto
                                  ? Colors.grey
                                  : Colors.blue,
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _profileDisplay?.displayName ??
                          _getLocalizedString('username'),
                      style: TextStyle(
                        fontSize: menuItemFontSize + 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _email.isNotEmpty ? _email : "email@domain.com",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      _profileDisplay?.jobs ?? _getLocalizedString('position'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

            SizedBox(height: isSmallScreen ? 20 : 30),

            // My Info Section
            _buildSectionTitle(
              _getLocalizedString('myInfo'),
              sectionTitleFontSize,
            ),
            const SizedBox(height: 8),
            _buildMenuSection([
              _buildMenuItem(
                Icons.person_outline,
                _getLocalizedString('personalInfo'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InfoProfileScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.emergency,
                _getLocalizedString('emergencyContact'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmergencyContactScreen(
                        userId: _profileDisplay?.userId ?? '',
                      ),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.family_restroom,
                _getLocalizedString('familyInfo'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  // Navigate to family info
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const FamilyInfoScreen(),
                  //   ),
                  // );
                  _showComingSoonDialog(context);
                },
              ),
              _buildMenuItem(
                Icons.school_outlined,
                _getLocalizedString('education'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const EducationExperienceScreen(),
                  //   ),
                  // );
                  _showComingSoonDialog(context);
                },
              ),
              _buildMenuItem(
                Icons.payment_outlined,
                _getLocalizedString('salaryInfo'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  // Navigate to payroll info
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => SalaryScreen()),
                  // );
                  _showComingSoonDialog(context);
                },
              ),
              // _buildMenuItem(
              //   Icons.info_outline,
              //   _getLocalizedString('additionalInfo'),
              //   iconSize: iconSize,
              //   fontSize: menuItemFontSize,
              //   onTap: () {
              //     // Navigate to additional info
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => const AdditionalInfoScreen(),
              //       ),
              //     );
              //   },
              // ),
              _buildMenuItem(
                Icons.warning_amber_outlined,
                _getLocalizedString('reprimand'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  // Navigate to reprimand
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => WarningLetterScreen(),
                  //   ),
                  // );
                  _showComingSoonDialog(context);
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Settings Section
            _buildSectionTitle(
              _getLocalizedString('settings'),
              sectionTitleFontSize,
            ),
            const SizedBox(height: 8),
            _buildMenuSection([
              _buildMenuItem(
                Icons.lock_outline,
                _getLocalizedString('changeSecurity'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HalamanPengaturanKeamanan(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.access_time_outlined,
                _getLocalizedString('attendanceReminder'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  // Navigate to reminder settings
                  _showComingSoonDialog(context);
                },
              ),
              // Button Masuk ke Mode User
              _buildMenuItem(
                Icons.person_outline,
                _getLocalizedString('switchToUserMode'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  _showSwitchModeBottomSheet();
                },
              ),
              // _buildMenuItem(
              //   Icons.language_outlined,
              //   _getLocalizedString('language'),
              //   iconSize: iconSize,
              //   fontSize: menuItemFontSize,
              //   trailingText: _getLanguageDisplayName(_selectedLanguage),
              //   onTap: () {
              //     _showLanguageBottomSheet();
              //   },
              // ),
            ]),

            const SizedBox(height: 24),
            _buildSectionTitle(
              _getLocalizedString('helpSupport'),
              sectionTitleFontSize,
            ),
            const SizedBox(height: 8),
            // Additional Menu Items
            _buildMenuSection([
              _buildMenuItem(
                Icons.privacy_tip_outlined,
                _getLocalizedString('privacyPolicy'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HalamanKebijakanPrivasi(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.help_outline,
                _getLocalizedString('helpSupport'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HalamanBantuanDukungan(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.contact_mail_outlined,
                _getLocalizedString('contactUs'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HalamanHubungiKami(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 20),

            // Logout Button
            Container(
              margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16),
              child: TextButton.icon(
                onPressed: _showLogoutBottomSheet,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(
                  _getLocalizedString('logout'),
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: menuItemFontSize,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, double fontSize) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 360 ? 8 : 16,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Coming Soon'),
        content: const Text('Untuk saat ini masih dalam pengembangan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(List<Widget> items) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalMargin = screenWidth < 360 ? 8 : 16;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin.toDouble()),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? trailingText,
    VoidCallback? onTap,
    double iconSize = 22,
    double fontSize = 16,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final horizontalPadding = isSmallScreen ? 12 : 16;
    final verticalPadding = isSmallScreen ? 12 : 16;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding.toDouble(),
            vertical: verticalPadding.toDouble(),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey.shade700, size: iconSize),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (trailingText != null)
                Flexible(
                  child: Text(
                    trailingText,
                    style: TextStyle(
                      fontSize: fontSize - 2,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(width: isSmallScreen ? 4 : 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: isSmallScreen ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
