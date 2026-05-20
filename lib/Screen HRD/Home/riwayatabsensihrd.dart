// screens/halaman_hrd_absensi.dart
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
import '../hrd_absensi_edit.dart';

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

  bool isLoading = false;
  String errorMessage = '';
  String selectedTimeRange = 'Semua Data';
  DateTimeRange? customDateRange;
  String selectedStatusFilter = 'Semua';
  Employee? selectedEmployee;
  Office? selectedOffice;
  String? selectedDepartment;
  String searchTerm = '';

  List<AdminAttendanceData> attendanceData = [];
  AdminAttendanceStats? stats;
  List<Employee> employees = [];
  List<Office> offices = [];
  List<String> departments = [];

  int currentPage = 1;
  int totalPages = 1;
  bool hasMoreData = false;
  bool isExporting = false;

  Map<String, int> departmentStats = {};
  Map<String, double> attendanceRateByDepartment = {};
  List<Employee> problematicEmployees = [];

  int _webTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _webTabIndex = _tabController.index);
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

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

  Future<void> _loadDashboardStats() async {
    try {
      String? timeRangeToSend;
      DateTime? startDateToSend, endDateToSend;
      if (selectedTimeRange == 'Pilih Periode' && customDateRange != null) {
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal meload data HRD.')));
      }
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
          if (refresh) {
            attendanceData = r.data?.data ?? [];
          } else {
            attendanceData.addAll(r.data?.data ?? []);
          }
          totalPages = r.data?.totalPages ?? 1;
          hasMoreData = currentPage < totalPages;
          isLoading = false;
          errorMessage = '';
        });
        if (refresh) await _loadHRDAnalytics();
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

  Future<void> _refreshData() async => _loadInitialData();

  // ─────────────────────────────────────────────────────────────────
  // UPDATE ITEM LANGSUNG (tanpa reload dari server)
  // ─────────────────────────────────────────────────────────────────

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

      // Hitung ulang working_hours_minutes
      int? newWorking;
      final ciDt = newCheckInTime != null
          ? DateTime.tryParse(newCheckInTime)
          : old.checkInTime;
      final coDt = newCheckOutTime != null
          ? DateTime.tryParse(newCheckOutTime)
          : old.checkOutTime;
      if (ciDt != null && coDt != null) {
        newWorking = coDt.difference(ciDt).inMinutes;
      }

      // Resolve displayStatus baru
      final statusRaw = newCheckInStatus ?? old.checkInStatus;
      String newDisplay = old.displayStatus;
      final s = statusRaw.toLowerCase();
      if (s.contains('tepat')) {
        newDisplay = 'Tepat Waktu';
      } else if (s.contains('terlambat'))
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

  // ─────────────────────────────────────────────────────────────────
  // BUKA EDIT SHEET INLINE
  // ─────────────────────────────────────────────────────────────────

  void _openEditSheet(AdminAttendanceData data) {
    // Konversi AdminAttendanceData → HrdAttendanceData
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
  // EXPORT
  // ─────────────────────────────────────────────────────────────────

  Future<void> _exportData() async {
    setState(() => isExporting = true);
    try {
      String? periodLabel;
      if (selectedTimeRange == 'Pilih Periode' && customDateRange != null) {
        periodLabel =
            '${DateFormat('dd MMM yyyy', 'id_ID').format(customDateRange!.start)} - '
            '${DateFormat('dd MMM yyyy', 'id_ID').format(customDateRange!.end)}';
      } else if (selectedTimeRange != 'Semua Data') {
        periodLabel = selectedTimeRange;
      }
      final bytes = ExcelExportService.buildAbsensiExcel(
        attendanceData,
        periodLabel: periodLabel,
      );
      if (bytes == null) throw Exception('Gagal encode excel');
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Absensi_$timestamp.xlsx';

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
        setState(() => isExporting = false);
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
          setState(() => isExporting = false);
          return;
        }
      }
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('Tidak dapat mengakses direktori');
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
        if (open == true) await OpenFile.open(path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Gagal export: $e');
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
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
        // ── Tombol buka halaman Edit Absensi ──
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
              // Refresh setelah kembali (sync log & perubahan dari halaman edit)
              _refreshData();
            },
          ),
        ),
        // ── Tombol refresh ──
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
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE / WEB LAYOUT
  // ─────────────────────────────────────────────────────────────────

  Widget _buildMobileBody() => TabBarView(
    controller: _tabController,
    children: [
      _buildDashboardTab(),
      _buildAttendanceTab(),
      _buildAnalyticsTab(),
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

  // ─────────────────────────────────────────────────────────────────
  // DASHBOARD TAB
  // ─────────────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard HRD - Absensi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            _buildHRDStatsGrid(),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (ctx, c) {
                if (c.maxWidth >= 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDepartmentAnalytics()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildProblematicEmployees()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildDepartmentAnalytics(),
                    const SizedBox(height: 16),
                    _buildProblematicEmployees(),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ABSENSI TAB
  // ─────────────────────────────────────────────────────────────────

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
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: filterW),
                  const SizedBox(width: 16),
                  Expanded(child: listW),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [filterW, const SizedBox(height: 20), listW],
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ANALITIK TAB
  // ─────────────────────────────────────────────────────────────────

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.analytics, color: Colors.white, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Analitik HRD',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Analisis mendalam data absensi karyawan',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (ctx, c) {
                if (c.maxWidth >= 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDepartmentAnalytics()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildProblematicEmployees()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildDepartmentAnalytics(),
                    const SizedBox(height: 16),
                    _buildProblematicEmployees(),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // STATS GRID
  // ─────────────────────────────────────────────────────────────────

  Widget _buildHRDStatsGrid() {
    final s = stats ?? AdminAttendanceStats();
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
                ),
                _statCard(
                  'Terlambat',
                  s.terlambat.toString(),
                  Icons.access_time,
                  const Color(0xFFF59E0B),
                  subtitle: 'Karyawan',
                  warn: s.terlambat > 5,
                ),
                _statCard(
                  'Tidak Hadir',
                  s.tidakHadir.toString(),
                  Icons.cancel,
                  const Color(0xFFEF4444),
                  subtitle: 'Karyawan',
                  warn: s.tidakHadir > 3,
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                          'Tingkat Kehadiran',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_calculateAttendanceRate()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
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

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    bool warn = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warn ? color.withOpacity(0.5) : color.withOpacity(0.2),
          width: warn ? 2 : 1,
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
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // FILTER SECTION
  // ─────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────
  // ATTENDANCE LIST & CARD
  // ─────────────────────────────────────────────────────────────────

  Widget _buildAttendanceList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!isLoading &&
            hasMoreData &&
            n.metrics.pixels == n.metrics.maxScrollExtent) {
          _loadMoreData();
        }
        return false;
      },
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: attendanceData.length + (hasMoreData ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= attendanceData.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildAttendanceCard(attendanceData[i]);
        },
      ),
    );
  }

  Widget _buildAttendanceCard(AdminAttendanceData data) {
    final color = _statusColor(data.displayStatus);
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
              // Status icon
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
              // Info
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
              // ── Tombol edit langsung di card ──
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

  // ─────────────────────────────────────────────────────────────────
  // ANALYTICS WIDGETS
  // ─────────────────────────────────────────────────────────────────

  Widget _buildDepartmentAnalytics() {
    if (departmentStats.isEmpty) return const SizedBox.shrink();
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
          ...departmentStats.entries.map((e) {
            final rate = attendanceRateByDepartment[e.key] ?? 0;
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
                        '${e.value} • ${rate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: rate / 100,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate > 90
                          ? const Color(0xFF10B981)
                          : rate > 75
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

  Widget _buildProblematicEmployees() {
    if (problematicEmployees.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFEF4444), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Karyawan Perlu Perhatian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...problematicEmployees
              .take(5)
              .map(
                (emp) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(
                          0xFFEF4444,
                        ).withOpacity(0.1),
                        child: Text(
                          emp.name.isNotEmpty ? emp.name[0] : '?',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: const Text(
                          'Detail',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // DETAIL BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────

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
                      // Header
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
                      // Action buttons
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
                      // Detail items
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
  ) {
    return ElevatedButton.icon(
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
  }

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
    if (data.employeeId != null) {
      add('ID Karyawan', data.employeeId!, Icons.badge_outlined, Colors.indigo);
    }
    if (data.department != null) {
      add('Departemen', data.department!, Icons.business, Colors.teal);
    }
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
    if (data.checkOutStatus.isNotEmpty) {
      add(
        'Status Check Out',
        data.checkOutStatus,
        _statusIcon(data.checkOutStatus),
        _statusColor(data.checkOutStatus),
      );
    }
    if (data.checkInOfficeName != null) {
      add('Kantor', data.checkInOfficeName!, Icons.location_city, Colors.red);
    }
    add(
      'Keterangan',
      data.notes.isNotEmpty ? data.notes : 'Tidak ada keterangan',
      Icons.info,
      Colors.purple,
    );
    if (data.workingHoursMinutes != null) {
      add(
        'Jam Kerja',
        '${(data.workingHoursMinutes! / 60).toStringAsFixed(1)} jam',
        Icons.schedule,
        Colors.indigo,
      );
    }
    if (data.overtimeMinutes != null && data.overtimeMinutes! > 0) {
      add(
        'Lembur',
        '${(data.overtimeMinutes! / 60).toStringAsFixed(1)} jam',
        Icons.access_time_filled,
        Colors.amber,
      );
    }
    if (data.checkInFaceConfidence != null) {
      add(
        'Confidence Check In',
        '${(data.checkInFaceConfidence! * 100).toStringAsFixed(1)}%',
        Icons.face,
        Colors.blue,
      );
    }
    return items;
  }

  Widget _detailItem(String label, String value, IconData icon, Color color) {
    return Container(
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
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

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
    if (l.contains('terlambat') || l == 'late' || l == 'very_late') {
      return Colors.orange;
    }
    if (l.contains('cuti') || l == 'leave') return Colors.blue;
    if (l.contains('absent') || l.contains('tidak hadir')) return Colors.red;
    return Colors.grey;
  }

  IconData _statusIcon(String s) {
    final l = s.toLowerCase();
    if (l.contains('tepat') || l == 'on_time') return Icons.check_circle;
    if (l.contains('terlambat') || l == 'late' || l == 'very_late') {
      return Icons.access_time;
    }
    if (l.contains('cuti') || l == 'leave') return Icons.event_busy;
    if (l.contains('absent') || l.contains('tidak hadir')) return Icons.cancel;
    return Icons.help;
  }

  double _calculateAttendanceRate() {
    if (stats == null || stats!.totalKaryawan == 0) return 0;
    return ((stats!.tepatWaktu + stats!.masukKantor) /
            stats!.totalKaryawan *
            100)
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

  // ── Filter Sheets ──────────────────────────────────────────────────────────

  void _showDateFilterSheet() {
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
                'Pilih Periode Waktu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...[
              ('Semua Data', 'Semua Data', Icons.all_inbox),
              ('Hari Ini', '1 Hari', Icons.today),
              ('7 Hari Terakhir', '7 Hari Terakhir', Icons.date_range),
              ('30 Hari Terakhir', '30 Hari Terakhir', Icons.date_range),
            ].map(
              (item) => ListTile(
                leading: Icon(item.$3, color: const Color(0xFF6366F1)),
                title: Text(item.$1),
                selected: selectedTimeRange == item.$2,
                onTap: () {
                  setState(() {
                    selectedTimeRange = item.$2;
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                  _loadDashboardStats();
                },
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.calendar_today,
                color: Color(0xFF6366F1),
              ),
              title: const Text('Pilih Periode Custom'),
              subtitle: customDateRange != null
                  ? Text(
                      '${DateFormat('dd/MM/yyyy').format(customDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(customDateRange!.end)}',
                    )
                  : null,
              selected: selectedTimeRange == 'Pilih Periode',
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: customDateRange,
                );
                if (picked != null) {
                  setState(() {
                    customDateRange = picked;
                    selectedTimeRange = 'Pilih Periode';
                  });
                  _loadAttendanceData(refresh: true);
                  _loadDashboardStats();
                }
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
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
