// Form Screen untuk Submit/Edit Overtime
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';

import 'package:absensikaryawan/Screen%20User/fitur/ajukanreimbursement.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/overtimeservice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OvertimeFormScreen extends StatefulWidget {
  final Overtime? overtime;

  const OvertimeFormScreen({super.key, this.overtime});

  @override
  State<OvertimeFormScreen> createState() => _OvertimeFormScreenState();
}

class _OvertimeFormScreenState extends State<OvertimeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catatanController = TextEditingController();
  final OvertimeService _overtimeService = OvertimeService();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;
  String? _userId;

  bool get isEditing => widget.overtime != null;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // If editing, fill form with existing data
    if (widget.overtime != null) {
      _selectedDate = widget.overtime!.tanggalOvertime;
      _startTime = TimeOfDay(
        hour: widget.overtime!.jamMulai.inHours,
        minute: widget.overtime!.jamMulai.inMinutes % 60,
      );
      _endTime = TimeOfDay(
        hour: widget.overtime!.jamSelesai.inHours,
        minute: widget.overtime!.jamSelesai.inMinutes % 60,
      );
      _catatanController.text = widget.overtime!.catatan ?? '';
    }
    _initializeNotifications();
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

  Future<void> _requestNotificationPermission() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
          // Permission granted
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
        if (notificationPlugin != null) {
          // Additional Android-specific setup if needed
        }
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
          const SnackBar(
            content: Text('Terjadi kesalahan saat memproses izin notifikasi.'),
          ),
        );
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'overtime_channel', // UBAH: dari 'timeoff_channel'
      'Overtime Notifications', // UBAH: dari 'Time Off Notifications'
      description:
          'Notifikasi untuk status pengajuan overtime', // UBAH: dari 'time off'
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
            'Aplikasi membutuhkan izin notifikasi untuk memberitahu Anda ketika pengajuan time off berhasil.',
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

  Future<void> _showSuccessNotification(String overtimeId) async {
    try {
      bool hasPermission = await _checkNotificationPermission();
      if (!hasPermission) {
        return;
      }

      // UBAH: variabel sesuai dengan overtime
      final totalJam = _calculateTotalHours();
      final tanggalOvertime = _selectedDate != null
          ? DateFormat('dd MMM yyyy').format(_selectedDate!)
          : '';
      final jamMulai = _startTime?.format(context) ?? '';
      final jamSelesai = _endTime?.format(context) ?? '';

      // UBAH: teks notifikasi untuk overtime
      final title = 'Overtime Berhasil Diajukan ✅';
      final body =
          'Pengajuan overtime (${totalJam.toStringAsFixed(1)} jam) telah dikirim untuk review';
      final bigText =
          'Pengajuan overtime untuk tanggal $tanggalOvertime '
          'dari jam $jamMulai - $jamSelesai '
          '(total ${totalJam.toStringAsFixed(1)} jam) telah berhasil diajukan dan sedang dalam proses review oleh atasan.';

      final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
        bigText,
        contentTitle: title,
        summaryText: 'Status: Menunggu Persetujuan',
      );

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'overtime_channel', // UBAH: dari 'timeoff_channel'
            'Overtime Notifications', // UBAH: dari 'Time Off Notifications'
            channelDescription:
                'Notifikasi untuk status pengajuan overtime', // UBAH
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
        threadIdentifier: 'overtime_thread', // UBAH: dari 'timeoff_thread'
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
        payload:
            'overtime_success_$overtimeId', // UBAH: dari 'timeoff_success_'
      );

      // UBAH: database notification untuk overtime
      final dbResult = await _addNotificationToDatabase(
        userId: _userId!, // UBAH: gunakan _userId bukan widget.userId
        title: title,
        message: bigText,
        type: 'Overtime', // UBAH: dari 'TimeOff'
        referenceId: overtimeId,
        referenceType: 'Overtime', // UBAH: dari 'TimeOff'
        isImportant: true,
        actionText: 'Lihat Status',
        actionUrl:
            '/overtime/status/$overtimeId', // UBAH: dari '/timeoff/status/'
      );

      if (dbResult) {}
    } catch (e) {
      // UBAH log message
    }
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

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('UserID');
    });
  }

  double _calculateTotalHours() {
    if (_startTime == null || _endTime == null) return 0;

    final start = Duration(
      hours: _startTime!.hour,
      minutes: _startTime!.minute,
    );
    final end = Duration(hours: _endTime!.hour, minutes: _endTime!.minute);

    var diff = end - start;
    if (diff.isNegative) {
      diff = const Duration(hours: 24) + diff;
    }

    return diff.inMinutes / 60.0;
  }

  String? _validateTimeRange() {
    if (_startTime == null || _endTime == null) return null;

    final totalHours = _calculateTotalHours();
    if (totalHours <= 0) {
      return 'Jam selesai harus lebih besar dari jam mulai';
    }
    if (totalHours > 12) {
      return 'Maksimal lembur adalah 12 jam';
    }
    return null;
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final timeError = _validateTimeRange();
    if (timeError != null) {
      _showSnackBar(timeError, isError: true);
      return;
    }

    if (_userId == null) {
      _showSnackBar('User ID tidak ditemukan', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = OvertimeRequest(
        userId: _userId!,
        tanggalOvertime: _selectedDate!,
        jamMulai: Duration(
          hours: _startTime!.hour,
          minutes: _startTime!.minute,
        ),
        jamSelesai: Duration(hours: _endTime!.hour, minutes: _endTime!.minute),
        totalJam: _calculateTotalHours(),
        catatan: _catatanController.text.trim().isEmpty
            ? null
            : _catatanController.text.trim(),
      );

      final response = isEditing
          ? await _overtimeService.updateOvertime(
              id: widget.overtime!.id,
              request: request,
            )
          : await _overtimeService.submitOvertime(request);

      _showSnackBar(response.message, isError: !response.success);

      if (response.success) {
        Navigator.pop(context, true);
        await _showSuccessNotification(response.toString());
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Lembur' : 'Ajukan Lembur',
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
              // Header Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
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
                        const Icon(
                          Icons.info_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? 'Edit Pengajuan' : 'Informasi Pengajuan',
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
                      isEditing
                          ? 'Pastikan data yang Anda ubah sudah benar. Perubahan akan direview kembali.'
                          : 'Pastikan data yang Anda masukkan sudah benar. Pengajuan akan direview oleh atasan.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    if (_calculateTotalHours() > 0) ...[
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
                              Icons.schedule_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total: ${_calculateTotalHours().toStringAsFixed(1)} jam',
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

              // Form Fields
              _buildSectionTitle(
                'Tanggal Lembur',
                Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 12),
              _buildDateField(),

              const SizedBox(height: 24),

              _buildSectionTitle('Waktu Lembur', Icons.schedule_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTimeField(isStart: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimeField(isStart: false)),
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionTitle('Catatan & Alasan', Icons.note_alt_rounded),
              const SizedBox(height: 12),
              _buildCatatanField(),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedDate != null &&
                          _startTime != null &&
                          _endTime != null &&
                          _calculateTotalHours() > 0 &&
                          !_isLoading
                      ? _submitForm
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
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
                          isEditing ? 'Update Lembur' : 'Ajukan Lembur',
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

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? now,
          firstDate: isEditing
              ? _selectedDate ?? now.subtract(const Duration(days: 30))
              : now.subtract(const Duration(days: 7)),
          lastDate: now.add(const Duration(days: 30)),
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
        if (date != null) {
          setState(() {
            _selectedDate = date;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Text(
              _selectedDate != null
                  ? DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!)
                  : 'Pilih Tanggal Lembur',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _selectedDate != null
                    ? const Color(0xFF1F2937)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({required bool isStart}) {
    final time = isStart ? _startTime : _endTime;
    final label = isStart ? 'Jam Mulai' : 'Jam Selesai';

    return InkWell(
      onTap: () async {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime:
              time ??
              (isStart
                  ? const TimeOfDay(hour: 17, minute: 0)
                  : const TimeOfDay(hour: 20, minute: 0)),
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
        if (selectedTime != null) {
          setState(() {
            if (isStart) {
              _startTime = selectedTime;
            } else {
              _endTime = selectedTime;
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isStart ? Icons.login_rounded : Icons.logout_rounded,
                  size: 18,
                  color: time != null
                      ? (isStart
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                      : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Text(
                  time?.format(context) ?? 'Pilih waktu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: time != null
                        ? const Color(0xFF1F2937)
                        : const Color(0xFF9CA3AF),
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
          hintText: 'Jelaskan alasan atau detail overtime Anda...',
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
          if (value != null && value.length > 500) {
            return 'Catatan maksimal 500 karakter';
          }
          return null;
        },
      ),
    );
  }
}
