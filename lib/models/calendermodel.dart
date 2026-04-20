import 'package:flutter/material.dart';

class CalendarEvent {
  final String title;
  final Color color;
  final String type;
  final bool isHoliday;
  final String?
  displayDate; // Tambahan untuk menyimpan tanggal display dari API
  final bool
  isCutiBersama; // Untuk membedakan cuti bersama dengan hari libur biasa

  CalendarEvent({
    required this.title,
    required this.color,
    required this.type,
    this.isHoliday = false,
    this.displayDate,
    this.isCutiBersama = false,
  });

  /// Factory constructor dari API dayoffapi.vercel.app
  factory CalendarEvent.fromDayoffJson(Map<String, dynamic> json) {
    String title = json['keterangan'] ?? 'Event';
    String? displayDate = json['tanggal_display'];
    bool isCutiBersama = (json['is_cuti'] == true);

    // Tentukan apakah ini hari libur (merah di kalender)
    // - Jika is_cuti = true, maka ini cuti bersama (merah)
    // - Jika is_cuti = false tapi hari penting, tetap merah tapi berbeda treatment
    bool isHoliday = isCutiBersama || _isNationalHoliday(title);

    // Tentukan warna berdasarkan jenis event
    Color color = _determineColor(title, isCutiBersama);

    // Tentukan tipe event
    String type = _determineType(title, isCutiBersama);

    return CalendarEvent(
      title: title,
      color: color,
      type: type,
      isHoliday: isHoliday,
      displayDate: displayDate,
      isCutiBersama: isCutiBersama,
    );
  }

  // Helper method untuk menentukan apakah ini hari libur nasional penting
  static bool _isNationalHoliday(String title) {
    List<String> nationalHolidays = [
      'Tahun Baru',
      'Kemerdekaan',
      'Natal',
      'Idul Fitri',
      'Idul Adha',
      'Nyepi',
      'Waisak',
    ];

    return nationalHolidays.any(
      (holiday) => title.toLowerCase().contains(holiday.toLowerCase()),
    );
  }

  // Helper method untuk menentukan warna
  static Color _determineColor(String title, bool isCutiBersama) {
    if (isCutiBersama) {
      return Colors.red[400]!; // Merah untuk cuti bersama
    }

    // Warna berdasarkan jenis hari penting
    String titleLower = title.toLowerCase();

    if (titleLower.contains('tahun baru') ||
        titleLower.contains('kemerdekaan')) {
      return Colors.red[600]!; // Merah tua untuk hari nasional
    } else if (titleLower.contains('idul fitri') ||
        titleLower.contains('idul adha')) {
      return Colors.green[600]!; // Hijau untuk hari raya Islam
    } else if (titleLower.contains('natal') || titleLower.contains('paskah')) {
      return Colors.blue[600]!; // Biru untuk hari raya Kristen
    } else if (titleLower.contains('nyepi') || titleLower.contains('imlek')) {
      return Colors.orange[600]!; // Orange untuk hari raya lainnya
    } else if (titleLower.contains('waisak')) {
      return Colors.amber[600]!; // Kuning untuk hari raya Buddha
    } else if (titleLower.contains('isra') || titleLower.contains('maulid')) {
      return Colors.teal[600]!; // Teal untuk hari penting Islam
    } else {
      return Colors.purple[600]!; // Default untuk hari penting lainnya
    }
  }

  // Helper method untuk menentukan tipe
  static String _determineType(String title, bool isCutiBersama) {
    if (isCutiBersama) {
      return 'cuti_bersama';
    }

    String titleLower = title.toLowerCase();

    if (titleLower.contains('tahun baru') ||
        titleLower.contains('kemerdekaan')) {
      return 'nasional';
    } else if (titleLower.contains('idul') ||
        titleLower.contains('isra') ||
        titleLower.contains('maulid') ||
        titleLower.contains('muharram')) {
      return 'islam';
    } else if (titleLower.contains('natal') ||
        titleLower.contains('paskah') ||
        titleLower.contains('kenaikan')) {
      return 'kristen';
    } else if (titleLower.contains('nyepi') || titleLower.contains('imlek')) {
      return 'tradisional';
    } else if (titleLower.contains('waisak')) {
      return 'buddha';
    } else if (titleLower.contains('buruh') ||
        titleLower.contains('pancasila')) {
      return 'negara';
    } else {
      return 'lainnya';
    }
  }

  // Method untuk mendapatkan deskripsi tipe dalam bahasa Indonesia
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
        return 'Hari Penting';
    }
  }

  // Method untuk mendapatkan icon berdasarkan tipe
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
  String toString() {
    return 'CalendarEvent{title: $title, type: $type, isHoliday: $isHoliday, isCutiBersama: $isCutiBersama}';
  }
}
