import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calendermodel.dart';

class CalendarEventService {
  static const String _dayoffBaseUrl = 'https://dayoffapi.vercel.app/api';
  static final Map<int, Map<DateTime, List<CalendarEvent>>> _cachedEvents = {};

  static Future<Map<DateTime, List<CalendarEvent>>> getDayoffEvents(
    int year,
  ) async {
    // Check cache first
    if (_cachedEvents.containsKey(year)) {
      return _cachedEvents[year]!;
    }

    try {
      final uri = Uri.parse('$_dayoffBaseUrl?year=$year');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        Map<DateTime, List<CalendarEvent>> eventMap = {};

        for (var item in data) {
          if (item is Map<String, dynamic> && item.containsKey('tanggal')) {
            try {
              String tanggalStr = item['tanggal'];
              DateTime date = _parseDate(tanggalStr);

              CalendarEvent event = CalendarEvent.fromDayoffJson(item);

              final key = DateTime(date.year, date.month, date.day);
              if (eventMap.containsKey(key)) {
                eventMap[key]!.add(event);
              } else {
                eventMap[key] = [event];
              }
            } catch (e) {
              rethrow;
            }
          }
        }

        // Cache the events
        _cachedEvents[year] = eventMap;
        return eventMap;
      } else {}
    } catch (e) {
      rethrow;
    }

    return _getFallbackEvents(year);
  }

  static DateTime _parseDate(String tanggalStr) {
    try {
      // Handle different date formats from API
      // Format dari API: "2025-01-1", "2025-04-1", etc.
      List<String> parts = tanggalStr.split('-');
      if (parts.length >= 3) {
        int year = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int day = int.parse(parts[2]);
        return DateTime(year, month, day);
      }

      // Fallback: try direct parsing
      return DateTime.parse(tanggalStr);
    } catch (e) {
      // Return current date as fallback
      return DateTime.now();
    }
  }

  static Map<DateTime, List<CalendarEvent>> _getFallbackEvents(int year) {
    Map<DateTime, List<CalendarEvent>> fallbackEvents = {};

    // Add some basic Indonesian holidays as fallback
    List<Map<String, dynamic>> basicHolidays = [
      {
        'tanggal': '$year-01-01',
        'keterangan': 'Tahun Baru Masehi',
        'is_cuti': false,
      },
      {
        'tanggal': '$year-08-17',
        'keterangan': 'Hari Kemerdekaan RI',
        'is_cuti': false,
      },
      {
        'tanggal': '$year-12-25',
        'keterangan': 'Hari Raya Natal',
        'is_cuti': false,
      },
    ];

    for (var holiday in basicHolidays) {
      try {
        DateTime date = _parseDate(holiday['tanggal']);
        CalendarEvent event = CalendarEvent.fromDayoffJson(holiday);
        final key = DateTime(date.year, date.month, date.day);
        fallbackEvents[key] = [event];
      } catch (e) {
        rethrow;
      }
    }

    return fallbackEvents;
  }

  // Method untuk menambah event custom (opsional)
  static void addCustomEvent(DateTime date, CalendarEvent event) {
    final key = DateTime(date.year, date.month, date.day);
    int year = date.year;

    if (!_cachedEvents.containsKey(year)) {
      _cachedEvents[year] = {};
    }

    if (_cachedEvents[year]!.containsKey(key)) {
      _cachedEvents[year]![key]!.add(event);
    } else {
      _cachedEvents[year]![key] = [event];
    }
  }

  // Method untuk clear cache jika diperlukan
  static void clearCache() {
    _cachedEvents.clear();
  }

  // Method untuk refresh data
  static Future<Map<DateTime, List<CalendarEvent>>> refreshEvents(
    int year,
  ) async {
    _cachedEvents.remove(year);
    return await getDayoffEvents(year);
  }
}
