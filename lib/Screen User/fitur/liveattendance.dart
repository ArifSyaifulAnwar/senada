// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

enum AttendanceStatus { notCheckedIn, checkedIn, onBreak, checkedOut }

class TodayAttendance {
  DateTime? checkInTime;
  DateTime? checkOutTime;
  DateTime? breakStartTime;
  DateTime? breakEndTime;
  String? checkInLocation;
  String? checkOutLocation;
  AttendanceStatus status;
  String? selfieImage;

  TodayAttendance({
    this.checkInTime,
    this.checkOutTime,
    this.breakStartTime,
    this.breakEndTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.status = AttendanceStatus.notCheckedIn,
    this.selfieImage,
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

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  _LiveAttendanceScreenState createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  DateTime _currentTime = DateTime.now();
  final TodayAttendance _todayAttendance = TodayAttendance();
  bool _isLoading = false;
  List<Map<String, dynamic>> _officeLocations = [];
  bool _isLoadingLocation = true;
  Timer? _locationTimer;
  Map<String, dynamic>? _nearestOfficeLocation;
  String _locationInfo = "Memuat lokasi...";

  bool get _isInOfficeArea {
    if (_nearestOfficeLocation == null) return false;
    final double distance =
        _nearestOfficeLocation!['distance'] ?? double.infinity;
    final double allowedRadius =
        (_nearestOfficeLocation!['radius_meters'] as num?)?.toDouble() ?? 100.0;
    return distance <= allowedRadius;
  }

  String get _displayLocationInfo {
    if (_isLoadingLocation) return "Memuat lokasi...";
    if (_nearestOfficeLocation == null) return "Tidak ada kantor terdekat";
    return _locationInfo;
  }

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _currentTime = DateTime.now()),
    );

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

    _loadTodayAttendance();
    _loadOfficeLocations().then((_) => _getCurrentLocation());
  }

  @override
  void dispose() {
    _timer.cancel();
    _locationTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // LOKASI — sama persis dengan AbsensiScreen
  // ─────────────────────────────────────────────────────────────────
  Future<void> _loadOfficeLocations() async {
    try {
      final tokenResponse = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResponse.statusCode == 200) {
        final token = json.decode(tokenResponse.body)['access_token'];
        final response = await http
            .get(
              Uri.parse('$baseURL/api/asn/office/locations'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data =
              (json.decode(response.body)['data'] ?? []) as List<dynamic>;
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationInfo = "Gagal memuat data kantor";
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    _locationTimer?.cancel();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi tidak aktif. Silakan aktifkan GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak secara permanen.');
      }

      _locationTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _isLoadingLocation) {
          setState(() {
            _locationInfo = "Timeout mendapatkan lokasi. Coba lagi.";
            _isLoadingLocation = false;
          });
        }
      });

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _locationTimer?.cancel();

      if (!mounted) return;
      _nearestOfficeLocation = _findNearestOffice(position);

      if (_nearestOfficeLocation != null) {
        final double distance = _nearestOfficeLocation!['distance'];
        final double allowedRadius =
            (_nearestOfficeLocation!['radius_meters'] as num).toDouble();
        setState(() {
          _locationInfo = distance <= allowedRadius
              ? '✅ Dalam radius ${_nearestOfficeLocation!['office_name']}'
              : '❌ Di luar radius ${_nearestOfficeLocation!['office_name']} (${distance.toStringAsFixed(0)}m dari batas ${allowedRadius.toStringAsFixed(0)}m)';
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _locationInfo = "Tidak ada kantor terdekat";
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      _locationTimer?.cancel();
      if (mounted) {
        setState(() {
          _locationInfo = "Error: ${e.toString()}";
          _isLoadingLocation = false;
        });
      }
    }
  }

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

  Future<void> _loadTodayAttendance() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _performCheckIn() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _todayAttendance.checkInTime = DateTime.now();
        _todayAttendance.checkInLocation =
            _nearestOfficeLocation?['office_name'] ?? 'Unknown';
        _todayAttendance.status = AttendanceStatus.checkedIn;
      });
      _showSuccessDialog(
        'Check In Berhasil!',
        'Anda berhasil check in pada ${DateFormat('HH:mm').format(DateTime.now())}',
      );
    } catch (_) {
      _showErrorDialog(
        'Gagal Check In',
        'Terjadi kesalahan. Silakan coba lagi.',
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _performCheckOut() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _todayAttendance.checkOutTime = DateTime.now();
        _todayAttendance.checkOutLocation =
            _nearestOfficeLocation?['office_name'] ?? 'Unknown';
        _todayAttendance.status = AttendanceStatus.checkedOut;
      });
      _showSuccessDialog(
        'Check Out Berhasil!',
        'Check out pada ${DateFormat('HH:mm').format(DateTime.now())}.\nTotal kerja: ${_todayAttendance.workingHours}',
      );
    } catch (_) {
      _showErrorDialog(
        'Gagal Check Out',
        'Terjadi kesalahan. Silakan coba lagi.',
      );
    }
    setState(() => _isLoading = false);
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 22),
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 22),
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
  // MOBILE LAYOUT (scroll vertikal — layout asli)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentTime(),
            _buildTodaysSummary(),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildQuickActionsCard(),
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
        // ── Kolom kiri: jam + summary + quick actions ──────────
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
                builder: (_, __) => Column(
                  children: [
                    _buildCurrentTime(),
                    const SizedBox(height: 20),
                    _buildTodaysSummary(),
                    const SizedBox(height: 20),
                    _buildQuickActionsCard(),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Kolom kanan: status badge + tombol aksi + panduan ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebStatusBadge(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                  _buildWebGuide(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Status badge kolom kanan web ──────────────────────────────
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

  // ── Panduan kolom kanan web ───────────────────────────────────
  Widget _buildWebGuide() {
    final steps = [
      {
        'step': '1',
        'title': 'Pastikan Lokasi Aktif',
        'desc': 'GPS harus aktif dan izin lokasi diberikan.',
        'color': Colors.blue,
      },
      {
        'step': '2',
        'title': 'Berada di Area Kantor',
        'desc': 'Anda harus berada dalam radius kantor untuk Check In.',
        'color': Colors.green,
      },
      {
        'step': '3',
        'title': 'Tekan Tombol Aksi',
        'desc': 'Klik Check In / Check Out untuk mencatat kehadiran.',
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
                    _displayLocationInfo,
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
                const Icon(Icons.today, color: Color(0xFF007AFF), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Ringkasan Hari Ini',
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
                  child: _buildSummaryItem(
                    'Check In',
                    _todayAttendance.checkInTime != null
                        ? DateFormat(
                            'HH:mm',
                          ).format(_todayAttendance.checkInTime!)
                        : '-',
                    Icons.login,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Check Out',
                    _todayAttendance.checkOutTime != null
                        ? DateFormat(
                            'HH:mm',
                          ).format(_todayAttendance.checkOutTime!)
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

  Widget _buildActionButtons() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Belum Check In ────────────────────────────────────
          if (_todayAttendance.status == AttendanceStatus.notCheckedIn) ...[
            _buildMainActionButton(
              'Check In',
              'Mulai hari kerja Anda',
              Icons.login,
              Colors.green,
              _isInOfficeArea ? _performCheckIn : null,
            ),
            if (!_isInOfficeArea) ...[
              const SizedBox(height: 12),
              _buildLocationWarning(),
            ],
          ],

          // ── Sedang Kerja ──────────────────────────────────────
          if (_todayAttendance.status == AttendanceStatus.checkedIn) ...[
            _buildMainActionButton(
              'Check Out',
              'Akhiri hari kerja Anda',
              Icons.logout,
              Colors.red,
              _performCheckOut,
            ),
            const SizedBox(height: 12),
            _buildSecondaryActionButton(
              'Mulai Istirahat',
              Icons.pause,
              Colors.orange,
              _performBreakStart,
            ),
          ],

          // ── Istirahat ─────────────────────────────────────────
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
              'Check Out',
              Icons.logout,
              Colors.red,
              _performCheckOut,
            ),
          ],

          // ── Selesai ───────────────────────────────────────────
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
      builder: (_, __) => Transform.scale(
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

  Widget _buildQuickActionsCard() {
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
                  () => Navigator.pop(context),
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
}
