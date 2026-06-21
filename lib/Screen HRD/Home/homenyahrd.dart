// Screen HRD/Home/home_screen_hrd.dart
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, use_build_context_synchronously
import 'dart:async';
import 'dart:convert';

import 'package:absensikaryawan/Screen%20HRD/Home/overtimehrd.dart';
import 'package:absensikaryawan/Screen%20HRD/Home/reimbursementhrd.dart';
import 'package:absensikaryawan/Screen%20HRD/Home/timeoffhrd.dart';
import 'package:absensikaryawan/Screen%20User/fitur/asset_screen.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// Data class untuk setiap item di grid layanan.
class ServiceIconData {
  const ServiceIconData({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final int? badge;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreenHRD extends StatefulWidget {
  const HomeScreenHRD({super.key});

  @override
  State<HomeScreenHRD> createState() => _HomeScreenHRDState();
}

class _HomeScreenHRDState extends State<HomeScreenHRD> {
  // ── State ──────────────────────────────────────────────────────────────────
  ProfileDisplay? _profileDisplay;
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _autoRefreshTimer;
  int _summaryRefreshTick = 0;

  /// Guard agar tidak ada dua refresh yang berjalan bersamaan.
  bool _isRefreshingPage = false;

  // Attendance
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;
  bool _isLoadingAttendance = false;
  Map<String, dynamic>? _todayAttendanceData;
  String _attendanceStatusMessage = '';

  // Slide button
  final GlobalKey<SlideActionState> _slideActionKey =
      GlobalKey<SlideActionState>();
  bool _isSlideActionProcessing = false;

  // Notifikasi
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;
  String? _notificationError;
  final NotificationService _notificationService = NotificationService();

  // Org approval badge
  int _pendingOrgCount = 0;

  // User identity — di-cache agar tidak bolak-balik SharedPreferences
  String? _userID;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _refreshAll(showLoading: true);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    super.dispose();
  }

  // ── Auth & Identity ────────────────────────────────────────────────────────

  /// Memuat UserID dari SharedPreferences dan menyimpannya ke cache `_userID`.
  Future<String?> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userID = prefs.getString('UserID');
    return _userID;
  }

  /// Mendapatkan token akses dari endpoint auth.
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
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = data['access_token'];
        if (token is String && token.isNotEmpty) return token;
      }
    } catch (_) {}
    return null;
  }

  // ── Refresh Orchestration ──────────────────────────────────────────────────

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshAll(showLoading: false);
    });
  }

  /// Entry point refresh. `showLoading` = true hanya saat cold start / pull-to-refresh manual.
  Future<void> _refreshAll({bool showLoading = false}) async {
    // Tolak jika sudah ada refresh yang berjalan
    if (_isRefreshingPage) return;
    _isRefreshingPage = true;

    try {
      if (showLoading) {
        await _initializeUserInfo();
      } else {
        // Pastikan UserID sudah tersedia
        if (_userID == null || _userID!.isEmpty) await _loadUserId();
      }

      // Jalankan semua task paralel.
      // Catatan: _loadPendingOrgCount sudah dipanggil di dalam _initializeUserInfo
      // saat showLoading=true, jadi kita skip agar tidak dobel.
      await Future.wait([
        _checkTodayAttendanceStatus(showLoading: showLoading),
        _loadUnreadNotificationCount(),
        if (!showLoading) _loadPendingOrgCount(),
      ]);

      // Hanya increment tick saat showLoading=true (cold start / pull-to-refresh)
      // agar AttendanceSummaryAdmin tidak di-rebuild ulang setiap 30 detik.
      if (mounted && showLoading) setState(() => _summaryRefreshTick++);
    } catch (_) {
      // Refresh otomatis berjalan silent — tidak ganggu user.
    } finally {
      _isRefreshingPage = false;
    }
  }

  Future<void> _initializeUserInfo() async {
    _safeSetState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        _safeSetState(() {
          _errorMessage = 'Gagal mendapatkan token akses';
          _isLoading = false;
        });
        return;
      }

      // Jalankan profile + userId + org count secara paralel
      await Future.wait([_loadProfileData(token), _loadUserId()]);
      await _loadPendingOrgCount();
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Error inisialisasi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileData(String accessToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email');

      if (email == null || email.isEmpty) {
        _safeSetState(() {
          _errorMessage = 'Email tidak ditemukan di perangkat';
          _isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/getDataUser'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'Email': email}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final rj = json.decode(response.body) as Map<String, dynamic>;
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

  // ── Attendance ─────────────────────────────────────────────────────────────

  Future<void> _checkTodayAttendanceStatus({bool showLoading = false}) async {
    if (!mounted) return;

    // Hanya tampilkan loading indicator saat cold start atau pull-to-refresh manual.
    // Background auto-refresh TIDAK boleh mengubah _isLoadingAttendance agar
    // tidak menyebabkan widget hilang-muncul (flicker/kedip).
    if (showLoading) _safeSetState(() => _isLoadingAttendance = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('UserID') ?? '';

      if (uid.isEmpty) {
        if (showLoading) {
          _safeSetState(() {
            _isLoadingAttendance = false;
            _attendanceStatusMessage = 'User ID tidak ditemukan';
          });
        }
        return;
      }

      // Fetch data di background — tanpa mengubah state loading
      final result = await FaceRecognitionService.getTodayAttendance(
        userId: uid,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>?;
        // Apply semua perubahan dalam SATU setState agar tidak ada intermediate
        // render yang menyebabkan flicker.
        _safeSetState(() {
          _todayAttendanceData = data;
          _hasCheckedIn = data?['CheckInTime'] != null;
          _hasCheckedOut = data?['CheckOutTime'] != null;
          _attendanceStatusMessage = _hasCheckedOut
              ? 'Anda sudah check out hari ini'
              : _hasCheckedIn
              ? 'Siap untuk check out'
              : 'Siap untuk check in';
          // Matikan loading hanya jika memang sedang loading
          if (_isLoadingAttendance) _isLoadingAttendance = false;
        });
      } else {
        // Jika background refresh gagal, pertahankan data lama agar tidak
        // tiba-tiba kosong (jangan null-kan _todayAttendanceData).
        if (showLoading) {
          _safeSetState(() {
            _todayAttendanceData = null;
            _hasCheckedIn = false;
            _hasCheckedOut = false;
            _isLoadingAttendance = false;
            _attendanceStatusMessage =
                result['message'] as String? ??
                'Gagal mengambil status absensi';
          });
        }
      }
    } catch (e) {
      // Saat background refresh error, jangan reset tampilan yang sudah ada
      if (showLoading) {
        _safeSetState(() {
          _isLoadingAttendance = false;
          _attendanceStatusMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _handleAttendanceAction() async {
    if (_isSlideActionProcessing || _hasCheckedOut) {
      if (_hasCheckedOut && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda sudah melakukan check out hari ini'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _safeResetSlider();
      return;
    }

    _isSlideActionProcessing = true;

    try {
      if (!mounted) return;
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AbsensiScreen(isCheckOut: _hasCheckedIn, showBackButton: true),
        ),
      );

      if (mounted) {
        if (result == true || result != null) {
          await _refreshAll(showLoading: false);
        }
        _safeResetSlider();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _safeResetSlider();
      }
    } finally {
      // Pastikan flag selalu di-reset meski ada exception
      _isSlideActionProcessing = false;
    }
  }

  void _safeResetSlider() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        try {
          _slideActionKey.currentState?.reset();
        } catch (_) {}
      }
    });
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<void> _loadUnreadNotificationCount({bool showLoading = false}) async {
    if (!mounted) return;

    // Spinner badge hanya muncul saat user secara eksplisit minta refresh,
    // bukan saat auto-refresh background (agar icon notif tidak kedip-kedip).
    if (showLoading) {
      _safeSetState(() {
        _isLoadingNotifications = true;
        _notificationError = null;
      });
    }

    try {
      if (_userID == null || _userID!.isEmpty) await _loadUserId();
      if (_userID == null || _userID!.isEmpty) {
        if (showLoading) _safeSetState(() => _isLoadingNotifications = false);
        return;
      }

      final result = await _notificationService.getAdminNotificationStats();
      if (mounted) {
        _safeSetState(() {
          _unreadNotificationCount = result['unreadCount'] ?? 0;
          _notificationError = null;
          if (_isLoadingNotifications) _isLoadingNotifications = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() {
          if (_isLoadingNotifications) _isLoadingNotifications = false;
          // Pertahankan count lama jika background refresh gagal
          if (showLoading) _notificationError = e.toString();
        });
      }
    }
  }

  // ── Org Approval ───────────────────────────────────────────────────────────

  Future<void> _loadPendingOrgCount() async {
    try {
      if (_userID == null || _userID!.isEmpty) await _loadUserId();
      if (_userID == null || _userID!.isEmpty) return;

      final res = await TimeOffService.getPendingOrgReview(_userID!);
      if (res.success && res.data != null && mounted) {
        _safeSetState(() => _pendingOrgCount = res.data!.length);
      }
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _safeSetState(VoidCallback cb) {
    if (mounted) setState(cb);
  }

  String _formatTime(String? ts) {
    if (ts == null || ts.isEmpty) return '-';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  String _formatStatus(String? s) {
    const map = {
      'on_time': 'Tepat Waktu',
      'late': 'Terlambat',
      'very_late': 'Sangat Terlambat',
      'early': 'Pulang Awal',
      'overtime': 'Lembur',
    };
    return map[s] ?? s ?? '-';
  }

  Color _getStatusColor(String? s) {
    const map = {
      'on_time': Colors.green,
      'late': Colors.orange,
      'very_late': Colors.red,
      'early': Colors.blue,
      'overtime': Colors.purple,
    };
    return map[s] ?? Colors.grey;
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

  void _showComingSoonDialog() {
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

  // Expose untuk dipanggil dari parent widget jika diperlukan
  void refreshPage() {
    if (mounted) _refreshAll(showLoading: false);
  }

  Future<void> refreshAttendanceStatus() async {
    if (mounted) await _checkTodayAttendanceStatus();
  }

  Future<void> refreshNotificationCount() async =>
      _loadUnreadNotificationCount(showLoading: true);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isWeb = _isWideScreen(context);
    const double baseW = 375, baseH = 812;
    final double scale = isWeb
        ? 1.0
        : ((size.width / baseW) + (size.height / baseH)) / 2;
    final double hPad = isWeb ? 32 : size.width * 0.04;
    final double vPad = isWeb ? 24 : size.height * 0.02;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final double slidePad = bottomSafe > 0 ? bottomSafe + 16 : 40;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: isWeb
            ? _buildWebLayout(scale, hPad, vPad)
            : _buildMobileLayout(scale, hPad, vPad, slidePad),
      ),
    );
  }

  // ── Layout: Mobile ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    double scale,
    double hPad,
    double vPad,
    double slidePad,
  ) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refreshAll(showLoading: false),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection(scale),
                  SizedBox(height: 20 * scale),
                  _buildAttendanceStatusInfo(scale),
                  SizedBox(height: 20 * scale),
                  const TanggalanHorizontal(),
                  SizedBox(height: 20 * scale),
                  AttendanceSummaryAdmin(
                    key: ValueKey('summary_mobile_$_summaryRefreshTick'),
                  ),
                  SizedBox(height: 20 * scale),
                  _buildServiceIconsSection(scale),
                  SizedBox(height: 20 * scale),
                  _buildActivitiesSection(scale),
                  SizedBox(height: 20 * scale),
                  _buildTasksSection(scale),
                  SizedBox(height: 12 * scale),
                  _buildTimesheetSection(scale),
                  SizedBox(height: 8 * scale),
                ],
              ),
            ),
          ),
        ),
        _buildSlideButton(scale, hPad, slidePad),
      ],
    );
  }

  // ── Layout: Web ────────────────────────────────────────────────────────────

  Widget _buildWebLayout(double scale, double hPad, double vPad) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar kiri
        SizedBox(
          width: 300,
          child: DecoratedBox(
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
                        _buildProfileSection(scale),
                        const SizedBox(height: 16),
                        _buildAttendanceStatusInfo(scale),
                        const SizedBox(height: 16),
                        _buildActivitiesSection(scale),
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
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
        // Konten utama
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refreshAll(showLoading: false),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TanggalanHorizontal(),
                  const SizedBox(height: 16),
                  AttendanceSummaryAdmin(
                    key: ValueKey('summary_web_$_summaryRefreshTick'),
                  ),
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
        ),
      ],
    );
  }

  // ── Slide Button ───────────────────────────────────────────────────────────

  Widget _buildSlideButton(double scale, double hPad, double bottomPad) {
    final bool isDisabled =
        _hasCheckedOut || _isLoadingAttendance || _isSlideActionProcessing;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, bottomPad),
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
            enabled: !isDisabled,
            onSubmit: isDisabled
                ? null
                : () async {
                    await _handleAttendanceAction();
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
          ),
        ],
      ),
    );
  }

  // ── Profile Section ────────────────────────────────────────────────────────

  Widget _buildProfileSection(double scale) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InfoProfileScreen()),
          ),
          child: Container(
            padding: EdgeInsets.all(3 * scale),
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
                  ? Icon(
                      Icons.person,
                      size: 28 * scale,
                      color: Colors.grey[600],
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                _buildShimmerText(width: 140 * scale, height: 16 * scale)
              else if (_errorMessage != null)
                Text(
                  'Gagal memuat data',
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                )
              else
                NamaDisplay(
                  nama: _profileDisplay?.displayName ?? 'Nama tidak tersedia',
                  scale: scale,
                ),
              SizedBox(height: 4 * scale),
              if (_isLoading)
                _buildShimmerText(width: 100 * scale, height: 12 * scale)
              else
                Text(
                  _profileDisplay?.jobs ?? 'Jabatan tidak tersedia',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildNotificationIcon(scale),
      ],
    );
  }

  /// Shimmer placeholder sederhana untuk skeleton loading.
  Widget _buildShimmerText({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ── Notification Icon ──────────────────────────────────────────────────────

  Widget _buildNotificationIcon(double scale) {
    final double iconSize = 28.0 * scale;
    final double badgeSize = 18.0 * scale;

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

          // Badge: loading
          if (_isLoadingNotifications)
            _buildBadgeContainer(
              size: badgeSize,
              iconSize: iconSize,
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(badgeSize * 0.2),
                child: const CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),

          // Badge: error
          if (_notificationError != null &&
              !_isLoadingNotifications &&
              _unreadNotificationCount == 0)
            _buildBadgeContainer(
              size: badgeSize,
              iconSize: iconSize,
              color: Colors.orange,
              child: Icon(
                Icons.error_outline,
                color: Colors.white,
                size: badgeSize * 0.6,
              ),
            ),

          // Badge: count
          if (_unreadNotificationCount > 0 && !_isLoadingNotifications)
            _buildBadgeContainer(
              size: badgeSize,
              iconSize: iconSize,
              color: Colors.red,
              child: Text(
                _unreadNotificationCount > 99
                    ? '99+'
                    : '$_unreadNotificationCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: badgeSize * 0.55,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadgeContainer({
    required double size,
    required double iconSize,
    required Color color,
    required Widget child,
  }) {
    // Posisi badge: pojok kanan-atas icon
    final double offset = (48 - iconSize) / 2 - (size * 0.3);
    return Positioned(
      right: offset,
      top: offset,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Attendance Status Info ─────────────────────────────────────────────────

  Widget _buildAttendanceStatusInfo(double scale) {
    if (_isLoadingAttendance) {
      return _buildStatusCard(
        color: Colors.blue,
        icon: null,
        title: 'Memuat status attendance...',
        scale: scale,
        isLoading: true,
      );
    }

    if (_todayAttendanceData == null) return const SizedBox.shrink();

    return _buildStatusCard(
      color: _hasCheckedOut
          ? Colors.green
          : (_hasCheckedIn ? Colors.orange : Colors.blue),
      icon: _hasCheckedOut
          ? Icons.check_circle
          : (_hasCheckedIn ? Icons.access_time : Icons.schedule),
      title: _hasCheckedOut
          ? 'Attendance Hari Ini Lengkap'
          : (_hasCheckedIn ? 'Sudah Check In' : 'Belum Check In'),
      scale: scale,
      checkinTime: _hasCheckedIn
          ? _formatTime(_todayAttendanceData!['CheckInTime'])
          : null,
      checkinStatus: _hasCheckedIn
          ? _todayAttendanceData!['CheckInStatus'] as String?
          : null,
      checkoutTime: _hasCheckedOut
          ? _formatTime(_todayAttendanceData!['CheckOutTime'])
          : null,
      checkoutStatus: _hasCheckedOut
          ? _todayAttendanceData!['CheckOutStatus'] as String?
          : null,
    );
  }

  Widget _buildStatusCard({
    required Color color,
    IconData? icon,
    required String title,
    required double scale,
    bool isLoading = false,
    String? checkinTime,
    String? checkinStatus,
    String? checkoutTime,
    String? checkoutStatus,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLoading)
                SizedBox(
                  width: 18 * scale,
                  height: 18 * scale,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, color: color.withOpacity(0.8), size: 18 * scale),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          if (checkinTime != null) ...[
            SizedBox(height: 8 * scale),
            _buildTimeRow(
              label: 'Check In',
              time: checkinTime,
              status: checkinStatus,
              scale: scale,
            ),
          ],
          if (checkoutTime != null) ...[
            SizedBox(height: 4 * scale),
            _buildTimeRow(
              label: 'Check Out',
              time: checkoutTime,
              status: checkoutStatus,
              scale: scale,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required String label,
    required String time,
    String? status,
    required double scale,
  }) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12 * scale, color: Colors.grey[600]),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        if (status != null) ...[
          Text(' • ', style: TextStyle(color: Colors.grey[400])),
          Text(
            _formatStatus(status),
            style: TextStyle(
              fontSize: 11 * scale,
              fontWeight: FontWeight.w500,
              color: _getStatusColor(status),
            ),
          ),
        ],
      ],
    );
  }

  // ── Service Icons Section ──────────────────────────────────────────────────

  List<ServiceIconData> _buildServices() => [
    ServiceIconData(
      icon: Icons.receipt_long,
      label: 'Reimbursement',
      color: const Color(0xFF4ECDC4),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HalamanHRDReimbursement()),
      ),
    ),
    ServiceIconData(
      icon: Icons.calendar_today,
      label: 'Kalender',
      color: const Color(0xFF007AFF),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HrdCalendarScreen()),
        );
        _refreshAll(showLoading: false);
      },
    ),
    ServiceIconData(
      icon: Icons.schedule,
      label: 'Izin',
      color: const Color(0xFF5856D6),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TimeOffHRDScreen()),
        );
        _refreshAll(showLoading: false);
      },
    ),
    ServiceIconData(
      icon: Icons.location_on,
      label: 'Absensi',
      color: const Color(0xFFFF9500),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LiveAttendanceScreenAdmin()),
        );
        _refreshAll(showLoading: false);
      },
    ),
    ServiceIconData(
      icon: Icons.access_time_filled,
      label: 'Lembur',
      color: const Color(0xFFFF6B35),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OvertimeHRDScreen()),
        );
        _refreshAll(showLoading: false);
      },
    ),
    ServiceIconData(
      icon: Icons.folder_open,
      label: 'File Saya',
      color: const Color(0xFFFFCC02),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const InfoProfileScreen(initialTabIndex: 2),
        ),
      ),
    ),
    ServiceIconData(
      icon: Icons.campaign_rounded,
      label: 'Broadcast',
      color: const Color(0xFF6366F1),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BroadcastNotifScreen()),
      ),
    ),
    ServiceIconData(
      icon: Icons.groups_rounded,
      label: 'Persetujuan',
      color: const Color(0xFF0EA5E9),
      badge: _pendingOrgCount,
      onTap: () async {
        final uid = _profileDisplay?.userId ?? _userID ?? '';
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrgApprovalScreen(userId: uid)),
        );
        _loadPendingOrgCount();
      },
    ),
    ServiceIconData(
      icon: Icons.event,
      label: 'Acara',
      color: const Color(0xFF795548),
      onTap: _showComingSoonDialog,
    ),
    ServiceIconData(
      icon: Icons.inventory,
      label: 'Asset',
      color: const Color(0xFF607D8B),
      onTap: () {
        final uid = _profileDisplay?.userId ?? _userID ?? '';
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AssetScreen(userId: uid)),
        );
      },
    ),
  ];

  Widget _buildServiceIconsSection(double scale) {
    final bool isWeb = _isWideScreen(context);
    final services = _buildServices();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWeb ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Layanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          SizedBox(height: isWeb ? 16 : 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final int cols = isWeb
                  ? (w >= 1200
                        ? 6
                        : w >= 900
                        ? 5
                        : 4)
                  : 3; // mobile selalu 3 kolom (landscape bisa lebih)
              const double ratio = 1.15;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: services.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: isWeb ? 10 : 8,
                  mainAxisSpacing: isWeb ? 10 : 8,
                  childAspectRatio: ratio,
                ),
                itemBuilder: (_, i) =>
                    _buildServiceGridItem(services[i], isWeb: isWeb),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGridItem(ServiceIconData s, {required bool isWeb}) {
    final double iconBoxSize = isWeb ? 44 : 42;
    final double iconSize = isWeb ? 22 : 20;
    final double fontSize = isWeb ? 11.5 : 10.5;
    final bool hasBadge = (s.badge ?? 0) > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: s.onTap,
        splashColor: s.color.withOpacity(0.12),
        highlightColor: s.color.withOpacity(0.06),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 8 : 6,
            vertical: isWeb ? 10 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          s.color.withOpacity(0.15),
                          s.color.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(s.icon, size: iconSize, color: s.color),
                  ),
                  if (hasBadge)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            s.badge! > 99 ? '99+' : '${s.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Activities Section ─────────────────────────────────────────────────────

  Widget _buildActivitiesSection(double scale) {
    return _buildCard(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title: 'Aktivitas Anda Hari Ini', scale: scale),
          SizedBox(height: 16 * scale),
          if (_isLoadingAttendance)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_todayAttendanceData != null) ...[
            if (_hasCheckedIn)
              _buildActivityItem(
                icon: Icons.login,
                title: 'Check In',
                time: _formatTime(_todayAttendanceData!['CheckInTime']),
                status: _formatStatus(
                  _todayAttendanceData!['CheckInStatus'] as String?,
                ),
                scale: scale,
                statusColor: _getStatusColor(
                  _todayAttendanceData!['CheckInStatus'] as String?,
                ),
              ),
            if (_hasCheckedIn && _hasCheckedOut) SizedBox(height: 10 * scale),
            if (_hasCheckedOut)
              _buildActivityItem(
                icon: Icons.logout,
                title: 'Check Out',
                time: _formatTime(_todayAttendanceData!['CheckOutTime']),
                status: _formatStatus(
                  _todayAttendanceData!['CheckOutStatus'] as String?,
                ),
                scale: scale,
                statusColor: _getStatusColor(
                  _todayAttendanceData!['CheckOutStatus'] as String?,
                ),
              ),
            if (!_hasCheckedIn)
              _buildEmptyState(
                scale,
                'Belum ada aktivitas',
                'Silakan lakukan check in untuk memulai',
              ),
          ] else
            _buildEmptyState(
              scale,
              'Belum ada aktivitas',
              'Data belum tersedia',
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String time,
    required String status,
    required double scale,
    Color? statusColor,
  }) {
    final Color sc = statusColor ?? Colors.grey;
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10 * scale),
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
                SizedBox(height: 3 * scale),
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
              color: sc.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10 * scale,
                color: sc,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tasks & Timesheet Section ──────────────────────────────────────────────

  Widget _buildTasksSection(double scale) {
    return _buildCard(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Tugas',
            actionLabel: 'Lihat Semua',
            onAction: () {},
            scale: scale,
          ),
          SizedBox(height: 16 * scale),
          _buildEmptyState(
            scale,
            'Tidak ada tugas',
            'Anda tidak memiliki tugas yang tertunda',
            icon: Icons.assignment_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetSection(double scale) {
    return _buildCard(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Timesheet',
            actionLabel: 'Ke Time Tracker',
            onAction: () {},
            scale: scale,
          ),
          SizedBox(height: 16 * scale),
          _buildEmptyState(
            scale,
            'Tidak ada timesheet',
            'Setelah Anda mengisi timesheet, akan muncul di sini.',
          ),
        ],
      ),
    );
  }

  // ── Reusable Primitives ────────────────────────────────────────────────────

  Widget _buildCard({required double scale, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required double scale,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15 * scale,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 12 * scale,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(
    double scale,
    String title,
    String subtitle, {
    IconData icon = Icons.schedule_outlined,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        child: Column(
          children: [
            Icon(icon, size: 44 * scale, color: Colors.grey[350]),
            SizedBox(height: 8 * scale),
            Text(
              title,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12 * scale, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
