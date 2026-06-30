// screens/time_off_screen.dart — FULL REPLACE
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io' show File, Directory, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:absensikaryawan/Services/time_off_file_service.dart';
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:absensikaryawan/Services/web_download.dart';
import 'add_time_off_screen.dart';
import 'dl_laporan_screen.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class TimeOffScreen extends StatefulWidget {
  final String userId;
  const TimeOffScreen({super.key, required this.userId});

  @override
  State<TimeOffScreen> createState() => _TimeOffScreenState();
}

class _TimeOffScreenState extends State<TimeOffScreen> {
  List<WorkPeriodModel> _workPeriods = [];
  WorkPeriodModel? _selectedPeriod;
  bool _isLoadingPeriods = false;
  List<TimeOffModel> _allTimeOffList = [];
  List<TimeOffModel> _filteredTimeOffList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();

  // Khusus layout web agar sidebar dan konten tidak memakai controller yang sama
  final ScrollController _webFilterScrollController = ScrollController();
  final ScrollController _webContentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTimeOffData();
    _loadWorkPeriods();
  }

  Future<void> _loadWorkPeriods() async {
    setState(() => _isLoadingPeriods = true);
    final res = await TimeOffService.getWorkPeriods();
    if (!mounted) return;
    setState(() {
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        _workPeriods = res.data!;
        // Default: pilih periode terbaru (urutan sudah desc dari SP)
        _selectedPeriod = _workPeriods.first;
      }
      _isLoadingPeriods = false;
    });
    await _loadTimeOffData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _webFilterScrollController.dispose();
    _webContentScrollController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadTimeOffData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await TimeOffService.getMyTimeOff(widget.userId);
      if (response.success && response.data != null) {
        setState(() {
          _allTimeOffList = response.data!.data;
          _applyClientSideFilter();
        });
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
        _isLoading = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyClientSideFilter() {
    List<TimeOffModel> filtered = _allTimeOffList;

    if (_selectedPeriod != null) {
      final start = _selectedPeriod!.tanggalMulai;
      final end = _selectedPeriod!.tanggalSelesai;
      filtered = filtered.where((t) {
        // Tampilkan izin yang OVERLAP dengan periode kerja terpilih
        return !t.tanggalSelesai.isBefore(start) &&
            !t.tanggalMulai.isAfter(end);
      }).toList();
    }

    filtered.sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));
    setState(() => _filteredTimeOffList = filtered);
  }

  Future<void> _refreshData() async => _loadTimeOffData();

  void _resetFilter() {
    setState(() {
      _selectedPeriod = _workPeriods.isNotEmpty ? _workPeriods.first : null;
    });
    _applyClientSideFilter();
  }

  String _getFilterDisplayText() {
    return _selectedPeriod?.label ?? 'Semua Periode';
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _navigateToFormSubmit(BuildContext context, {TimeOffModel? editData}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTimeOffScreen(userId: widget.userId, editData: editData),
      ),
    ).then((result) {
      if (result == true) _refreshData();
    });
  }

  void _navigateToDlLaporan(TimeOffModel timeOff) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DlLaporanScreen(timeOff: timeOff, userId: widget.userId),
      ),
    ).then((result) {
      if (result == true) _refreshData();
    });
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  void _confirmDelete(TimeOffModel timeOff) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengajuan'),
        content: const Text(
          'Hapus pengajuan ini? Tindakan tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteTimeOff(timeOff);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTimeOff(TimeOffModel timeOff) async {
    try {
      final res = await TimeOffService.deleteTimeOff(
        timeOff.id!,
        widget.userId,
      );
      if (res.success) {
        _showSnackBar('Pengajuan berhasil dihapus', isError: false);
        _refreshData();
      } else {
        _showSnackBar(res.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Gagal menghapus: $e', isError: true);
    }
  }

  // ── Export formulir ───────────────────────────────────────────────────────

  Future<void> _exportFormulirUser(TimeOffModel timeOff) async {
    if (timeOff.id == null) {
      _showSnackBar('ID pengajuan tidak valid', isError: true);
      return;
    }
    final status = timeOff.status.toLowerCase();
    if (status != 'approved' && status != 'disetujui') {
      _showSnackBar(
        'Formulir hanya bisa diexport setelah pengajuan disetujui',
        isError: true,
      );
      return;
    }
    try {
      _showSnackBar('Membuat formulir PDF...', isError: false);
      final res = await TimeOffService.exportTimeOffFormUser(
        timeOffId: timeOff.id!,
        userId: widget.userId,
        directorId: timeOff.directorUserId ??
            (timeOff.requiresDirectorApproval == true
                ? timeOff.approvedBy
                : null),
      );
      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }
      final safeJenis = _safeFileName(timeOff.jenisTimeOff);
      final fileName =
          'Formulir_${safeJenis}_${widget.userId}_${timeOff.id}.pdf';
      if (kIsWeb) {
        downloadFileWeb(res.data!, fileName);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(res.data!);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _showSnackBar(
            'Tidak dapat membuka PDF: ${result.message}',
            isError: true,
          );
          return;
        }
      }
      _showSnackBar('Formulir PDF berhasil diexport', isError: false);
    } catch (e) {
      _showSnackBar('Gagal export formulir PDF: $e', isError: true);
    }
  }

  String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  }

  bool _canPreviewOnWeb(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;

    return [
      'pdf',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'txt',
      'csv',
    ].contains(ext);
  }

  // ── File download/preview ─────────────────────────────────────────────────

  Future<void> _downloadFileById(
    int fileId,
    int timeOffId,
    String fileName,
  ) async {
    try {
      _showSnackBar('Mengunduh $fileName...', isError: false);

      final res = await TimeOffFileService.downloadFile(
        fileId,
        timeOffId,
        widget.userId,
      );

      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }

      final bytes = Uint8List.fromList(res.data!);

      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
      } else {
        await _saveAndOpenFile(bytes, fileName);
      }
    } catch (e) {
      _showSnackBar('Gagal mengunduh: $e', isError: true);
    }
  }

  Future<void> _previewFileById(
    int fileId,
    int timeOffId,
    String fileName,
  ) async {
    try {
      if (kIsWeb && !_canPreviewOnWeb(fileName)) {
        _showSnackBar(
          'Preview web hanya tersedia untuk PDF, gambar, TXT, atau CSV. Untuk file ini gunakan tombol Download.',
          isError: true,
        );
        return;
      }

      _showSnackBar('Membuka preview...', isError: false);

      final res = await TimeOffFileService.downloadFile(
        fileId,
        timeOffId,
        widget.userId,
      );

      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }

      final bytes = Uint8List.fromList(res.data!);

      if (kIsWeb) {
        previewFileWeb(bytes, fileName);
      } else {
        await _openTempFile(bytes, fileName);
      }
    } catch (e) {
      _showSnackBar('Gagal membuka preview: $e', isError: true);
    }
  }

  Future<void> _downloadFileLegacy(TimeOffModel timeOff) async {
    if (timeOff.id == null || timeOff.fileName == null) {
      _showSnackBar('File tidak tersedia', isError: true);
      return;
    }

    try {
      _showSnackBar('Mengunduh file...', isError: false);

      final res = await TimeOffService.downloadFile(timeOff.id!, widget.userId);

      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }

      final bytes = Uint8List.fromList(res.data!);

      if (kIsWeb) {
        downloadFileWeb(bytes, timeOff.fileName!);
      } else {
        await _saveAndOpenFile(bytes, timeOff.fileName!);
      }
    } catch (e) {
      _showSnackBar('Gagal mengunduh: $e', isError: true);
    }
  }

  Future<void> _previewFileLegacy(TimeOffModel timeOff) async {
    if (timeOff.id == null || timeOff.fileName == null) {
      _showSnackBar('File tidak tersedia', isError: true);
      return;
    }

    try {
      final fileName = timeOff.fileName!;

      if (kIsWeb && !_canPreviewOnWeb(fileName)) {
        _showSnackBar(
          'Preview web hanya tersedia untuk PDF, gambar, TXT, atau CSV. Untuk file ini gunakan tombol Download.',
          isError: true,
        );
        return;
      }

      _showSnackBar('Membuka preview...', isError: false);

      final res = await TimeOffService.downloadFile(timeOff.id!, widget.userId);

      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }

      final bytes = Uint8List.fromList(res.data!);

      if (kIsWeb) {
        previewFileWeb(bytes, fileName);
      } else {
        await _openTempFile(bytes, fileName);
      }
    } catch (e) {
      _showSnackBar('Gagal membuka preview: $e', isError: true);
    }
  }

  Future<void> _saveAndOpenFile(Uint8List fileBytes, String fileName) async {
    if (kIsWeb) {
      downloadFileWeb(fileBytes, fileName);
      return;
    }

    try {
      if (!await _requestStoragePermission()) {
        _showSnackBar('Izin akses storage diperlukan', isError: true);
        return;
      }

      final directory = await _getDownloadDirectory();

      if (directory == null) {
        _showSnackBar('Tidak dapat mengakses folder download', isError: true);
        return;
      }

      final filePath = await _getUniqueFilePath(directory.path, fileName);

      await File(filePath).writeAsBytes(fileBytes);

      _showSnackBar('File berhasil diunduh ke Downloads', isError: false);

      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        _showOpenFileDialog(filePath, fileName);
      }
    } catch (e) {
      _showSnackBar('Gagal menyimpan file: $e', isError: true);
    }
  }

  Future<void> _openTempFile(Uint8List fileBytes, String fileName) async {
    if (kIsWeb) {
      if (!_canPreviewOnWeb(fileName)) {
        _showSnackBar(
          'Preview web hanya tersedia untuk PDF, gambar, TXT, atau CSV.',
          isError: true,
        );
        return;
      }

      previewFileWeb(fileBytes, fileName);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');

      await tempFile.writeAsBytes(fileBytes);

      final result = await OpenFile.open(tempFile.path);

      if (result.type != ResultType.done) {
        _showSnackBar(
          'Tidak dapat membuka file: ${result.message}',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Gagal membuka file: $e', isError: true);
    }
  }

  Future<void> _exportDlFinal(TimeOffModel timeOff) async {
    if (timeOff.id == null) {
      _showSnackBar('ID pengajuan tidak valid', isError: true);
      return;
    }
    try {
      _showSnackBar('Membuat dokumen DL...', isError: false);
      final res = await TimeOffService.dlExportFinal(
        timeOffId: timeOff.id!,
        userId: widget.userId,
      );
      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }
      final fileName =
          'Dokumen_DL_${timeOff.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (kIsWeb) {
        downloadFileWeb(Uint8List.fromList(res.data!), fileName);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(res.data!);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _showSnackBar(
            'Tidak dapat membuka PDF: ${result.message}',
            isError: true,
          );
          return;
        }
      }
      _showSnackBar('Dokumen DL berhasil diexport', isError: false);
    } catch (e) {
      _showSnackBar('Gagal export dokumen DL: $e', isError: true);
    }
  }

  Future<String> _getUniqueFilePath(String dirPath, String fileName) async {
    if (kIsWeb) return '';
    String filePath = '$dirPath/$fileName';
    int counter = 1;
    while (await File(filePath).exists()) {
      final name = fileName.split('.').first;
      final ext = fileName.split('.').last;
      filePath = '$dirPath/${name}_$counter.$ext';
      counter++;
    }
    return filePath;
  }

  Future<bool> _requestStoragePermission() async {
    if (kIsWeb) return true;
    if (Platform.isIOS) return true;
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdkInt >= 30) return true;
    if (sdkInt >= 23) return (await Permission.storage.request()).isGranted;
    return true;
  }

  Future<Directory?> _getDownloadDirectory() async {
    if (kIsWeb) return null;
    try {
      if (Platform.isAndroid) {
        final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdkInt >= 30) {
          final appDir = await getExternalStorageDirectory();
          if (appDir != null) {
            final d = Directory('${appDir.path}/Downloads');
            if (!await d.exists()) await d.create(recursive: true);
            return d;
          }
        } else {
          final d = Directory('/storage/emulated/0/Download');
          if (await d.exists()) return d;
        }
        return await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      }
    } catch (_) {}
    return null;
  }

  void _showOpenFileDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 12),
            Text('Download Selesai'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File "$fileName" telah diunduh.'),
            const SizedBox(height: 16),
            const Text(
              'Apakah Anda ingin membuka file sekarang?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await OpenFile.open(filePath);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Buka File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _colorForStatus(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'disetujui':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'ditolak':
        return const Color(0xFFEF4444);
      case 'revisi': // ← BARU
        return const Color(0xFFD97706);
      case 'menunggu laporan':
        return const Color(0xFF7C3AED);
      case 'menunggu verifikasi head':
      case 'menunggu verifikasi hrd':
        return const Color(0xFF6366F1);
      case 'menunggu transfer':
        return const Color(0xFF059669);
      case 'pending finance':
        return const Color(0xFF0EA5E9);
      case 'menunggu org':
      case 'menunggu manager':
        return const Color(0xFFF97316);
      case 'pending hrd':
      case 'pending director':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _iconForStatus(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'disetujui':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'ditolak':
        return Icons.cancel_rounded;
      case 'revisi':
        return Icons.edit_note_rounded;
      case 'menunggu laporan':
        return Icons.upload_file_rounded;
      case 'menunggu verifikasi head':
      case 'menunggu verifikasi hrd':
        return Icons.rate_review_outlined;
      case 'menunggu transfer':
        return Icons.payments_outlined;
      case 'pending finance':
        return Icons.account_balance_wallet_outlined;
      case 'menunggu org':
      case 'menunggu manager':
        return Icons.groups_outlined;
      case 'pending hrd':
        return Icons.manage_accounts_outlined;
      case 'pending director':
        return Icons.person_outline_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  String _getJenisIcon(String j) {
    switch (j) {
      case 'Izin Tahunan':
        return '🏖️';
      case 'Sakit':
        return '🏥';
      case 'Umrah dan Haji':
        return '🕋';
      case 'Izin Datang Terlambat':
        return '⏰';
      case 'Izin Lahiran':
        return '👶';
      case 'Dinas Luar':
        return '🧳';
      case 'Keluarga Meninggal':
        return '🕯️';
      default:
        return '📅';
    }
  }

  IconData _getFileIcon(TimeOffFileItem file) {
    if (file.isImage) return Icons.image_rounded;
    if (file.isPdf) return Icons.picture_as_pdf_rounded;
    switch (file.ext) {
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileIconColor(TimeOffFileItem file) {
    if (file.isImage) return const Color(0xFF10B981);
    if (file.isPdf) return const Color(0xFFEF4444);
    switch (file.ext) {
      case 'doc':
      case 'docx':
        return const Color(0xFF3B82F6);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getFileSubtitle(TimeOffFileItem file) {
    final ext = file.ext.isEmpty ? 'FILE' : file.ext.toUpperCase();
    return file.sizeLabel.isEmpty ? ext : '$ext • ${file.sizeLabel}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWideScreen(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Izin',
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
        actions: [
          if (isWeb)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: ElevatedButton.icon(
                onPressed: () => _navigateToFormSubmit(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Ajukan Izin',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black87, size: 18),
              onPressed: _refreshData,
            ),
          ),
        ],
      ),
      body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
      floatingActionButton: isWeb
          ? null
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _navigateToFormSubmit(context),
                label: const Text(
                  'Ajukan Izin',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                icon: const Icon(Icons.add_rounded, size: 22),
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterSection(),
            const SizedBox(height: 24),
            _buildListHeader(),
            const SizedBox(height: 16),
            _buildListContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Scrollbar(
              controller: _webFilterScrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _webFilterScrollController,
                primary: false,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Periode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildWebFilterContent(),
                    const SizedBox(height: 20),
                    _buildWebStats(),
                  ],
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: Scrollbar(
            controller: _webContentScrollController,
            thumbVisibility: true,
            interactive: true,
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                controller: _webContentScrollController,
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildListHeader(),
                    const SizedBox(height: 16),
                    _buildListContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Periode Kerja',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        _isLoadingPeriods
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _workPeriods.isEmpty
            ? Text(
                'Belum ada periode. Tambahkan di Kalender.',
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              )
            : Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPeriod?.id,
                    isExpanded: true,
                    itemHeight: 56,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Pilih periode...',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    selectedItemBuilder: (context) => _workPeriods
                        .map(
                          (p) => Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                p.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: _workPeriods
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p.label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (p.keterangan?.isNotEmpty == true)
                                    Text(
                                      p.keterangan!,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey[500],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    icon: const Icon(Icons.arrow_drop_down),
                    onChanged: (selectedId) {
                      if (selectedId == null) return;
                      setState(() {
                        _selectedPeriod = _workPeriods.firstWhere(
                          (p) => p.id == selectedId,
                        );
                      });
                      _applyClientSideFilter();
                    },
                  ),
                ),
              ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetFilter,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Reset ke Periode Terbaru',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebStats() {
    final approved = _filteredTimeOffList
        .where(
          (t) =>
              t.status.toLowerCase() == 'approved' ||
              t.status.toLowerCase() == 'disetujui',
        )
        .length;
    final pending = _filteredTimeOffList
        .where(
          (t) => ![
            'approved',
            'disetujui',
            'rejected',
            'ditolak',
            'revisi',
          ].contains(t.status.toLowerCase()),
        )
        .length;
    final laporan = _filteredTimeOffList
        .where((t) => t.status.toLowerCase() == 'menunggu laporan')
        .length;
    final rejected = _filteredTimeOffList
        .where(
          (t) =>
              t.status.toLowerCase() == 'rejected' ||
              t.status.toLowerCase() == 'ditolak',
        )
        .length;
    final revisi =
        _filteredTimeOffList // ← BARU
            .where((t) => t.status.toLowerCase() == 'revisi')
            .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistik',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          _buildStatRow(
            'Total',
            _filteredTimeOffList.length,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 6),
          _buildStatRow('Disetujui', approved, const Color(0xFF10B981)),
          const SizedBox(height: 6),
          _buildStatRow('Menunggu', pending, const Color(0xFFF59E0B)),
          if (laporan > 0) ...[
            const SizedBox(height: 6),
            _buildStatRow('Menunggu Laporan', laporan, const Color(0xFF7C3AED)),
          ],
          if (revisi > 0) ...[
            // ← BARU
            const SizedBox(height: 6),
            _buildStatRow('Perlu Revisi', revisi, const Color(0xFFD97706)),
          ],
          const SizedBox(height: 6),
          _buildStatRow('Ditolak', rejected, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Riwayat Izin',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1F2937),
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        Text(
          '${_filteredTimeOffList.length} data',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage.isNotEmpty && _allTimeOffList.isEmpty) {
      return _buildErrorState();
    }
    if (_filteredTimeOffList.isEmpty) return _buildEmptyState();
    return Column(
      children: _filteredTimeOffList.map(_buildTimeOffCard).toList(),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.date_range_rounded,
                    size: 20,
                    color: Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filter Periode Kerja',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _isLoadingPeriods
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _workPeriods.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Belum ada periode kerja. Tambahkan di menu Kalender terlebih dahulu.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedPeriod?.id,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemHeight: 56,
                        hint: const Text(
                          'Pilih periode...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        selectedItemBuilder: (context) => _workPeriods
                            .map(
                              (p) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  p.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        items: _workPeriods
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (p.keterangan?.isNotEmpty == true)
                                      Text(
                                        p.keterangan!,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: Colors.grey[500],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (selectedId) {
                          if (selectedId == null) return;
                          setState(() {
                            _selectedPeriod = _workPeriods.firstWhere(
                              (p) => p.id == selectedId,
                            );
                          });
                          _applyClientSideFilter();
                        },
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(60),
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
      ),
    ),
  );

  Widget _buildErrorState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(40),
    margin: const EdgeInsets.only(top: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Color(0xFFEF4444),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Terjadi Kesalahan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'Coba Lagi',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildEmptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(40),
    margin: const EdgeInsets.only(top: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(
            Icons.calendar_month_outlined,
            size: 40,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tidak ada data Izin',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tidak ada data untuk periode ${_getFilterDisplayText()}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _navigateToFormSubmit(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Ajukan Izin',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Card ──────────────────────────────────────────────────────────────────

  Widget _buildTimeOffCard(TimeOffModel timeOff) {
    final isDL = timeOff.isDinasLuar;
    final isMenungguLaporan = timeOff.status == 'Menunggu Laporan';
    final isMenungguVerHead = timeOff.status == 'Menunggu Verifikasi Head';
    final isMenungguVerHrd = timeOff.status == 'Menunggu Verifikasi HRD';
    final isMenungguTransfer = timeOff.status == 'Menunggu Transfer';
    final isPendingFinance = timeOff.status == 'Pending Finance';
    final isMenungguOrg = timeOff.status == 'Menunggu Org';
    final isRevisi = timeOff.status == 'Revisi'; // ← BARU
    final isApproved =
        timeOff.status.toLowerCase() == 'approved' ||
        timeOff.status.toLowerCase() == 'disetujui';
    final canEditDelete =
        !isDL &&
        (timeOff.status == 'Pending' ||
            timeOff.status == 'Menunggu Manager' ||
            timeOff.status == 'Revisi'); // ← TAMBAH 'Revisi'
    final needsAction = isMenungguLaporan || isRevisi; // ← TAMBAH isRevisi
    final accentColor = _colorForStatus(timeOff.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: needsAction
              ? accentColor.withOpacity(0.4)
              : const Color(0xFFE5E7EB),
          width: needsAction ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (needsAction ? accentColor : Colors.black).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getJenisIcon(timeOff.jenisTimeOff),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              timeOff.jenisTimeOff,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF1F2937),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accentColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _iconForStatus(timeOff.status),
                                  size: 13,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeOff.statusLabel,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${DateFormat('dd MMM yyyy').format(timeOff.tanggalMulai)} s/d ${DateFormat('dd MMM yyyy').format(timeOff.tanggalSelesai)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF374151),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: ${timeOff.totalHari} hari',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Banner Revisi — tampil untuk DL dan non-DL    ← BARU
            if (isRevisi) ...[
              const SizedBox(height: 16),
              _buildRevisionBanner(timeOff),
            ],

            // Banner DL (hanya untuk DL, bukan Revisi)
            if (isDL && !isRevisi) ...[
              if (isMenungguLaporan) ...[
                const SizedBox(height: 16),
                _buildDlBanner(
                  color: const Color(0xFF7C3AED),
                  icon: Icons.upload_file_rounded,
                  title: 'Aksi Diperlukan',
                  message: timeOff.adaBiaya
                      ? 'Dinas Luar kamu sudah disetujui. Upload laporan hasil kerja dan laporan anggaran untuk menyelesaikan proses.'
                      : 'Dinas Luar kamu sudah disetujui. Upload laporan hasil kerja untuk menyelesaikan proses.',
                  actionLabel: 'Upload Laporan DL',
                  onTap: () => _navigateToDlLaporan(timeOff),
                ),
              ],
              if (isMenungguVerHead) ...[
                const SizedBox(height: 16),
                _buildDlBanner(
                  color: const Color(0xFF6366F1),
                  icon: Icons.rate_review_outlined,
                  title: 'Menunggu Verifikasi Head',
                  message: 'Laporan kamu sedang diverifikasi oleh Head Divisi.',
                  actionLabel: null,
                  onTap: null,
                ),
              ],
              if (isMenungguVerHrd) ...[
                const SizedBox(height: 16),
                _buildDlBanner(
                  color: const Color(0xFF6366F1),
                  icon: Icons.rate_review_outlined,
                  title: 'Menunggu Verifikasi HRD',
                  message:
                      'Head sudah menyetujui laporan. Menunggu verifikasi HRD.',
                  actionLabel: null,
                  onTap: null,
                ),
              ],
              if (isMenungguTransfer) ...[
                const SizedBox(height: 16),
                _buildDlBanner(
                  color: const Color(0xFF059669),
                  icon: Icons.payments_outlined,
                  title: 'Menunggu Transfer',
                  message:
                      'Laporan disetujui. Finance akan melakukan transfer reimbursement.',
                  actionLabel: null,
                  onTap: null,
                ),
              ],
              if (isPendingFinance) ...[
                const SizedBox(height: 16),
                _buildDlBanner(
                  color: const Color(0xFF0EA5E9),
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Menunggu Finance',
                  message:
                      'Pengajuan biaya sedang menunggu persetujuan Finance.',
                  actionLabel: null,
                  onTap: null,
                ),
              ],
              if (isMenungguOrg) ...[
                const SizedBox(height: 16),
                _buildDlBanner(
                  color: const Color(0xFFF97316),
                  icon: Icons.groups_outlined,
                  title: 'Menunggu Head Divisi',
                  message:
                      'Pengajuan Dinas Luar sedang menunggu persetujuan Head Divisimu.',
                  actionLabel: null,
                  onTap: null,
                ),
              ],
              if ((timeOff.hasSuratTugas || timeOff.hasFormBiaya) &&
                  !isApproved &&
                  timeOff.status != 'Rejected') ...[
                const SizedBox(height: 10),
                _buildDocDownloadRow(timeOff),
              ],
            ],

            // Laporan submitted
            if (isDL && isApproved && timeOff.laporanStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Laporan sudah disubmit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (timeOff.laporanSubmittedAt != null) ...[
                      const Spacer(),
                      Text(
                        DateFormat(
                          'dd MMM yyyy',
                        ).format(timeOff.laporanSubmittedAt!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Info DL
            if (isDL && timeOff.jenisPekerjaan != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.work_outline,
                      size: 14,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Jenis: ${timeOff.jenisPekerjaan}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B21B6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (timeOff.rabType != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          timeOff.rabType == 'reimbursement'
                              ? '💸 Reimbursement'
                              : '🏢 Uang Kantor',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF5B21B6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // File lampiran
            _buildFilePreview(timeOff),

            // Catatan
            if (timeOff.catatan != null && timeOff.catatan!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.note_alt_rounded,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Catatan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeOff.catatan!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Alasan penolakan (Rejected final)
            if (timeOff.status.toLowerCase() == 'rejected' &&
                timeOff.rejectionReason != null &&
                timeOff.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Alasan Penolakan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeOff.rejectionReason!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFDC2626),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Export formulir
            if (isApproved) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isDL
                      ? () => _exportDlFinal(timeOff)
                      : () => _exportFormulirUser(timeOff),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    isDL ? 'Export Dokumen DL' : 'Export Formulir PDF',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],

            // Edit / Delete (hanya non-DL, status Pending/Revisi)
            if (canEditDelete) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _navigateToFormSubmit(context, editData: timeOff),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(timeOff),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text(
                        'Hapus',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionBanner(TimeOffModel timeOff) {
    final isDL = timeOff.isDinasLuar;

    // Tentukan alasan berdasarkan siapa yang reject
    // Prioritas: hrdRejectionReason → financeRejectionReason → rejectionReason
    String alasan = '';
    String penolak = '';

    if (timeOff.hrdRejectionReason?.isNotEmpty == true) {
      alasan = timeOff.hrdRejectionReason!;
      penolak = 'HRD';
    } else if (timeOff.financeRejectionReason?.isNotEmpty == true) {
      alasan = timeOff.financeRejectionReason!;
      penolak = 'Finance';
    } else if (timeOff.rejectionReason?.isNotEmpty == true) {
      alasan = timeOff.rejectionReason!;
    }

    final String pesanUtama = penolak.isNotEmpty
        ? '$penolak meminta revisi:'
        : 'Pengajuan dikembalikan untuk diperbaiki:';

    final String pesanSub = alasan.isNotEmpty
        ? alasan
        : isDL
        ? 'Perbaiki dokumen atau rincian biaya, lalu ajukan DL baru.'
        : 'Perbaiki data izin dan ajukan ulang.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pengajuan Dikembalikan — Perlu Revisi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Alasan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pesanUtama,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pesanSub,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tombol aksi
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => isDL
                  // DL: ajukan DL baru (tidak bisa edit yang lama)
                  ? _navigateToFormSubmit(context)
                  // Non-DL: edit data yang sudah ada lalu resubmit
                  : _navigateToFormSubmit(context, editData: timeOff),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                isDL ? 'Ajukan DL Baru' : 'Perbaiki & Ajukan Ulang',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Info tambahan untuk DL
          if (isDL) ...[
            const SizedBox(height: 8),
            const Text(
              '💡 Pengajuan DL yang direvisi tidak bisa diedit. Kamu perlu membuat pengajuan DL baru.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
  

  // ── DL Banner ─────────────────────────────────────────────────────────────

  Widget _buildDlBanner({
    required Color color,
    required IconData icon,
    required String title,
    required String message,
    required String? actionLabel,
    required VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocDownloadRow(TimeOffModel timeOff) {
    return Row(
      children: [
        if (timeOff.hasSuratTugas)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _downloadDlDoc(timeOff, 'surat_tugas'),
              icon: const Icon(Icons.assignment_outlined, size: 16),
              label: const Text(
                'Surat Tugas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        if (timeOff.hasSuratTugas && timeOff.hasFormBiaya)
          const SizedBox(width: 8),
        if (timeOff.hasFormBiaya)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _downloadDlDoc(timeOff, 'form_biaya'),
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: Text(
                timeOff.rabType == 'reimbursement'
                    ? 'Form Reimburse'
                    : 'Form Uang Muka',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _downloadDlDoc(TimeOffModel timeOff, String docType) async {
    try {
      _showSnackBar('Mengunduh dokumen...', isError: false);
      final res = await TimeOffService.dlDownloadDoc(
        timeOffId: timeOff.id!,
        userId: widget.userId,
        docType: docType,
      );
      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }
      final bytes = Uint8List.fromList(res.data!);

      // Tentukan nama + ekstensi berdasarkan docType
      // surat_tugas → .pdf (generate via Spire.Doc)
      // form_biaya  → .docx
      String name;
      if (docType == 'surat_tugas') {
        name = 'Surat_Tugas_DL_${timeOff.id}.pdf';
      } else {
        name = timeOff.rabType == 'reimbursement'
            ? 'Form_Reimbursement_${timeOff.id}.docx'
            : 'Form_Uang_Muka_${timeOff.id}.docx';
      }

      if (kIsWeb) {
        downloadFileWeb(bytes, name);
      } else {
        await _saveAndOpenFile(bytes, name);
      }
    } catch (e) {
      _showSnackBar('Gagal download: $e', isError: true);
    }
  }

  // ── File preview ──────────────────────────────────────────────────────────

  Widget _buildFilePreview(TimeOffModel timeOff) {
    final files = timeOff.allFiles;
    if (files.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.attach_file_rounded,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                'File Lampiran (${files.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: files
                .map((file) => _buildSingleFileItem(timeOff, file))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleFileItem(TimeOffModel timeOff, TimeOffFileItem file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _getFileIconColor(file).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getFileIcon(file),
            color: _getFileIconColor(file),
            size: 22,
          ),
        ),
        title: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            _getFileSubtitle(file),
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Preview',
              icon: const Icon(
                Icons.visibility_rounded,
                size: 20,
                color: Color(0xFF3B82F6),
              ),
              onPressed: file.id > 0
                  ? () => _previewFileById(file.id, timeOff.id!, file.fileName)
                  : () => _previewFileLegacy(timeOff),
            ),
            IconButton(
              tooltip: 'Download',
              icon: const Icon(
                Icons.download_rounded,
                size: 20,
                color: Color(0xFF10B981),
              ),
              onPressed: file.id > 0
                  ? () => _downloadFileById(file.id, timeOff.id!, file.fileName)
                  : () => _downloadFileLegacy(timeOff),
            ),
          ],
        ),
      ),
    );
  }
}
