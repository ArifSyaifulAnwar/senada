import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calendermodel.dart';

/// CalendarEventService
///
/// Strategy:
/// 1. Fetch dari Nager.Date (hari libur nasional tetap, otomatis per tahun)
/// 2. Merge dengan data cuti bersama hardcode (karena cuti bersama diumumkan
///    pemerintah setiap tahun dan tidak ada API publik yang reliable)
/// 3. Fallback ke dayoffapi kalau Nager gagal
class CalendarEventService {
  static const String _nagerBaseUrl =
      'https://date.nager.at/api/v3/PublicHolidays';
  static const String _dayoffBaseUrl = 'https://dayoffapi.vercel.app/api';

  static final Map<int, Map<DateTime, List<CalendarEvent>>> _cachedEvents = {};

  // ─────────────────────────────────────────────────────────────────
  // PUBLIC
  // ─────────────────────────────────────────────────────────────────
  static Future<Map<DateTime, List<CalendarEvent>>> getDayoffEvents(
    int year,
  ) async {
    if (_cachedEvents.containsKey(year)) {
      return _cachedEvents[year]!;
    }

    // Step 1: fetch hari libur nasional dari API
    var apiEvents = await _fetchFromNager(year);
    if (apiEvents.length < 3) {
      // Nager gagal atau data kurang → coba dayoffapi
      apiEvents = await _fetchFromDayoff(year);
    }

    // Step 2: ambil cuti bersama hardcode untuk tahun ini
    final cutiEvents = _getCutiBersamaHardcode(year);

    // Step 3: merge — API sebagai base, cuti bersama ditambahkan
    final merged = Map<DateTime, List<CalendarEvent>>.from(apiEvents);
    cutiEvents.forEach((key, events) {
      if (merged.containsKey(key)) {
        // Tambahkan cuti bersama ke event yang sudah ada di tanggal itu
        merged[key] = [...merged[key]!, ...events];
      } else {
        merged[key] = events;
      }
    });

    _cachedEvents[year] = merged;
    return merged;
  }

  static void addCustomEvent(DateTime date, CalendarEvent event) {
    final key = DateTime(date.year, date.month, date.day);
    _cachedEvents.putIfAbsent(date.year, () => {});
    _cachedEvents[date.year]!.putIfAbsent(key, () => []).add(event);
  }

  static void clearCache() => _cachedEvents.clear();

  static Future<Map<DateTime, List<CalendarEvent>>> refreshEvents(
    int year,
  ) async {
    _cachedEvents.remove(year);
    return getDayoffEvents(year);
  }

  // ─────────────────────────────────────────────────────────────────
  // NAGER.DATE — hari libur nasional resmi
  // GET https://date.nager.at/api/v3/PublicHolidays/{year}/ID
  // ─────────────────────────────────────────────────────────────────
  static Future<Map<DateTime, List<CalendarEvent>>> _fetchFromNager(
    int year,
  ) async {
    try {
      final uri = Uri.parse('$_nagerBaseUrl/$year/ID');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return {};
      final List<dynamic> data = json.decode(response.body);
      if (data.isEmpty) return {};

      final Map<DateTime, List<CalendarEvent>> eventMap = {};
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final date = _parseDate(item['date'] as String? ?? '');
          if (date.year == 0) continue;

          final event = CalendarEvent.fromNagerJson(item);
          final key = DateTime(date.year, date.month, date.day);
          eventMap.putIfAbsent(key, () => []).add(event);
        } catch (_) {
          continue;
        }
      }
      return eventMap;
    } catch (_) {
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DAYOFFAPI — fallback
  // GET https://dayoffapi.vercel.app/api?year={year}
  // ─────────────────────────────────────────────────────────────────
  static Future<Map<DateTime, List<CalendarEvent>>> _fetchFromDayoff(
    int year,
  ) async {
    try {
      final uri = Uri.parse('$_dayoffBaseUrl?year=$year');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return {};
      final List<dynamic> data = json.decode(response.body);
      if (data.isEmpty) return {};

      final Map<DateTime, List<CalendarEvent>> eventMap = {};
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        if (!item.containsKey('tanggal')) continue;
        try {
          final date = _parseDate(item['tanggal'] as String);
          if (date.year == 0) continue;

          final event = CalendarEvent.fromDayoffJson(item);
          final key = DateTime(date.year, date.month, date.day);
          eventMap.putIfAbsent(key, () => []).add(event);
        } catch (_) {
          continue;
        }
      }
      return eventMap;
    } catch (_) {
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // CUTI BERSAMA HARDCODE
  // Diumumkan pemerintah tiap tahun — harus update manual per tahun baru
  // Sumber: SKB 3 Menteri tiap tahun
  // ─────────────────────────────────────────────────────────────────
  static Map<DateTime, List<CalendarEvent>> _getCutiBersamaHardcode(int year) {
    final List<Map<String, dynamic>> data;

    switch (year) {
      case 2026:
        data = _cuti2026;
        break;
      case 2025:
        data = _cuti2025;
        break;
      case 2024:
        data = _cuti2024;
        break;
      default:
        return {}; // Tahun lain: tidak ada data cuti bersama
    }

    final Map<DateTime, List<CalendarEvent>> result = {};
    for (final item in data) {
      try {
        final date = _parseDate(item['tanggal'] as String);
        if (date.year == 0) continue;
        final event = CalendarEvent.fromDayoffJson(item);
        final key = DateTime(date.year, date.month, date.day);
        result.putIfAbsent(key, () => []).add(event);
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  // ── Cuti Bersama 2026 (SKB 3 Menteri) ────────────────────────────
  // Sumber: Keputusan Bersama Menteri 2026
  static const _cuti2026 = <Map<String, dynamic>>[
    // Idul Fitri 1447 H (20-21 April 2026)
    {
      'tanggal': '2026-04-17',
      'keterangan': 'Cuti Bersama Idul Fitri 1447 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2026-04-18',
      'keterangan': 'Cuti Bersama Idul Fitri 1447 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2026-04-22',
      'keterangan': 'Cuti Bersama Idul Fitri 1447 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2026-04-23',
      'keterangan': 'Cuti Bersama Idul Fitri 1447 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2026-04-24',
      'keterangan': 'Cuti Bersama Idul Fitri 1447 H',
      'is_cuti': true,
    },
    // Nyepi (20 Maret 2026)
    {
      'tanggal': '2026-03-21',
      'keterangan': 'Cuti Bersama Hari Raya Nyepi',
      'is_cuti': true,
    },
    // Wafat Isa Al Masih (2 April 2026)
    {
      'tanggal': '2026-04-03',
      'keterangan': 'Cuti Bersama Wafat Isa Al Masih',
      'is_cuti': true,
    },
    // Waisak (24 Mei 2026)
    {
      'tanggal': '2026-05-25',
      'keterangan': 'Cuti Bersama Hari Raya Waisak',
      'is_cuti': true,
    },
    // Kenaikan Isa Al Masih (14 Mei 2026)
    {
      'tanggal': '2026-05-15',
      'keterangan': 'Cuti Bersama Kenaikan Isa Al Masih',
      'is_cuti': true,
    },
    // Idul Adha (27 Mei 2026)
    {
      'tanggal': '2026-05-28',
      'keterangan': 'Cuti Bersama Idul Adha 1447 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2026-05-29',
      'keterangan': 'Cuti Bersama Idul Adha 1447 H',
      'is_cuti': true,
    },
    // Natal
    {
      'tanggal': '2026-12-24',
      'keterangan': 'Cuti Bersama Hari Raya Natal',
      'is_cuti': true,
    },
    {
      'tanggal': '2026-12-31',
      'keterangan': 'Cuti Bersama Tahun Baru Masehi 2027',
      'is_cuti': true,
    },
  ];

  // ── Cuti Bersama 2025 (SKB 3 Menteri) ────────────────────────────
  static const _cuti2025 = <Map<String, dynamic>>[
    // Imlek
    {
      'tanggal': '2025-01-29',
      'keterangan': 'Cuti Bersama Tahun Baru Imlek 2576',
      'is_cuti': true,
    },
    // Idul Fitri 1446 H
    {
      'tanggal': '2025-03-28',
      'keterangan': 'Cuti Bersama Idul Fitri 1446 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2025-04-02',
      'keterangan': 'Cuti Bersama Idul Fitri 1446 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2025-04-03',
      'keterangan': 'Cuti Bersama Idul Fitri 1446 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2025-04-04',
      'keterangan': 'Cuti Bersama Idul Fitri 1446 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2025-04-07',
      'keterangan': 'Cuti Bersama Idul Fitri 1446 H',
      'is_cuti': true,
    },
    // Waisak
    {
      'tanggal': '2025-05-13',
      'keterangan': 'Cuti Bersama Hari Raya Waisak',
      'is_cuti': true,
    },
    // Idul Adha
    {
      'tanggal': '2025-06-07',
      'keterangan': 'Cuti Bersama Idul Adha 1446 H',
      'is_cuti': true,
    },
    // Natal
    {
      'tanggal': '2025-12-26',
      'keterangan': 'Cuti Bersama Hari Raya Natal',
      'is_cuti': true,
    },
  ];

  // ── Cuti Bersama 2024 (SKB 3 Menteri) ────────────────────────────
  static const _cuti2024 = <Map<String, dynamic>>[
    // Imlek
    {
      'tanggal': '2024-02-09',
      'keterangan': 'Cuti Bersama Tahun Baru Imlek 2575',
      'is_cuti': true,
    },
    // Idul Fitri 1445 H
    {
      'tanggal': '2024-04-08',
      'keterangan': 'Cuti Bersama Idul Fitri 1445 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2024-04-12',
      'keterangan': 'Cuti Bersama Idul Fitri 1445 H',
      'is_cuti': true,
    },
    {
      'tanggal': '2024-04-15',
      'keterangan': 'Cuti Bersama Idul Fitri 1445 H',
      'is_cuti': true,
    },
    // Kenaikan Isa Al Masih
    {
      'tanggal': '2024-05-10',
      'keterangan': 'Cuti Bersama Kenaikan Isa Al Masih',
      'is_cuti': true,
    },
    // Waisak
    {
      'tanggal': '2024-05-24',
      'keterangan': 'Cuti Bersama Hari Raya Waisak',
      'is_cuti': true,
    },
    // Idul Adha
    {
      'tanggal': '2024-06-18',
      'keterangan': 'Cuti Bersama Idul Adha 1445 H',
      'is_cuti': true,
    },
    // Natal
    {
      'tanggal': '2024-12-26',
      'keterangan': 'Cuti Bersama Hari Raya Natal',
      'is_cuti': true,
    },
  ];

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────
  static DateTime _parseDate(String tanggalStr) {
    final parts = tanggalStr.trim().split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    try {
      return DateTime.parse(tanggalStr);
    } catch (_) {
      return DateTime(0);
    }
  }
}
