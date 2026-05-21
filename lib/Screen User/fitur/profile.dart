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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingDisplay = true;
  bool _isUploadingPhoto = false;
  bool _isDeletingAccount = false;
  String _email = '';
  ProfileDisplay? _profileDisplay;
  String? _accessToken;
  final ImagePicker _picker = ImagePicker();
  String _selectedLanguage = 'system';

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
      'attendanceReminder': 'Pengingat Absen',
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
          'Peringatan: Akun Anda akan dihapus secara permanen.',
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
          'Warning: Your account will be permanently deleted.',
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
    setState(
      () =>
          _selectedLanguage = prefs.getString('selected_language') ?? 'system',
    );
  }

  String _l(String key) => _localizedStrings[_selectedLanguage]?[key] ?? key;

  static Future<String?> _getToken() async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d.containsKey('access_token') && d['access_token'] != null) {
          return d['access_token'];
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initializeUserInfo() async {
    _accessToken = await _getToken();
    if (_accessToken != null) await _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoadingDisplay = true);
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('Email');
    if (email == null) {
      setState(() => _isLoadingDisplay = false);
      return;
    }
    setState(() => _email = email);
    try {
      final r = await http.post(
        Uri.parse('$baseURL/api/asn/getDataUser'),
        headers: {
          'Authorization': 'bearer $_accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );
      if (r.statusCode == 200) {
        setState(() {
          _profileDisplay = ProfileDisplay.fromJson(json.decode(r.body));
          _isLoadingDisplay = false;
        });
      } else {
        setState(() => _isLoadingDisplay = false);
      }
    } catch (_) {
      setState(() => _isLoadingDisplay = false);
    }
  }

  // ── FIX: Foto Profil — pakai XFile.readAsBytes(), tidak pakai File() ─────
  Future<void> _pickImageFromGallery() async {
    try {
      // Permission hanya di mobile native
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (!await _checkGalleryPermission()) {
          _showErrorSnackBar('Permission galeri tidak diberikan');
          return;
        }
      }
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image != null) {
        // ← readAsBytes() bekerja di semua platform
        final bytes = await image.readAsBytes();
        await _uploadProfilePhotoBytes(bytes);
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memilih gambar: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (!await _checkCameraPermission()) {
          _showErrorSnackBar('Permission kamera tidak diberikan');
          return;
        }
      }
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        await _uploadProfilePhotoBytes(bytes);
      }
    } catch (e) {
      _showErrorSnackBar('Gagal mengambil foto: $e');
    }
  }

  Future<bool> _checkCameraPermission() async {
    var s = await Permission.camera.status;
    if (s.isDenied || s.isPermanentlyDenied) {
      s = await Permission.camera.request();
    }
    if (s.isPermanentlyDenied) {
      _showPermissionDialog('Kamera', 'kamera');
      return false;
    }
    return s.isGranted;
  }

  Future<bool> _checkGalleryPermission() async {
    Permission p;
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      p = info.version.sdkInt >= 33 ? Permission.photos : Permission.storage;
    } else {
      p = Permission.photos;
    }
    var s = await p.status;
    if (s.isDenied || s.isPermanentlyDenied) s = await p.request();
    if (s.isPermanentlyDenied) {
      _showPermissionDialog('Galeri', 'mengakses galeri');
      return false;
    }
    return s.isGranted;
  }

  void _showPermissionDialog(String name, String action) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Permission $name Diperlukan'),
        content: Text(
          'Aplikasi memerlukan akses $action untuk mengubah foto profil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  // ← Terima Uint8List langsung (bukan File)
  Future<void> _uploadProfilePhotoBytes(List<int> bytes) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final base64Image = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email') ?? '';
      if (email.isEmpty) {
        _showErrorSnackBar('Email tidak ditemukan');
        return;
      }

      final tokenResp = await http.post(
        Uri.parse('$baseURL/api/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'password', 'password': 'ASN_DBS'},
      );
      if (tokenResp.statusCode != 200) {
        _showErrorSnackBar('Gagal mendapatkan token');
        return;
      }
      final token = json.decode(tokenResp.body)['access_token'];

      final r = await http.post(
        Uri.parse('$baseURL/api/asn/user/profile/photo/upload-base64'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email, 'FotoProfilBase64': base64Image}),
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final rb = json.decode(r.body);
        if (rb['success'] == true) {
          _showSuccessSnackBar(
            rb['message'] ?? 'Foto profil berhasil diperbarui',
          );
          await _loadProfileData();
        } else {
          _showErrorSnackBar(rb['message'] ?? 'Gagal memperbarui foto profil');
        }
      } else {
        final rb = json.decode(r.body);
        _showErrorSnackBar(rb['message'] ?? 'Gagal memperbarui foto profil');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error upload: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showSuccessSnackBar(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showErrorSnackBar(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showLogoutBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _l('logout'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _l('logoutConfirm'),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      _l('cancel'),
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
                      Navigator.pop(context);
                      _performLogout();
                    },
                    child: Text(
                      _l('yes'),
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountBottomSheet() {
    final passwordCtrl = TextEditingController();
    bool hidePassword = true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setDS) => SingleChildScrollView(
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
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[600],
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  _l('deleteAccount'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    _l('deleteAccountWarning'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _l('deleteAccountConfirm'),
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordCtrl,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    hintText: _l('passwordHint'),
                    labelText: _l('deleteAccountPassword'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDS(() => hidePassword = !hidePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          passwordCtrl.dispose();
                          Navigator.pop(context);
                        },
                        child: Text(
                          _l('cancel'),
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
                                if (passwordCtrl.text.isEmpty) {
                                  _showErrorSnackBar(
                                    'Silakan masukkan password',
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                passwordCtrl.dispose();
                                _performDeleteAccount();
                              },
                        child: _isDeletingAccount
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _l('yesDelete'),
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
        ),
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    if (_profileDisplay == null) {
      _showErrorSnackBar('Data profil tidak ditemukan');
      return;
    }
    setState(() => _isDeletingAccount = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email') ?? '';
      final r = await http
          .post(
            Uri.parse('$baseURL/api/asn/user/deleteAccount'),
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'UserId': _profileDisplay!.id.toString(),
              'UpdatedBy': email,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final rb = json.decode(r.body);
        final msg = rb['Message'] ?? rb['message'] ?? '';
        if (msg.toLowerCase().contains('successfully')) {
          _showSuccessSnackBar(_l('successDeleteAccount'));
          await Future.delayed(const Duration(seconds: 2));
          await prefs.clear();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
        } else {
          _showErrorSnackBar(msg);
        }
      } else {
        final rb = json.decode(r.body);
        _showErrorSnackBar(
          rb['Message'] ?? rb['message'] ?? _l('errorDeleteAccount'),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<void> _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Coming Soon'),
        content: const Text('Untuk saat ini masih dalam pengembangan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWideScreen(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(child: isWeb ? _buildWebLayout() : _buildMobileLayout()),
    );
  }

  Widget _buildMobileLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final hPad = isSmall ? 16.0 : 24.0;
    const avatarRadius = 50.0;
    const titleFs = 24.0;
    const sectionFs = 18.0;
    const menuFs = 16.0;
    const iconSz = 22.0;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      children: [
        Center(
          child: Text(
            _l('profile'),
            style: const TextStyle(
              fontSize: titleFs,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildProfileHeader(avatarRadius, menuFs),
        const SizedBox(height: 28),
        _buildSectionTitle(_l('myInfo'), sectionFs),
        const SizedBox(height: 8),
        _buildInfoSection(iconSz, menuFs),
        const SizedBox(height: 24),
        _buildSectionTitle(_l('settings'), sectionFs),
        const SizedBox(height: 8),
        _buildSettingsSection(iconSz, menuFs),
        const SizedBox(height: 24),
        _buildSectionTitle(_l('helpSupport'), sectionFs),
        const SizedBox(height: 8),
        _buildHelpSection(iconSz, menuFs),
        const SizedBox(height: 20),
        _buildLogoutButton(menuFs),
        const SizedBox(height: 12),
        _buildDeleteAccountButton(menuFs),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWebLayout() {
    const avatarRadius = 60.0;
    const menuFs = 15.0;
    const iconSz = 20.0;
    const sectionFs = 16.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _l('profile'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileHeader(avatarRadius, menuFs),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildLogoutButton(menuFs),
                  const SizedBox(height: 8),
                  _buildDeleteAccountButton(menuFs),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(_l('myInfo'), sectionFs),
                          const SizedBox(height: 8),
                          _buildInfoSection(iconSz, menuFs),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(_l('settings'), sectionFs),
                          const SizedBox(height: 8),
                          _buildSettingsSection(iconSz, menuFs),
                          const SizedBox(height: 20),
                          _buildSectionTitle(_l('helpSupport'), sectionFs),
                          const SizedBox(height: 8),
                          _buildHelpSection(iconSz, menuFs),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(double avatarRadius, double menuFs) {
    if (_isLoadingDisplay) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
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
                    : () => showModalBottomSheet(
                        context: context,
                        builder: (_) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: Text(_l('selectFromGallery')),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImageFromGallery();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: Text(_l('takePhoto')),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImageFromCamera();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: _isUploadingPhoto
                      ? Colors.grey
                      : Colors.blue,
                  child: const Icon(Icons.edit, color: Colors.white, size: 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _profileDisplay?.displayName ?? _l('username'),
          style: TextStyle(fontSize: menuFs + 2, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Text(
          _email.isNotEmpty ? _email : 'email@domain.com',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        Text(
          _profileDisplay?.jobs ?? _l('position'),
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoSection(double iconSz, double menuFs) => _buildMenuSection([
    _buildMenuItem(
      Icons.person_outline,
      _l('personalInfo'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InfoProfileScreen()),
      ),
    ),
    _buildMenuItem(
      Icons.emergency,
      _l('emergencyContact'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EmergencyContactScreen(userId: _profileDisplay?.userId ?? ''),
        ),
      ),
    ),
    _buildMenuItem(
      Icons.family_restroom,
      _l('familyInfo'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => _showComingSoonDialog(context),
    ),
    _buildMenuItem(
      Icons.school_outlined,
      _l('education'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => _showComingSoonDialog(context),
    ),
    _buildMenuItem(
      Icons.payment_outlined,
      _l('salaryInfo'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => _showComingSoonDialog(context),
    ),
    _buildMenuItem(
      Icons.warning_amber_outlined,
      _l('reprimand'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => _showComingSoonDialog(context),
    ),
  ]);

  Widget _buildSettingsSection(double iconSz, double menuFs) =>
      _buildMenuSection([
        _buildMenuItem(
          Icons.lock_outline,
          _l('changeSecurity'),
          iconSize: iconSz,
          fontSize: menuFs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HalamanPengaturanKeamanan(),
            ),
          ),
        ),
        _buildMenuItem(
          Icons.access_time_outlined,
          _l('attendanceReminder'),
          iconSize: iconSz,
          fontSize: menuFs,
          onTap: () => _showComingSoonDialog(context),
        ),
      ]);

  Widget _buildHelpSection(double iconSz, double menuFs) => _buildMenuSection([
    _buildMenuItem(
      Icons.privacy_tip_outlined,
      _l('privacyPolicy'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanKebijakanPrivasi()),
      ),
    ),
    _buildMenuItem(
      Icons.help_outline,
      _l('helpSupport'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanBantuanDukungan()),
      ),
    ),
    _buildMenuItem(
      Icons.contact_mail_outlined,
      _l('contactUs'),
      iconSize: iconSz,
      fontSize: menuFs,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanHubungiKami()),
      ),
    ),
  ]);

  Widget _buildLogoutButton(double menuFs) => SizedBox(
    width: double.infinity,
    child: TextButton.icon(
      onPressed: _showLogoutBottomSheet,
      icon: const Icon(Icons.logout, color: Colors.blue),
      label: Text(
        _l('logout'),
        style: TextStyle(color: Colors.blue, fontSize: menuFs),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );

  Widget _buildDeleteAccountButton(double menuFs) => SizedBox(
    width: double.infinity,
    child: TextButton.icon(
      onPressed: _isDeletingAccount ? null : _showDeleteAccountBottomSheet,
      icon: Icon(
        Icons.delete_forever,
        color: _isDeletingAccount ? Colors.grey : Colors.red,
      ),
      label: Text(
        _l('deleteAccount'),
        style: TextStyle(
          color: _isDeletingAccount ? Colors.grey : Colors.red,
          fontSize: menuFs,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );

  Widget _buildSectionTitle(String title, double fontSize) => Text(
    title,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );

  Widget _buildMenuSection(List<Widget> items) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(children: items),
  );

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? trailingText,
    VoidCallback? onTap,
    double iconSize = 22,
    double fontSize = 16,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700, size: iconSize),
            const SizedBox(width: 14),
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
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    ),
  );
}
