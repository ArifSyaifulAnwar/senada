import 'dart:convert';

import 'package:intl/intl.dart';

import 'config.dart';
import 'token_service.dart';

class PrayerScheduleEntry {
  final int? weekday;
  final String prayerCode;
  final String muadzinUserId;
  final String muadzinName;
  final String imamUserId;
  final String imamName;
  final bool isOverride;

  const PrayerScheduleEntry({
    this.weekday,
    required this.prayerCode,
    required this.muadzinUserId,
    required this.muadzinName,
    required this.imamUserId,
    required this.imamName,
    this.isOverride = false,
  });

  factory PrayerScheduleEntry.fromJson(Map<String, dynamic> value) {
    String field(String snake, String pascal) =>
        (value[snake] ?? value[pascal] ?? '').toString();
    return PrayerScheduleEntry(
      weekday: int.tryParse((value['weekday'] ?? value['Weekday'] ?? '').toString()),
      prayerCode: field('prayer_code', 'PrayerCode'),
      muadzinUserId: field('muadzin_user_id', 'MuadzinUserId'),
      muadzinName: field('muadzin_name', 'MuadzinName'),
      imamUserId: field('imam_user_id', 'ImamUserId'),
      imamName: field('imam_name', 'ImamName'),
      isOverride: value['is_override'] == true || value['IsOverride'] == true,
    );
  }
}

class PrayerScheduleService {
  static Future<List<PrayerScheduleEntry>> weekly() async {
    final response = await TokenService.authorizedPost(
      Uri.parse('$baseURL/api/employee/prayer-schedule-weekly-list'),
      body: jsonEncode({}),
    );
    return _readList(response.statusCode, response.body);
  }

  static Future<void> saveWeekly({
    required int weekday,
    required String prayerCode,
    required String muadzinUserId,
    required String imamUserId,
  }) async {
    await _saveRequest('prayer-schedule-weekly-save', {
      'weekday': weekday,
      'prayerCode': prayerCode,
      'muadzinUserId': muadzinUserId,
      'imamUserId': imamUserId,
    });
  }
  static Future<List<PrayerScheduleEntry>> defaults() async {
    final response = await TokenService.authorizedPost(
      Uri.parse('$baseURL/api/employee/prayer-schedule-default-list'),
      body: jsonEncode({}),
    );
    return _readList(response.statusCode, response.body);
  }

  static Future<List<PrayerScheduleEntry>> list(DateTime date) async {
    final response = await TokenService.authorizedPost(
      Uri.parse('$baseURL/api/employee/prayer-schedule-list'),
      body: jsonEncode({'tanggal': DateFormat('yyyy-MM-dd').format(date)}),
    );
    return _readList(response.statusCode, response.body);
  }

  static List<PrayerScheduleEntry> _readList(
    int statusCode,
    String responseBody,
  ) {
    if (statusCode == 404) {
      throw StateError(
        'Endpoint jadwal salat belum tersedia di API. Deploy API terbaru.',
      );
    }
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    if (statusCode != 200 || (body['success'] ?? body['Success']) != true) {
      throw StateError(
        (body['message'] ??
                body['Message'] ??
                'Jadwal salat belum dapat dimuat.')
            .toString(),
      );
    }
    final data = body['data'] ?? body['Data'] ?? [];
    return (data as List)
        .map((e) => PrayerScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveDefault({
    required String prayerCode,
    required String muadzinUserId,
    required String imamUserId,
  }) async {
    await _saveRequest('prayer-schedule-default-save', {
      'prayerCode': prayerCode,
      'muadzinUserId': muadzinUserId,
      'imamUserId': imamUserId,
    });
  }

  static Future<void> save({
    required DateTime date,
    required String prayerCode,
    required String muadzinUserId,
    required String imamUserId,
  }) async {
    await _saveRequest('prayer-schedule-save', {
      'tanggal': DateFormat('yyyy-MM-dd').format(date),
      'prayerCode': prayerCode,
      'muadzinUserId': muadzinUserId,
      'imamUserId': imamUserId,
    });
  }

  static Future<void> deleteOverride({
    required DateTime date,
    required String prayerCode,
  }) async {
    await _saveRequest('prayer-schedule-override-delete', {
      'tanggal': DateFormat('yyyy-MM-dd').format(date),
      'prayerCode': prayerCode,
    });
  }

  static Future<void> _saveRequest(
    String route,
    Map<String, dynamic> data,
  ) async {
    final response = await TokenService.authorizedPost(
      Uri.parse('$baseURL/api/employee/$route'),
      body: jsonEncode(data),
    );
    if (response.statusCode == 404) {
      throw StateError(
        'Endpoint simpan jadwal salat belum tersedia di API. Deploy API terbaru.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 ||
        (body['success'] ?? body['Success']) != true) {
      throw StateError(
        (body['message'] ?? body['Message'] ?? 'Jadwal salat gagal disimpan.')
            .toString(),
      );
    }
  }
}
