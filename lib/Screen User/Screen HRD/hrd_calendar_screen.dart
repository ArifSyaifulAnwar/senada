// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Services/company_calendar_service.dart';
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../Services/web_download.dart';

class HrdCalendarScreen extends StatefulWidget {
  const HrdCalendarScreen({super.key});

  @override
  State<HrdCalendarScreen> createState() => _HrdCalendarScreenState();
}

class _HrdCalendarScreenState extends State<HrdCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WorkPeriod> _periods = [];
  bool _isLoadingPeriods = false;
  String? _hrdUserId;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  List<CompanyCalendarEvent> _events = [];
  bool _isLoading = false;
  String _filterTipe = 'SEMUA';

  final List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final List<String> _dayNames = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadUserId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _hrdUserId = prefs.getString('UserID'));
    await _loadEvents();
    await _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    setState(() => _isLoadingPeriods = true);

    final data = await CompanyCalendarService.getWorkPeriodsByYear(
      _selectedYear,
      forceRefresh: true,
    );

    if (mounted) {
      setState(() {
        _periods = data;
        _isLoadingPeriods = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await CompanyCalendarService.getByYear(
      _selectedYear,
      userId: _hrdUserId,
      forceRefresh: true,
    );
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  List<CompanyCalendarEvent> get _filteredEvents {
    var list = _filterTipe == 'SEMUA'
        ? _events
        : _events.where((e) => e.tipe == _filterTipe).toList();
    list.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return list;
  }

  List<CompanyCalendarEvent> _eventsForMonth(int month) => _events
      .where((e) => e.tanggal.year == _selectedYear && e.tanggal.month == month)
      .toList();

  List<CompanyCalendarEvent> _eventsForDate(DateTime date) => _events
      .where(
        (e) =>
            e.tanggal.year == date.year &&
            e.tanggal.month == date.month &&
            e.tanggal.day == date.day,
      )
      .toList();

  // ── Warna & icon per tipe ─────────────────────────────────────────
  Color _tipeColor(String tipe) {
    switch (tipe) {
      case 'LIBUR':
        return const Color(0xFFEF4444);
      case 'WFH':
        return const Color(0xFF10B981);
      case 'INFO':
        return const Color(0xFF3B82F6);
      case 'ULTAH':
        return const Color(0xFFEC4899);
      default:
        return Colors.grey;
    }
  }

  IconData _tipeIcon(String tipe) {
    switch (tipe) {
      case 'LIBUR':
        return Icons.beach_access_rounded;
      case 'WFH':
        return Icons.home_work_rounded;
      case 'INFO':
        return Icons.info_outline;
      case 'ULTAH':
        return Icons.cake_rounded;
      default:
        return Icons.event;
    }
  }

  String _tipeLabel(String tipe) {
    switch (tipe) {
      case 'LIBUR':
        return 'Hari Libur';
      case 'WFH':
        return 'Work From Home';
      case 'INFO':
        return 'Info / Pengumuman';
      case 'ULTAH':
        return 'Ulang Tahun';
      default:
        return tipe;
    }
  }

  // ── Apakah periode sedang aktif (hari ini berada di dalamnya) ────
  bool _isActivePeriod(WorkPeriod period) {
    final today = DateTime.now();
    final start = DateTime(
      period.tanggalMulai.year,
      period.tanggalMulai.month,
      period.tanggalMulai.day,
    );
    final end = DateTime(
      period.tanggalSelesai.year,
      period.tanggalSelesai.month,
      period.tanggalSelesai.day,
    );
    final todayNorm = DateTime(today.year, today.month, today.day);
    return !todayNorm.isBefore(start) && !todayNorm.isAfter(end);
  }

  // ── Hitung statistik hari dalam periode ──────────────────────────
  // totalDays  = semua hari dalam rentang periode
  // weekends   = Sabtu + Minggu
  // holidays   = event LIBUR yang jatuh di hari kerja (bukan weekend)
  // workDays   = totalDays - weekends - holidays
  Map<String, int> _calculateStats(WorkPeriod period) {
    final start = DateTime(
      period.tanggalMulai.year,
      period.tanggalMulai.month,
      period.tanggalMulai.day,
    );
    final end = DateTime(
      period.tanggalSelesai.year,
      period.tanggalSelesai.month,
      period.tanggalSelesai.day,
    );
    final totalDays = end.difference(start).inDays + 1;

    int weekendDays = 0;
    for (int i = 0; i < totalDays; i++) {
      final d = start.add(Duration(days: i));
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        weekendDays++;
      }
    }

    // Hitung LIBUR yang jatuh di hari kerja saja (weekend sudah dikurangi)
    int holidayCount = 0;
    for (final event in _events) {
      if (event.tipe != 'LIBUR') continue;
      final d = DateTime(
        event.tanggal.year,
        event.tanggal.month,
        event.tanggal.day,
      );
      if (!d.isBefore(start) && !d.isAfter(end)) {
        if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
          holidayCount++;
        }
      }
    }

    return {
      'total': totalDays,
      'weekends': weekendDays,
      'holidays': holidayCount,
      'workDays': totalDays - weekendDays - holidayCount,
    };
  }

  void _snack(
    String msg, {
    bool err = false,
  }) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            err ? Icons.error_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: err ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ),
  );

  // ── DIALOG TAMBAH / EDIT ──────────────────────────────────────────
  Future<void> _showFormDialog({
    CompanyCalendarEvent? existing,
    DateTime? initialDate,
  }) async {
    DateTime selectedDate = existing?.tanggal ?? initialDate ?? DateTime.now();
    String selectedTipe = existing?.tipe ?? 'LIBUR';
    final keteranganCtrl = TextEditingController(
      text: existing?.keterangan ?? '',
    );

    Uint8List? newAttachmentBytes;
    String? newAttachmentFileName;
    String? newAttachmentContentType;
    bool keepExistingAttachment = existing?.hasAttachment ?? false;
    bool removeAttachment = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            existing == null ? 'Tambah Event Kalender' : 'Edit Event',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 320,
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tanggal ──────────────────────────────────────
                  const Text(
                    'Tanggal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (_, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF6366F1),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setDlg(() => selectedDate = picked);
                    },
                    child: Container(
                      width: 296,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat(
                              'EEEE, dd MMMM yyyy',
                              'id_ID',
                            ).format(selectedDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tipe: LIBUR | WFH | INFO ──────────────────────
                  const Text(
                    'Tipe',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 296,
                    child: Row(
                      children: ['LIBUR', 'WFH', 'INFO'].map((tipe) {
                        final sel = selectedTipe == tipe;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setDlg(() => selectedTipe = tipe),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _tipeColor(tipe).withOpacity(0.1)
                                    : const Color(0xFFF9FAFB),
                                border: Border.all(
                                  color: sel
                                      ? _tipeColor(tipe)
                                      : const Color(0xFFE5E7EB),
                                  width: sel ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _tipeIcon(tipe),
                                    size: 18,
                                    color: sel ? _tipeColor(tipe) : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tipe,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? _tipeColor(tipe)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── Info hint untuk tipe INFO ──────────────────────
                  if (selectedTipe == 'INFO') ...[
                    const SizedBox(height: 8),
                    Container(
                      width: 296,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Info hanya sebagai pengumuman. Tidak mempengaruhi absen atau hari merah.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Keterangan ────────────────────────────────────
                  const Text(
                    'Keterangan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 296,
                    child: TextField(
                      controller: keteranganCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: selectedTipe == 'INFO'
                            ? 'Contoh: Ultah Direktur, Rapat All Hands...'
                            : selectedTipe == 'WFH'
                            ? 'Contoh: WFH seluruh karyawan...'
                            : 'Contoh: Hari Raya Idul Fitri...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),

                  // ── Lampiran (opsional) ────────────────────────────
                  const SizedBox(height: 16),
                  const Text(
                    'Lampiran (opsional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Builder(
                    builder: (_) {
                      const boxW = 296.0;
                      final isNewImage =
                          newAttachmentBytes != null &&
                          (newAttachmentContentType?.startsWith('image/') ??
                              false);
                      final hasExisting =
                          keepExistingAttachment &&
                          !removeAttachment &&
                          newAttachmentBytes == null;

                      // ── Ada file baru yang dipilih ──
                      if (newAttachmentBytes != null) {
                        return Container(
                          width: boxW,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isNewImage)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Container(
                                    width: boxW,
                                    height: 160,
                                    color: const Color(0xFFF3F4F6),
                                    child: Image.memory(
                                      newAttachmentBytes!,
                                      width: boxW,
                                      height: 160,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: boxW,
                                        height: 160,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: boxW,
                                  height: 70,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 32,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    Icon(
                                      isNewImage
                                          ? Icons.image_rounded
                                          : Icons.insert_drive_file_rounded,
                                      size: 15,
                                      color: const Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        newAttachmentFileName ?? 'File dipilih',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => setDlg(() {
                                        newAttachmentBytes = null;
                                        newAttachmentFileName = null;
                                        newAttachmentContentType = null;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.red[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  0,
                                  10,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _pickCalendarAttachment(
                                              ctx,
                                              setDlg,
                                              (b, name, type) {
                                                newAttachmentBytes = b;
                                                newAttachmentFileName = name;
                                                newAttachmentContentType = type;
                                                removeAttachment = false;
                                              },
                                            ),
                                        icon: const Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 15,
                                        ),
                                        label: const Text(
                                          'Ganti File',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF6366F1,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF6366F1),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // ── Ada lampiran tersimpan dari sebelumnya (edit mode) ──
                      if (hasExisting) {
                        final existingIsImage =
                            (existing?.attachmentContentType?.startsWith(
                              'image/',
                            ) ??
                            false);
                        return Container(
                          width: boxW,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    existingIsImage
                                        ? Icons.image_rounded
                                        : Icons.attach_file_rounded,
                                    size: 16,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      existing?.attachmentFileName ??
                                          'Lampiran tersimpan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        setDlg(() => removeAttachment = true),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 14,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickCalendarAttachment(
                                        ctx,
                                        setDlg,
                                        (b, name, type) {
                                          newAttachmentBytes = b;
                                          newAttachmentFileName = name;
                                          newAttachmentContentType = type;
                                          removeAttachment = false;
                                        },
                                      ),
                                      icon: const Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 15,
                                      ),
                                      label: const Text(
                                        'Ganti File',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF3B82F6,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF3B82F6),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      // ── Belum ada lampiran sama sekali ──
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickCalendarAttachment(
                                ctx,
                                setDlg,
                                (b, name, type) {
                                  newAttachmentBytes = b;
                                  newAttachmentFileName = name;
                                  newAttachmentContentType = type;
                                  removeAttachment = false;
                                },
                              ),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 17,
                              ),
                              label: const Text(
                                'Pilih Gambar / File',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6366F1),
                                side: const BorderSide(
                                  color: Color(0xFF6366F1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (keteranganCtrl.text.trim().isEmpty) {
                  _snack('Keterangan wajib diisi', err: true);
                  return;
                }
                Navigator.pop(ctx);
                final result = await CompanyCalendarService.save(
                  id: existing?.id,
                  tanggal: DateFormat('yyyy-MM-dd').format(selectedDate),
                  tipe: selectedTipe,
                  keterangan: keteranganCtrl.text.trim(),
                  createdBy: _hrdUserId ?? '',
                  attachmentBase64: newAttachmentBytes != null
                      ? base64Encode(newAttachmentBytes!)
                      : null,
                  attachmentFileName: newAttachmentFileName,
                  attachmentContentType: newAttachmentContentType,
                  removeAttachment: removeAttachment,
                );
                if (result['success'] == true) {
                  _snack(
                    existing == null
                        ? 'Event berhasil ditambahkan!'
                        : 'Event berhasil diupdate!',
                  );
                  await _loadEvents();
                } else {
                  _snack(result['message'] ?? 'Gagal', err: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(existing == null ? 'Simpan' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCalendarAttachment(
    BuildContext dialogCtx,
    StateSetter setDlg,
    void Function(Uint8List bytes, String fileName, String contentType)
    onPicked,
  ) async {
    final source = await showModalBottomSheet<String>(
      context: dialogCtx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pilih lampiran',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.green[600]),
              ),
              title: const Text(
                'Galeri / Foto',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(dialogCtx, 'gallery'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.insert_drive_file, color: Colors.orange[600]),
              ),
              title: const Text(
                'File Dokumen (PDF)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(dialogCtx, 'document'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;

    Uint8List? bytes;
    String? fileName;
    String? contentType;

    if (source == 'gallery') {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (img == null) return;
      bytes = await img.readAsBytes();
      fileName = img.name.isNotEmpty ? img.name : 'image.jpg';
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'jpg';
      contentType = 'image/$ext';
    } else {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (r == null || r.files.isEmpty) return;
      bytes = r.files.first.bytes;
      fileName = r.files.first.name;
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';
      contentType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
    }

    if (bytes == null) return;
    if (bytes.length > 10 * 1024 * 1024) {
      _snack('Ukuran maksimal 10MB', err: true);
      return;
    }

    setDlg(() => onPicked(bytes!, fileName!, contentType!));
  }

  // ── DELETE ────────────────────────────────────────────────────────
  Future<void> _confirmDelete(CompanyCalendarEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Event?'),
        content: Text(
          'Yakin hapus "${event.keterangan}" pada '
          '${DateFormat('dd MMM yyyy', 'id_ID').format(event.tanggal)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await CompanyCalendarService.delete(
        id: event.id,
        deletedBy: _hrdUserId ?? '',
        tahun: event.tanggal.year,
      );
      if (result['success'] == true) {
        _snack('Event berhasil dihapus!');
        await _loadEvents();
      } else {
        _snack(result['message'] ?? 'Gagal', err: true);
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Kelola Kalender',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Colors.black87),
              onPressed: _loadEvents,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Daftar Event'),
            Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Kalender'),
            Tab(
              icon: Icon(Icons.date_range_rounded, size: 18),
              text: 'Periode',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 2) {
            _showPeriodDialog();
          } else {
            _showFormDialog();
          }
        },
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: Icon(
          _tabController.index == 2
              ? Icons.date_range_rounded
              : Icons.add_rounded,
        ),
        label: Text(
          _tabController.index == 2 ? 'Tambah Periode' : 'Tambah Event',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildListTab(), _buildCalendarTab(), _buildPeriodTab()],
      ),
    );
  }

  Widget _buildPeriodTab() {
    final sorted = [..._periods]..sort((a, b) => a.bulan.compareTo(b.bulan));

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _selectedYear--);
                  _loadEvents();
                  _loadPeriods();
                },
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                'Periode $_selectedYear',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _selectedYear++);
                  _loadEvents();
                  _loadPeriods();
                },
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingPeriods
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                )
              : sorted.isEmpty
              ? _buildEmptyPeriod()
              : RefreshIndicator(
                  onRefresh: _loadPeriods,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) => _buildPeriodCard(sorted[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyPeriod() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.date_range_rounded,
              size: 56,
              color: Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Periode Kerja',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap tombol Tambah Periode untuk menentukan periode kerja per bulan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    ),
  );

  Widget _buildPeriodCard(WorkPeriod period) {
    final startLabel = DateFormat(
      'dd MMM yyyy',
      'id_ID',
    ).format(period.tanggalMulai);
    final endLabel = DateFormat(
      'dd MMM yyyy',
      'id_ID',
    ).format(period.tanggalSelesai);
    final monthName = _monthNames[period.bulan - 1];
    final isActive = _isActivePeriod(period);
    final stats = _calculateStats(period);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isActive ? 0.08 : 0.04),
            blurRadius: isActive ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF6366F1,
                    ).withOpacity(isActive ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.date_range_rounded,
                    color: const Color(0xFF6366F1),
                    size: isActive ? 26 : 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$monthName ${period.tahun}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Aktif',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$startLabel – $endLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (period.keterangan.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          period.keterangan,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showPeriodDialog(existing: period);
                    if (val == 'delete') _confirmDeletePeriod(period);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Color(0xFF6366F1)),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 8),
                          Text('Hapus'),
                        ],
                      ),
                    ),
                  ],
                  child: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Statistik hari kerja ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6366F1).withOpacity(0.05)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF6366F1).withOpacity(0.2)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  // Hari kerja — angka utama
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${stats['workDays']}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const Text(
                          'Hari Kerja',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFFE5E7EB),
                  ),
                  // Total hari
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${stats['total']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const Text(
                          'Total Hari',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFFE5E7EB),
                  ),
                  // Weekend
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${stats['weekends']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const Text(
                          'Weekend',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFFE5E7EB),
                  ),
                  // Hari libur
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${stats['holidays']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const Text(
                          'Libur',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePeriod(WorkPeriod period) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Periode?'),
        content: Text(
          'Yakin hapus periode ${_monthNames[period.bulan - 1]} ${period.tahun}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await CompanyCalendarService.deleteWorkPeriod(
        id: period.id,
        deletedBy: _hrdUserId ?? '',
      );

      if (result['success'] == true) {
        _snack('Periode kerja berhasil dihapus!');
        await _loadPeriods();
      } else {
        _snack(result['message'] ?? 'Gagal menghapus periode', err: true);
      }
    }
  }

  Future<void> _showPeriodDialog({WorkPeriod? existing}) async {
    int selectedYear = existing?.tahun ?? _selectedYear;
    int selectedMonth = existing?.bulan ?? _selectedMonth;

    DateTime startDate =
        existing?.tanggalMulai ?? DateTime(selectedYear, selectedMonth, 1);

    DateTime endDate =
        existing?.tanggalSelesai ??
        DateTime(selectedYear, selectedMonth + 1, 0);

    final ketCtrl = TextEditingController(text: existing?.keterangan ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            existing == null ? 'Tambah Periode Kerja' : 'Edit Periode Kerja',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: _periodInputDecoration('Tahun'),
                  // BUG lama: jendela tahun cuma currentYear-5..+5 — kalau
                  // edit periode kerja lama yang tahunnya di luar jendela
                  // itu (mis. rekap dari beberapa tahun lalu), value tidak
                  // ada di items dan dropdown-nya crash. Selalu sisipkan
                  // selectedYear supaya tetap valid dipilih.
                  items:
                      ({
                            ...List.generate(
                              11,
                              (i) => DateTime.now().year - 5 + i,
                            ),
                            selectedYear,
                          }.toList()..sort())
                          .map(
                            (year) => DropdownMenuItem(
                              value: year,
                              child: Text('$year'),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setDlg(() {
                      selectedYear = v;
                      startDate = DateTime(
                        selectedYear,
                        selectedMonth,
                        startDate.day,
                      );
                      endDate = DateTime(
                        selectedYear,
                        selectedMonth,
                        endDate.day,
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  value: selectedMonth,
                  decoration: _periodInputDecoration('Bulan Periode'),
                  items: List.generate(12, (i) {
                    final month = i + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text(_monthNames[i]),
                    );
                  }),
                  onChanged: (v) {
                    if (v == null) return;
                    setDlg(() {
                      selectedMonth = v;
                      startDate = DateTime(selectedYear, selectedMonth, 1);
                      endDate = DateTime(selectedYear, selectedMonth + 1, 0);
                    });
                  },
                ),
                const SizedBox(height: 12),

                _datePickTile(
                  title: 'Tanggal Mulai',
                  date: startDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (_, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF6366F1),
                          ),
                        ),
                        child: child!,
                      ),
                    );

                    if (picked != null) {
                      setDlg(() => startDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),

                _datePickTile(
                  title: 'Tanggal Selesai',
                  date: endDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (_, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF6366F1),
                          ),
                        ),
                        child: child!,
                      ),
                    );

                    if (picked != null) {
                      setDlg(() => endDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: ketCtrl,
                  maxLines: 2,
                  decoration: _periodInputDecoration(
                    'Keterangan',
                    hint: 'Contoh: Periode kerja tutup buku Juni',
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: Color(0xFF6366F1),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Periode kerja ini tidak mengirim notifikasi ke karyawan. Data ini hanya untuk pengaturan absensi dan laporan.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_hrdUserId == null || _hrdUserId!.isEmpty) {
                  _snack(
                    'User HRD tidak ditemukan. Silakan login ulang.',
                    err: true,
                  );
                  return;
                }

                if (startDate.isAfter(endDate)) {
                  _snack(
                    'Tanggal mulai tidak boleh lebih besar dari tanggal selesai',
                    err: true,
                  );
                  return;
                }

                Navigator.pop(ctx);

                final result = await CompanyCalendarService.saveWorkPeriod(
                  id: existing?.id,
                  tahun: selectedYear,
                  bulan: selectedMonth,
                  tanggalMulai: DateFormat('yyyy-MM-dd').format(startDate),
                  tanggalSelesai: DateFormat('yyyy-MM-dd').format(endDate),
                  keterangan: ketCtrl.text.trim(),
                  createdBy: _hrdUserId ?? '',
                );

                if (result['success'] == true) {
                  _snack(
                    existing == null
                        ? 'Periode kerja berhasil ditambahkan!'
                        : 'Periode kerja berhasil diupdate!',
                  );
                  await _loadPeriods();
                } else {
                  _snack(
                    result['message'] ?? 'Gagal menyimpan periode',
                    err: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: Text(existing == null ? 'Simpan' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _periodInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6366F1)),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _datePickTile({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Color(0xFF6366F1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            Text(
              DateFormat('dd MMM yyyy', 'id_ID').format(date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: LIST ───────────────────────────────────────────────────
  Widget _buildListTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _selectedYear--);
                  _loadEvents();
                },
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$_selectedYear',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _selectedYear++);
                  _loadEvents();
                },
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              // Filter chips: SEMUA | LIBUR | WFH | INFO | ULTAH
              ...[
                ('SEMUA', Colors.grey),
                ('LIBUR', const Color(0xFFEF4444)),
                ('WFH', const Color(0xFF10B981)),
                ('INFO', const Color(0xFF3B82F6)),
                ('ULTAH', const Color(0xFFEC4899)),
              ].map((item) {
                final sel = _filterTipe == item.$1;
                return GestureDetector(
                  onTap: () => setState(() => _filterTipe = item.$1),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? item.$2.withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: sel ? item.$2 : const Color(0xFFE5E7EB),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? item.$2 : Colors.grey,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),

        if (!_isLoading && _events.isNotEmpty) _buildStatsBar(),

        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                )
              : _filteredEvents.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (_, i) => _buildEventCard(_filteredEvents[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    final liburCount = _events.where((e) => e.tipe == 'LIBUR').length;
    final wfhCount = _events.where((e) => e.tipe == 'WFH').length;
    final infoCount = _events.where((e) => e.tipe == 'INFO').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _statChip('$liburCount Libur', const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _statChip('$wfhCount WFH', const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _statChip('$infoCount Info', const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _buildEventCard(CompanyCalendarEvent event) {
    final color = _tipeColor(event.tipe);
    final isSabtu = event.tanggal.weekday == DateTime.saturday;
    final isMinggu = event.tanggal.weekday == DateTime.sunday;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Tanggal box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${event.tanggal.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    _monthNames[event.tanggal.month - 1].substring(0, 3),
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.keterangan,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 11,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat(
                          'EEEE, dd MMM yyyy',
                          'id_ID',
                        ).format(event.tanggal),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      if (isSabtu || isMinggu) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isSabtu ? 'Sabtu' : 'Minggu',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.red[400],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      // ── Indikator lampiran (BARU) ──────────────
                      if (event.hasAttachment) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _previewCalendarAttachment(event),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_file,
                                  size: 10,
                                  color: const Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Lampiran',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: const Color(0xFF6366F1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Badge tipe
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _tipeLabel(event.tipe),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Menu edit/delete — disembunyikan untuk entri ulang tahun
            // (dihitung live oleh backend, tidak ada baris DB untuk diedit).
            if (!event.isUltah)
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') _showFormDialog(existing: event);
                  if (val == 'delete') _confirmDelete(event);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Color(0xFFEF4444)),
                        SizedBox(width: 8),
                        Text('Hapus'),
                      ],
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewCalendarAttachment(CompanyCalendarEvent event) async {
    _snack('Membuka lampiran...');

    final bytes = await CompanyCalendarService.downloadAttachment(event.id);
    if (bytes == null || bytes.isEmpty) {
      _snack('Gagal memuat lampiran', err: true);
      return;
    }

    final fileName = event.attachmentFileName ?? 'lampiran';
    final contentType = event.attachmentContentType ?? '';
    final isImg =
        contentType.startsWith('image/') ||
        [
          '.jpg',
          '.jpeg',
          '.png',
        ].any((e) => fileName.toLowerCase().endsWith(e));
    final isPdf =
        contentType == 'application/pdf' ||
        fileName.toLowerCase().endsWith('.pdf');

    if (!mounted) return;

    if (isImg) {
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) {
          final screenW = MediaQuery.of(ctx).size.width;
          final screenH = MediaQuery.of(ctx).size.height;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: screenW,
                    height: screenH,
                    color: Colors.transparent,
                  ),
                ),
                Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: screenW * 0.95,
                      maxHeight: screenH * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1F2937),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 5.0,
                              child: Image.memory(
                                Uint8List.fromList(bytes),
                                fit: BoxFit.contain,
                                width: screenW * 0.95,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (isPdf) {
      if (kIsWeb) {
        previewFileWeb(Uint8List.fromList(bytes), fileName);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _snack('Tidak dapat membuka PDF: ${result.message}', err: true);
        }
      }
    } else {
      _snack('Tipe file tidak didukung untuk preview', err: true);
    }
  }

  // ── TAB 2: KALENDER GRID ──────────────────────────────────────────
  Widget _buildCalendarTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  if (_selectedMonth == 1) {
                    _selectedMonth = 12;
                    _selectedYear--;
                    _loadEvents();
                  } else {
                    _selectedMonth--;
                  }
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedMonth = DateTime.now().month;
                  _selectedYear = DateTime.now().year;
                }),
                child: Column(
                  children: [
                    Text(
                      '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${_eventsForMonth(_selectedMonth).length} event',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  if (_selectedMonth == 12) {
                    _selectedMonth = 1;
                    _selectedYear++;
                    _loadEvents();
                  } else {
                    _selectedMonth++;
                  }
                }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              children: [
                _buildMonthGrid(_selectedMonth),
                const SizedBox(height: 20),
                _buildMonthEventList(_selectedMonth),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(int month) {
    final firstDay = DateTime(_selectedYear, month, 1);
    final lastDay = DateTime(_selectedYear, month + 1, 0);
    final startWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: _dayNames
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: d == 'Min'
                                ? Colors.red
                                : d == 'Sab'
                                ? Colors.red[300]
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 8),
            ..._buildGridRows(firstDay, lastDay, startWeekday),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGridRows(
    DateTime firstDay,
    DateTime lastDay,
    int startWeekday,
  ) {
    final List<Widget> rows = [];
    List<Widget> cells = [];

    for (int i = 0; i < startWeekday; i++) {
      cells.add(const Expanded(child: SizedBox(height: 48)));
    }

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_selectedYear, firstDay.month, day);
      final events = _eventsForDate(date);
      final isToday =
          date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;
      final isSunday = date.weekday == DateTime.sunday;
      final isSaturday = date.weekday == DateTime.saturday;
      final isWeekend = isSunday || isSaturday;

      // ── Warna cell ────────────────────────────────────────────────
      // INFO tidak mengubah warna cell — hanya dot biru yang muncul
      Color? bgColor;
      Color textColor;

      if (isToday) {
        bgColor = const Color(0xFF6366F1);
        textColor = Colors.white;
      } else if (events.any((e) => e.tipe == 'LIBUR')) {
        bgColor = const Color(0xFFEF4444).withOpacity(0.1);
        textColor = const Color(0xFFEF4444);
      } else if (events.any((e) => e.tipe == 'WFH')) {
        bgColor = const Color(0xFF10B981).withOpacity(0.1);
        textColor = const Color(0xFF10B981);
      } else if (isWeekend) {
        textColor = Colors.red[300]!;
      } else {
        // INFO tidak ubah warna — warna normal
        textColor = const Color(0xFF1E293B);
      }

      cells.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (events.isNotEmpty) {
                _showDayEventsSheet(date, events);
              } else {
                _showFormDialog(initialDate: date);
              }
            },
            onLongPress: () => _showFormDialog(initialDate: date),
            child: Container(
              height: 48,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: const Color(0xFF6366F1), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events
                          .take(3)
                          .map(
                            (e) => Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.white
                                    : _tipeColor(e.tipe),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      if ((startWeekday + day) % 7 == 0 || day == lastDay.day) {
        if (day == lastDay.day) {
          final rem = 7 - cells.length;
          for (int i = 0; i < rem; i++) {
            cells.add(const Expanded(child: SizedBox(height: 48)));
          }
        }
        rows.add(Row(children: List.from(cells)));
        cells.clear();
      }
    }
    return rows;
  }

  Widget _buildMonthEventList(int month) {
    final events = _eventsForMonth(month)
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'Tidak ada event di bulan ini',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _showFormDialog(
                initialDate: DateTime(_selectedYear, month, 1),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Event'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Event ${_monthNames[month - 1]} $_selectedYear',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        ...events.map((e) => _buildEventCard(e)),
      ],
    );
  }

  void _showDayEventsSheet(DateTime date, List<CompanyCalendarEvent> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showFormDialog(initialDate: date);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...events.map(
                    (e) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _tipeColor(e.tipe).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _tipeColor(e.tipe).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _tipeIcon(e.tipe),
                            color: _tipeColor(e.tipe),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.keterangan,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _tipeLabel(e.tipe),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _tipeColor(e.tipe),
                                  ),
                                ),
                                // Info hint untuk tipe INFO
                                if (e.tipe == 'INFO')
                                  Text(
                                    'Hanya informasi · tidak mempengaruhi absen',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[400],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Ulang tahun dihitung live oleh backend — tidak
                          // ada baris DB untuk diedit/dihapus.
                          if (!e.isUltah) ...[
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showFormDialog(existing: e);
                              },
                              icon: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Color(0xFF6366F1),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmDelete(e);
                              },
                              icon: const Icon(
                                Icons.delete,
                                size: 16,
                                color: Color(0xFFEF4444),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.event_note,
              size: 56,
              color: Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Event',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap tombol + untuk menambah hari libur, WFH, atau info pengumuman',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    ),
  );
}
