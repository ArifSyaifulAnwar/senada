// Pengingat Absen — notifikasi lokal (bukan push server) yang mengingatkan
// karyawan jika belum check-in di atas jam 10:00 pada hari kerjanya sendiri.
//
// Backend tidak punya scheduler/cron sama sekali (murni reaktif terhadap
// request), jadi ini murni client-side: dijadwalkan ulang setiap home screen
// dibuka (schedule-on-open) dan dibatalkan begitu karyawan berhasil check-in
// (cancel-on-checkin). ID notifikasi tetap/fixed supaya selalu bisa dicancel.
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:absensikaryawan/Services/fcm_service.dart';
import 'package:absensikaryawan/Screen%20User/Screen%20HRD/hrd_employee_service.dart';

class AttendanceReminderService {
  static const int _notificationId = 900001;
  static const int _reminderHour = 10;
  static const String prefsKey = 'attendance_reminder_enabled';
  static bool _tzReady = false;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, enabled);
    if (!enabled) await cancel();
  }

  static void _ensureTz() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    _tzReady = true;
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

    if (!await isEnabled()) {
      await cancel();
      return;
    }

    final now = DateTime.now();
    if (now.hour >= _reminderHour) {
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
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        _reminderHour,
      );

      await localNotificationsPlugin.zonedSchedule(
        _notificationId,
        'Pengingat Absen',
        'Anda belum melakukan absen masuk hari ini. Jangan lupa check-in ya!',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            highImportanceChannel.id,
            highImportanceChannel.name,
            channelDescription: highImportanceChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
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
    try {
      await localNotificationsPlugin.cancel(_notificationId);
    } catch (_) {}
  }
}
