// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

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

    // Subtract break time if any
    if (breakStartTime != null) {
      DateTime breakEnd = breakEndTime ?? DateTime.now();
      Duration breakDuration = breakEnd.difference(breakStartTime!);
      total = total - breakDuration;
    }

    return total;
  }

  String get workingHours {
    Duration duration = workingDuration;
    int hours = duration.inHours;
    int minutes = (duration.inMinutes % 60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
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

  // Tambahkan getter untuk mengecek apakah user berada di area kantor
  bool get _isInOfficeArea {
    if (_nearestOfficeLocation == null) return false;

    double distance = _nearestOfficeLocation!['distance'] ?? double.infinity;
    double allowedRadius =
        (_nearestOfficeLocation!['radius_meters'] as num?)?.toDouble() ?? 100.0;

    return distance <= allowedRadius;
  }

  // Getter untuk mendapatkan informasi lokasi yang akan ditampilkan
  String get _displayLocationInfo {
    if (_isLoadingLocation) return "Memuat lokasi...";
    if (_nearestOfficeLocation == null) return "Tidak ada kantor terdekat";

    return _locationInfo;
  }

  @override
  void initState() {
    super.initState();

    // Timer for real-time clock
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });

    // Animation controllers
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
    _getCurrentLocation();
    _loadOfficeLocations();
  }

  Future<void> _loadOfficeLocations() async {
    try {
      // Tambahkan timeout untuk request
      final tokenResponse = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResponse.statusCode == 200) {
        final tokenData = json.decode(tokenResponse.body);
        final token = tokenData['access_token'];

        // Panggil endpoint lokasi kantor dengan timeout
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
          final jsonData = json.decode(response.body);
          final List<dynamic> data = jsonData['data'] ?? [];

          if (mounted) {
            setState(() {
              _officeLocations = data
                  .map<Map<String, dynamic>>(
                    (item) => {
                      'id': item['id'],
                      // Handle berbagai format field name
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
        } else {
          throw Exception(
            'Gagal load lokasi kantor. Status: ${response.statusCode}',
          );
        }
      } else {
        throw Exception(
          'Gagal mendapatkan token. Status: ${tokenResponse.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationInfo = "Gagal memuat data kantor: ${e.toString()}";
          _isLoadingLocation = false;
        });
      }
      rethrow;
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLoadingLocation = true);

    // Cancel timer sebelumnya jika ada
    _locationTimer?.cancel();

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi tidak aktif. Silakan aktifkan GPS.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Izin lokasi ditolak secara permanen. Silakan aktifkan di pengaturan.',
        );
      }

      // Set timeout timer
      _locationTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _isLoadingLocation) {
          setState(() {
            _locationInfo = "Timeout mendapatkan lokasi. Silakan coba lagi.";
            _isLoadingLocation = false;
          });
        }
      });

      // Get current position dengan timeout dan akurasi tinggi
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Cancel timer karena sudah berhasil
      _locationTimer?.cancel();

      if (!mounted) return;

      //_currentPosition = position;
      _nearestOfficeLocation = _findNearestOffice(position);

      if (_nearestOfficeLocation != null) {
        double distance = _nearestOfficeLocation!['distance'];
        double allowedRadius = (_nearestOfficeLocation!['radius_meters'] as num)
            .toDouble();

        setState(() {
          _locationInfo = distance <= allowedRadius
              ? "Anda berada dalam radius ${_nearestOfficeLocation!['office_name']}"
              : "Anda di luar radius ${_nearestOfficeLocation!['office_name']} (${distance.toStringAsFixed(0)}m dari batas ${allowedRadius.toStringAsFixed(0)}m)";
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _locationInfo = "Tidak ada kantor terdekat yang ditemukan";
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      _locationTimer?.cancel();
      debugPrint('Error getting location: $e');

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

    Map<String, dynamic>? nearestOffice;
    double minDistance = double.infinity;

    for (var office in _officeLocations) {
      try {
        final double officeLat = (office['latitude'] as num).toDouble();
        final double officeLon = (office['longitude'] as num).toDouble();

        final double distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          officeLat,
          officeLon,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestOffice = Map<String, dynamic>.from(office);
          nearestOffice['distance'] = distance;
        }
      } catch (e) {
        debugPrint('Error calculating distance for office: $office, error: $e');
        continue;
      }
    }

    return nearestOffice;
  }

  @override
  void dispose() {
    _timer.cancel();
    _locationTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayAttendance() async {
    // Simulate loading today's attendance data
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _takeSelfie() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (photo != null) {
      setState(() {
        _todayAttendance.selfieImage = photo.path;
      });
    }
  }

  Future<void> _performCheckIn() async {
    setState(() => _isLoading = true);

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _todayAttendance.checkInTime = DateTime.now();
        _todayAttendance.checkInLocation =
            _nearestOfficeLocation?['office_name'] ?? 'Unknown Location';
        _todayAttendance.status = AttendanceStatus.checkedIn;
      });

      _showSuccessDialog(
        'Check In Berhasil!',
        'Anda berhasil melakukan check in pada ${DateFormat('HH:mm').format(DateTime.now())}',
      );
    } catch (e) {
      _showErrorDialog(
        'Gagal Check In',
        'Terjadi kesalahan saat melakukan check in. Silakan coba lagi.',
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
            _nearestOfficeLocation?['office_name'] ?? 'Unknown Location';
        _todayAttendance.status = AttendanceStatus.checkedOut;
      });

      _showSuccessDialog(
        'Check Out Berhasil!',
        'Anda berhasil melakukan check out pada ${DateFormat('HH:mm').format(DateTime.now())}.\n\nTotal waktu kerja: ${_todayAttendance.workingHours}',
      );
    } catch (e) {
      _showErrorDialog(
        'Gagal Check Out',
        'Terjadi kesalahan saat melakukan check out. Silakan coba lagi.',
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _performBreakStart() async {
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _todayAttendance.breakStartTime = DateTime.now();
        _todayAttendance.status = AttendanceStatus.onBreak;
      });

      _showSuccessDialog(
        'Istirahat Dimulai',
        'Waktu istirahat Anda telah dimulai.',
      );
    } catch (e) {
      _showErrorDialog(
        'Gagal Mulai Istirahat',
        'Terjadi kesalahan. Silakan coba lagi.',
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _performBreakEnd() async {
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _todayAttendance.breakEndTime = DateTime.now();
        _todayAttendance.status = AttendanceStatus.checkedIn;
      });

      _showSuccessDialog('Istirahat Selesai', 'Selamat kembali bekerja!');
    } catch (e) {
      _showErrorDialog(
        'Gagal Selesai Istirahat',
        'Terjadi kesalahan. Silakan coba lagi.',
      );
    }

    setState(() => _isLoading = false);
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
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

  Widget _buildCurrentTime() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF007AFF), const Color(0xFF5856D6)],
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
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('HH:mm:ss').format(_currentTime),
              style: const TextStyle(
                fontSize: 48,
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
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _displayLocationInfo,
                    style: const TextStyle(
                      fontSize: 14,
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
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
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
                Icon(Icons.today, color: const Color(0xFF007AFF), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Ringkasan Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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

            const SizedBox(height: 12),

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
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
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

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
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

  Widget _buildActionButtons() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Column(
        children: [
          if (_todayAttendance.status == AttendanceStatus.notCheckedIn) ...[
            _buildMainActionButton(
              'Check In',
              'Mulai hari kerja Anda',
              Icons.login,
              Colors.green,
              _isInOfficeArea ? _performCheckIn : null,
            ),
            if (!_isInOfficeArea)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anda berada di luar area kantor. Silakan pindah ke area kantor untuk melakukan check in.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          if (_todayAttendance.status == AttendanceStatus.checkedIn) ...[
            _buildMainActionButton(
              'Check Out',
              'Akhiri hari kerja Anda',
              Icons.logout,
              Colors.red,
              _performCheckOut,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryActionButton(
                    'Mulai Istirahat',
                    Icons.pause,
                    Colors.orange,
                    _performBreakStart,
                  ),
                ),
              ],
            ),
          ],

          if (_todayAttendance.status == AttendanceStatus.onBreak) ...[
            _buildMainActionButton(
              'Selesai Istirahat',
              'Kembali bekerja',
              Icons.play_arrow,
              Colors.green,
              _performBreakEnd,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryActionButton(
                    'Check Out',
                    Icons.logout,
                    Colors.red,
                    _performCheckOut,
                  ),
                ),
              ],
            ),
          ],

          if (_todayAttendance.status == AttendanceStatus.checkedOut) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Hari Kerja Selesai',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total waktu kerja: ${_todayAttendance.workingHours}',
                    style: TextStyle(fontSize: 14, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
          ],
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
      builder: (context, child) {
        return Transform.scale(
          scale: onPressed != null ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            height: 80,
            margin: const EdgeInsets.only(bottom: 8),
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
                        Icon(icon, size: 24),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecondaryActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentTime(),
                  _buildTodaysSummary(),
                  _buildActionButtons(),

                  const SizedBox(height: 20),

                  // Quick Actions
                  Container(
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
                            Icon(
                              Icons.flash_on,
                              color: const Color(0xFF007AFF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Aksi Cepat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionButton(
                                'Lihat Riwayat',
                                Icons.history,
                                Colors.blue,
                                () {
                                  // Navigate to attendance log
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickActionButton(
                                'Ambil Foto',
                                Icons.camera_alt,
                                Colors.green,
                                _takeSelfie,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
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
