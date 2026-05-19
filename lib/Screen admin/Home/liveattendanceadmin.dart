// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Import halaman absensi face recognition
import 'package:shared_preferences/shared_preferences.dart';
import '../../Screen User/fitur/attendance.dart'; // HalamanRiwayatAbsensi
import '../../Screen User/fitur/riwayatabsensi.dart';
import '../../Services/config.dart';
import '../../Services/face_recognition_service.dart';

enum AttendanceStatus { notCheckedIn, checkedIn, onBreak, checkedOut }

class TodayAttendance {
  DateTime? checkInTime;
  DateTime? checkOutTime;
  DateTime? breakStartTime;
  DateTime? breakEndTime;
  String? checkInLocation;
  String? checkOutLocation;
  AttendanceStatus status;

  TodayAttendance({
    this.checkInTime,
    this.checkOutTime,
    this.breakStartTime,
    this.breakEndTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.status = AttendanceStatus.notCheckedIn,
  });

  Duration get workingDuration {
    if (checkInTime == null) return Duration.zero;
    DateTime endTime = checkOutTime ?? DateTime.now();
    Duration total = endTime.difference(checkInTime!);
    if (breakStartTime != null) {
      DateTime breakEnd = breakEndTime ?? DateTime.now();
      total -= breakEnd.difference(breakStartTime!);
    }
    return total;
  }

  String get workingHours {
    final d = workingDuration;
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }
}

// ── helper ──────────────────────────────────────────────────────────
bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class LiveAttendanceScreenAdmin extends StatefulWidget {
  const LiveAttendanceScreenAdmin({super.key});

  @override
  _LiveAttendanceScreenAdminState createState() =>
      _LiveAttendanceScreenAdminState();
}

class _LiveAttendanceScreenAdminState extends State<LiveAttendanceScreenAdmin>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  DateTime _currentTime = DateTime.now();
  final TodayAttendance _todayAttendance = TodayAttendance();
  bool _isLoading = false;
  String _currentLocation = 'Memuat lokasi...';
  bool _isInOfficeArea = true;

  // Data absensi dari API (sama seperti HomeScreenHRD)
  Map<String, dynamic>? _todayAttendanceData;
  bool _isLoadingAttendance = false;
  String _attendanceStatusMessage = '';

  // Lokasi — sama persis dengan AbsensiScreen
  List<Map<String, dynamic>> _officeLocations = [];
  Map<String, dynamic>? _nearestOfficeLocation;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _pulseController.repeat(reverse: true);
    _slideController.forward();

    _checkTodayAttendanceStatus();
    _loadOfficeLocations().then((_) => _getCurrentLocation());
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Load status absensi hari ini dari API — sama dengan HomeScreenHRD
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
              final hasCheckedIn = data['CheckInTime'] != null;
              final hasCheckedOut = data['CheckOutTime'] != null;

              if (hasCheckedOut) {
                // Sudah check out → update TodayAttendance model
                _todayAttendance.status = AttendanceStatus.checkedOut;
                _todayAttendance.checkInTime = _parseTime(data['CheckInTime']);
                _todayAttendance.checkOutTime = _parseTime(
                  data['CheckOutTime'],
                );
                _attendanceStatusMessage = 'Anda sudah check out hari ini';
              } else if (hasCheckedIn) {
                // Sudah check in, belum check out
                _todayAttendance.status = AttendanceStatus.checkedIn;
                _todayAttendance.checkInTime = _parseTime(data['CheckInTime']);
                _todayAttendance.checkOutTime = null;
                _attendanceStatusMessage = 'Siap untuk check out';
              } else {
                _todayAttendance.status = AttendanceStatus.notCheckedIn;
                _attendanceStatusMessage = 'Siap untuk check in';
              }
            } else {
              _todayAttendance.status = AttendanceStatus.notCheckedIn;
              _attendanceStatusMessage = 'Siap untuk check in';
            }
            _isLoadingAttendance = false;
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoadingAttendance = false;
              _attendanceStatusMessage =
                  result['message'] ?? 'Gagal mengambil status absensi';
            });
          }
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

  // Helper parse waktu dari string API
  DateTime? _parseTime(String? timeString) {
    if (timeString == null) return null;
    try {
      return DateTime.parse(timeString);
    } catch (_) {
      return null;
    }
  }

  // Helper format waktu untuk display
  String _formatTime(String? timeString) {
    if (timeString == null) return '-';
    try {
      final dt = DateTime.parse(timeString);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timeString;
    }
  }

  // Helper format status absensi
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

  Color _getAttendanceStatusColor(String? status) {
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

  // ─── Load office locations dari API (sama seperti AbsensiScreen) ─────────
  Future<void> _loadOfficeLocations() async {
    try {
      final tokenResp = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResp.statusCode == 200) {
        final token = json.decode(tokenResp.body)['access_token'];
        final resp = await http
            .get(
              Uri.parse('$baseURL/api/asn/office/locations'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final data = (json.decode(resp.body)['data'] ?? []) as List<dynamic>;
          if (mounted) {
            setState(() {
              _officeLocations = data
                  .map<Map<String, dynamic>>(
                    (item) => {
                      'id': item['id'],
                      'office_name':
                          item['officeName'] ??
                          item['office_name'] ??
                          'Unknown Office',
                      'latitude': (item['latitude'] as num).toDouble(),
                      'longitude': (item['longitude'] as num).toDouble(),
                      'radius_meters':
                          (item['radiusMeters'] ?? item['radius_meters'] ?? 100)
                              .toDouble(),
                      'is_active':
                          item['isActive'] ?? item['is_active'] ?? true,
                    },
                  )
                  .toList();
            });
          }
        }
      }
    } catch (_) {
      // Gagal load office → tetap lanjut, radius check akan skip
    }
  }

  // ─── Cari kantor terdekat (sama persis dengan AbsensiScreen) ────────────
  Map<String, dynamic>? _findNearestOffice(Position userPosition) {
    if (_officeLocations.isEmpty) return null;
    Map<String, dynamic>? nearest;
    double minDist = double.infinity;

    for (var office in _officeLocations) {
      try {
        final distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          (office['latitude'] as num).toDouble(),
          (office['longitude'] as num).toDouble(),
        );
        if (distance < minDist) {
          minDist = distance;
          nearest = Map<String, dynamic>.from(office);
          nearest['distance'] = distance;
        }
      } catch (_) {
        continue;
      }
    }
    return nearest;
  }

  // ─── Get current location dengan GPS real (sama persis AbsensiScreen) ───
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _currentLocation = 'Memuat lokasi...';
    });

    try {
      // Check lokasi service aktif
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentLocation = 'GPS tidak aktif. Silakan aktifkan lokasi.';
            _isInOfficeArea = false;
          });
        }
        return;
      }

      // Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _currentLocation = 'Izin lokasi ditolak.';
              _isInOfficeArea = false;
            });
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentLocation = 'Izin lokasi ditolak permanen.';
            _isInOfficeArea = false;
          });
        }
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      _nearestOfficeLocation = _findNearestOffice(position);

      if (_nearestOfficeLocation != null) {
        final double distance = _nearestOfficeLocation!['distance'];
        final double allowedRadius =
            (_nearestOfficeLocation!['radius_meters'] as num).toDouble();
        final String officeName =
            _nearestOfficeLocation!['office_name'] as String;

        setState(() {
          _isInOfficeArea = distance <= allowedRadius;
          _currentLocation = _isInOfficeArea
              ? '✅ Dalam radius $officeName'
              : '❌ Di luar radius $officeName (${distance.toStringAsFixed(0)}m dari batas ${allowedRadius.toStringAsFixed(0)}m)';
        });
      } else {
        setState(() {
          // Tidak ada data kantor → tetap izinkan check in
          _isInOfficeArea = true;
          _currentLocation = 'Lokasi didapat (kantor tidak terkonfigurasi)';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _currentLocation = 'Timeout mendapatkan lokasi. Coba lagi.';
          _isInOfficeArea = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = 'Error lokasi: ${e.toString()}';
          _isInOfficeArea = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // NAVIGASI KE HALAMAN ABSENSI FACE RECOGNITION
  // ─────────────────────────────────────────────────────────────────

  /// Buka halaman AbsensiScreen (face recognition).
  /// [isCheckOut] = false → Check In, true → Check Out.
  /// Setelah selesai, result dikembalikan ke sini untuk update state.
  Future<void> _openAbsensiScreen({required bool isCheckOut}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AbsensiScreen(isCheckOut: isCheckOut, showBackButton: true),
      ),
    );

    // result = true berarti absensi berhasil → refresh data dari API
    if (result == true) {
      // Refresh dari API supaya data akurat (sama seperti HomeScreenHRD)
      await _checkTodayAttendanceStatus();
      // Update lokasi di model lokal
      if (!isCheckOut) {
        setState(() {
          _todayAttendance.checkInLocation = _currentLocation;
        });
      } else {
        setState(() {
          _todayAttendance.checkOutLocation = _currentLocation;
        });
      }
    }
  }

  Future<void> _performBreakStart() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _todayAttendance.breakStartTime = DateTime.now();
      _todayAttendance.status = AttendanceStatus.onBreak;
      _isLoading = false;
    });
    _showSuccessDialog(
      'Istirahat Dimulai',
      'Waktu istirahat Anda telah dimulai.',
    );
  }

  Future<void> _performBreakEnd() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _todayAttendance.breakEndTime = DateTime.now();
      _todayAttendance.status = AttendanceStatus.checkedIn;
      _isLoading = false;
    });
    _showSuccessDialog('Istirahat Selesai', 'Selamat kembali bekerja!');
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWeb = _isWideScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Clock In/Out',
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
              onPressed: _getCurrentLocation,
            ),
          ),
        ],
      ),
      body: SafeArea(child: isWeb ? _buildWebLayout() : _buildMobileLayout()),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (layout asli — scroll vertikal)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentTime(),
            _buildTodaysSummary(),
            const SizedBox(height: 16),
            _buildActivitiesSection(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildQuickActions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB LAYOUT (2 kolom: info kiri | aksi kanan)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Kolom kiri: jam + summary + quick actions ──────
        SizedBox(
          width: 380,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, _) => Column(
                  children: [
                    _buildCurrentTime(),
                    const SizedBox(height: 20),
                    _buildTodaysSummary(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Kolom kanan: tombol aksi + panduan ────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  _buildWebStatusBadge(),
                  const SizedBox(height: 24),

                  // Tombol aksi utama
                  _buildActionButtons(),
                  const SizedBox(height: 32),

                  // Panduan
                  _buildWebGuide(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Status badge web ──────────────────────────────────
  Widget _buildWebStatusBadge() {
    final status = _todayAttendance.status;
    final color = _getStatusColor(status);
    final text = _getStatusText(status);

    return Row(
      children: [
        const Text(
          'Status Hari Ini',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Panduan di kolom kanan web ─────────────────────────
  Widget _buildWebGuide() {
    final steps = [
      {
        'step': '1',
        'title': 'Buka Halaman Absensi',
        'desc': 'Klik tombol Check In / Check Out untuk membuka kamera.',
        'color': Colors.blue,
      },
      {
        'step': '2',
        'title': 'Verifikasi Wajah',
        'desc': 'Posisikan wajah dalam oval dan pastikan pencahayaan cukup.',
        'color': Colors.green,
      },
      {
        'step': '3',
        'title': 'Absensi Tercatat',
        'desc': 'Setelah verifikasi berhasil, data absensi otomatis tersimpan.',
        'color': Colors.purple,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cara Absensi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map((s) {
            final color = s['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(
                        s['step'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['title'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s['desc'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildCurrentTime() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('HH:mm:ss').format(_currentTime),
              style: const TextStyle(
                fontSize: 46,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isInOfficeArea ? Icons.location_on : Icons.location_off,
                  color: _isInOfficeArea ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _currentLocation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysSummary() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: const Color(0xFF007AFF), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Ringkasan Hari Ini',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_isLoadingAttendance)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Check In dari API
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Check In',
                    _todayAttendanceData != null
                        ? _formatTime(_todayAttendanceData!['CheckInTime'])
                        : '-',
                    Icons.login,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Check Out',
                    _todayAttendanceData != null
                        ? _formatTime(_todayAttendanceData!['CheckOutTime'])
                        : '-',
                    Icons.logout,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Jam Kerja',
                    _todayAttendance.checkInTime != null
                        ? _todayAttendance.workingHours
                        : '-',
                    Icons.schedule,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Status',
                    _getStatusText(_todayAttendance.status),
                    Icons.info,
                    _getStatusColor(_todayAttendance.status),
                  ),
                ),
              ],
            ),
            // Status dari API jika ada
            if (_todayAttendanceData != null &&
                _todayAttendanceData!['CheckInStatus'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getAttendanceStatusColor(
                    _todayAttendanceData!['CheckInStatus'],
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 13,
                      color: _getAttendanceStatusColor(
                        _todayAttendanceData!['CheckInStatus'],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatStatus(_todayAttendanceData!['CheckInStatus']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getAttendanceStatusColor(
                          _todayAttendanceData!['CheckInStatus'],
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
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(11),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ACTION BUTTONS — tombol Check In/Out navigasi ke AbsensiScreen
  // ─────────────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status message dari API
          if (_attendanceStatusMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _todayAttendance.status == AttendanceStatus.checkedOut
                    ? Colors.green.withOpacity(0.08)
                    : _todayAttendance.status == AttendanceStatus.checkedIn
                    ? Colors.orange.withOpacity(0.08)
                    : Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _todayAttendance.status == AttendanceStatus.checkedOut
                      ? Colors.green.withOpacity(0.25)
                      : _todayAttendance.status == AttendanceStatus.checkedIn
                      ? Colors.orange.withOpacity(0.25)
                      : Colors.blue.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _todayAttendance.status == AttendanceStatus.checkedOut
                        ? Icons.check_circle
                        : _todayAttendance.status == AttendanceStatus.checkedIn
                        ? Icons.access_time
                        : Icons.schedule,
                    size: 16,
                    color:
                        _todayAttendance.status == AttendanceStatus.checkedOut
                        ? Colors.green
                        : _todayAttendance.status == AttendanceStatus.checkedIn
                        ? Colors.orange
                        : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attendanceStatusMessage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color:
                            _todayAttendance.status ==
                                AttendanceStatus.checkedOut
                            ? Colors.green.shade700
                            : _todayAttendance.status ==
                                  AttendanceStatus.checkedIn
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── Belum Check In ──────────────────────────────
          if (_todayAttendance.status == AttendanceStatus.notCheckedIn) ...[
            _buildMainActionButton(
              'Check In',
              'Buka kamera untuk verifikasi wajah',
              Icons.login,
              Colors.green,
              _isInOfficeArea
                  ? () => _openAbsensiScreen(isCheckOut: false)
                  : null,
            ),
            if (!_isInOfficeArea) ...[
              const SizedBox(height: 12),
              _buildLocationWarning(),
            ],
          ],

          // ── Sedang Kerja ─────────────────────────────────
          if (_todayAttendance.status == AttendanceStatus.checkedIn) ...[
            _buildMainActionButton(
              'Check Out',
              'Buka kamera untuk verifikasi wajah',
              Icons.logout,
              Colors.red,
              () => _openAbsensiScreen(isCheckOut: true),
            ),
            const SizedBox(height: 12),
            _buildSecondaryActionButton(
              'Mulai Istirahat',
              Icons.pause,
              Colors.orange,
              _performBreakStart,
            ),
          ],

          // ── Istirahat ─────────────────────────────────────
          if (_todayAttendance.status == AttendanceStatus.onBreak) ...[
            _buildMainActionButton(
              'Selesai Istirahat',
              'Kembali bekerja',
              Icons.play_arrow,
              Colors.green,
              _performBreakEnd,
            ),
            const SizedBox(height: 12),
            _buildSecondaryActionButton(
              'Check Out Langsung',
              Icons.logout,
              Colors.red,
              () => _openAbsensiScreen(isCheckOut: true),
            ),
          ],

          // ── Selesai ───────────────────────────────────────
          if (_todayAttendance.status == AttendanceStatus.checkedOut)
            _buildWorkDoneCard(),
        ],
      ),
    );
  }

  Widget _buildLocationWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Anda berada di luar area kantor. Pindah ke area kantor untuk Check In.',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkDoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Hari Kerja Selesai',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total waktu kerja: ${_todayAttendance.workingHours}',
            style: TextStyle(fontSize: 13, color: Colors.green[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) => Transform.scale(
        scale: onPressed != null ? _pulseAnimation.value : 1.0,
        child: SizedBox(
          width: double.infinity,
          height: 76,
          child: ElevatedButton(
            onPressed: _isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: onPressed != null ? 8 : 0,
              shadowColor: color.withOpacity(0.3),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
      ),
    );
  }

  // ─── Aktivitas Hari Ini (sama seperti HomeScreenHRD) ────────────
  Widget _buildActivitiesSection() {
    if (_isLoadingAttendance) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Memuat aktivitas...',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF007AFF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Aktivitas Hari Ini',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_todayAttendanceData == null ||
              (_todayAttendanceData!['CheckInTime'] == null &&
                  _todayAttendanceData!['CheckOutTime'] == null))
            _buildEmptyActivity()
          else
            Column(
              children: [
                if (_todayAttendanceData!['CheckInTime'] != null)
                  _buildActivityItem(
                    icon: Icons.login,
                    title: 'Check In',
                    time: _formatTime(_todayAttendanceData!['CheckInTime']),
                    status: _formatStatus(
                      _todayAttendanceData!['CheckInStatus'],
                    ),
                    statusColor: _getAttendanceStatusColor(
                      _todayAttendanceData!['CheckInStatus'],
                    ),
                  ),
                if (_todayAttendanceData!['CheckInTime'] != null &&
                    _todayAttendanceData!['CheckOutTime'] != null)
                  const SizedBox(height: 10),
                if (_todayAttendanceData!['CheckOutTime'] != null)
                  _buildActivityItem(
                    icon: Icons.logout,
                    title: 'Check Out',
                    time: _formatTime(_todayAttendanceData!['CheckOutTime']),
                    status: _formatStatus(
                      _todayAttendanceData!['CheckOutStatus'],
                    ),
                    statusColor: _getAttendanceStatusColor(
                      _todayAttendanceData!['CheckOutStatus'],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(Icons.schedule_outlined, size: 44, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Belum ada aktivitas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lakukan check in untuk memulai',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String time,
    required String status,
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hari ini • $time',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (statusColor ?? Colors.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: statusColor ?? Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, color: Color(0xFF007AFF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Aksi Cepat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Lihat Riwayat',
                  Icons.history,
                  Colors.blue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HalamanRiwayatAbsensi(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Refresh Lokasi',
                  Icons.my_location,
                  Colors.green,
                  _getCurrentLocation,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.notCheckedIn:
        return 'Belum Absen';
      case AttendanceStatus.checkedIn:
        return 'Sedang Kerja';
      case AttendanceStatus.onBreak:
        return 'Istirahat';
      case AttendanceStatus.checkedOut:
        return 'Selesai';
    }
  }

  Color _getStatusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.notCheckedIn:
        return Colors.grey;
      case AttendanceStatus.checkedIn:
        return Colors.green;
      case AttendanceStatus.onBreak:
        return Colors.orange;
      case AttendanceStatus.checkedOut:
        return Colors.blue;
    }
  }
}
