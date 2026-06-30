// services/admin_notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:absensikaryawan/Screen%20admin/model/admin_notification_models.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminNotificationService {
  static const String _baseUrl = '$baseURL/api/admin/notifications';

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

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  Future<AdminNotificationResponse> getAllNotifications(
    AdminNotificationRequest request,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/list'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['Success'] == true || jsonResponse['success'] == true) {
          return AdminNotificationResponse.fromJson(
            jsonResponse['Data'] ?? jsonResponse['data'],
          );
        } else {
          throw Exception(jsonResponse['Message'] ?? jsonResponse['message']);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error loading notifications: $e');
    }
  }

  Future<AdminNotificationStats> getNotificationStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['Success'] == true || jsonResponse['success'] == true) {
          return AdminNotificationStats.fromJson(
            jsonResponse['Data'] ?? jsonResponse['data'],
          );
        } else {
          throw Exception(jsonResponse['Message'] ?? jsonResponse['message']);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error loading stats: $e');
    }
  }

  Future<bool> createNotification(CreateNotificationRequest request) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/create'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['Success'] == true || jsonResponse['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        final jsonResponse = jsonDecode(response.body);
        throw Exception(
          jsonResponse['Message'] ?? jsonResponse['message'] ?? 'Failed to create notification',
        );
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error creating notification: $e');
    }
  }

  Future<bool> uploadNotificationPdf(int notificationId, File pdfFile) async {
    try {
      final token = await _getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload-pdf/$notificationId'),
      );

      request.headers['Authorization'] = 'Bearer ${token ?? ''}';
      request.files.add(
        await http.MultipartFile.fromPath('pdfFile', pdfFile.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        return jsonResponse['Success'] == true || jsonResponse['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        final jsonResponse = jsonDecode(responseBody);
        throw Exception(jsonResponse['Message'] ?? jsonResponse['message'] ?? 'Failed to upload PDF');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Error uploading PDF: $e');
    }
  }

  Future<File> downloadNotificationPdf(
    int notificationId,
    String fileName,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/download-pdf/$notificationId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }

        Directory? downloadsDirectory;
        if (Platform.isAndroid) {
          downloadsDirectory = Directory('/storage/emulated/0/Download');
        } else if (Platform.isIOS) {
          downloadsDirectory = await getApplicationDocumentsDirectory();
        }

        if (downloadsDirectory == null) {
          throw Exception('Cannot access downloads directory');
        }

        final filePath = '${downloadsDirectory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else if (response.statusCode == 404) {
        throw Exception('File not found');
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Error downloading PDF: $e');
    }
  }

  // File picker helper for PDF
  Future<File?> pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          return File(path);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error picking PDF file: $e');
    }
  }

  bool isValidPdfFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return extension == 'pdf';
  }

  bool isFileSizeValid(File file, {int maxSizeInMB = 10}) {
    final fileSizeInBytes = file.lengthSync();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    return fileSizeInMB <= maxSizeInMB;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<bool> updateNotification(UpdateNotificationRequest request) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/update'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['Success'] == true || jsonResponse['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        final jsonResponse = jsonDecode(response.body);
        throw Exception(
          jsonResponse['Message'] ?? jsonResponse['message'] ?? 'Failed to update notification',
        );
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error updating notification: $e');
    }
  }

  Future<bool> deleteNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['Success'] == true || jsonResponse['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        final jsonResponse = jsonDecode(response.body);
        throw Exception(
          jsonResponse['Message'] ?? jsonResponse['message'] ?? 'Failed to delete notification',
        );
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error deleting notification: $e');
    }
  }

  Future<AdminNotification> getNotificationDetail(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/detail/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['Success'] == true || jsonResponse['success'] == true) {
          return AdminNotification.fromJson(
            jsonResponse['Data'] ?? jsonResponse['data'],
          );
        } else {
          throw Exception(jsonResponse['Message'] ?? jsonResponse['message']);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        throw Exception(
          'Failed to load notification detail: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error loading notification detail: $e');
    }
  }

  Future<List<UserForNotification>> getUsersForNotification() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['Success'] == true || jsonResponse['success'] == true) {
          final data = jsonResponse['Data'] ?? jsonResponse['data'];
          return (data as List)
              .map((item) => UserForNotification.fromJson(item))
              .toList();
        } else {
          throw Exception(jsonResponse['Message'] ?? jsonResponse['message']);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token expired');
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error loading users: $e');
    }
  }

  // Endpoint /types tidak ada di API — return list kosong agar filter "Semua" tetap berfungsi
  Future<List<NotificationTypeOption>> getNotificationTypes() async {
    return [];
  }
}
