// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/face_recognition_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Services/dlservice.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class AbsensiScreen extends StatefulWidget {
  final bool isCheckOut;
  final bool showBackButton;

  const AbsensiScreen({
    super.key,
    this.isCheckOut = false,
    this.showBackButton = true,
  });

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  File? _capturedImage;
  Uint8List? _capturedImageBytes;

  // State
  String _locationInfo = "Memuat lokasi...";
  bool _isLoadingLocation = true;
  bool _isCheckOut = false;
  bool _isProcessingFace = false;
  bool _isFaceRegistered = false;
  String _faceVerificationMessage = "";
  bool _isAttendanceSubmitted = false;
  bool _isCompanyUser = false;

  // Auto-retry
  static const int _maxAutoRetry = 3;
  int _autoRetryCount = 0;
  bool _isAutoRetrying = false;
  Timer? _autoRetryTimer;
  int _retryCountdown = 0;

  // Location
  List<Map<String, dynamic>> _officeLocations = [];
  Map<String, dynamic>? _nearestOfficeLocation;
  Position? _currentPosition;

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Company Calendar ──────────────────────────────────────────────
  bool _isWeekend = false;
  bool _isHariLibur = false;
  bool _isWfh = false;
  String _keteranganHari = '';
  bool _isLoadingCalendar = true;

  @override
  void initState() {
    super.initState();
    _isCheckOut = widget.isCheckOut;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(_pulseController);

    _checkHariIni();
    _initializeApp();
    _detectUserMode();
  }

  // ── Cek hari ini dari company calendar ───────────────────────────
  Future<void> _checkHariIni() async {
    try {
      final today = DateTime.now();

      // Weekend check lokal dulu
      if (today.weekday == DateTime.saturday ||
          today.weekday == DateTime.sunday) {
        if (mounted) {
          setState(() {
            _isWeekend = true;
            _isHariLibur = true;
            _keteranganHari = today.weekday == DateTime.saturday
                ? 'Hari Sabtu'
                : 'Hari Minggu';
            _isLoadingCalendar = false;
          });
        }
        return;
      }

      // Cek via API
      final tokenResp = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResp.statusCode != 200) {
        if (mounted) setState(() => _isLoadingCalendar = false);
        return;
      }

      final token = json.decode(tokenResp.body)['access_token'];
      final tanggal =
          '${today.year}-${today.month.toString().padLeft(2, '0')}'
          '-${today.day.toString().padLeft(2, '0')}';

      final resp = await http
          .post(
            Uri.parse('$baseURL/api/calendar/check'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'tanggal': tanggal}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && mounted) {
        final body = json.decode(resp.body);
        setState(() {
          _isWeekend = body['IsWeekend'] ?? body['is_weekend'] ?? false;
          _isHariLibur = body['IsHariLibur'] ?? body['is_hari_libur'] ?? false;
          _isWfh = body['IsWfh'] ?? body['is_wfh'] ?? false;
          _keteranganHari = body['Keterangan'] ?? body['keterangan'] ?? '';
          _isLoadingCalendar = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingCalendar = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCalendar = false);
    }
  }

  Future<void> _detectUserMode() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID') ?? '';
    final email = prefs.getString('Email') ?? '';
    _isCompanyUser = await isCompanyUser(userId, email);
    await prefs.setBool('isCompanyUser', _isCompanyUser);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    _cameraController?.dispose();
    _autoRetryTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _loadOfficeLocations();
      await _checkPermissions();
      await _checkFaceRegistration();
      await _initializeCamera();
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationInfo = "Error saat inisialisasi: $e";
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      CameraDescription camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();

      if (_cameraController!.value.isInitialized) {
        try {
          await _cameraController!.setExposureMode(ExposureMode.auto);
          await _cameraController!.setFocusMode(FocusMode.auto);
        } catch (_) {}
      }
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _captureImageFromCamera({bool isAutoRetry = false}) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() {
        _isProcessingFace = true;
        _isAutoRetrying = isAutoRetry;
        _faceVerificationMessage = isAutoRetry
            ? "🔄 Coba ulang ($_autoRetryCount/$_maxAutoRetry)..."
            : "📸 Mengambil foto...";
      });

      await Future.delayed(Duration(milliseconds: isAutoRetry ? 1200 : 800));

      final XFile imageFile = await _cameraController!.takePicture();
      if (!mounted) return;

      final Uint8List imageBytes = await imageFile.readAsBytes();
      setState(() {
        _capturedImageBytes = imageBytes;
        if (!kIsWeb) _capturedImage = File(imageFile.path);
        _isAttendanceSubmitted = false;
        _faceVerificationMessage = "🔍 Memverifikasi wajah...";
      });

      await Future.delayed(const Duration(milliseconds: 100));
      await _processFaceRecognition();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingFace = false;
          _isAutoRetrying = false;
          _faceVerificationMessage = "❌ Error mengambil foto: ${e.toString()}";
        });
      }
    }
  }

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationInfo = "Gagal memuat data kantor: ${e.toString()}";
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _checkFaceRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID') ?? '';
      if (userId.isNotEmpty) {
        final result = await FaceRecognitionService.checkFaceRegistration(
          userId: userId,
        ).timeout(const Duration(seconds: 10));
        if (mounted) {
          setState(() => _isFaceRegistered = result['isRegistered'] ?? false);
        }
      }
    } catch (_) {}
  }

  Future<bool> isCompanyUser(String userId, String email) async {
    try {
      final tokenResp = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResp.statusCode != 200) return false;
      final token = json.decode(tokenResp.body)['access_token'];
      if (token == null || token.isEmpty) return false;

      final resp = await http
          .post(
            Uri.parse('$baseURL/api/asn/getCompanyInfo'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({"UserId": userId, "Mail": email}),
          )
          .timeout(const Duration(seconds: 10));

      return resp.statusCode == 200 && json.decode(resp.body) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _processFaceRecognition() async {
    if ((_capturedImage == null && _capturedImageBytes == null) || !mounted) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID') ?? '';

      if (userId.isEmpty) {
        setState(() {
          _isProcessingFace = false;
          _isAutoRetrying = false;
          _faceVerificationMessage = "User ID tidak ditemukan";
        });
        return;
      }

      final imageBase64 = kIsWeb
          ? base64Encode(_capturedImageBytes!)
          : FaceRecognitionService.fileToBase64(_capturedImage!);

      if (!FaceRecognitionService.isImageQualityGood(imageBase64)) {
        _scheduleAutoRetry("Foto kurang jelas, mengambil ulang...");
        return;
      }

      if (!_isFaceRegistered) {
        setState(() => _faceVerificationMessage = "Mendaftarkan wajah...");
        final registerResult = await FaceRecognitionService.registerFace(
          userId: userId,
          faceImageBase64: imageBase64,
        ).timeout(const Duration(seconds: 30));

        if (mounted) {
          if (registerResult['success']) {
            setState(() {
              _isFaceRegistered = true;
              _faceVerificationMessage =
                  "Wajah terdaftar. Memproses absensi...";
            });
            await Future.delayed(const Duration(seconds: 1));
            await _submitAttendance(userId, imageBase64);
          } else {
            _scheduleAutoRetry(
              registerResult['message'] ?? "Gagal mendaftarkan wajah",
            );
          }
        }
      } else {
        await _submitAttendance(userId, imageBase64);
      }
    } catch (e) {
      if (mounted) _scheduleAutoRetry("Error: ${e.toString()}");
    } finally {
      if (mounted && !_isAutoRetrying) {
        setState(() => _isProcessingFace = false);
      }
    }
  }

  void _scheduleAutoRetry(String failReason) {
    if (!mounted) return;
    if (_autoRetryCount < _maxAutoRetry) {
      _autoRetryCount++;
      _retryCountdown = 2;
      setState(() {
        _isAutoRetrying = true;
        _faceVerificationMessage =
            "⚠️ $failReason\n🔄 Coba ulang "
            "$_autoRetryCount/$_maxAutoRetry "
            "dalam $_retryCountdown detik...";
        _capturedImage = null;
        _capturedImageBytes = null;
      });

      _autoRetryTimer?.cancel();
      _autoRetryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _retryCountdown--;
          _faceVerificationMessage =
              "⚠️ $failReason\n🔄 Coba ulang "
              "$_autoRetryCount/$_maxAutoRetry "
              "dalam $_retryCountdown detik...";
        });
        if (_retryCountdown <= 0) {
          t.cancel();
          _captureImageFromCamera(isAutoRetry: true);
        }
      });
    } else {
      _autoRetryCount = 0;
      setState(() {
        _isProcessingFace = false;
        _isAutoRetrying = false;
        _faceVerificationMessage =
            "❌ $failReason\n\nCoba perbaiki: posisi wajah di tengah, "
            "pastikan cahaya cukup, hapus kacamata jika ada.";
      });
    }
  }

  Future<void> _submitAttendance(String userId, String imageBase64) async {
    try {
      if (mounted) {
        setState(
          () => _faceVerificationMessage =
              "Memverifikasi wajah dan mengirim absensi...",
        );
      }

      final verifyResult = await FaceRecognitionService.verifyFaceForAttendance(
        userId: userId,
        faceImageBase64: imageBase64,
        latitude: _currentPosition?.latitude ?? 0,
        longitude: _currentPosition?.longitude ?? 0,
        attendanceType: _isCheckOut ? 'checkout' : 'checkin',
      ).timeout(const Duration(seconds: 45));

      if (mounted) {
        if (verifyResult['success']) {
          _autoRetryCount = 0;
          setState(() {
            _isAttendanceSubmitted = true;
            _isAutoRetrying = false;
            _isProcessingFace = false;
            _faceVerificationMessage =
                verifyResult['message'] ?? "Absensi berhasil";
          });
          _showSuccessDialog(verifyResult);
        } else {
          final reason = verifyResult['message'] ?? "Verifikasi gagal";
          if (reason.contains('luar radius') ||
              reason.contains('radius kantor')) {
            _handleOutsideRadius(userId, imageBase64);
          } else {
            _scheduleAutoRetry(reason);
          }
        }
      }
    } catch (e) {
      if (mounted) _scheduleAutoRetry("Error koneksi: ${e.toString()}");
    }
  }

  void _handleOutsideRadius(String userId, String imageBase64) {
    if (!mounted) return;
    setState(() {
      _isProcessingFace = false;
      _isAutoRetrying = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange[700], size: 26),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Di Luar Radius Kantor',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Anda berada di luar radius kantor terdekat.\n\n'
              'Apakah Anda sedang dinas luar? '
              'Absensi Anda akan dicatat sebagai DINAS LUAR '
              'dan memerlukan persetujuan atasan serta upload bukti kegiatan.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Text(
                '⚠️ Bukti dinas luar wajib diupload setelah disetujui atasan.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _retakePhoto();
            },
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitAsDinasLuar(userId, imageBase64);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Dinas Luar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAsDinasLuar(String userId, String imageBase64) async {
    setState(() {
      _isProcessingFace = true;
      _faceVerificationMessage = '📋 Mengirim absensi dinas luar...';
    });

    final result = await DinasLuarService.submit(
      userId: userId,
      attendanceType: _isCheckOut ? 'checkout' : 'checkin',
      latitude: _currentPosition?.latitude ?? 0,
      longitude: _currentPosition?.longitude ?? 0,
      faceImageBase64: imageBase64,
    );

    if (!mounted) return;
    setState(() {
      _isProcessingFace = false;
      _isAttendanceSubmitted = result['success'] ?? false;
      _faceVerificationMessage = result['success'] == true
          ? '✅ Absensi dinas luar dikirim!\nMenunggu persetujuan atasan.'
          : '❌ ${result['message']}';
    });

    if (result['success'] == true) {
      _showDinasLuarSuccessDialog(result['request_id']);
    }
  }

  void _showDinasLuarSuccessDialog(int? requestId) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Dinas Luar Terkirim', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Absensi dinas luar Anda berhasil dikirim.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (requestId != null)
              Text(
                'No. Referensi: #$requestId',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 12),
            _stepInfo('1', 'Menunggu persetujuan atasan', Colors.orange),
            const SizedBox(height: 6),
            _stepInfo(
              '2',
              'Setelah disetujui, Anda akan diminta upload bukti',
              Colors.blue,
            ),
            const SizedBox(height: 6),
            _stepInfo(
              '3',
              'Setelah upload bukti, absensi tercatat otomatis',
              Colors.green,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _goBackToHome(attendanceSuccess: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _stepInfo(String num, String text, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            num,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
    ],
  );

  void _showSuccessDialog(Map<String, dynamic> result) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text(_isCheckOut ? "Check Out Berhasil" : "Check In Berhasil"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result['message'] ?? ''),
            if (result['timestamp'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Waktu: ${result['timestamp']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (result['office_name'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Lokasi: ${result['office_name']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (result['note'] != null) ...[
              const SizedBox(height: 8),
              Text(
                result['note'].toString(),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    _locationTimer?.cancel();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
            _locationInfo = "Timeout mendapatkan lokasi. Silakan coba lagi.";
            _isLoadingLocation = false;
          });
        }
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _locationTimer?.cancel();
      if (!mounted) return;

      _currentPosition = position;
      _nearestOfficeLocation = _findNearestOffice(position);

      if (_nearestOfficeLocation != null) {
        double distance = _nearestOfficeLocation!['distance'];
        double allowedRadius = (_nearestOfficeLocation!['radius_meters'] as num)
            .toDouble();
        setState(() {
          _locationInfo = distance <= allowedRadius
              ? "✅ Dalam radius ${_nearestOfficeLocation!['office_name']}"
              : "❌ Di luar radius ${_nearestOfficeLocation!['office_name']} "
                    "(${distance.toStringAsFixed(0)}m dari batas "
                    "${allowedRadius.toStringAsFixed(0)}m)";
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
        final double distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          (office['latitude'] as num).toDouble(),
          (office['longitude'] as num).toDouble(),
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestOffice = Map<String, dynamic>.from(office);
          nearestOffice['distance'] = distance;
        }
      } catch (_) {
        continue;
      }
    }
    return nearestOffice;
  }

  Future<void> _checkPermissions() async {
    try {
      var locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.location.request();
      }

      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      if (locationStatus.isGranted && cameraStatus.isGranted) {
        await _getCurrentLocation();
      } else {
        if (mounted) {
          setState(() {
            _locationInfo = "Izin diperlukan untuk akses lokasi dan kamera";
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationInfo = "Error memeriksa izin: ${e.toString()}";
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _retakePhoto() {
    _autoRetryTimer?.cancel();
    setState(() {
      _capturedImage = null;
      _capturedImageBytes = null;
      _isAttendanceSubmitted = false;
      _isAutoRetrying = false;
      _autoRetryCount = 0;
      _faceVerificationMessage = "";
      _isProcessingFace = false;
    });
  }

  void _refreshLocation() {
    _autoRetryTimer?.cancel();
    setState(() {
      _locationInfo = "Memuat lokasi...";
      _isLoadingLocation = true;
      _capturedImage = null;
      _capturedImageBytes = null;
      _isAttendanceSubmitted = false;
      _isAutoRetrying = false;
      _autoRetryCount = 0;
      _faceVerificationMessage = "";
      _isProcessingFace = false;
    });
    _getCurrentLocation();
  }

  void _goBackToHome({bool? attendanceSuccess}) {
    if (widget.showBackButton) Navigator.pop(context, attendanceSuccess);
  }

  // ── Banner hari libur / WFH ───────────────────────────────────────
  Widget _buildHariBanner() {
    if (_isLoadingCalendar) return const SizedBox.shrink();
    if (!_isHariLibur && !_isWfh) return const SizedBox.shrink();

    Color bgColor, borderColor, textColor;
    IconData icon;
    String title, subtitle;

    if (_isWeekend) {
      bgColor = Colors.red[50]!;
      borderColor = Colors.red[300]!;
      textColor = Colors.red[800]!;
      icon = Icons.weekend_rounded;
      title = _keteranganHari;
      subtitle =
          'Tombol absensi dinonaktifkan. '
          'Jika lembur, ajukan melalui fitur Lembur.';
    } else if (_isHariLibur) {
      bgColor = Colors.orange[50]!;
      borderColor = Colors.orange[300]!;
      textColor = Colors.orange[800]!;
      icon = Icons.beach_access_rounded;
      title = 'Hari Libur: $_keteranganHari';
      subtitle = 'Hari ini libur. Absensi tetap bisa dilakukan jika lembur.';
    } else {
      bgColor = const Color(0xFFE8F8F2);
      borderColor = const Color(0xFF10B981);
      textColor = const Color(0xFF065F46);
      icon = Icons.home_work_rounded;
      title = 'Work From Home (WFH)';
      subtitle = _keteranganHari.isNotEmpty
          ? _keteranganHari
          : 'Hari ini jadwal WFH. Absensi tetap dilakukan dari rumah.';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
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
      appBar: _buildAppBar(),
      body: SafeArea(child: isWeb ? _buildWebLayout() : _buildMobileLayout()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _isCheckOut ? 'Check Out Face ID' : 'Check In Face ID',
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: widget.showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
              onPressed: _isAutoRetrying
                  ? null
                  : () => _goBackToHome(
                      attendanceSuccess: _isAttendanceSubmitted,
                    ),
            )
          : null,
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: _isCheckOut ? Colors.red[400] : Colors.blue,
          ),
          onPressed: (_isLoadingLocation || _isAutoRetrying)
              ? null
              : _refreshLocation,
        ),
      ],
    );
  }

  // ── Mobile Layout ─────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHariBanner(), // ← banner libur/WFH
          _buildLocationInfo(),
          _buildCameraPreview(),
          _buildRetryIndicator(),
          _buildActionButton(),
          _buildTips(),
        ],
      ),
    );
  }

  // ── Web Layout ────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    final accentColor = _isCheckOut ? Colors.red[600]! : Colors.blue[700]!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.black,
            child: Column(
              children: [
                Expanded(child: _buildWebCameraArea()),
                if (_autoRetryCount > 0 || _isAutoRetrying)
                  _buildRetryIndicatorWeb(accentColor),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 320,
          child: Container(
            height: double.infinity,
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHariBanner(), // ← banner di web
                  if (_isHariLibur || _isWfh) const SizedBox(height: 12),
                  // Header mode
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isCheckOut ? Icons.logout : Icons.login,
                          color: accentColor,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isCheckOut ? 'Mode Check Out' : 'Mode Check In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLocationInfoWeb(),
                  const SizedBox(height: 16),
                  if (_faceVerificationMessage.isNotEmpty) ...[
                    _buildVerificationStatusWeb(),
                    const SizedBox(height: 16),
                  ],
                  _buildActionButtonWeb(accentColor),
                  const SizedBox(height: 16),
                  if (!_isAttendanceSubmitted && !_isProcessingFace)
                    _buildTipsWeb(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebCameraArea() =>
      (_capturedImage != null || _capturedImageBytes != null)
      ? _buildWebCapturedView()
      : _buildWebLiveCameraView();

  Widget _buildWebCapturedView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        kIsWeb
            ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
            : Image.file(_capturedImage!, fit: BoxFit.cover),
        if (_isProcessingFace)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isAutoRetrying
                            ? "🔄 Mencoba ulang..."
                            : "🔍 Memverifikasi wajah...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebLiveCameraView() {
    if (_isCameraInitialized && _cameraController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          RealtimeFaceGuide(
            isProcessing: _isProcessingFace,
            showRegistrationInfo: !_isFaceRegistered,
            isCheckOut: _isCheckOut,
          ),
        ],
      );
    }
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              "Mempersiapkan kamera...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfoWeb() {
    final isInside =
        _locationInfo.contains("Dalam") || _locationInfo.contains("✅");
    final isError =
        _locationInfo.contains("Error") ||
        _locationInfo.contains("Timeout") ||
        _locationInfo.contains("❌");
    final color = isInside
        ? Colors.green
        : isError
        ? Colors.red
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInside
                    ? Icons.location_on
                    : isError
                    ? Icons.location_off
                    : Icons.location_searching,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Lokasi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: (_isLoadingLocation || _isAutoRetrying)
                    ? null
                    : _refreshLocation,
                child: Icon(
                  Icons.refresh,
                  size: 16,
                  color: (_isLoadingLocation || _isAutoRetrying)
                      ? Colors.grey
                      : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _locationInfo,
            style: TextStyle(
              fontSize: 12,
              color: _isLoadingLocation ? Colors.grey[500] : Colors.black87,
            ),
          ),
          if (_isLoadingLocation) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(color: color),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationStatusWeb() {
    final color = _isProcessingFace
        ? Colors.blue
        : _isAttendanceSubmitted
        ? Colors.green
        : _isAutoRetrying
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isProcessingFace
                ? Icons.hourglass_top
                : _isAttendanceSubmitted
                ? Icons.check_circle
                : Icons.info_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _faceVerificationMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonWeb(Color accentColor) {
    final bool isInside =
        _locationInfo.contains("Dalam") || _locationInfo.contains("✅");
    final bool canTakePhoto =
        !_isProcessingFace && !_isAutoRetrying && isInside && !_isWeekend;

    final String label = _isProcessingFace
        ? "Memproses..."
        : _isAutoRetrying
        ? "Mencoba ulang..."
        : (_capturedImage == null && _capturedImageBytes == null)
        ? _isHariLibur && !_isWeekend
              ? "Absen (Lembur)"
              : _isWfh
              ? "Absen WFH"
              : "Ambil Foto"
        : _isAttendanceSubmitted
        ? "Foto Ulang"
        : "Coba Lagi";

    final Color btnColor = !canTakePhoto
        ? Colors.grey
        : _isWfh
        ? const Color(0xFF10B981)
        : _isHariLibur
        ? Colors.orange[700]!
        : accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: !canTakePhoto ? null : () => _captureImageFromCamera(),
          icon: Icon(
            _isProcessingFace ? Icons.hourglass_empty : Icons.camera_alt,
            color: Colors.white,
            size: 18,
          ),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            disabledBackgroundColor: Colors.grey[400],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        if (widget.showBackButton) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isAutoRetrying
                ? null
                : () =>
                      _goBackToHome(attendanceSuccess: _isAttendanceSubmitted),
            icon: Icon(Icons.arrow_back, size: 16, color: Colors.grey[700]),
            label: Text('Kembali', style: TextStyle(color: Colors.grey[700])),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTipsWeb() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "💡 Tips agar berhasil:",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blue[800],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          for (var tip in [
            "Posisikan wajah tepat di tengah oval",
            "Pastikan wajah terang, hindari cahaya belakang",
            "Lepaskan kacamata hitam atau masker",
            "Jaga jarak 30–50 cm dari kamera",
            "Tatap langsung ke kamera",
          ])
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "• $tip",
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRetryIndicatorWeb(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black87,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Percobaan otomatis: $_autoRetryCount / $_maxAutoRetry",
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              if (_retryCountdown > 0)
                Text(
                  "Dalam ${_retryCountdown}s...",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _autoRetryCount / _maxAutoRetry,
            backgroundColor: Colors.white24,
            color: color,
          ),
        ],
      ),
    );
  }

  // ── Mobile shared widgets ─────────────────────────────────────────
  Widget _buildLocationInfo() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isInside =
        _locationInfo.contains("Dalam") || _locationInfo.contains("✅");
    final isError =
        _locationInfo.contains("Error") ||
        _locationInfo.contains("Timeout") ||
        _locationInfo.contains("❌");

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      margin: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: isInside
            ? Colors.green[50]
            : isError
            ? Colors.red[50]
            : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInside
              ? Colors.green[300]!
              : isError
              ? Colors.red[300]!
              : Colors.orange[300]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isInside
                    ? Icons.location_on
                    : isError
                    ? Icons.location_off
                    : Icons.location_searching,
                color: isInside
                    ? Colors.green
                    : isError
                    ? Colors.red
                    : Colors.orange,
                size: screenWidth * 0.06,
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: Text(
                  _locationInfo,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _isLoadingLocation ? Colors.grey : Colors.black87,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ),
            ],
          ),
          if (_isLoadingLocation)
            Padding(
              padding: EdgeInsets.only(top: screenWidth * 0.02),
              child: const LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth,
      height: screenWidth * 1.33,
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: (_isCheckOut ? Colors.red : Colors.blue).withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: (_capturedImage != null || _capturedImageBytes != null)
            ? _buildCapturedImageView()
            : _buildLiveCameraView(),
      ),
    );
  }

  Widget _buildCapturedImageView() {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: kIsWeb
              ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
              : Image.file(_capturedImage!, fit: BoxFit.cover),
        ),
        if (_isProcessingFace)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isAutoRetrying
                            ? "🔄 Mencoba ulang..."
                            : "🔍 Memverifikasi wajah...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        _buildStatusOverlay(),
      ],
    );
  }

  Widget _buildLiveCameraView() {
    if (_isCameraInitialized && _cameraController != null) {
      return Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_cameraController!),
          ),
          RealtimeFaceGuide(
            isProcessing: _isProcessingFace,
            showRegistrationInfo: !_isFaceRegistered,
            isCheckOut: _isCheckOut,
          ),
        ],
      );
    }
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              "Mempersiapkan kamera...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    if (_faceVerificationMessage.isEmpty) return const SizedBox.shrink();

    Color bgColor = _isProcessingFace
        ? Colors.blue
        : _isAttendanceSubmitted
        ? Colors.green
        : _isAutoRetrying
        ? Colors.orange
        : Colors.red;

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _faceVerificationMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRetryIndicator() {
    if (_autoRetryCount == 0 && !_isAutoRetrying) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Percobaan otomatis: $_autoRetryCount / $_maxAutoRetry",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_retryCountdown > 0)
                Text(
                  "Dalam ${_retryCountdown}s...",
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _autoRetryCount / _maxAutoRetry,
            backgroundColor: Colors.orange[100],
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isInside =
        _locationInfo.contains("Dalam") || _locationInfo.contains("✅");
    final bool canTakePhoto =
        !_isProcessingFace && !_isAutoRetrying && isInside && !_isWeekend;

    final String label = _isProcessingFace
        ? "Memproses..."
        : _isAutoRetrying
        ? "Mencoba ulang..."
        : (_capturedImage == null && _capturedImageBytes == null)
        ? _isHariLibur && !_isWeekend
              ? "Absen (Lembur)"
              : _isWfh
              ? "Absen WFH"
              : "Ambil Foto"
        : _isAttendanceSubmitted
        ? "Foto Ulang"
        : "Coba Lagi";

    final Color btnColor = !canTakePhoto
        ? Colors.grey
        : _isWfh
        ? const Color(0xFF10B981)
        : _isHariLibur
        ? Colors.orange[700]!
        : (_isCheckOut ? Colors.red[500]! : Colors.blue[600]!);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(screenWidth * 0.04),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: _isAutoRetrying
                    ? null
                    : () => _goBackToHome(
                        attendanceSuccess: _isAttendanceSubmitted,
                      ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.grey[300],
                ),
                child: Text(
                  "Kembali",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: widget.showBackButton ? 2 : 1,
            child: ElevatedButton.icon(
              onPressed: !canTakePhoto
                  ? null
                  : (_capturedImage == null && _capturedImageBytes == null)
                  ? () => _captureImageFromCamera()
                  : _isAttendanceSubmitted
                  ? _retakePhoto
                  : () => _captureImageFromCamera(),
              icon: Icon(
                _isProcessingFace
                    ? Icons.hourglass_empty
                    : (_capturedImage == null && _capturedImageBytes == null) ||
                          !_isAttendanceSubmitted
                    ? Icons.camera_alt
                    : Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: btnColor,
                disabledBackgroundColor: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    if (_isAttendanceSubmitted || _isProcessingFace) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "💡 Tips agar berhasil:",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blue[800],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          for (var tip in [
            "Posisikan wajah tepat di tengah oval",
            "Pastikan wajah terang, hindari cahaya belakang",
            "Lepaskan kacamata hitam atau masker",
            "Jaga jarak 30–50 cm dari kamera",
            "Tatap langsung ke kamera",
          ])
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                "• $tip",
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// REALTIME FACE GUIDE (tidak berubah)
// ─────────────────────────────────────────────────────────────────
class RealtimeFaceGuide extends StatelessWidget {
  final bool isProcessing;
  final bool showRegistrationInfo;
  final bool isCheckOut;

  const RealtimeFaceGuide({
    super.key,
    required this.isProcessing,
    required this.showRegistrationInfo,
    this.isCheckOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width >= 768;
    final guideWidth = isWeb ? size.width * 0.25 : size.width * 0.6;
    final guideHeight = guideWidth * 1.2;
    final accentColor = isCheckOut ? Colors.red[300]! : Colors.blue[300]!;

    return Stack(
      children: [
        Container(color: Colors.black.withOpacity(0.35)),
        Center(
          child: Container(
            width: guideWidth,
            height: guideHeight,
            decoration: BoxDecoration(
              border: Border.all(
                color: isProcessing ? Colors.greenAccent : Colors.white,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(guideWidth * 0.6),
            ),
          ),
        ),
        Center(
          child: SizedBox(
            width: guideWidth,
            height: guideHeight,
            child: Stack(
              children: [
                _corner(top: 0, left: 0, t: true, l: true),
                _corner(top: 0, right: 0, t: true, r: true),
                _corner(bottom: 0, left: 0, b: true, l: true),
                _corner(bottom: 0, right: 0, b: true, r: true),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isProcessing
                  ? "⏳ Sedang memverifikasi..."
                  : "📷 Posisikan wajah dalam oval\n"
                        "Pastikan wajah terang & terlihat jelas",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (showRegistrationInfo && !isProcessing)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Wajah belum terdaftar – akan didaftarkan otomatis",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isProcessing)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Memproses foto...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool t = false,
    bool b = false,
    bool l = false,
    bool r = false,
  }) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: t
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
          bottom: b
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
          left: l
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
          right: r
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
        ),
      ),
    ),
  );
}
