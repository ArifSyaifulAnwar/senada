import 'dart:convert';
import 'dart:io';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class TimeOffService {
  static const String timeoffEndpoint = '/api/timeoff';

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

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'bearer $token',
    };
  }

  static Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _getToken();
    return {'Authorization': 'bearer $token'};
  }

  /// ✅ FIXED: Normalisasi jenis time off sebelum dikirim
  static String _normalizeJenisTimeOff(String jenis) {
    // Remove any leading/trailing whitespace and normalize internal spaces
    return jenis.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Submit time off request dengan file upload
  static Future<ApiResponse<int>> submitTimeOff(TimeOffRequest request) async {
    try {
      final url = Uri.parse('$baseURL$timeoffEndpoint/submit');

      // ✅ NORMALIZE jenis time off
      final normalizedJenis = _normalizeJenisTimeOff(request.jenisTimeOff);


      // ✅ ALWAYS use multipart request for consistency
      var multipartRequest = http.MultipartRequest('POST', url);

      // Add headers
      multipartRequest.headers.addAll(await _getMultipartHeaders());

      // ✅ Add request data as JSON field
      final requestData = {
        'userId': request.userId,
        'jenisTimeOff': normalizedJenis, // ✅ Use normalized value
        'tanggalMulai': request.tanggalMulai.toIso8601String(),
        'tanggalSelesai': request.tanggalSelesai.toIso8601String(),
        'catatan': request.catatan,
      };

      multipartRequest.fields['request'] = jsonEncode(requestData);

      // ✅ Add file ONLY if provided
      if (request.receiptFile != null) {
        String fileName = path.basename(request.receiptFile!.path);
        String fileExtension = path.extension(fileName).toLowerCase();

        MediaType mediaType;
        switch (fileExtension) {
          case '.pdf':
            mediaType = MediaType('application', 'pdf');
            break;
          case '.jpg':
          case '.jpeg':
            mediaType = MediaType('image', 'jpeg');
            break;
          case '.png':
            mediaType = MediaType('image', 'png');
            break;
          default:
            mediaType = MediaType('application', 'octet-stream');
        }

        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'receiptFile',
            request.receiptFile!.path,
            filename: fileName,
            contentType: mediaType,
          ),
        );

      } else {
      }

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);


      if (response.body.isEmpty) {
        return ApiResponse<int>(
          success: false,
          message: 'Server mengembalikan response kosong',
          data: null,
        );
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<int>.fromJson(jsonResponse, (data) => data as int);
      } else {
        return ApiResponse<int>(
          success: false,
          message:
              jsonResponse['message'] ??
              jsonResponse['Message'] ??
              'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<int>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Update time off dengan file upload - FIXED VERSION
  static Future<ApiResponse<Map<String, dynamic>>> updateTimeOff(
    UpdateTimeOffRequest request,
  ) async {
    try {
      final url = Uri.parse('$baseURL$timeoffEndpoint/update');

      // ✅ NORMALIZE jenis time off
      final normalizedJenis = _normalizeJenisTimeOff(request.jenisTimeOff);


      // ALWAYS use multipart request for consistency
      var multipartRequest = http.MultipartRequest('POST', url);

      // Add headers
      multipartRequest.headers.addAll(await _getMultipartHeaders());

      // Add form fields with normalized value
      multipartRequest.fields['id'] = request.id.toString();
      multipartRequest.fields['userId'] = request.userId;
      multipartRequest.fields['jenisTimeOff'] =
          normalizedJenis; // ✅ Use normalized
      multipartRequest.fields['tanggalMulai'] = request.tanggalMulai
          .toIso8601String();
      multipartRequest.fields['tanggalSelesai'] = request.tanggalSelesai
          .toIso8601String();
      if (request.catatan != null) {
        multipartRequest.fields['catatan'] = request.catatan!;
      }

      // Add file only if provided
      if (request.receiptFile != null) {
        String fileName = path.basename(request.receiptFile!.path);
        String fileExtension = path.extension(fileName).toLowerCase();

        MediaType mediaType;
        switch (fileExtension) {
          case '.pdf':
            mediaType = MediaType('application', 'pdf');
            break;
          case '.jpg':
          case '.jpeg':
            mediaType = MediaType('image', 'jpeg');
            break;
          case '.png':
            mediaType = MediaType('image', 'png');
            break;
          default:
            mediaType = MediaType('application', 'octet-stream');
        }

        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'receiptFile',
            request.receiptFile!.path,
            filename: fileName,
            contentType: mediaType,
          ),
        );
      }

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);


      if (response.body.isEmpty) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'Server response is empty. Status: ${response.statusCode}',
          data: null,
        );
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Get time off by user
  static Future<ApiResponse<TimeOffListResponse>> getMyTimeOff(
    String userId,
  ) async {
    try {
      final url = Uri.parse('$baseURL$timeoffEndpoint/my-timeoff');

      final requestBody = {'userId': userId};

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<TimeOffListResponse>.fromJson(
          jsonResponse,
          (data) => TimeOffListResponse.fromJson(data),
        );
      } else {
        return ApiResponse<TimeOffListResponse>(
          success: false,
          message: jsonResponse['Message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<TimeOffListResponse>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Delete time off
  static Future<ApiResponse<Map<String, dynamic>>> deleteTimeOff(
    DeleteTimeOffRequest request,
  ) async {
    try {
      final url = Uri.parse('$baseURL$timeoffEndpoint/delete');

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(request.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Download file attachment
  static Future<ApiResponse<List<int>>> downloadFile(
    int timeOffId,
    String userId,
  ) async {
    try {
      final url = Uri.parse('$baseURL$timeoffEndpoint/download-file');

      final requestBody = {'TimeOffId': timeOffId, 'UserId': userId};

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return ApiResponse<List<int>>(
          success: true,
          message: 'File downloaded successfully',
          data: response.bodyBytes,
        );
      } else {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return ApiResponse<List<int>>(
          success: false,
          message: jsonResponse['message'] ?? 'Gagal download file',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<List<int>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Validate file before upload
  static bool validateFile(File file) {
    try {
      if (!file.existsSync()) {
        return false;
      }

      final fileSize = file.lengthSync();
      const maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        return false;
      }

      final fileName = path.basename(file.path);
      final fileExtension = path.extension(fileName).toLowerCase();
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.pdf'];

      if (!allowedExtensions.contains(fileExtension)) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get file info
  static Map<String, dynamic> getFileInfo(File file) {
    try {
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(fileName).toLowerCase();
      final fileSize = file.lengthSync();
      final fileSizeInMB = fileSize / (1024 * 1024);

      String fileType;
      switch (fileExtension) {
        case '.pdf':
          fileType = 'PDF Document';
          break;
        case '.jpg':
        case '.jpeg':
          fileType = 'JPEG Image';
          break;
        case '.png':
          fileType = 'PNG Image';
          break;
        default:
          fileType = 'Unknown';
      }

      return {
        'fileName': fileName,
        'fileExtension': fileExtension,
        'fileSize': fileSize,
        'fileSizeInMB': fileSizeInMB,
        'fileType': fileType,
      };
    } catch (e) {
      return {};
    }
  }

  // Test database connection
  static Future<ApiResponse<Map<String, dynamic>>> testConnection() async {
    try {
      final url = Uri.parse('$baseURL$timeoffEndpoint/test-db');

      final response = await http.post(url, headers: await _getHeaders());

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: jsonResponse['message'] ?? 'Connection failed',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Network error: ${e.toString()}',
        data: null,
      );
    }
  }
}
