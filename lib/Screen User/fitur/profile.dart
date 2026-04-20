// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/bantuandandukungan.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/hubungikami.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/infoprofile.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/keamanan.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/kebijakanprivacy.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/kontakdarurat.dart';
import 'package:absensikaryawan/Screen%20User/splash_screen.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/profile.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isDarkTheme = false;
  bool _isLoadingDisplay = true;
  bool _isUploadingPhoto = false;
  bool _isDeletingAccount = false;
  String _email = '';
  ProfileDisplay? _profileDisplay;
  String? _accessToken;
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
      'helpSupport': 'Bantuan & Dukungan',
      'privacyPolicy': 'Kebijakan Privasi',
      'contactUs': 'Hubungi Kami',
      'logout': 'Keluar',
      'logoutConfirm': 'Apakah Anda yakin ingin keluar?',
      'deleteAccount': 'Hapus Akun',
      'deleteAccountConfirm':
          'Apakah Anda yakin ingin menghapus akun ini secara permanen?',
      'deleteAccountWarning':
          'Peringatan: Akun Anda akan dihapus secara permanen dan semua data terkait akan hilang. Tindakan ini tidak dapat dibatalkan.',
      'deleteAccountPassword': 'Masukkan password Anda untuk konfirmasi',
      'passwordHint': 'Password',
      'cancel': 'Batal',
      'yes': 'Ya, Keluar',
      'yesDelete': 'Ya, Hapus Akun',
      'selectFromGallery': 'Pilih dari Galeri',
      'takePhoto': 'Ambil Foto Kamera',
      'selectLanguage': 'Pilih Bahasa',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
      'errorDeleteAccount': 'Gagal menghapus akun',
      'successDeleteAccount': 'Akun berhasil dihapus',
      'accountDeletedRedirect': 'Anda akan dialihkan ke halaman login...',
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
      'helpSupport': 'Bantuan & Dukungan',
      'privacyPolicy': 'Kebijakan Privasi',
      'contactUs': 'Hubungi Kami',
      'logout': 'Keluar',
      'logoutConfirm': 'Apakah Anda yakin ingin keluar?',
      'deleteAccount': 'Hapus Akun',
      'deleteAccountConfirm':
          'Apakah Anda yakin ingin menghapus akun ini secara permanen?',
      'deleteAccountWarning':
          'Peringatan: Akun Anda akan dihapus secara permanen dan semua data terkait akan hilang. Tindakan ini tidak dapat dibatalkan.',
      'deleteAccountPassword': 'Masukkan password Anda untuk konfirmasi',
      'passwordHint': 'Password',
      'cancel': 'Batal',
      'yes': 'Ya, Keluar',
      'yesDelete': 'Ya, Hapus Akun',
      'selectFromGallery': 'Pilih dari Galeri',
      'takePhoto': 'Ambil Foto Kamera',
      'selectLanguage': 'Pilih Bahasa',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
      'errorDeleteAccount': 'Gagal menghapus akun',
      'successDeleteAccount': 'Akun berhasil dihapus',
      'accountDeletedRedirect': 'Anda akan dialihkan ke halaman login...',
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
      'helpSupport': 'Help & Support',
      'privacyPolicy': 'Privacy Policy',
      'contactUs': 'Contact Us',
      'logout': 'Logout',
      'logoutConfirm': 'Are you sure you want to logout?',
      'deleteAccount': 'Delete Account',
      'deleteAccountConfirm':
          'Are you sure you want to permanently delete this account?',
      'deleteAccountWarning':
          'Warning: Your account will be permanently deleted and all associated data will be lost. This action cannot be undone.',
      'deleteAccountPassword': 'Enter your password to confirm',
      'passwordHint': 'Password',
      'cancel': 'Cancel',
      'yes': 'Yes, Logout',
      'yesDelete': 'Yes, Delete Account',
      'selectFromGallery': 'Select from Gallery',
      'takePhoto': 'Take Photo',
      'selectLanguage': 'Select Language',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
      'errorDeleteAccount': 'Failed to delete account',
      'successDeleteAccount': 'Account successfully deleted',
      'accountDeletedRedirect': 'You will be redirected to login page...',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _initializeUserInfo();
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

  Future<void> _initializeUserInfo() async {
    _accessToken = await _getToken();
    if (_accessToken != null) {
      await _loadProfileData();
    }
  }

  Future<void> _loadProfileData() async {
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
          'Authorization': 'bearer $_accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );

      if (userResponse.statusCode == 200) {
        final data = json.decode(userResponse.body);
        setState(() {
          _profileDisplay = ProfileDisplay.fromJson(data);
          _isLoadingDisplay = false;
        });
      } else {
        setState(() {
          _isLoadingDisplay = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingDisplay = false;
      });
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

      final tokenResponse = await http.post(
        Uri.parse('$baseURL/api/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'password', 'password': 'ASN_DBS'},
      );

      if (tokenResponse.statusCode != 200) {
        _showErrorSnackBar('Gagal mendapatkan token akses');
        return;
      }

      final tokenData = json.decode(tokenResponse.body);
      final String accessToken = tokenData['access_token'];

      final body = json.encode({
        'Email': email,
        'FotoProfilBase64': base64Image,
      });

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/user/profile/photo/upload-base64'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        if (responseBody['success'] == true) {
          _showSuccessSnackBar(
            responseBody['message'] ?? 'Foto profil berhasil diperbarui',
          );
          await _loadProfileData();
        } else {
          _showErrorSnackBar(
            responseBody['message'] ?? 'Gagal memperbarui foto profil',
          );
        }
      } else if (response.statusCode == 404) {
        final responseBody = json.decode(response.body);
        _showErrorSnackBar(responseBody['message'] ?? 'User tidak ditemukan');
      } else {
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

  // ===================== DELETE ACCOUNT FUNCTIONS =====================
  void _showDeleteAccountBottomSheet() {
    final TextEditingController passwordController = TextEditingController();
    bool hidePassword = true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning Icon
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red[600],
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _getLocalizedString('deleteAccount'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.red[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Warning Message
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!, width: 1),
                      ),
                      child: Text(
                        _getLocalizedString('deleteAccountWarning'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Confirmation Question
                    Center(
                      child: Text(
                        _getLocalizedString('deleteAccountConfirm'),
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password Input
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        hintText: _getLocalizedString('passwordHint'),
                        labelText: _getLocalizedString('deleteAccountPassword'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              foregroundColor: Colors.grey[800],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () {
                              passwordController.dispose();
                              Navigator.of(context).pop();
                            },
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
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _isDeletingAccount
                                ? null
                                : () {
                                    if (passwordController.text.isEmpty) {
                                      _showErrorSnackBar(
                                        'Silakan masukkan password Anda',
                                      );
                                      return;
                                    }
                                    Navigator.of(context).pop();
                                    passwordController.dispose();
                                    _performDeleteAccount();
                                  },
                            child: _isDeletingAccount
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _getLocalizedString('yesDelete'),
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _performDeleteAccount() async {
    if (_profileDisplay == null) {
      _showErrorSnackBar('Data profil tidak ditemukan');
      return;
    }

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email') ?? '';

      final body = json.encode({
        'UserId': _profileDisplay!.id.toString(),
        'UpdatedBy': email,
      });

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/user/deleteAccount'),
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final message =
            responseBody['Message'] ?? responseBody['message'] ?? '';

        if (message.toLowerCase().contains('successfully')) {
          // Show success message
          _showSuccessSnackBar(_getLocalizedString('successDeleteAccount'));

          // Show redirect message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getLocalizedString('accountDeletedRedirect')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Wait 2 seconds before redirecting
          await Future.delayed(const Duration(seconds: 2));

          // Clear all data
          await prefs.clear();

          if (!mounted) return;

          // Redirect to splash screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SplashScreen()),
          );
        } else {
          _showErrorSnackBar(message);
        }
      } else if (response.statusCode == 400) {
        final responseBody = json.decode(response.body);
        _showErrorSnackBar(
          responseBody['Message'] ??
              responseBody['message'] ??
              _getLocalizedString('errorDeleteAccount'),
        );
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('User tidak ditemukan');
      } else {
        final responseBody = json.decode(response.body);
        _showErrorSnackBar(
          responseBody['Message'] ??
              responseBody['message'] ??
              _getLocalizedString('errorDeleteAccount'),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Kesalahan: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }
  // ===================== END DELETE ACCOUNT FUNCTIONS =====================

  void _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Menghapus semua data tersimpan

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
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
                  _showComingSoonDialog(context);
                },
              ),
              _buildMenuItem(
                Icons.school_outlined,
                _getLocalizedString('education'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  _showComingSoonDialog(context);
                },
              ),
              _buildMenuItem(
                Icons.payment_outlined,
                _getLocalizedString('salaryInfo'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
                  _showComingSoonDialog(context);
                },
              ),
              _buildMenuItem(
                Icons.warning_amber_outlined,
                _getLocalizedString('reprimand'),
                iconSize: iconSize,
                fontSize: menuItemFontSize,
                onTap: () {
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
                _getLocalizedString('Ubah Keamanan'),
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
                  _showComingSoonDialog(context);
                },
              ),
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
                icon: const Icon(Icons.logout, color: Colors.blue),
                label: Text(
                  _getLocalizedString('logout'),
                  style: TextStyle(
                    color: Colors.blue,
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

            const SizedBox(height: 12),

            // Delete Account Button
            Container(
              margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16),
              child: TextButton.icon(
                onPressed: _isDeletingAccount
                    ? null
                    : _showDeleteAccountBottomSheet,
                icon: Icon(
                  Icons.delete_forever,
                  color: _isDeletingAccount ? Colors.grey : Colors.red,
                ),
                label: Text(
                  _getLocalizedString('deleteAccount'),
                  style: TextStyle(
                    color: _isDeletingAccount ? Colors.grey : Colors.red,
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
