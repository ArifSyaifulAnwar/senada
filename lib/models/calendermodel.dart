import 'package:flutter/material.dart';

class CalendarEvent {
  final String title;
  final Color color;
  final String type;
  final bool isHoliday;
  final String? displayDate;
  final bool isCutiBersama;

  CalendarEvent({
    required this.title,
    required this.color,
    required this.type,
    this.isHoliday = false,
    this.displayDate,
    this.isCutiBersama = false,
  });

  // ─────────────────────────────────────────────────────────────────
  // Factory: dari dayoffapi.vercel.app
  // {"tanggal":"2026-05-27","keterangan":"Hari Raya Idul Adha","is_cuti":false}
  // ─────────────────────────────────────────────────────────────────
  factory CalendarEvent.fromDayoffJson(Map<String, dynamic> json) {
    final title = json['keterangan'] as String? ?? 'Event';
    final displayDate = json['tanggal_display'] as String?;
    final isCutiBersama = json['is_cuti'] == true;
    final isHoliday = isCutiBersama || _isNationalHoliday(title);
    final color = _determineColor(title, isCutiBersama);
    final type = _determineType(title, isCutiBersama);

    return CalendarEvent(
      title: title,
      color: color,
      type: type,
      isHoliday: isHoliday,
      displayDate: displayDate,
      isCutiBersama: isCutiBersama,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Factory: dari date.nager.at
  // {"date":"2026-01-01","localName":"Tahun Baru Masehi","name":"New Year's Day",
  //  "types":["Public"],"global":true}
  // ─────────────────────────────────────────────────────────────────
  factory CalendarEvent.fromNagerJson(Map<String, dynamic> json) {
    final title = json['localName'] as String? ??
        json['name'] as String? ??
        'Hari Libur';

    // Nager.Date tidak punya field is_cuti, semua adalah hari libur nasional
    // Tapi ada tipe "Optional" yang bisa dianggap sebagai hari biasa
    final types = (json['types'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Public'];

    // Anggap semua Public holiday sebagai isHoliday = true
    final isHoliday = types.contains('Public') || types.contains('Bank');

    // Nager tidak punya is_cuti, set false — tapi bisa dioverride
    // berdasarkan nama (cuti bersama biasanya ada kata "Cuti")
    final isCutiBersama = title.toLowerCase().contains('cuti');

    final color = _determineColor(title, isCutiBersama);
    final type = _determineType(title, isCutiBersama);

    return CalendarEvent(
      title: title,
      color: color,
      type: type,
      isHoliday: isHoliday,
      displayDate: json['date'] as String?,
      isCutiBersama: isCutiBersama,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────
  static bool _isNationalHoliday(String title) {
    const keywords = [
      'tahun baru', 'kemerdekaan', 'natal', 'idul fitri', 'idul adha',
      'nyepi', 'waisak', 'paskah', 'kenaikan', 'imlek', 'maulid', 'isra',
      'muharram', 'pancasila', 'buruh',
    ];
    final lower = title.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }

  static Color _determineColor(String title, bool isCutiBersama) {
    if (isCutiBersama) return Colors.red[400]!;

    final lower = title.toLowerCase();

    if (lower.contains('kemerdekaan') || lower.contains('tahun baru masehi')) {
      return Colors.red[600]!;
    } else if (lower.contains('idul fitri') || lower.contains('idul adha')) {
      return Colors.green[600]!;
    } else if (lower.contains('natal') ||
        lower.contains('paskah') ||
        lower.contains('wafat isa') ||
        lower.contains('kenaikan isa') ||
        lower.contains('good friday') ||
        lower.contains('ascension')) {
      return Colors.blue[600]!;
    } else if (lower.contains('nyepi') ||
        lower.contains('imlek') ||
        lower.contains('chinese')) {
      return Colors.orange[600]!;
    } else if (lower.contains('waisak') || lower.contains('vesak')) {
      return Colors.amber[600]!;
    } else if (lower.contains('isra') ||
        lower.contains('maulid') ||
        lower.contains('muharram') ||
        lower.contains('muhammad')) {
      return Colors.teal[600]!;
    } else if (lower.contains('pancasila') ||
        lower.contains('buruh') ||
        lower.contains('labour') ||
        lower.contains('labor')) {
      return Colors.indigo[600]!;
    } else {
      return Colors.purple[600]!;
    }
  }

  static String _determineType(String title, bool isCutiBersama) {
    if (isCutiBersama) return 'cuti_bersama';

    final lower = title.toLowerCase();

    if (lower.contains('kemerdekaan') ||
        lower.contains('pancasila') ||
        lower.contains('buruh') ||
        lower.contains('labour') ||
        lower.contains('labor') ||
        lower.contains('tahun baru masehi') ||
        lower.contains("new year")) {
      return 'nasional';
    } else if (lower.contains('idul') ||
        lower.contains('isra') ||
        lower.contains('maulid') ||
        lower.contains('muharram') ||
        lower.contains('muhammad')) {
      return 'islam';
    } else if (lower.contains('natal') ||
        lower.contains('paskah') ||
        lower.contains('wafat isa') ||
        lower.contains('kenaikan isa') ||
        lower.contains('good friday') ||
        lower.contains('christmas') ||
        lower.contains('easter') ||
        lower.contains('ascension')) {
      return 'kristen';
    } else if (lower.contains('waisak') || lower.contains('vesak')) {
      return 'buddha';
    } else if (lower.contains('nyepi') ||
        lower.contains('imlek') ||
        lower.contains('chinese')) {
      return 'tradisional';
    } else {
      return 'lainnya';
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Display getters
  // ─────────────────────────────────────────────────────────────────
  String get typeDescription {
    switch (type) {
      case 'cuti_bersama':
        return 'Cuti Bersama';
      case 'nasional':
        return 'Hari Nasional';
      case 'islam':
        return 'Hari Raya Islam';
      case 'kristen':
        return 'Hari Raya Kristen';
      case 'buddha':
        return 'Hari Raya Buddha';
      case 'tradisional':
        return 'Hari Tradisional';
      case 'negara':
        return 'Hari Negara';
      default:
        return 'Hari Libur';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'cuti_bersama':
        return Icons.beach_access;
      case 'nasional':
        return Icons.flag;
      case 'islam':
        return Icons.mosque;
      case 'kristen':
        return Icons.church;
      case 'buddha':
        return Icons.temple_buddhist;
      case 'tradisional':
        return Icons.festival;
      case 'negara':
        return Icons.account_balance;
      default:
        return Icons.event;
    }
  }

  @override
  String toString() =>
      'CalendarEvent{title: $title, type: $type, isHoliday: $isHoliday}';
}