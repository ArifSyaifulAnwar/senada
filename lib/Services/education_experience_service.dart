// services/education_experience_service.dart
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';
import 'package:http/http.dart' as http;

class Education {
  final int id;
  final String userId;
  final String institution;
  final String degree;
  final String field;
  final int startYear;
  final int? endYear; // null = sedang bersekolah/kuliah
  final String? grade;

  Education({
    required this.id,
    required this.userId,
    required this.institution,
    required this.degree,
    required this.field,
    required this.startYear,
    this.endYear,
    this.grade,
  });

  String get period => endYear != null ? '$startYear - $endYear' : '$startYear - Sekarang';

  factory Education.fromJson(Map<String, dynamic> json) {
    dynamic get(String key) =>
        json[key] ?? json[key[0].toLowerCase() + key.substring(1)];
    return Education(
      id: get('Id'),
      userId: get('UserId') ?? '',
      institution: get('Institution') ?? '',
      degree: get('Degree') ?? '',
      field: get('Field') ?? '',
      startYear: get('StartYear') ?? 0,
      endYear: get('EndYear'),
      grade: get('Grade'),
    );
  }
}

class Experience {
  final int id;
  final String userId;
  final String company;
  final String position;
  final String startPeriod;
  final String? endPeriod; // null = masih bekerja di sini
  final String? description;

  Experience({
    required this.id,
    required this.userId,
    required this.company,
    required this.position,
    required this.startPeriod,
    this.endPeriod,
    this.description,
  });

  String get period => '$startPeriod - ${endPeriod ?? 'Sekarang'}';

  factory Experience.fromJson(Map<String, dynamic> json) {
    dynamic get(String key) =>
        json[key] ?? json[key[0].toLowerCase() + key.substring(1)];
    return Experience(
      id: get('Id'),
      userId: get('UserId') ?? '',
      company: get('Company') ?? '',
      position: get('Position') ?? '',
      startPeriod: get('StartPeriod') ?? '',
      endPeriod: get('EndPeriod'),
      description: get('Description'),
    );
  }
}

// Pendidikan & pengalaman 1 karyawan — dipakai Head HRD untuk lihat semua
// karyawan sekaligus (endpoint admin-list).
class EmployeeEducationExperienceGroup {
  final String userId;
  final String employeeName;
  final String? employeeJob;
  final String? department;
  final List<Education> educations;
  final List<Experience> experiences;

  EmployeeEducationExperienceGroup({
    required this.userId,
    required this.employeeName,
    this.employeeJob,
    this.department,
    required this.educations,
    required this.experiences,
  });

  factory EmployeeEducationExperienceGroup.fromJson(Map<String, dynamic> json) {
    dynamic get(String key) =>
        json[key] ?? json[key[0].toLowerCase() + key.substring(1)];
    final rawEdu = get('Educations') as List? ?? [];
    final rawExp = get('Experiences') as List? ?? [];
    return EmployeeEducationExperienceGroup(
      userId: get('UserId') ?? '',
      employeeName: get('EmployeeName') ?? '',
      employeeJob: get('EmployeeJob'),
      department: get('Department'),
      educations: rawEdu
          .map((e) => Education.fromJson(e as Map<String, dynamic>))
          .toList(),
      experiences: rawExp
          .map((e) => Experience.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});
}

class EducationExperienceService {
  Future<Map<String, String>> _getHeaders() => TokenService.jsonHeaders();

  static dynamic _get(Map<String, dynamic> body, String key) {
    if (body.containsKey(key)) return body[key];
    final lower = key[0].toLowerCase() + key.substring(1);
    if (body.containsKey(lower)) return body[lower];
    return null;
  }

  // ── PENDIDIKAN ───────────────────────────────────────────────────────────

  Future<ApiResponse<List<Education>>> getEducations(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/education/list'),
        headers: await _getHeaders(),
        body: jsonEncode({'userId': userId, 'includeInactive': false}),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final rawList = _get(body, 'Data') as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList.map((e) => Education.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return ApiResponse(success: false, message: (_get(body, 'Message') ?? 'Gagal mengambil data') as String);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<Education>> createEducation({
    required String userId,
    required String institution,
    required String degree,
    required String field,
    required int startYear,
    int? endYear,
    String? grade,
    String? actorUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/education/create'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'institution': institution,
          'degree': degree,
          'field': field,
          'startYear': startYear,
          'endYear': endYear,
          'grade': grade,
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final data = _get(body, 'Data');
        return ApiResponse(
          success: true,
          message: (_get(body, 'Message') ?? '') as String,
          data: data != null ? Education.fromJson(data) : null,
        );
      }
      return ApiResponse(success: false, message: (_get(body, 'Message') ?? 'Gagal menambah data') as String);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<Education>> updateEducation({
    required int id,
    required String userId,
    required String institution,
    required String degree,
    required String field,
    required int startYear,
    int? endYear,
    String? grade,
    String? actorUserId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseURL/api/asn/education/update'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'id': id,
          'userId': userId,
          'institution': institution,
          'degree': degree,
          'field': field,
          'startYear': startYear,
          'endYear': endYear,
          'grade': grade,
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final data = _get(body, 'Data');
        return ApiResponse(
          success: true,
          message: (_get(body, 'Message') ?? '') as String,
          data: data != null ? Education.fromJson(data) : null,
        );
      }
      return ApiResponse(success: false, message: (_get(body, 'Message') ?? 'Gagal memperbarui data') as String);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<void>> deleteEducation(
    int id,
    String userId, {
    String? actorUserId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseURL/api/asn/education/delete'),
        headers: await _getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId, 'actorUserId': actorUserId}),
      );
      final Map<String, dynamic> body = jsonDecode(response.body);
      return ApiResponse(
        success: _get(body, 'Success') == true,
        message: (_get(body, 'Message') ?? '') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // ── PENGALAMAN KERJA ─────────────────────────────────────────────────────

  Future<ApiResponse<List<Experience>>> getExperiences(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/experience/list'),
        headers: await _getHeaders(),
        body: jsonEncode({'userId': userId, 'includeInactive': false}),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final rawList = _get(body, 'Data') as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList.map((e) => Experience.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return ApiResponse(success: false, message: (_get(body, 'Message') ?? 'Gagal mengambil data') as String);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<Experience>> createExperience({
    required String userId,
    required String company,
    required String position,
    required String startPeriod,
    String? endPeriod,
    String? description,
    String? actorUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/experience/create'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'company': company,
          'position': position,
          'startPeriod': startPeriod,
          'endPeriod': endPeriod,
          'description': description,
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final data = _get(body, 'Data');
        return ApiResponse(
          success: true,
          message: (_get(body, 'Message') ?? '') as String,
          data: data != null ? Experience.fromJson(data) : null,
        );
      }
      return ApiResponse(success: false, message: (_get(body, 'Message') ?? 'Gagal menambah data') as String);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<Experience>> updateExperience({
    required int id,
    required String userId,
    required String company,
    required String position,
    required String startPeriod,
    String? endPeriod,
    String? description,
    String? actorUserId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseURL/api/asn/experience/update'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'id': id,
          'userId': userId,
          'company': company,
          'position': position,
          'startPeriod': startPeriod,
          'endPeriod': endPeriod,
          'description': description,
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final data = _get(body, 'Data');
        return ApiResponse(
          success: true,
          message: (_get(body, 'Message') ?? '') as String,
          data: data != null ? Experience.fromJson(data) : null,
        );
      }
      return ApiResponse(success: false, message: (_get(body, 'Message') ?? 'Gagal memperbarui data') as String);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<void>> deleteExperience(
    int id,
    String userId, {
    String? actorUserId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseURL/api/asn/experience/delete'),
        headers: await _getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId, 'actorUserId': actorUserId}),
      );
      final Map<String, dynamic> body = jsonDecode(response.body);
      return ApiResponse(
        success: _get(body, 'Success') == true,
        message: (_get(body, 'Message') ?? '') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // GET: Pendidikan & pengalaman SEMUA karyawan — khusus Head HRD.
  Future<ApiResponse<List<EmployeeEducationExperienceGroup>>> getAllForHrd(
    String hrdUserId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/education-experience/admin-list'),
        headers: await _getHeaders(),
        body: jsonEncode({'hrdUserId': hrdUserId}),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final rawList = _get(body, 'Data') as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList
              .map((e) => EmployeeEducationExperienceGroup.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
      return ApiResponse(success: false, message: (_get(body, 'Message') ?? 'Gagal mengambil data') as String);
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }
}
