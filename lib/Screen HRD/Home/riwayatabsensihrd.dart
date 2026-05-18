// screens/halaman_hrd_absensi.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
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

// ── helper ──────────────────────────────────────────
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

  // ── Web: index tab aktif ──
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

  Future<void> _loadInitialData() async {
    // Step 1: load employees, offices, stats secara paralel (cepat)
    await Future.wait([
      _loadEmployees(),
      _loadOffices(),
      _loadDashboardStats(),
    ]);

    // Step 2: load attendance data
    await _loadAttendanceData(refresh: true);

    // Step 3: analytics hanya sekali setelah data siap (tidak dipanggil lagi dari _loadAttendanceData)
    await _loadHRDAnalytics();
  }

  Future<void> _loadEmployees() async {
    try {
      final response = await _adminService.getEmployees();
      if (response.success) {
        setState(() {
          employees = response.data ?? [];
          departments =
              employees.map((e) => e.department ?? 'Unknown').toSet().toList()
                ..sort();
        });
      }
    } catch (e) {
      setState(() => employees = []);
    }
  }

  Future<void> _loadOffices() async {
    try {
      final response = await _adminService.getOffices();
      if (response.success) {
        setState(() => offices = response.data ?? []);
      }
    } catch (e) {
      setState(() => offices = []);
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      String? timeRangeToSend;
      DateTime? startDateToSend;
      DateTime? endDateToSend;

      if (selectedTimeRange == 'Pilih Periode' && customDateRange != null) {
        startDateToSend = customDateRange!.start;
        endDateToSend = customDateRange!.end;
      } else if (selectedTimeRange != 'Semua Data') {
        timeRangeToSend = selectedTimeRange;
      }

      final response = await _adminService.getDashboardStats(
        timeRange: timeRangeToSend,
        startDate: startDateToSend,
        endDate: endDateToSend,
      );

      if (response.success) {
        setState(() => stats = response.data ?? AdminAttendanceStats());
      }
    } catch (e) {
      setState(() => stats = AdminAttendanceStats());
    }
  }

  Future<void> _loadHRDAnalytics() async {
    try {
      Map<String, int> deptStats = {};
      Map<String, List<AdminAttendanceData>> deptAttendance = {};

      for (var data in attendanceData) {
        String dept = data.department ?? 'Unknown';
        deptStats[dept] = (deptStats[dept] ?? 0) + 1;
        deptAttendance.putIfAbsent(dept, () => []).add(data);
      }

      Map<String, double> deptRate = {};
      deptAttendance.forEach((dept, dataList) {
        int present = dataList
            .where(
              (d) =>
                  d.displayStatus.toLowerCase().contains('tepat') ||
                  d.displayStatus.toLowerCase().contains('terlambat'),
            )
            .length;
        deptRate[dept] = dataList.isEmpty
            ? 0
            : (present / dataList.length * 100);
      });

      Map<String, List<AdminAttendanceData>> empAttendance = {};
      for (var data in attendanceData) {
        empAttendance.putIfAbsent(data.userId, () => []).add(data);
      }

      List<Employee> problematic = [];
      empAttendance.forEach((userId, dataList) {
        int lateCount = dataList
            .where((d) => d.displayStatus.toLowerCase().contains('terlambat'))
            .length;
        int absentCount = dataList
            .where(
              (d) =>
                  d.displayStatus.toLowerCase().contains('tidak hadir') ||
                  d.displayStatus.toLowerCase().contains('absent'),
            )
            .length;
        double problemRate = dataList.isEmpty
            ? 0
            : ((lateCount + absentCount) / dataList.length * 100);
        if (problemRate > 30) {
          var emp = employees.firstWhere(
            (e) => e.userId == userId,
            orElse: () => Employee(userId: userId, name: 'Unknown'),
          );
          problematic.add(emp);
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
      DateTime? startDateToSend;
      DateTime? endDateToSend;

      if (selectedTimeRange == 'Pilih Periode' && customDateRange != null) {
        startDateToSend = customDateRange!.start;
        endDateToSend = customDateRange!.end;
      } else if (selectedTimeRange != 'Semua Data') {
        timeRangeToSend = selectedTimeRange;
      }

      String? statusFilter = selectedStatusFilter != 'Semua'
          ? selectedStatusFilter
          : null;

      final response = await _adminService.getAllAttendanceData(
        filterUserId: selectedEmployee?.userId,
        timeRange: timeRangeToSend,
        startDate: startDateToSend,
        endDate: endDateToSend,
        statusFilter: statusFilter,
        officeId: selectedOffice?.id,
        searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
        page: currentPage,
        pageSize: 50, // naik dari 20 → 50, kurangi jumlah request
      );

      if (response.success) {
        setState(() {
          if (refresh) {
            attendanceData = response.data?.data ?? [];
          } else {
            attendanceData.addAll(response.data?.data ?? []);
          }
          totalPages = response.data?.totalPages ?? 1;
          hasMoreData = currentPage < totalPages;
          isLoading = false;
          errorMessage = '';
        });
        // Analytics hanya di-update setelah refresh, bukan setiap load-more
        if (refresh) await _loadHRDAnalytics();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = response.message;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (!hasMoreData || isLoading) return;
    setState(() => currentPage++);
    await _loadAttendanceData();
  }

  Future<void> _refreshData() async => await _loadInitialData();

  Future<void> _exportData() async {
    setState(() => isExporting = true);
    try {
      // Buat label periode dari filter aktif
      String? periodLabel;
      if (selectedTimeRange == 'Pilih Periode' && customDateRange != null) {
        periodLabel =
            '${DateFormat('dd MMM yyyy', 'id_ID').format(customDateRange!.start)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(customDateRange!.end)}';
      } else if (selectedTimeRange != 'Semua Data') {
        periodLabel = selectedTimeRange;
      }

      // Pakai ExcelExportService untuk generate Excel yang rapi
      final bytes = ExcelExportService.buildAbsensiExcel(
        attendanceData,
        periodLabel: periodLabel,
      );
      if (bytes == null) throw Exception('Gagal encode excel');
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Absensi_$timestamp.xlsx';

      if (kIsWeb) {
        // Trigger download langsung via browser (dart:html)
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
      } else {
        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          Permission permission = androidInfo.version.sdkInt >= 33
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

        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          throw Exception('Tidak dapat mengakses direktori');
        }
        final path = '${directory.path}/$fileName';
        final file = File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);

        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
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
          if (shouldOpen == true) {
            await OpenFile.open(file.path);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export berhasil!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Gagal export: $e');
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _performSearch(String value) {
    setState(() => searchTerm = value);
    _loadAttendanceData(refresh: true);
  }

  Future<void> _showDetailAbsensi(AdminAttendanceData data) async {
    _showDetailBottomSheet(data);
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD UTAMA
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
      // Tab bar hanya untuk mobile
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
  // MOBILE BODY (layout asli)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDashboardTab(),
        _buildAttendanceTab(),
        _buildAnalyticsTab(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB BODY (2 kolom: sidebar nav kiri + konten kanan)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWebBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sidebar navigasi tab vertikal ──
        _buildWebSideNav(),

        // ── Konten tab aktif ──
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
  }

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
            final isSelected = _webTabIndex == tab.index;
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
                  color: isSelected
                      ? const Color(0xFF6366F1).withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
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
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : Colors.grey[500],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : Colors.grey[600],
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
  // DASHBOARD TAB — responsive grid
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
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600) {
                  // Web: analitik & problematic side by side
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
  // ABSENSI TAB — filter + list (web: 2 kolom filter/list)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildAttendanceTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;

            final filterWidget = _buildFilterSection();
            final listWidget = Column(
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
                  Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  )
                else if (attendanceData.isEmpty)
                  _buildEmptyStateWidget()
                else
                  _buildAttendanceList(),
              ],
            );

            if (isWide) {
              // Web: filter di kiri (fixed 300px), list di kanan
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: filterWidget),
                  const SizedBox(width: 16),
                  Expanded(child: listWidget),
                ],
              );
            }

            // Mobile: stacked
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [filterWidget, const SizedBox(height: 20), listWidget],
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ANALITIK TAB — responsive
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
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600) {
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
  // STATS GRID — 2 kolom mobile, 4 kolom web
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHRDStatsGrid() {
    final currentStats = stats ?? AdminAttendanceStats();

    return LayoutBuilder(
      builder: (context, constraints) {
        final int cols = constraints.maxWidth >= 600 ? 4 : 2;
        final double ratio = constraints.maxWidth >= 600 ? 1.6 : 1.2;

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
                _buildHRDStatCard(
                  'Total Karyawan',
                  currentStats.totalKaryawan.toString(),
                  Icons.people,
                  const Color(0xFF3B82F6),
                  subtitle: 'Terdaftar',
                ),
                _buildHRDStatCard(
                  'Tepat Waktu',
                  currentStats.tepatWaktu.toString(),
                  Icons.check_circle,
                  const Color(0xFF10B981),
                  subtitle: 'Karyawan',
                ),
                _buildHRDStatCard(
                  'Terlambat',
                  currentStats.terlambat.toString(),
                  Icons.access_time,
                  const Color(0xFFF59E0B),
                  subtitle: 'Karyawan',
                  isWarning: currentStats.terlambat > 5,
                ),
                _buildHRDStatCard(
                  'Tidak Hadir',
                  currentStats.tidakHadir.toString(),
                  Icons.cancel,
                  const Color(0xFFEF4444),
                  subtitle: 'Karyawan',
                  isWarning: currentStats.tidakHadir > 3,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Attendance rate card
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

  Widget _buildHRDStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? color.withOpacity(0.5) : color.withOpacity(0.2),
          width: isWarning ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isWarning
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
              if (isWarning)
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
  // FILTER SECTION — kompak untuk sidebar web
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

          // Search
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
            onChanged: (value) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_searchController.text == value) _performSearch(value);
              });
            },
          ),

          const SizedBox(height: 10),

          // Filter buttons — stacked vertikal (cocok di sidebar)
          _buildFilterBtn(
            'Periode',
            selectedTimeRange,
            Icons.calendar_today,
            const Color(0xFF3B82F6),
            _showDateFilterSheet,
          ),
          const SizedBox(height: 6),
          _buildFilterBtn(
            'Status',
            selectedStatusFilter,
            Icons.filter_alt,
            const Color(0xFF10B981),
            _showStatusFilterSheet,
          ),
          const SizedBox(height: 6),
          _buildFilterBtn(
            'Karyawan',
            selectedEmployee?.name ?? 'Semua',
            Icons.person,
            const Color(0xFF8B5CF6),
            _showEmployeeFilterSheet,
          ),
          const SizedBox(height: 6),
          _buildFilterBtn(
            'Departemen',
            selectedDepartment ?? 'Semua',
            Icons.business,
            const Color(0xFF6366F1),
            _showDepartmentFilterSheet,
          ),
          const SizedBox(height: 6),
          _buildFilterBtn(
            'Kantor',
            selectedOffice?.officeName ?? 'Semua',
            Icons.location_city,
            const Color(0xFFEF4444),
            _showOfficeFilterSheet,
          ),
          const SizedBox(height: 10),

          // Reset button
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

  Widget _buildFilterBtn(
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
      onNotification: (ScrollNotification scrollInfo) {
        if (!isLoading &&
            hasMoreData &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMoreData();
        }
        return false;
      },
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: attendanceData.length + (hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= attendanceData.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildAttendanceCard(attendanceData[index]);
        },
      ),
    );
  }

  Widget _buildAttendanceCard(AdminAttendanceData data) {
    return GestureDetector(
      onTap: () => _showDetailAbsensi(data),
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
                  color: _getStatusColor(data.displayStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(data.displayStatus),
                  color: _getStatusColor(data.displayStatus),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              data.displayStatus,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data.displayStatus,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(data.displayStatus),
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
                          _formatTanggalFromDateTime(data.attendanceDate),
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
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // DEPARTMENT ANALYTICS
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Analisis per Departemen',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Icon(Icons.insights, color: Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 14),
          ...departmentStats.entries.map((entry) {
            double rate = attendanceRateByDepartment[entry.key] ?? 0;
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
                          entry.key,
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
                        '${entry.value} • ${rate.toStringAsFixed(1)}%',
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

  // ─────────────────────────────────────────────────────────────────
  // PROBLEMATIC EMPLOYEES
  // ─────────────────────────────────────────────────────────────────
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
          ...problematicEmployees.take(5).map((employee) {
            return Container(
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
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                    child: Text(
                      employee.name.isNotEmpty ? employee.name[0] : '?',
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
                          employee.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (employee.department != null)
                          Text(
                            employee.department!,
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
                      setState(() => selectedEmployee = employee);
                      _loadAttendanceData(refresh: true);
                      setState(() => _webTabIndex = 1);
                      _tabController.animateTo(1);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('Detail', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // DETAIL BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────
  void _showDetailBottomSheet(AdminAttendanceData data) {
    final screenHeight = MediaQuery.of(context).size.height;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          height: screenHeight * 0.85,
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
                              color: _getStatusColor(
                                data.displayStatus,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getStatusIcon(data.displayStatus),
                              color: _getStatusColor(data.displayStatus),
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
                                  _formatTanggalFromDateTime(
                                    data.attendanceDate,
                                  ),
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
                                    color: _getStatusColor(
                                      data.displayStatus,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    data.displayStatus,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _getStatusColor(
                                        data.displayStatus,
                                      ),
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
                            child: _buildActionButton(
                              'Edit',
                              Icons.edit,
                              const Color(0xFF3B82F6),
                              () => _showEditAttendanceDialog(data),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              'Report',
                              Icons.description,
                              const Color(0xFF10B981),
                              () => _generateAttendanceReport(data),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              'Warning',
                              Icons.warning,
                              const Color(0xFFEF4444),
                              () => _sendWarningToEmployee(data),
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
                    onPressed: () => Navigator.pop(context),
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

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
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
    List<Widget> items = [];
    void add(String label, String value, IconData icon, Color color) {
      items.add(_buildDetailItem(label, value, icon, color));
    }

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
      _getStatusIcon(data.checkInStatus),
      _getStatusColor(data.checkInStatus),
    );
    if (data.checkOutStatus.isNotEmpty) {
      add(
        'Status Check Out',
        data.checkOutStatus,
        _getStatusIcon(data.checkOutStatus),
        _getStatusColor(data.checkOutStatus),
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

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
  Widget _buildLoadingWidget() {
    return const Center(
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
  }

  Widget _buildEmptyStateWidget() {
    return Center(
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
  }

  String _formatTanggalFromDateTime(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return date.toString().split(' ')[0];
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('tepat waktu') || s == 'on_time') return Colors.green;
    if (s.contains('terlambat') || s == 'late' || s == 'very_late') {
      return Colors.orange;
    }
    if (s.contains('cuti') || s == 'leave') return Colors.blue;
    if (s.contains('absent') || s.contains('tidak hadir')) return Colors.red;
    return Colors.grey;
  }

  IconData _getStatusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('tepat waktu') || s == 'on_time') {
      return Icons.check_circle;
    }
    if (s.contains('terlambat') || s == 'late' || s == 'very_late') {
      return Icons.access_time;
    }
    if (s.contains('cuti') || s == 'leave') return Icons.event_busy;
    if (s.contains('absent') || s.contains('tidak hadir')) {
      return Icons.cancel;
    }
    return Icons.help;
  }

  double _calculateAttendanceRate() {
    if (stats == null || stats!.totalKaryawan == 0) return 0;
    final present = stats!.tepatWaktu + stats!.masukKantor;
    return (present / stats!.totalKaryawan * 100).clamp(0, 100);
  }

  void _showEditAttendanceDialog(AdminAttendanceData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Absensi'),
        content: const Text('Fitur edit absensi akan segera tersedia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _generateAttendanceReport(AdminAttendanceData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
  }

  void _sendWarningToEmployee(AdminAttendanceData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
  }

  // ── Filter sheets (tidak berubah) ────────────────────────────────
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
    final options = [
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
            ...options.map(
              (opt) => ListTile(
                leading: Icon(opt.$2, color: opt.$3),
                title: Text(opt.$1),
                selected: selectedStatusFilter == opt.$1,
                onTap: () {
                  setState(() => selectedStatusFilter = opt.$1);
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
        builder: (context, scrollController) => SafeArea(
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
                  controller: scrollController,
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
              (dept) => ListTile(
                leading: const Icon(Icons.business, color: Color(0xFF6366F1)),
                title: Text(dept),
                selected: selectedDepartment == dept,
                onTap: () {
                  setState(() => selectedDepartment = dept);
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
              (office) => ListTile(
                leading: const Icon(
                  Icons.location_city,
                  color: Color(0xFFEF4444),
                ),
                title: Text(office.officeName),
                subtitle: office.address != null ? Text(office.address!) : null,
                selected: selectedOffice?.id == office.id,
                onTap: () {
                  setState(() => selectedOffice = office);
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

// ── model helper ──────────────────────────────────────────────────
class _WebNavItem {
  final IconData icon;
  final String label;
  final int index;
  const _WebNavItem(this.icon, this.label, this.index);
}
