import 'package:flutter/material.dart';

class CalendarEvent {
  final String title;
  final Color color;
  final String type;
  final bool isHoliday;
  final String? displayDate;
  final bool isCutiBersama;
  final bool isWfh;
  final bool isInfo;
  final String source;

  CalendarEvent({
    required this.title,
    required this.color,
    required this.type,
    this.isHoliday = false,
    this.displayDate,
    this.isCutiBersama = false,
    this.isWfh = false,
    this.isInfo = false,
    this.source = 'unknown',
  });

  // ── Factory: dari dayoffapi.vercel.app ────────────────────────────
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
      source: 'national',
    );
  }

  // ── Factory: dari date.nager.at ───────────────────────────────────
  factory CalendarEvent.fromNagerJson(Map<String, dynamic> json) {
    final title =
        json['localName'] as String? ?? json['name'] as String? ?? 'Hari Libur';

    final types =
        (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        ['Public'];

    final isHoliday = types.contains('Public') || types.contains('Bank');
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
      source: 'national',
    );
  }

  // ── Factory: dari Company Calendar (LIBUR / WFH / INFO) ──────────
  factory CalendarEvent.fromCompanyCalendar({
    required String tipe,
    required String keterangan,
    required String tanggal,
  }) {
    switch (tipe) {
      case 'LIBUR':
        return CalendarEvent(
          title: keterangan,
          color: const Color(0xFFEF4444),
          type: 'company_libur',
          isHoliday: true, // tanggal merah, disable absen
          isWfh: false,
          isInfo: false,
          source: 'company',
          displayDate: tanggal,
        );
      case 'WFH':
        return CalendarEvent(
          title: keterangan,
          color: const Color(0xFF10B981),
          type: 'company_wfh',
          isHoliday: false, // tidak tanggal merah
          isWfh: true,
          isInfo: false,
          source: 'company',
          displayDate: tanggal,
        );
      case 'INFO':
        return CalendarEvent(
          title: keterangan,
          color: const Color(0xFF3B82F6),
          type: 'company_info',
          isHoliday: false, // TIDAK tanggal merah
          isWfh: false,
          isInfo: true, // hanya informasi
          source: 'company',
          displayDate: tanggal,
        );
      default:
        return CalendarEvent(
          title: keterangan,
          color: Colors.grey,
          type: 'company_other',
          isHoliday: false,
          isWfh: false,
          isInfo: false,
          source: 'company',
          displayDate: tanggal,
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────
  static bool _isNationalHoliday(String title) {
    const keywords = [
      'tahun baru',
      'kemerdekaan',
      'natal',
      'idul fitri',
      'idul adha',
      'nyepi',
      'waisak',
      'paskah',
      'kenaikan',
      'imlek',
      'maulid',
      'isra',
      'muharram',
      'pancasila',
      'buruh',
    ];
    final lower = title.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }

  static Color _determineColor(String title, bool isCutiBersama) {
    if (isCutiBersama) return Colors.red[400]!;
    final lower = title.toLowerCase();
    if (lower.contains('kemerdekaan') || lower.contains('tahun baru masehi')) {
      return Colors.red[600]!;
    }
    if (lower.contains('idul fitri') || lower.contains('idul adha')) {
      return Colors.green[600]!;
    }
    if (lower.contains('natal') ||
        lower.contains('paskah') ||
        lower.contains('wafat isa') ||
        lower.contains('kenaikan isa') ||
        lower.contains('good friday') ||
        lower.contains('ascension')) {
      return Colors.blue[600]!;
    }
    if (lower.contains('nyepi') ||
        lower.contains('imlek') ||
        lower.contains('chinese')) {
      return Colors.orange[600]!;
    }
    if (lower.contains('waisak') || lower.contains('vesak')) {
      return Colors.amber[600]!;
    }
    if (lower.contains('isra') ||
        lower.contains('maulid') ||
        lower.contains('muharram') ||
        lower.contains('muhammad')) {
      return Colors.teal[600]!;
    }
    if (lower.contains('pancasila') ||
        lower.contains('buruh') ||
        lower.contains('labour') ||
        lower.contains('labor')) {
      return Colors.indigo[600]!;
    }
    return Colors.purple[600]!;
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
        lower.contains('new year')) {
      return 'nasional';
    }
    if (lower.contains('idul') ||
        lower.contains('isra') ||
        lower.contains('maulid') ||
        lower.contains('muharram') ||
        lower.contains('muhammad')) {
      return 'islam';
    }
    if (lower.contains('natal') ||
        lower.contains('paskah') ||
        lower.contains('wafat isa') ||
        lower.contains('kenaikan isa') ||
        lower.contains('good friday') ||
        lower.contains('christmas') ||
        lower.contains('easter') ||
        lower.contains('ascension')) {
      return 'kristen';
    }
    if (lower.contains('waisak') || lower.contains('vesak')) return 'buddha';
    if (lower.contains('nyepi') ||
        lower.contains('imlek') ||
        lower.contains('chinese')) {
      return 'tradisional';
    }
    return 'lainnya';
  }

  // ── Display getters ───────────────────────────────────────────────
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
      case 'company_libur':
        return 'Libur Perusahaan';
      case 'company_wfh':
        return 'Work From Home';
      case 'company_info':
        return 'Info / Pengumuman';
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
      case 'company_libur':
        return Icons.event_busy;
      case 'company_wfh':
        return Icons.home_work;
      case 'company_info':
        return Icons.info_outline;
      default:
        return Icons.event;
    }
  }

  @override
  String toString() =>
      'CalendarEvent{title: $title, type: $type, isHoliday: $isHoliday, isInfo: $isInfo}';
}
