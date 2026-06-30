// Services/daily_activity_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:absensikaryawan/Services/config.dart';

import '../../models/dailyactivitymodels.dart';

class DailyActivityService {
  static String? _accessToken;

  static Future<void> _ensureToken({bool forceRefresh = false}) async {
    if (_accessToken != null && !forceRefresh) return;
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
        _accessToken = data['access_token'];
      } else {
        _accessToken = null;
      }
    } catch (_) {
      _accessToken = null;
    }
  }

  static Future<String> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('UserID') ?? '';
  }

  static Map<String, String> _headers() => {
    'Authorization': 'Bearer $_accessToken',
    'Content-Type': 'application/json',
  };

  /// Wrapper untuk semua POST request yang otomatis refresh token + retry sekali kalau 401
  static Future<http.Response> _authedPost(String url, {String? body}) async {
    await _ensureToken();
    var response = await http
        .post(Uri.parse(url), headers: _headers(), body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      await _ensureToken(forceRefresh: true);
      response = await http
          .post(Uri.parse(url), headers: _headers(), body: body)
          .timeout(const Duration(seconds: 30));
    }

    return response;
  }

  static Future<Uint8List?> downloadAttachmentBytes(int attachmentId) async {
    final userId = await _userId();
    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/attachment/download',
        body: json.encode({
          'RequestUserId': userId,
          'AttachmentId': attachmentId,
        }),
      );
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// Ambil daftar kategori aktivitas (master data dari tabel) — endpoint POST
  static Future<List<DailyActivityCategory>> getCategories() async {
    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/categories',
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> data = body['Data'] ?? body['data'] ?? [];
        return data.map((e) => DailyActivityCategory.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Ambil daftar lokasi kantor — endpoint POST di DailyActivityController
  static Future<List<OfficeLocation>> getOfficeLocations() async {
    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/office/locations',
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> data = body['data'] ?? body['Data'] ?? [];
        return data.map((e) => OfficeLocation.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Simpan aktivitas baru + lampiran (base64)
  static Future<bool> createActivity({
    required DateTime activityDate,
    required int categoryId,
    required String description,
    int? officeLocationId,
    String? locationText,
    TimeOfDayValue? startTime,
    TimeOfDayValue? endTime,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final userId = await _userId();

    final body = {
      'UserId': userId,
      'ActivityDate': activityDate.toIso8601String(),
      'CategoryId': categoryId,
      'Description': description,
      'OfficeLocationId': officeLocationId,
      'LocationText': locationText,
      'StartTime': startTime?.formatted,
      'EndTime': endTime?.formatted,
      'Attachments': attachments,
    };

    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/create',
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ambil semua aktivitas milik user yang login
  static Future<List<DailyActivityItem>> getMyActivities() async {
    final userId = await _userId();

    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/getByUser',
        body: json.encode({'RequestUserId': userId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> data = body['Data'] ?? body['data'] ?? [];
        return data.map((e) => DailyActivityItem.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Download isi file lampiran untuk preview
  static Future<List<int>?> downloadAttachment(int attachmentId) async {
    final userId = await _userId();

    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/attachment/download',
        body: json.encode({
          'RequestUserId': userId,
          'AttachmentId': attachmentId,
        }),
      );

      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
  // Services/daily_activity_service.dart — tambahkan method ini di dalam class DailyActivityService

  /// Ambil semua aktivitas karyawan di company yang sama (khusus HRD/Direktur)
  static Future<Map<String, dynamic>> getAllActivitiesHRD() async {
    final userId = await _userId();
    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/getAllHRD',
        body: json.encode({'RequestUserId': userId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['Data'] ?? {};
        final bool denied = data['AccessDenied'] ?? false;
        final String? message = data['Message'] ?? body['Message'];
        final List<dynamic> activitiesJson = data['Activities'] ?? [];

        return {
          'accessDenied': denied,
          'message': message,
          'activities': activitiesJson
              .map((e) => DailyActivityHRDItem.fromJson(e))
              .toList(),
        };
      }
    } catch (_) {}
    return {
      'accessDenied': true,
      'message': 'Gagal memuat data',
      'activities': <DailyActivityHRDItem>[],
    };
  }

  /// Download attachment milik karyawan lain (khusus HRD/Direktur)
  static Future<Uint8List?> downloadAttachmentBytesHRD(int attachmentId) async {
    final userId = await _userId();
    try {
      final response = await _authedPost(
        '$baseURL/api/dailyactivity/attachment/downloadHRD',
        body: json.encode({
          'RequestUserId': userId,
          'AttachmentId': attachmentId,
        }),
      );
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
