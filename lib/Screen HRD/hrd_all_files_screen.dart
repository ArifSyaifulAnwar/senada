// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:absensikaryawan/Services/config.dart';

import '../Services/fileuserresponse.dart';

class HRDAllFilesScreen extends StatefulWidget {
  const HRDAllFilesScreen({super.key});

  @override
  State<HRDAllFilesScreen> createState() => _HRDAllFilesScreenState();
}

class _HRDAllFilesScreenState extends State<HRDAllFilesScreen> {
  String? _accessToken;
  bool _isLoading = true;
  bool _accessDenied = false;
  String? _accessMessage;
  List<FileUserAdminResponse> _allFiles = [];
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getToken();
    await _loadAllFiles();
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
        _accessToken = data['access_token'];
      }
    } catch (_) {}
  }

  Future<void> _loadAllFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _accessDenied = false;
      _accessMessage = null;
    });

    try {
      if (_accessToken == null) await _getToken();

      final prefs = await SharedPreferences.getInstance();
      final requestUserId = prefs.getString('UserID') ?? '';

      if (requestUserId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/file/getAllHRD'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'RequestUserId': requestUserId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['Data'] ?? {};
        final bool denied = data['AccessDenied'] ?? false;
        final String? msg = data['Message'] ?? body['Message'];
        final List<dynamic> filesJson = data['Files'] ?? [];

        setState(() {
          _accessDenied = denied;
          _accessMessage = msg;
          _allFiles = filesJson
              .map((e) => FileUserAdminResponse.fromJson(e))
              .toList();
        });

        if (denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg ?? 'Anda tidak memiliki akses'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          _accessDenied = true;
          _accessMessage = 'Gagal memuat data (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _accessDenied = true;
        _accessMessage = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _downloadFileContent(int fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final requestUserId = prefs.getString('UserID') ?? '';

    final response = await http.post(
      Uri.parse('$baseURL/api/asn/file/downloadAdminHRD'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({'RequestUserId': requestUserId, 'FileId': fileId}),
    );

    if (response.statusCode == 200) return response.bodyBytes;

    if (response.statusCode == 403) {
      String msg = 'Tidak memiliki akses untuk mengunduh file ini';
      try {
        final body = json.decode(response.body);
        msg = body['Message'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }

    throw Exception('Gagal mengunduh file: ${response.statusCode}');
  }

  Future<void> _openFile(FileUserAdminResponse file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
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
      final bytes = await _downloadFileContent(file.id);
      if (mounted) Navigator.pop(context);

      if (file.fileType.startsWith('image/')) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black87,
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final safeName =
          '${file.id}_${file.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}';
      final f = File('${dir.path}/$safeName');
      await f.writeAsBytes(bytes);
      await OpenFile.open(f.path);
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

  List<FileUserAdminResponse> get _filteredFiles {
    return _allFiles.where((f) {
      final q = _searchQuery.toLowerCase();
      final matchSearch =
          q.isEmpty ||
          f.name.toLowerCase().contains(q) ||
          f.employeeName.toLowerCase().contains(q) ||
          f.fileCategory.toLowerCase().contains(q);
      final matchCat =
          _selectedCategory == 'Semua' || f.fileCategory == _selectedCategory;
      return matchSearch && matchCat;
    }).toList();
  }

  List<String> get _categories {
    final set = <String>{'Semua'};
    for (final f in _allFiles) {
      if (f.fileCategory.isNotEmpty) set.add(f.fileCategory);
    }
    return set.toList();
  }

  IconData _getFileIcon(String ft) {
    if (ft.startsWith('image/')) return Icons.image;
    if (ft.contains('pdf')) return Icons.picture_as_pdf;
    if (ft.contains('word')) return Icons.description;
    if (ft.contains('excel')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String ft) {
    if (ft.startsWith('image/')) return Colors.green;
    if (ft.contains('pdf')) return Colors.red;
    if (ft.contains('word')) return Colors.blue;
    if (ft.contains('excel')) return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Semua File Karyawan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllFiles),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accessDenied
          ? _buildAccessDenied()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText:
                              'Cari nama file / nama karyawan / kategori...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _categories.map((c) {
                            final sel = c == _selectedCategory;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: sel,
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = c),
                                selectedColor: const Color(0xFF007AFF),
                                labelStyle: TextStyle(
                                  color: sel ? Colors.white : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredFiles.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada file',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: _filteredFiles.length,
                          itemBuilder: (_, i) {
                            final f = _filteredFiles[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                onTap: () => _openFile(f),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getFileColor(
                                      f.fileType,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getFileIcon(f.fileType),
                                    color: _getFileColor(f.fileType),
                                  ),
                                ),
                                title: Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${f.employeeName} • ${f.jobPosition}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF007AFF),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${f.fileCategory} • ${DateFormat('dd/MM/yyyy').format(f.uploadedAt)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _accessMessage ?? 'Anda tidak memiliki akses ke fitur ini',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadAllFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
