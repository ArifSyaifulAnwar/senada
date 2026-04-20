// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../model/admin_attendance_model.dart';
import '../service/admin_attendance_service.dart';

class HalamanAdminAbsensi extends StatefulWidget {
  const HalamanAdminAbsensi({super.key});

  @override
  _HalamanAdminAbsensiState createState() => _HalamanAdminAbsensiState();
}

class _HalamanAdminAbsensiState extends State<HalamanAdminAbsensi> {
  final AdminAttendanceService _adminService = AdminAttendanceService();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = false;
  String errorMessage = '';
  String selectedTimeRange = 'Semua Data'; // UBAH: Default ke semua data
  DateTimeRange? customDateRange;
  String selectedStatusFilter = 'Semua';
  Employee? selectedEmployee;
  Office? selectedOffice;
  String searchTerm = '';

  List<AdminAttendanceData> attendanceData = [];
  AdminAttendanceStats? stats;
  List<Employee> employees = [];
  List<Office> offices = [];

  int currentPage = 1;
  int totalPages = 1;
  bool hasMoreData = false;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadEmployees(),
      _loadOffices(),
      _loadAttendanceData(refresh: true),
      _loadDashboardStats(),
    ]);
  }

  Future<void> _loadEmployees() async {
    try {
      final response = await _adminService.getEmployees();
      if (response.data != null) {}

      if (response.success) {
        setState(() {
          employees = response.data ?? [];
        });
      } else {
        setState(() {
          employees = [];
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

      if (response.data != null) {
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No offices found')));
      }

      if (response.success) {
        setState(() {
          offices = response.data ?? [];
        });
      } else {
        setState(() {
          offices = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading offices: ${response.message}')),
        );
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
        timeRangeToSend =
            null; // Jangan kirim time range jika pakai custom date
      } else if (selectedTimeRange != 'Semua Data') {
        timeRangeToSend = selectedTimeRange;
      } else {
        timeRangeToSend = null; // Kirim null jika semua data
      }
      final response = await _adminService.getDashboardStats(
        timeRange: timeRangeToSend,
        startDate: startDateToSend,
        endDate: endDateToSend,
      );

      if (response.data != null) {}

      if (response.success) {
        setState(() {
          stats = response.data ?? AdminAttendanceStats();
        });
      } else {
        setState(() {
          stats = AdminAttendanceStats(); // Set default stats on error
        });

        if (response.error != null) {}
      }
    } catch (e) {
      setState(() {
        stats = AdminAttendanceStats(); // Set default stats on exception
      });
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
      // PERBAIKAN: Sama seperti dashboard stats, hanya kirim filter jika diperlukan
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

      if (response.data != null) {}
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
        if (attendanceData.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Tidak ada data absensi')));
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = response.message;
        });
        if (response.error != null) {}
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

      final response = await _adminService.exportAttendanceData(
        filterUserId: selectedEmployee?.userId,
        timeRange: timeRangeToSend,
        startDate: startDateToSend,
        endDate: endDateToSend,
        statusFilter: statusFilter,
        officeId: selectedOffice?.id,
        searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
      );

      if (response.success && response.data != null) {
        // Copy CSV data to clipboard
        await Clipboard.setData(ClipboardData(text: response.data!));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data CSV berhasil disalin ke clipboard'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(response.message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal mengekspor data: ${e.toString()}');
      }
    } finally {
      setState(() {
        isExporting = false;
      });
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
    setState(() {
      searchTerm = value;
    });
    _loadAttendanceData(refresh: true);
  }

  Future<void> _showDetailAbsensi(AdminAttendanceData data) async {
    _showDetailBottomSheet(data);
  }

  void _showDetailBottomSheet(AdminAttendanceData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Header
              Row(
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
                          'Detail Absensi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _formatTanggalFromDateTime(data.attendanceDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        color: _getStatusColor(data.displayStatus),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Detail informasi
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailItem(
                      'ID Absensi',
                      '#${data.id.toString().padLeft(4, '0')}',
                      Icons.badge,
                      Colors.blue,
                    ),
                    _buildDetailItem(
                      'Nama Karyawan',
                      data.userName,
                      Icons.person,
                      Colors.purple,
                    ),
                    if (data.employeeId != null)
                      _buildDetailItem(
                        'ID Karyawan',
                        data.employeeId!,
                        Icons.badge_outlined,
                        Colors.indigo,
                      ),
                    if (data.department != null)
                      _buildDetailItem(
                        'Departemen',
                        data.department!,
                        Icons.business,
                        Colors.teal,
                      ),
                    if (data.displayStatus != 'Cuti') ...[
                      _buildDetailItem(
                        'Jam Masuk',
                        data.formattedCheckIn,
                        Icons.login,
                        Colors.green,
                      ),
                      _buildDetailItem(
                        'Jam Keluar',
                        data.formattedCheckOut,
                        Icons.logout,
                        Colors.orange,
                      ),
                    ],
                    _buildDetailItem(
                      'Status Check In',
                      data.checkInStatus.isNotEmpty
                          ? data.checkInStatus
                          : 'Tidak ada data',
                      _getStatusIcon(data.checkInStatus),
                      _getStatusColor(data.checkInStatus),
                    ),
                    if (data.checkOutStatus.isNotEmpty)
                      _buildDetailItem(
                        'Status Check Out',
                        data.checkOutStatus,
                        _getStatusIcon(data.checkOutStatus),
                        _getStatusColor(data.checkOutStatus),
                      ),
                    if (data.checkInOfficeName != null)
                      _buildDetailItem(
                        'Kantor',
                        data.checkInOfficeName!,
                        Icons.location_city,
                        Colors.red,
                      ),
                    _buildDetailItem(
                      'Keterangan',
                      data.notes.isNotEmpty
                          ? data.notes
                          : 'Tidak ada keterangan',
                      Icons.info,
                      Colors.purple,
                    ),
                    if (data.workingHoursMinutes != null)
                      _buildDetailItem(
                        'Jam Kerja',
                        '${(data.workingHoursMinutes! / 60).toStringAsFixed(1)} jam',
                        Icons.schedule,
                        Colors.indigo,
                      ),
                    if (data.overtimeMinutes != null &&
                        data.overtimeMinutes! > 0)
                      _buildDetailItem(
                        'Lembur',
                        '${(data.overtimeMinutes! / 60).toStringAsFixed(1)} jam',
                        Icons.access_time_filled,
                        Colors.amber,
                      ),
                    if (data.checkInFaceConfidence != null)
                      _buildDetailItem(
                        'Confidence Check In',
                        '${(data.checkInFaceConfidence! * 100).toStringAsFixed(1)}%',
                        Icons.face,
                        Colors.blue,
                      ),
                  ],
                ),
              ),

              SizedBox(height: 20),
              // Tombol close
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
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
            ],
          ),
        ),
      ),
    );
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
      return Colors.red;
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

  Widget _buildStatsGrid() {
    // Always show stats, even if null or loading
    final currentStats = stats ?? AdminAttendanceStats();
    final statsMap = currentStats.toMap();
    final statsList = statsMap.entries.toList();

    if (isLoading && attendanceData.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat statistik...'),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: statsList.length,
      itemBuilder: (context, index) {
        final entry = statsList[index];
        return _buildStatsCard(
          entry.key,
          entry.value.toString(),
          _getStatsColor(index),
        );
      },
    );
  }

  Widget _buildStatsCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatsColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  Widget _buildAttendanceCard(AdminAttendanceData data) {
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                data.userName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _getStatusColor(data.displayStatus),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        if (data.employeeId != null)
                          Text(
                            'ID: ${data.employeeId} • ${data.department ?? ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        SizedBox(height: 4),
                        Text(
                          _formatTanggalFromDateTime(data.attendanceDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 8),
                        if (data.displayStatus != 'Cuti') ...[
                          Row(
                            children: [
                              Icon(
                                Icons.login,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Masuk: ${data.formattedCheckIn}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              SizedBox(width: 16),
                              Icon(
                                Icons.logout,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Keluar: ${data.formattedCheckOut}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                        ],
                        if (data.checkInOfficeName != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.location_city,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data.checkInOfficeName!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.notes.isNotEmpty
                                    ? data.notes
                                    : 'Tidak ada keterangan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
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
              Text(
                'Filter Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
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
            ),
            onChanged: (value) {
              // Debounce search
              Future.delayed(Duration(milliseconds: 500), () {
                if (_searchController.text == value) {
                  _performSearch(value);
                }
              });
            },
          ),

          SizedBox(height: 16),

          // Filter buttons row
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
                  'Kantor',
                  selectedOffice?.officeName ?? 'Semua Kantor',
                  Icons.location_city,
                  Color(0xFFEF4444),
                  _showOfficeFilterSheet,
                ),
              ),
            ],
          ),
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
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
          SizedBox(height: 16),
          Text(
            'Memuat data absensi...',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWidget() {
    return Center(
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
          ),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _refreshData, child: Text('Muat Ulang')),
        ],
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
              // PERBAIKAN: Tambahkan opsi 'Semua Data'
              ListTile(
                leading: Icon(Icons.all_inbox),
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
                leading: Icon(Icons.today),
                title: Text('1 Hari'),
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
                leading: Icon(Icons.date_range),
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
                leading: Icon(Icons.date_range),
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
                leading: Icon(Icons.date_range),
                title: Text('1 Tahun Terakhir'),
                onTap: () {
                  setState(() {
                    selectedTimeRange = '1 Tahun Terakhir';
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadAttendanceData(refresh: true);
                  _loadDashboardStats();
                },
                selected: selectedTimeRange == '1 Tahun Terakhir',
              ),
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Pilih Periode'),
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
                leading: Icon(Icons.event_busy, color: Colors.red),
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

  void _showOfficeFilterSheet() {
    showModalBottomSheet(
      context: context,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Admin - Data Absensi',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
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
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              onPressed: _refreshData,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Stats
              Text(
                'Dashboard Statistik',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 16),
              _buildStatsGrid(),

              SizedBox(height: 24),

              // Filter Section
              _buildFilterSection(),

              SizedBox(height: 24),

              // Header with data count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Data Absensi Karyawan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.5,
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

              // Attendance List
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
            ],
          ),
        ),
      ),
    );
  }
}
