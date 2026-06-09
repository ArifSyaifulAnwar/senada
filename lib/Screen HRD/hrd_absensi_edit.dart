// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Screen admin/service/admin_attendance_service.dart';
import '../Screen admin/service/hrd_attendance_service.dart';

class HrdAbsensiEditPage extends StatefulWidget {
  const HrdAbsensiEditPage({super.key});

  @override
  _HrdAbsensiEditPageState createState() => _HrdAbsensiEditPageState();
}

class _HrdAbsensiEditPageState extends State<HrdAbsensiEditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  bool _isLoading = false;
  String _error = '';
  String _search = '';
  String? _statusFilter;
  String? _startDate;
  String? _endDate;
  int _page = 1;
  int _totalPages = 1;
  final AdminAttendanceService _adminService = AdminAttendanceService();

  List<HrdWorkPeriod> _workPeriods = [];
  List<HrdAttendanceData> _attendanceList = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await _loadDefaultWorkPeriod();
    await _loadData(refresh: true);
  }

  Future<void> _loadDefaultWorkPeriod() async {
    try {
      final result = await _adminService.getCurrentWorkPeriod();

      if (!mounted) return;

      if (result.success && result.data != null) {
        final range = result.data!;

        setState(() {
          _startDate = DateFormat('yyyy-MM-dd').format(range.start);
          _endDate = DateFormat('yyyy-MM-dd').format(range.end);
        });
      } else {
        final now = DateTime.now();

        setState(() {
          _startDate = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime(now.year, now.month, 1));
          _endDate = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime(now.year, now.month + 1, 0));
        });
      }
    } catch (_) {
      final now = DateTime.now();

      if (!mounted) return;

      setState(() {
        _startDate = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month, 1));
        _endDate = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month + 1, 0));
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load data ─────────────────────────────────────────────────────────────

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _attendanceList.clear();
      });
    }
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final res = await HrdAttendanceService.getList(
      startDate: _startDate,
      endDate: _endDate,
      statusFilter: _statusFilter,
      searchTerm: _search.isNotEmpty ? _search : null,
      page: _page,
      pageSize: 50,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        if (refresh || _page == 1) {
          _attendanceList = res.data!.data;
        } else {
          _attendanceList.addAll(res.data!.data);
        }
        _totalPages = res.data!.totalPages;
      } else {
        _error = res.message;
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Edit Absensi Karyawan',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.refresh,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            onPressed: () => _loadData(refresh: true),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          tabs: const [
            Tab(
              icon: Icon(Icons.edit_calendar, size: 18),
              text: 'Data Absensi',
            ),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Log Perubahan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildAttendanceTab(), _buildLogTab()],
      ),
    );
  }

  // ── Tab 1: Data Absensi ───────────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    return Column(
      children: [
        // Filter bar
        _buildFilterBar(),
        // List
        Expanded(
          child: _isLoading && _attendanceList.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                )
              : _error.isNotEmpty && _attendanceList.isEmpty
              ? _buildError()
              : _attendanceList.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => _loadData(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _attendanceList.length + (_page < _totalPages ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= _attendanceList.length) {
                        return _buildLoadMore();
                      }
                      return _buildAttendanceCard(_attendanceList[i]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF64748B),
              ),
              suffixIcon: _search.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _search = '';
                          _searchCtrl.clear();
                        });
                        _loadData(refresh: true);
                      },
                      child: const Icon(Icons.clear, size: 16),
                    )
                  : null,
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
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() => _search = v);
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_searchCtrl.text == v) _loadData(refresh: true);
              });
            },
          ),
          const SizedBox(height: 8),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Semua', null),
                const SizedBox(width: 6),
                _filterChip('Tepat Waktu', 'Tepat Waktu'),
                const SizedBox(width: 6),
                _filterChip('Terlambat', 'Terlambat'),
                const SizedBox(width: 6),
                _filterChip('Cuti', 'Cuti'),
                const SizedBox(width: 6),
                _filterChip('Tidak Hadir', 'Tidak Hadir'),
                const SizedBox(width: 6),
                // Date filter
                GestureDetector(
                  onTap: _showDateFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (_startDate != null)
                          ? const Color(0xFF6366F1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: _startDate != null
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('dd/MM').format(DateTime.parse(_startDate!))} - ${DateFormat('dd/MM').format(DateTime.parse(_endDate!))}'
                              : 'Pilih Periode',
                          style: TextStyle(
                            fontSize: 11,
                            color: _startDate != null
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  Widget _filterChip(String label, String? value) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _loadData(refresh: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Attendance Card ───────────────────────────────────────────────────────

  Widget _buildAttendanceCard(HrdAttendanceData data) {
    final statusColor = _statusColor(data.displayStatus);

    return Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _statusIcon(data.displayStatus),
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                      Text(
                        '${data.employeeId ?? ''} ${data.department != null ? "• ${data.department}" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6366F1),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data.displayStatus,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Date + time row
            Row(
              children: [
                _infoChip(
                  Icons.calendar_today,
                  data.formattedDate,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _infoChip(Icons.login, data.formattedCheckIn, Colors.green),
                const SizedBox(width: 8),
                _infoChip(Icons.logout, data.formattedCheckOut, Colors.orange),
              ],
            ),
            if (data.workingHoursMinutes != null &&
                data.workingHoursMinutes! > 0) ...[
              const SizedBox(height: 6),
              _infoChip(
                Icons.schedule,
                '${(data.workingHoursMinutes! / 60).toStringAsFixed(1)} jam kerja',
                Colors.purple,
              ),
            ],
            const SizedBox(height: 10),
            // Edit button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showEditDialog(data),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text(
                  'Edit Jam Absensi',
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // ── Edit Dialog ───────────────────────────────────────────────────────────

  void _showEditDialog(HrdAttendanceData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAttendanceSheet(
        data: data,
        onRefresh: () => _loadData(refresh: true),
      ),
    );
  }

  // ── Tab 2: Log Perubahan ──────────────────────────────────────────────────

  Widget _buildLogTab() {
    return FutureBuilder(
      future: HrdAttendanceService.getEditLog(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }

        final res = snapshot.data;
        if (res == null ||
            !res.success ||
            res.data == null ||
            res.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text(
                  'Belum ada riwayat perubahan',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: res.data!.length,
          itemBuilder: (ctx, i) => _buildLogCard(res.data![i]),
        );
      },
    );
  }

  Widget _buildLogCard(HrdAttendanceEditLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header log
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Color(0xFF6366F1),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.employeeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Diedit oleh ${log.editedByName} • ${_formatLogDate(log.editedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Alasan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Alasan: ${log.editReason}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Perubahan check-in
            if (log.oldCheckInTime != log.newCheckInTime)
              _changeRow(
                'Jam Masuk',
                _formatTimeStr(log.oldCheckInTime),
                _formatTimeStr(log.newCheckInTime),
                Icons.login,
                Colors.green,
              ),
            // Perubahan check-out
            if (log.oldCheckOutTime != log.newCheckOutTime)
              _changeRow(
                'Jam Keluar',
                _formatTimeStr(log.oldCheckOutTime),
                _formatTimeStr(log.newCheckOutTime),
                Icons.logout,
                Colors.orange,
              ),
            // Perubahan status
            if (log.oldCheckInStatus != log.newCheckInStatus)
              _changeRow(
                'Status',
                log.oldCheckInStatus ?? '-',
                log.newCheckInStatus ?? '-',
                Icons.circle,
                Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _changeRow(
    String label,
    String oldVal,
    String newVal,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              oldVal,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              newVal,
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  // ── Date filter ───────────────────────────────────────────────────────────

  Future<void> _showDateFilter() async {
    final now = DateTime.now();

    final result = await _adminService.getWorkPeriodsByYear(tahun: now.year);

    if (!mounted) return;

    if (!result.success || result.data == null || result.data!.isEmpty) {
      _showSnackBar('Belum ada periode kerja yang disetting HRD.', true);
      return;
    }

    final periods = result.data!
      ..sort((a, b) {
        final tahunCompare = b.tahun.compareTo(a.tahun);
        if (tahunCompare != 0) return tahunCompare;
        return b.bulan.compareTo(a.bulan);
      });

    setState(() {
      _workPeriods = periods;
    });

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
                  itemCount: _workPeriods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _workPeriods[i];

                    final start = DateFormat(
                      'yyyy-MM-dd',
                    ).format(p.tanggalMulai);
                    final end = DateFormat(
                      'yyyy-MM-dd',
                    ).format(p.tanggalSelesai);

                    final selected = _startDate == start && _endDate == end;

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
                      onTap: () {
                        Navigator.pop(context);

                        setState(() {
                          _startDate = start;
                          _endDate = end;
                        });

                        _loadData(refresh: true);
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

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  // ── Load more ─────────────────────────────────────────────────────────────

  Widget _buildLoadMore() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton(
          onPressed: () {
            setState(() => _page++);
            _loadData();
          },
          child: const Text('Muat Lebih Banyak'),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(
          _error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _loadData(refresh: true),
          child: const Text('Coba Lagi'),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text(
          'Tidak ada data absensi',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    ),
  );

  Color _statusColor(String s) {
    if (s == 'Tepat Waktu') return Colors.green;
    if (s == 'Terlambat') return Colors.orange;
    if (s == 'Cuti') return Colors.blue;
    if (s == 'Tidak Hadir') return Colors.red;
    if (s == 'Sangat Terlambat') return Colors.red;
    return Colors.grey;
  }

  IconData _statusIcon(String s) {
    if (s == 'Tepat Waktu') return Icons.check_circle;
    if (s == 'Terlambat') return Icons.access_time;
    if (s == 'Cuti') return Icons.event_busy;
    if (s == 'Tidak Hadir') return Icons.cancel;
    if (s == 'Sangat Terlambat') return Icons.warning;
    return Icons.help;
  }

  String _formatLogDate(String dt) {
    try {
      final d = DateTime.parse(dt).toLocal();
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(d);
    } catch (_) {
      return dt;
    }
  }

  String _formatTimeStr(String? dt) {
    if (dt == null) return '-';
    try {
      return DateTime.parse(dt).toLocal().toString().substring(11, 16);
    } catch (_) {
      return '-';
    }
  }
}

// ── Edit Bottom Sheet ─────────────────────────────────────────────────────────
typedef EditAttendanceSaved =
    void Function({
      String? checkInTime,
      String? checkOutTime,
      String? checkInStatus,
      String? checkOutStatus,
      String? notes,
    });

class EditAttendanceSheet extends StatefulWidget {
  final HrdAttendanceData data;
  final EditAttendanceSaved? onSaved;
  final VoidCallback? onRefresh;

  const EditAttendanceSheet({
    super.key,
    required this.data,
    this.onSaved,
    this.onRefresh,
  });

  @override
  EditAttendanceSheetState createState() => EditAttendanceSheetState();
}

class EditAttendanceSheetState extends State<EditAttendanceSheet> {
  bool _isSaving = false;

  // Controllers
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Jam yang bisa diedit
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  String? _checkInStatus;
  String? _checkOutStatus;

  static const _statusOptions = [
    'Tepat Waktu',
    'Terlambat',
    'Sangat Terlambat',
    'Cuti',
    'Tidak Hadir',
    'Waktu Pulang',
  ];
  String? _safeDropdownValue(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) return null;

    return _statusOptions.contains(cleaned) ? cleaned : null;
  }

  @override
  void initState() {
    super.initState();

    _checkInTime = _parseTime(widget.data.checkInTime);
    _checkOutTime = _parseTime(widget.data.checkOutTime);

    _checkInStatus = _safeDropdownValue(widget.data.checkInStatus);
    _checkOutStatus = _safeDropdownValue(widget.data.checkOutStatus);

    _notesCtrl.text = widget.data.notes ?? '';
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? dt) {
    if (dt == null) return null;
    try {
      final d = DateTime.parse(dt).toLocal();
      return TimeOfDay(hour: d.hour, minute: d.minute);
    } catch (_) {
      return null;
    }
  }

  String _timeToDisplay(TimeOfDay? t) => t != null
      ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
      : '-';

  // Gabungkan tanggal absensi + TimeOfDay → ISO string
  String? _buildDateTime(TimeOfDay? time) {
    if (time == null) return null;
    try {
      final date = DateTime.parse(widget.data.attendanceDate!);
      return DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toIso8601String();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final initial = isCheckIn
        ? (_checkInTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (_checkOutTime ?? const TimeOfDay(hour: 17, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final newCheckInTime = _buildDateTime(_checkInTime);
    final newCheckOutTime = _buildDateTime(_checkOutTime);
    final newNotes = _notesCtrl.text.trim().isNotEmpty
        ? _notesCtrl.text.trim()
        : null;
    if (_reasonCtrl.text.trim().isEmpty) {
      _showSnack('Alasan perubahan wajib diisi!', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final res = await HrdAttendanceService.editAttendance(
      attendanceId: widget.data.id,
      editReason: _reasonCtrl.text.trim(),
      checkInTime: newCheckInTime,
      checkOutTime: newCheckOutTime,
      checkInStatus: _checkInStatus,
      checkOutStatus: _checkOutStatus,
      notes: newNotes,
    );

    setState(() => _isSaving = false);

    if (res.success) {
      _showSnack('Absensi berhasil diperbarui!', isError: false);
      await Future.delayed(const Duration(milliseconds: 400));
      Navigator.pop(context);
      widget.onSaved?.call(
        checkInTime: newCheckInTime,
        checkOutTime: newCheckOutTime,
        checkInStatus: _checkInStatus,
        checkOutStatus: _checkOutStatus,
        notes: newNotes,
      );

      widget.onRefresh?.call();
    } else {
      _showSnack(res.message, isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_calendar,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Absensi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${widget.data.userName} • ${widget.data.formattedDate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info current
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _currentInfo(
                    'Masuk Saat Ini',
                    widget.data.formattedCheckIn,
                    Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _currentInfo(
                    'Keluar Saat Ini',
                    widget.data.formattedCheckOut,
                    Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _currentInfo(
                      'Status',
                      widget.data.displayStatus,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Jam Masuk ────────────────────────────────────────────────────
            _sectionLabel('Jam Masuk Baru'),
            _timePicker(
              label: _timeToDisplay(_checkInTime),
              icon: Icons.login,
              color: Colors.green,
              onTap: () => _pickTime(true),
            ),
            const SizedBox(height: 12),

            // ── Jam Keluar ───────────────────────────────────────────────────
            _sectionLabel('Jam Keluar Baru'),
            _timePicker(
              label: _timeToDisplay(_checkOutTime),
              icon: Icons.logout,
              color: Colors.orange,
              onTap: () => _pickTime(false),
            ),
            const SizedBox(height: 12),

            // ── Status Check In ──────────────────────────────────────────────
            _sectionLabel('Status Check In'),
            DropdownButtonFormField<String>(
              value: _safeDropdownValue(_checkInStatus),
              hint: const Text('-- Pilih Status --'),
              onChanged: (v) => setState(() => _checkInStatus = v),
              decoration: _inputDeco(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              items: _statusOptions.map((s) {
                return DropdownMenuItem<String>(value: s, child: Text(s));
              }).toList(),
            ),
            const SizedBox(height: 12),

            // ── Status Check Out ─────────────────────────────────────────────
            _sectionLabel('Status Check Out'),
            DropdownButtonFormField<String>(
              value: _safeDropdownValue(_checkOutStatus),
              hint: const Text('-- Pilih Status --'),
              onChanged: (v) => setState(() => _checkOutStatus = v),
              decoration: _inputDeco(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              items: _statusOptions.map((s) {
                return DropdownMenuItem<String>(value: s, child: Text(s));
              }).toList(),
            ),
            const SizedBox(height: 12),

            // ── Catatan ──────────────────────────────────────────────────────
            _sectionLabel('Catatan (opsional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: _inputDeco(hint: 'Tambahkan catatan...'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            // ── Alasan (wajib) ───────────────────────────────────────────────
            Row(
              children: [
                _sectionLabel('Alasan Perubahan'),
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: _inputDeco(
                hint:
                    'Contoh: Gangguan jaringan saat check-in, koreksi data...',
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),

            // ── Save ─────────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _currentInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: label == '-'
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
            const Icon(Icons.access_time, size: 16, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
      borderSide: const BorderSide(color: Color(0xFF6366F1)),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
