import 'dart:convert';

import 'package:intl/intl.dart';

import 'config.dart';
import 'token_service.dart';

class PrayerScheduleEntry {
  final String prayerCode;
  final String muadzinUserId;
  final String muadzinName;
  final String imamUserId;
  final String imamName;

  const PrayerScheduleEntry({
    required this.prayerCode,
    required this.muadzinUserId,
    required this.muadzinName,
    required this.imamUserId,
    required this.imamName,
  });

  factory PrayerScheduleEntry.fromJson(Map<String, dynamic> value) {
    String field(String snake, String pascal) =>
        (value[snake] ?? value[pascal] ?? '').toString();
    return PrayerScheduleEntry(
      prayerCode: field('prayer_code', 'PrayerCode'),
      muadzinUserId: field('muadzin_user_id', 'MuadzinUserId'),
      muadzinName: field('muadzin_name', 'MuadzinName'),
      imamUserId: field('imam_user_id', 'ImamUserId'),
      imamName: field('imam_name', 'ImamName'),
    );
  }
}

class PrayerScheduleService {
  static Future<List<PrayerScheduleEntry>> list(DateTime date) async {
    final response = await TokenService.authorizedPost(
      Uri.parse('$baseURL/api/employee/prayer-schedule-list'),
      body: jsonEncode({'tanggal': DateFormat('yyyy-MM-dd').format(date)}),
    );
    if (response.statusCode == 404) {
      throw StateError(
        'Endpoint jadwal salat belum tersedia di API. Deploy API terbaru.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 ||
        (body['success'] ?? body['Success']) != true) {
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

  static Future<void> save({
    required DateTime date,
    required String prayerCode,
    required String muadzinUserId,
    required String imamUserId,
  }) async {
    final response = await TokenService.authorizedPost(
      Uri.parse('$baseURL/api/employee/prayer-schedule-save'),
      body: jsonEncode({
        'tanggal': DateFormat('yyyy-MM-dd').format(date),
        'prayerCode': prayerCode,
        'muadzinUserId': muadzinUserId,
        'imamUserId': imamUserId,
      }),
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
