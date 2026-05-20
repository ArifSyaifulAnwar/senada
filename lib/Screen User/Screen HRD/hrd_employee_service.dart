// File: Services/hrd_employee_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST MODELS
// ─────────────────────────────────────────────────────────────────────────────

class HrdUpdateEmployeeRequest {
  final int id;
  final String? name;
  final String? email;
  final String? phone;
  final String? additionalPhone;
  final String? gender;
  final String? placeOfBirth;
  final String? birthDate;
  final String? maritalStatus;
  final String? bloodType;
  final String? religion;
  final String? nik;
  final String? nip;
  final String? npwp;
  final String? passportNumber;
  final String? passportExpiry;
  final String? address;
  final String? citizenIdAddress;
  final String? residentialAddress;
  final String? postalCode;
  final String? department;
  final String? jobPosition;
  final String? jobLevel;
  final String? employmentStatus;
  final String? joinDate;
  final String? endContractDate;
  final String? manager;
  final String? approvalLine;
  final String? grade;
  final String? classLevel;
  final String? branch;
  final String? companyName;
  final String? statusDisplay;
  final List<String>? skills;
  final String? profilePhotoBase64;

  HrdUpdateEmployeeRequest({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.additionalPhone,
    this.gender,
    this.placeOfBirth,
    this.birthDate,
    this.maritalStatus,
    this.bloodType,
    this.religion,
    this.nik,
    this.nip,
    this.npwp,
    this.passportNumber,
    this.passportExpiry,
    this.address,
    this.citizenIdAddress,
    this.residentialAddress,
    this.postalCode,
    this.department,
    this.jobPosition,
    this.jobLevel,
    this.employmentStatus,
    this.joinDate,
    this.endContractDate,
    this.manager,
    this.approvalLine,
    this.grade,
    this.classLevel,
    this.branch,
    this.companyName,
    this.statusDisplay,
    this.skills,
    this.profilePhotoBase64,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'TargetId': id, // C# model pakai TargetId, bukan Id
    };

    void add(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      data[key] = value;
    }

    add('Name', name);
    add('Email', email);
    add('Phone', phone);
    add('AdditionalPhone', additionalPhone);
    add('Gender', gender);
    add('PlaceOfBirth', placeOfBirth);
    add('BirthDate', birthDate);
    add('MaritalStatus', maritalStatus);
    add('BloodType', bloodType);
    add('Religion', religion);
    add('Nik', nik);
    add('Nip', nip);
    add('Npwp', npwp);
    add('PassportNumber', passportNumber);
    add('PassportExpiry', passportExpiry);
    add('Address', address);
    add('CitizenIdAddress', citizenIdAddress);
    add('ResidentialAddress', residentialAddress);
    add('PostalCode', postalCode);
    add('Organization', department); // C# model pakai Organization
    add('JobPosition', jobPosition);
    add('JobLevel', jobLevel);
    add('EmploymentStatus', employmentStatus);
    add('JoinDate', joinDate);
    add('EndContractDate', endContractDate);
    add('Manager', manager);
    add('ApprovalLine', approvalLine);
    add('Grade', grade);
    add('ClassLevel', classLevel); // C# model pakai ClassLevel
    add('Branch', branch);
    add('StatusDisplay', statusDisplay);

    if (skills != null) data['Skills'] = skills;

    // Strip base64 prefix "data:image/jpeg;base64," kalau ada
    if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      String photo = profilePhotoBase64!;
      if (photo.contains(',')) photo = photo.split(',').last;
      photo = photo.trim().replaceAll(' ', '+');
      data['ProfilePhoto'] = photo;
    }

    return data;
  }
}

class HrdCreateEmployeeRequest {
  final String name;
  final String email;
  final String? phone;
  final String? department;
  final String? jobPosition;
  final String? jobLevel;
  final String? employmentStatus;
  final String? joinDate;
  final String? gender;
  final String? nik;
  final String? profilePhotoBase64;
  final List<String>? skills;

  HrdCreateEmployeeRequest({
    required this.name,
    required this.email,
    this.phone,
    this.department,
    this.jobPosition,
    this.jobLevel,
    this.employmentStatus,
    this.joinDate,
    this.gender,
    this.nik,
    this.profilePhotoBase64,
    this.skills,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'Name': name,
      'Mail': email,
    }; // C# pakai Mail

    void add(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      data[key] = value;
    }

    add('Phone', phone);
    add('Organization', department); // C# pakai Organization
    add('JobPosition', jobPosition);
    add('JobLevel', jobLevel);
    add('EmploymentStatus', employmentStatus);
    add('JoinDate', joinDate);
    add('Gender', gender);
    add('Nik', nik);

    if (skills != null) data['Skills'] = skills;

    if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      String photo = profilePhotoBase64!;
      if (photo.contains(',')) photo = photo.split(',').last;
      photo = photo.trim().replaceAll(' ', '+');
      data['ProfilePhoto'] = photo;
    }

    return data;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HRD EMPLOYEE SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class HrdEmployeeService {
  static const String _hrdUrl = '$baseURL/api/hrd/employee';

  // ── Auth helpers ──────────────────────────────────────────────────────────

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
        return data['access_token'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('UserID');
    } catch (_) {
      return null;
    }
  }

  // ── Konversi file foto → base64 ───────────────────────────────────────────

  static Future<String?> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting file to base64: $e');
      return null;
    }
  }

  // ── GET LIST ──────────────────────────────────────────────────────────────

  static Future<ApiResponse<EmployeeListResponse>> getEmployeeList({
    String? searchQuery,
    String? department,
    String? status,
    String? sortBy,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        return ApiResponse(
          success: false,
          message: 'UserId tidak ditemukan. Silakan login ulang.',
        );
      }

      final body = <String, dynamic>{
        'HrdUserId': userId, // pakai HrdUserId sesuai C# model
        'SortBy': sortBy ?? 'name_asc',
        'Page': page,
        'PageSize': pageSize,
      };
      if (searchQuery != null && searchQuery.isNotEmpty) {
        body['SearchQuery'] = searchQuery;
      }
      if (department != null && department.isNotEmpty) {
        body['Department'] = department;
      }
      if (status != null && status.isNotEmpty) {
        body['Status'] = status;
      }

      final response = await http
          .post(
            Uri.parse('$_hrdUrl/list'), // pakai hrd endpoint
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final j = jsonDecode(response.body);
        // API return lowercase success/message/data
        if (j['success'] == true && j['data'] != null) {
          return ApiResponse(
            success: true,
            message: j['message'] ?? 'Success',
            data: EmployeeListResponse.fromJson(j['data']),
          );
        }
        return ApiResponse(
          success: false,
          message: j['message'] ?? 'Gagal mengambil data',
        );
      }
      return ApiResponse(
        success: false,
        message: 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── GET DETAIL ────────────────────────────────────────────────────────────

  static Future<ApiResponse<EmployeeApiData>> getEmployeeDetail(int id) async {
    try {
      final hrdUserId = await _getCurrentUserId();
      if (hrdUserId == null) {
        return ApiResponse(success: false, message: 'UserID tidak ditemukan.');
      }

      final response = await http
          .post(
            Uri.parse('$_hrdUrl/detail'),
            headers: await _getHeaders(),
            body: jsonEncode({'HrdUserId': hrdUserId, 'TargetId': id}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final j = jsonDecode(response.body);
        if (j['success'] == true && j['data'] != null) {
          return ApiResponse(
            success: true,
            message: j['message'] ?? 'Success',
            data: EmployeeApiData.fromJson(j['data']),
          );
        }
        return ApiResponse(
          success: false,
          message: j['message'] ?? 'Data tidak ditemukan',
        );
      }
      return ApiResponse(
        success: false,
        message: 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  static Future<ApiResponse<EmployeeApiData>> createEmployee(
    HrdCreateEmployeeRequest request,
  ) async {
    try {
      final hrdUserId = await _getCurrentUserId();
      if (hrdUserId == null) {
        return ApiResponse(success: false, message: 'UserID tidak ditemukan.');
      }

      final body = request.toJson();
      body['HrdUserId'] = hrdUserId; // inject HrdUserId

      final response = await http
          .post(
            Uri.parse('$_hrdUrl/create'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final j = jsonDecode(response.body);
        if (j['success'] == true) {
          return ApiResponse(
            success: true,
            message: j['message'] ?? 'Karyawan berhasil dibuat',
            data: j['data'] != null
                ? EmployeeApiData.fromJson(j['data'])
                : null,
          );
        }
        return ApiResponse(
          success: false,
          message: j['message'] ?? 'Gagal membuat karyawan',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  static Future<ApiResponse<EmployeeApiData>> updateEmployee(
    HrdUpdateEmployeeRequest request,
  ) async {
    try {
      final hrdUserId = await _getCurrentUserId();
      if (hrdUserId == null) {
        return ApiResponse(
          success: false,
          message: 'UserID tidak ditemukan. Silakan login ulang.',
        );
      }

      final body = request.toJson();
      body['HrdUserId'] = hrdUserId; // inject HrdUserId — wajib untuk SP

      final response = await http
          .post(
            Uri.parse('$_hrdUrl/update'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final j = jsonDecode(response.body);
        if (j['success'] == true) {
          return ApiResponse(
            success: true,
            message: j['message'] ?? 'Data berhasil diperbarui',
            data: j['data'] != null
                ? EmployeeApiData.fromJson(j['data'])
                : null,
          );
        }
        return ApiResponse(
          success: false,
          message: j['message'] ?? 'Gagal memperbarui data',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  static Future<ApiResponse<void>> deleteEmployee(int id) async {
    try {
      final hrdUserId = await _getCurrentUserId();
      if (hrdUserId == null) {
        return ApiResponse(success: false, message: 'UserID tidak ditemukan.');
      }

      final response = await http
          .post(
            Uri.parse('$_hrdUrl/delete'),
            headers: await _getHeaders(),
            body: jsonEncode({'HrdUserId': hrdUserId, 'TargetId': id}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final j = jsonDecode(response.body);
        return ApiResponse(
          success: j['success'] ?? false,
          message: j['message'] ?? 'Selesai',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── UPDATE PHOTO ──────────────────────────────────────────────────────────

  static Future<ApiResponse<void>> updateEmployeePhoto(
    int id,
    String base64Photo,
  ) async {
    try {
      final hrdUserId = await _getCurrentUserId();
      if (hrdUserId == null) {
        return ApiResponse(success: false, message: 'UserID tidak ditemukan.');
      }

      // Strip prefix kalau ada
      String photo = base64Photo;
      if (photo.contains(',')) photo = photo.split(',').last;
      photo = photo.trim().replaceAll(' ', '+');

      final response = await http
          .post(
            Uri.parse('$_hrdUrl/update-photo'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'HrdUserId': hrdUserId,
              'TargetId': id,
              'ProfilePhoto': photo,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final j = jsonDecode(response.body);
        return ApiResponse(
          success: j['success'] ?? false,
          message: j['message'] ?? 'Foto berhasil diperbarui',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  static ApiResponse<T> _handleHttpError<T>(http.Response response) {
    try {
      final j = jsonDecode(response.body);
      return ApiResponse(
        success: false,
        message: j['message'] ?? j['Message'] ?? 'HTTP ${response.statusCode}',
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }
}
