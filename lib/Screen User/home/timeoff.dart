// screens/time_off_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';

import 'package:absensikaryawan/Screen%20User/home/ajuantimeoff.dart';
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class TimeOffScreen extends StatefulWidget {
  final String userId; // Pass dari screen sebelumnya

  const TimeOffScreen({super.key, required this.userId});

  @override
  State<TimeOffScreen> createState() => _TimeOffScreenState();
}

class _TimeOffScreenState extends State<TimeOffScreen> {
  List<TimeOffModel> _allTimeOffList = []; // Semua data dari API
  List<TimeOffModel> _filteredTimeOffList = []; // Data yang sudah difilter
  bool _isLoading = true;
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();

  // Filter variables
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isFilterExpanded = false;

  // Month names
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

  Future<void> _loadTimeOffData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Ambil semua data dari API tanpa filter
      final response = await TimeOffService.getMyTimeOff(widget.userId);

      if (response.success && response.data != null) {
        setState(() {
          _allTimeOffList = response.data!.data;
          _applyClientSideFilter(); // Terapkan filter di client
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyClientSideFilter() {
    List<TimeOffModel> filtered = _allTimeOffList;

    // Filter berdasarkan tahun
    filtered = filtered.where((timeOff) {
      return timeOff.tanggalMulai.year == _selectedYear;
    }).toList();

    // Filter berdasarkan bulan (jika bukan "Semua Bulan")
    if (_selectedMonth != 0) {
      filtered = filtered.where((timeOff) {
        return timeOff.tanggalMulai.month == _selectedMonth;
      }).toList();
    }

    // Urutkan berdasarkan tanggal terbaru
    filtered.sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));

    setState(() {
      _filteredTimeOffList = filtered;
    });
  }

  Future<void> _refreshData() async {
    await _loadTimeOffData();
  }

  void _applyFilter() {
    setState(() {
      _isFilterExpanded = false;
    });
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

  // Mendapatkan tahun yang tersedia dari data
  List<int> _getAvailableYears() {
    final years = _allTimeOffList
        .map((timeOff) => timeOff.tanggalMulai.year)
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a)); // Urutkan dari terbaru

    // Jika tidak ada data, gunakan 5 tahun terakhir
    if (years.isEmpty) {
      final currentYear = DateTime.now().year;
      return List.generate(5, (index) => currentYear - 2 + index);
    }

    return years;
  }

  void _navigateToFormSubmit(BuildContext context, {TimeOffModel? editData}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTimeOffScreen(userId: widget.userId, editData: editData),
      ),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  // Future<void> _deleteTimeOff(TimeOffModel timeOff) async {
  //   // Show confirmation dialog
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Row(
  //         children: [
  //           Icon(
  //             Icons.warning_amber_rounded,
  //             color: Color(0xFFEF4444),
  //             size: 28,
  //           ),
  //           SizedBox(width: 12),
  //           Text(
  //             'Konfirmasi Hapus',
  //             style: TextStyle(fontWeight: FontWeight.w700),
  //           ),
  //         ],
  //       ),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             'Apakah Anda yakin ingin menghapus pengajuan time off ini?',
  //             style: TextStyle(fontSize: 16),
  //           ),
  //           const SizedBox(height: 16),
  //           Container(
  //             padding: const EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: const Color(0xFFF8FAFC),
  //               borderRadius: BorderRadius.circular(12),
  //               border: Border.all(color: const Color(0xFFE2E8F0)),
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text('📅 ${timeOff.jenisTimeOff}'),
  //                 const SizedBox(height: 4),
  //                 Text(
  //                   '🗓️ ${DateFormat('dd MMM yyyy').format(timeOff.tanggalMulai)} - ${DateFormat('dd MMM yyyy').format(timeOff.tanggalSelesai)}',
  //                 ),
  //                 const SizedBox(height: 4),
  //                 Text('⏱️ ${timeOff.totalHari} hari'),
  //                 if (timeOff.catatan != null &&
  //                     timeOff.catatan!.isNotEmpty) ...[
  //                   const SizedBox(height: 4),
  //                   Text('📝 ${timeOff.catatan}'),
  //                 ],
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 12),
  //           const Text(
  //             'Data yang dihapus tidak dapat dikembalikan.',
  //             style: TextStyle(
  //               fontSize: 14,
  //               color: Color(0xFFEF4444),
  //               fontWeight: FontWeight.w500,
  //             ),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(false),
  //           child: const Text('Batal'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.of(context).pop(true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: const Color(0xFFEF4444),
  //             foregroundColor: Colors.white,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //           child: const Text('Hapus'),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirmed == true) {
  //     // Show loading dialog
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (context) => const Center(child: CircularProgressIndicator()),
  //     );

  //     try {
  //       final deleteRequest = DeleteTimeOffRequest(
  //         id: timeOff.id!,
  //         userId: widget.userId,
  //       );

  //       final response = await TimeOffService.deleteTimeOff(deleteRequest);
  //       Navigator.pop(context); // Close loading dialog

  //       if (response.success) {
  //         _showSnackBar('Data time off berhasil dihapus', isError: false);
  //         _refreshData();
  //       } else {
  //         _showSnackBar(response.message, isError: true);
  //       }
  //     } catch (e) {
  //       Navigator.pop(context); // Close loading dialog
  //       _showSnackBar('Terjadi kesalahan: ${e.toString()}', isError: true);
  //     }
  //   }
  // }

  Future<void> _downloadFile(TimeOffModel timeOff) async {
    if (timeOff.id == null) {
      _showSnackBar('ID Cuti tidak valid', isError: true);
      return;
    }

    try {
      _showSnackBar('Mengunduh file...', isError: false);

      final response = await TimeOffService.downloadFile(
        timeOff.id!,
        widget.userId,
      );

      if (response.success && response.data != null) {
        final fileBytes = Uint8List.fromList(response.data!);
        await _saveAndOpenFile(fileBytes, timeOff.fileName!);
      } else {
        _showSnackBar(response.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Gagal mengunduh file: $e', isError: true);
    }
  }

  Future<void> _saveAndOpenFile(Uint8List fileBytes, String fileName) async {
    try {
      // Check dan request permission yang tepat
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        _showSnackBar(
          'Izin akses storage diperlukan untuk menyimpan file',
          isError: true,
        );
        return;
      }

      // Get directory untuk menyimpan file
      final directory = await _getDownloadDirectory();
      if (directory == null) {
        _showSnackBar('Tidak dapat mengakses folder download', isError: true);
        return;
      }

      // Buat file path yang unik jika file sudah ada
      final filePath = await _getUniqueFilePath(directory.path, fileName);
      final file = File(filePath);

      // Write file
      await file.writeAsBytes(fileBytes);

      _showSnackBar('File berhasil diunduh ke Downloads', isError: false);

      // Open file automatically
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        // Jika gagal buka otomatis, tampilkan dialog
        _showOpenFileDialog(filePath, fileName);
      }
    } catch (e) {
      _showSnackBar('Gagal menyimpan file: $e', isError: true);
    }
  }

  Future<String> _getUniqueFilePath(String dirPath, String fileName) async {
    String filePath = '$dirPath/$fileName';

    // Jika file sudah ada, tambahkan angka di belakang nama
    int counter = 1;
    while (await File(filePath).exists()) {
      final nameWithoutExt = fileName.split('.').first;
      final extension = fileName.split('.').last;
      filePath = '$dirPath/${nameWithoutExt}_$counter.$extension';
      counter++;
    }

    return filePath;
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) {
      return true; // iOS tidak perlu permission khusus untuk Documents directory
    }

    // Get Android version - PERBAIKAN: gunakan version.sdkInt
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt; // UBAH DARI androidInfo.sdkInt

    if (sdkInt >= 30) {
      // Android 11+ (API 30+) - Tidak perlu permission untuk Downloads folder
      return true;
    } else if (sdkInt >= 23) {
      // Android 6+ (API 23+) - Perlu permission storage
      final status = await Permission.storage.request();
      return status.isGranted;
    } else {
      // Android dibawah 6.0 - Tidak perlu runtime permission
      return true;
    }
  }

  Future<Directory?> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Untuk Android 11+, gunakan getExternalStorageDirectory
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt =
            androidInfo.version.sdkInt; // UBAH DARI androidInfo.sdkInt

        if (sdkInt >= 30) {
          final appDir = await getExternalStorageDirectory();
          if (appDir != null) {
            // Buat folder Downloads di app directory
            final downloadDir = Directory('${appDir.path}/Downloads');
            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }
            return downloadDir;
          }
        } else {
          // Untuk Android dibawah 11, gunakan Downloads folder sistem
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            return downloadsDir;
          }
        }

        // Fallback ke external storage directory
        return await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        // Untuk iOS, gunakan Documents directory
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat mendownload file.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return null;
  }

  // Dialog untuk membuka file manual jika auto-open gagal
  void _showOpenFileDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nanti'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
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

  // Alternative: Langsung buka file tanpa menyimpan (untuk preview)
  Future<void> _previewFile(TimeOffModel timeOff) async {
    if (timeOff.id == null) {
      _showSnackBar('ID Cuti tidak valid', isError: true);
      return;
    }

    try {
      _showSnackBar('Membuka preview...', isError: false);

      final response = await TimeOffService.downloadFile(
        timeOff.id!,
        widget.userId,
      );

      if (response.success && response.data != null) {
        final fileBytes = Uint8List.fromList(response.data!);
        await _openTempFile(fileBytes, timeOff.fileName!);
      } else {
        _showSnackBar(response.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Gagal membuka preview: $e', isError: true);
    }
  }

  Future<void> _openTempFile(Uint8List fileBytes, String fileName) async {
    try {
      // Tidak perlu permission untuk temp directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');

      await tempFile.writeAsBytes(fileBytes);

      final result = await OpenFile.open(tempFile.path);

      if (result.type == ResultType.done) {
        _showSnackBar('File dibuka untuk preview', isError: false);
      } else {
        _showSnackBar(
          'Tidak dapat membuka file: ${result.message}',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Gagal membuka file: $e', isError: true);
    }
  }

  // Untuk menambahkan opsi preview dan download terpisah
  Widget _buildDownloadButton(TimeOffModel timeOff) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview button (tidak perlu permission)
        InkWell(
          onTap: () =>
              _previewFile(timeOff), // PASTIKAN MEMANGGIL FUNGSI YANG BENAR
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.visibility_rounded,
              size: 16,
              color: Color(0xFF10B981),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Download button
        InkWell(
          onTap: () => _downloadFile(timeOff),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.download_rounded,
              size: 16,
              color: Color(0xFF3B82F6),
            ),
          ),
        ),
      ],
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

  Color _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "disetujui":
        return const Color(0xFF10B981);
      case "rejected":
      case "ditolak":
        return const Color(0xFFEF4444);
      case "pending":
      case "menunggu":
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _iconForStatus(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "disetujui":
        return Icons.check_circle_rounded;
      case "rejected":
      case "ditolak":
        return Icons.cancel_rounded;
      case "pending":
      case "menunggu":
      default:
        return Icons.schedule_rounded;
    }
  }

  String _getJenisIcon(String jenis) {
    switch (jenis) {
      case "Cuti Tahunan":
        return "🏖️";
      case "Sakit":
        return "🏥";
      case "Cuti Khusus":
        return "🎉";
      case "Izin Pribadi":
        return "👤";
      default:
        return "📅";
    }
  }

  String _getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

  bool _isImageFile(String fileName) {
    final extension = _getFileExtension(fileName);
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  Widget _buildFilePreview(TimeOffModel timeOff) {
    if (timeOff.fileName == null || timeOff.fileName!.isEmpty) {
      return const SizedBox.shrink();
    }

    final fileName = timeOff.fileName!;
    _getFileExtension(fileName);
    final isImage = _isImageFile(fileName);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              SizedBox(width: 6),
              Text(
                "File Lampiran",
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
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: isImage
                ? _buildImagePreview(timeOff)
                : _buildDocumentPreview(timeOff),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(TimeOffModel timeOff) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          // Image preview section
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey[100],
            child: Stack(
              children: [
                // Placeholder for image - In a real app, you'd load from network
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_rounded,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preview Gambar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // File type badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getFileExtension(timeOff.fileName!).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // File info section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeOff.fileName!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gambar • ${_getFileExtension(timeOff.fileName!).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildDownloadButton(timeOff),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview(TimeOffModel timeOff) {
    final fileExtension = _getFileExtension(timeOff.fileName!);

    IconData fileIcon;
    Color iconColor;
    String fileType;

    switch (fileExtension) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf_rounded;
        iconColor = const Color(0xFFEF4444);
        fileType = 'PDF Document';
        break;
      case 'doc':
      case 'docx':
        fileIcon = Icons.description_rounded;
        iconColor = const Color(0xFF2563EB);
        fileType = 'Word Document';
        break;
      default:
        fileIcon = Icons.insert_drive_file_rounded;
        iconColor = const Color(0xFF6B7280);
        fileType = 'Document';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(fileIcon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeOff.fileName!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$fileType • ${fileExtension.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildDownloadButton(timeOff),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _getAvailableYears();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Cuti',
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
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Section
              _buildFilterSection(),

              const SizedBox(height: 24),

              // Section Header
              Row(
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
                    "Riwayat Cuti",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${_filteredTimeOffList.length} data",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Content based on loading state
              if (_isLoading)
                _buildLoadingState()
              else if (_errorMessage.isNotEmpty && _allTimeOffList.isEmpty)
                _buildErrorState()
              else if (_filteredTimeOffList.isEmpty)
                _buildEmptyState()
              else
                ..._filteredTimeOffList.map(
                  (timeOff) => _buildTimeOffCard(timeOff),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
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
            'Ajukan Cuti',
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

  Widget _buildFilterSection() {
    final availableYears = _getAvailableYears();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
          // Filter Header
          InkWell(
            onTap: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
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

          // Filter Content
          if (_isFilterExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Year Selector
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
                                  : (availableYears.isNotEmpty
                                        ? availableYears.first
                                        : DateTime.now().year),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value!;
                                });
                              },
                              items: availableYears.map((year) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(year.toString()),
                                  ),
                                );
                              }).toList(),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Month Selector
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
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value!;
                                });
                              },
                              items: List.generate(_monthNames.length, (index) {
                                return DropdownMenuItem(
                                  value: index,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(_monthNames[index]),
                                  ),
                                );
                              }),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
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

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
            "Terjadi Kesalahan",
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
              "Coba Lagi",
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
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
            "Tidak ada data Cuti",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tidak ada data Cuti untuk periode ${_getFilterDisplayText()}.\nCoba ubah filter periode atau buat pengajuan baru.",
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
              "Ajukan Cuti",
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
  }

  Widget _buildTimeOffCard(TimeOffModel timeOff) {
    final canEdit = timeOff.status.toLowerCase() == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
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
                      // Jenis dan Status
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
                                width: 1,
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
                                  timeOff.status,
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

                      // Tanggal dan Total Hari
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
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
                                    "${DateFormat('dd MMM yyyy').format(timeOff.tanggalMulai)} s/d ${DateFormat('dd MMM yyyy').format(timeOff.tanggalSelesai)}",
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
                                  "Total: ${timeOff.totalHari} hari",
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

                // Action Menu for Pending Status
                if (canEdit) ...[
                  const SizedBox(width: 8),
                  // PopupMenuButton<String>(
                  //   onSelected: (value) {
                  //     if (value == 'edit') {
                  //       _navigateToFormSubmit(context, editData: timeOff);
                  //     } else if (value == 'delete') {
                  //       _deleteTimeOff(timeOff);
                  //     }
                  //   },
                  //   shape: RoundedRectangleBorder(
                  //     borderRadius: BorderRadius.circular(12),
                  //   ),
                  //   // itemBuilder: (context) => [
                  //   //   const PopupMenuItem(
                  //   //     value: 'edit',
                  //   //     child: Row(
                  //   //       children: [
                  //   //         Icon(
                  //   //           Icons.edit_rounded,
                  //   //           size: 18,
                  //   //           color: Color(0xFF3B82F6),
                  //   //         ),
                  //   //         SizedBox(width: 12),
                  //   //         Text('Edit'),
                  //   //       ],
                  //   //     ),
                  //   //   ),
                  //   //   const PopupMenuItem(
                  //   //     value: 'delete',
                  //   //     child: Row(
                  //   //       children: [
                  //   //         Icon(
                  //   //           Icons.delete_rounded,
                  //   //           size: 18,
                  //   //           color: Color(0xFFEF4444),
                  //   //         ),
                  //   //         SizedBox(width: 12),
                  //   //         Text(
                  //   //           'Hapus',
                  //   //           style: TextStyle(color: Color(0xFFEF4444)),
                  //   //         ),
                  //   //       ],
                  //   //     ),
                  //   //   ),
                  //   // ],
                  //   // child: Container(
                  //   //   padding: const EdgeInsets.all(8),
                  //   //   decoration: BoxDecoration(
                  //   //     color: const Color(0xFFF3F4F6),
                  //   //     borderRadius: BorderRadius.circular(8),
                  //   //   ),
                  //   //   child: const Icon(
                  //   //     Icons.more_vert_rounded,
                  //   //     size: 18,
                  //   //     color: Color(0xFF6B7280),
                  //   //   ),
                  //   // ),
                  // ),
                ],
              ],
            ),

            // File Preview Section - NEW!
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
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
                          "Catatan",
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

            // Action Buttons untuk status Pending (alternative display)
            if (canEdit) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     onPressed: () =>
                  //         _navigateToFormSubmit(context, editData: timeOff),
                  //     icon: const Icon(Icons.edit_rounded, size: 16),
                  //     label: const Text('Edit'),
                  //     style: OutlinedButton.styleFrom(
                  //       foregroundColor: const Color(0xFF3B82F6),
                  //       side: const BorderSide(color: Color(0xFF3B82F6)),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //       padding: const EdgeInsets.symmetric(vertical: 8),
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(width: 12),
                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     onPressed: () => _deleteTimeOff(timeOff),
                  //     icon: const Icon(Icons.delete_rounded, size: 16),
                  //     label: const Text('Hapus'),
                  //     style: OutlinedButton.styleFrom(
                  //       foregroundColor: const Color(0xFFEF4444),
                  //       side: const BorderSide(color: Color(0xFFEF4444)),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //       padding: const EdgeInsets.symmetric(vertical: 8),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],

            // Rejection reason jika ditolak
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
                    width: 1,
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
                          "Alasan Penolakan",
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
          ],
        ),
      ),
    );
  }
}
