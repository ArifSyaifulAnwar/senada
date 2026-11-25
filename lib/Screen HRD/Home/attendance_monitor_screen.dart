import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Screen User/Screen HRD/hrd_employee_service.dart';
import '../doa_karyawan_screen.dart';
import '../../Screen admin/model/admin_attendance_model.dart';
import '../../Screen admin/model/timeoffmodeladmin.dart';
import '../../Screen admin/service/admin_attendance_service.dart';
import '../../Screen admin/service/timeoffserviceadmin.dart';
import '../../Services/token_service.dart';
import '../../Services/company_calendar_service.dart';
import '../../Services/attendance_reminder_service.dart';
import '../../Services/prayer_schedule_service.dart';

/// Tampilan read-only untuk layar briefing. Semua data tetap lewat endpoint
/// HRD/Admin yang menggunakan JWT dan membatasi data berdasarkan perusahaan.
class AttendanceMonitorScreen extends StatefulWidget {
  const AttendanceMonitorScreen({super.key});

  @override
  State<AttendanceMonitorScreen> createState() =>
      _AttendanceMonitorScreenState();
}

class _AttendanceMonitorScreenState extends State<AttendanceMonitorScreen> {
  static const _background = Color(0xFF071431);
  static const _panel = Color(0xFF0B1B40);
  static const _muted = Color(0xFF9EACCD);
  static const _green = Color(0xFF18C886);
  static const _amber = Color(0xFFFFB52E);
  static const _blue = Color(0xFF459BFF);
  static const _red = Color(0xFFF14758);
  static const _purple = Color(0xFF8B42EB);
  static const _pageSize = 5;

  final _service = AdminAttendanceService();
  Timer? _refreshTimer;
  Timer? _pageTimer;
  Timer? _clockTimer;
  Timer? _prayerTickerTimer;
  final ScrollController _prayerTickerController = ScrollController();
  DateTime _clock = _jakartaNow();
  DateTime? _lastUpdated;
  DateTime? _dataDate;
  DateTimeRange? _activePeriod;
  bool _authorized = false;
  bool _checkingAccess = true;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _page = 0;
  List<Employee> _employees = [];
  List<AdminAttendanceData> _attendance = [];
  List<AdminAttendanceData> _periodAttendance = [];
  List<({String label, int present, int scheduled})> _periodTrend = [];
  final Map<int, List<AdminAttendanceData>> _pastPeriodAttendance = {};
  List<HrdWorkPeriod> _availablePeriods = [];
  DateTime? _periodListLoadedAt;
  List<AdminTimeOffData> _timeOffs = [];
  List<CompanyCalendarEvent> _calendarEvents = [];
  Map<String, List<int>> _workDays = {};
  Map<String, List<DoaRecord>> _doaByDate = {};
  DateTime? _doaLastLoaded;
  DateTime? _doaPeriodStart;
  int _companyStartMinutes = 8 * 60;
  List<PrayerScheduleEntry> _prayerSchedule = [];

  static DateTime _jakartaNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  static String _monthName(int month) => const [
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
  ][month - 1];

  static String _dateLabel(DateTime date) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${_monthName(date.month)} ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _clock = _jakartaNow());
    });
    _pageTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) setState(() => _page++);
    });
    _prayerTickerTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted ||
          _prayerSchedule.isEmpty ||
          !_prayerTickerController.hasClients) {
        return;
      }
      final position = _prayerTickerController.position;
      if (position.hasContentDimensions) {
        _prayerTickerController.jumpTo(position.pixels + 1);
      }
    });
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('Role') ?? '').toLowerCase();
    final userId = prefs.getString('UserID') ?? '';
    final token = await TokenService.getToken();
    final allowed =
        (role == 'hrd' || role == 'admin') &&
        userId.isNotEmpty &&
        token != null &&
        token.isNotEmpty;
    if (!mounted) return;
    setState(() {
      _authorized = allowed;
      _checkingAccess = false;
      if (!allowed) _loading = false;
    });
    if (!allowed) return;

    await _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    if (_refreshing || !_authorized) return;
    _refreshing = true;
    final now = _jakartaNow();
    final date = DateTime(now.year, now.month, now.day);
    final previousMonth = DateTime(date.year, date.month - 1, 1);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID') ?? '';
      if (userId.isEmpty || await TokenService.getToken() == null) {
        if (mounted) setState(() => _authorized = false);
        return;
      }

      final periodResult = await _service.getCurrentWorkPeriod();
      final activePeriod = periodResult.data;
      if (!periodResult.success || activePeriod == null) {
        throw StateError(periodResult.message);
      }
      final periodStart = DateUtils.dateOnly(activePeriod.start);
      final periodEnd = DateUtils.dateOnly(activePeriod.end);
      if (date.isBefore(periodStart) || date.isAfter(periodEnd)) {
        throw StateError('Periode kerja aktif tidak mencakup hari ini.');
      }
      final calendarYears = [
        for (var year = periodStart.year; year <= date.year; year++) year,
      ];

      final responses = await Future.wait<dynamic>([
        _service.getEmployees(),
        _service.getAllAttendanceData(
          startDate: date,
          endDate: date,
          pageSize: 500,
        ),
        _service.getAllAttendanceData(
          startDate: periodStart,
          endDate: date,
          pageSize: 10000,
        ),
        TimeOffAdminService.getAllTimeOffs(
          adminId: userId,
          yearFilter: date.year,
          monthFilter: date.month,
        ),
        TimeOffAdminService.getAllTimeOffs(
          adminId: userId,
          yearFilter: previousMonth.year,
          monthFilter: previousMonth.month,
        ),
        HrdEmployeeService.getAllWorkDays(),
        AttendanceReminderService.getCompanySchedule(userId),
        Future.wait(
          calendarYears.map(
            (year) => CompanyCalendarService.getByYear(year, userId: userId),
          ),
        ),
      ]);
      // Jadwal bersifat tambahan; API yang belum terpasang tidak boleh
      // menghentikan seluruh dashboard absensi.
      List<PrayerScheduleEntry> prayerSchedule = [];
      try {
        prayerSchedule = await PrayerScheduleService.list(date);
      } catch (_) {}
      final employees = responses[0];
      final attendance = responses[1];
      final periodAttendance = responses[2];
      final timeOffs = responses[3];
      final previousTimeOffs = responses[4];
      if (!employees.success ||
          !attendance.success ||
          !periodAttendance.success ||
          !timeOffs.success) {
        throw StateError(
          [
            if (!employees.success) employees.message,
            if (!attendance.success) attendance.message,
            if (!periodAttendance.success) periodAttendance.message,
            if (!timeOffs.success) timeOffs.message,
          ].join(' · '),
        );
      }
      final monitorEmployees = (employees.data as List<Employee>? ?? <Employee>[])
          .where(_includeInMonitor)
          .toList();
      final monitorIds = monitorEmployees
          .map((employee) => employee.userId.toLowerCase())
          .toSet();
      final employeesForTrend = monitorEmployees;
      final workDaysForTrend =
          (responses[5] as Map<String, List<int>>?) ?? <String, List<int>>{};
      if (_periodListLoadedAt == null ||
          DateTime.now().difference(_periodListLoadedAt!) >=
              const Duration(minutes: 5)) {
        final periodLists = await Future.wait([
          _service.getWorkPeriodsByYear(tahun: date.year - 1),
          _service.getWorkPeriodsByYear(tahun: date.year),
          _service.getWorkPeriodsByYear(tahun: date.year + 1),
        ]);
        _availablePeriods = [
          for (final result in periodLists)
            if (result.success) ...?result.data,
        ]..sort((a, b) => a.tanggalMulai.compareTo(b.tanggalMulai));
        _periodListLoadedAt = DateTime.now();
      }
      final selectedPeriods = _availablePeriods
          .where(
            (period) => !DateUtils.dateOnly(period.tanggalMulai).isAfter(date),
          )
          .toList();
      final recentPeriods = selectedPeriods.length > 6
          ? selectedPeriods.sublist(selectedPeriods.length - 6)
          : selectedPeriods;
      final trendYears = <int>{
        for (final period in recentPeriods) ...[
          period.tanggalMulai.year,
          period.tanggalSelesai.year,
        ],
      };
      final trendCalendars = (await Future.wait([
        for (final year in trendYears)
          CompanyCalendarService.getByYear(year, userId: userId),
      ])).expand((events) => events).toList();
      final trend = <({String label, int present, int scheduled})>[];
      for (final period in recentPeriods) {
        final start = DateUtils.dateOnly(period.tanggalMulai);
        final end = DateUtils.dateOnly(period.tanggalSelesai);
        final active = !date.isBefore(start) && !date.isAfter(end);
        List<AdminAttendanceData> records;
        if (active) {
          records =
              (periodAttendance.data?.data as List<AdminAttendanceData>?) ??
              <AdminAttendanceData>[];
        } else {
          records = _pastPeriodAttendance[period.id] ?? <AdminAttendanceData>[];
          if (!_pastPeriodAttendance.containsKey(period.id)) {
            final result = await _service.getAllAttendanceData(
              startDate: start,
              endDate: end,
              pageSize: 10000,
            );
            if (!result.success) continue;
            records = result.data?.data ?? <AdminAttendanceData>[];
            _pastPeriodAttendance[period.id] = records;
          }
        }
        var scheduledCount = 0;
        final through = active ? date : end;
        for (
          var day = start;
          !day.isAfter(through);
          day = day.add(const Duration(days: 1))
        ) {
          final events = trendCalendars.where(
            (event) => DateUtils.isSameDay(event.tanggal, day),
          );
          final workOverride = events.any((event) => event.isKerja);
          if (!workOverride && events.any((event) => event.isLibur)) continue;
          scheduledCount += employeesForTrend.where((employee) {
            if (!employee.isActive || employee.userId.isEmpty) return false;
            final customDays = workDaysForTrend[employee.userId];
            return customDays == null
                ? day.weekday <= DateTime.friday || workOverride
                : customDays.contains(day.weekday);
          }).length;
        }
        final presentCount = records
            .where((record) => record.checkInTime != null &&
                monitorIds.contains(record.userId.toLowerCase()))
            .map(
              (record) =>
                  '${record.userId.toLowerCase()}|${DateFormat('yyyy-MM-dd').format(record.attendanceDate)}',
            )
            .toSet()
            .length;
        trend.add((
          label: '${_monthName(period.bulan).substring(0, 3)} ${period.tahun}',
          present: presentCount,
          scheduled: scheduledCount,
        ));
      }
      final needsDoaRefresh =
          _doaLastLoaded == null ||
          _doaPeriodStart != periodStart ||
          DateTime.now().difference(_doaLastLoaded!) >=
              const Duration(minutes: 5);
      var doaByDate = _doaByDate;
      if (needsDoaRefresh) {
        final List<AdminAttendanceData> periodRows =
            (periodAttendance.data?.data as List<AdminAttendanceData>?) ??
            <AdminAttendanceData>[];
        final attendanceDates =
            periodRows
                .where(
                  (record) =>
                      monitorIds.contains(record.userId.toLowerCase()) &&
                      record.checkInTime != null &&
                      record.attendanceDate.isBefore(date),
                )
                .map((record) => DateUtils.dateOnly(record.attendanceDate))
                .toSet()
                .toList()
              ..sort();
        doaByDate = {};
        for (var offset = 0; offset < attendanceDates.length; offset += 6) {
          final batch = attendanceDates.skip(offset).take(6).toList();
          final List<Future<List<DoaRecord>>> requests = [
            for (final DateTime day in batch)
              DoaService.getDoaByTanggal(userId, day),
          ];
          final results = await Future.wait<List<DoaRecord>>(requests);
          for (var i = 0; i < batch.length; i++) {
            doaByDate[DateFormat('yyyy-MM-dd').format(batch[i])] = results[i];
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _employees = monitorEmployees;
        _attendance = (attendance.data?.data ?? <AdminAttendanceData>[])
            .where((record) => monitorIds.contains(record.userId.toLowerCase()))
            .toList();
        _periodAttendance =
            (periodAttendance.data?.data ?? <AdminAttendanceData>[])
                .where((record) => monitorIds.contains(record.userId.toLowerCase()))
                .toList();
        _periodTrend = trend;
        _prayerSchedule = prayerSchedule;
        _timeOffs = [
          ...?timeOffs.data,
          if (previousTimeOffs.success) ...?previousTimeOffs.data,
        ];
        _workDays = responses[5] ?? <String, List<int>>{};
        if (needsDoaRefresh) {
          _doaByDate = doaByDate;
          _doaLastLoaded = DateTime.now();
          _doaPeriodStart = periodStart;
        }
        final schedule = responses[6];
        _companyStartMinutes = schedule.hour * 60 + schedule.minute;
        _calendarEvents = (responses[7] as List<List<CompanyCalendarEvent>>)
            .expand((events) => events)
            .toList();
        _dataDate = date;
        _activePeriod = activePeriod;
        _lastUpdated = _jakartaNow();
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Data belum dapat diperbarui: $error';
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageTimer?.cancel();
    _clockTimer?.cancel();
    _prayerTickerTimer?.cancel();
    _prayerTickerController.dispose();
    super.dispose();
  }

  bool _hasActiveTimeOff(String userId, DateTime date) {
    return _timeOffs.any((leave) {
      if (leave.userId.toLowerCase() != userId.toLowerCase()) return false;
      final status = leave.status.trim().toLowerCase();
      if (const {
        'rejected',
        'ditolak',
        'cancelled',
        'canceled',
        'dibatalkan',
      }.contains(status)) {
        return false;
      }
      final start = DateUtils.dateOnly(leave.tanggalMulai);
      final end = DateUtils.dateOnly(leave.tanggalSelesai);
      return !date.isBefore(start) && !date.isAfter(end);
    });
  }

  bool _isLate(AdminAttendanceData record) {
    final status = '${record.displayStatus} ${record.checkInStatus}'
        .toLowerCase();
    return status.contains('terlambat') || status.contains('late');
  }

  bool _includeInMonitor(Employee employee) =>
      (employee.employmentStatus ?? '').trim().toUpperCase() != 'FREELANCE';

  bool _ignoreMissingCheckIn(Employee employee) {
    final role = (employee.role ?? '').trim().toUpperCase();
    if (role == 'ADMIN' || role == 'DIREKTUR') return true;
    final position = (employee.position ?? '').trim().toUpperCase();
    return position.contains('DIREKTUR') ||
        position == 'ADMIN' ||
        position.startsWith('ADMIN ');
  }

  List<Employee> get _scheduledEmployees {
    final date = _dataDate;
    if (date == null) return [];
    return _employees.where((employee) {
      if (!employee.isActive || employee.userId.isEmpty) return false;
      final days = _workDays[employee.userId];
      return days == null ? date.weekday <= 5 : days.contains(date.weekday);
    }).toList();
  }

  Map<String, AdminAttendanceData> get _checkIns {
    final result = <String, AdminAttendanceData>{};
    for (final record in _attendance) {
      if (record.checkInTime == null) continue;
      final key = record.userId.toLowerCase();
      final previous = result[key];
      if (previous == null ||
          record.checkInTime!.isAfter(previous.checkInTime!)) {
        result[key] = record;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_authorized) {
      return Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: _amber),
              const SizedBox(height: 16),
              const Text(
                'Dashboard monitor hanya untuk HRD dan Admin',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (_) => false),
                child: const Text('Buka halaman login'),
              ),
            ],
          ),
        ),
      );
    }

    final date = _dataDate;
    final scheduled = _scheduledEmployees;
    final checkIns = _checkIns;
    final present =
        scheduled
            .where(
              (employee) => checkIns.containsKey(employee.userId.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final at = checkIns[a.userId.toLowerCase()]!.checkInTime!;
            final bt = checkIns[b.userId.toLowerCase()]!.checkInTime!;
            return bt.compareTo(at);
          });
    final leave = date == null
        ? <Employee>[]
        : scheduled
              .where(
                (e) =>
                    !checkIns.containsKey(e.userId.toLowerCase()) &&
                    _hasActiveTimeOff(e.userId, date),
              )
              .toList();
    final pending =
        scheduled
            .where(
              (e) =>
                  !_ignoreMissingCheckIn(e) &&
                  !checkIns.containsKey(e.userId.toLowerCase()) &&
                  !leave.any((item) => item.userId == e.userId),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final late = present
        .where((e) => _isLate(checkIns[e.userId.toLowerCase()]!))
        .length;
    final activeIds = _employees
        .where((employee) => employee.isActive)
        .map((employee) => employee.userId.toLowerCase())
        .toSet();
    final periodByUserDay = <String, AdminAttendanceData>{};
    for (final record in _periodAttendance) {
      if (record.checkInTime == null ||
          !activeIds.contains(record.userId.toLowerCase())) {
        continue;
      }
      final key =
          '${record.userId.toLowerCase()}|${DateFormat('yyyy-MM-dd').format(record.attendanceDate)}';
      periodByUserDay.putIfAbsent(key, () => record);
    }
    final periodRecords = periodByUserDay.values.toList();
    final periodLate = periodRecords.where(_isLate).length;
    final lateByUser = <String, List<AdminAttendanceData>>{};
    for (final record in periodRecords) {
      if (!_isLate(record) ||
          (date != null && !record.attendanceDate.isBefore(date))) {
        continue;
      }
      lateByUser.putIfAbsent(record.userId.toLowerCase(), () => []).add(record);
    }
    DateTime latestLate(List<AdminAttendanceData> records) => records
        .map((r) => r.attendanceDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final attention =
        _employees
            .where(
              (employee) =>
                  employee.isActive &&
                  lateByUser.containsKey(employee.userId.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final aRecords = lateByUser[a.userId.toLowerCase()]!;
            final bRecords = lateByUser[b.userId.toLowerCase()]!;
            final byCount = bRecords.length.compareTo(aRecords.length);
            return byCount != 0
                ? byCount
                : latestLate(bRecords).compareTo(latestLate(aRecords));
          });
    final joinedApelByUser = <String, List<DateTime>>{};
    for (final entry in _doaByDate.entries) {
      final day = DateTime.tryParse(entry.key);
      if (day == null) continue;
      final participantIds = <String>{};
      for (final doa in entry.value) {
        participantIds.add(doa.pemimpinDoaId.toLowerCase());
        participantIds.addAll(doa.pesertaIds.map((id) => id.toLowerCase()));
      }
      for (final userId in participantIds) {
        if (activeIds.contains(userId)) {
          joinedApelByUser.putIfAbsent(userId, () => []).add(day);
        }
      }
    }
    final joinedApel =
        _employees
            .where(
              (employee) =>
                  employee.isActive &&
                  joinedApelByUser.containsKey(employee.userId.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final aDates = joinedApelByUser[a.userId.toLowerCase()]!;
            final bDates = joinedApelByUser[b.userId.toLowerCase()]!;
            final byCount = bDates.length.compareTo(aDates.length);
            return byCount != 0 ? byCount : bDates.last.compareTo(aDates.last);
          });
    final periodStart = _activePeriod?.start;
    var scheduledShifts = 0;
    if (periodStart != null && date != null) {
      for (
        var day = DateUtils.dateOnly(periodStart);
        !day.isAfter(date);
        day = day.add(const Duration(days: 1))
      ) {
        scheduledShifts += _employees.where((employee) {
          if (!employee.isActive || employee.userId.isEmpty) return false;
          final workDays = _workDays[employee.userId];
          return workDays == null
              ? day.weekday <= DateTime.friday
              : workDays.contains(day.weekday);
        }).length;
      }
    }
    String percentage(int value, int total) =>
        total == 0 ? '0%' : '${(value * 100 / total).toStringAsFixed(1)}%';
    final performers =
        <
          ({
            Employee employee,
            int hadir,
            int workDays,
            int earlyMinutes,
            double score,
          })
        >[];
    if (periodStart != null && date != null) {
      for (final employee in _employees.where(
        (e) => e.isActive && e.userId.isNotEmpty,
      )) {
        final records = periodRecords
            .where(
              (r) => r.userId.toLowerCase() == employee.userId.toLowerCase(),
            )
            .toList();
        if (records.isEmpty) continue;
        var effectiveDays = 0;
        for (
          var day = DateUtils.dateOnly(periodStart);
          !day.isAfter(date);
          day = day.add(const Duration(days: 1))
        ) {
          final events = _calendarEvents.where(
            (event) => DateUtils.isSameDay(event.tanggal, day),
          );
          final workOverride = events.any((event) => event.isKerja);
          if (!workOverride && events.any((event) => event.isLibur)) continue;
          final customDays = _workDays[employee.userId];
          if (customDays == null
              ? day.weekday <= DateTime.friday || workOverride
              : customDays.contains(day.weekday)) {
            effectiveDays++;
          }
        }
        var checkInScoreTotal = 0.0;
        var earlyMinutes = 0;
        for (final record in records) {
          final checkIn = record.checkInTime!;
          final difference =
              (_companyStartMinutes - checkIn.hour * 60 - checkIn.minute)
                  .clamp(-120, 120)
                  .toInt();
          checkInScoreTotal += difference >= 0
              ? 80.0 + difference.clamp(0, 60) / 60 * 20
              : (80.0 + difference / 30 * 20).clamp(0.0, 80.0).toDouble();
          if (difference > 0) earlyMinutes += difference;
        }
        final attendancePercent = effectiveDays == 0
            ? 0.0
            : records.length / effectiveDays * 100;
        final score =
            attendancePercent * .5 + (checkInScoreTotal / records.length) * .5;
        performers.add((
          employee: employee,
          hadir: records.length,
          workDays: effectiveDays,
          earlyMinutes: earlyMinutes,
          score: score,
        ));
      }
      performers.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byEarly = b.earlyMinutes.compareTo(a.earlyMinutes);
        return byEarly != 0 ? byEarly : b.hadir.compareTo(a.hadir);
      });
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 1250 && constraints.maxHeight >= 700;
            final content = Column(
              children: [
                _header(),
                if (_error != null) _warning(_error!),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Row(
                      children: [
                        _metric(
                          'KARYAWAN PT',
                          activeIds.length,
                          Icons.groups_rounded,
                          _blue,
                          '100% dari karyawan aktif',
                        ),
                        _metric(
                          'CHECK-IN PERIODE',
                          periodRecords.length,
                          Icons.event_available_rounded,
                          _green,
                          '${percentage(periodRecords.length, scheduledShifts)} dari jadwal periode',
                        ),
                        _metric(
                          'TEPAT WAKTU PERIODE',
                          periodRecords.length - periodLate,
                          Icons.person_remove_alt_1_rounded,
                          _amber,
                          '${percentage(periodRecords.length - periodLate, periodRecords.length)} dari check-in',
                        ),
                        _metric(
                          'TERLAMBAT PERIODE',
                          periodLate,
                          Icons.schedule_rounded,
                          _purple,
                          '${percentage(periodLate, periodRecords.length)} dari check-in',
                        ),
                        _metric(
                          'BELUM ABSEN HARI INI',
                          pending.length,
                          Icons.badge_rounded,
                          const Color(0xFF12B9D4),
                          '${percentage(pending.length, scheduled.where((employee) => !_ignoreMissingCheckIn(employee)).length)} dari karyawan terjadwal',
                        ),
                      ],
                    ),
                  ),
                  _prayerScheduleStrip(),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _overviewPanel(periodRecords),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _summaryPanel(
                              present.length - late,
                              late,
                              pending.length,
                              leave.length,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: _topPerformersPanel(performers),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _personPanel(
                              title: 'Karyawan terlambat',
                              subtitle: 'Keterlambatan periode sampai kemarin',
                              icon: Icons.priority_high_rounded,
                              color: _amber,
                              people: attention,
                              emptyMessage:
                                  'Tidak ada keterlambatan dalam periode',
                              detail: (e) {
                                final records =
                                    lateByUser[e.userId.toLowerCase()]!;
                                return '${records.length}x terlambat · terakhir ${DateFormat('dd MMM').format(latestLate(records))}';
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 4,
                            child: _personPanel(
                              title: 'Karyawan ikut apel',
                              subtitle: 'Peserta apel dalam periode hingga kemarin',
                              icon: Icons.volunteer_activism_rounded,
                              color: _green,
                              people: joinedApel,
                              emptyMessage:
                                  'Belum ada peserta apel tercatat',
                              detail: (e) {
                                final dates =
                                    joinedApelByUser[e.userId.toLowerCase()]!;
                                return '${dates.length}x ikut · terakhir ${DateFormat('dd MMM').format(dates.last)}';
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 4,
                            child: _personPanel(
                              title: 'Belum check-in',
                              subtitle: 'Karyawan terjadwal hari ini',
                              icon: Icons.pending_actions_rounded,
                              color: _amber,
                              people: pending,
                              detail: (e) =>
                                  e.department ?? 'Belum ada departemen',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: _monthlyPanel()),
                        ],
                      ),
                    ),
                  ),
                ],
                _footer(),
              ],
            );
            return wide
                ? content
                : SingleChildScrollView(
                    child: SizedBox(
                      width: math.max(1250, constraints.maxWidth),
                      height: math.max(700, constraints.maxHeight),
                      child: content,
                    ),
                  );
          },
        ),
      ),
    );
  }

  Widget _chartPanel(String title, Widget child) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFF1E3561)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: child),
      ],
    ),
  );

  Widget _overviewPanel(List<AdminAttendanceData> records) {
    final start = _activePeriod?.start;
    final end = _dataDate;
    final days = start == null || end == null
        ? <DateTime>[]
        : List.generate(
            end.difference(DateUtils.dateOnly(start)).inDays + 1,
            (i) => DateUtils.dateOnly(start).add(Duration(days: i)),
          );
    final present = <double>[];
    final absent = <double>[];
    final late = <double>[];
    final leave = <double>[];
    for (final day in days) {
      final daily = records.where(
        (r) => DateUtils.isSameDay(r.attendanceDate, day),
      );
      final checkedInIds = daily.map((r) => r.userId.toLowerCase()).toSet();
      final scheduled = _employees.where((employee) {
        if (!employee.isActive || employee.userId.isEmpty) return false;
        final workDays = _workDays[employee.userId];
        return workDays == null
            ? day.weekday <= DateTime.friday
            : workDays.contains(day.weekday);
      }).toList();
      final missingEligible = scheduled
          .where((employee) => !_ignoreMissingCheckIn(employee))
          .toList();
      final onLeave = missingEligible
          .where(
            (employee) =>
                !checkedInIds.contains(employee.userId.toLowerCase()) &&
                _hasActiveTimeOff(employee.userId, day),
          )
          .length;
      present.add(daily.length.toDouble());
      late.add(daily.where(_isLate).length.toDouble());
      leave.add(onLeave.toDouble());
      absent.add(
        math
            .max(
              0,
              missingEligible.length -
                  missingEligible
                      .where(
                        (employee) => checkedInIds.contains(
                          employee.userId.toLowerCase(),
                        ),
                      )
                      .length -
                  onLeave,
            )
            .toDouble(),
      );
    }
    final peak = [
      present,
      absent,
      late,
      leave,
    ].expand((series) => series).fold<double>(0, math.max);
    final maximum = math.max(1.0, (peak / 4).ceil() * 4.0);
    return _chartPanel(
      'TREN KEHADIRAN PERIODE BERJALAN',
      Column(
        children: [
          Row(
            children: [
              _legend('Hadir', _green),
              const SizedBox(width: 15),
              _legend('Belum hadir', _red),
              const SizedBox(width: 15),
              _legend('Terlambat', _amber),
              const SizedBox(width: 15),
              _legend('Izin / cuti', _blue),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _AttendanceTrendPainter(
                present: present,
                absent: absent,
                late: late,
                leave: leave,
                maximum: maximum,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 33, right: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final index = days.isEmpty
                    ? 0
                    : ((days.length - 1) * i / 4).round();
                return Text(
                  days.isEmpty ? '-' : DateFormat('dd MMM').format(days[index]),
                  style: const TextStyle(color: _muted, fontSize: 10),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    ],
  );

  Widget _summaryPanel(int onTime, int late, int pending, int leave) {
    final total = onTime + late + pending + leave;
    return _chartPanel(
      'STATUS ABSENSI HARI INI',
      Row(
        children: [
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, c) {
                final size = math.min(c.maxWidth, c.maxHeight);
                return Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(size, size),
                          painter: _AttendanceDonutPainter(
                            values: [onTime, pending, late, leave],
                            colors: const [_green, _red, _amber, _blue],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Terjadwal',
                              style: TextStyle(color: _muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryItem('Tepat waktu', onTime, total, _green),
                _summaryItem('Belum absen', pending, total, _red),
                _summaryItem('Terlambat', late, total, _amber),
                _summaryItem('Izin / cuti', leave, total, _blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int count, int total, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
            Text(
              '$count (${total == 0 ? 0 : (count * 100 / total).round()}%)',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      );

  Widget _monthlyPanel() {
    const colors = <Color>[_green, _blue, _amber, _purple, _red, _green];
    return _chartPanel(
      'KEHADIRAN PER PERIODE KERJA',
      _periodTrend.isEmpty
          ? const Center(
              child: Text(
                'Belum ada data periode kerja',
                style: TextStyle(color: _muted),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_periodTrend.length, (i) {
                final item = _periodTrend[i];
                final rate = item.scheduled == 0
                    ? 0
                    : (item.present * 100 / item.scheduled)
                          .clamp(0, 100)
                          .round();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Text(
                          '$rate%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              widthFactor: .65,
                              heightFactor: rate == 0 ? .015 : rate / 100,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF133AAB), Color(0xFF081F67), Color(0xFF102A70)],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 55,
          height: 55,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Image.asset(
            'assets/images/icon_sdb_monitor1.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DASHBOARD ABSENSI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _activePeriod == null
                    ? 'Menunggu periode kerja PT'
                    : 'Periode kerja PT: ${DateFormat('dd/MM/yyyy').format(_activePeriod!.start)} - ${DateFormat('dd/MM/yyyy').format(_activePeriod!.end)}  |  Briefing hari ini',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFC0D5ED), fontSize: 13),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _dateLabel(_clock),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${DateFormat('HH:mm:ss').format(_clock)} WIB',
              style: const TextStyle(
                color: _green,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color accent,
    String description,
  ) => Expanded(
    child: Container(
      height: 112,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: .48),
            accent.withValues(alpha: .33),
            accent.withValues(alpha: .19),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .13), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE4ECFF),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .62),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: .28), blurRadius: 9),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 29),
          ),
        ],
      ),
    ),
  );

  Widget _personPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Employee> people,
    String emptyMessage = 'Belum ada data',
    int rowsPerPage = _pageSize,
    required String Function(Employee) detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF1E3561)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Header, pemisah, dan indikator halaman butuh ruang tetap.
          // Setiap nama butuh >=36 px agar dua baris teks tidak overflow.
          final fittedRows = math.max(
            1,
            ((constraints.maxHeight - 82) / 36).floor(),
          );
          final visibleRows = math.min(rowsPerPage, fittedRows);
          final pages = people.isEmpty
              ? 1
              : (people.length / visibleRows).ceil();
          final page = _page % pages;
          final visible = people
              .skip(page * visibleRows)
              .take(visibleRows)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 23),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${people.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF29415D), height: 1),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      emptyMessage,
                      style: const TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: visible
                        .map(
                          (employee) => Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: color.withValues(alpha: .15),
                                  child: Text(
                                    employee.name.isEmpty
                                        ? '?'
                                        : employee.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        employee.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        detail(employee),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (pages > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Halaman ${page + 1}/$pages · berganti otomatis',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _topPerformersPanel(
    List<
      ({
        Employee employee,
        int hadir,
        int workDays,
        int earlyMinutes,
        double score,
      })
    >
    performers,
  ) {
    final visible = performers.take(5).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF1E3561)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KARYAWAN PALING DISIPLIN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data kehadiran periode ini',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final rowCount = math.min(
                        visible.length,
                        math.max(1, (constraints.maxHeight / 24).floor()),
                      );
                      final showDetail = constraints.maxHeight / rowCount >= 38;
                      return Column(
                        children: visible
                            .take(rowCount)
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (entry) => Expanded(
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 25,
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                          color: _amber,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.value.employee.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (showDetail)
                                            Text(
                                              '${entry.value.hadir}/${entry.value.workDays} hadir${entry.value.earlyMinutes > 0 ? ' · ${entry.value.earlyMinutes} menit lebih awal' : ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: _muted,
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      entry.value.score.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: _green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _warning(String message) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(24, 10, 24, 0),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: const Color(0xFF563D22),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      message,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: _amber, fontSize: 11),
    ),
  );

  Widget _prayerScheduleStrip() {
    const labels = {
      'SUBUH': 'Subuh',
      'ZUHUR': 'Zuhur',
      'ASAR': 'Asar',
      'MAGRIB': 'Magrib',
      'ISYA': 'Isya',
    };
    return Container(
      height: 58,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF254278)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mosque, color: _blue, size: 18),
          const SizedBox(width: 8),
          const Text(
            'JADWAL SALAT HARI INI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _prayerSchedule.isEmpty
                ? const Text(
                    'Belum ada jadwal',
                    style: TextStyle(color: _muted, fontSize: 11),
                  )
                : ListView.builder(
                    controller: _prayerTickerController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, index) {
                      final item =
                          _prayerSchedule[index % _prayerSchedule.length];
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 32),
                          child: Text(
                            '${labels[item.prayerCode] ?? item.prayerCode}  ·  Azan ${item.muadzinName}  ·  Imam ${item.imamName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _footer() => Container(
    height: 39,
    padding: const EdgeInsets.symmetric(horizontal: 25),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF252277), Color(0xFF6225A9), Color(0xFF262374)],
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 9, color: _green),
        const SizedBox(width: 7),
        const Text(
          'Data diperbarui otomatis setiap 30 detik',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
        const Spacer(),
        Text(
          _lastUpdated == null
              ? 'Menunggu data'
              : 'Pembaruan terakhir ${DateFormat('HH:mm:ss').format(_lastUpdated!)} WIB',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: _refresh,
          child: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ],
    ),
  );
}

class _AttendanceTrendPainter extends CustomPainter {
  const _AttendanceTrendPainter({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.maximum,
  });

  final List<double> present;
  final List<double> absent;
  final List<double> late;
  final List<double> leave;
  final double maximum;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 33.0;
    const top = 7.0;
    const bottom = 5.0;
    final width = math.max(1.0, size.width - left - 6);
    final height = math.max(1.0, size.height - top - bottom);
    final grid = Paint()
      ..color = const Color(0xFF29426D)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      final label = TextPainter(
        text: TextSpan(
          text: '${(maximum * (4 - i) / 4).round()}',
          style: const TextStyle(color: Color(0xFFB7C7E8), fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(left - label.width - 7, y - label.height / 2));
    }
    canvas.drawLine(Offset(left, top), Offset(left, top + height), grid);

    Offset pointAt(List<double> values, int i) => Offset(
      left + width * i / math.max(1, values.length - 1),
      top + height * (1 - (values[i] / maximum).clamp(0.0, 1.0)),
    );

    if (present.isNotEmpty) {
      final area = Path()..moveTo(left, top + height);
      for (var i = 0; i < present.length; i++) {
        final point = pointAt(present, i);
        area.lineTo(point.dx, point.dy);
      }
      area.lineTo(left + width, top + height);
      area.close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xAA13BD81), Color(0x1213BD81)],
          ).createShader(Rect.fromLTWH(left, top, width, height)),
      );
    }

    void line(List<double> values, Color color) {
      if (values.isEmpty) return;
      final path = Path();
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      final dot = Paint()..color = color;
      for (var i = 0; i < values.length; i++) {
        final point = pointAt(values, i);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        final step = math.max(1, (values.length / 12).ceil());
        if (i % step == 0 || i == values.length - 1) {
          canvas.drawCircle(point, 2.9, dot);
        }
      }
      canvas.drawPath(path, paint);
    }

    line(present, const Color(0xFF18C886));
    line(absent, const Color(0xFFF14758));
    line(late, const Color(0xFFFFB52E));
    line(leave, const Color(0xFF459BFF));
  }

  @override
  bool shouldRepaint(covariant _AttendanceTrendPainter oldDelegate) =>
      oldDelegate.present != present ||
      oldDelegate.absent != absent ||
      oldDelegate.late != late ||
      oldDelegate.leave != leave ||
      oldDelegate.maximum != maximum;
}

class _AttendanceDonutPainter extends CustomPainter {
  const _AttendanceDonutPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    final ring = math.max(14.0, size.width * .21);
    final inset = ring / 2 + 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring;
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        paint..color = const Color(0xFF29426D),
      );
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = math.pi * 2 * values[i] / total;
      canvas.drawArc(rect, start, sweep, false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceDonutPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString();
}
