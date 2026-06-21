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

import '../../Services/web_download_web.dart';
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
  List<TimeOffModel> _allTimeOffList = [];
  List<TimeOffModel> _filteredTimeOffList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isFilterExpanded = false;

  final List<String> _monthNames = [
    'Semua Bulan',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _loadTimeOffData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    List<TimeOffModel> filtered = _allTimeOffList
        .where((t) => t.tanggalMulai.year == _selectedYear)
        .toList();
    if (_selectedMonth != 0) {
      filtered = filtered
          .where((t) => t.tanggalMulai.month == _selectedMonth)
          .toList();
    }
    filtered.sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));
    setState(() => _filteredTimeOffList = filtered);
  }

  Future<void> _refreshData() async => _loadTimeOffData();

  void _applyFilter() {
    setState(() => _isFilterExpanded = false);
    _applyClientSideFilter();
  }

  void _resetFilter() {
    setState(() {
      _selectedYear = DateTime.now().year;
      _selectedMonth = DateTime.now().month;
      _isFilterExpanded = false;
    });
    _applyClientSideFilter();
  }

  String _getFilterDisplayText() {
    final monthName = _selectedMonth == 0
        ? 'Semua'
        : _monthNames[_selectedMonth];
    return '$monthName $_selectedYear';
  }

  List<int> _getAvailableYears() {
    final years = _allTimeOffList
        .map((t) => t.tanggalMulai.year)
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a));
    if (years.isEmpty) {
      final y = DateTime.now().year;
      return List.generate(5, (i) => y - 2 + i);
    }
    return years;
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
      if (res.success && res.data != null) {
        await _saveAndOpenFile(Uint8List.fromList(res.data!), fileName);
      } else {
        _showSnackBar(res.message, isError: true);
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
        downloadFileWeb(bytes, fileName);
      } else {
        await _openTempFile(bytes, fileName);
      }
    } catch (e) {
      _showSnackBar('Gagal membuka preview: $e', isError: true);
    }
  }

  Future<void> _saveAndOpenFile(Uint8List fileBytes, String fileName) async {
    if (kIsWeb) {
      // Di web: langsung trigger download via browser
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

  Future<void> _openTempFile(Uint8List fileBytes, String fileName) async {
    if (kIsWeb) {
      _showSnackBar('Preview file tidak tersedia di web.', isError: false);
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
      case 'menunggu laporan':
        return const Color(0xFF7C3AED);
      case 'menunggu manager':
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
      case 'menunggu laporan':
        return Icons.upload_file_rounded;
      case 'menunggu manager':
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

  // ── File icon helpers ─────────────────────────────────────────────────────

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

  // ── Mobile layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        controller: _scrollController,
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

  // ── Web layout ────────────────────────────────────────────────────────────

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
            child: SingleChildScrollView(
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
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
      ],
    );
  }

  Widget _buildWebFilterContent() {
    final availableYears = _getAvailableYears();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tahun',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: availableYears.contains(_selectedYear)
                  ? _selectedYear
                  : availableYears.first,
              isExpanded: true,
              onChanged: (v) => setState(() => _selectedYear = v!),
              items: availableYears
                  .map(
                    (y) => DropdownMenuItem(
                      value: y,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(y.toString()),
                      ),
                    ),
                  )
                  .toList(),
              icon: const Icon(Icons.arrow_drop_down),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Bulan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedMonth,
              isExpanded: true,
              onChanged: (v) => setState(() => _selectedMonth = v!),
              items: List.generate(
                _monthNames.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_monthNames[i]),
                  ),
                ),
              ).toList(),
              icon: const Icon(Icons.arrow_drop_down),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
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
                  'Reset',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _applyFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Terapkan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
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
        .where((t) => t.status.toLowerCase() == 'pending')
        .length;
    final menungguLaporan = _filteredTimeOffList
        .where((t) => t.status.toLowerCase() == 'menunggu laporan')
        .length;
    final rejected = _filteredTimeOffList
        .where(
          (t) =>
              t.status.toLowerCase() == 'rejected' ||
              t.status.toLowerCase() == 'ditolak',
        )
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
          if (menungguLaporan > 0) ...[
            const SizedBox(height: 6),
            _buildStatRow(
              'Menunggu Laporan',
              menungguLaporan,
              const Color(0xFF7C3AED),
            ),
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
    final availableYears = _getAvailableYears();
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
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: _isFilterExpanded
                  ? Radius.zero
                  : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter Periode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getFilterDisplayText(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (_isFilterExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tahun:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: availableYears.contains(_selectedYear)
                                  ? _selectedYear
                                  : availableYears.first,
                              onChanged: (v) =>
                                  setState(() => _selectedYear = v!),
                              items: availableYears
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(y.toString()),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Bulan:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedMonth,
                              onChanged: (v) =>
                                  setState(() => _selectedMonth = v!),
                              items: List.generate(
                                _monthNames.length,
                                (i) => DropdownMenuItem(
                                  value: i,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(_monthNames[i]),
                                  ),
                                ),
                              ).toList(),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetFilter,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Reset',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _applyFilter,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text(
                            'Terapkan Filter',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
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

  // ── Time off card ─────────────────────────────────────────────────────────

  Widget _buildTimeOffCard(TimeOffModel timeOff) {
    final isMenungguLaporan = timeOff.status == 'Menunggu Laporan';
    final canEditDelete =
        timeOff.status == 'Pending' || timeOff.status == 'Menunggu Manager';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMenungguLaporan
              ? const Color(0xFF7C3AED).withOpacity(0.4)
              : const Color(0xFFE5E7EB),
          width: isMenungguLaporan ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMenungguLaporan ? const Color(0xFF7C3AED) : Colors.black)
                .withOpacity(0.05),
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
            // ── Header row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _colorForStatus(timeOff.status).withOpacity(0.1),
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
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _colorForStatus(
                                timeOff.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _colorForStatus(
                                  timeOff.status,
                                ).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _iconForStatus(timeOff.status),
                                  size: 14,
                                  color: _colorForStatus(timeOff.status),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeOff.statusLabel,
                                  style: TextStyle(
                                    color: _colorForStatus(timeOff.status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Tanggal
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
                                    '${DateFormat('dd MMM yyyy').format(timeOff.tanggalMulai)}'
                                    ' s/d ${DateFormat('dd MMM yyyy').format(timeOff.tanggalSelesai)}',
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

            // ── Banner "Menunggu Laporan" ─────────────────────────────
            if (isMenungguLaporan) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          size: 16,
                          color: Color(0xFF7C3AED),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Aksi Diperlukan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dinas Luar kamu sudah disetujui. Upload laporan hasil kerja dan laporan anggaran untuk menyelesaikan proses.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4C1D95),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToDlLaporan(timeOff),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text(
                          'Upload Laporan DL',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
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
                ),
              ),
            ],

            // ── Laporan sudah disubmit ────────────────────────────────
            if (timeOff.isDinasLuar &&
                timeOff.status == 'Approved' &&
                timeOff.laporanStatus != null) ...[
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

            // ── Info DL ───────────────────────────────────────────────
            if (timeOff.isDinasLuar && timeOff.jenisPekerjaan != null) ...[
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

            // ── File lampiran ─────────────────────────────────────────
            _buildFilePreview(timeOff),

            // ── Catatan ───────────────────────────────────────────────
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

            // ── Alasan penolakan ──────────────────────────────────────
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

            // ── Edit / Delete ─────────────────────────────────────────
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
            // Gunakan file.id jika ada (tabel baru), fallback ke timeOff.id (file lama)
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

  // Legacy download (kolom file_name lama di udt_timeoff, id = 0)
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
      _showSnackBar('Membuka preview...', isError: false);
      final res = await TimeOffService.downloadFile(timeOff.id!, widget.userId);
      if (!res.success || res.data == null) {
        _showSnackBar(res.message, isError: true);
        return;
      }
      final bytes = Uint8List.fromList(res.data!);
      if (kIsWeb) {
        downloadFileWeb(bytes, timeOff.fileName!);
      } else {
        await _openTempFile(bytes, timeOff.fileName!);
      }
    } catch (e) {
      _showSnackBar('Gagal membuka: $e', isError: true);
    }
  }
}
