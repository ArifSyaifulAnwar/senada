// Pengingat Absen — notifikasi lokal (bukan push server) yang mengingatkan
// karyawan jika belum check-in di atas jam 10:00 pada hari kerjanya sendiri.
//
// Backend tidak punya scheduler/cron sama sekali (murni reaktif terhadap
// request), jadi ini murni client-side: dijadwalkan ulang setiap home screen
// dibuka (schedule-on-open) dan dibatalkan begitu karyawan berhasil check-in
// (cancel-on-checkin). ID notifikasi tetap/fixed supaya selalu bisa dicancel.
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:absensikaryawan/Services/fcm_service.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';
import 'package:absensikaryawan/Screen%20User/Screen%20HRD/hrd_employee_service.dart';
import 'attendance_reminder_web_stub.dart'
    if (dart.library.html) 'attendance_reminder_web.dart' as web_reminder;

class AttendanceReminderService {
  static const int _notificationId = 900001;
  static const String _prefsKeyPrefix = 'attendance_reminder_enabled_';
  static bool _tzReady = false;

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

  static void _ensureTz() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    _tzReady = true;
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

  /// Dipanggil tiap kali home screen karyawan dibuka. [isHariLibur] harus
  /// sudah menggabungkan weekend + libur kalender perusahaan (lihat
  /// `_checkHariIni`/`_checkHariIniHome` yang sudah ada). Cek jadwal kerja
  /// kustom per-karyawan dilakukan di dalam sini sendiri.
  static Future<void> scheduleIfNeeded({
    required String userId,
    required bool isHariLibur,
    required bool hasCheckedIn,
  }) async {
    if (userId.isEmpty || hasCheckedIn || isHariLibur) {
      await cancel();
      return;
    }

    if (!await isEnabled(userId)) {
      await cancel();
      return;
    }

    final now = DateTime.now();
    final schedule = await getCompanySchedule(userId);
    if (!schedule.enabled) {
      await cancel();
      return;
    }

    final customDays = await HrdEmployeeService.getWorkDays(userId);
    if (customDays != null &&
        customDays.isNotEmpty &&
        !customDays.contains(now.weekday)) {
      // Karyawan dengan jadwal kustom dan hari ini bukan jadwalnya.
      await cancel();
      return;
    }

    try {
      _ensureTz();
      final companyStart = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        schedule.hour,
        schedule.minute,
      );
      final scheduledDate = companyStart.add(Duration(minutes: schedule.graceMinutes));
      if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) return;
      final body =
          'Jam masuk Anda sudah lewat ${schedule.graceMinutes} menit. Jangan lupa check-in ya!';

      if (kIsWeb) {
        await web_reminder.scheduleBrowserAttendanceReminder(
          scheduledAt: scheduledDate,
          title: 'Pengingat Absen',
          body: body,
        );
        return;
      }

      await localNotificationsPlugin.zonedSchedule(
        _notificationId,
        'Pengingat Absen',
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            highImportanceChannel.id,
            highImportanceChannel.name,
            channelDescription: highImportanceChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_senada',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': 'attendance_reminder'}),
      );
    } catch (_) {
      // Gagal menjadwalkan (mis. izin notifikasi ditolak) — diamkan saja,
      // ini fitur pengingat tambahan, bukan alur kritis absensi.
    }
  }

  /// Dipanggil begitu karyawan berhasil check-in, supaya pengingat jam 10
  /// tidak muncul lagi hari itu.
  static Future<void> cancel() async {
    await web_reminder.cancelBrowserAttendanceReminder();
    try {
      await localNotificationsPlugin.cancel(_notificationId);
    } catch (_) {}
  }
}
