import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class CompanyCalendarEvent {
  final int id;
  final DateTime tanggal;
  final String tipe; // 'LIBUR' | 'WFH' | 'LEMBUR'
  final String keterangan;
  final String createdBy;

  const CompanyCalendarEvent({
    required this.id,
    required this.tanggal,
    required this.tipe,
    required this.keterangan,
    required this.createdBy,
  });

  factory CompanyCalendarEvent.fromJson(Map<String, dynamic> j) =>
      CompanyCalendarEvent(
        id: j['Id'] ?? j['id'] ?? 0,
        tanggal:
            DateTime.tryParse(j['Tanggal'] ?? j['tanggal'] ?? '') ??
            DateTime.now(),
        tipe: j['Tipe'] ?? j['tipe'] ?? '',
        keterangan: j['Keterangan'] ?? j['keterangan'] ?? '',
        createdBy: j['CreatedBy'] ?? j['created_by'] ?? '',
      );

  bool get isLibur => tipe == 'LIBUR';
  bool get isWfh => tipe == 'WFH';
  bool get isLembur => tipe == 'LEMBUR';
}

class CompanyCalendarService {
  static final Map<int, List<CompanyCalendarEvent>> _cache = {};

  static Future<String?> _getToken() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return json.decode(res.body)['access_token'];
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Ambil semua event company untuk 1 tahun
  static Future<List<CompanyCalendarEvent>> getByYear(
    int tahun, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(tahun)) return _cache[tahun]!;

    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/calendar/list'),
            headers: await _headers(),
            body: json.encode({'tahun': tahun}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['Success'] == true || body['success'] == true) {
          final data = body['Data'] ?? body['data'] ?? [];
          final events = (data as List)
              .map((e) => CompanyCalendarEvent.fromJson(e))
              .toList();
          _cache[tahun] = events;
          return events;
        }
      }
    } catch (_) {}
    return _cache[tahun] ?? [];
  }

  // Ambil event per tanggal tertentu
  static List<CompanyCalendarEvent> getForDate(
    DateTime date,
    List<CompanyCalendarEvent> allEvents,
  ) {
    return allEvents
        .where(
          (e) =>
              e.tanggal.year == date.year &&
              e.tanggal.month == date.month &&
              e.tanggal.day == date.day,
        )
        .toList();
  }

  // Cek apakah tanggal libur (LIBUR atau weekend)
  static bool isHariLibur(DateTime date, List<CompanyCalendarEvent> allEvents) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }
    return allEvents.any(
      (e) =>
          e.isLibur &&
          e.tanggal.year == date.year &&
          e.tanggal.month == date.month &&
          e.tanggal.day == date.day,
    );
  }

  // Save (HRD only)
  static Future<Map<String, dynamic>> save({
    int? id,
    required String tanggal,
    required String tipe,
    required String keterangan,
    required String createdBy,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/calendar/save'),
            headers: await _headers(),
            body: json.encode({
              'id': id,
              'tanggal': tanggal,
              'tipe': tipe,
              'keterangan': keterangan,
              'createdBy': createdBy,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = json.decode(res.body);
      final success = body['Success'] ?? body['success'] ?? false;
      if (success) _cache.remove(int.tryParse(tanggal.substring(0, 4)));
      return {
        'success': success,
        'message': body['Message'] ?? body['message'] ?? 'Terjadi kesalahan',
        'id': body['Id'] ?? body['id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi bermasalah: $e'};
    }
  }

  // Delete (HRD only)
  static Future<Map<String, dynamic>> delete({
    required int id,
    required String deletedBy,
    required int tahun,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/calendar/delete'),
            headers: await _headers(),
            body: json.encode({'id': id, 'deletedBy': deletedBy}),
          )
          .timeout(const Duration(seconds: 15));

      final body = json.decode(res.body);
      final success = body['Success'] ?? body['success'] ?? false;
      if (success) _cache.remove(tahun);
      return {
        'success': success,
        'message': body['Message'] ?? body['message'] ?? 'Terjadi kesalahan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi bermasalah: $e'};
    }
  }

  static void clearCache() => _cache.clear();
}
