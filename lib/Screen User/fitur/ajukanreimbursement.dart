// HalamanAjukanReimbursement - Perbaikan dengan integrasi notifikasi database
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/reimbursementmodel.dart';
import 'package:absensikaryawan/Services/reimbursementservice.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HalamanAjukanReimbursement extends StatefulWidget {
  const HalamanAjukanReimbursement({super.key});

  @override
  _HalamanAjukanReimbursementState createState() =>
      _HalamanAjukanReimbursementState();
}

class _HalamanAjukanReimbursementState
    extends State<HalamanAjukanReimbursement> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  final ReimbursementService _reimbursementService = ReimbursementService();

  String _selectedCategory = '';
  List<ReimbursementCategory> _categories = [];
  XFile? _selectedImage;
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;
  String? _currentUserId;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadUserData();
    _loadCategories();
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

  // =============================================
  // NOTIFICATION INITIALIZATION
  // =============================================

  Future<void> _initializeNotifications() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
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
      'reimbursement_channel',
      'Reimbursement Notifications',
      description: 'Notifikasi untuk status reimbursement',
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
    if (payload != null) {
      // Navigate to reimbursement status page if needed
    }
  }

  // =============================================
  // DATABASE NOTIFICATION INTEGRATION
  // =============================================

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
        if (responseData['success'] == true) {
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // =============================================
  // IMPROVED SUCCESS NOTIFICATION
  // =============================================

  Future<void> _showSuccessNotification(String reimbursementId) async {
    try {
      // Check permission first
      bool hasPermission = await _checkNotificationPermission();
      if (!hasPermission) {
        return;
      }

      // Get amount for notification
      final amountText = _jumlahController.text.replaceAll(',', '');
      final amount = double.tryParse(amountText) ?? 0;
      final formattedAmount = _formatCurrency(amount);

      // Prepare notification content
      final title = 'Reimbursement Berhasil Diajukan ✅';
      final body = 'Pengajuan Rp $formattedAmount telah dikirim untuk review';
      final bigText =
          'Pengajuan reimbursement "${_judulController.text}" sebesar Rp $formattedAmount telah berhasil diajukan dan sedang dalam proses review oleh tim finance. Anda akan mendapat notifikasi ketika status berubah.';

      // Create notification details
      final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
        bigText,
        contentTitle: title,
        summaryText: 'Status: Menunggu Persetujuan',
      );

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'reimbursement_channel',
            'Reimbursement Notifications',
            channelDescription: 'Notifikasi untuk status reimbursement',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: bigTextStyle,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'view_status',
                'Lihat Status',
                showsUserInterface: true,
              ),
            ],
          );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        subtitle: 'Status: Menunggu Persetujuan',
        threadIdentifier: 'reimbursement_thread',
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show local notification
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: 'reimbursement_success_$reimbursementId',
      );

      // Add notification to database
      final dbResult = await _addNotificationToDatabase(
        userId: _currentUserId!,
        title: title,
        message: bigText,
        type: 'reimbursement',
        referenceId: reimbursementId,
        referenceType: 'reimbursement',
        isImportant: true,
        actionText: 'Lihat Status',
        actionUrl: '/reimbursement/status/$reimbursementId',
      );

      if (dbResult) {
      } else {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal.'),
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

  // =============================================
  // IMPROVED SUBMIT FORM
  // =============================================

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      _showErrorSnackBar('Harap upload bukti pembayaran');
      return;
    }

    if (_currentUserId == null) {
      _showErrorSnackBar('User ID tidak ditemukan');
      return;
    }

    if (_selectedDate == null) {
      _showErrorSnackBar('Harap pilih tanggal pengeluaran');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final amountText = _jumlahController.text.replaceAll(',', '');
      final amount = double.tryParse(amountText);

      if (amount == null || amount <= 0) {
        throw Exception('Jumlah tidak valid');
      }

      // Submit reimbursement
      final response = await _reimbursementService.submitReimbursement(
        userId: _currentUserId!,
        title: _judulController.text.trim(),
        category: _selectedCategory,
        amount: amount,
        expenseDate: _selectedDate!,
        description: _keteranganController.text.trim().isEmpty
            ? null
            : _keteranganController.text.trim(),
        receiptFile: File(_selectedImage!.path),
        status: 'pending',
      );

      setState(() {
        _isSubmitting = false;
      });

      if (response.success) {
        // Show success notification (both local and database)
        if (response.reimbursementId != null) {
          await _showSuccessNotification(response.reimbursementId.toString());
        }

        // Show success snackbar
        _showSuccessSnackBar(response.message);

        // Navigate back with success result
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  // =============================================
  // PERMISSION HANDLING
  // =============================================

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

        // Request additional permission for Android 13+
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
            content: Text('Gagal.'),
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
            'Aplikasi membutuhkan izin notifikasi untuk memberitahu Anda ketika pengajuan reimbursement berhasil. '
            'Silakan berikan izin notifikasi agar Anda tidak melewatkan informasi penting.',
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

  // =============================================
  // HELPER METHODS
  // =============================================

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    return formatter.format(amount).replaceAll(',', '.');
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('UserID');
    if (_currentUserId == null) {
      _showErrorSnackBar('User ID tidak ditemukan');
      Navigator.pop(context);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _reimbursementService.getCategories();
      setState(() {
        _categories = categories;
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first.name;
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      _showErrorSnackBar('Gagal memuat kategori');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // =============================================
  // FILE HANDLING METHODS
  // =============================================

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _tanggalController.text = DateFormat('dd MMMM yyyy').format(picked);
      });
    }
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

          final String fileExtension = file.extension?.toLowerCase() ?? '';
          if (fileExtension == 'pdf') {
          } else {}
        } else {}
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
      });
    } catch (e) {
      _showErrorSnackBar('Gagal memproses file: $e');
    }
  }

  void _removeFile() {
    setState(() {
      _selectedImage = null;
    });
    _showSuccessSnackBar('File berhasil dihapus. Silakan pilih file baru.');
  }

  // =============================================
  // VALIDATION METHODS
  // =============================================

  String? _validateJudul(String? value) {
    if (value == null || value.isEmpty) {
      return 'Judul tidak boleh kosong';
    }
    if (value.length < 5) {
      return 'Judul terlalu pendek (minimal 5 karakter)';
    }
    if (value.length > 255) {
      return 'Judul terlalu panjang (maksimal 255 karakter)';
    }
    return null;
  }

  String? _validateJumlah(String? value) {
    if (value == null || value.isEmpty) {
      return 'Jumlah tidak boleh kosong';
    }

    final cleanValue = value.replaceAll(',', '');
    if (double.tryParse(cleanValue) == null) {
      return 'Masukkan angka yang valid';
    }

    final amount = double.parse(cleanValue);
    if (amount <= 0) {
      return 'Jumlah harus lebih dari 0';
    }
    if (amount > 999999999) {
      return 'Jumlah terlalu besar';
    }
    return null;
  }

  bool _isFormValid() {
    return _formKey.currentState?.validate() == true &&
        _selectedImage != null &&
        _selectedDate != null &&
        _selectedCategory.isNotEmpty;
  }

  // =============================================
  // UI HELPER METHODS
  // =============================================

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

  InputDecoration _buildModernInputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(
        horizontal: _getResponsivePadding(context, 20),
        vertical: _getResponsivePadding(context, 16),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: const Color(0xFF3B82F6), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[400]!, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: _getResponsiveFontSize(context, 14),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontSize: _getResponsiveFontSize(context, 14),
      ),
      errorStyle: TextStyle(
        color: Colors.red[600],
        fontSize: _getResponsiveFontSize(context, 12),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // =============================================
  // UI COMPONENTS
  // =============================================

  Widget _buildCategoryDropdown() {
    if (_isLoadingCategories) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[100],
        ),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_categories.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[100],
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Center(
          child: Text(
            'Gagal memuat kategori',
            style: TextStyle(color: Colors.red[600]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory.isEmpty ? null : _selectedCategory,
        decoration: _buildModernInputDecoration(
          labelText: 'Kategori',
          prefixIcon: Icon(
            Icons.category_outlined,
            color: Colors.grey[600],
            size: 20,
          ),
        ),
        items: _categories.map((ReimbursementCategory category) {
          return DropdownMenuItem<String>(
            value: category.name,
            child: Text(
              category.name,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedCategory = newValue ?? '';
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Pilih kategori';
          }
          return null;
        },
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildFilePreview() {
    if (_selectedImage == null) {
      return GestureDetector(
        onTap: () => _showFileSourceOptions(context),
        child: Container(
          margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 16)),
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 2),
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.upload_file_outlined,
                  size: 28,
                  color: Colors.grey[500],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Belum ada file dipilih',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: _getResponsiveFontSize(context, 13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String fileName = _selectedImage!.path.split('/').last;
    final String fileExtension = fileName.split('.').last.toLowerCase();
    final bool isImage = ['jpg', 'jpeg', 'png'].contains(fileExtension);

    return Container(
      margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 16)),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green[300]!, width: 2),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File berhasil dipilih',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: _getResponsiveFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red[600], size: 18),
                  onPressed: _removeFile,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
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
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
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
                      SizedBox(height: 2),
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

  void _showFileSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Ambil dari Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text('Pilih dari File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromFiles();
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
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
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(fileIcon, size: 40, color: iconColor),
          ),
          SizedBox(height: 12),
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

  // Widget _buildUploadOptionButton({
  //   required IconData icon,
  //   required String label,
  //   required String subtitle,
  //   required MaterialColor color,
  //   required VoidCallback onTap,
  // }) {
  //   return InkWell(
  //     onTap: onTap,
  //     borderRadius: BorderRadius.circular(12),
  //     child: Container(
  //       padding: EdgeInsets.symmetric(
  //         vertical: _getResponsivePadding(context, 16),
  //         horizontal: _getResponsivePadding(context, 8),
  //       ),
  //       decoration: BoxDecoration(
  //         color: color[50],
  //         border: Border.all(color: color[200]!, width: 1.5),
  //         borderRadius: BorderRadius.circular(12),
  //       ),
  //       child: Column(
  //         children: [
  //           Container(
  //             padding: EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: color[100],
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //             child: Icon(icon, color: color[600], size: 24),
  //           ),
  //           SizedBox(height: 8),
  //           Text(
  //             label,
  //             style: TextStyle(
  //               fontWeight: FontWeight.w600,
  //               fontSize: _getResponsiveFontSize(context, 13),
  //               color: color[700],
  //             ),
  //           ),
  //           SizedBox(height: 2),
  //           Text(
  //             subtitle,
  //             style: TextStyle(
  //               fontSize: _getResponsiveFontSize(context, 10),
  //               color: color[600],
  //               fontWeight: FontWeight.w500,
  //             ),
  //             textAlign: TextAlign.center,
  //             maxLines: 1,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  String _getFileInfo() {
    if (_selectedImage == null) return '';

    final String fileName = _selectedImage!.path.split('/').last;
    final String fileExtension = fileName.split('.').last.toLowerCase();

    switch (fileExtension) {
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

  // =============================================
  // MAIN BUILD METHOD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Ajukan Reimbursement',
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
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black87,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _judulController,
                        decoration: _buildModernInputDecoration(
                          labelText: 'Judul Pengajuan',
                          hintText: 'Contoh: Biaya transportasi ke klien',
                          prefixIcon: Icon(
                            Icons.title_outlined,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),
                        validator: _validateJudul,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                    SizedBox(height: _getResponsivePadding(context, 16)),

                    // Category Dropdown
                    _buildCategoryDropdown(),
                    SizedBox(height: _getResponsivePadding(context, 16)),

                    // Amount Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _jumlahController,
                        decoration: _buildModernInputDecoration(
                          labelText: 'Jumlah (Rp)',
                          hintText: 'Masukkan nominal',
                          prefixIcon: Icon(
                            Icons.payments_outlined,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          NumberInputFormatter(),
                        ],
                        validator: _validateJumlah,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                    SizedBox(height: _getResponsivePadding(context, 16)),

                    // Date Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _tanggalController,
                        decoration: _buildModernInputDecoration(
                          labelText: 'Tanggal Pengeluaran',
                          prefixIcon: Icon(
                            Icons.event_outlined,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          suffixIcon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey[600],
                          ),
                        ),
                        readOnly: true,
                        onTap: _selectDate,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih tanggal pengeluaran';
                          }
                          return null;
                        },
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: _getResponsivePadding(context, 16)),

                    // Description Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _keteranganController,
                        decoration: _buildModernInputDecoration(
                          labelText: 'Keterangan (Opsional)',
                          hintText: 'Tambahkan keterangan jika perlu',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Icon(
                              Icons.notes_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        ),
                        maxLines: 3,
                        maxLength: 500,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: _getResponsivePadding(context, 24)),

                    // File Upload Section
                    Container(
                      padding: EdgeInsets.all(
                        _getResponsivePadding(context, 16),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.upload_file_outlined,
                                color: const Color(0xFF3B82F6),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Bukti Pembayaran',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: _getResponsiveFontSize(context, 16),
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Wajib',
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(
                                      context,
                                      10,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),

                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue[600],
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Format yang didukung: JPG, PNG, PDF (Maks 10MB)',
                                    style: TextStyle(
                                      fontSize: _getResponsiveFontSize(
                                        context,
                                        12,
                                      ),
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: _getResponsivePadding(context, 16)),

                          _buildFilePreview(),

                          // Text(
                          //   'Pilih sumber file:',
                          //   style: TextStyle(
                          //     fontSize: _getResponsiveFontSize(context, 14),
                          //     fontWeight: FontWeight.w600,
                          //     color: Colors.grey[700],
                          //   ),
                          // ),
                          // SizedBox(height: 12),

                          // Row(
                          //   children: [
                          //     Expanded(
                          //       child: _buildUploadOptionButton(
                          //         icon: Icons.camera_alt_outlined,
                          //         label: 'Kamera',
                          //         subtitle: 'Ambil Foto',
                          //         color: Colors.green,
                          //         onTap: _pickFromCamera,
                          //       ),
                          //     ),
                          //     SizedBox(width: 8),
                          //     Expanded(
                          //       child: _buildUploadOptionButton(
                          //         icon: Icons.photo_library_outlined,
                          //         label: 'Galeri',
                          //         subtitle: 'Pilih Foto',
                          //         color: Colors.blue,
                          //         onTap: _pickFromGallery,
                          //       ),
                          //     ),
                          //     SizedBox(width: 8),
                          //     Expanded(
                          //       child: _buildUploadOptionButton(
                          //         icon: Icons.folder_outlined,
                          //         label: 'File',
                          //         subtitle: 'PDF & Foto',
                          //         color: Colors.orange,
                          //         onTap: _pickFromFiles,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          // SizedBox(height: 16),
                          if (_selectedImage != null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _removeFile,
                                icon: Icon(Icons.refresh_outlined, size: 18),
                                label: Text(
                                  'Ganti File',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[100],
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: _getResponsivePadding(
                                      context,
                                      12,
                                    ),
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
                    ),
                    SizedBox(height: _getResponsivePadding(context, 32)),

                    // Submit Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: _isSubmitting || !_isFormValid()
                              ? [Colors.grey[300]!, Colors.grey[400]!]
                              : [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF2563EB),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: _isSubmitting || !_isFormValid()
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting || !_isFormValid()
                            ? null
                            : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Mengirim...',
                                    style: TextStyle(
                                      fontSize: _getResponsiveFontSize(
                                        context,
                                        16,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Ajukan Reimbursement',
                                    style: TextStyle(
                                      fontSize: _getResponsiveFontSize(
                                        context,
                                        16,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: _getResponsivePadding(context, 20)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _judulController.dispose();
    _jumlahController.dispose();
    _tanggalController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }
}

// =============================================
// HELPER CLASSES
// =============================================

class NumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String cleanedText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final formatter = NumberFormat("#,###");
    String formattedText = formatter.format(int.parse(cleanedText));

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
