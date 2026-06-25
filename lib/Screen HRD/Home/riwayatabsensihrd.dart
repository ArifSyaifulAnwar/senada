// screens/halaman_hrd_absensi.dart — FULL REPLACE
// ignore_for_file: curly_braces_in_flow_control_structures, library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:absensikaryawan/Services/excel_export_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Screen admin/model/admin_attendance_model.dart';
import '../../Screen admin/service/admin_attendance_service.dart';
import '../../Screen admin/service/hrd_attendance_service.dart';
import '../../Services/company_calendar_service.dart';
import '../doa_karyawan_screen.dart';
import '../hrd_absensi_edit.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← TAMBAH
import 'dart:convert';
import 'dart:typed_data';

bool _isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 768;

class HalamanHRDAbsensi extends StatefulWidget {
  const HalamanHRDAbsensi({super.key});
  @override
  _HalamanHRDAbsensiState createState() => _HalamanHRDAbsensiState();
}

class _HalamanHRDAbsensiState extends State<HalamanHRDAbsensi>
    with SingleTickerProviderStateMixin {
  final AdminAttendanceService _adminService = AdminAttendanceService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  DateTime? _dashboardDate; // null = hari ini
  bool isLoading = false;
  String errorMessage = '';
  String selectedTimeRange = 'Pilih Periode';
  DateTimeRange? customDateRange;
  String selectedStatusFilter = 'Semua';
  Employee? selectedEmployee;
  Office? selectedOffice;
  String? selectedDepartment;
  String searchTerm = '';
  bool _loadingAnalytics = true;
  List<AdminAttendanceData> _analyticsData = [];
  List<HrdWorkPeriod> _analyticsPeriods = [];
  HrdWorkPeriod? _selectedAnalyticsPeriod;
  final int _analyticsYear = DateTime.now().year;
  List<AdminAttendanceData> attendanceData = [];
  AdminAttendanceStats? stats;
  List<Employee> employees = [];
  List<Office> offices = [];
  List<String> departments = [];
  List<Map<String, dynamic>> _tidakHadirList = [];
  bool _isSendingBelumAbsenWa = false;
  int currentPage = 1;
  int totalPages = 1;
  bool hasMoreData = false;
  bool isExporting = false;
  Map<String, int> departmentStats = {};
  Map<String, double> attendanceRateByDepartment = {};
  List<Employee> problematicEmployees = [];
  int _webTabIndex = 0;
  String? _currentUserId;
  Map<String, String> _doaMap = {};
  Employee? _selectedAnalyticsEmployee;
  List<CompanyCalendarEvent> _analyticsCalendarEvents = [];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _webTabIndex = _tabController.index);
    });
    _initAll(); // ← ganti jadi 1 fungsi yang sequential
  }

  Future<void> _loadDefaultWorkPeriod() async {
    try {
      final result = await _adminService.getCurrentWorkPeriod();

      if (result.success && result.data != null) {
        setState(() {
          selectedTimeRange = 'Pilih Periode';
          customDateRange = result.data;
        });
      } else {
        final now = DateTime.now();
        setState(() {
          selectedTimeRange = 'Pilih Periode';
          customDateRange = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          );
        });
      }
    } catch (_) {
      final now = DateTime.now();
      setState(() {
        selectedTimeRange = 'Pilih Periode';
        customDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
      });
    }
  }

  Future<void> _sendBelumAbsenWa() async {
    if (_isSendingBelumAbsenWa) return;

    if (_tidakHadirList.isEmpty) {
      _showErrorSnackBar('Tidak ada karyawan yang belum absen.');
      return;
    }

    final now = DateTime.now();
    final targetDate = _dashboardDate ?? now;

    final isToday =
        DateFormat('yyyy-MM-dd').format(targetDate) ==
        DateFormat('yyyy-MM-dd').format(now);

    if (!isToday) {
      _showErrorSnackBar('Notifikasi WA hanya bisa dikirim untuk hari ini.');
      return;
    }

    final totalBelumAbsen = _tidakHadirList.length;
    final totalDiproses = totalBelumAbsen > 5 ? 5 : totalBelumAbsen;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kirim Pengingat WA?'),
        content: Text(
          'Sistem akan memproses pengingat WhatsApp untuk $totalDiproses dari $totalBelumAbsen karyawan yang belum absen.\n\n'
          'Pengiriman dibatasi maksimal 5 orang per klik agar akun WhatsApp lebih aman dan tidak terdeteksi spam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Proses'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      setState(() => _isSendingBelumAbsenWa = true);
    }

    try {
      final result = await _adminService.notifyBelumAbsenWa(
        tanggal: targetDate,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.message,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );

        await _loadTidakHadirList();
      } else {
        _showErrorSnackBar(result.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal memproses notifikasi WA: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingBelumAbsenWa = false);
      }
    }
  }

  Future<void> _initAll() async {
    await _loadCurrentUser();
    await _loadDefaultWorkPeriod();
    await _loadAnalyticsPeriods();
    await _loadInitialData();
  }

  Future<void> _loadAnalyticsPeriods() async {
    try {
      final result = await _adminService.getWorkPeriodsByYear(
        tahun: _analyticsYear,
      );

      final calendarEvents = await CompanyCalendarService.getByYear(
        _analyticsYear,
        forceRefresh: true,
      );

      if (!mounted) return;

      if (result.success && result.data != null && result.data!.isNotEmpty) {
        final periods = result.data!;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Pilih periode yang rentang tanggalnya benar-benar mencakup hari ini.
        // Jangan gunakan `bulan == now.month`, karena periode baru bisa mulai
        // sebelum bulan kalender berganti.
        final activePeriods = periods.where((p) {
          final start = DateTime(
            p.tanggalMulai.year,
            p.tanggalMulai.month,
            p.tanggalMulai.day,
          );
          final end = DateTime(
            p.tanggalSelesai.year,
            p.tanggalSelesai.month,
            p.tanggalSelesai.day,
          );

          return !today.isBefore(start) && !today.isAfter(end);
        }).toList()..sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));

        final currentPeriod = activePeriods.isNotEmpty
            ? activePeriods.first
            : periods.last;

        setState(() {
          _analyticsPeriods = periods;
          _selectedAnalyticsPeriod = currentPeriod;
          _analyticsCalendarEvents = calendarEvents;
        });
      } else {
        setState(() {
          _analyticsPeriods = [];
          _selectedAnalyticsPeriod = null;
          _analyticsCalendarEvents = calendarEvents;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _analyticsPeriods = [];
          _selectedAnalyticsPeriod = null;
          _analyticsCalendarEvents = [];
        });
      }
    }
  }

  DateTime _onlyDate(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isLiburHrd(DateTime date) {
    return _analyticsCalendarEvents.any((e) {
      return e.isLibur && _isSameDate(e.tanggal, date);
    });
  }

  bool _isWorkdayForAnalytics(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }

    if (_isLiburHrd(date)) {
      return false;
    }

    return true;
  }

  int _effectiveWorkDaysInSelectedPeriod() {
    final p = _selectedAnalyticsPeriod;

    if (p == null) return 0;

    final today = _onlyDate(DateTime.now());
    final start = _onlyDate(p.tanggalMulai);
    final periodEnd = _onlyDate(p.tanggalSelesai);

    // Kalau periode sekarang belum selesai, hitung sampai hari ini saja.
    // Kalau periode lama, hitung sampai tanggal selesai periode.
    final end = periodEnd.isAfter(today) ? today : periodEnd;

    if (end.isBefore(start)) return 0;

    int total = 0;
    DateTime current = start;

    while (!current.isAfter(end)) {
      if (_isWorkdayForAnalytics(current)) {
        total++;
      }

      current = current.add(const Duration(days: 1));
    }

    return total;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── TAMBAH: load user ID dari SharedPreferences ──────────────────────
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted)
        setState(() {
          _currentUserId = prefs.getString('UserID');
        });
    } catch (_) {}
  }
  // ────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadEmployees(),
      _loadOffices(),
      _loadDashboardStats(),
    ]);
    await _loadAttendanceData(refresh: true);
    await _loadHRDAnalytics();
    await _loadTidakHadirList(); // ← load sendiri, tidak bergantung attendanceData
    await _loadAnalyticsData(); // ← load data untuk tab Analitik (terpisah dari _loadHRDAnalytics)
  }

  // Ambil SEMUA data absensi tahun berjalan (loop semua halaman, page_size 1000)
  Future<void> _loadAnalyticsData() async {
    if (mounted) setState(() => _loadingAnalytics = true);

    try {
      DateTime start;
      DateTime end;

      if (_selectedAnalyticsPeriod != null) {
        start = _selectedAnalyticsPeriod!.tanggalMulai;
        end = _selectedAnalyticsPeriod!.tanggalSelesai;
      } else {
        final now = DateTime.now();
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
      }

      final all = <AdminAttendanceData>[];
      int page = 1;
      int totalPages = 1;

      do {
        final r = await _adminService.getAllAttendanceData(
          filterUserId: _selectedAnalyticsEmployee?.userId,
          startDate: start,
          endDate: end,
          page: page,
          pageSize: 1000,
        );

        if (!r.success) break;

        all.addAll(r.data?.data ?? []);
        totalPages = r.data?.totalPages ?? 1;
        page++;
      } while (page <= totalPages && page <= 60);

      if (mounted) {
        setState(() {
          _analyticsData = all;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _analyticsData = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAnalytics = false);
      }
    }
  }

  String _analyticsPeriodLabel() {
    final p = _selectedAnalyticsPeriod;

    if (p == null) {
      return 'Periode belum disetting';
    }

    return '${p.bulanLabel} • '
        '${DateFormat('dd MMM yyyy', 'id_ID').format(p.tanggalMulai)} - '
        '${DateFormat('dd MMM yyyy', 'id_ID').format(p.tanggalSelesai)}';
  }

  Widget _buildAnalyticsPeriodFilter() {
    return GestureDetector(
      onTap: _showAnalyticsPeriodSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _analyticsPeriodLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalyticsPeriodSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
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

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Pilih Periode Analitik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              if (_analyticsPeriods.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada periode kerja yang disetting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _analyticsPeriods.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _analyticsPeriods[i];

                      final selected = _selectedAnalyticsPeriod?.id == p.id;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          p.bulanLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy', 'id_ID').format(p.tanggalMulai)} - '
                          '${DateFormat('dd MMM yyyy', 'id_ID').format(p.tanggalSelesai)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF6366F1),
                              )
                            : null,
                        selected: selected,
                        onTap: () async {
                          Navigator.pop(context);

                          setState(() {
                            _selectedAnalyticsPeriod = p;
                          });

                          await _loadAnalyticsData();
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadEmployees() async {
    try {
      final r = await _adminService.getEmployees();
      if (r.success) {
        setState(() {
          employees = r.data ?? [];
          departments =
              employees.map((e) => e.department ?? 'Unknown').toSet().toList()
                ..sort();
        });
      }
    } catch (_) {
      setState(() => employees = []);
    }
  }

  Future<void> _loadOffices() async {
    try {
      final r = await _adminService.getOffices();
      if (r.success) setState(() => offices = r.data ?? []);
    } catch (_) {
      setState(() => offices = []);
    }
  }

  Future<void> _loadTidakHadirList() async {
    if (employees.isEmpty) return;

    try {
      final now = DateTime.now();
      final targetDate = _dashboardDate ?? now;
      final targetStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final isToday = targetStr == DateFormat('yyyy-MM-dd').format(now);
      final jamSekarang = now.hour * 60 + now.minute;
      final jam17 = 17 * 60;

      // Load data absensi untuk tanggal yang dipilih
      final r = await _adminService.getAllAttendanceData(
        timeRange: isToday ? 'Hari Ini' : null,
        startDate: isToday ? null : targetDate,
        endDate: isToday ? null : targetDate,
        page: 1,
        pageSize: 500,
      );

      final hadirUserIds = (r.data?.data ?? [])
          .where(
            (d) =>
                DateFormat('yyyy-MM-dd').format(d.attendanceDate) == targetStr,
          )
          .map((d) => d.userId)
          .toSet();

      // Label: kalau hari ini sebelum jam 17 → "Belum Absen", lainnya → "Tidak Hadir"
      final label = (isToday && jamSekarang < jam17)
          ? 'Belum Absen'
          : 'Tidak Hadir';

      final tidakHadir = employees
          .where((e) => !hadirUserIds.contains(e.userId))
          .map(
            (e) => {
              'userId': e.userId,
              'name': e.name,
              'department': e.department ?? '-',
              'label': label,
            },
          )
          .toList();

      if (mounted) setState(() => _tidakHadirList = tidakHadir);
    } catch (_) {
      if (mounted) setState(() => _tidakHadirList = []);
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      String? timeRangeToSend;
      DateTime? startDateToSend, endDateToSend;

      if (_dashboardDate != null) {
        // ← Filter dari date picker dashboard
        startDateToSend = _dashboardDate;
        endDateToSend = _dashboardDate;
      } else if (selectedTimeRange == 'Pilih Periode' &&
          customDateRange != null) {
        startDateToSend = customDateRange!.start;
        endDateToSend = customDateRange!.end;
      } else if (selectedTimeRange != 'Semua Data') {
        timeRangeToSend = selectedTimeRange;
      }

      final r = await _adminService.getDashboardStats(
        timeRange: timeRangeToSend,
        startDate: startDateToSend,
        endDate: endDateToSend,
      );
      if (r.success) setState(() => stats = r.data ?? AdminAttendanceStats());
    } catch (_) {
      setState(() => stats = AdminAttendanceStats());
    }
  }

  Future<void> _loadHRDAnalytics() async {
    try {
      final Map<String, int> deptStats = {};
      final Map<String, List<AdminAttendanceData>> deptAtt = {};
      for (var d in attendanceData) {
        final dept = d.department ?? 'Unknown';
        deptStats[dept] = (deptStats[dept] ?? 0) + 1;
        deptAtt.putIfAbsent(dept, () => []).add(d);
      }
      final Map<String, double> deptRate = {};
      deptAtt.forEach((dept, list) {
        final present = list
            .where(
              (d) =>
                  d.displayStatus.toLowerCase().contains('tepat') ||
                  d.displayStatus.toLowerCase().contains('terlambat'),
            )
            .length;
        deptRate[dept] = list.isEmpty ? 0 : present / list.length * 100;
      });
      final Map<String, List<AdminAttendanceData>> empAtt = {};
      for (var d in attendanceData) {
        empAtt.putIfAbsent(d.userId, () => []).add(d);
      }
      final List<Employee> problematic = [];
      empAtt.forEach((userId, list) {
        final late = list
            .where((d) => d.displayStatus.toLowerCase().contains('terlambat'))
            .length;
        final absent = list
            .where(
              (d) =>
                  d.displayStatus.toLowerCase().contains('tidak hadir') ||
                  d.displayStatus.toLowerCase().contains('absent'),
            )
            .length;
        final rate = list.isEmpty ? 0.0 : (late + absent) / list.length * 100;
        if (rate > 30) {
          problematic.add(
            employees.firstWhere(
              (e) => e.userId == userId,
              orElse: () => Employee(userId: userId, name: 'Unknown'),
            ),
          );
        }
      });
      setState(() {
        departmentStats = deptStats;
        attendanceRateByDepartment = deptRate;
        problematicEmployees = problematic;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal meload data HRD.')));
    }
  }

  Future<void> _loadAttendanceData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        isLoading = true;
        errorMessage = '';
        currentPage = 1;
        attendanceData.clear();
      });
    }
    try {
      String? timeRangeToSend;
      DateTime? startDateToSend, endDateToSend;
      if (selectedTimeRange == 'Pilih Periode' && customDateRange != null) {
        startDateToSend = customDateRange!.start;
        endDateToSend = customDateRange!.end;
      } else if (selectedTimeRange != 'Semua Data') {
        timeRangeToSend = selectedTimeRange;
      }
      final r = await _adminService.getAllAttendanceData(
        filterUserId: selectedEmployee?.userId,
        timeRange: timeRangeToSend,
        startDate: startDateToSend,
        endDate: endDateToSend,
        statusFilter: selectedStatusFilter != 'Semua'
            ? selectedStatusFilter
            : null,
        officeId: selectedOffice?.id,
        searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
        page: currentPage,
        pageSize: 50,
      );
      if (r.success) {
        setState(() {
          if (refresh)
            attendanceData = r.data?.data ?? [];
          else
            attendanceData.addAll(r.data?.data ?? []);
          totalPages = r.data?.totalPages ?? 1;
          hasMoreData = currentPage < totalPages;
          isLoading = false;
          errorMessage = '';
        });
        if (refresh) {
          await _loadHRDAnalytics();
          await _loadDoaMap(); // ← TAMBAH: load doa otomatis setelah absensi
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = r.message;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (!hasMoreData || isLoading) return;
    setState(() => currentPage++);
    await _loadAttendanceData();
  }

  Future<void> _refreshData() async {
    await _loadDefaultWorkPeriod();
    await _loadAnalyticsPeriods();
    await _loadInitialData();
  }

  // ── TAMBAH: Load doa map otomatis ────────────────────────────────────
  Future<void> _loadDoaMap() async {
    if (_currentUserId == null || attendanceData.isEmpty) return;

    final uniqueDates =
        attendanceData
            .map(
              (d) => DateTime(
                d.attendanceDate.year,
                d.attendanceDate.month,
                d.attendanceDate.day,
              ),
            )
            .toSet()
            .toList()
          ..sort();

    final newMap = <String, String>{};

    for (final tanggal in uniqueDates) {
      try {
        final records = await DoaService.getDoaByTanggal(
          _currentUserId!,
          tanggal,
        );
        for (final rec in records) {
          final tStr = DateFormat('yyyy-MM-dd').format(
            DateTime(rec.tanggal.year, rec.tanggal.month, rec.tanggal.day),
          );
          newMap['${tStr}_${rec.pemimpinDoaId.toLowerCase()}'] = 'ikut';
          for (final uid in rec.pesertaIds) {
            newMap['${tStr}_${uid.toLowerCase()}'] = 'ikut';
          }
        }
      } catch (_) {}
    }

    // Karyawan yang HADIR tapi tidak ikut doa → 'tidak'
    final hariAdaDoa = newMap.keys.map((k) => k.split('_').first).toSet();
    for (final d in attendanceData) {
      // Skip yang tidak hadir — tidak dihitung doa
      final status = d.displayStatus.toLowerCase();
      if (status.contains('tidak hadir') ||
          status.contains('tidak absen') ||
          status.contains('absent'))
        continue;

      final tStr = DateFormat('yyyy-MM-dd').format(
        DateTime(
          d.attendanceDate.year,
          d.attendanceDate.month,
          d.attendanceDate.day,
        ),
      );
      final key = '${tStr}_${d.userId.toLowerCase()}';
      if (hariAdaDoa.contains(tStr) && !newMap.containsKey(key)) {
        newMap[key] = 'tidak';
      }
    }

    if (mounted) setState(() => _doaMap = newMap);
  }
  // ────────────────────────────────────────────────────────────────────

  // ── TAMBAH: Inject baris "Tidak Hadir" untuk export multi-hari ───────
  List<AdminAttendanceData> _buildDataWithTidakHadir(
    List<AdminAttendanceData> rawData, {
    required DateTime startDate,
    required DateTime endDate,
    required List<CompanyCalendarEvent> calendarEvents,
  }) {
    if (rawData.isEmpty) return rawData;

    final start = DateTime(startDate.year, startDate.month, startDate.day);

    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (end.isBefore(start)) return rawData;

    // Key record yang sudah ada: userid_yyyy-MM-dd
    final existingKeys = rawData
        .map(
          (d) =>
              '${d.userId}_${DateFormat('yyyy-MM-dd').format(d.attendanceDate)}',
        )
        .toSet();

    // Sample 1 record per user untuk copy nama, dept, employeeId, dll
    final userSample = <String, AdminAttendanceData>{};
    for (final d in rawData) {
      userSample.putIfAbsent(d.userId, () => d);
    }

    final result = List<AdminAttendanceData>.from(rawData);

    var current = start;

    while (!current.isAfter(end)) {
      // Skip Sabtu, Minggu, dan LIBUR dari kalender HRD
      if (!_isLiburExport(current, calendarEvents)) {
        for (final entry in userSample.entries) {
          final uid = entry.key;
          final sample = entry.value;

          final key = '${uid}_${DateFormat('yyyy-MM-dd').format(current)}';

          if (!existingKeys.contains(key)) {
            result.add(
              AdminAttendanceData(
                id: -1,
                userId: uid,
                userName: sample.userName,
                employeeId: sample.employeeId,
                department: sample.department,
                attendanceDate: current,
                checkInTime: null,
                checkOutTime: null,
                checkInLatitude: null,
                checkInLongitude: null,
                checkOutLatitude: null,
                checkOutLongitude: null,
                checkInOfficeId: null,
                checkOutOfficeId: null,
                checkInOfficeName: null,
                checkOutOfficeName: null,
                checkInStatus: 'Tidak Hadir / Tidak Absen',
                checkOutStatus: '',
                checkInFaceConfidence: null,
                checkOutFaceConfidence: null,
                workingHoursMinutes: null,
                overtimeMinutes: null,
                notes: '',
                createdAt: current,
                updatedAt: current,
                displayStatus: 'Tidak Hadir / Tidak Absen',
                formattedCheckIn: '-',
                formattedCheckOut: '-',
              ),
            );

            existingKeys.add(key);
          }
        }
      }

      current = current.add(const Duration(days: 1));
    }

    result.sort((a, b) {
      final userCompare = a.userName.compareTo(b.userName);
      if (userCompare != 0) return userCompare;

      return b.attendanceDate.compareTo(a.attendanceDate);
    });

    return result;
  }

  void _updateAttendanceItem(
    int id, {
    String? newCheckInTime,
    String? newCheckOutTime,
    String? newCheckInStatus,
    String? newCheckOutStatus,
    String? newNotes,
  }) {
    setState(() {
      final idx = attendanceData.indexWhere((d) => d.id == id);
      if (idx == -1) return;
      final old = attendanceData[idx];

      int? newWorking;
      final ciDt = newCheckInTime != null
          ? DateTime.tryParse(newCheckInTime)
          : old.checkInTime;
      final coDt = newCheckOutTime != null
          ? DateTime.tryParse(newCheckOutTime)
          : old.checkOutTime;
      if (ciDt != null && coDt != null)
        newWorking = coDt.difference(ciDt).inMinutes;

      final statusRaw = newCheckInStatus ?? old.checkInStatus;
      String newDisplay = old.displayStatus;
      final s = statusRaw.toLowerCase();
      if (s.contains('tepat'))
        newDisplay = 'Tepat Waktu';
      else if (s.contains('terlambat'))
        newDisplay = 'Terlambat';
      else if (s.contains('cuti'))
        newDisplay = 'Cuti';
      else if (s.contains('absent') || s.contains('tidak hadir'))
        newDisplay = 'Tidak Hadir';
      else
        newDisplay = statusRaw;

      attendanceData[idx] = AdminAttendanceData(
        id: old.id,
        userId: old.userId,
        userName: old.userName,
        employeeId: old.employeeId,
        department: old.department,
        attendanceDate: old.attendanceDate,
        checkInTime: newCheckInTime != null
            ? DateTime.parse(newCheckInTime)
            : old.checkInTime,
        checkOutTime: newCheckOutTime != null
            ? DateTime.parse(newCheckOutTime)
            : old.checkOutTime,
        checkInLatitude: old.checkInLatitude,
        checkInLongitude: old.checkInLongitude,
        checkOutLatitude: old.checkOutLatitude,
        checkOutLongitude: old.checkOutLongitude,
        checkInOfficeId: old.checkInOfficeId,
        checkOutOfficeId: old.checkOutOfficeId,
        checkInOfficeName: old.checkInOfficeName,
        checkOutOfficeName: old.checkOutOfficeName,
        checkInStatus: newCheckInStatus ?? old.checkInStatus,
        checkOutStatus: newCheckOutStatus ?? old.checkOutStatus,
        checkInFaceConfidence: old.checkInFaceConfidence,
        checkOutFaceConfidence: old.checkOutFaceConfidence,
        workingHoursMinutes: newWorking ?? old.workingHoursMinutes,
        overtimeMinutes: old.overtimeMinutes,
        notes: newNotes ?? old.notes,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
        displayStatus: newDisplay,
        formattedCheckIn: newCheckInTime != null
            ? _fmtTime(DateTime.parse(newCheckInTime))
            : old.formattedCheckIn,
        formattedCheckOut: newCheckOutTime != null
            ? _fmtTime(DateTime.parse(newCheckOutTime))
            : old.formattedCheckOut,
      );
    });
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _openEditSheet(AdminAttendanceData data) {
    final hrdData = HrdAttendanceData(
      id: data.id,
      userId: data.userId,
      userName: data.userName,
      employeeId: data.employeeId,
      department: data.department,
      attendanceDate: data.attendanceDate.toIso8601String().split('T')[0],
      checkInTime: data.checkInTime?.toIso8601String(),
      checkOutTime: data.checkOutTime?.toIso8601String(),
      checkInStatus: data.checkInStatus,
      checkOutStatus: data.checkOutStatus,
      workingHoursMinutes: data.workingHoursMinutes,
      notes: data.notes,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAttendanceSheet(
        data: hrdData,
        onSaved:
            ({
              String? checkInTime,
              String? checkOutTime,
              String? checkInStatus,
              String? checkOutStatus,
              String? notes,
            }) {
              _updateAttendanceItem(
                data.id,
                newCheckInTime: checkInTime,
                newCheckOutTime: checkOutTime,
                newCheckInStatus: checkInStatus,
                newCheckOutStatus: checkOutStatus,
                newNotes: notes,
              );
            },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // EXPORT — DIUPDATE dengan doa + tidak hadir
  // ─────────────────────────────────────────────────────────────────

  Future<void> _exportData() async {
    setState(() => isExporting = true);

    try {
      String? periodLabel;
      DateTime? exportStartDate;
      DateTime? exportEndDate;

      // ── Tentukan label dan range export ─────────────────────────────
      if (selectedTimeRange == 'Pilih Periode' && customDateRange != null) {
        exportStartDate = DateTime(
          customDateRange!.start.year,
          customDateRange!.start.month,
          customDateRange!.start.day,
        );

        exportEndDate = DateTime(
          customDateRange!.end.year,
          customDateRange!.end.month,
          customDateRange!.end.day,
        );
      } else if (selectedTimeRange != 'Semua Data') {
        if (attendanceData.isNotEmpty) {
          final sortedDates =
              attendanceData.map((d) => d.attendanceDate).toList()..sort();

          exportStartDate = DateTime(
            sortedDates.first.year,
            sortedDates.first.month,
            sortedDates.first.day,
          );

          exportEndDate = DateTime(
            sortedDates.last.year,
            sortedDates.last.month,
            sortedDates.last.day,
          );
        }
      } else {
        if (attendanceData.isNotEmpty) {
          final sortedDates =
              attendanceData.map((d) => d.attendanceDate).toList()..sort();

          exportStartDate = DateTime(
            sortedDates.first.year,
            sortedDates.first.month,
            sortedDates.first.day,
          );

          exportEndDate = DateTime(
            sortedDates.last.year,
            sortedDates.last.month,
            sortedDates.last.day,
          );
        }
      }

      if (attendanceData.isEmpty) {
        _showErrorSnackBar('Tidak ada data absensi untuk diexport');
        if (mounted) setState(() => isExporting = false);
        return;
      }

      if (exportStartDate == null || exportEndDate == null) {
        _showErrorSnackBar('Range tanggal export tidak ditemukan');
        if (mounted) setState(() => isExporting = false);
        return;
      }
      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);

      if (exportEndDate.isAfter(todayOnly)) {
        exportEndDate = todayOnly;
      }

      // Kalau periode belum mulai, jangan export
      if (exportEndDate.isBefore(exportStartDate)) {
        _showErrorSnackBar('Periode export belum berjalan');
        if (mounted) setState(() => isExporting = false);
        return;
      }

      // Label setelah endDate dipotong ke hari ini
      periodLabel =
          '${DateFormat('dd MMM yyyy', 'id_ID').format(exportStartDate)} - '
          '${DateFormat('dd MMM yyyy', 'id_ID').format(exportEndDate)}';

      // ── Filter data asli supaya tidak ada data setelah hari ini ──────
      final filteredAttendanceData = attendanceData.where((d) {
        final dateOnly = DateTime(
          d.attendanceDate.year,
          d.attendanceDate.month,
          d.attendanceDate.day,
        );

        return !dateOnly.isBefore(exportStartDate!) &&
            !dateOnly.isAfter(exportEndDate!);
      }).toList();

      if (filteredAttendanceData.isEmpty) {
        _showErrorSnackBar('Tidak ada data absensi pada range export');
        if (mounted) setState(() => isExporting = false);
        return;
      }

      // ── Inject "Tidak Hadir" sinkron kalender HRD ───────────────────
      final isHariIni =
          selectedTimeRange == 'Hari Ini' || selectedTimeRange == '1 Hari';

      List<AdminAttendanceData> exportData = filteredAttendanceData;

      if (!isHariIni) {
        final calendarEvents = await _getCalendarEventsForExportRange(
          exportStartDate,
          exportEndDate,
        );

        exportData = _buildDataWithTidakHadir(
          filteredAttendanceData,
          startDate: exportStartDate,
          endDate: exportEndDate,
          calendarEvents: calendarEvents,
        );
      }

      // ── Build Excel ─────────────────────────────────────────────────
      // ── Hitung total hari kerja export ───────────────────────────────
      int totalHariKerja = 0;

      final calendarEventsForTotal = await _getCalendarEventsForExportRange(
        exportStartDate,
        exportEndDate,
      );

      totalHariKerja = _countHariKerjaExport(
        startDate: exportStartDate,
        endDate: exportEndDate,
        calendarEvents: calendarEventsForTotal,
      );

      // ── Build Excel ─────────────────────────────────────────────────
      final bytes = ExcelExportService.buildAbsensiExcel(
        exportData,
        periodLabel: periodLabel,
        doaMap: _doaMap,
        totalHariKerja: totalHariKerja,
      );

      if (bytes == null) {
        throw Exception('Gagal encode excel');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Absensi_$timestamp.xlsx';

      // ── Export Web ──────────────────────────────────────────────────
      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.download_done, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File Excel berhasil diunduh!',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        if (mounted) setState(() => isExporting = false);
        return;
      }

      // ── Permission Android ──────────────────────────────────────────
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final permission = info.version.sdkInt >= 33
            ? Permission.photos
            : Permission.storage;

        var status = await permission.status;

        if (status.isDenied || status.isPermanentlyDenied) {
          status = await permission.request();
        }

        if (!status.isGranted) {
          _showErrorSnackBar('Izin penyimpanan diperlukan untuk export');
          if (mounted) setState(() => isExporting = false);
          return;
        }
      }

      // ── Simpan file mobile ──────────────────────────────────────────
      final dir = await getExternalStorageDirectory();

      if (dir == null) {
        throw Exception('Tidak dapat mengakses direktori');
      }

      final path = '${dir.path}/$fileName';

      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      if (mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Berhasil'),
            content: Text('File tersimpan di:\n$path\n\nBuka sekarang?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Nanti'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Buka'),
              ),
            ],
          ),
        );

        if (open == true) {
          await OpenFile.open(path);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal export: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }

  int _countHariKerjaExport({
    required DateTime startDate,
    required DateTime endDate,
    required List<CompanyCalendarEvent> calendarEvents,
  }) {
    int total = 0;

    var current = DateTime(startDate.year, startDate.month, startDate.day);

    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      // _isLiburExport sudah skip:
      // Sabtu, Minggu, dan event kalender tipe LIBUR.
      // WFH dan INFO tetap dihitung hari kerja.
      if (!_isLiburExport(current, calendarEvents)) {
        total++;
      }

      current = current.add(const Duration(days: 1));
    }

    return total;
  }

  Future<void> _showWorkPeriodPickerSheet() async {
    final now = DateTime.now();

    final result = await _adminService.getWorkPeriodsByYear(tahun: now.year);

    if (!mounted) return;

    if (!result.success || result.data == null || result.data!.isEmpty) {
      _showErrorSnackBar('Belum ada periode kerja yang disetting HRD.');
      return;
    }

    final periods = result.data!..sort((a, b) => a.bulan.compareTo(b.bulan));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
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

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Pilih Periode Kerja',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Periode diambil dari data yang sudah disetting HRD.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),

              const SizedBox(height: 12),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: periods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = periods[i];

                    final selected =
                        customDateRange != null &&
                        customDateRange!.start.year == p.tanggalMulai.year &&
                        customDateRange!.start.month == p.tanggalMulai.month &&
                        customDateRange!.start.day == p.tanggalMulai.day &&
                        customDateRange!.end.year == p.tanggalSelesai.year &&
                        customDateRange!.end.month == p.tanggalSelesai.month &&
                        customDateRange!.end.day == p.tanggalSelesai.day;

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        p.bulanLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy', 'id_ID').format(p.tanggalMulai)} - '
                        '${DateFormat('dd MMM yyyy', 'id_ID').format(p.tanggalSelesai)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF6366F1),
                            )
                          : null,
                      selected: selected,
                      onTap: () async {
                        Navigator.pop(context);

                        setState(() {
                          selectedTimeRange = 'Pilih Periode';
                          customDateRange = DateTimeRange(
                            start: p.tanggalMulai,
                            end: p.tanggalSelesai,
                          );
                        });

                        await Future.wait([
                          _loadAttendanceData(refresh: true),
                          _loadDashboardStats(),
                          _loadTidakHadirList(),
                        ]);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

  void _performSearch(String value) {
    setState(() => searchTerm = value);
    _loadAttendanceData(refresh: true);
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWebLayout = _isWeb(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isWebLayout),
      body: SafeArea(child: isWebLayout ? _buildWebBody() : _buildMobileBody()),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isWebLayout) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_ind,
              color: Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'HRD - Data Absensi',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: isWebLayout ? false : true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          child: IconButton(
            tooltip: 'Halaman Edit Absensi',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.edit_calendar,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HrdAbsensiEditPage()),
              );
              _refreshData();
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            onPressed: _refreshData,
          ),
        ),
      ],
      bottom: isWebLayout
          ? null
          : TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6366F1),
              isScrollable: MediaQuery.of(context).size.width < 400,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
                Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Absensi'),
                Tab(icon: Icon(Icons.analytics, size: 18), text: 'Analitik'),
                Tab(
                  icon: Icon(Icons.volunteer_activism, size: 18),
                  text: 'Input Doa',
                ),
              ],
            ),
    );
  }

  Widget _buildMobileBody() => TabBarView(
    controller: _tabController,
    children: [
      _buildDashboardTab(),
      _buildAttendanceTab(),
      _buildAnalyticsTab(),
      _buildKaryawanDoa(),
    ],
  );

  Widget _buildWebBody() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildWebSideNav(),
      Expanded(
        child: IndexedStack(
          index: _webTabIndex,
          children: [
            _buildDashboardTab(),
            _buildAttendanceTab(),
            _buildAnalyticsTab(),
            _buildKaryawanDoa(),
          ],
        ),
      ),
    ],
  );

  Widget _buildWebSideNav() {
    final tabs = [
      _WebNavItem(Icons.dashboard, 'Dashboard', 0),
      _WebNavItem(Icons.list_alt, 'Absensi', 1),
      _WebNavItem(Icons.analytics, 'Analitik', 2),
      _WebNavItem(Icons.volunteer_activism, 'Input Doa', 3),
    ];
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          ...tabs.map((tab) {
            final sel = _webTabIndex == tab.index;
            return GestureDetector(
              onTap: () {
                setState(() => _webTabIndex = tab.index);
                _tabController.animateTo(tab.index);
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF6366F1).withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: sel
                      ? Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: sel ? const Color(0xFF6366F1) : Colors.grey[500],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? const Color(0xFF6366F1) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── TABS (sama persis dengan aslinya) ─────────────────────────────
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        controller: _dashboardScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: judul + filter tanggal ──────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Dashboard HRD - Absensi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Filter tanggal dashboard
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dashboardDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      helpText: 'Pilih Tanggal Dashboard',
                    );
                    if (picked != null) {
                      setState(() => _dashboardDate = picked);
                      await _loadDashboardStats();
                      await _loadTidakHadirList();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _dashboardDate == null
                              ? 'Hari Ini'
                              : DateFormat(
                                  'dd MMM yyyy',
                                  'id_ID',
                                ).format(_dashboardDate!),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        if (_dashboardDate != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() => _dashboardDate = null);
                              _loadDashboardStats();
                              _loadTidakHadirList();
                            },
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Stats grid + tingkat kehadiran (full width) ──────────
            _buildHRDStatsGrid(),
            const SizedBox(height: 20),

            // ── Perlu Perhatian + Belum Absen — BERSEBELAHAN ─────────
            LayoutBuilder(
              builder: (ctx, c) {
                final hasProblematic = problematicEmployees.isNotEmpty;
                final hasTidakHadir = _tidakHadirList.isNotEmpty;

                // Layar lebar → bersebelahan, tinggi disamakan + scroll di dalam
                if (c.maxWidth >= 700) {
                  if (hasProblematic && hasTidakHadir) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildProblematicEmployees(height: 440),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTidakHadirSection(height: 440)),
                      ],
                    );
                  }
                  if (hasProblematic) return _buildProblematicEmployees();
                  if (hasTidakHadir) return _buildTidakHadirSection();
                  return const SizedBox.shrink();
                }

                // Layar sempit (HP) → ditumpuk, tinggi natural
                return Column(
                  children: [
                    if (hasProblematic) ...[
                      _buildProblematicEmployees(),
                      if (hasTidakHadir) const SizedBox(height: 16),
                    ],
                    if (hasTidakHadir) _buildTidakHadirSection(),
                  ],
                );
              },
            ),

            // ── Analisis per Departemen — FULL WIDTH, DI BAWAH ───────
            if (departmentStats.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDepartmentAnalytics(),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<List<CompanyCalendarEvent>> _getCalendarEventsForExportRange(
    DateTime start,
    DateTime end,
  ) async {
    final years = <int>{start.year, end.year};
    final events = <CompanyCalendarEvent>[];

    for (final year in years) {
      final yearEvents = await CompanyCalendarService.getByYear(
        year,
        forceRefresh: true,
      );
      events.addAll(yearEvents);
    }

    return events;
  }

  bool _isSameExportDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isLiburExport(
    DateTime date,
    List<CompanyCalendarEvent> calendarEvents,
  ) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }

    return calendarEvents.any((e) {
      return e.isLibur && _isSameExportDate(e.tanggal, date);
    });
  }

  Widget _buildTidakHadirSection({double? height}) {
    if (_tidakHadirList.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final jamSekarang = now.hour * 60 + now.minute;
    final jam17 = 17 * 60;

    final targetDate = _dashboardDate ?? now;
    final isToday =
        DateFormat('yyyy-MM-dd').format(targetDate) ==
        DateFormat('yyyy-MM-dd').format(now);

    // Sebelum jam 17:00 = Belum Absen
    // Setelah jam 17:00 = Tidak Hadir
    final isBelumAbsen = isToday && jamSekarang < jam17;

    final mainColor = isBelumAbsen
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    final list = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: height == null,
      physics: height == null
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: _tidakHadirList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _tidakHadirTile(_tidakHadirList[i]),
    );

    return Container(
      key: _tidakHadirKey,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isBelumAbsen ? Icons.access_time : Icons.cancel,
                  color: mainColor,
                  size: 18,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  isBelumAbsen
                      ? 'Karyawan Belum Absen'
                      : 'Karyawan Tidak Hadir',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_tidakHadirList.length} orang',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mainColor,
                  ),
                ),
              ),
            ],
          ),

          if (isBelumAbsen) ...[
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSendingBelumAbsenWa ? null : _sendBelumAbsenWa,
                icon: _isSendingBelumAbsenWa
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  _isSendingBelumAbsenWa
                      ? 'Memproses...'
                      : 'Kirim WA ke Karyawan Belum Absen',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          if (height == null) list else Expanded(child: list),
        ],
      ),
    );
  }

  Widget _tidakHadirTile(Map<String, dynamic> karyawan) {
    final label = karyawan['label'] as String? ?? 'Tidak Hadir';

    final bool isBelumAbsen = label == 'Belum Absen';

    final labelColor = isBelumAbsen
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    final bgColor = isBelumAbsen
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFFEF2F2);

    final userId = karyawan['userId']?.toString() ?? '';
    final name = karyawan['name']?.toString() ?? '-';
    final department = karyawan['department']?.toString() ?? '-';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: labelColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: labelColor.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  department,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: labelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),

          const SizedBox(width: 4),

          TextButton(
            onPressed: () async {
              final emp = employees.firstWhere(
                (e) => e.userId == userId,
                orElse: () => Employee(userId: userId, name: name),
              );

              // Ambil ulang periode kerja bulan berjalan.
              // Jadi tidak balik ke Semua Data.
              await _loadDefaultWorkPeriod();

              if (!mounted) return;

              setState(() {
                selectedEmployee = emp;
                _webTabIndex = 1;
              });

              _tabController.animateTo(1);

              await Future.wait([
                _loadAttendanceData(refresh: true),
                _loadDashboardStats(),
                _loadTidakHadirList(),
              ]);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: const Color(0xFF6366F1),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Riwayat', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (ctx, c) {
            final isWide = c.maxWidth >= 700;
            final filterW = _buildFilterSection();
            final listW = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Data Absensi Karyawan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${attendanceData.length} data',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading && attendanceData.isEmpty)
                  _buildLoadingWidget()
                else if (errorMessage.isNotEmpty && attendanceData.isEmpty)
                  _buildErrorWidget()
                else if (attendanceData.isEmpty)
                  _buildEmptyStateWidget()
                else
                  _buildAttendanceList(),
              ],
            );
            if (isWide)
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: filterW),
                  const SizedBox(width: 16),
                  Expanded(child: listW),
                ],
              );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [filterW, const SizedBox(height: 20), listW],
            );
          },
        ),
      ),
    );
  }

  // ── Tab Input Doa — pakai DoaKaryawanScreen ───────────────────────
  Widget _buildKaryawanDoa() {
    return DoaKaryawanScreen(
      initialHrdUserId: _currentUserId,
      onDoaSaved: () async {
        // Refresh doa map otomatis setelah doa disimpan
        await _loadDoaMap();
      },
    );
  }

  void _showAnalyticsEmployeeSheet() {
    final sortedEmployees = List<Employee>.from(employees)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
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

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Pilih Karyawan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Semua Karyawan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: _selectedAnalyticsEmployee == null
                    ? const Icon(Icons.check_circle, color: Color(0xFF6366F1))
                    : null,
                onTap: () async {
                  Navigator.pop(context);

                  setState(() {
                    _selectedAnalyticsEmployee = null;
                  });

                  await _loadAnalyticsData();
                },
              ),

              const Divider(height: 1),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sortedEmployees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final emp = sortedEmployees[i];
                    final selected =
                        _selectedAnalyticsEmployee?.userId == emp.userId;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(
                          0xFF6366F1,
                        ).withOpacity(0.12),
                        child: Text(
                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        emp.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        emp.department ?? '-',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF6366F1),
                            )
                          : null,
                      onTap: () async {
                        Navigator.pop(context);

                        setState(() {
                          _selectedAnalyticsEmployee = emp;
                        });

                        await _loadAnalyticsData();
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsEmployeeFilter() {
    final label = _selectedAnalyticsEmployee == null
        ? 'Semua Karyawan'
        : _selectedAnalyticsEmployee!.name;

    return GestureDetector(
      onTap: _showAnalyticsEmployeeSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_search_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendancePercentageByEmployee(Map<String, dynamic> a) {
    final performers = List<_PerfData>.from(a['performers'] as List<_PerfData>);
    final effectiveWorkDays = a['effectiveWorkDays'] as int;

    if (performers.isEmpty) {
      return const SizedBox.shrink();
    }

    return _card(
      title: 'Distribusi Persentase Kehadiran',
      icon: Icons.percent_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dihitung berdasarkan $effectiveWorkDays hari kerja berjalan pada periode ini.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          ...performers.map((p) {
            final percent = p.attendancePercent.clamp(0, 100);
            final color = percent >= 90
                ? const Color(0xFF10B981)
                : percent >= 70
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withOpacity(0.14),
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              p.department ?? '-',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Hadir ${p.hadir}, Izin/Cuti ${p.cuti}, Tidak Hadir ${p.tidakHadir} dari $effectiveWorkDays hari kerja',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final a = _computeAnalytics();

    final sections = <Widget>[
      _buildAnalyticsSummaryGrid(a),
      _buildAttendancePercentageByEmployee(a),
      if ((a['deptStats'] as Map<String, int>).isNotEmpty)
        _buildDepartmentAnalytics(
          stats: a['deptStats'] as Map<String, int>,
          rate: a['deptRate'] as Map<String, double>,
        ),
      if ((a['performers'] as List<_PerfData>).any((p) => p.hadir > 0))
        _buildTopPerformers(a),
      if ((a['problematic'] as List<Employee>).isNotEmpty)
        _buildProblematicEmployees(
          employeesList: a['problematic'] as List<Employee>,
        ),
    ];

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header gradient + Export + Tahun ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.analytics,
                        color: Colors.white,
                        size: 32,
                      ),
                      const Spacer(),
                      if (isExporting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap:
                              _analyticsData.isEmpty ||
                                  _loadingAnalytics ||
                                  isExporting
                              ? null
                              : () => _exportAnalytics(a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                _analyticsData.isEmpty ? 0.08 : 0.2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.download,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Export',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Analitik HRD',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rekap absensi berdasarkan periode kerja HRD',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  _buildAnalyticsPeriodFilter(),
                  const SizedBox(height: 10),
                  _buildAnalyticsEmployeeFilter(),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _loadingAnalytics ? null : _loadAnalyticsData,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _loadingAnalytics
                                ? 'Memuat data periode...'
                                : '${_analyticsData.length} record',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Body ──
            if (_analyticsData.isEmpty)
              _loadingAnalytics
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6366F1),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Memuat data periode...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bar_chart_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada data absensi pada periode ini',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadAnalyticsData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Muat Ulang'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
            else
              for (int i = 0; i < sections.length; i++) ...[
                sections[i],
                if (i != sections.length - 1) const SizedBox(height: 16),
              ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Hitung semua analitik dari attendanceData (sinkron dgn filter) ──
  Map<String, dynamic> _computeAnalytics() {
    final data = _analyticsData;

    final int effectiveWorkDays = _effectiveWorkDaysInSelectedPeriod();

    int tepatWaktu = 0;
    int terlambat = 0;
    int tidakHadir = 0;
    int cuti = 0;
    int totalWorkingMinutes = 0;
    int workingCount = 0;
    int totalOvertimeMinutes = 0;

    final Map<String, _PerfData> perfByUser = {};
    final Map<String, int> deptCount = {};
    final Map<String, int> deptHadir = {};

    for (final d in data) {
      final s = d.displayStatus.toLowerCase();
      final ci = d.checkInStatus.toLowerCase();
      final notes = d.notes.toLowerCase();

      final isTepat = s.contains('tepat') || ci.contains('on_time');

      final isTerlambat =
          s.contains('terlambat') ||
          ci.contains('late') ||
          ci.contains('very_late');

      final isCuti =
          s.contains('cuti') ||
          s.contains('izin') ||
          s.contains('sakit') ||
          s.contains('dinas') ||
          s.contains('timeoff') ||
          s.contains('leave') ||
          ci.contains('cuti') ||
          ci.contains('izin') ||
          ci.contains('leave') ||
          notes.contains('cuti') ||
          notes.contains('izin') ||
          notes.contains('sakit') ||
          notes.contains('dinas');

      final isAbsent =
          s.contains('tidak hadir') ||
          s.contains('absent') ||
          s.contains('tidak absen');

      final dateKey = DateFormat('yyyy-MM-dd').format(d.attendanceDate);
      final isHadir = isTepat || isTerlambat;

      if (isTepat) {
        tepatWaktu++;
      } else if (isTerlambat) {
        terlambat++;
      } else if (isCuti) {
        cuti++;
      } else if (isAbsent) {
        // Tidak langsung dijadikan final total,
        // karena total tidak hadir akan dihitung ulang dari hari kerja efektif.
        tidakHadir++;
      }

      if (d.workingHoursMinutes != null &&
          d.workingHoursMinutes! > 0 &&
          d.workingHoursMinutes! < 1440) {
        totalWorkingMinutes += d.workingHoursMinutes!;
        workingCount++;
      }

      if (d.overtimeMinutes != null &&
          d.overtimeMinutes! > 0 &&
          d.overtimeMinutes! < 1440) {
        totalOvertimeMinutes += d.overtimeMinutes!;
      }

      final dept = d.department ?? 'Unknown';

      deptCount[dept] = (deptCount[dept] ?? 0) + 1;
      if (isHadir) {
        deptHadir[dept] = (deptHadir[dept] ?? 0) + 1;
      }

      final p = perfByUser.putIfAbsent(
        d.userId,
        () => _PerfData(d.userName, d.department),
      );

      p.total++;

      if (isTepat) {
        p.tepat++;
        p.hadir++;
        p.hadirDates.add(dateKey);
      } else if (isTerlambat) {
        p.terlambat++;
        p.hadir++;
        p.hadirDates.add(dateKey);
      } else if (isCuti) {
        p.cuti++;
        p.cutiDates.add(dateKey);
      }
    }

    // Pastikan semua karyawan tetap dihitung, walaupun tidak punya record absensi.
    if (_selectedAnalyticsEmployee == null) {
      for (final e in employees) {
        perfByUser.putIfAbsent(e.userId, () => _PerfData(e.name, e.department));
      }
    } else {
      final e = _selectedAnalyticsEmployee!;
      perfByUser.putIfAbsent(e.userId, () => _PerfData(e.name, e.department));
    }

    final deptRate = <String, double>{};
    deptCount.forEach((dept, count) {
      deptRate[dept] = count == 0 ? 0 : (deptHadir[dept] ?? 0) / count * 100;
    });

    final performers = perfByUser.values.toList();

    for (final p in performers) {
      final hadirUnik = p.hadirDates.length;
      final cutiUnik = p.cutiDates.length;

      p.hadir = hadirUnik;
      p.cuti = cutiUnik;
      p.effectiveWorkDays = effectiveWorkDays;

      final calculatedAbsent = effectiveWorkDays - hadirUnik - cutiUnik;
      p.tidakHadir = calculatedAbsent < 0 ? 0 : calculatedAbsent;

      p.attendancePercent = effectiveWorkDays > 0
          ? hadirUnik / effectiveWorkDays * 100
          : 0;
    }

    tidakHadir = performers.fold<int>(0, (sum, p) => sum + p.tidakHadir);

    cuti = performers.fold<int>(0, (sum, p) => sum + p.cuti);

    performers.sort((a, b) {
      final cmp = b.attendancePercent.compareTo(a.attendancePercent);
      if (cmp != 0) return cmp;
      return b.hadir.compareTo(a.hadir);
    });

    final problematic = <Employee>[];

    for (final p in performers) {
      if (p.effectiveWorkDays <= 0) continue;

      if (p.attendancePercent < 70) {
        final emp = employees.firstWhere(
          (e) => e.name == p.name,
          orElse: () => Employee(userId: '', name: p.name),
        );

        problematic.add(emp);
      }
    }

    return {
      'tepatWaktu': tepatWaktu,
      'terlambat': terlambat,
      'tidakHadir': tidakHadir,
      'cuti': cuti,
      'totalHadir': tepatWaktu + terlambat,
      'totalRecords': data.length,
      'effectiveWorkDays': effectiveWorkDays,
      'avgWorkingMinutes': workingCount > 0
          ? totalWorkingMinutes / workingCount
          : 0,
      'totalOvertimeMinutes': totalOvertimeMinutes,
      'performers': performers,
      'deptStats': deptCount,
      'deptRate': deptRate,
      'problematic': problematic,
    };
  }

  // ── Card wrapper analitik ──
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── Grid ringkasan ──
  Widget _buildAnalyticsSummaryGrid(Map<String, dynamic> a) {
    final avgMin = (a['avgWorkingMinutes'] as num?)?.toDouble() ?? 0.0;
    final totalOvertimeMin =
        (a['totalOvertimeMinutes'] as num?)?.toDouble() ?? 0.0;
    final effectiveWorkDays = (a['effectiveWorkDays'] as int?) ?? 0;

    String formatJam(double minutes) {
      if (minutes <= 0) return '0 jam';

      final hours = minutes / 60;

      if (hours < 1) {
        return '${minutes.toStringAsFixed(0)} menit';
      }

      return '${hours.toStringAsFixed(1)} jam';
    }

    Widget summaryItem({
      required String title,
      required String value,
      required IconData icon,
      required Color color,
      String? subtitle,
      VoidCallback? onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.055),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 3),

                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: color.withOpacity(0.75),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final items = <Widget>[
      summaryItem(
        title: 'Hari Kerja',
        value: '$effectiveWorkDays',
        subtitle: 'periode berjalan',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF6366F1),
      ),

      summaryItem(
        title: 'Total Hadir',
        value: '${a['totalHadir'] ?? 0}',
        subtitle: 'tepat + terlambat',
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF10B981),
      ),

      summaryItem(
        title: 'Tepat Waktu',
        value: '${a['tepatWaktu'] ?? 0}',
        subtitle: 'klik detail',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        onTap: () => _showAnalyticsDetailPopup(
          title: 'Detail Tepat Waktu',
          statusType: 'tepat',
          color: const Color(0xFF10B981),
          icon: Icons.check_circle_rounded,
        ),
      ),

      summaryItem(
        title: 'Terlambat',
        value: '${a['terlambat'] ?? 0}',
        subtitle: 'klik detail',
        icon: Icons.access_time_filled_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => _showAnalyticsDetailPopup(
          title: 'Detail Terlambat',
          statusType: 'terlambat',
          color: const Color(0xFFF59E0B),
          icon: Icons.access_time_filled_rounded,
        ),
      ),

      summaryItem(
        title: 'Tidak Hadir',
        value: '${a['tidakHadir'] ?? 0}',
        subtitle: 'klik detail',
        icon: Icons.cancel_rounded,
        color: const Color(0xFFEF4444),
        onTap: () => _showAnalyticsDetailPopup(
          title: 'Detail Tidak Hadir',
          statusType: 'tidak_hadir',
          color: const Color(0xFFEF4444),
          icon: Icons.cancel_rounded,
        ),
      ),

      summaryItem(
        title: 'Izin / Cuti',
        value: '${a['cuti'] ?? 0}',
        subtitle: 'klik detail',
        icon: Icons.event_busy_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => _showAnalyticsDetailPopup(
          title: 'Detail Izin / Cuti',
          statusType: 'cuti',
          color: const Color(0xFF8B5CF6),
          icon: Icons.event_busy_rounded,
        ),
      ),

      summaryItem(
        title: 'Rata-rata Kerja',
        value: formatJam(avgMin),
        subtitle: 'per hari hadir',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF3B82F6),
      ),

      summaryItem(
        title: 'Total Lembur',
        value: formatJam(totalOvertimeMin),
        subtitle: 'periode ini',
        icon: Icons.more_time_rounded,
        color: const Color(0xFFEC4899),
      ),
    ];

    return _card(
      title: 'Ringkasan Analitik',
      icon: Icons.insights_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          int crossAxisCount;
          double ratio;

          if (width >= 1200) {
            crossAxisCount = 4;
            ratio = 4.2;
          } else if (width >= 900) {
            crossAxisCount = 3;
            ratio = 3.8;
          } else if (width >= 650) {
            crossAxisCount = 2;
            ratio = 3.5;
          } else {
            crossAxisCount = 1;
            ratio = 4.6;
          }

          return GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: ratio,
            children: items,
          );
        },
      ),
    );
  }

  // Widget _analyticsMiniCard({
  //   required String title,
  //   required String value,
  //   required IconData icon,
  //   required Color color,
  // }) {
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(14),
  //       border: Border.all(color: color.withOpacity(0.18)),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.025),
  //           blurRadius: 6,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           width: 36,
  //           height: 36,
  //           decoration: BoxDecoration(
  //             color: color.withOpacity(0.1),
  //             borderRadius: BorderRadius.circular(10),
  //           ),
  //           child: Icon(icon, color: color, size: 18),
  //         ),
  //         const SizedBox(width: 10),
  //         Expanded(
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 value,
  //                 style: TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.w800,
  //                   color: color,
  //                   height: 1,
  //                 ),
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //               const SizedBox(height: 6),
  //               Text(
  //                 title,
  //                 style: const TextStyle(
  //                   fontSize: 11,
  //                   fontWeight: FontWeight.w500,
  //                   color: Color(0xFF64748B),
  //                 ),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ── Donut distribusi status ──
  // ignore: unused_element
  Widget _buildStatusDonut(Map<String, dynamic> a) {
    final tepat = a['tepatWaktu'] as int;
    final telat = a['terlambat'] as int;
    final absen = a['tidakHadir'] as int;
    final cuti = a['cuti'] as int;
    final total = tepat + telat + absen + cuti;
    if (total == 0) return const SizedBox.shrink();

    final rate = (tepat + telat) / total * 100;
    final segs = [
      _DonutSeg(tepat.toDouble(), const Color(0xFF10B981)),
      _DonutSeg(telat.toDouble(), const Color(0xFFF59E0B)),
      _DonutSeg(absen.toDouble(), const Color(0xFFEF4444)),
      _DonutSeg(cuti.toDouble(), const Color(0xFF3B82F6)),
    ];

    Widget legendItem(String label, int val, Color c) {
      final pct = val / total * 100;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
            Text(
              '$val',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${pct.toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return _card(
      title: 'Distribusi Status Absensi',
      icon: Icons.pie_chart_rounded,
      child: LayoutBuilder(
        builder: (ctx, c) {
          final donut = SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(150, 150),
                  painter: _DonutChartPainter(segs),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'Kehadiran',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          );
          final legend = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              legendItem('Tepat Waktu', tepat, const Color(0xFF10B981)),
              legendItem('Terlambat', telat, const Color(0xFFF59E0B)),
              legendItem('Tidak Hadir', absen, const Color(0xFFEF4444)),
              legendItem('Cuti', cuti, const Color(0xFF3B82F6)),
            ],
          );
          if (c.maxWidth >= 420) {
            return Row(
              children: [
                donut,
                const SizedBox(width: 20),
                Expanded(child: legend),
              ],
            );
          }
          return Column(children: [donut, const SizedBox(height: 12), legend]);
        },
      ),
    );
  }

  // ── Bar chart tren kehadiran harian ──
  // Widget _buildDailyTrendChart(Map<String, dynamic> a) {
  //   var entries = (a['dailyHadir'] as Map<String, int>).entries.toList()
  //     ..sort((x, y) => x.key.compareTo(y.key));
  //   if (entries.length > 14) entries = entries.sublist(entries.length - 14);
  //   final maxVal = entries
  //       .map((e) => e.value)
  //       .fold<int>(1, (m, v) => v > m ? v : m);

  //   return _card(
  //     title: 'Tren Kehadiran Harian',
  //     icon: Icons.show_chart_rounded,
  //     child: SizedBox(
  //       height: 180,
  //       child: SingleChildScrollView(
  //         scrollDirection: Axis.horizontal,
  //         child: Row(
  //           crossAxisAlignment: CrossAxisAlignment.end,
  //           children: entries.map((e) {
  //             final h = (e.value / maxVal) * 130;
  //             final date = DateTime.parse(e.key);
  //             return Container(
  //               width: 40,
  //               margin: const EdgeInsets.symmetric(horizontal: 4),
  //               child: Column(
  //                 mainAxisAlignment: MainAxisAlignment.end,
  //                 children: [
  //                   Text(
  //                     '${e.value}',
  //                     style: const TextStyle(
  //                       fontSize: 11,
  //                       fontWeight: FontWeight.w700,
  //                       color: Color(0xFF1E293B),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Container(
  //                     width: 24,
  //                     height: h < 4 ? 4 : h,
  //                     decoration: BoxDecoration(
  //                       gradient: const LinearGradient(
  //                         colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
  //                         begin: Alignment.bottomCenter,
  //                         end: Alignment.topCenter,
  //                       ),
  //                       borderRadius: BorderRadius.circular(6),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 6),
  //                   Text(
  //                     DateFormat('dd/MM').format(date),
  //                     style: const TextStyle(
  //                       fontSize: 10,
  //                       color: Color(0xFF94A3B8),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             );
  //           }).toList(),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // ── Distribusi jam check-in ──

  // ── Top performers ──
  Widget _buildTopPerformers(Map<String, dynamic> a) {
    final performers = (a['performers'] as List<_PerfData>)
        .where((p) => p.total > 0 && p.tepat > 0)
        .take(5)
        .toList();
    if (performers.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Karyawan Paling Disiplin',
      icon: Icons.emoji_events_rounded,
      child: Column(
        children: performers.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final rate = p.tepat / p.total * 100;
          final medal = i == 0
              ? '🥇'
              : i == 1
              ? '🥈'
              : i == 2
              ? '🥉'
              : '${i + 1}';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    medal,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${p.department ?? "-"} • ${p.hadir}/${p.effectiveWorkDays} tepat waktu',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${rate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Export analitik ke CSV ──
  String _csv(String s) =>
      (s.contains(',') || s.contains('"') || s.contains('\n'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;

  Future<void> _exportAnalytics(Map<String, dynamic> a) async {
    setState(() => isExporting = true);

    try {
      final year = DateTime.now().year;

      int toInt(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value.toString()) ?? 0;
      }

      double toDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is double) return value;
        if (value is num) return value.toDouble();
        return double.tryParse(value.toString()) ?? 0.0;
      }

      final deptStats = Map<String, int>.from(
        ((a['deptStats'] as Map?) ?? {}).map(
          (key, value) => MapEntry(key.toString(), toInt(value)),
        ),
      );

      final deptRate = Map<String, double>.from(
        ((a['deptRate'] as Map?) ?? {}).map(
          (key, value) => MapEntry(key.toString(), toDouble(value)),
        ),
      );

      final performers = (a['performers'] is List)
          ? List<_PerfData>.from(a['performers'] as List)
          : <_PerfData>[];

      final sb = StringBuffer();

      sb.writeln('\uFEFFLAPORAN ANALITIK ABSENSI HRD');
      sb.writeln(
        'Tanggal Export,${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.now())}',
      );

      final periodText = _selectedAnalyticsPeriod == null
          ? 'Tahun $year'
          : '${_selectedAnalyticsPeriod!.bulanLabel} (${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedAnalyticsPeriod!.tanggalMulai)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedAnalyticsPeriod!.tanggalSelesai)})';

      sb.writeln('Periode,$periodText');
      sb.writeln('');

      sb.writeln('RINGKASAN');
      sb.writeln('Total Record,${toInt(a['totalRecords'])}');
      sb.writeln('Hari Kerja Berjalan,${toInt(a['effectiveWorkDays'])}');
      sb.writeln('Total Hadir,${toInt(a['totalHadir'])}');
      sb.writeln('Tepat Waktu,${toInt(a['tepatWaktu'])}');
      sb.writeln('Terlambat,${toInt(a['terlambat'])}');
      sb.writeln('Tidak Hadir,${toInt(a['tidakHadir'])}');
      sb.writeln('Izin / Cuti,${toInt(a['cuti'])}');

      final avgMin = toDouble(a['avgWorkingMinutes']);
      final totalOvertimeMinutes = toDouble(a['totalOvertimeMinutes']);

      sb.writeln('Rata-rata Jam Kerja,${(avgMin / 60).toStringAsFixed(1)} jam');
      sb.writeln(
        'Total Lembur,${totalOvertimeMinutes.toStringAsFixed(0)} menit',
      );
      sb.writeln('');

      sb.writeln('ANALISIS PER DEPARTEMEN');
      sb.writeln('Departemen,Jumlah Record,Tingkat Kehadiran (%)');

      if (deptStats.isEmpty) {
        sb.writeln('Tidak ada data,0,0.0');
      } else {
        deptStats.forEach((dept, count) {
          final rate = deptRate[dept] ?? 0.0;
          sb.writeln('${_csv(dept)},$count,${rate.toStringAsFixed(1)}');
        });
      }

      sb.writeln('');

      final allPerf = performers
        ..sort((x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()));

      sb.writeln('REKAP PER KARYAWAN (${allPerf.length} orang)');
      sb.writeln(
        'Nama,Departemen,Hari Kerja Berjalan,Hadir,Tepat Waktu,Terlambat,Tidak Hadir,Persentase Kehadiran (%)',
      );

      for (final p in allPerf) {
        sb.writeln(
          '${_csv(p.name)},'
          '${_csv(p.department ?? "-")},'
          '${p.effectiveWorkDays},'
          '${p.hadir},'
          '${p.tepat},'
          '${p.terlambat},'
          '${p.tidakHadir},'
          '${p.attendancePercent.toStringAsFixed(1)}',
        );
      }

      final bytes = Uint8List.fromList(utf8.encode(sb.toString()));
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Analitik_HRD_${year}_$timestamp.csv';

      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analitik berhasil diunduh!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        return;
      }

      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final permission = info.version.sdkInt >= 33
            ? Permission.photos
            : Permission.storage;

        var status = await permission.status;

        if (status.isDenied || status.isPermanentlyDenied) {
          status = await permission.request();
        }

        if (!status.isGranted) {
          _showErrorSnackBar('Izin penyimpanan diperlukan untuk export');
          return;
        }
      }

      final dir = await getExternalStorageDirectory();

      if (dir == null) {
        throw Exception('Tidak dapat mengakses direktori');
      }

      final path = '${dir.path}/$fileName';

      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      if (mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Berhasil'),
            content: Text('File tersimpan di:\n$path\n\nBuka sekarang?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Nanti'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Buka'),
              ),
            ],
          ),
        );

        if (open == true) {
          await OpenFile.open(path);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal export analitik: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }
  // ── Semua widget lainnya sama persis dengan aslinya ───────────────

  Widget _buildHRDStatsGrid() {
    final s = stats ?? AdminAttendanceStats();

    // ── Label dinamis: sebelum jam 17:00 = Belum Absen, sesudah = Tidak Hadir ──
    final now = DateTime.now();
    final targetDate = _dashboardDate ?? now;
    final isToday =
        DateFormat('yyyy-MM-dd').format(targetDate) ==
        DateFormat('yyyy-MM-dd').format(now);
    final isBelumAbsen = isToday && (now.hour * 60 + now.minute) < 17 * 60;
    final tidakHadirLabel = isBelumAbsen ? 'Belum Absen' : 'Tidak Hadir';
    final tidakHadirIcon = isBelumAbsen ? Icons.access_time : Icons.cancel;
    final tidakHadirColor = isBelumAbsen
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = c.maxWidth >= 600 ? 4 : 2;
        final ratio = c.maxWidth >= 600 ? 1.6 : 1.2;
        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                _statCard(
                  'Total Karyawan',
                  s.totalKaryawan.toString(),
                  Icons.people,
                  const Color(0xFF3B82F6),
                  subtitle: 'Terdaftar',
                ),
                _statCard(
                  'Tepat Waktu',
                  s.tepatWaktu.toString(),
                  Icons.check_circle,
                  const Color(0xFF10B981),
                  subtitle: 'Karyawan',
                  onTap: () => _filterByStatusAndGoToTab('Tepat Waktu'),
                ),
                _statCard(
                  'Terlambat',
                  s.terlambat.toString(),
                  Icons.access_time,
                  const Color(0xFFF59E0B),
                  subtitle: 'Karyawan',
                  warn: s.terlambat > 5,
                  onTap: () => _filterByStatusAndGoToTab('Terlambat'),
                ),
                // ── Card dinamis ──
                _statCard(
                  tidakHadirLabel,
                  s.tidakHadir.toString(),
                  tidakHadirIcon,
                  tidakHadirColor,
                  subtitle: 'Karyawan',
                  warn: !isBelumAbsen && s.tidakHadir > 3,
                  onTap: () => _scrollToTidakHadir(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tingkat Kehadiran
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tingkat Kehadiran Hari Ini',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_calculateAttendanceRate().toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${s.tepatWaktu + s.terlambat} dari ${s.totalKaryawan} karyawan hadir',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _calculateAttendanceRate() > 90
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  final ScrollController _dashboardScrollController = ScrollController();
  final GlobalKey _tidakHadirKey = GlobalKey();
  void _filterByStatusAndGoToTab(String status) {
    setState(() {
      selectedStatusFilter = status;
      selectedTimeRange = '1 Hari'; // ← pastikan ini, bukan '1 Hari'
      customDateRange = null;
      _webTabIndex = 1;
    });
    _tabController.animateTo(1);
    _loadAttendanceData(refresh: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.filter_alt, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Menampilkan karyawan: $status hari ini'),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToTidakHadir() {
    // Scroll ke bagian tidak hadir di dashboard
    if (_tidakHadirKey.currentContext != null) {
      Scrollable.ensureVisible(
        _tidakHadirKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    bool warn = false,
    VoidCallback? onTap, // ← TAMBAH
  }) {
    return GestureDetector(
      // ← WRAP dengan GestureDetector
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                onTap !=
                    null // ← highlight kalau bisa diklik
                ? color.withOpacity(0.4)
                : warn
                ? color.withOpacity(0.5)
                : color.withOpacity(0.2),
            width: warn || onTap != null ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: warn
                  ? color.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (warn)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.priority_high,
                      size: 10,
                      color: Colors.red,
                    ),
                  ),
                // Icon tap hint
                if (onTap != null && !warn)
                  Icon(
                    Icons.touch_app,
                    size: 14,
                    color: color.withOpacity(0.5),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Label "Tap untuk lihat detail"
            if (onTap != null)
              Text(
                'Tap untuk lihat',
                style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Filter Data HRD',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (isExporting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                GestureDetector(
                  onTap: _exportData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Export',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama, ID, departemen...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF64748B),
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            onChanged: (v) =>
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == v) _performSearch(v);
                }),
          ),
          const SizedBox(height: 10),
          _filterBtn(
            'Periode',
            selectedTimeRange,
            Icons.calendar_today,
            const Color(0xFF3B82F6),
            _showDateFilterSheet,
          ),
          const SizedBox(height: 6),
          _filterBtn(
            'Status',
            selectedStatusFilter,
            Icons.filter_alt,
            const Color(0xFF10B981),
            _showStatusFilterSheet,
          ),
          const SizedBox(height: 6),
          _filterBtn(
            'Karyawan',
            selectedEmployee?.name ?? 'Semua',
            Icons.person,
            const Color(0xFF8B5CF6),
            _showEmployeeFilterSheet,
          ),
          const SizedBox(height: 6),
          _filterBtn(
            'Departemen',
            selectedDepartment ?? 'Semua',
            Icons.business,
            const Color(0xFF6366F1),
            _showDepartmentFilterSheet,
          ),
          const SizedBox(height: 6),
          _filterBtn(
            'Kantor',
            selectedOffice?.officeName ?? 'Semua',
            Icons.location_city,
            const Color(0xFFEF4444),
            _showOfficeFilterSheet,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  selectedTimeRange = 'Semua Data';
                  selectedStatusFilter = 'Semua';
                  selectedEmployee = null;
                  selectedOffice = null;
                  selectedDepartment = null;
                  customDateRange = null;
                  _searchController.clear();
                });
                _loadAttendanceData(refresh: true);
              },
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('Reset Filter', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B7280),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.04),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!isLoading &&
            hasMoreData &&
            n.metrics.pixels == n.metrics.maxScrollExtent)
          _loadMoreData();
        return false;
      },
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: attendanceData.length + (hasMoreData ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= attendanceData.length)
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          return _buildAttendanceCard(attendanceData[i]);
        },
      ),
    );
  }

  Widget _buildAttendanceCard(AdminAttendanceData data) {
    final color = _statusColor(data.displayStatus);
    // Cek status doa untuk hari ini
    final tanggalKey =
        '${DateFormat('yyyy-MM-dd').format(data.attendanceDate)}_${data.userId.toLowerCase()}';
    final doaVal = _doaMap[tanggalKey] ?? '';

    return GestureDetector(
      onTap: () => _showDetailBottomSheet(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon(data.displayStatus),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.userName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (data.department != null)
                                Text(
                                  data.department!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6366F1),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Badge status
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data.displayStatus,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ),
                        // Badge doa (TAMBAH)
                        if (doaVal.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: doaVal == 'ikut'
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '🙏 $doaVal',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: doaVal == 'ikut'
                                    ? const Color(0xFF10B981)
                                    : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(data.attendanceDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (data.displayStatus != 'Cuti') ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.login,
                            size: 12,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            data.formattedCheckIn,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.logout,
                            size: 12,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              data.formattedCheckOut,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openEditSheet(data),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_calendar,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentAnalytics({
    Map<String, int>? stats,
    Map<String, double>? rate,
  }) {
    final ds = stats ?? departmentStats;
    final dr = rate ?? attendanceRateByDepartment;
    if (ds.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Analisis per Departemen',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Icon(Icons.insights, color: Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 14),
          ...ds.entries.map((e) {
            final r = dr[e.key] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${e.value} • ${r.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: r / 100,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      r > 90
                          ? const Color(0xFF10B981)
                          : r > 75
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                    ),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProblematicEmployees({
    double? height,
    List<Employee>? employeesList,
  }) {
    final src = employeesList ?? problematicEmployees;
    if (src.isEmpty) return const SizedBox.shrink();

    final list = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: height == null,
      physics: height == null
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: src.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _problematicTile(src[i]),
    );

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Karyawan Perlu Perhatian',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${src.length} orang',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          height != null ? Expanded(child: list) : list,
        ],
      ),
    );
  }

  Widget _problematicTile(Employee emp) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
            child: Text(
              emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (emp.department != null)
                  Text(
                    emp.department!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                selectedEmployee = emp;
                _webTabIndex = 1;
              });
              _loadAttendanceData(refresh: true);
              _tabController.animateTo(1);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text('Detail', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showDetailBottomSheet(AdminAttendanceData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _statusColor(
                                data.displayStatus,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _statusIcon(data.displayStatus),
                              color: _statusColor(data.displayStatus),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detail Absensi HRD',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(data.attendanceDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      data.displayStatus,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    data.displayStatus,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _statusColor(data.displayStatus),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              'Edit Absensi',
                              Icons.edit_calendar,
                              const Color(0xFF6366F1),
                              () {
                                Navigator.pop(ctx);
                                _openEditSheet(data);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionBtn(
                              'Report',
                              Icons.description,
                              const Color(0xFF10B981),
                              () => _generateReport(data),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionBtn(
                              'Warning',
                              Icons.warning,
                              const Color(0xFFEF4444),
                              () => _sendWarning(data),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ..._buildDetailItems(data),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 10),
    ),
  );

  List<Widget> _buildDetailItems(AdminAttendanceData data) {
    final items = <Widget>[];
    void add(String label, String value, IconData icon, Color color) =>
        items.add(_detailItem(label, value, icon, color));
    add(
      'ID Absensi',
      '#${data.id.toString().padLeft(4, '0')}',
      Icons.badge,
      Colors.blue,
    );
    add('Nama Karyawan', data.userName, Icons.person, Colors.purple);
    if (data.employeeId != null)
      add('ID Karyawan', data.employeeId!, Icons.badge_outlined, Colors.indigo);
    if (data.department != null)
      add('Departemen', data.department!, Icons.business, Colors.teal);
    if (data.displayStatus != 'Cuti') {
      add('Jam Masuk', data.formattedCheckIn, Icons.login, Colors.green);
      add('Jam Keluar', data.formattedCheckOut, Icons.logout, Colors.orange);
    }
    add(
      'Status Check In',
      data.checkInStatus.isNotEmpty ? data.checkInStatus : 'Tidak ada data',
      _statusIcon(data.checkInStatus),
      _statusColor(data.checkInStatus),
    );
    if (data.checkOutStatus.isNotEmpty)
      add(
        'Status Check Out',
        data.checkOutStatus,
        _statusIcon(data.checkOutStatus),
        _statusColor(data.checkOutStatus),
      );
    if (data.checkInOfficeName != null)
      add('Kantor', data.checkInOfficeName!, Icons.location_city, Colors.red);
    add(
      'Keterangan',
      data.notes.isNotEmpty ? data.notes : 'Tidak ada keterangan',
      Icons.info,
      Colors.purple,
    );
    if (data.workingHoursMinutes != null)
      add(
        'Jam Kerja',
        '${(data.workingHoursMinutes! / 60).toStringAsFixed(1)} jam',
        Icons.schedule,
        Colors.indigo,
      );
    if (data.overtimeMinutes != null && data.overtimeMinutes! > 0)
      add(
        'Lembur',
        '${(data.overtimeMinutes! / 60).toStringAsFixed(1)} jam',
        Icons.access_time_filled,
        Colors.amber,
      );
    if (data.checkInFaceConfidence != null)
      add(
        'Confidence Check In',
        '${(data.checkInFaceConfidence! * 100).toStringAsFixed(1)}%',
        Icons.face,
        Colors.blue,
      );
    return items;
  }

  Widget _detailItem(String label, String value, IconData icon, Color color) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildLoadingWidget() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
          SizedBox(height: 16),
          Text(
            'Memuat data absensi HRD...',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );

  Widget _buildErrorWidget() => Column(
    children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 16),
      Text(
        errorMessage,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _refreshData, child: const Text('Coba Lagi')),
    ],
  );

  Widget _buildEmptyStateWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada data absensi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coba ubah filter atau periode waktu',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Muat Ulang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );

  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return date.toString().split(' ')[0];
    }
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('tepat') || l == 'on_time') return Colors.green;
    if (l.contains('terlambat') || l == 'late' || l == 'very_late')
      return Colors.orange;
    if (l.contains('cuti') || l == 'leave') return Colors.blue;
    if (l.contains('absent') || l.contains('tidak hadir')) return Colors.red;
    return Colors.grey;
  }

  IconData _statusIcon(String s) {
    final l = s.toLowerCase();
    if (l.contains('tepat') || l == 'on_time') return Icons.check_circle;
    if (l.contains('terlambat') || l == 'late' || l == 'very_late')
      return Icons.access_time;
    if (l.contains('cuti') || l == 'leave') return Icons.event_busy;
    if (l.contains('absent') || l.contains('tidak hadir')) return Icons.cancel;
    return Icons.help;
  }

  double _calculateAttendanceRate() {
    if (stats == null || stats!.totalKaryawan == 0) return 0;
    // Hanya hitung yang benar-benar hadir (tepat waktu + terlambat)
    return ((stats!.tepatWaktu + stats!.terlambat) / stats!.totalKaryawan * 100)
        .clamp(0, 100);
  }

  void _generateReport(AdminAttendanceData data) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Generate Report'),
      content: const Text('Laporan absensi akan segera tersedia'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  void _sendWarning(AdminAttendanceData data) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Kirim Peringatan'),
      content: Text('Kirim peringatan ke ${data.userName}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Peringatan telah dikirim'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
          ),
          child: const Text('Kirim'),
        ),
      ],
    ),
  );

  void _showDateFilterSheet() {
    final currentPeriodLabel = customDateRange != null
        ? '${DateFormat('dd MMM yyyy', 'id_ID').format(customDateRange!.start)} - '
              '${DateFormat('dd MMM yyyy', 'id_ID').format(customDateRange!.end)}'
        : 'Belum ada periode';

    final opts = [
      ('Hari Ini', Icons.today, Colors.green),
      ('1 Hari', Icons.calendar_today, Colors.blue),
      ('7 Hari Terakhir', Icons.date_range, Colors.orange),
      ('30 Hari Terakhir', Icons.calendar_month, Colors.purple),
      ('1 Tahun Terakhir', Icons.calendar_view_month, Colors.teal),
      ('Semua Data', Icons.all_inbox, Colors.grey),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
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

                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    'Filter Periode Absensi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Default mengikuti periode kerja bulan berjalan yang disetting HRD.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Periode kerja bulan berjalan ─────────────────────
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Periode Kerja Bulan Ini',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    currentPeriodLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing:
                      selectedTimeRange == 'Pilih Periode' &&
                          customDateRange != null
                      ? const Icon(Icons.check_circle, color: Color(0xFF6366F1))
                      : null,
                  selected:
                      selectedTimeRange == 'Pilih Periode' &&
                      customDateRange != null,
                  onTap: () async {
                    Navigator.pop(context);

                    await _loadDefaultWorkPeriod();

                    await Future.wait([
                      _loadAttendanceData(refresh: true),
                      _loadDashboardStats(),
                      _loadTidakHadirList(),
                    ]);
                  },
                ),

                const Divider(height: 1),

                // ── Pilih periode yang sudah dibuat HRD ───────────────
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Pilih Periode Kerja',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Pilih dari periode yang sudah disetting HRD',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showWorkPeriodPickerSheet();
                  },
                ),

                const Divider(height: 1),

                // ── Filter cepat ─────────────────────────────────────
                ...opts.map(
                  (o) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: o.$3.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(o.$2, color: o.$3, size: 20),
                    ),
                    title: Text(
                      o.$1,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: selectedTimeRange == o.$1
                        ? Icon(Icons.check_circle, color: o.$3)
                        : null,
                    selected: selectedTimeRange == o.$1,
                    onTap: () async {
                      setState(() {
                        selectedTimeRange = o.$1;
                        customDateRange = null;
                      });

                      Navigator.pop(context);

                      await Future.wait([
                        _loadAttendanceData(refresh: true),
                        _loadDashboardStats(),
                        _loadTidakHadirList(),
                      ]);
                    },
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusFilterSheet() {
    final opts = [
      ('Semua', Icons.all_inclusive, Colors.blue),
      ('Tepat Waktu', Icons.check_circle, Colors.green),
      ('Terlambat', Icons.access_time, Colors.orange),
      ('Cuti', Icons.event_busy, Colors.blue),
      ('Tidak Hadir', Icons.cancel, Colors.red),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Filter Status Absensi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...opts.map(
              (o) => ListTile(
                leading: Icon(o.$2, color: o.$3),
                title: Text(o.$1),
                selected: selectedStatusFilter == o.$1,
                onTap: () {
                  setState(() => selectedStatusFilter = o.$1);
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEmployeeFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scroll) => SafeArea(
          child: Column(
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
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Pilih Karyawan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.all_inclusive,
                        color: Colors.blue,
                      ),
                      title: const Text('Semua Karyawan'),
                      selected: selectedEmployee == null,
                      onTap: () {
                        setState(() => selectedEmployee = null);
                        Navigator.pop(context);
                        _loadAttendanceData(refresh: true);
                      },
                    ),
                    ...employees.map(
                      (emp) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF8B5CF6,
                          ).withOpacity(0.1),
                          child: Text(
                            emp.name.isNotEmpty
                                ? emp.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(emp.name),
                        subtitle: Text(
                          '${emp.employeeId ?? ""} • ${emp.department ?? ""}',
                        ),
                        selected: selectedEmployee?.userId == emp.userId,
                        onTap: () {
                          setState(() => selectedEmployee = emp);
                          Navigator.pop(context);
                          _loadAttendanceData(refresh: true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DateTime> _effectiveWorkDatesInSelectedPeriod() {
    final p = _selectedAnalyticsPeriod;
    if (p == null) return [];

    final today = _onlyDate(DateTime.now());
    final start = _onlyDate(p.tanggalMulai);
    final periodEnd = _onlyDate(p.tanggalSelesai);

    final end = periodEnd.isAfter(today) ? today : periodEnd;

    if (end.isBefore(start)) return [];

    final result = <DateTime>[];
    var current = start;

    while (!current.isAfter(end)) {
      if (_isWorkdayForAnalytics(current)) {
        result.add(current);
      }

      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  List<_AnalyticsDetailItem> _buildAnalyticsDetailsByStatus(String statusType) {
    final details = <_AnalyticsDetailItem>[];

    final selectedUserId = _selectedAnalyticsEmployee?.userId;

    bool isSelectedEmployeeData(AdminAttendanceData d) {
      if (selectedUserId == null) return true;
      return d.userId == selectedUserId;
    }

    String normalize(String value) => value.toLowerCase();

    bool isCutiOrIzin(AdminAttendanceData d) {
      final s = normalize(d.displayStatus);
      final ci = normalize(d.checkInStatus);
      final notes = normalize(d.notes);

      return s.contains('cuti') ||
          s.contains('izin') ||
          s.contains('sakit') ||
          s.contains('dinas') ||
          s.contains('timeoff') ||
          s.contains('leave') ||
          ci.contains('cuti') ||
          ci.contains('izin') ||
          ci.contains('leave') ||
          notes.contains('cuti') ||
          notes.contains('izin') ||
          notes.contains('sakit') ||
          notes.contains('dinas');
    }

    if (statusType == 'tepat') {
      for (final d in _analyticsData.where(isSelectedEmployeeData)) {
        final s = normalize(d.displayStatus);
        final ci = normalize(d.checkInStatus);

        if (s.contains('tepat') || ci.contains('on_time')) {
          details.add(
            _AnalyticsDetailItem(
              userId: d.userId,
              name: d.userName,
              department: d.department ?? '-',
              tanggal: d.attendanceDate,
              status: 'Tepat Waktu',
              jamMasuk: d.formattedCheckIn,
              keterangan: d.notes,
            ),
          );
        }
      }
    } else if (statusType == 'terlambat') {
      for (final d in _analyticsData.where(isSelectedEmployeeData)) {
        final s = normalize(d.displayStatus);
        final ci = normalize(d.checkInStatus);

        if (s.contains('terlambat') ||
            ci.contains('late') ||
            ci.contains('very_late')) {
          details.add(
            _AnalyticsDetailItem(
              userId: d.userId,
              name: d.userName,
              department: d.department ?? '-',
              tanggal: d.attendanceDate,
              status: 'Terlambat',
              jamMasuk: d.formattedCheckIn,
              keterangan: d.notes,
            ),
          );
        }
      }
    } else if (statusType == 'cuti') {
      for (final d in _analyticsData.where(isSelectedEmployeeData)) {
        if (isCutiOrIzin(d)) {
          details.add(
            _AnalyticsDetailItem(
              userId: d.userId,
              name: d.userName,
              department: d.department ?? '-',
              tanggal: d.attendanceDate,
              status: 'Izin / Cuti',
              jamMasuk: null,
              keterangan: d.notes.isNotEmpty ? d.notes : d.displayStatus,
            ),
          );
        }
      }
    } else if (statusType == 'tidak_hadir') {
      final workDates = _effectiveWorkDatesInSelectedPeriod();

      final targetEmployees = selectedUserId == null
          ? employees
          : employees.where((e) => e.userId == selectedUserId).toList();

      final hadirKeys = <String>{};
      final cutiKeys = <String>{};

      for (final d in _analyticsData) {
        if (selectedUserId != null && d.userId != selectedUserId) continue;

        final t = DateFormat('yyyy-MM-dd').format(d.attendanceDate);
        final key = '${d.userId}_$t';

        final s = normalize(d.displayStatus);
        final ci = normalize(d.checkInStatus);

        final isHadir =
            s.contains('tepat') ||
            s.contains('terlambat') ||
            ci.contains('on_time') ||
            ci.contains('late') ||
            ci.contains('very_late');

        if (isHadir) {
          hadirKeys.add(key);
        }

        if (isCutiOrIzin(d)) {
          cutiKeys.add(key);
        }
      }

      for (final emp in targetEmployees) {
        for (final date in workDates) {
          final t = DateFormat('yyyy-MM-dd').format(date);
          final key = '${emp.userId}_$t';

          if (!hadirKeys.contains(key) && !cutiKeys.contains(key)) {
            details.add(
              _AnalyticsDetailItem(
                userId: emp.userId,
                name: emp.name,
                department: emp.department ?? '-',
                tanggal: date,
                status: 'Tidak Hadir',
                jamMasuk: null,
                keterangan: 'Tidak ada absensi / izin pada hari kerja ini',
              ),
            );
          }
        }
      }
    }

    details.sort((a, b) {
      final dateCompare = b.tanggal.compareTo(a.tanggal);
      if (dateCompare != 0) return dateCompare;
      return a.name.compareTo(b.name);
    });

    return details;
  }

  void _showAnalyticsDetailPopup({
    required String title,
    required String statusType,
    required Color color,
    required IconData icon,
  }) {
    final details = _buildAnalyticsDetailsByStatus(statusType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${details.length} data pada ${_analyticsPeriodLabel()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  if (details.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 56,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tidak ada detail data',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Data tidak ditemukan pada periode ini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: details.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = details[i];

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withOpacity(0.16),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: color.withOpacity(0.14),
                                  child: Text(
                                    item.name.isNotEmpty
                                        ? item.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      const SizedBox(height: 2),

                                      Text(
                                        item.department,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      const SizedBox(height: 6),

                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.calendar_today_rounded,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat(
                                                  'dd MMM yyyy',
                                                  'id_ID',
                                                ).format(item.tanggal),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF475569),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),

                                          if (item.jamMasuk != null &&
                                              item.jamMasuk!.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item.jamMasuk!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF475569),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),

                                      if (item.keterangan != null &&
                                          item.keterangan!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.notes_rounded,
                                              size: 12,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                item.keterangan!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF475569),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Widget _buildAnalyticsSummaryItem({
  //   required String title,
  //   required String value,
  //   required IconData icon,
  //   required Color color,
  //   VoidCallback? onTap,
  // }) {
  //   return InkWell(
  //     onTap: onTap,
  //     borderRadius: BorderRadius.circular(14),
  //     child: Container(
  //       padding: const EdgeInsets.all(14),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(14),
  //         border: Border.all(color: color.withOpacity(0.18)),
  //       ),
  //       child: Row(
  //         children: [
  //           Container(
  //             padding: const EdgeInsets.all(9),
  //             decoration: BoxDecoration(
  //               color: color.withOpacity(0.12),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Icon(icon, color: color, size: 20),
  //           ),
  //           const SizedBox(width: 10),
  //           Expanded(
  //             child: Text(
  //               title,
  //               style: const TextStyle(
  //                 fontSize: 12,
  //                 color: Color(0xFF64748B),
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           ),
  //           Text(
  //             value,
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.w800,
  //               color: color,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  void _showDepartmentFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Pilih Departemen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.all_inclusive,
                color: Color(0xFF6366F1),
              ),
              title: const Text('Semua Departemen'),
              selected: selectedDepartment == null,
              onTap: () {
                setState(() => selectedDepartment = null);
                Navigator.pop(context);
                _loadAttendanceData(refresh: true);
              },
            ),
            ...departments.map(
              (d) => ListTile(
                leading: const Icon(Icons.business, color: Color(0xFF6366F1)),
                title: Text(d),
                selected: selectedDepartment == d,
                onTap: () {
                  setState(() => selectedDepartment = d);
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showOfficeFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Pilih Kantor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive, color: Colors.blue),
              title: const Text('Semua Kantor'),
              selected: selectedOffice == null,
              onTap: () {
                setState(() => selectedOffice = null);
                Navigator.pop(context);
                _loadAttendanceData(refresh: true);
              },
            ),
            ...offices.map(
              (o) => ListTile(
                leading: const Icon(
                  Icons.location_city,
                  color: Color(0xFFEF4444),
                ),
                title: Text(o.officeName),
                subtitle: o.address != null ? Text(o.address!) : null,
                selected: selectedOffice?.id == o.id,
                onTap: () {
                  setState(() => selectedOffice = o);
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _WebNavItem {
  final IconData icon;
  final String label;
  final int index;
  const _WebNavItem(this.icon, this.label, this.index);
}

class _PerfData {
  final String name;
  final String? department;

  int total = 0;
  int tepat = 0;
  int terlambat = 0;
  int tidakHadir = 0;
  int cuti = 0;
  int hadir = 0;

  int effectiveWorkDays = 0;
  double attendancePercent = 0;

  final Set<String> hadirDates = <String>{};
  final Set<String> cutiDates = <String>{};

  _PerfData(this.name, this.department);
}

class _AnalyticsDetailItem {
  final String userId;
  final String name;
  final String department;
  final DateTime tanggal;
  final String status;
  final String? jamMasuk;
  final String? keterangan;

  const _AnalyticsDetailItem({
    required this.userId,
    required this.name,
    required this.department,
    required this.tanggal,
    required this.status,
    this.jamMasuk,
    this.keterangan,
  });
}

class _DonutSeg {
  final double value;
  final Color color;
  _DonutSeg(this.value, this.color);
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSeg> segments;
  _DonutChartPainter(this.segments);

  static const double _pi = 3.1415926535897932;
  static const double _strokeWidth = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    var startAngle = -90 * _pi / 180;
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * 2 * _pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter old) =>
      old.segments != segments;
}
