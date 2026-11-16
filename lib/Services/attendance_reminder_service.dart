// Pengingat otomatis dikirim Cloud Scheduler + API saat jam masuk + masa
// tenggang. Klien hanya menyimpan preferensi dan membatalkan jadwal lokal lama.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:absensikaryawan/Services/fcm_service.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';
import 'attendance_reminder_web_stub.dart'
    if (dart.library.html) 'attendance_reminder_web.dart' as web_reminder;

class AttendanceReminderService {
  static const int _notificationId = 900001;
  static const String _prefsKeyPrefix = 'attendance_reminder_enabled_';

  static String _prefsKey(String userId) => '$_prefsKeyPrefix$userId';

  static Future<bool> isEnabled(String userId) async {
    if (userId.trim().isEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey(userId)) ?? true;
  }

  static Future<void> setEnabled(String userId, bool enabled) async {
    if (userId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey(userId), enabled);
    // Simpan juga di server agar push pengingat tidak tetap masuk ketika
    // pengguna sengaja mematikan toggle ini di perangkat lain.
    try {
      await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/asn/attendance/reminder-preference'),
        body: jsonEncode({'UserId': userId, 'IsEnabled': enabled}),
      );
    } catch (_) {}
    if (!enabled) await cancel();
  }

  static Future<({int hour, int minute, int graceMinutes, bool enabled})>
      getCompanySchedule(String userId) async {
    const fallback = (hour: 8, minute: 0, graceMinutes: 10, enabled: true);
    try {
      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/asn/attendance/reminder-settings'),
        body: jsonEncode({'UserId': userId}),
      );
      if (response.statusCode != 200) return fallback;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return fallback;
      final rawTime = (data['StartTime'] ?? data['startTime'] ?? '').toString();
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(rawTime);
      final hour = int.tryParse(match?.group(1) ?? '') ?? fallback.hour;
      final minute = int.tryParse(match?.group(2) ?? '') ?? fallback.minute;
      final grace = int.tryParse('${data['GraceMinutes'] ?? data['graceMinutes']}') ?? fallback.graceMinutes;
      final rawEnabled = data['IsEnabled'] ?? data['isEnabled'];
      final enabled = rawEnabled is bool
          ? rawEnabled
          : rawEnabled?.toString().toLowerCase() != 'false';
      return (
        hour: hour.clamp(0, 23).toInt(),
        minute: minute.clamp(0, 59).toInt(),
        graceMinutes: grace.clamp(0, 120).toInt(),
        enabled: enabled,
      );
    } catch (_) {
      return fallback;
    }
  }

  /// Dipanggil saat home dibuka untuk membersihkan jadwal lokal versi lama.
  static Future<void> scheduleIfNeeded({
    required String userId,
    required bool isHariLibur,
    required bool hasCheckedIn,
  }) async {
    // Cloud Scheduler + API adalah satu-satunya pengirim pengingat otomatis.
    // Bersihkan jadwal lokal dari versi lama agar tidak muncul dua kali.
    await cancel();
  }
  /// Dipanggil saat check-in dan saat home dibuka.
  static Future<void> cancel() async {
    await web_reminder.cancelBrowserAttendanceReminder();
    try {
      await localNotificationsPlugin.cancel(_notificationId);
    } catch (_) {}
  }
}
