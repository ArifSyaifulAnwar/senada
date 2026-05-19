// File: Services/hrd_employee_service.dart
// Service khusus HRD dengan kemampuan CRUD lengkap

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
  // Identity
  final int id;
  final String? name;
  final String? email;
  final String? phone;
  final String? additionalPhone;

  // Personal
  final String? gender;
  final String? placeOfBirth;
  final String? birthDate; // yyyy-MM-dd
  final String? maritalStatus;
  final String? bloodType;
  final String? religion;
  final String? nik;
  final String? nip;
  final String? npwp;
  final String? passportNumber;
  final String? passportExpiry; // yyyy-MM-dd

  // Address
  final String? address;
  final String? citizenIdAddress;
  final String? residentialAddress;
  final String? postalCode;

  // Employment
  final String? department;
  final String? jobPosition;
  final String? jobLevel;
  final String? employmentStatus;
  final String? joinDate; // yyyy-MM-dd
  final String? endContractDate; // yyyy-MM-dd
  final String? manager;
  final String? approvalLine;
  final String? grade;
  final String? classLevel;
  final String? branch;
  final String? companyName;
  final String? statusDisplay; // Aktif / Cuti / Non-Aktif

  // Skills
  final List<String>? skills;

  // Photo — base64 string (tanpa prefix data:image/...)
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
    final data = <String, dynamic>{'Id': id};
    void add(String key, dynamic value) {
      if (value != null) data[key] = value;
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
    add('Department', department);
    add('JobPosition', jobPosition);
    add('JobLevel', jobLevel);
    add('EmploymentStatus', employmentStatus);
    add('JoinDate', joinDate);
    add('EndContractDate', endContractDate);
    add('Manager', manager);
    add('ApprovalLine', approvalLine);
    add('Grade', grade);
    add('Class', classLevel);
    add('Branch', branch);
    add('CompanyName', companyName);
    add('StatusDisplay', statusDisplay);
    if (skills != null) data['Skills'] = skills;
    add('ProfilePhoto', profilePhotoBase64);
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
    final data = <String, dynamic>{'Name': name, 'Email': email};
    void add(String key, dynamic value) {
      if (value != null) data[key] = value;
    }

    add('Phone', phone);
    add('Department', department);
    add('JobPosition', jobPosition);
    add('JobLevel', jobLevel);
    add('EmploymentStatus', employmentStatus);
    add('JoinDate', joinDate);
    add('Gender', gender);
    add('Nik', nik);
    add('ProfilePhoto', profilePhotoBase64);
    if (skills != null) data['Skills'] = skills;
    return data;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HRD EMPLOYEE SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class HrdEmployeeService {
  static const String _baseUrl = '$baseURL/api/employee';
  static const String _hrdUrl = '$baseURL/api/hrd/employee';

  // ── Auth helpers ────────────────────────────────────────────────────────────
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
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'bearer $token',
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

  // ── Konversi file foto → base64 ─────────────────────────────────────────────
  static Future<String?> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting file to base64: $e');
      return null;
    }
  }

  // ── GET LIST (sama seperti EmployeeService, di-reuse) ───────────────────────
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
        'UserId': userId,
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
      if (status != null && status.isNotEmpty) body['Status'] = status;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/list'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['Success'] == true && json['Data'] != null) {
          return ApiResponse(
            success: true,
            message: json['Message'] ?? 'Success',
            data: EmployeeListResponse.fromJson(json['Data']),
          );
        }
        return ApiResponse(
          success: false,
          message: json['Message'] ?? 'Gagal mengambil data',
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

  // ── GET DETAIL ──────────────────────────────────────────────────────────────
  static Future<ApiResponse<EmployeeApiData>> getEmployeeDetail(int id) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/detail'),
            headers: await _getHeaders(),
            body: jsonEncode({'Id': id}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['Success'] == true && json['Data'] != null) {
          return ApiResponse(
            success: true,
            message: json['Message'] ?? 'Success',
            data: EmployeeApiData.fromJson(json['Data']),
          );
        }
        return ApiResponse(
          success: false,
          message: json['Message'] ?? 'Data tidak ditemukan',
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

  // ── CREATE (HRD) ────────────────────────────────────────────────────────────
  /// POST /api/hrd/employee/create
  static Future<ApiResponse<EmployeeApiData>> createEmployee(
    HrdCreateEmployeeRequest request,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_hrdUrl/create'),
            headers: await _getHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['Success'] == true) {
          return ApiResponse(
            success: true,
            message: json['Message'] ?? 'Karyawan berhasil dibuat',
            data: json['Data'] != null
                ? EmployeeApiData.fromJson(json['Data'])
                : null,
          );
        }
        return ApiResponse(
          success: false,
          message: json['Message'] ?? 'Gagal membuat karyawan',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── UPDATE (HRD) ────────────────────────────────────────────────────────────
  /// POST /api/hrd/employee/update
  static Future<ApiResponse<EmployeeApiData>> updateEmployee(
    HrdUpdateEmployeeRequest request,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_hrdUrl/update'),
            headers: await _getHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['Success'] == true) {
          return ApiResponse(
            success: true,
            message: json['Message'] ?? 'Data berhasil diperbarui',
            data: json['Data'] != null
                ? EmployeeApiData.fromJson(json['Data'])
                : null,
          );
        }
        return ApiResponse(
          success: false,
          message: json['Message'] ?? 'Gagal memperbarui data',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── DELETE (HRD) ────────────────────────────────────────────────────────────
  /// POST /api/hrd/employee/delete
  static Future<ApiResponse<void>> deleteEmployee(int id) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_hrdUrl/delete'),
            headers: await _getHeaders(),
            body: jsonEncode({'Id': id}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResponse(
          success: json['Success'] ?? false,
          message: json['Message'] ?? 'Selesai',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── UPDATE PHOTO ONLY ───────────────────────────────────────────────────────
  /// POST /api/hrd/employee/update-photo  (multipart atau base64)
  static Future<ApiResponse<void>> updateEmployeePhoto(
    int id,
    String base64Photo,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_hrdUrl/update-photo'),
            headers: await _getHeaders(),
            body: jsonEncode({'Id': id, 'ProfilePhoto': base64Photo}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResponse(
          success: json['Success'] ?? false,
          message: json['Message'] ?? 'Foto berhasil diperbarui',
        );
      }
      return _handleHttpError(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── Helper HTTP error ────────────────────────────────────────────────────────
  static ApiResponse<T> _handleHttpError<T>(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      return ApiResponse(
        success: false,
        message: json['Message'] ?? 'HTTP ${response.statusCode}',
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }
}
