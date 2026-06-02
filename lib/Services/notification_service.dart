// Services/notification_service.dart

import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/models/notification_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  String? userId;
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

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Perbaikan: Ubah return type dan implementasi
  Future<String?> _getUserID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('UserID');
    return userId;
  }

  // Get user notifications
  Future<NotificationListResponse> getUserNotifications({
    int page = 1,
    int pageSize = 20,
    String? typeFilter,
    bool unreadOnly = false,
  }) async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();

      final body = jsonEncode({
        'UserId': userId,
        'Page': page, // ← uppercase sesuai model C#
        'PageSize': pageSize,
        'TypeFilter': typeFilter,
        'UnreadOnly': unreadOnly,
      });

      final response = await http.post(
        Uri.parse('$baseURL/api/notification/list'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        // Controller: Ok(new ApiResponse<NotificationListResponse> { Data = result })
        if (d['Success'] == true) {
          return NotificationListResponse.fromJson(d['Data']);
        } else {
          throw Exception(d['Message'] ?? 'Failed to get notifications');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  Future<Map<String, int>> getAdminNotificationStats() async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .post(
            Uri.parse('$baseURL/api/admin/notifications/stats'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d['Success'] == true) {
          final data = d['Data'];
          return {
            'unreadCount': data['UnreadCount'] ?? 0,
            'totalCount': data['TotalNotifications'] ?? 0,
          };
        }
      }
    } catch (_) {}
    return {'unreadCount': 0, 'totalCount': 0};
  }

  // Mark notification as read
  Future<bool> markAsRead({int? notificationId, bool markAll = false}) async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();

      final body = jsonEncode({
        'UserId': userId,
        'NotificationId': notificationId, // ← uppercase
        'MarkAll': markAll, // ← uppercase
      });

      final response = await http.post(
        Uri.parse('$baseURL/api/notification/mark-read'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        return d['Success'] == true; // ← uppercase
      }
    } catch (_) {}
    return false;
  }

  // Get notification stats - Perbaikan: Ubah ke POST
  Future<NotificationStats> getNotificationStats() async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();
      final body = jsonEncode({'UserId': userId});

      final response = await http
          .post(
            Uri.parse('$baseURL/api/notification/stats'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        // Controller return ApiResponse<NotificationStats>
        if (d['Success'] == true) {
          return NotificationStats.fromJson(d['Data']);
        }
      }
    } catch (_) {}
    return NotificationStats(
      totalNotifications: 0,
      unreadCount: 0,
      unreadImportantCount: 0,
      thisWeekCount: 0,
      typeStats: [],
    );
  }

  // Get notification categories - Perbaikan: Ubah ke POST
  Future<List<NotificationCategory>> getNotificationCategories() async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();
      final body = jsonEncode({'UserId': userId});

      final response = await http.post(
        Uri.parse('$baseURL/api/notification/categories'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        if (d['Success'] == true) {
          // Controller: ApiResponse<NotificationCategoriesResponse>
          // Data.Categories adalah list
          final categories = (d['Data']['Categories'] as List<dynamic>? ?? [])
              .map((item) => NotificationCategory.fromJson(item))
              .toList();
          return categories;
        }
      }
    } catch (_) {}
    return [];
  }

  // Get unread count - Perbaikan: Ubah ke POST
  // Di notification_service.dart, ganti getUnreadCount():
  // Di notification_service.dart, ganti getUnreadCount():
  Future<Map<String, int>> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();
      final body = jsonEncode({'UserId': userId});

      final response = await http
          .post(
            Uri.parse('$baseURL/api/notification/unread-count'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final d = jsonDecode(response.body);
        // Controller return ApiResponse → key 'Success' (uppercase)
        if (d['Success'] == true) {
          final data = d['Data'];
          return {
            'unreadCount': data['UnreadCount'] ?? 0,
            'unreadImportantCount': data['UnreadImportantCount'] ?? 0,
            'totalCount': data['TotalCount'] ?? 0,
          };
        }
      }
    } catch (_) {}
    return {'unreadCount': 0, 'unreadImportantCount': 0, 'totalCount': 0};
  }

  // Create notification (for testing purposes or admin functions)
  Future<bool> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
    String? referenceType,
    bool isImportant = false,
    String? actionText,
    String? actionUrl,
    DateTime? expiresAt,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = jsonEncode({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'referenceId': referenceId,
        'referenceType': referenceType,
        'isImportant': isImportant,
        'actionText': actionText,
        'actionUrl': actionUrl,
        'expiresAt': expiresAt?.toIso8601String(),
      });

      final response = await http.post(
        Uri.parse('$baseURL/api/notification/create'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return false;
    }
  }
}
