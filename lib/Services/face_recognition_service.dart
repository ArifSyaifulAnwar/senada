// file: lib/Services/face_recognition_service.dart (FIXED VERSION)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';

class FaceRecognitionService {
  // Convert File to Base64
  static String fileToBase64(File file) {
    List<int> imageBytes = file.readAsBytesSync();
    return base64Encode(imageBytes);
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

  // Check if face is registered (FIXED)
  static Future<Map<String, dynamic>> checkFaceRegistration({
    required String userId,
  }) async {
    try {
      if (userId.trim().isEmpty) {
        return {
          'success': false,
          'isRegistered': false,
          'message': 'User ID tidak boleh kosong',
        };
      }

      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'isRegistered': false,
          'message': 'Gagal mendapatkan token akses',
        };
      }

      // ✅ PERBAIKAN: Gunakan PascalCase
      final requestBody = {'UserId': userId.trim()}; // ✅ Changed from 'userId'

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/face/check-registration'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        return {
          'success': responseData['success'] ?? false,
          'isRegistered': responseData['isRegistered'] ?? false,
          'message': responseData['message'] ?? 'Status berhasil diperiksa',
        };
      } else {
        try {
          final responseData = json.decode(response.body);
          return {
            'success': false,
            'isRegistered': false,
            'message':
                responseData['message'] ??
                'Gagal memeriksa status registrasi wajah',
          };
        } catch (e) {
          return {
            'success': false,
            'isRegistered': false,
            'message':
                'Gagal memeriksa status registrasi wajah - Status ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'isRegistered': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> registerFace({
    required String userId,
    required String faceImageBase64,
  }) async {
    try {
      // Validasi input
      if (userId.trim().isEmpty) {
        return {'success': false, 'message': 'User ID tidak boleh kosong'};
      }

      if (faceImageBase64.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Data gambar wajah tidak boleh kosong',
        };
      }

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      // ✅ PERBAIKAN: Gunakan PascalCase untuk match C# Model
      final requestBody = {
        'UserId': userId.trim(), // ✅ Changed from 'userId'
        'FaceImageBase64': faceImageBase64
            .trim(), // ✅ Changed from 'faceImageBase64'
      };

      // Debug

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/face/register'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 45));

      // Debug
      // Debug

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          return {
            'success': responseData['success'] ?? false,
            'message': responseData['message'] ?? 'Wajah berhasil didaftarkan',
            'userId': responseData['userId'],
            'personId': responseData['personId'], // ✅ Added
            'persistedFaceId': responseData['persistedFaceId'], // ✅ Added
            'registeredAt': responseData['registeredAt'],
          };
        } catch (e) {
          // Debug
          return {
            'success': false,
            'message': 'Error parsing response: ${e.toString()}',
          };
        }
      } else {
        try {
          final responseData = json.decode(response.body);
          return {
            'success': false,
            'message':
                responseData['message'] ??
                responseData['Message'] ??
                'Gagal mendaftarkan wajah',
          };
        } catch (e) {
          return {
            'success': false,
            'message':
                'Gagal mendaftarkan wajah - Status ${response.statusCode}: ${response.body}',
          };
        }
      }
    } catch (e) {
      // Debug
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  // Verify face for attendance (FIXED)
  // Verify face for attendance (ENHANCED DEBUG)
  static Future<Map<String, dynamic>> verifyFaceForAttendance({
    required String userId,
    required String faceImageBase64,
    required double latitude,
    required double longitude,
    required String attendanceType,
  }) async {
    try {
      // Validasi input
      if (userId.trim().isEmpty) {
        return {'success': false, 'message': 'User ID tidak boleh kosong'};
      }

      if (faceImageBase64.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Data gambar wajah tidak boleh kosong',
        };
      }

      if (attendanceType.trim().isEmpty) {
        return {'success': false, 'message': 'Tipe absensi tidak boleh kosong'};
      }

      // Validasi attendance type
      final validTypes = ['checkin', 'checkout'];
      if (!validTypes.contains(attendanceType.trim().toLowerCase())) {
        return {
          'success': false,
          'message': 'Tipe absensi harus checkin atau checkout',
        };
      }

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      // ✅ PERBAIKAN: Gunakan PascalCase untuk match C# Model
      final requestBody = {
        'UserId': userId.trim(), // ✅ Changed from 'userId'
        'FaceImageBase64': faceImageBase64
            .trim(), // ✅ Changed from 'faceImageBase64'
        'Latitude': latitude, // ✅ Changed from 'latitude'
        'Longitude': longitude, // ✅ Changed from 'longitude'
        'AttendanceType': attendanceType
            .trim()
            .toLowerCase(), // ✅ Changed from 'attendanceType'
      };

      // Debug
      // Debug

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/face/verify-attendance'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 45));

      // Debug
      // Debug

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        return {
          'success': responseData['success'] ?? false,
          'message': responseData['message'] ?? 'Verifikasi berhasil',
          'confidence': responseData['confidence'],
          'timestamp': responseData['timestamp'],
          'office_name': responseData['office_name'],
          'status': responseData['status'],
          'attendance_type': responseData['attendance_type'],
        };
      } else {
        try {
          final responseData = json.decode(response.body);
          return {
            'success': false,
            'message':
                responseData['message'] ??
                responseData['Message'] ??
                'Verifikasi gagal - Status ${response.statusCode}',
          };
        } catch (e) {
          return {
            'success': false,
            'message':
                'Verifikasi gagal - Status ${response.statusCode}: ${response.body}',
          };
        }
      }
    } catch (e) {
      // Debug
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  // Get today's attendance (FIXED)
  static Future<Map<String, dynamic>> getTodayAttendance({
    required String userId,
  }) async {
    try {
      if (userId.trim().isEmpty) {
        return {'success': false, 'message': 'User ID tidak boleh kosong'};
      }

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      // ✅ PERBAIKAN: Gunakan PascalCase
      final requestBody = {'UserId': userId.trim()}; // ✅ Changed from 'userId'

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/attendance/today'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': responseData['success'] ?? false,
          'data': responseData['data'],
          'message': responseData['message'] ?? 'Data berhasil diambil',
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal mengambil data absensi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  // Get office locations (NEW)
  static Future<Map<String, dynamic>> getOfficeLocations() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      final response = await http
          .get(
            Uri.parse('$baseURL/api/asn/office/locations'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': responseData['success'] ?? false,
          'data': responseData['data'] ?? [],
          'message': responseData['message'] ?? 'Data lokasi berhasil diambil',
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message':
              responseData['message'] ?? 'Gagal mengambil data lokasi kantor',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  // Get attendance summary for dashboard (FIXED)
  static Future<Map<String, dynamic>> getAttendanceSummary({
    required String userId,
    String? month,
    String? year,
  }) async {
    try {
      if (userId.trim().isEmpty) {
        return {'success': false, 'message': 'User ID tidak boleh kosong'};
      }

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      final requestBody = {
        'userId': userId.trim(),
        'month': month,
        'year': year,
      };

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/attendance/summary'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': responseData['success'] ?? false,
          'data': responseData['data'],
          'message':
              responseData['message'] ?? 'Data ringkasan berhasil diambil',
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message':
              responseData['message'] ?? 'Gagal mengambil ringkasan absensi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  // Check if user can check in/out based on time and last attendance (IMPROVED)
  static Future<Map<String, dynamic>> checkAttendanceEligibility({
    required String userId,
    required String attendanceType,
  }) async {
    try {
      if (userId.trim().isEmpty) {
        return {
          'success': false,
          'canProceed': false,
          'message': 'User ID tidak boleh kosong',
        };
      }

      // ─── DETEKSI HARI ──────────────────────────────────────────────────────
      final now = DateTime.now();
      final weekday = now.weekday; // 1=Senin ... 6=Sabtu, 7=Minggu
      final isSaturday = weekday == DateTime.saturday; // 6
      final isSunday = weekday == DateTime.sunday; // 7

      // Hari Minggu: tidak ada absensi sama sekali
      if (isSunday) {
        return {
          'success': false,
          'canProceed': false,
          'isSaturday': false,
          'isWeekend': true,
          'message': 'Hari Minggu tidak ada jadwal kerja',
        };
      }

      final todayAttendance = await getTodayAttendance(userId: userId.trim());

      if (!todayAttendance['success']) {
        return {
          'success': false,
          'canProceed': false,
          'message': todayAttendance['message'],
        };
      }

      final data = todayAttendance['data'];
      final currentTime = TimeOfDay.fromDateTime(now);

      // ════════════════════════════════════════════════════════════════════════
      // SABTU — LEMBUR: tidak ada batas jam masuk, bisa kapan saja
      // ════════════════════════════════════════════════════════════════════════
      if (isSaturday) {
        // Batas paling awal boleh absen sabtu (misal 06:00 agar tidak absurd)
        const saturdayEarliestCheckIn = TimeOfDay(hour: 6, minute: 0);
        // Batas paling akhir checkout sabtu (misal 22:00)
        const saturdayLatestCheckOut = TimeOfDay(hour: 22, minute: 0);

        if (attendanceType.toLowerCase() == 'checkin') {
          if (data != null && data['checkInTime'] != null) {
            return {
              'success': false,
              'canProceed': false,
              'isSaturday': true,
              'message': 'Sudah check-in lembur hari ini',
            };
          }

          if (_isTimeBefore(currentTime, saturdayEarliestCheckIn)) {
            return {
              'success': false,
              'canProceed': false,
              'isSaturday': true,
              'message': 'Terlalu awal untuk absen lembur (min 06:00)',
            };
          }

          return {
            'success': true,
            'canProceed': true,
            'isSaturday': true,
            'message': '📋 Lembur Sabtu – check-in dapat dilakukan kapan saja',
          };
        }

        if (attendanceType.toLowerCase() == 'checkout') {
          if (data == null || data['checkInTime'] == null) {
            return {
              'success': false,
              'canProceed': false,
              'isSaturday': true,
              'message': 'Belum check-in lembur hari ini',
            };
          }
          if (data['checkOutTime'] != null) {
            return {
              'success': false,
              'canProceed': false,
              'isSaturday': true,
              'message': 'Sudah check-out lembur hari ini',
            };
          }

          if (!_isTimeBefore(currentTime, saturdayLatestCheckOut)) {
            return {
              'success': false,
              'canProceed': false,
              'isSaturday': true,
              'message': 'Sudah melewati batas waktu checkout lembur (22:00)',
            };
          }

          return {
            'success': true,
            'canProceed': true,
            'isSaturday': true,
            'message': '📋 Lembur Sabtu – check-out lembur',
          };
        }
      }

      // ════════════════════════════════════════════════════════════════════════
      // SENIN – JUMAT — Logika normal
      // ════════════════════════════════════════════════════════════════════════
      const checkInStart = TimeOfDay(hour: 7, minute: 0);
      const checkInEnd = TimeOfDay(hour: 10, minute: 0);
      const checkOutStart = TimeOfDay(hour: 16, minute: 0);
      const checkOutEnd = TimeOfDay(hour: 20, minute: 0);

      if (attendanceType.toLowerCase() == 'checkin') {
        if (data != null && data['checkInTime'] != null) {
          return {
            'success': false,
            'canProceed': false,
            'isSaturday': false,
            'message': 'Anda sudah melakukan check in hari ini',
          };
        }

        if (_isTimeInRange(currentTime, checkInStart, checkInEnd)) {
          return {
            'success': true,
            'canProceed': true,
            'isSaturday': false,
            'message': 'Anda dapat melakukan check in',
          };
        } else {
          final msg = _isTimeBefore(currentTime, checkInStart)
              ? 'Check in belum dapat dilakukan. Waktu check in: 07:00 – 10:00'
              : 'Waktu check in telah berakhir. Waktu check in: 07:00 – 10:00';
          return {
            'success': false,
            'canProceed': false,
            'isSaturday': false,
            'message': msg,
          };
        }
      }

      if (attendanceType.toLowerCase() == 'checkout') {
        if (data == null || data['checkInTime'] == null) {
          return {
            'success': false,
            'canProceed': false,
            'isSaturday': false,
            'message': 'Anda belum melakukan check in hari ini',
          };
        }
        if (data['checkOutTime'] != null) {
          return {
            'success': false,
            'canProceed': false,
            'isSaturday': false,
            'message': 'Anda sudah melakukan check out hari ini',
          };
        }

        if (_isTimeInRange(currentTime, checkOutStart, checkOutEnd)) {
          return {
            'success': true,
            'canProceed': true,
            'isSaturday': false,
            'message': 'Anda dapat melakukan check out',
          };
        } else {
          final msg = _isTimeBefore(currentTime, checkOutStart)
              ? 'Check out belum dapat dilakukan. Waktu check out: 16:00 – 20:00'
              : 'Waktu check out telah berakhir. Waktu check out: 16:00 – 20:00';
          return {
            'success': false,
            'canProceed': false,
            'isSaturday': false,
            'message': msg,
          };
        }
      }

      return {
        'success': false,
        'canProceed': false,
        'message': 'Tipe absensi tidak valid',
      };
    } catch (e) {
      return {
        'success': false,
        'canProceed': false,
        'message': 'Terjadi kesalahan: ${e.toString()}',
      };
    }
  }

  // Helper methods for time comparison
  static bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  static bool _isTimeBefore(TimeOfDay time, TimeOfDay reference) {
    final timeMinutes = time.hour * 60 + time.minute;
    final refMinutes = reference.hour * 60 + reference.minute;

    return timeMinutes < refMinutes;
  }

  // Format attendance status for display
  static String formatAttendanceStatus(String? status) {
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
        return '-';
    }
  }

  // Format time for display
  static String formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '-';

    try {
      final dateTime = DateTime.parse(timeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeString;
    }
  }

  // Calculate working hours
  static String formatWorkingHours(int? minutes) {
    if (minutes == null) return '-';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    return '${hours}j ${remainingMinutes}m';
  }

  // Validate image quality (NEW)
  static bool isImageQualityGood(String base64Image) {
    try {
      // Check base64 string length (rough quality indicator)
      if (base64Image.length < 10000) {
        // Less than ~7.5KB
        return false;
      }

      if (base64Image.length > 5000000) {
        // More than ~3.75MB
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

}
