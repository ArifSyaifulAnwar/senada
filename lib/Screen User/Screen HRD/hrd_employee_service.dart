// Services/hrd_employee_service.dart — FULL REPLACE
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Manager dropdown item ─────────────────────────────────────────────────────
class ManagerItem {
  final String userId;
  final String name;
  final String? jobPosition;
  final String? organization;

  const ManagerItem({
    required this.userId,
    required this.name,
    this.jobPosition,
    this.organization,
  });

  factory ManagerItem.fromJson(Map<String, dynamic> j) => ManagerItem(
    userId: j['userId']?.toString() ?? j['userid']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    jobPosition: j['jobPosition']?.toString() ?? j['job_position']?.toString(),
    organization: j['organization']?.toString(),
  );

  String get displayName => jobPosition != null && jobPosition!.isNotEmpty
      ? '$name ($jobPosition)'
      : name;
}

// ── Request models ────────────────────────────────────────────────────────────
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
  final String? bpjsKetenagakerjaan;
  final String? passportNumber;
  final String? passportExpiry;
  final String? address;
  final String? citizenIdAddress;
  final String? residentialAddress;
  final String? postalCode;
  final String? department; // → organization
  final String? jobPosition;
  final String? employmentStatus;
  final String? joinDate;
  final String? endContractDate;
  final String? managerUserId; // kirim userid manager, SP resolve name
  final String? branch;
  final String? companyName;
  final String? statusDisplay;
  final List<String>? skills;
  final String? profilePhotoBase64;

  const HrdUpdateEmployeeRequest({
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
    this.bpjsKetenagakerjaan,
    this.passportNumber,
    this.passportExpiry,
    this.address,
    this.citizenIdAddress,
    this.residentialAddress,
    this.postalCode,
    this.department,
    this.jobPosition,
    this.employmentStatus,
    this.joinDate,
    this.endContractDate,
    this.managerUserId,
    this.branch,
    this.companyName,
    this.statusDisplay,
    this.skills,
    this.profilePhotoBase64,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'TargetId': id};
    void add(String k, dynamic v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      data[k] = v;
    }

    add('Name', name);
    add('Mail', email);
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
    add('BpjsKetenagakerjaan', bpjsKetenagakerjaan);
    add('PassportNumber', passportNumber);
    add('PassportExpiry', passportExpiry);
    add('Address', address);
    add('CitizenIdAddress', citizenIdAddress);
    add('ResidentialAddress', residentialAddress);
    add('PostalCode', postalCode);
    add('Organization', department);
    add('JobPosition', jobPosition);
    add('EmploymentStatus', employmentStatus);
    add('JoinDate', joinDate);
    add('EndContractDate', endContractDate);
    add('ManagerUserId', managerUserId); // userid, bukan nama
    add('Branch', branch);
    add('CompanyName', companyName);
    add('StatusDisplay', statusDisplay);
    if (skills != null) data['Skills'] = skills;
    if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      String p = profilePhotoBase64!;
      if (p.contains(',')) p = p.split(',').last;
      data['ProfilePhoto'] = p.trim().replaceAll(' ', '+');
    }
    return data;
  }
}

class HrdCreateEmployeeRequest {
  final String name, email;
  final String? phone,
      department,
      jobPosition,
      employmentStatus,
      joinDate,
      gender,
      nik,
      profilePhotoBase64,
      bpjsKetenagakerjaan;
  final List<String>? skills;

  const HrdCreateEmployeeRequest({
    required this.name,
    required this.email,
    this.phone,
    this.department,
    this.jobPosition,
    this.employmentStatus,
    this.joinDate,
    this.gender,
    this.nik,
    this.profilePhotoBase64,
    this.bpjsKetenagakerjaan,
    this.skills,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'Name': name, 'Mail': email};
    void add(String k, dynamic v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      data[k] = v;
    }

    add('Phone', phone);
    add('Organization', department);
    add('JobPosition', jobPosition);
    add('EmploymentStatus', employmentStatus);
    add('JoinDate', joinDate);
    add('Gender', gender);
    add('Nik', nik);
    add('BpjsKetenagakerjaan', bpjsKetenagakerjaan);
    if (skills != null) data['Skills'] = skills;
    if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      String p = profilePhotoBase64!;
      if (p.contains(',')) p = p.split(',').last;
      data['ProfilePhoto'] = p.trim().replaceAll(' ', '+');
    }
    return data;
  }
}

// ── Service ───────────────────────────────────────────────────────────────────
class HrdEmployeeService {
  static const String _base = '$baseURL/api/hrd/employee';

  static Future<String?> _getToken() async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) return json.decode(r.body)['access_token'];
    } catch (_) {}
    return null;
  }

  static Future<Map<String, String>> _headers() async {
    final tok = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $tok',
    };
  }

  static Future<String?> _userId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('UserID');
  }

  static dynamic _get(Map<String, dynamic> j, String k) =>
      j[k[0].toUpperCase() + k.substring(1)] ?? j[k];

  // ── Employee list ───────────────────────────────────────────────────────────
  static Future<ApiResponse<EmployeeListResponse>> getEmployeeList({
    String? searchQuery,
    String? department,
    String? status,
    String? sortBy,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final uid = await _userId();
      if (uid == null || uid.isEmpty) {
        return ApiResponse(success: false, message: 'UserId tidak ditemukan');
      }

      final body = <String, dynamic>{
        'HrdUserId': uid,
        'SortBy': sortBy ?? 'name_asc',
        'Page': page,
        'PageSize': pageSize,
      };
      if (searchQuery?.isNotEmpty == true) body['SearchQuery'] = searchQuery;
      if (department?.isNotEmpty == true) body['Department'] = department;
      if (status?.isNotEmpty == true) body['Status'] = status;

      final r = await http
          .post(
            Uri.parse('$_base/list'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (_get(j, 'success') == true && _get(j, 'data') != null) {
          return ApiResponse(
            success: true,
            message: '',
            data: EmployeeListResponse.fromJson(_get(j, 'data')),
          );
        }
        return ApiResponse(
          success: false,
          message: _get(j, 'message') ?? 'Gagal mengambil data',
        );
      }
      return ApiResponse(success: false, message: 'HTTP ${r.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── Employee detail ─────────────────────────────────────────────────────────
  static Future<ApiResponse<EmployeeApiData>> getEmployeeDetail(int id) async {
    try {
      final uid = await _userId();
      final r = await http
          .post(
            Uri.parse('$_base/detail'),
            headers: await _headers(),
            body: jsonEncode({'HrdUserId': uid, 'TargetId': id}),
          )
          .timeout(const Duration(seconds: 20));

      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (_get(j, 'success') == true && _get(j, 'data') != null) {
          return ApiResponse(
            success: true,
            message: '',
            data: EmployeeApiData.fromJson(_get(j, 'data')),
          );
        }
        return ApiResponse(
          success: false,
          message: _get(j, 'message') ?? 'Data tidak ditemukan',
        );
      }
      return ApiResponse(success: false, message: 'HTTP ${r.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── Manager list (dropdown, sesuai PT) ─────────────────────────────────────
  static Future<ApiResponse<List<ManagerItem>>> getManagerList({
    String? excludeUserId,
  }) async {
    try {
      final uid = await _userId();
      final r = await http
          .post(
            Uri.parse('$_base/manager-list'),
            headers: await _headers(),
            body: jsonEncode({
              'HrdUserId': uid,
              if (excludeUserId != null) 'ExcludeUserId': excludeUserId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (_get(j, 'success') == true) {
          final raw = _get(j, 'data') as List? ?? [];
          return ApiResponse(
            success: true,
            message: '',
            data: raw
                .map((e) => ManagerItem.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
        return ApiResponse(success: false, message: _get(j, 'message') ?? '');
      }
      return ApiResponse(success: false, message: 'HTTP ${r.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── Create ──────────────────────────────────────────────────────────────────
  static Future<ApiResponse<EmployeeApiData>> createEmployee(
    HrdCreateEmployeeRequest req,
  ) async {
    try {
      final uid = await _userId();
      final body = req.toJson()..['HrdUserId'] = uid;
      final r = await http
          .post(
            Uri.parse('$_base/create'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _parseResponse<EmployeeApiData>(
        r,
        dataParser: (d) => EmployeeApiData.fromJson(d),
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────────
  static Future<ApiResponse<EmployeeApiData>> updateEmployee(
    HrdUpdateEmployeeRequest req,
  ) async {
    try {
      final uid = await _userId();
      final body = req.toJson()..['HrdUserId'] = uid;
      final r = await http
          .post(
            Uri.parse('$_base/update'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _parseResponse<EmployeeApiData>(
        r,
        dataParser: (d) => EmployeeApiData.fromJson(d),
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────
  static Future<ApiResponse<void>> deleteEmployee(int id) async {
    try {
      final uid = await _userId();
      final r = await http
          .post(
            Uri.parse('$_base/delete'),
            headers: await _headers(),
            body: jsonEncode({'HrdUserId': uid, 'TargetId': id}),
          )
          .timeout(const Duration(seconds: 20));
      return _parseResponse<void>(r);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  static ApiResponse<T> _parseResponse<T>(
    http.Response r, {
    T Function(Map<String, dynamic>)? dataParser,
  }) {
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final ok = (_get(j, 'success') == true);
      final msg = (_get(j, 'message') ?? '') as String;
      final raw = _get(j, 'data');
      return ApiResponse(
        success: ok,
        message: msg,
        data: ok && raw != null && dataParser != null
            ? dataParser(raw as Map<String, dynamic>)
            : null,
      );
    } catch (_) {
      return ApiResponse(success: false, message: 'HTTP ${r.statusCode}');
    }
  }
}
