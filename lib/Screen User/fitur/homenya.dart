// ignore_for_file: unused_local_variable, unused_element, unused_field, deprecated_member_use, use_build_context_synchronously
import 'dart:convert';
import 'package:absensikaryawan/Screen%20User/fitur/attendance.dart';
import 'package:absensikaryawan/Screen%20User/fitur/liveattendance.dart';
import 'package:absensikaryawan/Screen%20User/fitur/notifikasi.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/infoprofile.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/reimbursement.dart';
import 'package:absensikaryawan/Screen%20User/home/overtime.dart';
import 'package:absensikaryawan/Screen%20User/home/timeoff.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/nama.dart';
import 'package:absensikaryawan/Services/profile.dart';
import 'package:absensikaryawan/Services/face_recognition_service.dart';
import 'package:absensikaryawan/designnya/attendance_summary.dart';
import 'package:absensikaryawan/designnya/tanggal.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'profile fitur/halaman_calendar.dart';
bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen> {
  ProfileDisplay? _profileDisplay;
  String? _accessToken;
  bool _isLoading = true;
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
  bool _debugShowTestBadge = false;
  String? userID;

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

  void _debugTestNotificationBadge() {
    setState(() {
      _unreadNotificationCount = 5;
      _debugShowTestBadge = true;
    });
  }

  @override
  void dispose() {
    _isSlideActionProcessing = false;
    super.dispose();
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

  Future<void> _loadUnreadNotificationCount() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNotifications = true;
      _notificationError = null;
    });
    try {
      String? currentToken = _accessToken ?? await _getToken();
      if (currentToken == null) throw Exception('Failed to get access token');
      if (userID == null) await loadUserId();
      if (userID == null || userID!.isEmpty) {
        throw Exception('User ID not found');
      }

      final response = await http
          .post(
            Uri.parse('$baseURL/api/notification/unread-count'),
            headers: {
              'Authorization': 'Bearer $currentToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({"UserId": userID}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['Success'] == true) {
            setState(() {
              _unreadNotificationCount = data['Data']['UnreadCount'] ?? 0;
              _isLoadingNotifications = false;
              _notificationError = null;
            });
          } else {
            setState(() {
              _isLoadingNotifications = false;
              _notificationError = data['Message'] ?? 'Unknown error';
            });
          }
        } else if (response.statusCode == 401) {
          final newToken = await _getToken();
          if (newToken != null && mounted) {
            await _loadUnreadNotificationCount();
          } else {
            setState(() {
              _isLoadingNotifications = false;
              _notificationError = 'Authentication failed';
            });
          }
        } else {
          setState(() {
            _isLoadingNotifications = false;
            _notificationError = 'HTTP Error: ${response.statusCode}';
          });
        }
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

  Future<void> refreshNotificationCount() async {
    await _loadUnreadNotificationCount();
  }

  Future<void> _checkTodayAttendanceStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingAttendance = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID') ?? '';
      if (userId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingAttendance = false;
            _attendanceStatusMessage = 'User ID tidak ditemukan';
          });
        }
        return;
      }
      final result = await FaceRecognitionService.getTodayAttendance(
        userId: userId,
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
                result['message'] ?? 'Gagal mengambil status';
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

  void _safeSetState(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  Future<void> _initializeUserInfo() async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _accessToken = await _getToken();
      if (_accessToken != null) {
        await _loadProfileData();
      } else {
        _safeSetState(() {
          _errorMessage = 'Gagal mendapatkan token akses';
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
      final token = await _getToken();
      if (token == null) {
        _safeSetState(() {
          _errorMessage = 'Gagal mendapatkan token';
          _isLoading = false;
        });
        return;
      }
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/getDataUser'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final rj = json.decode(response.body);
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
          _errorMessage = 'Error API: ${response.statusCode}';
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
      } else if (mounted) {
        _safeResetSlider();
      }
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

  void refreshPage() {
    if (mounted) _checkTodayAttendanceStatus();
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isWeb = _isWideScreen(context);

    const double baseWidth = 375;
    const double baseHeight = 812;
    final double widthScale = screenWidth / baseWidth;
    final double heightScale = screenHeight / baseHeight;
    // Di web pakai scale = 1.0 supaya teks tidak terlalu besar
    final double scale = isWeb ? 1.0 : (widthScale + heightScale) / 2;

    final double horizontalPadding = isWeb ? 24 : screenWidth * 0.04;
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final double slideButtonBottomPadding = isWeb
        ? 16
        : (bottomSafeArea > 0 ? bottomSafeArea + 16 : 40);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: isWeb
            ? _buildWebLayout(
                scale,
                horizontalPadding,
                slideButtonBottomPadding,
              )
            : _buildMobileLayout(
                scale,
                horizontalPadding,
                slideButtonBottomPadding,
                screenHeight,
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (layout asli)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    double scale,
    double hPad,
    double slidePad,
    double screenHeight,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSection(scale, hPad),
                SizedBox(height: 20 * scale),
                _buildAttendanceStatusInfo(scale),
                SizedBox(height: 20 * scale),
                const TanggalanHorizontal(),
                SizedBox(height: 20 * scale),
                const AttendanceSummary(),
                SizedBox(height: 20 * scale),
                _buildServiceIconsSection(scale, isWeb: false),
                SizedBox(height: 20 * scale),
                _buildActivitiesSection(scale),
                SizedBox(height: 20 * scale),
                _buildTasksAndTimesheetSection(scale),
                if (_errorMessage != null) _buildDebugInfo(scale, hPad),
              ],
            ),
          ),
        ),
        _buildSlideButton(scale, hPad, slidePad, screenHeight * 0.07),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB LAYOUT (2 kolom: panel kiri | panel kanan)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWebLayout(double scale, double hPad, double slidePad) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panel kiri: Profil + Status + Aktivitas + Slide ────
        SizedBox(
          width: 340,
          child: Container(
            height: double.infinity,
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
                // Slide button sticky di bawah panel kiri
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: _buildSlideButton(scale, 20, 20, 60),
                ),
              ],
            ),
          ),
        ),

        // ── Panel kanan: Kalender + Summary + Layanan + Tasks ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TanggalanHorizontal(),
                const SizedBox(height: 16),
                const AttendanceSummary(),
                const SizedBox(height: 16),
                _buildServiceIconsSection(scale, isWeb: true),
                const SizedBox(height: 16),
                // Tugas + Timesheet side by side di web
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

  // ── Slide button (reusable mobile & web) ──────────────────────
  Widget _buildSlideButton(
    double scale,
    double hPad,
    double bottomPad,
    double height,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            height: height,
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

  // ─────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────
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
                MaterialPageRoute(builder: (_) => const HalamanNotifikasi()),
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
          if (_isLoadingNotifications && _unreadNotificationCount == 0)
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
            border: Border.all(color: Colors.lightBlue.shade200, width: 2),
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
        padding: EdgeInsets.all(14 * scale),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18 * scale,
              height: 18 * scale,
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
                  fontSize: 13 * scale,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_todayAttendanceData == null) return const SizedBox.shrink();

    final bgColor = _hasCheckedOut
        ? Colors.green.shade50
        : _hasCheckedIn
        ? Colors.orange.shade50
        : Colors.blue.shade50;
    final borderColor = _hasCheckedOut
        ? Colors.green.shade200
        : _hasCheckedIn
        ? Colors.orange.shade200
        : Colors.blue.shade200;
    final textColor = _hasCheckedOut
        ? Colors.green.shade700
        : _hasCheckedIn
        ? Colors.orange.shade700
        : Colors.blue.shade700;
    final icon = _hasCheckedOut
        ? Icons.check_circle
        : _hasCheckedIn
        ? Icons.access_time
        : Icons.schedule;
    final label = _hasCheckedOut
        ? 'Attendance Hari Ini Lengkap'
        : _hasCheckedIn
        ? 'Sudah Check In'
        : 'Belum Check In';

    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 18 * scale),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (_hasCheckedIn) ...[
            SizedBox(height: 7 * scale),
            Row(
              children: [
                Text(
                  'Check In: ',
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _formatTime(_todayAttendanceData!['CheckInTime']),
                  style: TextStyle(
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                if (_todayAttendanceData!['CheckInStatus'] != null) ...[
                  Text(' • ', style: TextStyle(color: Colors.grey[600])),
                  Text(
                    _formatStatus(_todayAttendanceData!['CheckInStatus']),
                    style: TextStyle(
                      fontSize: 11 * scale,
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
                    fontSize: 11 * scale,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _formatTime(_todayAttendanceData!['CheckOutTime']),
                  style: TextStyle(
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                if (_todayAttendanceData!['CheckOutStatus'] != null) ...[
                  Text(' • ', style: TextStyle(color: Colors.grey[600])),
                  Text(
                    _formatStatus(_todayAttendanceData!['CheckOutStatus']),
                    style: TextStyle(
                      fontSize: 11 * scale,
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

  Widget _buildServiceIconsSection(double scale, {required bool isWeb}) {
    final allServices = [
      _buildServiceIconData(
        Icons.receipt_long,
        "Reimbursement",
        const Color(0xFF4ECDC4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HalamanReimbursement()),
        ),
      ),
      _buildServiceIconData(
        Icons.calendar_today,
        "Kalender",
        const Color(0xFF007AFF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HalamanCalendar()),
        ),
      ),
      _buildServiceIconData(
        Icons.schedule,
        "Izin",
        const Color(0xFF007AFF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TimeOffScreen(userId: _profileDisplay?.userId ?? ''),
          ),
        ),
      ),
      _buildServiceIconData(
        Icons.location_on,
        "Live Attendance",
        const Color(0xFFFF9500),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LiveAttendanceScreen()),
        ),
      ),
      _buildServiceIconData(
        Icons.access_time_filled,
        "Lembur",
        const Color(0xFFFF6B35),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OvertimeScreen()),
        ),
      ),
      _buildServiceIconData(
        Icons.folder_open,
        "File Saya",
        const Color(0xFFFFCC02),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InfoProfileScreen(initialTabIndex: 2),
          ),
        ),
      ),
      _buildServiceIconData(
        Icons.flag,
        "Goal",
        const Color(0xFF795548),
        onTap: () => _showComingSoonDialog(context),
      ),
      _buildServiceIconData(
        Icons.inventory,
        "Asset",
        const Color(0xFF607D8B),
        onTap: () => _showComingSoonDialog(context),
      ),
    ];

    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: isWeb ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: isWeb
            ? null
            : [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4 * scale,
                  offset: Offset(0, 2 * scale),
                ),
              ],
        border: isWeb ? Border.all(color: Colors.grey.shade200) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Layanan',
            style: TextStyle(
              fontSize: 15 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 14 * scale),
          if (isWeb)
            // Web: Wrap — semua icon tampil tanpa scroll horizontal
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: allServices.map((s) {
                return GestureDetector(
                  onTap: s.onTap,
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: s.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(s.icon, size: 22, color: s.color),
                        ),
                        const SizedBox(height: 5),
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
            // Mobile: scroll horizontal 2 baris (asli)
            SizedBox(
              height: 176 * scale,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    Row(
                      children: allServices
                          .sublist(0, 4)
                          .map(
                            (s) => Container(
                              width: 70 * scale,
                              height: 80 * scale,
                              margin: EdgeInsets.only(right: 12 * scale),
                              child: _buildServiceIcon(
                                s.icon,
                                s.label,
                                s.color,
                                s.color,
                                scale,
                                onTap: s.onTap,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: 16 * scale),
                    Row(
                      children: allServices
                          .sublist(4)
                          .map(
                            (s) => Container(
                              width: 70 * scale,
                              height: 80 * scale,
                              margin: EdgeInsets.only(right: 12 * scale),
                              child: _buildServiceIcon(
                                s.icon,
                                s.label,
                                s.color,
                                s.color,
                                scale,
                                onTap: s.onTap,
                              ),
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

  Widget _buildActivitiesSection(double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
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
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
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
                  SizedBox(height: 10 * scale),
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
                          size: 44 * scale,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          'Belum ada aktivitas',
                          style: TextStyle(
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 3 * scale),
                        Text(
                          'Silakan lakukan check in untuk memulai',
                          style: TextStyle(
                            fontSize: 11 * scale,
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
                    size: 44 * scale,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(
                      fontSize: 13 * scale,
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

  Widget _buildTasksAndTimesheetSection(double scale) {
    return Column(
      children: [
        _buildTasksSection(scale),
        SizedBox(height: 12 * scale),
        _buildTimesheetSection(scale),
      ],
    );
  }

  Widget _buildTasksSection(double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
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
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Lihat Semua',
                style: TextStyle(fontSize: 11 * scale, color: Colors.blue),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 44 * scale,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 8 * scale),
                Text(
                  'Tidak ada tugas',
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 3 * scale),
                Text(
                  'Anda tidak memiliki tugas yang tertunda',
                  style: TextStyle(
                    fontSize: 11 * scale,
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
      padding: EdgeInsets.all(14 * scale),
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
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Ke Time Tracker',
                style: TextStyle(fontSize: 11 * scale, color: Colors.blue),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 44 * scale,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 8 * scale),
                Text(
                  'Tidak ada timesheet',
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 3 * scale),
                Text(
                  'Setelah Anda mengisi timesheet, akan muncul di sini.',
                  style: TextStyle(
                    fontSize: 11 * scale,
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

  Widget _buildDebugInfo(double scale, double hPad) {
    return Container(
      margin: EdgeInsets.only(top: 14 * scale),
      padding: EdgeInsets.all(11 * scale),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Text(
        'Debug: $_errorMessage',
        style: TextStyle(fontSize: 11 * scale, color: Colors.red.shade700),
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
      padding: EdgeInsets.all(11 * scale),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(7 * scale),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(7 * scale),
            ),
            child: Icon(icon, color: Colors.blue, size: 18 * scale),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3 * scale),
                Text(
                  'Hari ini • $time',
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 7 * scale,
              vertical: 3 * scale,
            ),
            decoration: BoxDecoration(
              color: (statusColor ?? Colors.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10 * scale),
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

  Widget _buildServiceIcon(
    IconData icon,
    String label,
    Color bgColor,
    Color iconColor,
    double scale, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              width: 45 * scale,
              height: 45 * scale,
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12 * scale),
              ),
              child: Icon(icon, size: 22 * scale, color: iconColor),
            ),
          ),
          SizedBox(height: 5 * scale),
          Flexible(
            flex: 2,
            child: Text(
              label,
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

  // ── Helper methods ─────────────────────────────────────────────
  String _formatTime(String? ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.parse(ts);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  String _formatStatus(String? status) {
    switch (status) {
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
        return status ?? '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
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
}

class ServiceIconData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const ServiceIconData({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
}

ServiceIconData _buildServiceIconData(
  IconData icon,
  String label,
  Color color, {
  VoidCallback? onTap,
}) {
  return ServiceIconData(icon: icon, label: label, color: color, onTap: onTap);
}
