// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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

bool _isWebLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class ProfileScreenAdmin extends StatefulWidget {
  const ProfileScreenAdmin({super.key});
  @override
  _ProfileScreenAdminState createState() => _ProfileScreenAdminState();
}

class _ProfileScreenAdminState extends State<ProfileScreenAdmin> {
  bool _isLoadingDisplay = true;
  bool _isUploadingPhoto = false;
  bool _isDeletingAccount = false;
  String _email = '';
  ProfileDisplay? _profileDisplay;
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
      'attendanceReminder': 'Pengingat Absen',
      'language': 'Bahasa',
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
      'deleteAccount': 'Hapus Akun',
      'deleteAccountConfirm':
          'Apakah Anda yakin ingin menghapus akun ini secara permanen?',
      'deleteAccountWarning':
          'Peringatan: Akun Anda akan dihapus secara permanen dan semua data terkait akan hilang. Tindakan ini tidak dapat dibatalkan.',
      'deleteAccountPassword': 'Masukkan password Anda untuk konfirmasi',
      'passwordHint': 'Password',
      'yesDelete': 'Ya, Hapus Akun',
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
      'education': 'Education & Experience',
      'salaryInfo': 'Salary Information',
      'additionalInfo': 'Additional Information',
      'reprimand': 'Reprimand',
      'settings': 'Settings',
      'changeSecurity': 'Change Security',
      'attendanceReminder': 'Attendance Reminder',
      'language': 'Language',
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
      'deleteAccount': 'Delete Account',
      'deleteAccountConfirm':
          'Are you sure you want to permanently delete this account?',
      'deleteAccountWarning':
          'Warning: Your account will be permanently deleted and all associated data will be lost.',
      'deleteAccountPassword': 'Enter your password to confirm',
      'passwordHint': 'Password',
      'yesDelete': 'Yes, Delete Account',
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

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () =>
          _selectedLanguage = prefs.getString('selected_language') ?? 'system',
    );
  }

  String _t(String key) =>
      _localizedStrings[_selectedLanguage]?[key] ??
      _localizedStrings['system']?[key] ??
      key;

  Future<void> _initializeUserInfo() async {
    setState(() => _isLoadingDisplay = true);
    final token = await _getToken();
    if (token == null) {
      setState(() => _isLoadingDisplay = false);
      return;
    }
    await _loadProfileData(token);
  }

  Future<void> _loadProfileData(String token) async {
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
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() {
          _profileDisplay = ProfileDisplay.fromJson(json.decode(r.body));
          _isLoadingDisplay = false;
        });
      } else if (r.statusCode == 401) {
        final newToken = await _getToken();
        if (newToken != null) {
          await _loadProfileData(newToken);
        } else {
          setState(() => _isLoadingDisplay = false);
        }
      } else {
        setState(() => _isLoadingDisplay = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDisplay = false);
    }
  }

  // ── FIX: Foto Profil — pakai XFile.readAsBytes(), tidak pakai File() ─────
  Future<void> _pickImageFromGallery() async {
    try {
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  // ← Terima List<int> bytes langsung — tidak perlu File
  Future<void> _uploadProfilePhotoBytes(List<int> bytes) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final b64 = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email') ?? '';
      if (email.isEmpty) {
        _showErrorSnackBar('Email tidak ditemukan');
        return;
      }
      final token = await _getToken();
      if (token == null) {
        _showErrorSnackBar('Gagal mendapatkan token');
        return;
      }
      final r = await http.post(
        Uri.parse('$baseURL/api/asn/user/profile/photo/upload-base64'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email, 'FotoProfilBase64': b64}),
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        if (body['success'] == true) {
          _showSuccessSnackBar(body['message'] ?? 'Foto berhasil diperbarui');
          await _loadProfileData(token);
        } else {
          _showErrorSnackBar(body['message'] ?? 'Gagal memperbarui foto');
        }
      } else if (r.statusCode == 401) {
        final newToken = await _getToken();
        if (newToken != null) {
          await _uploadProfilePhotoBytes(bytes);
        } else {
          _showErrorSnackBar('Authentication gagal');
        }
      } else {
        _showErrorSnackBar('Gagal memperbarui foto');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error: $e');
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

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(child: isWeb ? _buildWebLayout() : _buildMobileLayout()),
    );
  }

  Widget _buildMobileLayout() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    children: [
      Center(
        child: Text(
          _t('profile'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 24),
      _buildAvatarSection(avatarRadius: 50),
      const SizedBox(height: 28),
      _buildSectionTitle(_t('myInfo')),
      const SizedBox(height: 8),
      _buildMenuSection(_myInfoItems()),
      const SizedBox(height: 24),
      _buildSectionTitle(_t('settings')),
      const SizedBox(height: 8),
      _buildMenuSection(_settingsItems()),
      const SizedBox(height: 24),
      _buildSectionTitle(_t('helpSupport')),
      const SizedBox(height: 8),
      _buildMenuSection(_helpItems()),
      const SizedBox(height: 20),
      _buildLogoutButton(),
      const SizedBox(height: 8),
      _buildDeleteAccountButton(),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildWebLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 280,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildAvatarSection(avatarRadius: 56),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildWebInfoRow(
                Icons.badge_outlined,
                _profileDisplay?.userId ?? '-',
              ),
              const SizedBox(height: 8),
              _buildWebInfoRow(Icons.email_outlined, _email),
              const SizedBox(height: 8),
              _buildWebInfoRow(
                Icons.work_outline,
                _profileDisplay?.jobs ?? _t('position'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutBottomSheet,
                  icon: const Icon(Icons.logout, color: Colors.red, size: 16),
                  label: Text(
                    _t('logout'),
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isDeletingAccount
                      ? null
                      : _showDeleteAccountBottomSheet,
                  icon: Icon(
                    Icons.delete_forever,
                    color: _isDeletingAccount ? Colors.grey : Colors.red,
                    size: 16,
                  ),
                  label: Text(
                    _t('deleteAccount'),
                    style: TextStyle(
                      color: _isDeletingAccount ? Colors.grey : Colors.red,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isDeletingAccount
                          ? Colors.grey.withOpacity(0.4)
                          : Colors.red.withOpacity(0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('profile'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWebSectionHeader(
                          _t('myInfo'),
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 10),
                        _buildWebMenuGrid(_myInfoItems()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWebSectionHeader(
                          _t('settings'),
                          Icons.settings_outlined,
                        ),
                        const SizedBox(height: 10),
                        _buildWebMenuGrid(_settingsItems()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildWebSectionHeader(_t('helpSupport'), Icons.help_outline),
              const SizedBox(height: 10),
              Row(
                children: _helpItems()
                    .map(
                      (item) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildWebMenuCard(item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildWebInfoRow(IconData icon, String value) => Row(
    children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _buildWebSectionHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
    ],
  );

  Widget _buildWebMenuGrid(List<_MenuItem> items) => Column(
    children: items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildWebMenuCard(item),
          ),
        )
        .toList(),
  );

  Widget _buildWebMenuCard(_MenuItem item) => GestureDetector(
    onTap: item.onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 16, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
        ],
      ),
    ),
  );

  Widget _buildAvatarSection({required double avatarRadius}) {
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
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _showPhotoOptions,
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
          _profileDisplay?.displayName ?? _t('username'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Text(
          _email.isNotEmpty ? _email : 'email@domain.com',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Text(
          _profileDisplay?.jobs ?? _t('position'),
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  void _showPhotoOptions() => showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(_t('selectFromGallery')),
            onTap: () {
              Navigator.of(context).pop();
              _pickImageFromGallery();
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text(_t('takePhoto')),
            onTap: () {
              Navigator.of(context).pop();
              _pickImageFromCamera();
            },
          ),
        ],
      ),
    ),
  );

  List<_MenuItem> _myInfoItems() => [
    _MenuItem(
      icon: Icons.person_outline,
      title: _t('personalInfo'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InfoProfileScreen()),
      ),
    ),
    _MenuItem(
      icon: Icons.emergency,
      title: _t('emergencyContact'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EmergencyContactScreen(userId: _profileDisplay?.userId ?? ''),
        ),
      ),
    ),
    _MenuItem(
      icon: Icons.family_restroom,
      title: _t('familyInfo'),
      onTap: _showComingSoonDialog,
    ),
    _MenuItem(
      icon: Icons.school_outlined,
      title: _t('education'),
      onTap: _showComingSoonDialog,
    ),
    _MenuItem(
      icon: Icons.payment_outlined,
      title: _t('salaryInfo'),
      onTap: _showComingSoonDialog,
    ),
    _MenuItem(
      icon: Icons.warning_amber_outlined,
      title: _t('reprimand'),
      onTap: _showComingSoonDialog,
    ),
  ];

  List<_MenuItem> _settingsItems() => [
    _MenuItem(
      icon: Icons.lock_outline,
      title: _t('changeSecurity'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanPengaturanKeamanan()),
      ),
    ),
    _MenuItem(
      icon: Icons.access_time_outlined,
      title: _t('attendanceReminder'),
      onTap: _showComingSoonDialog,
    ),
    _MenuItem(
      icon: Icons.swap_horiz,
      title: _t('switchToUserMode'),
      onTap: _showSwitchModeBottomSheet,
    ),
  ];

  List<_MenuItem> _helpItems() => [
    _MenuItem(
      icon: Icons.privacy_tip_outlined,
      title: _t('privacyPolicy'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanKebijakanPrivasi()),
      ),
    ),
    _MenuItem(
      icon: Icons.help_outline,
      title: _t('helpSupport'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanBantuanDukungan()),
      ),
    ),
    _MenuItem(
      icon: Icons.contact_mail_outlined,
      title: _t('contactUs'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanHubungiKami()),
      ),
    ),
  ];

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildMenuSection(List<_MenuItem> items) => Container(
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
    child: Column(children: items.map(_buildMobileMenuItem).toList()),
  );

  Widget _buildMobileMenuItem(_MenuItem item) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(item.icon, color: Colors.grey.shade700, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    ),
  );

  Widget _buildLogoutButton() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: TextButton.icon(
      onPressed: _showLogoutBottomSheet,
      icon: const Icon(Icons.logout, color: Colors.red),
      label: Text(
        _t('logout'),
        style: const TextStyle(color: Colors.red, fontSize: 15),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );

  Widget _buildDeleteAccountButton() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: TextButton.icon(
      onPressed: _isDeletingAccount ? null : _showDeleteAccountBottomSheet,
      icon: Icon(
        Icons.delete_forever,
        color: _isDeletingAccount ? Colors.grey : Colors.red,
      ),
      label: Text(
        _t('deleteAccount'),
        style: TextStyle(
          color: _isDeletingAccount ? Colors.grey : Colors.red,
          fontSize: 15,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );

  void _showComingSoonDialog() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
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

  void _showLogoutBottomSheet() => showModalBottomSheet(
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
            _t('logout'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t('logoutConfirm'),
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t('cancel')),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _performLogout();
                  },
                  child: Text(
                    _t('yes'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _showSwitchModeBottomSheet() => showModalBottomSheet(
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
            _t('switchToUserMode'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.orange[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t('switchModeConfirm'),
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t('cancel')),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _performSwitchToUserMode();
                  },
                  child: Text(
                    _t('yesSwitch'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

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
      builder: (_) => StatefulBuilder(
        builder: (ctx, setMS) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 40,
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
                  _t('deleteAccount'),
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
                    _t('deleteAccountWarning'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _t('deleteAccountConfirm'),
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    hintText: _t('passwordHint'),
                    labelText: _t('deleteAccountPassword'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setMS(() => hidePassword = !hidePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          passwordController.dispose();
                          Navigator.of(ctx).pop();
                        },
                        child: Text(_t('cancel')),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                                Navigator.of(ctx).pop();
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
                                _t('yesDelete'),
                                style: const TextStyle(color: Colors.white),
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
      final token = await _getToken();
      if (token == null) {
        _showErrorSnackBar('Gagal mendapatkan token');
        setState(() => _isDeletingAccount = false);
        return;
      }
      final r = await http
          .post(
            Uri.parse('$baseURL/api/asn/user/deleteAccount'),
            headers: {
              'Authorization': 'Bearer $token',
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
        final body = json.decode(r.body);
        final message = body['Message'] ?? body['message'] ?? '';
        if (message.toLowerCase().contains('successfully')) {
          _showSuccessSnackBar(_t('successDeleteAccount'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('accountDeletedRedirect')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          await prefs.clear();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
        } else {
          _showErrorSnackBar(
            message.isNotEmpty ? message : _t('errorDeleteAccount'),
          );
        }
      } else {
        final body = json.decode(r.body);
        _showErrorSnackBar(
          body['Message'] ?? body['message'] ?? _t('errorDeleteAccount'),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  void _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  void _performSwitchToUserMode() => Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  const _MenuItem({required this.icon, required this.title, this.onTap});
}
