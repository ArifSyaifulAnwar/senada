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
      final userId =
          await _getUserID(); // Perbaikan: Panggil function dengan await

      final body = jsonEncode({
        'UserId': userId, // Perbaikan: Gunakan nilai userId, bukan function
        'page': page,
        'pageSize': pageSize,
        'typeFilter': typeFilter,
        'unreadOnly': unreadOnly,
      });

      final response = await http.post(
        Uri.parse('$baseURL/api/notification/list'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['Success'] == true) {
          return NotificationListResponse.fromJson(jsonResponse['Data']);
        } else {
          throw Exception(
            jsonResponse['Message'] ?? 'Failed to get notifications',
          );
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  // Mark notification as read
  Future<bool> markAsRead({int? notificationId, bool markAll = false}) async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID(); // Tambahkan userId jika diperlukan

      final body = jsonEncode({
        'UserId': userId, // Tambahkan jika API memerlukan
        'notificationId': notificationId,
        'markAll': markAll,
      });

      final response = await http.post(
        Uri.parse('$baseURL/api/notification/mark-read'),
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

  // Get notification stats - Perbaikan: Ubah ke POST
  Future<NotificationStats> getNotificationStats() async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();

      final body = jsonEncode({'UserId': userId});

      final response = await http.post(
        // Ubah dari GET ke POST
        Uri.parse('$baseURL/api/notification/stats'),
        headers: headers,
        body: body, // Tambahkan body
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return NotificationStats.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to get stats');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to get notification stats: $e');
    }
  }

  // Get notification categories - Perbaikan: Ubah ke POST
  Future<List<NotificationCategory>> getNotificationCategories() async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();

      final body = jsonEncode({'UserId': userId});

      final response = await http.post(
        // Ubah dari GET ke POST
        Uri.parse('$baseURL/api/notification/categories'),
        headers: headers,
        body: body, // Tambahkan body
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['Success'] == true) {
          final categories =
              (jsonResponse['Data']['Categories'] as List<dynamic>?)
                  ?.map((item) => NotificationCategory.fromJson(item))
                  .toList() ??
              [];
          return categories;
        } else {
          throw Exception(
            jsonResponse['Message'] ?? 'Failed to get categories',
          );
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to get notification categories: $e');
    }
  }

  // Get unread count - Perbaikan: Ubah ke POST
  Future<Map<String, int>> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final userId = await _getUserID();

      final body = jsonEncode({'UserId': userId});

      final response = await http.post(
        // Ubah dari GET ke POST
        Uri.parse('$baseURL/api/notification/unread-count'),
        headers: headers,
        body: body, // Tambahkan body
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'];
          return {
            'unreadCount': data['unreadCount'] ?? 0,
            'unreadImportantCount': data['unreadImportantCount'] ?? 0,
            'totalCount': data['totalCount'] ?? 0,
          };
        } else {
          throw Exception(
            jsonResponse['message'] ?? 'Failed to get unread count',
          );
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return {'unreadCount': 0, 'unreadImportantCount': 0, 'totalCount': 0};
    }
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
