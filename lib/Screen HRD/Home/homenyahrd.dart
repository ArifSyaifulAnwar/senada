// Screen HRD/Home/home_screen_hrd.dart — FULL REPLACE
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:absensikaryawan/Screen%20HRD/Home/overtimehrd.dart';
import 'package:absensikaryawan/Screen%20HRD/Home/reimbursementhrd.dart';
import 'package:absensikaryawan/Screen%20HRD/Home/timeoffhrd.dart';
import 'package:absensikaryawan/Screen%20User/fitur/attendance.dart';

import 'package:absensikaryawan/Screen%20admin/Home/liveattendanceadmin.dart';
import 'package:absensikaryawan/Screen%20admin/Home/notifikasiadminnya.dart';
import 'package:absensikaryawan/Screen%20admin/design/attendance_summaryadmin.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/nama.dart';
import 'package:absensikaryawan/Services/profile.dart';
import 'package:absensikaryawan/Services/face_recognition_service.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:absensikaryawan/designnya/tanggal.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_to_act/slide_to_act.dart';

import '../../Screen User/Screen HRD/hrd_calendar_screen.dart';
import '../../Screen User/fitur/org_approval_screen.dart';
import '../../Screen User/fitur/profile fitur/infoprofile.dart';
import '../../Services/notification_service.dart';
import '../notifikasi_broadcast_screen.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class HomeScreenHRD extends StatefulWidget {
  const HomeScreenHRD({super.key});
  @override
  State<HomeScreenHRD> createState() => _HomeScreenHRDState();
}

class _HomeScreenHRDState extends State<HomeScreenHRD> {
  ProfileDisplay? _profileDisplay;
  bool _isLoading = true;
  final NotificationService _notificationService = NotificationService();
  String? _errorMessage;

  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;
  bool _isLoadingAttendance = false;
  Map<String, dynamic>? _todayAttendanceData;
  String _attendanceStatusMessage = '';

  final GlobalKey<SlideActionState> _slideActionKey =
      GlobalKey<SlideActionState>();
  bool _isSlideActionProcessing = false;
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;
  String? _notificationError;
  String? userID;

  // ── Org approval count ──────────────────────────────────────────────────
  int _pendingOrgCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeUserInfo();
    _checkTodayAttendanceStatus();
    _loadUnreadNotificationCount();
  }

  Future<String?> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userID = prefs.getString('UserID');
    return userID;
  }

  Future<void> _loadPendingOrgCount() async {
    try {
      if (userID == null) await loadUserId();
      if (userID == null || userID!.isEmpty) return;
      final res = await TimeOffService.getPendingOrgReview(userID!);
      if (res.success && res.data != null && mounted) {
        setState(() => _pendingOrgCount = res.data!.length);
      }
    } catch (_) {}
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
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _isSlideActionProcessing = false;
    super.dispose();
  }

  Future<void> _loadUnreadNotificationCount() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNotifications = true;
      _notificationError = null;
    });
    try {
      if (userID == null) await loadUserId();
      if (userID == null || userID!.isEmpty) {
        setState(() => _isLoadingNotifications = false);
        return;
      }
      final result = await _notificationService.getAdminNotificationStats();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = result['unreadCount'] ?? 0;
          _isLoadingNotifications = false;
          _notificationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
          _notificationError = e.toString();
        });
      }
    }
  }

  Future<void> refreshNotificationCount() async =>
      _loadUnreadNotificationCount();

  Future<void> _checkTodayAttendanceStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingAttendance = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('UserID') ?? '';
      if (uid.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingAttendance = false;
            _attendanceStatusMessage = 'User ID tidak ditemukan';
          });
        }
        return;
      }
      final result = await FaceRecognitionService.getTodayAttendance(
        userId: uid,
      );
      if (mounted) {
        if (result['success']) {
          final data = result['data'];
          setState(() {
            _todayAttendanceData = data;
            if (data != null) {
              _hasCheckedIn = data['CheckInTime'] != null;
              _hasCheckedOut = data['CheckOutTime'] != null;
              _attendanceStatusMessage = _hasCheckedOut
                  ? 'Anda sudah check out hari ini'
                  : _hasCheckedIn
                  ? 'Siap untuk check out'
                  : 'Siap untuk check in';
            } else {
              _hasCheckedIn = false;
              _hasCheckedOut = false;
              _attendanceStatusMessage = 'Siap untuk check in';
            }
            _isLoadingAttendance = false;
          });
        } else {
          setState(() {
            _hasCheckedIn = false;
            _hasCheckedOut = false;
            _isLoadingAttendance = false;
            _attendanceStatusMessage =
                result['message'] ?? 'Gagal mengambil status absensi';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAttendance = false;
          _attendanceStatusMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  void _safeSetState(VoidCallback cb) {
    if (mounted) setState(cb);
  }

  Future<void> _initializeUserInfo() async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final token = await _getToken();
      if (token != null) {
        await _loadProfileData();
        await loadUserId();
        await _loadPendingOrgCount();
      } else {
        _safeSetState(() {
          _errorMessage = 'Gagal mendapatkan token akses';
          _isLoading = false;
        });
      }
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Error saat inisialisasi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email');
      if (email == null) {
        _safeSetState(() {
          _errorMessage = 'Email tidak ditemukan';
          _isLoading = false;
        });
        return;
      }
      final accessToken = await _getToken();
      if (accessToken == null) {
        _safeSetState(() {
          _errorMessage = 'Gagal mendapatkan access token';
          _isLoading = false;
        });
        return;
      }
      final userResponse = await http.post(
        Uri.parse('$baseURL/api/asn/getDataUser'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );
      if (!mounted) return;
      if (userResponse.statusCode == 200) {
        final rj = json.decode(userResponse.body);
        if (rj['data'] != null) {
          _safeSetState(() {
            _profileDisplay = ProfileDisplay.fromJson(rj);
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          _safeSetState(() {
            _errorMessage = 'Data user tidak ditemukan';
            _isLoading = false;
          });
        }
      } else {
        _safeSetState(() {
          _errorMessage = 'Error API: ${userResponse.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAttendanceAction() async {
    if (_isSlideActionProcessing) return;
    try {
      _isSlideActionProcessing = true;
      if (_hasCheckedOut) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah melakukan check out hari ini'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AbsensiScreen(isCheckOut: _hasCheckedIn, showBackButton: true),
        ),
      );
      if (mounted && (result == true || result != null)) {
        await _checkTodayAttendanceStatus();
        _safeResetSlider();
      } else if (mounted)
        _safeResetSlider();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isSlideActionProcessing = false;
    }
  }

  void _safeResetSlider() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted &&
          _slideActionKey.currentState != null &&
          _slideActionKey.currentState!.mounted) {
        try {
          _slideActionKey.currentState?.reset();
        } catch (_) {}
      }
    });
  }

  Future<void> refreshAttendanceStatus() async {
    if (mounted) await _checkTodayAttendanceStatus();
  }

  Color _getSliderColor() {
    if (_hasCheckedOut) return Colors.grey;
    if (_hasCheckedIn) return const Color(0xFFFC8980);
    return Colors.blue;
  }

  String _getSliderText() {
    if (_isLoadingAttendance) return 'Memuat status...';
    if (_hasCheckedOut) return 'Anda sudah check out hari ini';
    if (_hasCheckedIn) return 'Geser untuk Check Out';
    return 'Geser untuk Check In';
  }

  IconData _getSliderIcon() {
    if (_hasCheckedOut) return Icons.check_circle;
    if (_hasCheckedIn) return Icons.logout;
    return Icons.login;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final bool isWeb = _isWideScreen(context);
    const double baseWidth = 375, baseHeight = 812;
    final double scale = isWeb
        ? 1.0
        : ((screenWidth / baseWidth) + (screenHeight / baseHeight)) / 2;
    final double horizontalPadding = isWeb ? 32 : screenWidth * 0.04;
    final double verticalPadding = isWeb ? 24 : screenHeight * 0.02;
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final double slideButtonBottomPadding = bottomSafeArea > 0
        ? bottomSafeArea + 16
        : 40;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: isWeb
            ? _buildWebLayout(scale, horizontalPadding, verticalPadding)
            : _buildMobileLayout(
                scale,
                horizontalPadding,
                verticalPadding,
                slideButtonBottomPadding,
              ),
      ),
    );
  }

  Widget _buildMobileLayout(
    double scale,
    double hPad,
    double vPad,
    double slidePad,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSection(scale, hPad),
                SizedBox(height: 20 * scale),
                _buildAttendanceStatusInfo(scale),
                SizedBox(height: 20 * scale),
                const TanggalanHorizontal(),
                SizedBox(height: 20 * scale),
                const AttendanceSummaryAdmin(),
                SizedBox(height: 20 * scale),
                _buildServiceIconsSection(scale),
                SizedBox(height: 20 * scale),
                _buildActivitiesSection(scale),
                SizedBox(height: 20 * scale),
                _buildTasksAndTimesheetSection(scale),
              ],
            ),
          ),
        ),
        _buildSlideButton(scale, hPad, slidePad),
      ],
    );
  }

  Widget _buildWebLayout(double scale, double hPad, double vPad) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSection(scale, 0),
                        const SizedBox(height: 16),
                        _buildAttendanceStatusInfo(scale),
                        const SizedBox(height: 16),
                        _buildActivitiesSection(scale),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: _buildSlideButton(scale, 20, 20),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TanggalanHorizontal(),
                const SizedBox(height: 16),
                const AttendanceSummaryAdmin(),
                const SizedBox(height: 16),
                _buildServiceIconsSection(scale),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTasksSection(scale)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTimesheetSection(scale)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlideButton(double scale, double hPad, double bottomPad) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, bottomPad),
      child: Column(
        children: [
          if (_attendanceStatusMessage.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: Text(
                _attendanceStatusMessage,
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          SlideAction(
            key: _slideActionKey,
            onSubmit: (_hasCheckedOut || _isSlideActionProcessing)
                ? null
                : () async {
                    if (_isSlideActionProcessing) return null;
                    try {
                      await _handleAttendanceAction();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Terjadi kesalahan: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                    return null;
                  },
            sliderButtonIcon: Icon(_getSliderIcon(), color: Colors.white),
            innerColor: _getSliderColor(),
            outerColor: _getSliderColor().withOpacity(0.2),
            elevation: _hasCheckedOut ? 1 : 4,
            text: _getSliderText(),
            textStyle: TextStyle(
              color: _hasCheckedOut
                  ? Colors.grey[600]
                  : (_hasCheckedIn ? Colors.white : _getSliderColor()),
              fontWeight: FontWeight.bold,
              fontSize: 16 * scale,
            ),
            height: screenHeight * 0.07,
            borderRadius: 12,
            enabled:
                !_hasCheckedOut &&
                !_isLoadingAttendance &&
                !_isSlideActionProcessing,
          ),
        ],
      ),
    );
  }

  // ── Notification icon (sama dengan asli) ─────────────────────────────────

  Widget _buildNotificationIcon(double scale) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final iconSize = 28.0 * scale;
    final badgeSize = isSmall ? 16.0 * scale : 18.0 * scale;
    final badgeFontSize = isSmall ? 9.0 * scale : 10.0 * scale;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.notifications_none,
              color: Colors.grey[800],
              size: iconSize,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HalamanNotifikasiAdmin(),
                ),
              );
              await refreshNotificationCount();
            },
          ),
          if (_unreadNotificationCount > 0)
            Positioned(
              right: (48 - iconSize) / 2 - (badgeSize * 0.3),
              top: (48 - iconSize) / 2 - (badgeSize * 0.3),
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(badgeSize / 2),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _unreadNotificationCount > 99
                        ? '99+'
                        : _unreadNotificationCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          if (_isLoadingNotifications)
            Positioned(
              right: (48 - iconSize) / 2 - (badgeSize * 0.3),
              top: (48 - iconSize) / 2 - (badgeSize * 0.3),
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(badgeSize / 2),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Padding(
                  padding: EdgeInsets.all(badgeSize * 0.2),
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          if (_notificationError != null &&
              !_isLoadingNotifications &&
              _unreadNotificationCount == 0)
            Positioned(
              right: (48 - iconSize) / 2 - (badgeSize * 0.3),
              top: (48 - iconSize) / 2 - (badgeSize * 0.3),
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(badgeSize / 2),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: badgeSize * 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(double scale, double hPad) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(4 * scale),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.lightBlue.shade200,
              width: 2 * scale,
            ),
          ),
          child: CircleAvatar(
            radius: 28 * scale,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _profileDisplay?.fotoProfil != null
                ? MemoryImage(_profileDisplay!.fotoProfil!)
                : null,
            child: _profileDisplay?.fotoProfil == null
                ? Icon(Icons.person, size: 28 * scale, color: Colors.grey[600])
                : null,
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                Text(
                  'Memuat...',
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                )
              else if (_errorMessage != null)
                Text(
                  'Error loading data',
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                )
              else
                NamaDisplay(
                  nama: _profileDisplay?.displayName ?? 'Nama tidak tersedia',
                  scale: scale,
                ),
              SizedBox(height: 4 * scale),
              Text(
                _isLoading
                    ? 'Memuat...'
                    : (_profileDisplay?.jobs ?? 'Pekerjaan tidak tersedia'),
                style: TextStyle(fontSize: 12 * scale, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        _buildNotificationIcon(scale),
      ],
    );
  }

  Widget _buildAttendanceStatusInfo(double scale) {
    if (_isLoadingAttendance) {
      return Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20 * scale,
              height: 20 * scale,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Text(
                'Memuat status attendance...',
                style: TextStyle(
                  fontSize: 14 * scale,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_todayAttendanceData != null) {
      return Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: _hasCheckedOut
              ? Colors.green.shade50
              : (_hasCheckedIn ? Colors.orange.shade50 : Colors.blue.shade50),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
            color: _hasCheckedOut
                ? Colors.green.shade200
                : (_hasCheckedIn
                      ? Colors.orange.shade200
                      : Colors.blue.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasCheckedOut
                      ? Icons.check_circle
                      : (_hasCheckedIn ? Icons.access_time : Icons.schedule),
                  color: _hasCheckedOut
                      ? Colors.green.shade700
                      : (_hasCheckedIn
                            ? Colors.orange.shade700
                            : Colors.blue.shade700),
                  size: 20 * scale,
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    _hasCheckedOut
                        ? 'Attendance Hari Ini Lengkap'
                        : (_hasCheckedIn ? 'Sudah Check In' : 'Belum Check In'),
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
                      color: _hasCheckedOut
                          ? Colors.green.shade700
                          : (_hasCheckedIn
                                ? Colors.orange.shade700
                                : Colors.blue.shade700),
                    ),
                  ),
                ),
              ],
            ),
            if (_hasCheckedIn) ...[
              SizedBox(height: 8 * scale),
              Row(
                children: [
                  Text(
                    'Check In: ',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    _formatTime(_todayAttendanceData!['CheckInTime']),
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (_todayAttendanceData!['CheckInStatus'] != null) ...[
                    Text(' • ', style: TextStyle(color: Colors.grey[600])),
                    Text(
                      _formatStatus(_todayAttendanceData!['CheckInStatus']),
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(
                          _todayAttendanceData!['CheckInStatus'],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (_hasCheckedOut) ...[
              SizedBox(height: 4 * scale),
              Row(
                children: [
                  Text(
                    'Check Out: ',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    _formatTime(_todayAttendanceData!['CheckOutTime']),
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (_todayAttendanceData!['CheckOutStatus'] != null) ...[
                    Text(' • ', style: TextStyle(color: Colors.grey[600])),
                    Text(
                      _formatStatus(_todayAttendanceData!['CheckOutStatus']),
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(
                          _todayAttendanceData!['CheckOutStatus'],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Service icons section (dengan OrgApproval) ────────────────────────────

  Widget _buildServiceIconsSection(double scale) {
    final bool isWeb = _isWideScreen(context);

    final firstRow = [
      _buildServiceIconData(
        Icons.receipt_long,
        'Reimbursement',
        const Color(0xFF4ECDC4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HalamanHRDReimbursement()),
        ),
      ),
      _buildServiceIconData(
        Icons.calendar_today,
        'Kalender',
        const Color(0xFF007AFF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HrdCalendarScreen()),
        ),
      ),
      _buildServiceIconData(
        Icons.schedule,
        'Izin',
        const Color(0xFF007AFF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TimeOffHRDScreen()),
        ),
      ),
      _buildServiceIconData(
        Icons.location_on,
        'Absensi',
        const Color(0xFFFF9500),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LiveAttendanceScreenAdmin()),
        ),
      ),
    ];

    final secondRow = [
      _buildServiceIconData(
        Icons.access_time_filled,
        'Lembur',
        const Color(0xFFFF6B35),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OvertimeHRDScreen()),
        ),
      ),
      _buildServiceIconData(
        Icons.folder_open,
        'File Saya',
        const Color(0xFFFFCC02),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InfoProfileScreen(initialTabIndex: 2),
          ),
        ),
      ),
      _buildServiceIconData(
        Icons.campaign_rounded,
        'Broadcast',
        const Color(0xFF6366F1),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BroadcastNotifScreen()),
        ),
      ),
      // ── BARU: Persetujuan Divisi ──────────────────────────────────────────
      _buildServiceIconData(
        Icons.groups_rounded,
        'Persetujuan\nDivisi',
        const Color(0xFF0EA5E9),
        badge: _pendingOrgCount,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrgApprovalScreen(
                userId: _profileDisplay?.userId ?? userID ?? '',
              ),
            ),
          );
          _loadPendingOrgCount();
        },
      ),
      _buildServiceIconData(
        Icons.event,
        'Acara',
        const Color(0xFF795548),
        onTap: () => _showComingSoonDialog(context),
      ),
      _buildServiceIconData(
        Icons.inventory,
        'Asset',
        const Color(0xFF607D8B),
        onTap: () => _showComingSoonDialog(context),
      ),
    ];

    final allServices = [...firstRow, ...secondRow];

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Layanan',
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16 * scale),
          if (isWeb)
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: allServices.map((s) {
                return GestureDetector(
                  onTap: s.onTap,
                  child: SizedBox(
                    width: 90,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: s.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(s.icon, size: 24, color: s.color),
                            ),
                            if (s.badge != null && s.badge! > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    s.badge! > 99 ? '99+' : '${s.badge}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          else
            SizedBox(
              height: 176 * scale,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    Row(
                      children: firstRow
                          .map(
                            (s) => Container(
                              width: 70 * scale,
                              height: 80 * scale,
                              margin: EdgeInsets.only(right: 12 * scale),
                              child: _buildServiceIconMobile(s, scale),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: 16 * scale),
                    Row(
                      children: secondRow
                          .map(
                            (s) => Container(
                              width: 70 * scale,
                              height: 80 * scale,
                              margin: EdgeInsets.only(right: 12 * scale),
                              child: _buildServiceIconMobile(s, scale),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceIconMobile(ServiceIconData s, double scale) {
    return GestureDetector(
      onTap: s.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: 45 * scale,
                  height: 45 * scale,
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Icon(s.icon, size: 22 * scale, color: s.color),
                ),
                if (s.badge != null && s.badge! > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        s.badge! > 99 ? '99+' : '${s.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 6 * scale),
          Flexible(
            flex: 2,
            child: Text(
              s.label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 10 * scale,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesSection(double scale) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aktivitas Anda Hari Ini',
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          if (_isLoadingAttendance)
            const Center(child: CircularProgressIndicator())
          else if (_todayAttendanceData != null)
            Column(
              children: [
                if (_hasCheckedIn)
                  _buildActivityItem(
                    icon: Icons.login,
                    title: 'Check In',
                    date: DateTime.now().toString(),
                    time: _formatTime(_todayAttendanceData!['CheckInTime']),
                    status: _formatStatus(
                      _todayAttendanceData!['CheckInStatus'],
                    ),
                    scale: scale,
                    statusColor: _getStatusColor(
                      _todayAttendanceData!['CheckInStatus'],
                    ),
                  ),
                if (_hasCheckedIn && _hasCheckedOut)
                  SizedBox(height: 12 * scale),
                if (_hasCheckedOut)
                  _buildActivityItem(
                    icon: Icons.logout,
                    title: 'Check Out',
                    date: DateTime.now().toString(),
                    time: _formatTime(_todayAttendanceData!['CheckOutTime']),
                    status: _formatStatus(
                      _todayAttendanceData!['CheckOutStatus'],
                    ),
                    scale: scale,
                    statusColor: _getStatusColor(
                      _todayAttendanceData!['CheckOutStatus'],
                    ),
                  ),
                if (!_hasCheckedIn)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 48 * scale,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          'Belum ada aktivitas',
                          style: TextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          'Silakan lakukan check in untuk memulai',
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 48 * scale,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTasksAndTimesheetSection(double scale) => Column(
    children: [
      _buildTasksSection(scale),
      SizedBox(height: 12 * scale),
      _buildTimesheetSection(scale),
    ],
  );

  Widget _buildTasksSection(double scale) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tugas',
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 12 * scale, color: Colors.blue),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 48 * scale,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 8 * scale),
                Text(
                  'Tidak ada tugas',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  'Anda tidak memiliki tugas yang tertunda',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetSection(double scale) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Timesheet',
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Ke Time Tracker',
                  style: TextStyle(fontSize: 12 * scale, color: Colors.blue),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 48 * scale,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 8 * scale),
                Text(
                  'Tidak ada timesheet',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  'Setelah Anda mengisi timesheet, akan muncul di sini.',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String date,
    required String time,
    required String status,
    required double scale,
    Color? statusColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Icon(icon, color: Colors.blue, size: 20 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  'Hari ini • $time',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8 * scale,
              vertical: 4 * scale,
            ),
            decoration: BoxDecoration(
              color: (statusColor ?? Colors.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10 * scale,
                color: statusColor ?? Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
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
  }

  String _formatTime(String? ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.parse(ts);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  String _formatStatus(String? s) {
    switch (s) {
      case 'on_time':
        return 'Tepat Waktu';
      case 'late':
        return 'Terlambat';
      case 'very_late':
        return 'Sangat Terlambat';
      case 'early':
        return 'Pulang Awal';
      case 'overtime':
        return 'Lembur';
      default:
        return s ?? '-';
    }
  }

  Color _getStatusColor(String? s) {
    switch (s) {
      case 'on_time':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'very_late':
        return Colors.red;
      case 'early':
        return Colors.blue;
      case 'overtime':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void refreshPage() {
    if (mounted) _checkTodayAttendanceStatus();
  }
}

class ServiceIconData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final int? badge;
  ServiceIconData({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.badge,
  });
}

ServiceIconData _buildServiceIconData(
  IconData icon,
  String label,
  Color color, {
  VoidCallback? onTap,
  int? badge,
}) => ServiceIconData(
  icon: icon,
  label: label,
  color: color,
  onTap: onTap,
  badge: badge,
);
