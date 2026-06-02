// Screen HRD/Home/timeoffhrd.dart — FULL REPLACE
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:absensikaryawan/Services/web_download.dart';
import 'package:absensikaryawan/Screen%20admin/model/timeoffmodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/timeoffserviceadmin.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isWebLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class TimeOffHRDScreen extends StatefulWidget {
  const TimeOffHRDScreen({super.key});

  @override
  _TimeOffHRDScreenState createState() => _TimeOffHRDScreenState();
}

class _TimeOffHRDScreenState extends State<TimeOffHRDScreen>
    with SingleTickerProviderStateMixin {
  List<AdminTimeOffData> _allTimeOffs = [];
  List<AdminTimeOffData> _filteredTimeOffs = [];
  List<UserWithTimeOffs> _users = [];
  TimeOffAdminStatistics? _statistics;
  double _annualLeaveQuota = 21;
  double _maxConsecutiveLeaveDays = 12;
  bool _requireAttachmentForSickLeave = true;
  bool _allowBackdateRequest = false;
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _selectedStatus;
  String? _selectedUserId;
  String? _selectedDepartment;
  String? _selectedTimeRange = 'Bulan Ini';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _webTabIndex = 0;

  final Map<String, int> _departmentStats = {};
  final Map<String, double> _leaveBalances = {};

  final List<String> _departments = [
    'Semua Departemen',
    'IT',
    'HR',
    'Finance',
    'Marketing',
    'Operations',
  ];
  final List<String> _statusOptions = [
    'Semua Status',
    'Pending',
    'Approved',
    'Rejected',
    'Processed',
  ];
  final List<String> _timeRangeOptions = [
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
    'Tahun Ini',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _webTabIndex = _tabController.index);
    });
    _loadUserData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _fs(double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return base - 2;
    if (w < 400) return base - 1;
    if (w > 600) return base + 1;
    return base;
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('UserID');
      _currentUserName = prefs.getString('Name');
      if (_currentUserId != null && _currentUserName != null) {
        await _loadAllData();
      } else {
        setState(() => _isLoading = false);
        _snackErr('Data user tidak ditemukan. Silakan login ulang.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _snackErr('Gagal memuat data user: $e');
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final futures =
          await Future.wait([
            TimeOffAdminService.getAllTimeOffs(adminId: _currentUserId!),
            TimeOffAdminService.getUsersWithTimeOffs(adminId: _currentUserId!),
            TimeOffAdminService.getAdminStatistics(),
          ]).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout.'),
          );

      setState(() {
        _allTimeOffs =
            (futures[0] as ApiResponse<List<AdminTimeOffData>>).data ?? [];
        _users = (futures[1] as ApiResponse<List<UserWithTimeOffs>>).data ?? [];
        _statistics = (futures[2] as ApiResponse<TimeOffAdminStatistics>).data;
        _calculateDepartmentStats();
        _calculateLeaveBalances();
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _snackErr('Gagal memuat data: $e');
    }
  }

  void _calculateDepartmentStats() {
    _departmentStats.clear();
    for (var u in _users) {
      final d = u.department ?? 'Unknown';
      _departmentStats[d] = (_departmentStats[d] ?? 0) + u.totalTimeOff;
    }
  }

  void _calculateLeaveBalances() {
    _leaveBalances.clear();
    for (var u in _users) {
      _leaveBalances[u.userId] = 21.0 - u.totalApprovedDays.toDouble();
    }
  }

  void _applyFilters() {
    List<AdminTimeOffData> f = _allTimeOffs;
    if (_selectedStatus != null && _selectedStatus != 'Semua Status') {
      f = f.where((i) => i.status == _selectedStatus).toList();
    }
    if (_selectedUserId != null) {
      f = f.where((i) => i.userId == _selectedUserId).toList();
    }
    if (_selectedDepartment != null &&
        _selectedDepartment != 'Semua Departemen') {
      final ids = _users
          .where((u) => u.department == _selectedDepartment)
          .map((u) => u.userId)
          .toList();
      f = f.where((i) => ids.contains(i.userId)).toList();
    }
    if (_selectedTimeRange != null) {
      final now = DateTime.now();
      DateTime start;
      switch (_selectedTimeRange) {
        case 'Hari Ini':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'Minggu Ini':
          start = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'Tahun Ini':
          start = DateTime(now.year, 1, 1);
          break;
        default:
          start = DateTime(now.year, now.month, 1);
      }
      f = f.where((i) => i.submittedAt.isAfter(start)).toList();
    }
    final kw = _searchController.text.toLowerCase();
    if (kw.isNotEmpty) {
      f = f
          .where(
            (i) =>
                i.jenisTimeOff.toLowerCase().contains(kw) ||
                i.userName.toLowerCase().contains(kw) ||
                (i.catatan?.toLowerCase().contains(kw) ?? false),
          )
          .toList();
    }

    f.sort((a, b) {
      if (a.status == 'Pending' && b.status != 'Pending') return -1;
      if (a.status != 'Pending' && b.status == 'Pending') return 1;
      if (a.status == 'Pending' && b.status == 'Pending') {
        return b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted);
      }
      return b.submittedAt.compareTo(a.submittedAt);
    });

    setState(() => _filteredTimeOffs = f);
  }

  Future<void> _refreshData() async {
    await _loadAllData();
    _snackOk('Data berhasil diperbarui');
  }

  void _snackOk(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ),
  );

  void _snackErr(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );

  void _showTimeOffDetail(AdminTimeOffData item) {
    if (_currentUserId == null || _currentUserName == null) {
      _snackErr('Data user belum dimuat.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HRDTimeOffDetailModal(
        item: item,
        currentHRDId: _currentUserId!,
        currentHRDName: _currentUserName!,
        onActionCompleted: _refreshData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isWeb),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat data HRD...',
                    style: TextStyle(
                      fontSize: _fs(16),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : _currentUserId == null || _currentUserName == null
          ? _buildErrorState()
          : isWeb
          ? _buildWebLayout()
          : _buildMobileLayout(),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isWeb) => AppBar(
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
            Icons.business_center,
            color: Color(0xFF6366F1),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Manajemen Izin Karyawan',
            style: TextStyle(
              fontSize: _fs(isWeb ? 20 : 17),
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    centerTitle: !isWeb,
    elevation: 0,
    backgroundColor: Colors.white,
    leading: Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    actions: [
      Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black87, size: 18),
          onPressed: _refreshData,
        ),
      ),
    ],
    bottom: isWeb
        ? null
        : TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6366F1),
            indicatorWeight: 3,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
              Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Pengajuan'),
              Tab(icon: Icon(Icons.people, size: 18), text: 'Karyawan'),
              Tab(icon: Icon(Icons.analytics, size: 18), text: 'Laporan'),
            ],
          ),
  );

  Widget _buildMobileLayout() => TabBarView(
    controller: _tabController,
    children: [
      _buildDashboardTab(),
      _buildTimeOffsTab(),
      _buildEmployeesTab(),
      _buildReportsTab(),
    ],
  );

  Widget _buildWebLayout() {
    final tabs = [
      _WebTab(Icons.dashboard, 'Dashboard', 0),
      _WebTab(Icons.list_alt, 'Pengajuan', 1),
      _WebTab(Icons.people, 'Karyawan', 2),
      _WebTab(Icons.analytics, 'Laporan', 3),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 210,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildWebStatsSummary(),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...tabs.map((tab) {
                final sel = _webTabIndex == tab.index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _webTabIndex = tab.index);
                    _tabController.animateTo(tab.index);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
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
                          size: 16,
                          color: sel
                              ? const Color(0xFF6366F1)
                              : Colors.grey[500],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: sel
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
        ),
        Expanded(
          child: IndexedStack(
            index: _webTabIndex,
            children: [
              _buildDashboardTab(),
              _buildTimeOffsTab(),
              _buildEmployeesTab(),
              _buildReportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebStatsSummary() {
    final items = [
      {
        'label': 'Total',
        'value': _statistics?.totalSubmissions ?? _allTimeOffs.length,
        'color': Colors.blue,
      },
      {
        'label': 'Pending',
        'value': _statistics?.pendingCount ?? 0,
        'color': Colors.orange,
      },
      {
        'label': 'Approved',
        'value': _statistics?.approvedCount ?? 0,
        'color': Colors.green,
      },
      {
        'label': 'Ditolak',
        'value': _statistics?.rejectedCount ?? 0,
        'color': Colors.red,
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final color = item['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['label'] as String,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
                Text(
                  '${item['value']}',
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildDashboardTab() => RefreshIndicator(
    onRefresh: _refreshData,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(),
          const SizedBox(height: 24),
          if (_statistics != null) _buildHRDStatistics(_statistics!),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (_, c) => c.maxWidth >= 600
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDepartmentOverview()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildLeaveBalanceOverview()),
                    ],
                  )
                : Column(
                    children: [
                      _buildDepartmentOverview(),
                      const SizedBox(height: 24),
                      _buildLeaveBalanceOverview(),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (_, c) => c.maxWidth >= 600
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildUrgentItems()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildHRDQuickActions()),
                    ],
                  )
                : Column(
                    children: [
                      _buildUrgentItems(),
                      const SizedBox(height: 24),
                      _buildHRDQuickActions(),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _buildWelcomeBanner() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business_center,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Human Resource Department',
                    style: TextStyle(fontSize: _fs(11), color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUserName ?? 'HRD Manager',
                    style: TextStyle(
                      fontSize: _fs(17),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('Karyawan', '${_users.length}', Icons.people),
              Container(width: 1, height: 36, color: Colors.white24),
              _buildQuickStat(
                'Cuti Hari Ini',
                '${_getTodayLeaveCount()}',
                Icons.today,
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              _buildQuickStat(
                'Menunggu',
                '${_statistics?.pendingCount ?? 0}',
                Icons.pending,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildQuickStat(String label, String value, IconData icon) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: _fs(17),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: _fs(10), color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  int _getTodayLeaveCount() {
    final today = DateTime.now();
    return _allTimeOffs
        .where(
          (i) =>
              i.status == 'Approved' &&
              i.tanggalMulai.isBefore(today.add(const Duration(days: 1))) &&
              i.tanggalSelesai.isAfter(today.subtract(const Duration(days: 1))),
        )
        .length;
  }

  Widget _buildHRDStatistics(TimeOffAdminStatistics stats) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Statistik Cuti & Time Off',
            style: TextStyle(
              fontSize: _fs(17),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => _webTabIndex = 3);
              _tabController.animateTo(3);
            },
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Lihat Detail'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (_, c) => GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: c.maxWidth > 600 ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: c.maxWidth > 600 ? 1.5 : 1.3,
          children: [
            _buildStatCard(
              title: 'Total Pengajuan',
              value: stats.totalSubmissions.toString(),
              icon: Icons.calendar_month,
              color: const Color(0xFF6366F1),
              trend: '+12%',
              onTap: () => _navFilter('all'),
            ),
            _buildStatCard(
              title: 'Menunggu Review',
              value: stats.pendingCount.toString(),
              icon: Icons.pending_actions,
              color: const Color(0xFFF59E0B),
              urgent: true,
              onTap: () => _navFilter('Pending'),
            ),
            _buildStatCard(
              title: 'Disetujui',
              value: stats.approvedCount.toString(),
              icon: Icons.check_circle,
              color: const Color(0xFF10B981),
              trend: '+5%',
              onTap: () => _navFilter('Approved'),
            ),
            _buildStatCard(
              title: 'Ditolak',
              value: stats.rejectedCount.toString(),
              icon: Icons.cancel,
              color: const Color(0xFFEF4444),
              trend: '-3%',
              onTap: () => _navFilter('Rejected'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? trend,
    bool urgent = false,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent ? color.withOpacity(0.5) : const Color(0xFFE5E7EB),
          width: urgent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: trend.startsWith('+')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: trend.startsWith('+') ? Colors.green : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: _fs(22),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(fontSize: _fs(11), color: const Color(0xFF6B7280)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  Widget _buildDepartmentOverview() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview per Departemen',
          style: TextStyle(
            fontSize: _fs(15),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 14),
        ..._departmentStats.entries.map((e) {
          final pct =
              (_allTimeOffs.isEmpty ? 0.0 : e.value / _allTimeOffs.length)
                  .clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: TextStyle(
                        fontSize: _fs(13),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    Text(
                      '${e.value} req',
                      style: TextStyle(
                        fontSize: _fs(11),
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(_deptColor(e.key)),
                  minHeight: 5,
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  Color _deptColor(String d) {
    const c = {
      'IT': Color(0xFF3B82F6),
      'HR': Color(0xFF8B5CF6),
      'Finance': Color(0xFF10B981),
      'Marketing': Color(0xFFF59E0B),
      'Operations': Color(0xFFEF4444),
    };
    return c[d] ?? const Color(0xFF6B7280);
  }

  Widget _buildLeaveBalanceOverview() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
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
              'Sisa Cuti Karyawan',
              style: TextStyle(
                fontSize: _fs(15),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _webTabIndex = 2);
                _tabController.animateTo(2);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._users.take(5).map((u) {
          final bal = _leaveBalances[u.userId] ?? 21.0;
          final low = bal < 7;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: low
                  ? Colors.red.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: low ? Colors.red.withOpacity(0.2) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
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
                        u.name,
                        style: TextStyle(
                          fontSize: _fs(13),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        u.jobs ?? '-',
                        style: TextStyle(
                          fontSize: _fs(11),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${bal.toInt()} hr',
                  style: TextStyle(
                    fontSize: _fs(13),
                    fontWeight: FontWeight.w700,
                    color: low ? Colors.red : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  Widget _buildUrgentItems() {
    final urgent = _allTimeOffs
        .where((i) => i.status == 'Pending' && i.daysSinceSubmitted > 2)
        .take(3)
        .toList();
    if (urgent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 12),
            Text(
              'Tidak ada pengajuan urgent',
              style: TextStyle(
                fontSize: _fs(13),
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.warning, size: 15, color: Colors.red),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pengajuan Urgent',
                  style: TextStyle(
                    fontSize: _fs(15),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _navFilter('Pending'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...urgent.map(
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildTimeOffCard(i, isUrgent: true),
          ),
        ),
      ],
    );
  }

  Widget _buildHRDQuickActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Aksi Cepat HRD',
        style: TextStyle(
          fontSize: _fs(15),
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1F2937),
        ),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (_, c) => GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: c.maxWidth > 400 ? 2 : 1,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: [
            _buildQuickActionCard(
              title: 'Review Pending',
              subtitle: '${_statistics?.pendingCount ?? 0} pengajuan',
              icon: Icons.pending_actions,
              color: const Color(0xFFF59E0B),
              onTap: () => _navFilter('Pending'),
            ),
            _buildQuickActionCard(
              title: 'Generate Report',
              subtitle: 'Laporan bulanan',
              icon: Icons.assessment,
              color: const Color(0xFF6366F1),
              onTap: _openReportsTab,
            ),
            _buildQuickActionCard(
              title: 'Kelola Kebijakan',
              subtitle: 'Atur cuti tahunan',
              icon: Icons.rule,
              color: const Color(0xFF10B981),
              onTap: _showPolicySettingsDialog,
            ),
            _buildQuickActionCard(
              title: 'Broadcast',
              subtitle: 'Kirim pengumuman',
              icon: Icons.campaign,
              color: const Color(0xFF8B5CF6),
              onTap: _showBroadcastDialog,
            ),
          ],
        ),
      ),
    ],
  );
  void _openReportsTab() {
    setState(() {
      _webTabIndex = 3;
    });

    _tabController.animateTo(3);
  }

  void _showPolicySettingsDialog() {
    double annualQuota = _annualLeaveQuota;
    double maxConsecutive = _maxConsecutiveLeaveDays;
    bool requireSickAttachment = _requireAttachmentForSickLeave;
    bool allowBackdate = _allowBackdateRequest;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.rule, color: Color(0xFF10B981)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Kelola Kebijakan Cuti',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPolicySlider(
                    title: 'Kuota Cuti Tahunan',
                    value: annualQuota,
                    min: 0,
                    max: 30,
                    suffix: 'hari',
                    onChanged: (v) {
                      setDialogState(() => annualQuota = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildPolicySlider(
                    title: 'Maksimal Cuti Berturut-turut',
                    value: maxConsecutive,
                    min: 1,
                    max: 30,
                    suffix: 'hari',
                    onChanged: (v) {
                      setDialogState(() => maxConsecutive = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wajib lampiran untuk izin sakit'),
                    value: requireSickAttachment,
                    onChanged: (v) {
                      setDialogState(() => requireSickAttachment = v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Izinkan pengajuan tanggal mundur'),
                    value: allowBackdate,
                    onChanged: (v) {
                      setDialogState(() => allowBackdate = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _annualLeaveQuota = annualQuota;
                    _maxConsecutiveLeaveDays = maxConsecutive;
                    _requireAttachmentForSickLeave = requireSickAttachment;
                    _allowBackdateRequest = allowBackdate;
                  });

                  Navigator.pop(context);
                  _snackOk('Kebijakan cuti berhasil disimpan sementara');
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Simpan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPolicySlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            Text(
              '${value.toInt()} $suffix',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          label: '${value.toInt()} $suffix',
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showBroadcastDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    String target = 'Semua Karyawan';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.campaign, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Broadcast Pengumuman',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: target,
                    decoration: InputDecoration(
                      labelText: 'Target Penerima',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Semua Karyawan',
                        child: Text('Semua Karyawan'),
                      ),
                      DropdownMenuItem(
                        value: 'Karyawan Pending',
                        child: Text('Karyawan dengan pengajuan pending'),
                      ),
                      DropdownMenuItem(
                        value: 'Karyawan Approved',
                        child: Text('Karyawan dengan cuti disetujui'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => target = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Judul Broadcast',
                      hintText: 'Contoh: Pengingat Pengajuan Cuti',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Isi Pesan',
                      hintText: 'Tulis isi pengumuman...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  titleController.dispose();
                  messageController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final title = titleController.text.trim();
                  final message = messageController.text.trim();

                  if (title.isEmpty || message.isEmpty) {
                    _snackErr('Judul dan isi pesan wajib diisi');
                    return;
                  }

                  titleController.dispose();
                  messageController.dispose();
                  Navigator.pop(context);

                  _snackOk('Broadcast berhasil disiapkan untuk $target');
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Kirim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _fs(12),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: _fs(10),
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildTimeOffsTab() => RefreshIndicator(
    onRefresh: _refreshData,
    child: LayoutBuilder(
      builder: (_, c) {
        final isWide = c.maxWidth >= 700;
        final listContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list,
                      size: 14,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_filteredTimeOffs.length} Hasil',
                      style: TextStyle(
                        fontSize: _fs(13),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _filteredTimeOffs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _filteredTimeOffs.length,
                      itemBuilder: (_, i) =>
                          _buildTimeOffCard(_filteredTimeOffs[i]),
                    ),
            ),
          ],
        );
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 270, child: _buildFilterPanel(true)),
              Expanded(
                child: Column(children: [Expanded(child: listContent)]),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildFilterPanel(false),
            Expanded(child: listContent),
          ],
        );
      },
    ),
  );

  Widget _buildFilterPanel(bool isWide) => Container(
    padding: const EdgeInsets.all(14),
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cari nama, jenis cuti...',
            hintStyle: TextStyle(
              fontSize: _fs(13),
              color: const Color(0xFF9CA3AF),
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF6B7280),
              size: 18,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        if (isWide) ...[
          _buildStatusFilter(),
          const SizedBox(height: 8),
          _buildDepartmentFilter(),
          const SizedBox(height: 8),
          _buildTimeRangeFilter(),
          const SizedBox(height: 8),
          _buildUserFilter(),
        ] else
          Row(
            children: [
              Expanded(child: _buildStatusFilter()),
              const SizedBox(width: 10),
              Expanded(child: _buildDepartmentFilter()),
            ],
          ),
      ],
    ),
  );

  Widget _buildStatusFilter() => DropdownButtonFormField<String>(
    value: _selectedStatus,
    decoration: InputDecoration(
      labelText: 'Status',
      labelStyle: TextStyle(fontSize: _fs(12)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      isDense: true,
    ),
    style: TextStyle(fontSize: _fs(13), color: Colors.black),
    items: _statusOptions
        .map(
          (s) => DropdownMenuItem(
            value: s == 'Semua Status' ? null : s,
            child: Text(
              s == 'Semua Status'
                  ? s
                  : TimeOffAdminService.getStatusDisplayName(s),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: (v) {
      setState(() {
        _selectedStatus = v;
        _applyFilters();
      });
    },
  );

  Widget _buildDepartmentFilter() => DropdownButtonFormField<String>(
    value: _selectedDepartment,
    decoration: InputDecoration(
      labelText: 'Departemen',
      labelStyle: TextStyle(fontSize: _fs(12)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      isDense: true,
    ),
    style: TextStyle(fontSize: _fs(13), color: Colors.black),
    items: _departments
        .map(
          (d) => DropdownMenuItem(
            value: d == 'Semua Departemen' ? null : d,
            child: Text(d, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) {
      setState(() {
        _selectedDepartment = v;
        _applyFilters();
      });
    },
  );

  Widget _buildTimeRangeFilter() => DropdownButtonFormField<String>(
    value: _selectedTimeRange,
    decoration: InputDecoration(
      labelText: 'Periode',
      labelStyle: TextStyle(fontSize: _fs(12)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      isDense: true,
    ),
    style: TextStyle(fontSize: _fs(13), color: Colors.black),
    items: _timeRangeOptions
        .map(
          (r) => DropdownMenuItem(
            value: r,
            child: Text(r, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) {
      setState(() {
        _selectedTimeRange = v;
        _applyFilters();
      });
    },
  );

  Widget _buildUserFilter() {
    final opts = ['Semua User'] + _users.map((u) => u.name).toList();
    final currentName = _selectedUserId == null
        ? 'Semua User'
        : (_users.where((u) => u.userId == _selectedUserId).isNotEmpty
              ? _users.firstWhere((u) => u.userId == _selectedUserId).name
              : 'Semua User');
    return DropdownButtonFormField<String>(
      value: currentName,
      decoration: InputDecoration(
        labelText: 'Karyawan',
        labelStyle: TextStyle(fontSize: _fs(12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(fontSize: _fs(13), color: Colors.black),
      isExpanded: true,
      items: opts
          .map(
            (n) => DropdownMenuItem(
              value: n,
              child: Text(n, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          )
          .toList(),
      onChanged: (v) {
        setState(() {
          _selectedUserId = v == 'Semua User'
              ? null
              : _users.firstWhere((u) => u.name == v).userId;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildEmployeesTab() => RefreshIndicator(
    onRefresh: _refreshData,
    child: _users.isEmpty
        ? _buildEmptyState()
        : LayoutBuilder(
            builder: (_, c) => c.maxWidth >= 700
                ? GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.3,
                        ),
                    itemCount: _users.length,
                    itemBuilder: (_, i) => _buildEmployeeCard(_users[i]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (_, i) => _buildEmployeeCard(_users[i]),
                  ),
          ),
  );

  Widget _buildReportsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              const Icon(Icons.assessment, color: Colors.white, size: 28),
              const SizedBox(height: 10),
              Text(
                'Laporan HRD',
                style: TextStyle(
                  fontSize: _fs(19),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Analisis komprehensif time off karyawan',
                style: TextStyle(fontSize: _fs(13), color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (_, c) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: c.maxWidth > 600 ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildReportCard(
                title: 'Laporan Bulanan',
                icon: Icons.calendar_today,
                color: const Color(0xFF3B82F6),
                onTap: () => _exportReportData('bulanan'),
              ),
              _buildReportCard(
                title: 'Laporan Tahunan',
                icon: Icons.date_range,
                color: const Color(0xFF10B981),
                onTap: () => _exportReportData('tahunan'),
              ),
              _buildReportCard(
                title: 'Per Departemen',
                icon: Icons.business,
                color: const Color(0xFFF59E0B),
                onTap: () => _exportReportData('departemen'),
              ),
              _buildReportCard(
                title: 'Per Karyawan',
                icon: Icons.person,
                color: const Color(0xFF8B5CF6),
                onTap: () => _exportReportData('karyawan'),
              ),
              _buildReportCard(
                title: 'Tren Cuti',
                icon: Icons.trending_up,
                color: const Color(0xFFEF4444),
                onTap: () => _exportReportData('tren'),
              ),
              _buildReportCard(
                title: 'Export Data',
                icon: Icons.download,
                color: const Color(0xFF6B7280),
                onTap: () => _exportReportData('detail'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ringkasan Laporan',
                style: TextStyle(
                  fontSize: _fs(16),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryItem(
                'Total Hari Cuti Digunakan',
                '${_calculateTotalDaysUsed()} hari',
              ),
              _buildSummaryItem(
                'Rata-rata Cuti per Karyawan',
                '${_calculateAverageDays().toStringAsFixed(1)} hari',
              ),
              _buildSummaryItem(
                'Departemen Paling Aktif',
                _getMostActiveDepartment(),
              ),
              _buildSummaryItem(
                'Tingkat Approval',
                '${_calculateApprovalRate().toStringAsFixed(1)}%',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _exportReportData(String reportType) async {
    try {
      final buffer = StringBuffer();

      String clean(String? value) {
        return '"${(value ?? '-').replaceAll('"', '""')}"';
      }

      String normalizeStatus(String status) {
        return status.trim();
      }

      bool isPendingLike(String status) {
        final s = status.toLowerCase();
        return s == 'pending' || s == 'menunggu laporan' || s == 'menunggu org';
      }

      bool isApprovedLike(String status) {
        final s = status.toLowerCase();
        return s == 'approved' || s == 'processed' || s == 'submitted';
      }

      bool isRejectedLike(String status) {
        return status.toLowerCase() == 'rejected';
      }

      String getDept(AdminTimeOffData item) {
        return item.userDepartment ?? 'Tidak Ada Departemen';
      }

      String title = 'laporan_timeoff_hrd';

      if (reportType == 'bulanan') {
        title = 'laporan_bulanan_timeoff_hrd';

        buffer.writeln(
          'Bulan,Tahun,Total Pengajuan,Menunggu,Approved,Rejected,Total Hari',
        );

        final Map<String, List<AdminTimeOffData>> grouped = {};

        for (final item in _allTimeOffs) {
          final key =
              '${item.tanggalMulai.year}-${item.tanggalMulai.month.toString().padLeft(2, '0')}';

          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(item);
        }

        final entries = grouped.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        for (final entry in entries) {
          final items = entry.value;
          final first = items.first.tanggalMulai;

          final menunggu = items
              .where((e) => isPendingLike(normalizeStatus(e.status)))
              .length;
          final approved = items
              .where((e) => isApprovedLike(normalizeStatus(e.status)))
              .length;
          final rejected = items
              .where((e) => isRejectedLike(normalizeStatus(e.status)))
              .length;

          final totalHari = items.fold<int>(0, (sum, e) => sum + e.totalHari);

          buffer.writeln(
            [
              clean(_getMonthName(first.month)),
              clean(first.year.toString()),
              clean(items.length.toString()),
              clean(menunggu.toString()),
              clean(approved.toString()),
              clean(rejected.toString()),
              clean(totalHari.toString()),
            ].join(','),
          );
        }
      } else if (reportType == 'tahunan') {
        title = 'laporan_tahunan_timeoff_hrd';

        buffer.writeln(
          'Tahun,Total Pengajuan,Menunggu,Approved,Rejected,Total Hari',
        );

        final Map<int, List<AdminTimeOffData>> grouped = {};

        for (final item in _allTimeOffs) {
          final key = item.tanggalMulai.year;
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(item);
        }

        final entries = grouped.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        for (final entry in entries) {
          final items = entry.value;

          final menunggu = items
              .where((e) => isPendingLike(normalizeStatus(e.status)))
              .length;
          final approved = items
              .where((e) => isApprovedLike(normalizeStatus(e.status)))
              .length;
          final rejected = items
              .where((e) => isRejectedLike(normalizeStatus(e.status)))
              .length;

          final totalHari = items.fold<int>(0, (sum, e) => sum + e.totalHari);

          buffer.writeln(
            [
              clean(entry.key.toString()),
              clean(items.length.toString()),
              clean(menunggu.toString()),
              clean(approved.toString()),
              clean(rejected.toString()),
              clean(totalHari.toString()),
            ].join(','),
          );
        }
      } else if (reportType == 'departemen') {
        title = 'laporan_per_departemen_timeoff_hrd';

        buffer.writeln(
          'Departemen,Total Pengajuan,Menunggu,Approved,Rejected,Total Hari',
        );

        final Map<String, List<AdminTimeOffData>> grouped = {};

        for (final item in _allTimeOffs) {
          final key = getDept(item);
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(item);
        }

        final entries = grouped.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

        for (final entry in entries) {
          final items = entry.value;

          final menunggu = items
              .where((e) => isPendingLike(normalizeStatus(e.status)))
              .length;
          final approved = items
              .where((e) => isApprovedLike(normalizeStatus(e.status)))
              .length;
          final rejected = items
              .where((e) => isRejectedLike(normalizeStatus(e.status)))
              .length;

          final totalHari = items.fold<int>(0, (sum, e) => sum + e.totalHari);

          buffer.writeln(
            [
              clean(entry.key),
              clean(items.length.toString()),
              clean(menunggu.toString()),
              clean(approved.toString()),
              clean(rejected.toString()),
              clean(totalHari.toString()),
            ].join(','),
          );
        }
      } else if (reportType == 'karyawan') {
        title = 'laporan_per_karyawan_timeoff_hrd';

        buffer.writeln(
          'User ID,Nama,Jabatan,Departemen,Total Pengajuan,Menunggu,Approved,Rejected,Total Hari',
        );

        final Map<String, List<AdminTimeOffData>> grouped = {};

        for (final item in _allTimeOffs) {
          grouped.putIfAbsent(item.userId, () => []);
          grouped[item.userId]!.add(item);
        }

        final entries = grouped.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

        for (final entry in entries) {
          final items = entry.value;
          final first = items.first;

          final menunggu = items
              .where((e) => isPendingLike(normalizeStatus(e.status)))
              .length;
          final approved = items
              .where((e) => isApprovedLike(normalizeStatus(e.status)))
              .length;
          final rejected = items
              .where((e) => isRejectedLike(normalizeStatus(e.status)))
              .length;

          final totalHari = items.fold<int>(0, (sum, e) => sum + e.totalHari);

          buffer.writeln(
            [
              clean(first.userId),
              clean(first.userName),
              clean(first.userJob),
              clean(first.userDepartment),
              clean(items.length.toString()),
              clean(menunggu.toString()),
              clean(approved.toString()),
              clean(rejected.toString()),
              clean(totalHari.toString()),
            ].join(','),
          );
        }
      } else if (reportType == 'tren') {
        title = 'laporan_tren_cuti_timeoff_hrd';

        buffer.writeln('Periode,Total Pengajuan,Total Hari');

        final Map<String, List<AdminTimeOffData>> grouped = {};

        for (final item in _allTimeOffs) {
          final key =
              '${item.tanggalMulai.year}-${item.tanggalMulai.month.toString().padLeft(2, '0')}';

          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(item);
        }

        final entries = grouped.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        for (final entry in entries) {
          final items = entry.value;
          final totalHari = items.fold<int>(0, (sum, e) => sum + e.totalHari);

          buffer.writeln(
            [
              clean(entry.key),
              clean(items.length.toString()),
              clean(totalHari.toString()),
            ].join(','),
          );
        }
      } else {
        title = 'laporan_detail_timeoff_hrd';

        buffer.writeln(
          'ID,User ID,Nama,Jenis Cuti,Tanggal Mulai,Tanggal Selesai,Total Hari,Status,Departemen,Catatan,Laporan Status',
        );

        for (final item in _filteredTimeOffs) {
          buffer.writeln(
            [
              clean(item.id.toString()),
              clean(item.userId),
              clean(item.userName),
              clean(item.jenisTimeOff),
              clean(DateFormat('dd/MM/yyyy').format(item.tanggalMulai)),
              clean(DateFormat('dd/MM/yyyy').format(item.tanggalSelesai)),
              clean(item.totalHari.toString()),
              clean(item.statusText),
              clean(item.userDepartment),
              clean(item.catatan),
              clean(item.hasLaporan ? 'Ada Laporan' : 'Tidak Ada Laporan'),
            ].join(','),
          );
        }
      }

      final fileName =
          '${title}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

      final content = buffer.toString();

      if (kIsWeb) {
        final bytes = Uint8List.fromList(utf8.encode(content));
        downloadFileWeb(bytes, fileName);
        _snackOk('Laporan berhasil diunduh');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');

      await file.writeAsString(content);

      _snackOk('Laporan berhasil dibuat');

      await OpenFile.open(file.path);
    } catch (e) {
      _snackErr('Gagal membuat laporan: $e');
    }
  }

  String _getMonthName(int month) {
    const months = [
      '',
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

    if (month < 1 || month > 12) return '-';
    return months[month];
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: _fs(13),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildSummaryItem(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: _fs(13), color: const Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: _fs(13),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    ),
  );

  Widget _buildTimeOffCard(
    AdminTimeOffData item, {
    bool isUrgent = false,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: isUrgent ? 4 : 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: isUrgent
          ? const BorderSide(color: Color(0xFFEF4444), width: 1)
          : BorderSide.none,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showTimeOffDetail(item),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isUrgent) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.priority_high,
                          size: 11,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: _fs(9),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(item.jenisIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.jenisTimeOff,
                    style: TextStyle(
                      fontSize: _fs(14),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.statusColorValue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    item.statusText,
                    style: TextStyle(
                      fontSize: _fs(11),
                      fontWeight: FontWeight.w600,
                      color: item.statusColorValue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  child: Text(
                    item.userName.isNotEmpty
                        ? item.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.userName,
                        style: TextStyle(
                          fontSize: _fs(13),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.userJob ?? 'No Position'} • ${item.userDepartment ?? 'No Dept'}',
                        style: TextStyle(
                          fontSize: _fs(11),
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.formattedDate,
                        style: TextStyle(
                          fontSize: _fs(12),
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.totalHari} hari',
                      style: TextStyle(
                        fontSize: _fs(12),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Badge laporan tersedia
            if (item.isDinasLuar &&
                item.hasLaporan &&
                item.status == 'Pending') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '📎 Laporan DL sudah diupload — siap direview',
                      style: TextStyle(
                        fontSize: _fs(11),
                        color: const Color(0xFF5B21B6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.status == 'Pending') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Diajukan ${item.daysSinceSubmitted} hari yang lalu',
                        style: TextStyle(
                          fontSize: _fs(11),
                          color: item.urgencyColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _quickReview(item, 'Rejected'),
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Tolak'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _quickReview(item, 'Approved'),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Setujui'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _buildEmployeeCard(UserWithTimeOffs user) {
    final bal = _leaveBalances[user.userId] ?? 21.0;
    final low = bal < 7;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedUserId = user.userId;
            _webTabIndex = 1;
            _tabController.animateTo(1);
            _applyFilters();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: _fs(14),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${user.jobs ?? '-'} • ${user.department ?? '-'}',
                          style: TextStyle(
                            fontSize: _fs(12),
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (low)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 11,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Low',
                            style: TextStyle(
                              fontSize: _fs(10),
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sisa Cuti',
                    style: TextStyle(
                      fontSize: _fs(11),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    '${bal.toInt()} / 21 hari',
                    style: TextStyle(
                      fontSize: _fs(11),
                      fontWeight: FontWeight.w600,
                      color: low ? Colors.red : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (bal / 21).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(
                  low ? Colors.red : const Color(0xFF10B981),
                ),
                minHeight: 5,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildUserStatItem(
                    'Total',
                    user.totalTimeOff.toString(),
                    Colors.blue,
                  ),
                  _buildUserStatItem(
                    'Pending',
                    user.pendingCount.toString(),
                    Colors.orange,
                  ),
                  _buildUserStatItem(
                    'Approved',
                    user.approvedCount.toString(),
                    Colors.green,
                  ),
                  _buildUserStatItem(
                    'Rejected',
                    user.rejectedCount.toString(),
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserStatItem(String label, String value, Color color) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: _fs(15),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: TextStyle(fontSize: _fs(10), color: const Color(0xFF6B7280)),
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _buildEmptyState() => Center(
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
              Icons.inbox_outlined,
              size: 60,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tidak Ada Data',
            style: TextStyle(
              fontSize: _fs(17),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Belum ada data yang sesuai dengan filter',
            style: TextStyle(fontSize: _fs(13), color: const Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _selectedUserId = null;
                _selectedDepartment = null;
                _searchController.clear();
                _applyFilters();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          Text(
            'Data User Tidak Ditemukan',
            style: TextStyle(
              fontSize: _fs(19),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan login ulang untuk mengakses halaman HRD.',
            style: TextStyle(fontSize: _fs(13), color: const Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  int _calculateTotalDaysUsed() => _allTimeOffs
      .where((i) => i.status == 'Approved')
      .fold(0, (s, i) => s + i.totalHari);
  double _calculateAverageDays() =>
      _users.isEmpty ? 0 : _calculateTotalDaysUsed() / _users.length;
  double _calculateApprovalRate() =>
      (_statistics == null || _statistics!.totalSubmissions == 0)
      ? 0
      : _statistics!.approvedCount / _statistics!.totalSubmissions * 100;
  String _getMostActiveDepartment() => _departmentStats.isEmpty
      ? 'N/A'
      : (_departmentStats.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

  void _navFilter(String filter) {
    setState(() => _webTabIndex = 1);
    _tabController.animateTo(1);
    setState(() {
      _selectedStatus = filter == 'all' ? null : filter;
      _selectedUserId = null;
      _selectedDepartment = null;
      _searchController.clear();
      _applyFilters();
    });
  }

  Future<void> _quickReview(AdminTimeOffData item, String status) async {
    try {
      final resp = await TimeOffAdminService.reviewTimeOff(
        id: item.id,
        status: status,
        approvedBy: _currentUserName!,
        adminId: _currentUserId!,
      );
      if (resp.success) {
        await _refreshData();
        _snackOk(
          status == 'Approved' ? 'Pengajuan disetujui' : 'Pengajuan ditolak',
        );
      } else {
        _snackErr(resp.message);
      }
    } catch (e) {
      _snackErr('Terjadi kesalahan: $e');
    }
  }
}

class _WebTab {
  final IconData icon;
  final String label;
  final int index;
  const _WebTab(this.icon, this.label, this.index);
}

// ══════════════════════════════════════════════════════════════════════════════
// HRDTimeOffDetailModal
// ══════════════════════════════════════════════════════════════════════════════
class HRDTimeOffDetailModal extends StatefulWidget {
  final AdminTimeOffData item;
  final String currentHRDId;
  final String currentHRDName;
  final VoidCallback onActionCompleted;

  const HRDTimeOffDetailModal({
    super.key,
    required this.item,
    required this.currentHRDId,
    required this.currentHRDName,
    required this.onActionCompleted,
  });

  @override
  _HRDTimeOffDetailModalState createState() => _HRDTimeOffDetailModalState();
}

class _HRDTimeOffDetailModalState extends State<HRDTimeOffDetailModal> {
  final TextEditingController _reviewNotesController = TextEditingController();
  final FocusNode _reviewNotesFocusNode = FocusNode();
  bool _isProcessing = false;
  bool _isDownloading = false;

  @override
  void dispose() {
    _reviewNotesController.dispose();
    _reviewNotesFocusNode.dispose();
    super.dispose();
  }

  // ── Token (pakai method dari TimeOffAdminService) ─────────────────
  Future<String?> _getToken() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        return d['access_token'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Download laporan / anggaran ──────────────────────────────────
  Future<void> _downloadDlFile(String fileType) async {
    setState(() => _isDownloading = true);
    _snack('Mengunduh file $fileType...', err: false, dur: 1);
    try {
      final token = await _getToken();
      if (token == null) {
        _snack('Gagal mendapatkan token', err: true);
        return;
      }

      final response = await http
          .post(
            Uri.parse('$baseURL/api/timeoff/dl-download-laporan'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'timeOffId': widget.item.id,
              'userId': widget.currentHRDId,
              'fileType': fileType,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final fileName = fileType == 'laporan'
            ? (widget.item.laporanFileName ?? 'laporan.pdf')
            : (widget.item.anggaranFileName ?? 'anggaran.pdf');

        if (kIsWeb) {
          _snack('File $fileName berhasil diunduh', err: false);
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done) {
            _snack('Tidak dapat membuka file: ${result.message}', err: true);
          }
        }
      } else {
        final body = response.body.isNotEmpty ? json.decode(response.body) : {};
        _snack(
          (body as Map)['Message'] ??
              (body)['message'] ??
              'Gagal mengunduh (${response.statusCode})',
          err: true,
        );
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _reviewTimeOff(String status) async {
    FocusScope.of(context).unfocus();
    setState(() => _isProcessing = true);
    try {
      final response = await TimeOffAdminService.reviewTimeOff(
        id: widget.item.id,
        status: status,
        approvedBy: widget.currentHRDName,
        rejectionReason: _reviewNotesController.text.trim().isNotEmpty
            ? _reviewNotesController.text.trim()
            : null,
        adminId: widget.currentHRDId,
      );
      if (response.success) {
        Navigator.of(context).pop();
        widget.onActionCompleted();
        _snack(response.message, err: false);
      } else {
        _snack(response.message, err: true);
      }
    } catch (e) {
      _snack('Terjadi kesalahan: $e', err: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _snack(String msg, {required bool err, int dur = 3}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: Duration(seconds: dur),
          backgroundColor: err
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
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
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment, color: Color(0xFF6366F1)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Detail Pengajuan Time Off',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.item.statusColorValue.withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.item.statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.item.statusColorValue,
                            ),
                          ),
                        ),
                        if (widget.item.urgencyText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.item.urgencyColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.item.urgencyText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.item.urgencyColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Info Karyawan
                    _buildInfoCard(
                      title: 'Informasi Karyawan',
                      icon: Icons.person,
                      children: [
                        _detailRow('Nama', widget.item.userName),
                        _detailRow('Email', widget.item.userEmail),
                        if (widget.item.userPhone != null)
                          _detailRow('Telepon', widget.item.userPhone!),
                        if (widget.item.userJob != null)
                          _detailRow('Posisi', widget.item.userJob!),
                        if (widget.item.userDepartment != null)
                          _detailRow('Departemen', widget.item.userDepartment!),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Detail Cuti
                    _buildInfoCard(
                      title: 'Detail Cuti',
                      icon: Icons.calendar_today,
                      children: [
                        _detailRow('Jenis Cuti', widget.item.jenisTimeOff),
                        _detailRow('Periode', widget.item.formattedDate),
                        _detailRow(
                          'Total Hari',
                          '${widget.item.totalHari} hari',
                        ),
                        if (widget.item.jenisPekerjaan != null)
                          _detailRow(
                            'Jenis Pekerjaan',
                            widget.item.jenisPekerjaan!,
                          ),
                        if (widget.item.catatan != null)
                          _detailRow('Catatan', widget.item.catatan!),
                        _detailRow(
                          'Tanggal Pengajuan',
                          widget.item.formattedSubmittedDate,
                        ),
                      ],
                    ),

                    // ── Section Laporan DL ────────────────────────────────
                    if (widget.item.isDinasLuar) ...[
                      const SizedBox(height: 16),
                      _buildDlLaporanSection(),
                    ],

                    // Review notes
                    if (widget.item.status == 'Pending') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Catatan Review HRD',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _reviewNotesController,
                        focusNode: _reviewNotesFocusNode,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tambahkan catatan untuk keputusan Anda...',
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                            Icons.note_add,
                            color: Color(0xFF6366F1),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            // Bottom
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SafeArea(
                child: _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : _buildActionButtons(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Laporan DL section ───────────────────────────────────────────
  Widget _buildDlLaporanSection() {
    if (!widget.item.hasLaporan) {
      return _buildInfoCard(
        title: 'Laporan Dinas Luar',
        icon: Icons.folder_open,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pending_outlined,
                  color: Colors.orange[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Laporan belum diupload oleh karyawan',
                    style: TextStyle(fontSize: 13, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _buildInfoCard(
      title: 'Laporan Dinas Luar',
      icon: Icons.folder_open,
      children: [
        const SizedBox(height: 4),
        if (widget.item.jenisPekerjaan != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.work_outline,
                  size: 14,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 6),
                Text(
                  'Divisi: ${widget.item.jenisPekerjaan}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5B21B6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.item.laporanFileName != null)
          _buildFileRow(
            label: 'Laporan Hasil Kerja',
            fileName: widget.item.laporanFileName!,
            fileType: 'laporan',
            color: const Color(0xFF3B82F6),
            icon: Icons.description_outlined,
          ),
        if (widget.item.laporanFileName != null &&
            widget.item.anggaranFileName != null)
          const SizedBox(height: 8),
        if (widget.item.anggaranFileName != null)
          _buildFileRow(
            label: 'Laporan Anggaran',
            fileName: widget.item.anggaranFileName!,
            fileType: 'anggaran',
            color: const Color(0xFF10B981),
            icon: Icons.receipt_long_outlined,
          ),
        if (widget.item.laporanSubmittedAt != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 13, color: Color(0xFF6B7280)),
              const SizedBox(width: 5),
              Text(
                'Diupload: ${DateFormat('dd MMM yyyy HH:mm').format(widget.item.laporanSubmittedAt!)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFileRow({
    required String label,
    required String fileName,
    required String fileType,
    required Color color,
    required IconData icon,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _isDownloading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : ElevatedButton.icon(
                onPressed: () => _downloadDlFile(fileType),
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: const Text('Lihat', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
      ],
    ),
  );

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildActionButtons() {
    if (widget.item.status != 'Pending') return const SizedBox();
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _reviewTimeOff('Rejected'),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Tolak'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _reviewTimeOff('Approved'),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Setujui'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Extensions ────────────────────────────────────────────────────────
extension UserWithTimeOffsExtension on UserWithTimeOffs {
  String? get department {
    final depts = ['IT', 'HR', 'Finance', 'Marketing', 'Operations'];
    return depts[userId.hashCode % depts.length];
  }
}

extension AdminTimeOffDataExtension on AdminTimeOffData {
  String? get userDepartment {
    if (userJob?.contains('Developer') ?? false) return 'IT';
    if (userJob?.contains('HR') ?? false) return 'HR';
    if (userJob?.contains('Finance') ?? false) return 'Finance';
    if (userJob?.contains('Marketing') ?? false) return 'Marketing';
    return 'Operations';
  }
}
