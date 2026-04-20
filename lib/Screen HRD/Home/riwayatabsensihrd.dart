// screens/halaman_hrd_absensi.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Screen admin/model/admin_attendance_model.dart';
import '../../Screen admin/service/admin_attendance_service.dart';

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

  // HRD specific stats
  Map<String, int> departmentStats = {};
  Map<String, double> attendanceRateByDepartment = {};
  List<Employee> problematicEmployees = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadEmployees(),
      _loadOffices(),
      _loadAttendanceData(refresh: true),
      _loadDashboardStats(),
      _loadHRDAnalytics(),
    ]);
  }

  Future<void> _loadEmployees() async {
    try {
      final response = await _adminService.getEmployees();
      if (response.success) {
        setState(() {
          employees = response.data ?? [];
          // Extract departments
          departments =
              employees.map((e) => e.department ?? 'Unknown').toSet().toList()
                ..sort();
        });
      }
    } catch (e) {
      setState(() {
        employees = [];
      });
    }
  }

  Future<void> _loadOffices() async {
    try {
      final response = await _adminService.getOffices();
      if (response.success) {
        setState(() {
          offices = response.data ?? [];
        });
      }
    } catch (e) {
      setState(() {
        offices = [];
      });
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
        timeRangeToSend = null;
      } else if (selectedTimeRange != 'Semua Data') {
        timeRangeToSend = selectedTimeRange;
      } else {
        timeRangeToSend = null;
      }

      final response = await _adminService.getDashboardStats(
        timeRange: timeRangeToSend,
        startDate: startDateToSend,
        endDate: endDateToSend,
      );

      if (response.success) {
        setState(() {
          stats = response.data ?? AdminAttendanceStats();
        });
      }
    } catch (e) {
      setState(() {
        stats = AdminAttendanceStats();
      });
    }
  }

  Future<void> _loadHRDAnalytics() async {
    // Load HRD specific analytics
    try {
      // Calculate department statistics
      Map<String, int> deptStats = {};
      Map<String, List<AdminAttendanceData>> deptAttendance = {};

      for (var data in attendanceData) {
        String dept = data.department ?? 'Unknown';
        deptStats[dept] = (deptStats[dept] ?? 0) + 1;

        if (!deptAttendance.containsKey(dept)) {
          deptAttendance[dept] = [];
        }
        deptAttendance[dept]!.add(data);
      }

      // Calculate attendance rate by department
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

      // Find problematic employees (high absence/late rate)
      Map<String, List<AdminAttendanceData>> employeeAttendance = {};
      for (var data in attendanceData) {
        String userId = data.userId;
        if (!employeeAttendance.containsKey(userId)) {
          employeeAttendance[userId] = [];
        }
        employeeAttendance[userId]!.add(data);
      }

      List<Employee> problematic = [];
      employeeAttendance.forEach((userId, dataList) {
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
          // More than 30% problematic attendance
          var employee = employees.firstWhere(
            (e) => e.userId == userId,
            orElse: () => Employee(userId: userId, name: 'Unknown'),
          );
          problematic.add(employee);
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
        timeRangeToSend = null;
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
        pageSize: 20,
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

        // Reload HRD analytics after data update
        await _loadHRDAnalytics();
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

    setState(() {
      currentPage++;
    });

    await _loadAttendanceData();
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  Future<void> _exportData() async {
    setState(() {
      isExporting = true;
    });

    try {
      // 1. bikin excel nya dulu (ini common, bisa dipakai web & mobile)

      var excel = Excel.createExcel();

      // nama sheet yang kita pakai
      const sheetName = 'Absensi';

      // Ambil sheet 'Absensi'
      Sheet sheetObject = excel[sheetName];

      // HAPUS sheet default yg kosong
      excel.delete('Sheet1'); // <-- ini penting

      // Set sheet 'Absensi' jadi aktif
      excel.setDefaultSheet(sheetName);
      // Header
      sheetObject.appendRow([
        TextCellValue('ID Absensi'),
        TextCellValue('Nama Karyawan'),
        TextCellValue('Departemen'),
        TextCellValue('Tanggal'),
        TextCellValue('Jam Masuk'),
        TextCellValue('Jam Keluar'),
        TextCellValue('Status'),
      ]);

      for (var data in attendanceData) {
        sheetObject.appendRow([
          TextCellValue(data.id.toString()),
          TextCellValue(data.userName),
          TextCellValue(data.department ?? '-'),
          TextCellValue(_formatTanggalFromDateTime(data.attendanceDate)),
          TextCellValue(data.formattedCheckIn),
          TextCellValue(data.formattedCheckOut),
          TextCellValue(data.displayStatus),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Gagal encode excel');

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Absensi_$timestamp.xlsx';

      // 2. Cek platform
      if (kIsWeb) {
        // ✅ Web platform - Flutter web tidak bisa direct download
        // User akan download via browser default behavior
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Export berhasil! File Excel siap diunduh. '
                'Gunakan fitur save dari browser Anda.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => isExporting = false);
        return;
      } else {
        // =========================
        // JALUR MOBILE / DESKTOP
        // =========================

        // cek permission android
        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          Permission permission;
          if (androidInfo.version.sdkInt >= 33) {
            permission = Permission.photos;
          } else {
            permission = Permission.storage;
          }

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

        // simpan ke folder external
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          throw Exception('Tidak dapat mengakses direktori penyimpanan');
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
              content: Text(
                'File Excel berhasil disimpan di:\n$path\n\nBuka sekarang?',
              ),
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
              content: Text('Export berhasil! File tersimpan di storage.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal export: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  // ✅ Simplified export untuk mobile/desktop
  // Untuk web, user akan menggunakan browser download

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
    setState(() {
      searchTerm = value;
    });
    _loadAttendanceData(refresh: true);
  }

  Future<void> _showDetailAbsensi(AdminAttendanceData data) async {
    _showDetailBottomSheet(data);
  }

  void _showDetailBottomSheet(AdminAttendanceData data) {
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          height: screenHeight * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with HRD Actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                data.displayStatus,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getStatusIcon(data.displayStatus),
                              color: _getStatusColor(data.displayStatus),
                              size: 30,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detail Absensi HRD',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatTanggalFromDateTime(
                                    data.attendanceDate,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
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

                      SizedBox(height: 24),

                      // HRD Action Buttons - Made responsive
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 400) {
                            // For wider screens, show buttons in a row
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    'Edit',
                                    Icons.edit,
                                    Color(0xFF3B82F6),
                                    () => _showEditAttendanceDialog(data),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: _buildActionButton(
                                    'Report',
                                    Icons.description,
                                    Color(0xFF10B981),
                                    () => _generateAttendanceReport(data),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: _buildActionButton(
                                    'Warning',
                                    Icons.warning,
                                    Color(0xFFEF4444),
                                    () => _sendWarningToEmployee(data),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // For smaller screens, show buttons in a column
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildActionButton(
                                        'Edit',
                                        Icons.edit,
                                        Color(0xFF3B82F6),
                                        () => _showEditAttendanceDialog(data),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: _buildActionButton(
                                        'Report',
                                        Icons.description,
                                        Color(0xFF10B981),
                                        () => _generateAttendanceReport(data),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildActionButton(
                                    'Warning',
                                    Icons.warning,
                                    Color(0xFFEF4444),
                                    () => _sendWarningToEmployee(data),
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),

                      SizedBox(height: 20),

                      // Detail informasi
                      ..._buildDetailItems(data),
                    ],
                  ),
                ),
              ),

              // Close button
              Padding(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6366F1),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 16,
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
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  List<Widget> _buildDetailItems(AdminAttendanceData data) {
    List<Widget> items = [];

    items.add(
      _buildDetailItem(
        'ID Absensi',
        '#${data.id.toString().padLeft(4, '0')}',
        Icons.badge,
        Colors.blue,
      ),
    );

    items.add(
      _buildDetailItem(
        'Nama Karyawan',
        data.userName,
        Icons.person,
        Colors.purple,
      ),
    );

    if (data.employeeId != null) {
      items.add(
        _buildDetailItem(
          'ID Karyawan',
          data.employeeId!,
          Icons.badge_outlined,
          Colors.indigo,
        ),
      );
    }

    if (data.department != null) {
      items.add(
        _buildDetailItem(
          'Departemen',
          data.department!,
          Icons.business,
          Colors.teal,
        ),
      );
    }

    if (data.displayStatus != 'Cuti') {
      items.add(
        _buildDetailItem(
          'Jam Masuk',
          data.formattedCheckIn,
          Icons.login,
          Colors.green,
        ),
      );

      items.add(
        _buildDetailItem(
          'Jam Keluar',
          data.formattedCheckOut,
          Icons.logout,
          Colors.orange,
        ),
      );
    }

    items.add(
      _buildDetailItem(
        'Status Check In',
        data.checkInStatus.isNotEmpty ? data.checkInStatus : 'Tidak ada data',
        _getStatusIcon(data.checkInStatus),
        _getStatusColor(data.checkInStatus),
      ),
    );

    if (data.checkOutStatus.isNotEmpty) {
      items.add(
        _buildDetailItem(
          'Status Check Out',
          data.checkOutStatus,
          _getStatusIcon(data.checkOutStatus),
          _getStatusColor(data.checkOutStatus),
        ),
      );
    }

    if (data.checkInOfficeName != null) {
      items.add(
        _buildDetailItem(
          'Kantor',
          data.checkInOfficeName!,
          Icons.location_city,
          Colors.red,
        ),
      );
    }

    items.add(
      _buildDetailItem(
        'Keterangan',
        data.notes.isNotEmpty ? data.notes : 'Tidak ada keterangan',
        Icons.info,
        Colors.purple,
      ),
    );

    if (data.workingHoursMinutes != null) {
      items.add(
        _buildDetailItem(
          'Jam Kerja',
          '${(data.workingHoursMinutes! / 60).toStringAsFixed(1)} jam',
          Icons.schedule,
          Colors.indigo,
        ),
      );
    }

    if (data.overtimeMinutes != null && data.overtimeMinutes! > 0) {
      items.add(
        _buildDetailItem(
          'Lembur',
          '${(data.overtimeMinutes! / 60).toStringAsFixed(1)} jam',
          Icons.access_time_filled,
          Colors.amber,
        ),
      );
    }

    if (data.checkInFaceConfidence != null) {
      items.add(
        _buildDetailItem(
          'Confidence Check In',
          '${(data.checkInFaceConfidence! * 100).toStringAsFixed(1)}%',
          Icons.face,
          Colors.blue,
        ),
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
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
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

  String _formatTanggalFromDateTime(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return date.toString().split(' ')[0];
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('tepat waktu') || statusLower == 'on_time') {
      return Colors.green;
    } else if (statusLower.contains('terlambat') ||
        statusLower == 'late' ||
        statusLower == 'very_late') {
      return Colors.orange;
    } else if (statusLower.contains('cuti') || statusLower == 'leave') {
      return Colors.blue;
    } else if (statusLower.contains('absent') ||
        statusLower.contains('tidak hadir')) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('tepat waktu') || statusLower == 'on_time') {
      return Icons.check_circle;
    } else if (statusLower.contains('terlambat') ||
        statusLower == 'late' ||
        statusLower == 'very_late') {
      return Icons.access_time;
    } else if (statusLower.contains('cuti') || statusLower == 'leave') {
      return Icons.event_busy;
    } else if (statusLower.contains('absent') ||
        statusLower.contains('tidak hadir')) {
      return Icons.cancel;
    } else {
      return Icons.help;
    }
  }

  Widget _buildHRDStatsGrid() {
    final currentStats = stats ?? AdminAttendanceStats();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Stats Cards - Responsive grid
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate number of columns based on screen width
            int crossAxisCount = isSmallScreen ? 2 : 4;
            double childAspectRatio = isSmallScreen ? 1.2 : 1.5;

            return GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                _buildHRDStatCard(
                  'Total Karyawan',
                  currentStats.totalKaryawan.toString(),
                  Icons.people,
                  Color(0xFF3B82F6),
                  subtitle: 'Terdaftar',
                ),
                _buildHRDStatCard(
                  'Tepat Waktu',
                  currentStats.tepatWaktu.toString(),
                  Icons.check_circle,
                  Color(0xFF10B981),
                  subtitle: 'Karyawan',
                ),
                _buildHRDStatCard(
                  'Terlambat',
                  currentStats.terlambat.toString(),
                  Icons.access_time,
                  Color(0xFFF59E0B),
                  subtitle: 'Karyawan',
                  isWarning: currentStats.terlambat > 5,
                ),
                _buildHRDStatCard(
                  'Tidak Hadir',
                  currentStats.tidakHadir.toString(),
                  Icons.cancel,
                  Color(0xFFEF4444),
                  subtitle: 'Karyawan',
                  isWarning: currentStats.tidakHadir > 3,
                ),
              ],
            );
          },
        ),

        SizedBox(height: 20),

        // Attendance Rate Card
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tingkat Kehadiran',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_calculateAttendanceRate()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
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
      padding: EdgeInsets.all(12),
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
            offset: Offset(0, 2),
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
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (isWarning)
                Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.priority_high, size: 10, color: Colors.red),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
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

  Widget _buildDepartmentAnalytics() {
    if (departmentStats.isEmpty) {
      return Container();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Analisis per Departemen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Icon(Icons.insights, color: Color(0xFF6366F1)),
            ],
          ),
          SizedBox(height: 16),
          ...departmentStats.entries.map((entry) {
            double rate = attendanceRateByDepartment[entry.key] ?? 0;
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${entry.value} • ${rate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: rate / 100,
                    backgroundColor: Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate > 90
                          ? Color(0xFF10B981)
                          : rate > 75
                          ? Color(0xFFF59E0B)
                          : Color(0xFFEF4444),
                    ),
                    minHeight: 6,
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
    if (problematicEmployees.isEmpty) {
      return Container();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFEF4444), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Karyawan Perlu Perhatian',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...problematicEmployees.take(5).map((employee) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFEF4444).withOpacity(0.1),
                    child: Text(
                      employee.name.isNotEmpty ? employee.name[0] : '?',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (employee.department != null)
                          Text(
                            employee.department!,
                            style: TextStyle(
                              fontSize: 12,
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
                        selectedEmployee = employee;
                      });
                      _loadAttendanceData(refresh: true);
                      _tabController.animateTo(1);
                    },
                    child: Text('Detail', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AdminAttendanceData data) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return GestureDetector(
      onTap: () => _showDetailAbsensi(data),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        data.displayStatus,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(data.displayStatus),
                      color: _getStatusColor(data.displayStatus),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.userName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (data.department != null)
                                    Text(
                                      data.department!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _getStatusColor(data.displayStatus),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (data.employeeId != null)
                          Row(
                            children: [
                              Icon(
                                Icons.badge,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'ID: ${data.employeeId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatTanggalFromDateTime(data.attendanceDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (data.displayStatus != 'Cuti') ...[
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: isSmallScreen
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.login,
                                            size: 16,
                                            color: Color(0xFF10B981),
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Masuk: ${data.formattedCheckIn}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.logout,
                                            size: 16,
                                            color: Color(0xFFF59E0B),
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Keluar: ${data.formattedCheckOut}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Icon(
                                        Icons.login,
                                        size: 16,
                                        color: Color(0xFF10B981),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Masuk: ${data.formattedCheckIn}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(
                                        Icons.logout,
                                        size: 16,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Keluar: ${data.formattedCheckOut}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                        if (data.checkInOfficeName != null) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_city,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data.checkInOfficeName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isSmallScreen &&
                            data.displayStatus.toLowerCase().contains(
                              'terlambat',
                            )) ...[
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _sendWarningToEmployee(data),
                                icon: Icon(Icons.warning, size: 16),
                                label: Text('Kirim Peringatan'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Filter Data HRD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (isExporting)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                GestureDetector(
                  onTap: _exportData,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download,
                          size: 16,
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
          SizedBox(height: 16),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan, ID, atau departemen...',
              prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF3B82F6)),
              ),
              filled: true,
              fillColor: Color(0xFFF8FAFC),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              Future.delayed(Duration(milliseconds: 500), () {
                if (_searchController.text == value) {
                  _performSearch(value);
                }
              });
            },
          ),

          SizedBox(height: 16),

          // Filter buttons - Made responsive
          if (isSmallScreen) ...[
            // For small screens, arrange filters in pairs
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    'Periode',
                    selectedTimeRange == 'Pilih Periode' &&
                            customDateRange != null
                        ? '${customDateRange!.start.day}/${customDateRange!.start.month} - ${customDateRange!.end.day}/${customDateRange!.end.month}'
                        : selectedTimeRange,
                    Icons.calendar_today,
                    Color(0xFF3B82F6),
                    _showDateFilterSheet,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton(
                    'Status',
                    selectedStatusFilter,
                    Icons.filter_alt,
                    Color(0xFF10B981),
                    _showStatusFilterSheet,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    'Karyawan',
                    selectedEmployee?.name ?? 'Semua Karyawan',
                    Icons.person,
                    Color(0xFF8B5CF6),
                    _showEmployeeFilterSheet,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton(
                    'Departemen',
                    selectedDepartment ?? 'Semua Dept',
                    Icons.business,
                    Color(0xFF6366F1),
                    _showDepartmentFilterSheet,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    'Kantor',
                    selectedOffice?.officeName ?? 'Semua Kantor',
                    Icons.location_city,
                    Color(0xFFEF4444),
                    _showOfficeFilterSheet,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
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
                    icon: Icon(Icons.clear, size: 16),
                    label: Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6B7280),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // For larger screens, keep original layout
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    'Periode',
                    selectedTimeRange == 'Pilih Periode' &&
                            customDateRange != null
                        ? '${customDateRange!.start.day}/${customDateRange!.start.month} - ${customDateRange!.end.day}/${customDateRange!.end.month}'
                        : selectedTimeRange,
                    Icons.calendar_today,
                    Color(0xFF3B82F6),
                    _showDateFilterSheet,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton(
                    'Status',
                    selectedStatusFilter,
                    Icons.filter_alt,
                    Color(0xFF10B981),
                    _showStatusFilterSheet,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    'Karyawan',
                    selectedEmployee?.name ?? 'Semua Karyawan',
                    Icons.person,
                    Color(0xFF8B5CF6),
                    _showEmployeeFilterSheet,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton(
                    'Departemen',
                    selectedDepartment ?? 'Semua Dept',
                    Icons.business,
                    Color(0xFF6366F1),
                    _showDepartmentFilterSheet,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    'Kantor',
                    selectedOffice?.officeName ?? 'Semua Kantor',
                    Icons.location_city,
                    Color(0xFFEF4444),
                    _showOfficeFilterSheet,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
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
                    icon: Icon(Icons.clear, size: 16),
                    label: Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6B7280),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
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
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
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
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Tidak ada data absensi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coba ubah filter atau periode waktu',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh),
              label: Text('Muat Ulang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        physics: NeverScrollableScrollPhysics(),
        itemCount: attendanceData.length + (hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= attendanceData.length) {
            return Center(
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

  void _showDateFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Pilih Periode Waktu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: Icon(Icons.all_inbox, color: Color(0xFF6366F1)),
                title: Text('Semua Data'),
                onTap: () {
                  setState(() {
                    selectedTimeRange = 'Semua Data';
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                  _loadDashboardStats();
                },
                selected: selectedTimeRange == 'Semua Data',
              ),
              ListTile(
                leading: Icon(Icons.today, color: Color(0xFF6366F1)),
                title: Text('Hari Ini'),
                onTap: () {
                  setState(() {
                    selectedTimeRange = '1 Hari';
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                  _loadDashboardStats();
                },
                selected: selectedTimeRange == '1 Hari',
              ),
              ListTile(
                leading: Icon(Icons.date_range, color: Color(0xFF6366F1)),
                title: Text('7 Hari Terakhir'),
                onTap: () {
                  setState(() {
                    selectedTimeRange = '7 Hari Terakhir';
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                  _loadDashboardStats();
                },
                selected: selectedTimeRange == '7 Hari Terakhir',
              ),
              ListTile(
                leading: Icon(Icons.date_range, color: Color(0xFF6366F1)),
                title: Text('30 Hari Terakhir'),
                onTap: () {
                  setState(() {
                    selectedTimeRange = '30 Hari Terakhir';
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                  _loadDashboardStats();
                },
                selected: selectedTimeRange == '30 Hari Terakhir',
              ),
              ListTile(
                leading: Icon(Icons.calendar_today, color: Color(0xFF6366F1)),
                title: Text('Pilih Periode Custom'),
                subtitle: customDateRange != null
                    ? Text(
                        '${DateFormat('dd/MM/yyyy').format(customDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(customDateRange!.end)}',
                      )
                    : null,
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
                selected: selectedTimeRange == 'Pilih Periode',
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showStatusFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Filter Status Absensi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: Icon(Icons.all_inclusive, color: Colors.blue),
                title: Text('Semua'),
                onTap: () {
                  setState(() => selectedStatusFilter = 'Semua');
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
                selected: selectedStatusFilter == 'Semua',
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Tepat Waktu'),
                onTap: () {
                  setState(() => selectedStatusFilter = 'Tepat Waktu');
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
                selected: selectedStatusFilter == 'Tepat Waktu',
              ),
              ListTile(
                leading: Icon(Icons.access_time, color: Colors.orange),
                title: Text('Terlambat'),
                onTap: () {
                  setState(() => selectedStatusFilter = 'Terlambat');
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
                selected: selectedStatusFilter == 'Terlambat',
              ),
              ListTile(
                leading: Icon(Icons.event_busy, color: Colors.blue),
                title: Text('Cuti'),
                onTap: () {
                  setState(() => selectedStatusFilter = 'Cuti');
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
                selected: selectedStatusFilter == 'Cuti',
              ),
              ListTile(
                leading: Icon(Icons.cancel, color: Colors.red),
                title: Text('Tidak Hadir'),
                onTap: () {
                  setState(() => selectedStatusFilter = 'Tidak Hadir');
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
                selected: selectedStatusFilter == 'Tidak Hadir',
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEmployeeFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Pilih Karyawan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.all_inclusive,
                            color: Colors.blue,
                          ),
                          title: Text('Semua Karyawan'),
                          onTap: () {
                            setState(() => selectedEmployee = null);
                            Navigator.pop(context);
                            _loadAttendanceData(refresh: true);
                          },
                          selected: selectedEmployee == null,
                        ),
                        ...employees.map(
                          (employee) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(
                                0xFF8B5CF6,
                              ).withOpacity(0.1),
                              child: Text(
                                employee.name.isNotEmpty
                                    ? employee.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(employee.name),
                            subtitle: Text(
                              '${employee.employeeId ?? ""} • ${employee.department ?? ""}',
                            ),
                            onTap: () {
                              setState(() => selectedEmployee = employee);
                              Navigator.pop(context);
                              _loadAttendanceData(refresh: true);
                            },
                            selected:
                                selectedEmployee?.userId == employee.userId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDepartmentFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Pilih Departemen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: Icon(Icons.all_inclusive, color: Color(0xFF6366F1)),
                title: Text('Semua Departemen'),
                onTap: () {
                  setState(() => selectedDepartment = null);
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
                selected: selectedDepartment == null,
              ),
              ...departments.map(
                (dept) => ListTile(
                  leading: Icon(Icons.business, color: Color(0xFF6366F1)),
                  title: Text(dept),
                  onTap: () {
                    setState(() => selectedDepartment = dept);
                    Navigator.pop(context);
                    _loadAttendanceData(refresh: true);
                  },
                  selected: selectedDepartment == dept,
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showOfficeFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Pilih Kantor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: Icon(Icons.all_inclusive, color: Colors.blue),
                title: Text('Semua Kantor'),
                onTap: () {
                  setState(() => selectedOffice = null);
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                },
                selected: selectedOffice == null,
              ),
              ...offices.map(
                (office) => ListTile(
                  leading: Icon(Icons.location_city, color: Color(0xFFEF4444)),
                  title: Text(office.officeName),
                  subtitle: office.address != null
                      ? Text(office.address!)
                      : null,
                  onTap: () {
                    setState(() => selectedOffice = office);
                    Navigator.pop(context);
                    _loadAttendanceData(refresh: true);
                  },
                  selected: selectedOffice?.id == office.id,
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // HRD Specific Methods
  double _calculateAttendanceRate() {
    if (stats == null || stats!.totalKaryawan == 0) return 0;

    // Menggunakan tepatWaktu + masukKantor sebagai total hadir
    final present = stats!.tepatWaktu + stats!.masukKantor;
    return (present / stats!.totalKaryawan * 100).clamp(0, 100);
  }

  void _showEditAttendanceDialog(AdminAttendanceData data) {
    // Implementation for editing attendance
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Absensi'),
        content: Text('Fitur edit absensi akan segera tersedia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _generateAttendanceReport(AdminAttendanceData data) {
    // Implementation for generating report
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generate Report'),
        content: Text('Laporan absensi akan segera tersedia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _sendWarningToEmployee(AdminAttendanceData data) {
    // Implementation for sending warning
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kirim Peringatan'),
        content: Text('Kirim peringatan ke ${data.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Peringatan telah dikirim'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard HRD - Absensi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 16),
            _buildHRDStatsGrid(),
            SizedBox(height: 20),
            _buildDepartmentAnalytics(),
            SizedBox(height: 20),
            _buildProblematicEmployees(),
            SizedBox(height: 20), // Extra padding at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterSection(),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
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
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${attendanceData.length} data',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (isLoading && attendanceData.isEmpty)
              _buildLoadingWidget()
            else if (errorMessage.isNotEmpty && attendanceData.isEmpty)
              Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: Text('Coba Lagi'),
                  ),
                ],
              )
            else if (attendanceData.isEmpty)
              _buildEmptyStateWidget()
            else
              _buildAttendanceList(),
            SizedBox(height: 20), // Extra padding at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
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
            SizedBox(height: 20),
            _buildDepartmentAnalytics(),
            SizedBox(height: 20),
            _buildProblematicEmployees(),
            SizedBox(height: 20), // Extra padding at bottom
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.assignment_ind,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            SizedBox(width: 10),
            Flexible(
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
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              onPressed: _refreshData,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xFF6366F1),
          isScrollable: MediaQuery.of(context).size.width < 400,
          tabs: [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Absensi'),
            Tab(icon: Icon(Icons.analytics, size: 18), text: 'Analitik'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            _buildAttendanceTab(),
            _buildAnalyticsTab(),
          ],
        ),
      ),
    );
  }
}
