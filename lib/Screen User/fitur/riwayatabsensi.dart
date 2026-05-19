// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/Services/attendance_service.dart';
import 'package:absensikaryawan/models/attendancemodel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── helper ──────────────────────────────────────────────────────────
bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

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

  // Web: record yang dipilih untuk detail panel kanan
  AttendanceData? _selectedRecord;
  bool _isLoadingDetail = false;
  AttendanceData? _detailData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAttendanceHistory(refresh: true);
  }

  Map<String, DateTime> _calculateDateRange(String timeRange) {
    final now = DateTime.now();
    DateTime startDate;
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (timeRange) {
      case '1 Hari':
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case '7 Hari Terakhir':
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        break;
      case '30 Hari Terakhir':
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
        break;
      case '1 Tahun Terakhir':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year - 1, now.month, now.day);
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
      final timeRange = selectedTimeRange != 'Pilih Periode'
          ? selectedTimeRange
          : null;
      final statusFilter = selectedAbsensiType != 'Semua'
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

        // Client-side date filtering
        if (timeRange != null || customDateRange != null) {
          DateTime? filterStart;
          DateTime? filterEnd;

          if (customDateRange != null) {
            filterStart = DateTime(
              customDateRange!.start.year,
              customDateRange!.start.month,
              customDateRange!.start.day,
            );
            filterEnd = DateTime(
              customDateRange!.end.year,
              customDateRange!.end.month,
              customDateRange!.end.day,
              23,
              59,
              59,
            );
          } else if (timeRange != null) {
            final dr = _calculateDateRange(timeRange);
            filterStart = dr['startDate'];
            filterEnd = dr['endDate'];
          }

          if (filterStart != null && filterEnd != null) {
            filteredData = filteredData.where((d) {
              final dd = DateTime(
                d.attendanceDate.year,
                d.attendanceDate.month,
                d.attendanceDate.day,
              );
              final fs = DateTime(
                filterStart!.year,
                filterStart.month,
                filterStart.day,
              );
              final fe = DateTime(
                filterEnd!.year,
                filterEnd.month,
                filterEnd.day,
              );
              return dd.isAfter(fs.subtract(const Duration(days: 1))) &&
                  dd.isBefore(fe.add(const Duration(days: 1)));
            }).toList();
          }
        }

        // Status filter
        if (statusFilter != null) {
          filteredData = filteredData.where((d) {
            switch (statusFilter) {
              case 'Tepat Waktu':
                return d.status.toLowerCase().contains('tepat waktu') ||
                    d.checkInStatus.toLowerCase() == 'on_time';
              case 'Terlambat':
                return d.status.toLowerCase().contains('terlambat') ||
                    d.checkInStatus.toLowerCase() == 'late' ||
                    d.checkInStatus.toLowerCase() == 'very_late';
              case 'Cuti':
                return d.status.toLowerCase().contains('cuti') ||
                    d.checkInStatus.toLowerCase().contains('cuti');
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
    setState(() => currentPage++);
    await _loadAttendanceHistory();
  }

  Future<void> _refreshData() async {
    setState(() {
      _selectedRecord = null;
      _detailData = null;
    });
    await _loadInitialData();
  }

  // ── Load detail dan tampilkan: mobile = bottom sheet, web = panel kanan
  Future<void> _showDetailAbsensi(AttendanceData data) async {
    final isWeb = _isWideScreen(context);

    if (isWeb) {
      // Web: load detail ke panel kanan
      setState(() {
        _selectedRecord = data;
        _isLoadingDetail = true;
        _detailData = null;
      });
      try {
        final response = await _attendanceService.getAttendanceDetail(data.id);
        if (mounted) {
          setState(() {
            _detailData = response.success && response.data != null
                ? response.data
                : data;
            _isLoadingDetail = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _detailData = data;
            _isLoadingDetail = false;
          });
        }
      }
    } else {
      // Mobile: bottom sheet seperti asli
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final response = await _attendanceService.getAttendanceDetail(data.id);
        Navigator.pop(context);
        if (response.success && response.data != null) {
          _showDetailBottomSheet(response.data!);
        } else {
          _showErrorSnackBar(response.message);
        }
      } catch (_) {
        Navigator.pop(context);
        _showErrorSnackBar('Gagal memuat detail absensi');
      }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),
              _buildDetailHeader(data),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: _buildDetailItems(data),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
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

  Map<String, int> _calculateFilteredStats(List<AttendanceData> data) {
    int masuk = 0, tepat = 0, terlambat = 0, cuti = 0;
    for (var d in data) {
      switch (d.status.toLowerCase()) {
        case 'tepat waktu':
          masuk++;
          tepat++;
          break;
        case 'terlambat':
          masuk++;
          terlambat++;
          break;
        case 'cuti':
          cuti++;
          break;
      }
      if (d.checkInStatus.toLowerCase() == 'on_time' &&
          !d.status.toLowerCase().contains('tepat waktu')) {
        masuk++;
        tepat++;
      } else if (d.checkInStatus.toLowerCase().contains('late') &&
          !d.status.toLowerCase().contains('terlambat')) {
        masuk++;
        terlambat++;
      }
    }
    return {
      'Masuk Kantor': masuk,
      'Tepat Waktu': tepat,
      'Terlambat': terlambat,
      'Cuti Karyawan': cuti,
    };
  }

  Map<String, int> getAbsensiStats() => _calculateFilteredStats(attendanceData);

  String _formatDisplayDate(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  String _formatTanggal(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return date.toString().split(' ')[0];
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('tepat waktu') || s == 'on_time') return Colors.green;
    if (s.contains('terlambat') || s == 'late' || s == 'very_late') {
      return Colors.orange;
    }
    if (s.contains('cuti') || s == 'leave') return Colors.red;
    if (s.contains('absent') || s.contains('tidak hadir')) return Colors.red;
    return Colors.grey;
  }

  IconData _getStatusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('tepat waktu') || s == 'on_time') return Icons.check_circle;
    if (s.contains('terlambat') || s == 'late' || s == 'very_late') {
      return Icons.access_time;
    }
    if (s.contains('cuti') || s == 'leave') return Icons.event_busy;
    if (s.contains('absent') || s.contains('tidak hadir')) return Icons.cancel;
    return Icons.help;
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWeb = _isWideScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Riwayat Absensi',
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
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            onPressed: _refreshData,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (layout asli)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final stats = getAbsensiStats();
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(stats, crossAxis: 2, ratio: 1.3),
            const SizedBox(height: 20),
            _buildListHeader(),
            const SizedBox(height: 20),
            _buildFilterRow(),
            const SizedBox(height: 24),
            _buildListContent(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB LAYOUT (filter sidebar kiri | list tengah | detail kanan)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    final stats = getAbsensiStats();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Kolom kiri: Stats + Filter ─────────────────────
        SizedBox(
          width: 220,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats 2x2
                  _buildWebStats(stats),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Filter periode
                  _buildWebFilterPanel(),
                ],
              ),
            ),
          ),
        ),

        // ── Kolom tengah: List absensi ──────────────────────
        SizedBox(
          width: 380,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // Header + jumlah
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  color: const Color(0xFFF8FAFC),
                  child: _buildListHeader(),
                ),
                // List
                Expanded(
                  child: isLoading && attendanceData.isEmpty
                      ? _buildLoadingWidget()
                      : errorMessage.isNotEmpty && attendanceData.isEmpty
                      ? _buildErrorWidget()
                      : attendanceData.isEmpty
                      ? _buildEmptyStateWidget()
                      : NotificationListener<ScrollNotification>(
                          onNotification: (s) {
                            if (!isLoading &&
                                hasMoreData &&
                                s.metrics.pixels == s.metrics.maxScrollExtent) {
                              _loadMoreData();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount:
                                attendanceData.length + (hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= attendanceData.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final item = attendanceData[index];
                              final isSelected = _selectedRecord?.id == item.id;
                              return _buildAbsensiCardWeb(item, isSelected);
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        // ── Kolom kanan: Detail ─────────────────────────────
        Expanded(
          child: _selectedRecord == null
              ? _buildWebDetailEmpty()
              : _isLoadingDetail
              ? const Center(child: CircularProgressIndicator())
              : _buildWebDetailPanel(_detailData ?? _selectedRecord!),
        ),
      ],
    );
  }

  // ── Stats di sidebar web ──────────────────────────────
  Widget _buildWebStats(Map<String, int> stats) {
    final items = [
      {
        'label': 'Masuk Kantor',
        'value': stats['Masuk Kantor'],
        'color': Colors.blue,
      },
      {
        'label': 'Tepat Waktu',
        'value': stats['Tepat Waktu'],
        'color': Colors.green,
      },
      {
        'label': 'Terlambat',
        'value': stats['Terlambat'],
        'color': Colors.orange,
      },
      {'label': 'Cuti', 'value': stats['Cuti Karyawan'], 'color': Colors.red},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        // Pakai list vertikal, bukan grid — lebih aman di sidebar sempit
        ...items.map((item) {
          final color = item['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['label'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                Text(
                  '${item['value']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Filter panel sidebar web ──────────────────────────
  Widget _buildWebFilterPanel() {
    final timeRanges = [
      '1 Hari',
      '7 Hari Terakhir',
      '30 Hari Terakhir',
      '1 Tahun Terakhir',
    ];
    final statusFilters = ['Semua', 'Tepat Waktu', 'Terlambat', 'Cuti'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Periode',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        ...timeRanges.map((range) {
          final isSelected =
              selectedTimeRange == range && customDateRange == null;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedTimeRange = range;
                customDateRange = null;
              });
              _loadInitialData();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3B82F6).withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    range,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        // Custom date range
        GestureDetector(
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
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: customDateRange != null
                  ? const Color(0xFF3B82F6).withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  customDateRange != null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: customDateRange != null
                      ? const Color(0xFF3B82F6)
                      : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customDateRange != null
                        ? '${_formatDisplayDate(customDateRange!.start)} - ${_formatDisplayDate(customDateRange!.end)}'
                        : 'Pilih Periode',
                    style: TextStyle(
                      fontSize: 12,
                      color: customDateRange != null
                          ? const Color(0xFF3B82F6)
                          : Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 12),

        const Text(
          'Status',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: statusFilters.map((s) {
            final isSelected = selectedAbsensiType == s;
            return GestureDetector(
              onTap: () {
                setState(() => selectedAbsensiType = s);
                _loadInitialData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Card absensi versi web (compact) ─────────────────
  Widget _buildAbsensiCardWeb(AttendanceData data, bool isSelected) {
    return GestureDetector(
      onTap: () => _showDetailAbsensi(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6).withOpacity(0.3)
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _getStatusColor(data.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getStatusIcon(data.status),
                color: _getStatusColor(data.status),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTanggal(data.attendanceDate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.status != 'Cuti'
                        ? '${data.jamMasuk} – ${data.jamKeluar}'
                        : 'Cuti',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(data.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(data.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Placeholder detail kosong (web) ──────────────────
  Widget _buildWebDetailEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 36,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pilih catatan absensi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Klik baris di kiri untuk\nmelihat detail',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Detail panel web ──────────────────────────────────
  Widget _buildWebDetailPanel(AttendanceData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailHeader(data),
          const SizedBox(height: 20),
          ..._buildDetailItems(data),
        ],
      ),
    );
  }

  // ── Header detail (shared mobile + web) ──────────────
  Widget _buildDetailHeader(AttendanceData data) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _getStatusColor(data.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _getStatusIcon(data.status),
            color: _getStatusColor(data.status),
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detail Absensi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                _formatTanggal(data.attendanceDate),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  // ── Item detail (shared) ──────────────────────────────
  List<Widget> _buildDetailItems(AttendanceData data) {
    final items = <Widget>[];

    void add(String label, String value, IconData icon, Color color) {
      items.add(_buildDetailItem(label, value, icon, color));
    }

    if (data.status != 'Cuti') {
      add('Jam Masuk', data.jamMasuk, Icons.login, Colors.green);
      add('Jam Keluar', data.jamKeluar, Icons.logout, Colors.orange);
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
    add('Lokasi', data.lokasi, Icons.location_on, Colors.red);
    add(
      'Keterangan',
      data.keterangan.isNotEmpty ? data.keterangan : 'Tidak ada keterangan',
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
    return items;
  }

  // ─────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(
    Map<String, int> stats, {
    required int crossAxis,
    required double ratio,
  }) {
    final items = [
      {
        'title': 'Masuk Kantor',
        'value': '${stats['Masuk Kantor']}',
        'border': Colors.blue,
        'val': Colors.blue,
      },
      {
        'title': 'Tepat Waktu',
        'value': '${stats['Tepat Waktu']}',
        'border': Colors.green,
        'val': Colors.green,
      },
      {
        'title': 'Terlambat',
        'value': '${stats['Terlambat']}',
        'border': Colors.orange,
        'val': Colors.orange,
      },
      {
        'title': 'Cuti Karyawan',
        'value': '${stats['Cuti Karyawan']}',
        'border': Colors.red,
        'val': Colors.red,
      },
    ];
    return GridView.count(
      crossAxisCount: crossAxis,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: ratio,
      children: items
          .map(
            (i) => _buildInfoBox(
              i['title'] as String,
              i['value'] as String,
              i['border'] as Color,
              i['val'] as Color,
            ),
          )
          .toList(),
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Riwayat Absensi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(4),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        selectedTimeRange == 'Pilih Periode' &&
                                customDateRange != null
                            ? '${customDateRange!.start.day}/${customDateRange!.start.month} - ${customDateRange!.end.day}/${customDateRange!.end.month}'
                            : selectedTimeRange,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3B82F6),
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
          Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: InkWell(
              onTap: _showAbsensiTypeFilterSheet,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.filter_alt,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        selectedAbsensiType,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF10B981),
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
    );
  }

  Widget _buildListContent() {
    if (isLoading && attendanceData.isEmpty) return _buildLoadingWidget();
    if (errorMessage.isNotEmpty && attendanceData.isEmpty) {
      return _buildErrorWidget();
    }
    if (attendanceData.isEmpty) return _buildEmptyStateWidget();
    return _buildAbsensiList();
  }

  Widget _buildAbsensiList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (s) {
        if (!isLoading &&
            hasMoreData &&
            s.metrics.pixels == s.metrics.maxScrollExtent) {
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
          return _buildAbsensiCard(attendanceData[index]);
        },
      ),
    );
  }

  Widget _buildAbsensiCard(AttendanceData data) {
    return GestureDetector(
      onTap: () => _showDetailAbsensi(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          padding: const EdgeInsets.all(16),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTanggal(data.attendanceDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _getStatusColor(data.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (data.status != 'Cuti')
                          Row(
                            children: [
                              const Icon(
                                Icons.login,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Masuk: ${data.jamMasuk}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(
                                Icons.logout,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Keluar: ${data.jamKeluar}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                data.lokasi,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.keterangan.isNotEmpty
                                    ? data.keterangan
                                    : 'Tidak ada keterangan',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
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

  Widget _buildInfoBox(
    String title,
    String value,
    Color borderColor,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.black),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
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

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
          SizedBox(height: 16),
          Text(
            'Memuat riwayat absensi...',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
  }

  Widget _buildEmptyStateWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada data absensi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coba ubah filter atau periode waktu',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Muat Ulang'),
          ),
        ],
      ),
    );
  }

  // ─── Bottom sheet filter (mobile) ────────────────────
  void _showDateFilterSheet() {
    showModalBottomSheet(
      context: context,
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
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final range in [
              '1 Hari',
              '7 Hari Terakhir',
              '30 Hari Terakhir',
              '1 Tahun Terakhir',
            ])
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(range),
                selected: selectedTimeRange == range,
                onTap: () {
                  setState(() {
                    selectedTimeRange = range;
                    customDateRange = null;
                  });
                  Navigator.pop(context);
                  _loadInitialData();
                },
              ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Pilih Periode'),
              subtitle: customDateRange != null
                  ? Text(
                      '${_formatDisplayDate(customDateRange!.start)} - ${_formatDisplayDate(customDateRange!.end)}',
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
                  _loadInitialData();
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

  void _showAbsensiTypeFilterSheet() {
    showModalBottomSheet(
      context: context,
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
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final entry in [
              ['Semua', Icons.all_inclusive, Colors.blue],
              ['Tepat Waktu', Icons.check_circle, Colors.green],
              ['Terlambat', Icons.access_time, Colors.orange],
              ['Cuti', Icons.event_busy, Colors.red],
            ])
              ListTile(
                leading: Icon(entry[1] as IconData, color: entry[2] as Color),
                title: Text(entry[0] as String),
                selected: selectedAbsensiType == entry[0],
                onTap: () {
                  setState(() => selectedAbsensiType = entry[0] as String);
                  Navigator.pop(context);
                  _loadInitialData();
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
