// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/Services/attendance_service.dart';
import 'package:absensikaryawan/models/attendancemodel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HalamanRiwayatAbsensi extends StatefulWidget {
  const HalamanRiwayatAbsensi({super.key});

  @override
  _HalamanRiwayatAbsensiState createState() => _HalamanRiwayatAbsensiState();
}

class _HalamanRiwayatAbsensiState extends State<HalamanRiwayatAbsensi> {
  final AttendanceService _attendanceService = AttendanceService();

  bool isLoading = false;
  String errorMessage = '';
  String selectedTimeRange = '1 Tahun Terakhir';
  DateTimeRange? customDateRange;
  String selectedAbsensiType = 'Semua';

  List<AttendanceData> attendanceData = [];
  AttendanceStats? attendanceStats;
  int currentPage = 1;
  int totalPages = 1;
  bool hasMoreData = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadAttendanceHistory(refresh: true)]);
  }

  // Perbaiki fungsi _calculateDateRange
  Map<String, DateTime> _calculateDateRange(String timeRange) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // Set endDate ke akhir hari ini (23:59:59)
    endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (timeRange) {
      case '1 Hari':
        // PERBAIKAN: Untuk 1 hari, ambil dari awal hari ini sampai akhir hari ini
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case '7 Hari Terakhir':
        // 7 hari terakhir termasuk hari ini
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
          0,
          0,
          0,
        ).subtract(Duration(days: 6));
        break;
      case '30 Hari Terakhir':
        // 30 hari terakhir termasuk hari ini
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
          0,
          0,
          0,
        ).subtract(Duration(days: 29));
        break;
      case '1 Tahun Terakhir':
        // 1 tahun terakhir
        startDate = DateTime(now.year - 1, now.month, now.day, 0, 0, 0);
        break;
      default:
        // Default ke 1 tahun terakhir
        startDate = DateTime(now.year - 1, now.month, now.day, 0, 0, 0);
        break;
    }

    return {'startDate': startDate, 'endDate': endDate};
  }

  Future<void> _loadAttendanceHistory({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        isLoading = true;
        errorMessage = '';
        currentPage = 1;
        attendanceData.clear();
      });
    }

    try {
      String? timeRange = selectedTimeRange != 'Pilih Periode'
          ? selectedTimeRange
          : null;
      String? statusFilter = selectedAbsensiType != 'Semua'
          ? selectedAbsensiType
          : null;
      final response = await _attendanceService.getAttendanceHistory(
        timeRange: timeRange,
        startDate: customDateRange?.start,
        endDate: customDateRange?.end,
        statusFilter: statusFilter,
        page: currentPage,
        pageSize: 10000,
      );

      if (response.success && response.data != null) {
        List<AttendanceData> filteredData = response.data!.data;

        // PERBAIKAN: Client-side filtering yang lebih ketat
        // Filter berdasarkan tanggal jika backend tidak memfilter dengan benar
        if (timeRange != null || customDateRange != null) {
          DateTime? filterStartDate;
          DateTime? filterEndDate;

          if (customDateRange != null) {
            filterStartDate = DateTime(
              customDateRange!.start.year,
              customDateRange!.start.month,
              customDateRange!.start.day,
            );
            filterEndDate = DateTime(
              customDateRange!.end.year,
              customDateRange!.end.month,
              customDateRange!.end.day,
              23,
              59,
              59,
            );
          } else if (timeRange != null) {
            final dateRange = _calculateDateRange(timeRange);
            filterStartDate = dateRange['startDate'];
            filterEndDate = dateRange['endDate'];
          }

          if (filterStartDate != null && filterEndDate != null) {
            filteredData = filteredData.where((data) {
              final dataDate = DateTime(
                data.attendanceDate.year,
                data.attendanceDate.month,
                data.attendanceDate.day,
              );
              final startDate = DateTime(
                filterStartDate!.year,
                filterStartDate.month,
                filterStartDate.day,
              );
              final endDate = DateTime(
                filterEndDate!.year,
                filterEndDate.month,
                filterEndDate.day,
              );

              return dataDate.isAfter(startDate.subtract(Duration(days: 1))) &&
                  dataDate.isBefore(endDate.add(Duration(days: 1)));
            }).toList();
          }
        }

        // Filter berdasarkan status
        if (statusFilter != null) {
          filteredData = filteredData.where((data) {
            switch (statusFilter) {
              case 'Tepat Waktu':
                return data.status.toLowerCase().contains('tepat waktu') ||
                    data.checkInStatus.toLowerCase() == 'on_time';
              case 'Terlambat':
                return data.status.toLowerCase().contains('terlambat') ||
                    data.checkInStatus.toLowerCase() == 'late' ||
                    data.checkInStatus.toLowerCase() == 'very_late';
              case 'Cuti':
                return data.status.toLowerCase().contains('cuti') ||
                    data.checkInStatus.toLowerCase().contains('cuti');
              default:
                return true;
            }
          }).toList();
        }

        setState(() {
          if (refresh) {
            attendanceData = filteredData;
          } else {
            attendanceData.addAll(filteredData);
          }
          totalPages = response.data!.totalPages;
          hasMoreData = currentPage < totalPages;
          isLoading = false;
          errorMessage = '';
        });
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

    await _loadAttendanceHistory();
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  Future<void> _showDetailAbsensi(AttendanceData data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _attendanceService.getAttendanceDetail(data.id);
      Navigator.pop(context); // Close loading dialog

      if (response.success && response.data != null) {
        _showDetailBottomSheet(response.data!);
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('Gagal memuat detail absensi');
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

  void _showDetailBottomSheet(AttendanceData data) {
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
                      color: _getStatusColor(data.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getStatusIcon(data.status),
                      color: _getStatusColor(data.status),
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
                      color: _getStatusColor(data.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(data.status),
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
                    // _buildDetailItem(
                    //   'ID Absensi',
                    //   '#${data.id.toString().padLeft(4, '0')}',
                    //   Icons.badge,
                    //   Colors.blue,
                    // ),
                    if (data.status != 'Cuti') ...[
                      _buildDetailItem(
                        'Jam Masuk',
                        data.jamMasuk,
                        Icons.login,
                        Colors.green,
                      ),
                      _buildDetailItem(
                        'Jam Keluar',
                        data.jamKeluar,
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
                    _buildDetailItem(
                      'Lokasi',
                      data.lokasi,
                      Icons.location_on,
                      Colors.red,
                    ),
                    _buildDetailItem(
                      'Keterangan',
                      data.keterangan.isNotEmpty
                          ? data.keterangan
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

  // Tambahkan fungsi untuk menghitung stats dari data yang sudah difilter
  Map<String, int> _calculateFilteredStats(List<AttendanceData> filteredData) {
    int masukKantor = 0;
    int tepatWaktu = 0;
    int terlambat = 0;
    int cutiKaryawan = 0;

    for (var data in filteredData) {
      // Hitung berdasarkan status yang sudah difilter
      switch (data.status.toLowerCase()) {
        case 'tepat waktu':
          masukKantor++;
          tepatWaktu++;
          break;
        case 'terlambat':
          masukKantor++;
          terlambat++;
          break;
        case 'cuti':
          cutiKaryawan++;
          break;
      }

      // Alternatif berdasarkan checkInStatus
      if (data.checkInStatus.toLowerCase() == 'on_time') {
        if (!data.status.toLowerCase().contains('tepat waktu')) {
          masukKantor++;
          tepatWaktu++;
        }
      } else if (data.checkInStatus.toLowerCase().contains('late')) {
        if (!data.status.toLowerCase().contains('terlambat')) {
          masukKantor++;
          terlambat++;
        }
      }
    }

    return {
      'Masuk Kantor': masukKantor,
      'Tepat Waktu': tepatWaktu,
      'Terlambat': terlambat,
      'Cuti Karyawan': cutiKaryawan,
    };
  }

  // Ubah fungsi getAbsensiStats()
  Map<String, int> getAbsensiStats() {
    // PERBAIKAN: Hitung stats dari data yang sudah difilter, bukan dari API stats
    return _calculateFilteredStats(attendanceData);
  }

  String _formatDisplayDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
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

  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return baseFontSize * scale.clamp(0.85, 1.15);
  }

  double _getResponsivePadding(BuildContext context, double basePadding) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return basePadding * scale.clamp(0.85, 1.1);
  }

  double _getResponsiveIconSize(BuildContext context, double baseIconSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return baseIconSize * scale.clamp(0.85, 1.1);
  }

  Widget _buildInfoBox(
    String title,
    String value,
    Color borderColor,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor.withOpacity(0.6), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 13),
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
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

  Widget _buildAbsensiCard(AttendanceData data) {
    return GestureDetector(
      onTap: () => _showDetailAbsensi(data),
      child: Container(
        margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 12)),
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
        child: Padding(
          padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
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
                      color: _getStatusColor(data.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(data.status),
                      color: _getStatusColor(data.status),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: _getResponsivePadding(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTanggalFromDateTime(data.attendanceDate),
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 16),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _getResponsivePadding(context, 8),
                                vertical: _getResponsivePadding(context, 4),
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  data.status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                data.status,
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(context, 12),
                                  fontWeight: FontWeight.w500,
                                  color: _getStatusColor(data.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _getResponsivePadding(context, 8)),
                        if (data.status != 'Cuti') ...[
                          Row(
                            children: [
                              Icon(
                                Icons.login,
                                size: _getResponsiveIconSize(context, 16),
                                color: const Color(0xFF64748B),
                              ),
                              SizedBox(
                                width: _getResponsivePadding(context, 4),
                              ),
                              Text(
                                'Masuk: ${data.jamMasuk}',
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(context, 14),
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              SizedBox(
                                width: _getResponsivePadding(context, 16),
                              ),
                              Icon(
                                Icons.logout,
                                size: _getResponsiveIconSize(context, 16),
                                color: const Color(0xFF64748B),
                              ),
                              SizedBox(
                                width: _getResponsivePadding(context, 4),
                              ),
                              Text(
                                'Keluar: ${data.jamKeluar}',
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(context, 14),
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: _getResponsivePadding(context, 4)),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: _getResponsiveIconSize(context, 16),
                              color: const Color(0xFF64748B),
                            ),
                            SizedBox(width: _getResponsivePadding(context, 4)),
                            Expanded(
                              child: Text(
                                data.lokasi,
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(context, 14),
                                  color: const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _getResponsivePadding(context, 4)),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.keterangan.isNotEmpty
                                    ? data.keterangan
                                    : 'Tidak ada keterangan',
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(context, 14),
                                  color: const Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
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
            'Memuat riwayat absensi...',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: const Color(0xFF64748B),
            ),
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
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coba ubah filter atau periode waktu',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _refreshData, child: Text('Muat Ulang')),
        ],
      ),
    );
  }

  Widget _buildAbsensiList() {
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
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildAbsensiCard(attendanceData[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, int> stats = getAbsensiStats();

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Riwayat Absensi',
          style: TextStyle(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: _getResponsiveFontSize(context, 18),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: _getResponsivePadding(context, 16)),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(_getResponsivePadding(context, 8)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: const Color(0xFF3B82F6),
                  size: _getResponsiveIconSize(context, 20),
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                children: [
                  _buildInfoBox(
                    'Masuk Kantor',
                    '${stats['Masuk Kantor']}',
                    Colors.blue,
                    Colors.blue,
                  ),
                  _buildInfoBox(
                    'Tepat Waktu',
                    '${stats['Tepat Waktu']}',
                    Colors.green,
                    Colors.green,
                  ),
                  _buildInfoBox(
                    'Terlambat',
                    '${stats['Terlambat']}',
                    Colors.orange,
                    Colors.orange,
                  ),
                  _buildInfoBox(
                    'Cuti Karyawan',
                    '${stats['Cuti Karyawan']}',
                    Colors.red,
                    Colors.red,
                  ),
                ],
              ),
              SizedBox(height: _getResponsivePadding(context, 20)),

              // Header with absensi count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Riwayat Absensi',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 18),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _getResponsivePadding(context, 12),
                      vertical: _getResponsivePadding(context, 6),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${attendanceData.length} data',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: _getResponsivePadding(context, 20)),

              // Filter buttons
              Container(
                padding: EdgeInsets.all(_getResponsivePadding(context, 4)),
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
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showDateFilterSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _getResponsivePadding(context, 12),
                            vertical: _getResponsivePadding(context, 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: _getResponsiveIconSize(context, 16),
                                color: const Color(0xFF3B82F6),
                              ),
                              SizedBox(
                                width: _getResponsivePadding(context, 8),
                              ),
                              Flexible(
                                child: Text(
                                  selectedTimeRange == 'Pilih Periode' &&
                                          customDateRange != null
                                      ? '${customDateRange!.start.day}/${customDateRange!.start.month} - ${customDateRange!.end.day}/${customDateRange!.end.month}'
                                      : selectedTimeRange,
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(
                                      context,
                                      12,
                                    ),
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _showAbsensiTypeFilterSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _getResponsivePadding(context, 12),
                            vertical: _getResponsivePadding(context, 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_alt,
                                size: _getResponsiveIconSize(context, 16),
                                color: const Color(0xFF10B981),
                              ),
                              SizedBox(
                                width: _getResponsivePadding(context, 8),
                              ),
                              Flexible(
                                child: Text(
                                  selectedAbsensiType,
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(
                                      context,
                                      12,
                                    ),
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF10B981),
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: _getResponsivePadding(context, 24)),

              // Debug info untuk monitoring filter

              // Absensi List
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
                _buildAbsensiList(),
            ],
          ),
        ),
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
              ListTile(
                leading: Icon(Icons.today),
                title: Text('1 Hari'),
                onTap: () {
                  setState(() {
                    selectedTimeRange = '1 Hari';
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadInitialData();
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
                  _loadInitialData();
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
                  _loadInitialData();
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
                  _loadInitialData();
                },
                selected: selectedTimeRange == '1 Tahun Terakhir',
              ),
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Pilih Periode'),
                subtitle: customDateRange != null
                    ? Text(
                        '${_formatDisplayDate(customDateRange!.start)} - ${_formatDisplayDate(customDateRange!.end)}',
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
                    _loadInitialData();
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

  void _showAbsensiTypeFilterSheet() {
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
                  setState(() => selectedAbsensiType = 'Semua');
                  Navigator.pop(context);
                  _loadInitialData();
                },
                selected: selectedAbsensiType == 'Semua',
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Tepat Waktu'),
                onTap: () {
                  setState(() => selectedAbsensiType = 'Tepat Waktu');
                  Navigator.pop(context);
                  _loadInitialData();
                },
                selected: selectedAbsensiType == 'Tepat Waktu',
              ),
              ListTile(
                leading: Icon(Icons.access_time, color: Colors.orange),
                title: Text('Terlambat'),
                onTap: () {
                  setState(() => selectedAbsensiType = 'Terlambat');
                  Navigator.pop(context);
                  _loadInitialData();
                },
                selected: selectedAbsensiType == 'Terlambat',
              ),
              ListTile(
                leading: Icon(Icons.event_busy, color: Colors.red),
                title: Text('Cuti'),
                onTap: () {
                  setState(() => selectedAbsensiType = 'Cuti');
                  Navigator.pop(context);
                  _loadInitialData();
                },
                selected: selectedAbsensiType == 'Cuti',
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
