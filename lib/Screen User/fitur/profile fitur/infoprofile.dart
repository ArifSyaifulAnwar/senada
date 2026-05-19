// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/edit_profile_screen.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/filecategory.dart';
import 'package:absensikaryawan/Services/fileuserresponse.dart';
import 'package:absensikaryawan/Services/profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

// ── helper ──────────────────────────────────────────────────────────

class InfoProfileScreen extends StatefulWidget {
  final int initialTabIndex;
  const InfoProfileScreen({super.key, this.initialTabIndex = 0});

  @override
  _InfoProfileScreenState createState() => _InfoProfileScreenState();
}

class _InfoProfileScreenState extends State<InfoProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  String? _accessToken;
  ProfileDisplay? _profileDisplay;
  String employeeID = '';
  String barcode = '';
  String companyName = '';
  String branch = '';
  String organization = '';
  String jobPosition = '';
  String jobLevel = '';
  String employmentStatus = '';
  String joinDate = '';
  String endContractDate = '';
  int workingPeriodYear = 0;
  int workingPeriodMonth = 0;
  int workingPeriodDay = 0;
  String grade = '';
  String className = '';
  String approvalLine = '';
  String manager = '';
  List<FileUserResponse> _userFiles = [];
  bool _isLoadingFiles = false;

  int _selectedTabIndex = 0;
  final List<String> _tabs = ["Personal", "Profesional", "Dokumen"];
  String _searchQuery = '';
  String _sortBy = 'newest';
  List<FileCategory> _categories = [];
  FileCategory? _selectedCategoryFile;
  TextEditingController categoryController = TextEditingController();
  Uint8List? fileBytes;
  String? mimeType;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _initProfile();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  // ─── semua method API tidak berubah ──────────────────────────────
  Future<void> _loadCategories() async {
    try {
      if (_accessToken == null) await _getToken();
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/file/category/all'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _categories = [
            FileCategory(id: 0, name: 'Semua'),
            ...data.map((item) => FileCategory.fromJson(item)),
          ];
          _selectedCategoryFile = _categories[0];
        });
      } else if (response.statusCode == 401) {
        await _refreshTokenAndRetry();
        await _loadCategories();
      } else {
        setState(() {
          _categories = [
            FileCategory(id: 0, name: 'Semua'),
            FileCategory(id: 6, name: 'Lainnya'),
          ];
          _selectedCategoryFile = _categories[0];
        });
      }
    } catch (e) {
      setState(() {
        _categories = [
          FileCategory(id: 0, name: 'Semua'),
          FileCategory(id: 6, name: 'Lainnya'),
        ];
        _selectedCategoryFile = _categories[0];
      });
    }
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
        _accessToken = data.containsKey('access_token')
            ? data['access_token']
            : null;
      } else {
        _accessToken = null;
      }
    } catch (_) {
      _accessToken = null;
    }
  }

  Future<void> _refreshTokenAndRetry() async {
    await _getToken();
    if (_accessToken == null) throw Exception('Failed to refresh token');
  }

  Future<http.Response> _makeAuthenticatedRequest({
    required String url,
    required Map<String, String> headers,
    String? body,
    String method = 'POST',
  }) async {
    if (_accessToken == null) {
      await _getToken();
      if (_accessToken == null) {
        throw Exception('Unable to obtain access token');
      }
    }
    final authHeaders = {...headers, 'Authorization': 'Bearer $_accessToken'};
    http.Response response;
    try {
      response = method.toUpperCase() == 'POST'
          ? await http.post(Uri.parse(url), headers: authHeaders, body: body)
          : await http.get(Uri.parse(url), headers: authHeaders);
      if (response.statusCode == 401) {
        await _refreshTokenAndRetry();
        authHeaders['Authorization'] = 'Bearer $_accessToken';
        response = method.toUpperCase() == 'POST'
            ? await http.post(Uri.parse(url), headers: authHeaders, body: body)
            : await http.get(Uri.parse(url), headers: authHeaders);
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _initProfile() async {
    try {
      await _getToken();
      if (_accessToken != null && mounted) {
        await Future.wait([
          _loadProfileData(),
          _loadProfileProfessional(),
          _loadUserFiles(),
          _loadCategories(),
        ]);
      }
      _safeSetState(() => _isLoading = false);
    } catch (_) {
      _safeSetState(() => _isLoading = false);
    }
  }

  void _safeSetState(VoidCallback cb) {
    if (mounted) setState(cb);
  }

  String _formatDate(String s) {
    if (s.isEmpty) return '';
    try {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  Map<String, int> _calculateWorkingPeriod(String joinDateStr) {
    if (joinDateStr.isEmpty) return {'years': 0, 'months': 0, 'days': 0};
    try {
      final jd = DateTime.parse(joinDateStr);
      final now = DateTime.now();
      int years = now.year - jd.year;
      int months = now.month - jd.month;
      int days = now.day - jd.day;
      if (days < 0) {
        months--;
        days += DateTime(now.year, now.month, 0).day;
      }
      if (months < 0) {
        years--;
        months += 12;
      }
      return {'years': years, 'months': months, 'days': days};
    } catch (_) {
      return {'years': 0, 'months': 0, 'days': 0};
    }
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('Email');
    if (email == null) {
      _safeSetState(() => _isLoading = false);
      return;
    }
    try {
      final response = await _makeAuthenticatedRequest(
        url: '$baseURL/api/asn/getDataUser',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final rj = json.decode(response.body);
        if (rj['data'] != null) {
          _safeSetState(() => _profileDisplay = ProfileDisplay.fromJson(rj));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadProfileProfessional() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('Email');
    final userId = prefs.getString('UserID');
    if (email == null || userId == null) return;
    try {
      final response = await _makeAuthenticatedRequest(
        url: '$baseURL/api/asn/getCompanyInfo',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Mail': email, 'UserId': userId}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final rj = json.decode(response.body);
        _safeSetState(() {
          employeeID = rj['EmployeeID'] ?? '';
          barcode = rj['Barcode'] ?? '';
          companyName = rj['CompanyName'] ?? '';
          branch = rj['Branch'] ?? '';
          organization = rj['Organization'] ?? '';
          jobPosition = rj['JobPosition'] ?? '';
          jobLevel = rj['JobLevel'] ?? '';
          employmentStatus = rj['EmploymentStatus'] ?? '';
          joinDate = rj['JoinDate'] ?? '';
          endContractDate = rj['EndContractDate'] ?? '';
          grade = rj['Grade'] ?? '';
          className = rj['Class'] ?? '';
          approvalLine = rj['ApprovalLine'] ?? '';
          manager = rj['Manager'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserFiles() async {
    if (!mounted) return;
    _safeSetState(() => _isLoadingFiles = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    final mail = prefs.getString('Email');
    if (userId == null || mail == null) {
      _safeSetState(() => _isLoadingFiles = false);
      return;
    }
    try {
      final response = await _makeAuthenticatedRequest(
        url: '$baseURL/api/asn/file/get',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'UserId': userId, 'Mail': mail}),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _safeSetState(() {
          _userFiles = data
              .map((item) => FileUserResponse.fromJson(item))
              .toList();
        });
      } else {
        _safeSetState(() => _userFiles = []);
      }
    } catch (_) {
      _safeSetState(() => _userFiles = []);
    }
    _safeSetState(() => _isLoadingFiles = false);
  }

  Future<Uint8List> _getFileContent(int fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    final mail = prefs.getString('Email');
    if (userId == null || mail == null) throw Exception('User tidak ditemukan');
    final response = await _makeAuthenticatedRequest(
      url: '$baseURL/api/asn/file/download',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/octet-stream',
      },
      body: json.encode({'Id': fileId, 'UserId': userId, 'Mail': mail}),
    );
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Gagal mengunduh file: ${response.statusCode}');
  }

  Future<void> _performUpload(
    String userId,
    String mail,
    String fileName,
    Uint8List fileBytes,
    String? mimeType,
    String category,
    String description,
  ) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            const Text('Mengupload file...'),
          ],
        ),
      ),
    );
    try {
      final response = await _makeAuthenticatedRequest(
        url: '$baseURL/api/asn/file/upload',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'UserId': userId,
          'Name': fileName,
          'Mail': mail,
          'FileCategory': category,
          'Description': description,
          'FileContent': base64Encode(fileBytes),
          'FileType': mimeType,
        }),
      );
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File berhasil diunggah'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupload: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFile(int fileId) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    final mail = prefs.getString('Email');
    if (userId == null || mail == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            const Text('Menghapus file...'),
          ],
        ),
      ),
    );
    try {
      final response = await _makeAuthenticatedRequest(
        url: '$baseURL/api/asn/file/delete',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'Id': fileId, 'UserId': userId, 'Mail': mail}),
      );
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserFiles();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _previewFile(FileUserResponse file) async {
    if (!mounted) return;
    try {
      if (file.fileType.startsWith('image/')) {
        _showImagePreview(file);
        return;
      }
      await _openFileWithExternalApp(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openFileWithExternalApp(FileUserResponse file) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            const Text('Memuat file...'),
          ],
        ),
      ),
    );
    try {
      final bytes = await _getFileContent(file.id);
      if (mounted) Navigator.pop(context);
      if (Platform.isAndroid || Platform.isIOS) {
        await _openFileOnMobile(file, bytes);
      } else {
        await _openFileOnDesktop(file, bytes);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openFileOnMobile(FileUserResponse file, Uint8List bytes) async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            _showInternalFilePreview(file, bytes);
            return;
          }
        }
      }
      Directory? dir;
      if (Platform.isAndroid) {
        try {
          dir = await getExternalStorageDirectory();
        } catch (_) {
          dir = await getApplicationDocumentsDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir == null) throw Exception('Tidak dapat mengakses penyimpanan');
      final f = File('${dir.path}/${_createSafeFileName(file.name)}');
      await f.writeAsBytes(bytes);
      final result = await OpenFile.open(f.path);
      if (result.type != ResultType.done) _showInternalFilePreview(file, bytes);
    } catch (_) {
      _showInternalFilePreview(file, bytes);
    }
  }

  Future<void> _openFileOnDesktop(
    FileUserResponse file,
    Uint8List bytes,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${_createSafeFileName(file.name)}');
      await f.writeAsBytes(bytes);
      final result = await OpenFile.open(f.path);
      if (result.type != ResultType.done) _showInternalFilePreview(file, bytes);
    } catch (_) {
      _showInternalFilePreview(file, bytes);
    }
  }

  String _createSafeFileName(String name) {
    final safe = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final dot = safe.lastIndexOf('.');
    return dot != -1
        ? '${safe.substring(0, dot)}_$ts${safe.substring(dot)}'
        : '${safe}_$ts';
  }

  void _showInternalFilePreview(FileUserResponse file, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(file.fileType),
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        file.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileIcon(file.fileType),
                        size: 60,
                        color: _getFileColor(file.fileType),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Preview Dokumen',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'File: ${file.name}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ukuran: ${_formatFileSize(bytes.length)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _downloadFile(file, bytes);
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _shareFile(file, bytes),
                            icon: const Icon(Icons.share),
                            label: const Text('Bagikan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile(FileUserResponse file, Uint8List bytes) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir != null) {
        final f = File('${dir.path}/${_createSafeFileName(file.name)}');
        await f.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded ke ${f.path}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Buka',
                textColor: Colors.white,
                onPressed: () => OpenFile.open(f.path),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareFile(FileUserResponse file, Uint8List bytes) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur berbagi akan segera tersedia'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showImagePreview(FileUserResponse file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  file.name,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () async {
                      try {
                        final bytes = await _getFileContent(file.id);
                        await _downloadFile(file, bytes);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal download: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              Expanded(
                child: FutureBuilder<Uint8List>(
                  future: _getFileContent(file.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'Data kosong',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadFile(String source) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    final mail = prefs.getString('Email');
    if (userId == null || mail == null) return;

    try {
      Uint8List? bytes;
      String? fileName;
      String? mimeType;

      if (source == 'camera') {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera);
        if (photo != null) {
          bytes = await photo.readAsBytes();
          fileName = photo.name;
          mimeType = 'image/jpeg';
        }
      } else if (source == 'gallery') {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          bytes = await image.readAsBytes();
          fileName = image.name;
          mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
        }
      } else {
        final result = await FilePicker.platform.pickFiles(type: FileType.any);
        if (result != null) {
          final path = result.files.single.path!;
          final name = result.files.single.name;
          final mime = lookupMimeType(name);
          final fb = await File(path).readAsBytes();
          await _showUploadDialog(userId, mail, name, fb, mime);
          return;
        }
      }
      if (bytes != null && fileName != null && mounted) {
        await _showUploadDialog(userId, mail, fileName, bytes, mimeType);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showUploadDialog(
    String userId,
    String mail,
    String fileName,
    Uint8List fileBytes,
    String? mimeType,
  ) async {
    if (!mounted) return;
    final descCtrl = TextEditingController();
    FileCategory? selCat;
    final uploadCats = _categories.where((c) => c.name != 'Semua').toList();
    if (uploadCats.isNotEmpty) selCat = uploadCats.first;

    return showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_upload, color: Color(0xFF007AFF)),
              SizedBox(width: 8),
              Text('Upload Dokumen'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFileIcon(mimeType),
                        color: _getFileColor(mimeType),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatFileSize(fileBytes.length),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kategori',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FileCategory>(
                      value: selCat,
                      isExpanded: true,
                      items: uploadCats
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (v) => setDS(() => selCat = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Deskripsi (Opsional)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tambahkan deskripsi...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF007AFF)),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: selCat == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _performUpload(
                        userId,
                        mail,
                        fileName,
                        fileBytes,
                        mimeType,
                        selCat!.name,
                        descCtrl.text,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Memuat profil...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Tab selector (sama untuk semua lebar layar) ──────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(_tabs[0], 0),
                      _buildTabButton(_tabs[1], 1),
                      _buildTabButton(_tabs[2], 2),
                    ],
                  ),
                ),
              ),
            ),

            // ── Konten ───────────────────────────────────────────
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSel = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 2 && _selectedTabIndex != 2) _loadUserFiles();
          _safeSetState(() => _selectedTabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF007AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSel ? Colors.white : Colors.grey[600],
              fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildPersonalTab();
      case 1:
        return _buildProfessionalTab();
      case 2:
        return _buildDocumentsTab();
      default:
        return _buildPersonalTab();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PERSONAL TAB — web: 2 kolom grid items
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPersonalTab() {
    if (_profileDisplay == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Data profil tidak tersedia',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final editButton = Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(profileData: _profileDisplay!),
            ),
          );
          if (result == true) await _loadProfileData();
        },
        icon: const Icon(Icons.edit),
        label: const Text('Edit Profil'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    // Data items
    final dataItems = [
      _ItemData(
        'ID Pengguna',
        _profileDisplay!.userId,
        icon: Icons.badge_outlined,
      ),
      _ItemData(
        'Nama Lengkap',
        _profileDisplay!.fullName,
        icon: Icons.person_outline,
      ),
      _ItemData(
        'Alamat Email',
        _profileDisplay!.email,
        icon: Icons.email_outlined,
        valueColor: const Color(0xFF007AFF),
      ),
      _ItemData(
        'Nomor Telepon',
        _profileDisplay!.phoneNumber,
        icon: Icons.phone_outlined,
      ),
      _ItemData(
        'Telepon Tambahan',
        _profileDisplay!.additionalPhone ?? '-',
        icon: Icons.phone_outlined,
      ),
      _ItemData(
        'Jenis Kelamin',
        _profileDisplay!.gender ?? '-',
        icon: Icons.wc_outlined,
      ),
      _ItemData(
        'Tempat Lahir',
        _profileDisplay!.placeOfBirth ?? '-',
        icon: Icons.location_on_outlined,
      ),
      _ItemData(
        'Tanggal Lahir',
        _profileDisplay!.birthDate ?? '-',
        icon: Icons.calendar_today_outlined,
      ),
      _ItemData(
        'Status Pernikahan',
        _profileDisplay!.maritalStatus ?? '-',
        icon: Icons.favorite_outline,
      ),
      _ItemData(
        'Golongan Darah',
        _profileDisplay!.bloodType ?? '-',
        icon: Icons.bloodtype_outlined,
      ),
      _ItemData(
        'Agama',
        _profileDisplay!.religion ?? '-',
        icon: Icons.account_balance_outlined,
      ),
      _ItemData(
        'NIK',
        _profileDisplay!.nik ?? '-',
        icon: Icons.credit_card_outlined,
        sectionBefore: 'Identitas & Alamat',
      ),
      _ItemData(
        'NPWP',
        _profileDisplay!.npwp ?? '-',
        icon: Icons.credit_card_outlined,
      ),
      _ItemData(
        'NIP',
        _profileDisplay!.nip ?? '-',
        icon: Icons.credit_card_outlined,
      ),
      _ItemData(
        'Nomor Paspor',
        _profileDisplay!.passportNumber ?? '-',
        icon: Icons.card_travel_outlined,
      ),
      _ItemData(
        'Kedaluwarsa Paspor',
        _profileDisplay!.passportExpiry ?? '-',
        icon: Icons.date_range_outlined,
      ),
      _ItemData(
        'Kode Pos',
        _profileDisplay!.postalCode ?? '-',
        icon: Icons.markunread_mailbox_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 768;
        if (isWeb) {
          return _buildProfileTabWeb(
            editButton,
            dataItems,
            sectionLabel: 'Data Pribadi',
          );
        }
        return _buildProfileTabMobile(
          editButton,
          dataItems,
          sectionLabel: 'Data Pribadi',
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // PROFESSIONAL TAB — web: 2 kolom grid
  // ─────────────────────────────────────────────────────────────────
  Widget _buildProfessionalTab() {
    if (employeeID.isEmpty && companyName.isEmpty) {
      return const Center(
        child: Text(
          'Data profesional tidak tersedia.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final wp = _calculateWorkingPeriod(joinDate);
    final items = [
      _ItemData('ID Karyawan', employeeID, icon: Icons.badge_outlined),
      _ItemData('Barcode', barcode, icon: Icons.qr_code),
      _ItemData('Perusahaan', companyName, icon: Icons.business_outlined),
      _ItemData('Cabang', branch, icon: Icons.location_city_outlined),
      _ItemData('Organisasi', organization, icon: Icons.account_tree_outlined),
      _ItemData('Posisi Jabatan', jobPosition, icon: Icons.work_outline),
      _ItemData('Level Jabatan', jobLevel, icon: Icons.layers_outlined),
      _ItemData(
        'Status Karyawan',
        employmentStatus,
        icon: Icons.how_to_reg_outlined,
      ),
      _ItemData(
        'Tanggal Masuk',
        _formatDate(joinDate),
        icon: Icons.calendar_today_outlined,
      ),
      _ItemData(
        'Akhir Kontrak',
        _formatDate(endContractDate),
        icon: Icons.event_busy_outlined,
      ),
      _ItemData(
        'Masa Kerja',
        joinDate.isNotEmpty
            ? '${wp['years']} Th ${wp['months']} Bl ${wp['days']} Hr'
            : 'Tidak tersedia',
        icon: Icons.timelapse_outlined,
      ),
      _ItemData('Grade', grade, icon: Icons.grade_outlined),
      _ItemData('Kelas', className, icon: Icons.class_outlined),
      _ItemData(
        'Approval Line',
        approvalLine.isNotEmpty ? approvalLine : '-',
        icon: Icons.approval_outlined,
      ),
      _ItemData(
        'Atasan Langsung',
        manager.isNotEmpty ? manager : '-',
        icon: Icons.supervisor_account_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 768;
        if (isWeb) {
          return _buildProfileTabWeb(null, items);
        }
        return _buildProfileTabMobile(null, items);
      },
    );
  }

  // ── Mobile: Column list items ──────────────────────────────────
  Widget _buildProfileTabMobile(
    Widget? headerWidget,
    List<_ItemData> items, {
    String sectionLabel = '',
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerWidget != null) headerWidget,
          if (sectionLabel.isNotEmpty) _buildSectionHeader('Data Pribadi'),
          ...items.map((item) {
            final widgets = <Widget>[];
            if (item.sectionBefore != null) {
              widgets.add(const SizedBox(height: 8));
              widgets.add(_buildSectionHeader(item.sectionBefore!));
            }
            widgets.add(
              _buildProfileItem(
                label: item.label,
                value: item.value,
                icon: item.icon,
                valueColor: item.valueColor,
              ),
            );
            return Column(children: widgets);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Web: 2 kolom grid items ────────────────────────────────────
  Widget _buildProfileTabWeb(
    Widget? headerWidget,
    List<_ItemData> items, {
    String sectionLabel = '',
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerWidget != null) headerWidget,
          // Split items menjadi pasangan untuk 2 kolom
          // Items dengan sectionBefore tetap span full row
          _buildWebProfileGrid(items, sectionLabel: sectionLabel),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWebProfileGrid(
    List<_ItemData> items, {
    String sectionLabel = '',
  }) {
    if (sectionLabel.isNotEmpty) {
      // Kelompokkan: items sebelum sectionBefore pertama = Data Pribadi,
      // sisanya = Identitas & Alamat
    }

    final List<Widget> rows = [];
    if (sectionLabel.isNotEmpty) {
      rows.add(_buildSectionHeader('Data Pribadi'));
    }

    final List<_ItemData> current = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.sectionBefore != null && current.isNotEmpty) {
        rows.addAll(_buildItemPairs(current));
        current.clear();
        rows.add(const SizedBox(height: 8));
        rows.add(_buildSectionHeader(item.sectionBefore!));
      }
      current.add(item);
    }
    if (current.isNotEmpty) rows.addAll(_buildItemPairs(current));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  List<Widget> _buildItemPairs(List<_ItemData> items) {
    final List<Widget> result = [];
    for (int i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      result.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildProfileItem(
                  label: left.label,
                  value: left.value,
                  icon: left.icon,
                  valueColor: left.valueColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: right != null
                    ? _buildProfileItem(
                        label: right.label,
                        value: right.value,
                        icon: right.icon,
                        valueColor: right.valueColor,
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────
  // DOCUMENTS TAB — web: 2 panel (kiri upload+filter | kanan list)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildDocumentsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 768;
        if (isWeb) {
          return _buildDocumentsTabWeb();
        }
        return _buildDocumentsTabMobile();
      },
    );
  }

  // ── Mobile documents (layout asli) ────────────────────────────
  Widget _buildDocumentsTabMobile() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildUploadBanner(),
          _buildFilterPanel(),
          const SizedBox(height: 12),
          if (_userFiles.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open,
                    color: Color(0xFF007AFF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_getFilteredFiles().length} Dokumen',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _buildFileList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Web documents (2 panel) ────────────────────────────────────
  Widget _buildDocumentsTabWeb() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panel kiri: upload + filter ──────────────────────
        Container(
          width: 300,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upload banner compact
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Upload Dokumen',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildUploadButton(
                              icon: Icons.camera_alt,
                              label: 'Kamera',
                              onTap: () => _uploadFile('camera'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildUploadButton(
                              icon: Icons.photo_library,
                              label: 'Galeri',
                              onTap: () => _uploadFile('gallery'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildUploadButton(
                              icon: Icons.insert_drive_file,
                              label: 'File',
                              onTap: () => _uploadFile('file'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Search
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Cari dokumen...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Kategori filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FileCategory>(
                      value: _selectedCategoryFile,
                      isExpanded: true,
                      hint: const Text('Kategori'),
                      items: _categories
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedCategoryFile = v;
                            categoryController.text = v.name;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Sort
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text('Terbaru'),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text('Terlama'),
                        ),
                        DropdownMenuItem(value: 'name', child: Text('Nama')),
                        DropdownMenuItem(
                          value: 'category',
                          child: Text('Kategori'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Stats
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_open,
                        color: Color(0xFF007AFF),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getFilteredFiles().length} Dokumen',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Panel kanan: file list ─────────────────────────────
        Expanded(
          child: _isLoadingFiles
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF007AFF)),
                      SizedBox(height: 14),
                      Text(
                        'Memuat dokumen...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _getFilteredFiles().isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userFiles.isEmpty
                            ? 'Belum ada dokumen'
                            : 'Tidak ada hasil filter',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _getFilteredFiles().length,
                  itemBuilder: (_, i) =>
                      _buildEnhancedFileItem(_getFilteredFiles()[i]),
                ),
        ),
      ],
    );
  }

  // ── Upload banner (mobile) ───────────────────────────────────
  Widget _buildUploadBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Upload Dokumen',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildUploadButton(
                  icon: Icons.camera_alt,
                  label: 'Kamera',
                  onTap: () => _uploadFile('camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildUploadButton(
                  icon: Icons.photo_library,
                  label: 'Galeri',
                  onTap: () => _uploadFile('gallery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildUploadButton(
                  icon: Icons.insert_drive_file,
                  label: 'File',
                  onTap: () => _uploadFile('file'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Filter panel (mobile) ──────────────────────────────────────
  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Cari dokumen...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FileCategory>(
                      value: _selectedCategoryFile,
                      isExpanded: true,
                      hint: const Text('Kategori'),
                      items: _categories
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedCategoryFile = v;
                            categoryController.text = v.name;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text('Terbaru'),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text('Terlama'),
                        ),
                        DropdownMenuItem(value: 'name', child: Text('Nama')),
                        DropdownMenuItem(
                          value: 'category',
                          child: Text('Kategori'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── File list ──────────────────────────────────────────────────
  Widget _buildFileList() {
    if (_isLoadingFiles) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF007AFF)),
              SizedBox(height: 14),
              Text('Memuat dokumen...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    if (_userFiles.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 60, color: Color(0xFFE5E7EB)),
              SizedBox(height: 14),
              Text(
                'Belum ada dokumen',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final filtered = _getFilteredFiles();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildEnhancedFileItem(filtered[i]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required String label,
    required String value,
    Color? valueColor,
    IconData? icon,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: const Color(0xFF007AFF), size: 18),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value.isNotEmpty ? value : 'Tidak tersedia',
                    style: TextStyle(
                      fontSize: 15,
                      color: valueColor ?? Colors.black87,
                      fontWeight: FontWeight.w600,
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

  Widget _buildEnhancedFileItem(FileUserResponse file) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _previewFile(file),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getFileColor(file.fileType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getFileIcon(file.fileType),
                  color: _getFileColor(file.fileType),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        file.fileCategory,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    if (file.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        file.description,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 11,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('dd/MM/yyyy').format(file.uploadedAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'view') _previewFile(file);
                  if (v == 'delete') _showDeleteConfirmation(file.id);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          size: 15,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 7),
                        const Text('Lihat'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 15, color: Colors.red),
                        const SizedBox(width: 7),
                        const Text('Hapus'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.more_vert,
                    size: 15,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int fileId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Konfirmasi Hapus'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin menghapus dokumen ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(fileId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Color _getFileColor(String? ft) {
    if (ft == null) return Colors.grey;
    if (ft.startsWith('image/')) return Colors.green;
    if (ft.startsWith('video/')) return Colors.purple;
    if (ft.contains('pdf')) return Colors.red;
    if (ft.contains('word')) return Colors.blue;
    if (ft.contains('excel')) return Colors.green;
    if (ft.contains('powerpoint')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getFileIcon(String? ft) {
    if (ft == null) return Icons.insert_drive_file;
    if (ft.startsWith('image/')) return Icons.image;
    if (ft.startsWith('video/')) return Icons.video_file;
    if (ft.contains('pdf')) return Icons.picture_as_pdf;
    if (ft.contains('word')) return Icons.description;
    if (ft.contains('excel')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  List<FileUserResponse> _getFilteredFiles() {
    var files = _userFiles.where((f) {
      final matchSearch =
          _searchQuery.isEmpty ||
          f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.fileCategory.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCat =
          _selectedCategoryFile?.name == 'Semua' ||
          f.fileCategory == _selectedCategoryFile?.name;
      return matchSearch && matchCat;
    }).toList();

    switch (_sortBy) {
      case 'newest':
        files.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        break;
      case 'oldest':
        files.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
        break;
      case 'name':
        files.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'category':
        files.sort((a, b) => a.fileCategory.compareTo(b.fileCategory));
        break;
    }
    return files;
  }
}

// ── Model helper untuk item profil ─────────────────────────────────
class _ItemData {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final String? sectionBefore;

  const _ItemData(
    this.label,
    this.value, {
    this.icon,
    this.valueColor,
    this.sectionBefore,
  });
}
