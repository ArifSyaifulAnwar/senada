// screens/add_time_off_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:absensikaryawan/Screen%20User/fitur/ajukanreimbursement.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class AddTimeOffScreen extends StatefulWidget {
  final String userId;
  final TimeOffModel? editData;

  const AddTimeOffScreen({super.key, required this.userId, this.editData});

  @override
  State<AddTimeOffScreen> createState() => _AddTimeOffScreenState();
}

class _AddTimeOffScreenState extends State<AddTimeOffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catatanController = TextEditingController();
  XFile? _selectedImage;

  String? _selectedJenis;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Variables for existing file handling
  bool _hasExistingFile = false;
  String? _existingFileName;
  bool _keepExistingFile = true; // Default to keep existing file
  bool _isDownloadingFile = false;

  final List<Map<String, dynamic>> _jenisTimeOff = [
    {
      'value': 'Cuti Tahunan',
      'label': 'Cuti Tahunan',
      'icon': '🏖️',
      'description': 'Cuti tahunan untuk istirahat',
    },
    {
      'value': 'Sakit',
      'label': 'Izin Sakit',
      'icon': '🏥',
      'description': 'Izin karena sakit',
    },
    {
      'value': 'Cuti Khusus',
      'label': 'Cuti Khusus',
      'icon': '🎉',
      'description': 'Cuti untuk acara penting',
    },
    {
      'value': 'Izin Pribadi',
      'label': 'Izin Pribadi',
      'icon': '👤',
      'description': 'Izin untuk keperluan pribadi',
    },
    {
      'value': 'Cuti Lahiran',
      'label': 'Cuti Lahiran',
      'icon': '👶',
      'description': 'Cuti untuk melahirkan atau mendampingi istri melahirkan',
    },
    {
      'value': 'Dinas Luar',
      'label': 'Dinas Luar',
      'icon': '🧳',
      'description': 'Perjalanan dinas di luar kantor',
    },
    {
      'value': 'Keluarga Meninggal',
      'label': 'Keluarga Meninggal',
      'icon': '🕯️',
      'description': 'Cuti karena anggota keluarga meninggal dunia',
    },
  ];

  bool _isFileRequired() {
    if (_selectedJenis == null) return false;
    return _selectedJenis == 'Sakit' || _selectedJenis == 'Cuti Khusus';
  }

  String _getFileUploadInfo() {
    if (_selectedJenis == null) {
      return 'Upload file pendukung seperti surat dokter, undangan, atau dokumen lainnya';
    }

    switch (_selectedJenis) {
      case 'Sakit':
        return 'Upload surat dokter atau keterangan medis (WAJIB)';
      case 'Cuti Khusus':
        return 'Upload undangan atau dokumen pendukung acara (WAJIB)';
      case 'Cuti Tahunan':
        return 'Upload dokumen pendukung jika diperlukan (OPSIONAL)';
      case 'Izin Pribadi':
        return 'Upload dokumen pendukung jika diperlukan (OPSIONAL)';
      case 'Cuti Lahiran':
        return 'Upload surat keterangan lahir jika diperlukan (OPSIONAL)';
      case 'Dinas Luar':
        return 'Upload surat tugas atau undangan jika diperlukan (OPSIONAL)';
      case 'Keluarga Meninggal':
        return 'Upload surat keterangan kematian jika diperlukan (OPSIONAL)';
      default:
        return 'Upload file pendukung jika diperlukan (OPSIONAL)';
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _isEditMode = widget.editData != null;

    if (_isEditMode) {
      _loadEditData();
    }
  }

  void _loadEditData() {
    final data = widget.editData!;
    _selectedJenis = data.jenisTimeOff;
    _tanggalMulai = data.tanggalMulai;
    _tanggalSelesai = data.tanggalSelesai;
    _catatanController.text = data.catatan ?? '';

    // Check if existing file exists
    if (data.fileName != null && data.fileName!.isNotEmpty) {
      _hasExistingFile = true;
      _existingFileName = data.fileName;
      _keepExistingFile = true;
    }
  }

  Future<void> _downloadExistingFile() async {
    if (!_hasExistingFile || widget.editData?.id == null) {
      _showErrorSnackBar('File tidak tersedia untuk didownload');
      return;
    }

    setState(() {
      _isDownloadingFile = true;
    });

    try {
      final response = await TimeOffService.downloadFile(
        widget.editData!.id!,
        widget.userId,
      );

      if (response.success && response.data != null) {
        // Here you would handle the file download
        // For mobile apps, you might want to save to downloads folder
        // or open the file with a file viewer
        _showSuccessSnackBar('File berhasil didownload');

        // You can implement platform-specific file saving here
        // For example, using path_provider and permission_handler
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      _showErrorSnackBar('Gagal mendownload file: $e');
    } finally {
      setState(() {
        _isDownloadingFile = false;
      });
    }
  }

  void _chooseNewFile() {
    setState(() {
      _keepExistingFile = false;
      _selectedImage = null;
    });
    _showFileSourceOptions(context);
  }

  void _keepExistingFileOption() {
    setState(() {
      _keepExistingFile = true;
      _selectedImage = null;
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannel();
    await _requestNotificationPermission();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'timeoff_channel',
      'Time Off Notifications',
      description: 'Notifikasi untuk status pengajuan Cuti',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {}
  }

  // ... (keep all existing notification methods)

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_isEditMode) {
      if (_isFileRequired() && _selectedImage == null) {
        _showErrorSnackBar(
          'File pendukung WAJIB untuk jenis Cuti "$_selectedJenis". Harap upload surat dokter atau dokumen pendukung.',
        );
        return;
      }
    } else {
      // Mode EDIT: File wajib hanya untuk Sakit dan Cuti Khusus
      if (_isFileRequired()) {
        // Jika file wajib, harus ada file (baik existing atau new)
        if (!_keepExistingFile && _selectedImage == null) {
          _showErrorSnackBar(
            'File pendukung WAJIB untuk jenis Cuti "$_selectedJenis". '
            'Harap pilih file baru atau pertahankan file yang ada.',
          );
          return;
        }

        // Jika keep existing file, pastikan memang ada file existing
        if (_keepExistingFile && !_hasExistingFile) {
          _showErrorSnackBar(
            'File pendukung WAJIB untuk jenis Cuti "$_selectedJenis". '
            'Tidak ada file existing, harap upload file baru.',
          );
          return;
        }
      }
    }

    // Validasi jenis Cuti
    if (_selectedJenis == null) {
      _showSnackBar('Pilih jenis Cuti terlebih dahulu', isError: true);
      return;
    }

    // Validasi tanggal
    if (_tanggalMulai == null) {
      _showSnackBar('Pilih tanggal mulai terlebih dahulu', isError: true);
      return;
    }

    if (_tanggalSelesai == null) {
      _showSnackBar('Pilih tanggal selesai terlebih dahulu', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditMode) {
        // ✅ TRIM value sebelum dikirim
        final updateRequest = UpdateTimeOffRequest(
          id: widget.editData!.id!,
          userId: widget.userId,
          jenisTimeOff: _selectedJenis!.trim(), // ✅ TRIM HERE
          tanggalMulai: _tanggalMulai!,
          tanggalSelesai: _tanggalSelesai!,
          catatan: _catatanController.text.trim().isEmpty
              ? null
              : _catatanController.text.trim(),
          receiptFile: (!_keepExistingFile && _selectedImage != null)
              ? File(_selectedImage!.path)
              : null,
        );


        final response = await TimeOffService.updateTimeOff(updateRequest);

        if (response.success) {
          _showSnackBar('Cuti berhasil diupdate!', isError: false);
          Navigator.of(context).pop(true);
        } else {
          _showSnackBar(response.message, isError: true);
        }
      } else {
        // ✅ TRIM value sebelum dikirim
        final request = TimeOffRequest(
          userId: widget.userId,
          jenisTimeOff: _selectedJenis!.trim(), // ✅ TRIM HERE
          tanggalMulai: _tanggalMulai!,
          tanggalSelesai: _tanggalSelesai!,
          catatan: _catatanController.text.trim().isEmpty
              ? null
              : _catatanController.text.trim(),
          receiptFile: _selectedImage != null
              ? File(_selectedImage!.path)
              : null,
        );


        final response = await TimeOffService.submitTimeOff(request);

        if (response.success && response.data != null) {
          _showSnackBar('Cuti berhasil diajukan!', isError: false);
          await _showSuccessNotification(response.data.toString());
          Navigator.of(context).pop(true);
        } else {
          _showSnackBar(response.message, isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ... (keep all existing helper methods for notifications, validation, etc.)

  Widget _buildFileSection() {
    final bool isRequired = _isFileRequired();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          isRequired ? 'Upload File (Wajib)' : 'Upload File (Opsional)',
          Icons.upload_file_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRequired ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRequired ? Colors.red[200]! : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isRequired ? Icons.warning_rounded : Icons.info_outline,
                      size: 16,
                      color: isRequired ? Colors.red[600] : Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getFileUploadInfo(),
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: isRequired
                              ? Colors.red[700]
                              : Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Peringatan jika jenis belum dipilih
              if (_selectedJenis == null) ...[
                SizedBox(height: _getResponsivePadding(context, 12)),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pilih jenis Cuti terlebih dahulu untuk melihat persyaratan file',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: Colors.amber[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: _getResponsivePadding(context, 16)),

              // Show existing file in edit mode
              if (_isEditMode && _hasExistingFile) ...[
                _buildExistingFilePreview(),
                const SizedBox(height: 16),
              ],

              // Show file picker
              if (!_isEditMode || !_keepExistingFile) _buildFilePreview(),

              // Action buttons for edit mode
              if (_isEditMode && _hasExistingFile) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _keepExistingFile
                            ? null
                            : _keepExistingFileOption,
                        icon: Icon(
                          _keepExistingFile
                              ? Icons.check_circle
                              : Icons.restore,
                          size: 18,
                        ),
                        label: const Text(
                          'Pertahankan File',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _keepExistingFile
                              ? Colors.green[100]
                              : Colors.grey[100],
                          foregroundColor: _keepExistingFile
                              ? Colors.green[700]
                              : Colors.grey[700],
                          side: BorderSide(
                            color: _keepExistingFile
                                ? Colors.green[300]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: _getResponsivePadding(context, 12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: !_keepExistingFile ? null : _chooseNewFile,
                        icon: Icon(
                          !_keepExistingFile
                              ? Icons.check_circle
                              : Icons.refresh_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Ganti File',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_keepExistingFile
                              ? Colors.blue[100]
                              : Colors.grey[100],
                          foregroundColor: !_keepExistingFile
                              ? Colors.blue[700]
                              : Colors.grey[700],
                          side: BorderSide(
                            color: !_keepExistingFile
                                ? Colors.blue[300]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: _getResponsivePadding(context, 12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Info untuk file opsional jika tidak ada file
              if (!isRequired &&
                  !_isEditMode &&
                  _selectedImage == null &&
                  _selectedJenis != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'File tidak wajib untuk jenis Cuti ini. Anda dapat melanjutkan tanpa upload file.',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExistingFilePreview() {
    if (!_hasExistingFile || _existingFileName == null) {
      return const SizedBox.shrink();
    }

    final String fileName = _existingFileName!;
    final String fileExtension = fileName.split('.').last.toLowerCase();
    final bool isImage = ['jpg', 'jpeg', 'png'].contains(fileExtension);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _keepExistingFile ? Colors.green[300]! : Colors.grey[300]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: (_keepExistingFile ? Colors.green : Colors.grey).withOpacity(
              0.1,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _keepExistingFile ? Colors.green[50] : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done,
                  color: _keepExistingFile
                      ? Colors.green[600]
                      : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File yang sudah ada',
                    style: TextStyle(
                      color: _keepExistingFile
                          ? Colors.green[700]
                          : Colors.grey[700],
                      fontSize: _getResponsiveFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isDownloadingFile)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _keepExistingFile
                            ? Colors.green[600]!
                            : Colors.grey[600]!,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.download,
                      color: _keepExistingFile
                          ? Colors.green[600]
                          : Colors.grey[600],
                      size: 18,
                    ),
                    onPressed: _downloadExistingFile,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: _buildExistingFileContent(fileName, fileExtension, isImage),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getFileTypeFromExtension(fileExtension),
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 11),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _keepExistingFile
                        ? Colors.green[100]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'File tersimpan',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 10),
                      color: _keepExistingFile
                          ? Colors.green[700]
                          : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingFileContent(
    String fileName,
    String fileExtension,
    bool isImage,
  ) {
    IconData fileIcon;
    Color iconColor;

    switch (fileExtension) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        iconColor = Colors.red[600]!;
        break;
      case 'jpg':
      case 'jpeg':
        fileIcon = Icons.image;
        iconColor = Colors.blue[600]!;
        break;
      case 'png':
        fileIcon = Icons.image;
        iconColor = Colors.green[600]!;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        iconColor = Colors.grey[600]!;
    }

    return Container(
      width: double.infinity,
      color: Colors.grey[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(fileIcon, size: 32, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            fileExtension.toUpperCase(),
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getFileTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'PDF Document';
      case 'jpg':
      case 'jpeg':
        return 'JPEG Image';
      case 'png':
        return 'PNG Image';
      default:
        return 'File';
    }
  }

  // ... (keep all existing methods for file picking, validation, UI building, etc.)
  // I'll include the key methods but keeping them the same as before

  Widget _buildFilePreview() {
    final bool isRequired = _isFileRequired();

    if (_selectedImage == null) {
      return GestureDetector(
        onTap: () => _showFileSourceOptions(context),
        child: Container(
          margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 16)),
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(
              color: isRequired ? Colors.red[300]! : Colors.grey[300]!,
              width: isRequired ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: isRequired ? Colors.red[25] : Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRequired ? Colors.red[100] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.upload_file_outlined,
                  size: 28,
                  color: isRequired ? Colors.red[500] : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRequired
                    ? 'Tap untuk upload file (WAJIB)'
                    : 'Tap untuk upload file (OPSIONAL)',
                style: TextStyle(
                  color: isRequired ? Colors.red[600] : Colors.grey[600],
                  fontSize: _getResponsiveFontSize(context, 13),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'JPG, PNG, atau PDF (Max 10MB)',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: _getResponsiveFontSize(context, 11),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Rest of the existing file preview code remains the same
    final String fileName = _selectedImage!.path.split('/').last;
    final String fileExtension = fileName.split('.').last.toLowerCase();
    final bool isImage = ['jpg', 'jpeg', 'png'].contains(fileExtension);

    return Container(
      margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 16)),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue[300]!, width: 2),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File baru dipilih',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: _getResponsiveFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red[600], size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      if (_isEditMode && _hasExistingFile) {
                        _keepExistingFile = true;
                      }
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: isImage
                ? _buildImagePreviewContent()
                : _buildFilePreviewContent(fileName, fileExtension),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getFileInfo(),
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 11),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFileSizeInfo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Include all the existing helper methods
  String _getFileInfo() {
    if (_selectedImage == null) return '';
    final String fileName = _selectedImage!.path.split('/').last;
    final String fileExtension = fileName.split('.').last.toLowerCase();
    return _getFileTypeFromExtension(fileExtension);
  }

  Widget _buildImagePreviewContent() {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(File(_selectedImage!.path)),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreviewContent(String fileName, String fileExtension) {
    IconData fileIcon;
    Color iconColor;

    switch (fileExtension) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        iconColor = Colors.red[600]!;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        iconColor = Colors.blue[600]!;
    }

    return Container(
      width: double.infinity,
      color: Colors.grey[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(fileIcon, size: 40, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            fileExtension.toUpperCase(),
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSizeInfo() {
    return FutureBuilder<int>(
      future: File(_selectedImage!.path).length(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final size = snapshot.data!;
          final sizeInMB = size / (1024 * 1024);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sizeInMB < 5 ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${sizeInMB.toStringAsFixed(1)} MB',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 10),
                color: sizeInMB < 5 ? Colors.green[700] : Colors.orange[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Loading...',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 10),
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  // ... (include all the other existing methods like _showFileSourceOptions,
  // _pickFromGallery, _pickFromCamera, etc. - keeping them unchanged)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Cuti' : 'Ajukan Cuti',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF374151),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Info dengan kondisi edit mode
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isEditMode
                        ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                        : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Icon(
                        //   _isEditMode ? Icons.edit_rounded : Icons.info_rounded,
                        //   color: Colors.white,
                        //   size: 24,
                        // ),
                        const SizedBox(width: 12),
                        Text(
                          _isEditMode
                              ? 'Edit Pengajuan'
                              : 'Informasi Pengajuan',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEditMode
                          ? 'Anda sedang mengedit pengajuan Cuti. Pastikan data yang diubah sudah benar.'
                          : 'Pastikan data yang Anda masukkan sudah benar. Pengajuan akan direview oleh atasan.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    if (_calculateDays() > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total: ${_calculateDays()} hari',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Jenis Cuti
              _buildSectionTitle('Jenis Cuti', Icons.category_rounded),
              const SizedBox(height: 12),
              _buildJenisSelector(),

              const SizedBox(height: 24),

              // Tanggal
              _buildSectionTitle('Periode Cuti', Icons.date_range_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Tanggal Mulai',
                      date: _tanggalMulai,
                      onTap: () => _selectDate(isStartDate: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateField(
                      label: 'Tanggal Selesai',
                      date: _tanggalSelesai,
                      onTap: () => _selectDate(isStartDate: false),
                      enabled: _tanggalMulai != null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Catatan
              _buildSectionTitle('Catatan & Alasan', Icons.note_alt_rounded),
              const SizedBox(height: 12),
              _buildCatatanField(),

              const SizedBox(height: 24),

              // Enhanced File Section
              _buildFileSection(),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditMode
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Memproses...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _isEditMode ? 'Update Cuti' : 'Ajukan Cuti',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
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

  // All remaining helper methods
  Future<bool> _addNotificationToDatabase({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
    String? referenceType,
    bool isImportant = false,
    String? actionText,
    String? actionUrl,
  }) async {
    try {
      final accessToken = await _getToken();
      if (accessToken == null) {
        return false;
      }

      final notificationData = {
        "userId": userId,
        "title": title,
        "message": message,
        "type": type,
        "referenceId": referenceId,
        "referenceType": referenceType,
        "isImportant": isImportant,
        "actionText": actionText,
        "actionUrl": actionUrl,
      };

      final response = await http.post(
        Uri.parse('$baseURL/api/notification/create'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(notificationData),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
        } else if (status.isDenied) {
          if (mounted) {
            _showPermissionDialog();
          }
        } else if (status.isPermanentlyDenied) {
          if (mounted) {
            _showSettingsDialog();
          }
        }

        final notificationPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (notificationPlugin != null) {}
      }

      if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          if (granted != true) {
            if (mounted) {
              _showPermissionDialog();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat meminta izin notifikasi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Izin Notifikasi'),
          content: const Text(
            'Aplikasi membutuhkan izin notifikasi untuk memberitahu Anda ketika pengajuan Cuti berhasil.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestNotificationPermission();
              },
              child: const Text('Berikan Izin'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Izin Notifikasi Diperlukan'),
          content: const Text(
            'Izin notifikasi telah ditolak secara permanen. '
            'Silakan buka pengaturan aplikasi untuk mengaktifkan notifikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
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

  Future<void> _showSuccessNotification(String timeOffId) async {
    try {
      bool hasPermission = await _checkNotificationPermission();
      if (!hasPermission) {
        return;
      }

      final jenisTimeOff = _selectedJenis ?? 'Cuti';
      final totalHari = _calculateDays();
      final tanggalMulai = _tanggalMulai != null
          ? DateFormat('dd MMM yyyy').format(_tanggalMulai!)
          : '';
      final tanggalSelesai = _tanggalSelesai != null
          ? DateFormat('dd MMM yyyy').format(_tanggalSelesai!)
          : '';

      final title = 'Cuti Berhasil Diajukan ✅';
      final body =
          'Pengajuan $jenisTimeOff ($totalHari hari) telah dikirim untuk review';
      final bigText =
          'Pengajuan Cuti "$jenisTimeOff" untuk periode $tanggalMulai - $tanggalSelesai '
          '($totalHari hari) telah berhasil diajukan dan sedang dalam proses review oleh atasan.';

      final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
        bigText,
        contentTitle: title,
        summaryText: 'Status: Menunggu Persetujuan',
      );

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'timeoff_channel',
            'Time Off Notifications',
            channelDescription: 'Notifikasi untuk status pengajuan Cuti',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: bigTextStyle,
          );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        subtitle: 'Status: Menunggu Persetujuan',
        threadIdentifier: 'timeoff_thread',
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: 'timeoff_success_$timeOffId',
      );

      final dbResult = await _addNotificationToDatabase(
        userId: widget.userId,
        title: title,
        message: bigText,
        type: 'TimeOff',
        referenceId: timeOffId,
        referenceType: 'TimeOff',
        isImportant: true,
        actionText: 'Lihat Status',
        actionUrl: '/timeoff/status/$timeOffId',
      );

      if (dbResult) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat menyimpan data.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _checkNotificationPermission() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        return status.isGranted;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosPlugin != null) {
          return await iosPlugin.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              false;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_tanggalMulai ?? DateTime.now())
          : (_tanggalSelesai ?? _tanggalMulai ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _tanggalMulai = picked;
          if (_tanggalSelesai != null && _tanggalSelesai!.isBefore(picked)) {
            _tanggalSelesai = null;
          }
        } else {
          _tanggalSelesai = picked;
        }
      });
    }
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

  int _calculateDays() {
    if (_tanggalMulai != null && _tanggalSelesai != null) {
      return _tanggalSelesai!.difference(_tanggalMulai!).inDays + 1;
    }
    return 0;
  }

  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return baseFontSize * scale.clamp(0.85, 1.15);
  }

  double _getResponsivePadding(BuildContext context, double basePadding) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return basePadding * scale.clamp(0.85, 1.1);
  }

  void _showFileSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Pilih Sumber File',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.blue[600]),
                ),
                title: const Text('Ambil dari Kamera'),
                subtitle: const Text('Ambil foto langsung dari kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library, color: Colors.green[600]),
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Pilih foto dari galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.insert_drive_file,
                    color: Colors.orange[600],
                  ),
                ),
                title: const Text('Pilih dari File'),
                subtitle: const Text('Pilih file PDF atau gambar'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromFiles();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _validateAndSetFile(image);
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memilih foto dari galeri: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _validateAndSetFile(image);
      }
    } catch (e) {
      _showErrorSnackBar('Gagal mengambil foto dari kamera: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.path != null) {
          final xFile = XFile(file.path!);
          await _validateAndSetFile(xFile);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memilih file: $e');
    }
  }

  Future<void> _validateAndSetFile(XFile file) async {
    try {
      final fileData = File(file.path);
      final fileSize = await fileData.length();
      const maxSize = 10 * 1024 * 1024; // 10MB

      if (fileSize > maxSize) {
        _showErrorSnackBar('Ukuran file terlalu besar. Maksimal 10MB.');
        return;
      }

      final allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
      final fileExtension = file.path.split('.').last.toLowerCase();

      if (!allowedExtensions.contains(fileExtension)) {
        _showErrorSnackBar(
          'Format file tidak didukung. Gunakan JPG, PNG, atau PDF.',
        );
        return;
      }

      setState(() {
        _selectedImage = file;
        if (_isEditMode) {
          _keepExistingFile = false;
        }
      });

      _showSuccessSnackBar('File berhasil dipilih');
    } catch (e) {
      _showErrorSnackBar('Gagal memproses file: $e');
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildJenisSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: _jenisTimeOff.map((jenis) {
          final isSelected = _selectedJenis == jenis['value'];
          final isLast = jenis == _jenisTimeOff.last;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedJenis = jenis['value'];
              });
            },
            borderRadius: BorderRadius.vertical(
              top: jenis == _jenisTimeOff.first
                  ? const Radius.circular(12)
                  : Radius.zero,
              bottom: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3B82F6).withOpacity(0.1)
                    : Colors.transparent,
                border: !isLast
                    ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
                    : null,
              ),
              child: Row(
                children: [
                  Text(jenis['icon'], style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jenis['label'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          jenis['description'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? const Color(0xFFE5E7EB) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: enabled
                      ? (date != null
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF9CA3AF))
                      : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('dd MMM yyyy').format(date)
                        : 'Pilih tanggal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? (date != null
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF9CA3AF))
                          : const Color(0xFF9CA3AF),
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

  Widget _buildCatatanField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextFormField(
        controller: _catatanController,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Jelaskan alasan atau detail Cuti Anda...',
          hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1F2937),
          height: 1.5,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Catatan tidak boleh kosong';
          }
          if (value.trim().length < 10) {
            return 'Catatan minimal 10 karakter';
          }
          return null;
        },
      ),
    );
  }
}
