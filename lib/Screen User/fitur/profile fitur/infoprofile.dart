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

  Future<void> _loadCategories() async {
    try {
      // Pastikan token tersedia sebelum request
      if (_accessToken == null) {
        await _getToken();
      }

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
        // Token expired, refresh dan coba lagi
        await _refreshTokenAndRetry();
        await _loadCategories(); // Rekursif call setelah refresh token
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

  // Fixed _getToken method - assign to _accessToken
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
          _accessToken =
              data['access_token']; // FIXED: Assign to instance variable
          _accessToken =
              data['access_token']; // FIXED: Assign to instance variable
        } else {
          _accessToken = null;
        }
      } else {
        _accessToken = null;
      }
    } catch (e) {
      _accessToken = null;
    }
  }

  // New method to refresh token and retry failed requests
  Future<void> _refreshTokenAndRetry() async {
    await _getToken();
    if (_accessToken == null) {
      throw Exception('Failed to refresh token');
    }
  }

  // Helper method to make authenticated HTTP requests with automatic token refresh
  Future<http.Response> _makeAuthenticatedRequest({
    required String url,
    required Map<String, String> headers,
    String? body,
    String method = 'POST',
  }) async {
    // Ensure we have a token
    if (_accessToken == null) {
      await _getToken();
      if (_accessToken == null) {
        throw Exception('Unable to obtain access token');
      }
    }

    // Add authorization header
    final authHeaders = {...headers, 'Authorization': 'Bearer $_accessToken'};

    http.Response response;

    try {
      if (method.toUpperCase() == 'POST') {
        response = await http.post(
          Uri.parse(url),
          headers: authHeaders,
          body: body,
        );
      } else {
        response = await http.get(Uri.parse(url), headers: authHeaders);
      }

      // If we get 401, try to refresh token once
      if (response.statusCode == 401) {
        await _refreshTokenAndRetry();

        // Update headers with new token
        authHeaders['Authorization'] = 'Bearer $_accessToken';

        // Retry the request
        if (method.toUpperCase() == 'POST') {
          response = await http.post(
            Uri.parse(url),
            headers: authHeaders,
            body: body,
          );
        } else {
          response = await http.get(Uri.parse(url), headers: authHeaders);
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _initProfile() async {
    try {
      await _getToken(); // Get initial token

      if (_accessToken != null && mounted) {
        await Future.wait([
          _loadProfileData(),
          _loadProfileProfessional(),
          _loadUserFiles(),
          _loadCategories(),
        ]);
      }

      _safeSetState(() => _isLoading = false);
    } catch (e) {
      _safeSetState(() => _isLoading = false);
    }
  }

  void _safeSetState(VoidCallback callback) {
    if (mounted) {
      setState(callback);
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';

    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Map<String, int> _calculateWorkingPeriod(String joinDateString) {
    if (joinDateString.isEmpty) {
      return {'years': 0, 'months': 0, 'days': 0};
    }

    try {
      DateTime joinDate = DateTime.parse(joinDateString);
      DateTime now = DateTime.now();

      int years = now.year - joinDate.year;
      int months = now.month - joinDate.month;
      int days = now.day - joinDate.day;

      if (days < 0) {
        months--;
        DateTime lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
        days += lastDayOfPrevMonth.day;
      }

      if (months < 0) {
        years--;
        months += 12;
      }

      return {'years': years, 'months': months, 'days': days};
    } catch (e) {
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
        final responseJson = json.decode(response.body);
        if (responseJson['data'] != null) {
          _safeSetState(() {
            _profileDisplay = ProfileDisplay.fromJson(responseJson);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat profil: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error load profile: $e')));
      }
    }
  }

  Future<void> _loadProfileProfessional() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('Email');
    final userId = prefs.getString('UserID');
    if (email == null || userId == null) {
      return;
    }

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
        final responseJson = json.decode(response.body);
        _safeSetState(() {
          employeeID = responseJson['EmployeeID'] ?? '';
          barcode = responseJson['Barcode'] ?? '';
          companyName = responseJson['CompanyName'] ?? '';
          branch = responseJson['Branch'] ?? '';
          organization = responseJson['Organization'] ?? '';
          jobPosition = responseJson['JobPosition'] ?? '';
          jobLevel = responseJson['JobLevel'] ?? '';
          employmentStatus = responseJson['EmploymentStatus'] ?? '';
          joinDate = responseJson['JoinDate'] ?? '';
          endContractDate = responseJson['EndContractDate'] ?? '';
          grade = responseJson['Grade'] ?? '';
          className = responseJson['Class'] ?? '';
          approvalLine = responseJson['ApprovalLine'] ?? '';
          manager = responseJson['Manager'] ?? '';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat data profesional: ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error load professional profile: $e')),
        );
      }
    }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat file: ${response.body}')),
          );
        }
        _safeSetState(() => _userFiles = []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error load files: $e')));
      }
      _safeSetState(() => _userFiles = []);
    }

    _safeSetState(() => _isLoadingFiles = false);
  }

  Future<Uint8List> _getFileContent(int fileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID');
      final mail = prefs.getString('Email');

      if (userId == null || mail == null) {
        throw Exception('User ID atau Email tidak ditemukan');
      }

      final response = await _makeAuthenticatedRequest(
        url: '$baseURL/api/asn/file/download',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/octet-stream',
        },
        body: json.encode({'Id': fileId, 'UserId': userId, 'Mail': mail}),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        throw Exception(
          'File tidak ditemukan atau tidak memiliki akses. FileID: $fileId',
        );
      } else {
        throw Exception(
          'Gagal mengunduh file: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
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
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mengupload file...'),
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

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File berhasil diunggah'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupload file: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red,
          ),
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
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menghapus file...'),
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

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus file: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Rest of the methods remain the same as they don't involve API calls...
  Future<void> _previewFile(FileUserResponse file) async {
    if (!mounted) return;

    try {
      if (file.fileType.startsWith('image/') == true) {
        _showImagePreview(file);
        return;
      }
      await _openFileWithExternalApp(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preview file: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Detail',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Error Detail'),
                    content: SingleChildScrollView(
                      child: Text(
                        'File: ${file.name}\nID: ${file.id}\nType: ${file.fileType}\n\nError:\n$e',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _testFileDownload(FileUserResponse file) async {
    try {
      final fileBytes = await _getFileContent(file.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test berhasil: ${file.name} (${fileBytes.length} bytes)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test gagal: $e'),
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
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Memuat file...'),
          ],
        ),
      ),
    );

    try {
      final fileBytes = await _getFileContent(file.id);

      if (mounted) {
        Navigator.pop(context);
      }

      if (Platform.isAndroid || Platform.isIOS) {
        await _openFileOnMobile(file, fileBytes);
      } else {
        await _openFileOnDesktop(file, fileBytes);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openFileOnMobile(
    FileUserResponse file,
    Uint8List fileBytes,
  ) async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            _showInternalFilePreview(file, fileBytes);
            return;
          }
        }
      }

      Directory? directory;

      if (Platform.isAndroid) {
        try {
          directory = await getExternalStorageDirectory();
        } catch (e) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Tidak dapat mengakses penyimpanan');
      }

      String safeFileName = _createSafeFileName(file.name);
      final tempFile = File('${directory.path}/$safeFileName');

      await tempFile.writeAsBytes(fileBytes);

      final result = await OpenFile.open(tempFile.path);

      if (result.type != ResultType.done) {
        _showInternalFilePreview(file, fileBytes);
      }
    } catch (e) {
      _showInternalFilePreview(file, fileBytes);
    }
  }

  Future<void> _openFileOnDesktop(
    FileUserResponse file,
    Uint8List fileBytes,
  ) async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      String safeFileName = _createSafeFileName(file.name);
      final tempFile = File('${tempDir.path}/$safeFileName');

      await tempFile.writeAsBytes(fileBytes);

      final result = await OpenFile.open(tempFile.path);

      if (result.type != ResultType.done) {
        _showInternalFilePreview(file, fileBytes);
      }
    } catch (e) {
      _showInternalFilePreview(file, fileBytes);
    }
  }

  String _createSafeFileName(String originalName) {
    String safeName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    int lastDotIndex = safeName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      String nameWithoutExt = safeName.substring(0, lastDotIndex);
      String extension = safeName.substring(lastDotIndex);
      return '${nameWithoutExt}_$timestamp$extension';
    } else {
      return '${safeName}_$timestamp';
    }
  }

  void _showInternalFilePreview(FileUserResponse file, Uint8List fileBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(file.fileType),
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        file.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileIcon(file.fileType),
                        size: 64,
                        color: _getFileColor(file.fileType),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Preview Dokumen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'File: ${file.name}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ukuran: ${_formatFileSize(fileBytes.length)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _downloadFile(file, fileBytes);
                            },
                            icon: Icon(Icons.download),
                            label: Text('Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _shareFile(file, fileBytes),
                            icon: Icon(Icons.share),
                            label: Text('Bagikan'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tidak dapat membuka file dengan aplikasi eksternal.\nAnda dapat mendownload file untuk membukanya.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
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

  Future<void> _downloadFile(FileUserResponse file, Uint8List fileBytes) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        String safeFileName = _createSafeFileName(file.name);
        final downloadFile = File('${directory.path}/$safeFileName');

        await downloadFile.writeAsBytes(fileBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File berhasil didownload ke ${downloadFile.path}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Buka',
                textColor: Colors.white,
                onPressed: () => OpenFile.open(downloadFile.path),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendownload file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareFile(FileUserResponse file, Uint8List fileBytes) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur berbagi akan segera tersedia'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showImagePreview(FileUserResponse file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  style: TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: Icon(Icons.download, color: Colors.white),
                    onPressed: () async {
                      try {
                        final fileBytes = await _getFileContent(file.id);
                        await _downloadFile(file, fileBytes);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal download: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: FutureBuilder<Uint8List>(
                    future: _getFileContent(file.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Memuat gambar...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        );
                      }

                      if (snapshot.hasError) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.white, size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Error loading image',
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                '${snapshot.error}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showImagePreview(file);
                                  },
                                  child: Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              color: Colors.white,
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Data gambar kosong',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        );
                      }

                      return InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Tidak dapat menampilkan gambar',
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Error: $error',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
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
      Uint8List? fileBytes;
      String? fileName;
      String? mimeType;

      if (source == 'camera') {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(source: ImageSource.camera);
        if (photo != null) {
          fileBytes = await photo.readAsBytes();
          fileName = photo.name;
          mimeType = 'image/jpeg';
        }
      } else if (source == 'gallery') {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          fileBytes = await image.readAsBytes();
          fileName = image.name;
          mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
        }
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
        );

        if (result != null) {
          String filePath = result.files.single.path!;
          String fileName = result.files.single.name;
          String? mimeType = lookupMimeType(fileName);
          if (filePath.isNotEmpty) {
            File file = File(filePath);
            Uint8List fileBytes = await file.readAsBytes();
            await _showUploadDialog(
              userId,
              mail,
              fileName,
              fileBytes,
              mimeType,
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('File tidak dapat diakses')));
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Pemilihan file dibatalkan')));
        }
      }

      if (fileBytes != null && fileName != null && mounted) {
        await _showUploadDialog(userId, mail, fileName, fileBytes, mimeType);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
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

    final descriptionController = TextEditingController();

    FileCategory? selectedCategoryFile;

    final uploadCategories = _categories
        .where((cat) => cat.name != 'Semua')
        .toList();

    if (uploadCategories.isNotEmpty) {
      selectedCategoryFile = uploadCategories.first;
    }

    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
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
                  padding: EdgeInsets.all(12),
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
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: TextStyle(fontWeight: FontWeight.w600),
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
                SizedBox(height: 16),
                Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FileCategory>(
                      value: selectedCategoryFile,
                      isExpanded: true,
                      hint: Text('Pilih kategori'),
                      items: uploadCategories.map((category) {
                        return DropdownMenuItem<FileCategory>(
                          value: category,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryFile = value;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Deskripsi (Opsional)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Tambahkan deskripsi dokumen...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF007AFF)),
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
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: selectedCategoryFile == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _performUpload(
                        userId,
                        mail,
                        fileName,
                        fileBytes,
                        mimeType,
                        selectedCategoryFile!.name,
                        descriptionController.text,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              child: Text('Upload'),
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

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: () {
            if (index == 2 && _selectedTabIndex != 2) {
              _loadUserFiles();
            }
            _safeSetState(() {
              _selectedTabIndex = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              boxShadow: isSelected
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
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.3,
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
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.isNotEmpty ? value : 'Tidak tersedia',
                    style: TextStyle(
                      fontSize: 16,
                      color: valueColor ?? Colors.black87,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
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

  Widget _buildPersonalTab() {
    if (_profileDisplay == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Data profil tidak tersedia',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edit Button
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditProfileScreen(profileData: _profileDisplay!),
                ),
              );

              // Refresh data jika ada perubahan
              if (result == true) {
                await _loadProfileData();
              }
            },
            icon: Icon(Icons.edit),
            label: Text('Edit Profil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        _buildSectionHeader('Data Pribadi'),
        _buildProfileItem(
          label: 'ID Pengguna',
          value: _profileDisplay!.userId,
          icon: Icons.badge_outlined,
        ),
        _buildProfileItem(
          label: 'Nama Lengkap',
          value: _profileDisplay!.fullName,
          icon: Icons.person_outline,
        ),
        _buildProfileItem(
          label: 'Alamat Email',
          value: _profileDisplay!.email,
          valueColor: const Color(0xFF007AFF),
          icon: Icons.email_outlined,
        ),
        _buildProfileItem(
          label: 'Nomor Telepon',
          value: _profileDisplay!.phoneNumber,
          icon: Icons.phone_outlined,
        ),
        _buildProfileItem(
          label: 'Nomor Telepon Tambahan',
          value: _profileDisplay!.additionalPhone ?? '-',
          icon: Icons.phone_outlined,
        ),
        _buildProfileItem(
          label: 'Jenis Kelamin',
          value: _profileDisplay!.gender ?? '-',
          icon: Icons.wc_outlined,
        ),
        _buildProfileItem(
          label: 'Tempat Lahir',
          value: _profileDisplay!.placeOfBirth ?? '-',
          icon: Icons.location_on_outlined,
        ),
        _buildProfileItem(
          label: 'Tanggal Lahir',
          value: _profileDisplay!.birthDate ?? '-',
          icon: Icons.calendar_today_outlined,
        ),
        _buildProfileItem(
          label: 'Status Pernikahan',
          value: _profileDisplay!.maritalStatus ?? '-',
          icon: Icons.favorite_outline,
        ),
        _buildProfileItem(
          label: 'Golongan Darah',
          value: _profileDisplay!.bloodType ?? '-',
          icon: Icons.bloodtype_outlined,
        ),
        _buildProfileItem(
          label: 'Agama',
          value: _profileDisplay!.religion ?? '-',
          icon: Icons.account_balance_outlined,
        ),
        _buildSectionHeader('Identitas & Alamat'),
        _buildProfileItem(
          label: 'NIK',
          value: _profileDisplay!.nik ?? '-',
          icon: Icons.credit_card_outlined,
        ),
        _buildProfileItem(
          label: 'NPWP',
          value: _profileDisplay!.npwp ?? '-',
          icon: Icons.credit_card_outlined,
        ),
        _buildProfileItem(
          label: 'NIP',
          value: _profileDisplay!.nip ?? '-',
          icon: Icons.credit_card_outlined,
        ),
        _buildProfileItem(
          label: 'Nomor Paspor',
          value: _profileDisplay!.passportNumber ?? '-',
          icon: Icons.card_travel_outlined,
        ),
        _buildProfileItem(
          label: 'Tanggal Kedaluwarsa Paspor',
          value: _profileDisplay!.passportExpiry ?? '-',
          icon: Icons.date_range_outlined,
        ),
        _buildProfileItem(
          label: 'Kode Pos',
          value: _profileDisplay!.postalCode ?? '-',
          icon: Icons.markunread_mailbox_outlined,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProfessionalTab() {
    if (employeeID.isEmpty && companyName.isEmpty) {
      return const Center(
        child: Text(
          'Data profesional tidak tersedia.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final workingPeriod = _calculateWorkingPeriod(joinDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileItem(
          label: 'ID Karyawan',
          value: employeeID,
          icon: Icons.badge_outlined,
        ),
        _buildProfileItem(
          label: 'Barcode',
          value: barcode,
          icon: Icons.qr_code,
        ),
        _buildProfileItem(
          label: 'Perusahaan',
          value: companyName,
          icon: Icons.business_outlined,
        ),
        _buildProfileItem(
          label: 'Cabang',
          value: branch,
          icon: Icons.location_city_outlined,
        ),
        _buildProfileItem(
          label: 'Organisasi',
          value: organization,
          icon: Icons.account_tree_outlined,
        ),
        _buildProfileItem(
          label: 'Posisi Jabatan',
          value: jobPosition,
          icon: Icons.work_outline,
        ),
        _buildProfileItem(
          label: 'Level Jabatan',
          value: jobLevel,
          icon: Icons.layers_outlined,
        ),
        _buildProfileItem(
          label: 'Status Karyawan',
          value: employmentStatus,
          icon: Icons.how_to_reg_outlined,
        ),
        _buildProfileItem(
          label: 'Tanggal Masuk',
          value: _formatDate(joinDate),
          icon: Icons.calendar_today_outlined,
        ),
        _buildProfileItem(
          label: 'Tanggal Akhir Kontrak',
          value: _formatDate(endContractDate),
          icon: Icons.event_busy_outlined,
        ),
        _buildProfileItem(
          label: 'Masa Kerja',
          value: joinDate.isNotEmpty
              ? '${workingPeriod['years']} Tahun ${workingPeriod['months']} Bulan ${workingPeriod['days']} Hari'
              : 'Tidak tersedia',
          icon: Icons.timelapse_outlined,
        ),
        _buildProfileItem(
          label: 'Grade',
          value: grade,
          icon: Icons.grade_outlined,
        ),
        _buildProfileItem(
          label: 'Kelas',
          value: className,
          icon: Icons.class_outlined,
        ),
        _buildProfileItem(
          label: 'Approval Line',
          value: approvalLine.isNotEmpty ? approvalLine : '-',
          icon: Icons.approval_outlined,
        ),
        _buildProfileItem(
          label: 'Atasan Langsung',
          value: manager.isNotEmpty ? manager : '-',
          icon: Icons.supervisor_account_outlined,
        ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF007AFF).withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_upload, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Upload Dokumen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildUploadButton(
                      icon: Icons.camera_alt,
                      label: 'Kamera',
                      onTap: () => _uploadFile('camera'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildUploadButton(
                      icon: Icons.photo_library,
                      label: 'Galeri',
                      onTap: () => _uploadFile('gallery'),
                    ),
                  ),
                  SizedBox(width: 12),
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

        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
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
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<FileCategory>(
                          value: _selectedCategoryFile,
                          isExpanded: true,
                          hint: Text('Kategori'),
                          items: _categories.map((category) {
                            return DropdownMenuItem<FileCategory>(
                              value: category,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategoryFile = value;
                                categoryController.text = value.name;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isExpanded: true,
                          hint: Text('Urutkan'),
                          items: [
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text('Terbaru'),
                            ),
                            DropdownMenuItem(
                              value: 'oldest',
                              child: Text('Terlama'),
                            ),
                            DropdownMenuItem(
                              value: 'name',
                              child: Text('Nama'),
                            ),
                            DropdownMenuItem(
                              value: 'category',
                              child: Text('Kategori'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _sortBy = value!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Documents List Header
        if (_userFiles.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open, color: Color(0xFF007AFF), size: 20),
                SizedBox(width: 8),
                Text(
                  '${_getFilteredFiles().length} Dokumen',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ],
            ),
          ),

        // File list
        _isLoadingFiles
            ? SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF007AFF)),
                      SizedBox(height: 16),
                      Text(
                        'Memuat dokumen...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            : _userFiles.isEmpty
            ? SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada dokumen',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Upload dokumen pertama Anda',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _getFilteredFiles().length,
                itemBuilder: (context, index) {
                  final file = _getFilteredFiles()[index];
                  return _buildEnhancedFileItem(file);
                },
              ),
      ],
    );
  }

  Widget _buildEnhancedFileItem(FileUserResponse file) {
    //final fileSize = _formatFileSize(file.size ?? 0);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _previewFile(file),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File Icon/Thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getFileColor(file.fileType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _getFileIcon(file.fileType),
                    color: _getFileColor(file.fileType),
                    size: 24,
                  ),
                ),
              ),
              SizedBox(width: 16),

              // File Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),

                    // Category Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        file.fileCategory,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Description
                    if (file.description.isNotEmpty == true)
                      Text(
                        file.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    SizedBox(height: 8),

                    // Upload date and file size
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy').format(file.uploadedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.storage, size: 12, color: Colors.grey[400]),
                        SizedBox(width: 4),
                        // Text(
                        //   fileSize,
                        //   style: TextStyle(
                        //     fontSize: 11,
                        //     color: Colors.grey[500],
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      _previewFile(file);
                      break;
                    case 'test':
                      _testFileDownload(file);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(file.id);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Lihat'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.more_vert,
                    size: 16,
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

  Color _getFileColor(String? fileType) {
    if (fileType == null) return Colors.grey;

    if (fileType.startsWith('image/')) return Colors.green;
    if (fileType.startsWith('video/')) return Colors.purple;
    if (fileType.contains('pdf')) return Colors.red;
    if (fileType.contains('word')) return Colors.blue;
    if (fileType.contains('excel')) return Colors.green;
    if (fileType.contains('powerpoint')) return Colors.orange;

    return Colors.grey;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  List<FileUserResponse> _getFilteredFiles() {
    var filteredFiles = _userFiles.where((file) {
      bool matchesSearch =
          _searchQuery.isEmpty ||
          file.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          file.fileCategory.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesCategory =
          _selectedCategoryFile?.name ==
              'Semua' || // Check if "Semua" is selected
          file.fileCategory ==
              _selectedCategoryFile?.name; // Compare with selected category

      return matchesSearch && matchesCategory;
    }).toList();

    // Sort files
    switch (_sortBy) {
      case 'newest':
        filteredFiles.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        break;
      case 'oldest':
        filteredFiles.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
        break;
      case 'name':
        filteredFiles.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'category':
        filteredFiles.sort((a, b) => a.fileCategory.compareTo(b.fileCategory));
        break;
    }

    return filteredFiles;
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;

    if (fileType.startsWith('image/')) return Icons.image;
    if (fileType.startsWith('video/')) return Icons.video_file;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('word')) return Icons.description;
    if (fileType.contains('excel')) return Icons.table_chart;

    return Icons.insert_drive_file;
  }

  void _showDeleteConfirmation(int fileId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Konfirmasi Hapus'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus dokumen ini? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
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
            child: Text('Hapus'),
          ),
        ],
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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profil Saya',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
          ],
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
            // Header with shadow
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  padding: const EdgeInsets.all(6),
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

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildTabContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
