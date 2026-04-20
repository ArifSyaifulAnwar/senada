// screens/time_off_hrd_screen.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/model/timeoffmodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/timeoffserviceadmin.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _selectedStatus;
  String? _selectedUserId;
  String? _selectedDepartment;
  String? _selectedTimeRange = 'Bulan Ini';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // HRD specific data
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
    _loadUserData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('UserID');
      _currentUserName = prefs.getString('Name');

      if (_currentUserId != null && _currentUserName != null) {
        await _loadAllData();
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Data user tidak ditemukan. Silakan login ulang.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Gagal memuat data user: $e');
    }
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) {
      return baseSize - 2;
    } else if (screenWidth < 400) {
      return baseSize - 1;
    } else if (screenWidth > 600) {
      return baseSize + 1;
    } else {
      return baseSize;
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures =
          await Future.wait([
            TimeOffAdminService.getAllTimeOffs(adminId: _currentUserId!),
            TimeOffAdminService.getUsersWithTimeOffs(adminId: _currentUserId!),
            TimeOffAdminService.getAdminStatistics(),
          ]).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. Silakan coba lagi.');
            },
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
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Gagal memuat data: $e');
    }
  }

  void _calculateDepartmentStats() {
    _departmentStats.clear();
    for (var user in _users) {
      String dept = user.department ?? 'Unknown';
      _departmentStats[dept] =
          (_departmentStats[dept] ?? 0) + user.totalTimeOff;
    }
  }

  void _calculateLeaveBalances() {
    _leaveBalances.clear();
    for (var user in _users) {
      // Simulasi perhitungan sisa cuti (ini bisa disesuaikan dengan logika bisnis)
      double totalDays = 21.0; // Total cuti tahunan
      double usedDays = user.totalApprovedDays.toDouble();
      _leaveBalances[user.userId] = totalDays - usedDays;
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    List<AdminTimeOffData> filtered = _allTimeOffs;

    // Filter by status
    if (_selectedStatus != null && _selectedStatus != 'Semua Status') {
      filtered = filtered
          .where((item) => item.status == _selectedStatus)
          .toList();
    }

    // Filter by user
    if (_selectedUserId != null && _selectedUserId != 'Semua User') {
      filtered = filtered
          .where((item) => item.userId == _selectedUserId)
          .toList();
    }

    // Filter by department (HRD specific)
    if (_selectedDepartment != null &&
        _selectedDepartment != 'Semua Departemen') {
      var userIds = _users
          .where((user) => user.department == _selectedDepartment)
          .map((user) => user.userId)
          .toList();
      filtered = filtered
          .where((item) => userIds.contains(item.userId))
          .toList();
    }

    // Filter by time range
    if (_selectedTimeRange != null) {
      DateTime now = DateTime.now();
      DateTime startDate;

      switch (_selectedTimeRange) {
        case 'Hari Ini':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Minggu Ini':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'Bulan Ini':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Tahun Ini':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      filtered = filtered
          .where((item) => item.submittedAt.isAfter(startDate))
          .toList();
    }

    // Filter by search keyword
    String searchKeyword = _searchController.text.toLowerCase();
    if (searchKeyword.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.jenisTimeOff.toLowerCase().contains(searchKeyword) ||
            item.userName.toLowerCase().contains(searchKeyword) ||
            (item.catatan?.toLowerCase().contains(searchKeyword) ?? false);
      }).toList();
    }

    // Sort by urgency and date
    filtered.sort((a, b) {
      if (a.status == 'Pending' && b.status != 'Pending') return -1;
      if (a.status != 'Pending' && b.status == 'Pending') return 1;

      if (a.status == 'Pending' && b.status == 'Pending') {
        return b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted);
      }

      return b.submittedAt.compareTo(a.submittedAt);
    });

    setState(() {
      _filteredTimeOffs = filtered;
    });
  }

  Future<void> _refreshData() async {
    await _loadAllData();
    _showSuccessSnackBar('Data berhasil diperbarui');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
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
  }

  void _showTimeOffDetail(AdminTimeOffData item) {
    if (_currentUserId == null || _currentUserName == null) {
      _showErrorSnackBar('Data user belum dimuat. Silakan tunggu sebentar.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return HRDTimeOffDetailModal(
          item: item,
          currentHRDId: _currentUserId!,
          currentHRDName: _currentUserName!,
          onActionCompleted: _refreshData,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
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
                'HRD Time Off Management',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, isTablet ? 22 : 18),
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          if (isTablet) ...[
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black87,
                  size: 18,
                ),
                onPressed: () {
                  // Show notifications
                },
              ),
            ),
          ],
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          isScrollable: !isTablet,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
            Tab(icon: const Icon(Icons.list_alt, size: 18), text: 'Pengajuan'),
            Tab(icon: const Icon(Icons.people, size: 18), text: 'Karyawan'),
            Tab(icon: const Icon(Icons.analytics, size: 18), text: 'Laporan'),
          ],
        ),
      ),
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
                      fontSize: _getResponsiveFontSize(context, 16),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : _currentUserId == null || _currentUserName == null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildTimeOffsTab(),
                _buildEmployeesTab(),
                _buildReportsTab(),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
                fontSize: _getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Silakan login ulang untuk mengakses halaman HRD.',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section with HRD specific info
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business_center,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Human Resource Department',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 12),
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentUserName ?? 'HRD Manager',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(
                                  context,
                                  isTablet ? 20 : 18,
                                ),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickStat(
                          'Karyawan Aktif',
                          '${_users.length}',
                          Icons.people,
                        ),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _buildQuickStat(
                          'Cuti Hari Ini',
                          '${_getTodayLeaveCount()}',
                          Icons.today,
                        ),
                        Container(width: 1, height: 40, color: Colors.white24),
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
            ),

            const SizedBox(height: 24),

            // HRD Specific Statistics
            if (_statistics != null) _buildHRDStatistics(_statistics!),

            const SizedBox(height: 24),

            // Department Overview
            _buildDepartmentOverview(),

            const SizedBox(height: 24),

            // Leave Balance Overview
            _buildLeaveBalanceOverview(),

            const SizedBox(height: 24),

            // Recent Urgent Items
            _buildUrgentItems(),

            const SizedBox(height: 24),

            // HRD Quick Actions
            _buildHRDQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 10),
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _getTodayLeaveCount() {
    final today = DateTime.now();
    return _allTimeOffs.where((item) {
      return item.status == 'Approved' &&
          item.tanggalMulai.isBefore(today.add(const Duration(days: 1))) &&
          item.tanggalSelesai.isAfter(today.subtract(const Duration(days: 1)));
    }).length;
  }

  Widget _buildHRDStatistics(TimeOffAdminStatistics stats) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Statistik Cuti & Time Off',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _tabController.animateTo(3); // Go to Reports tab
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

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: screenWidth > 600 ? 1.5 : 1.3,
          children: [
            _buildStatCard(
              title: 'Total Pengajuan',
              value: stats.totalSubmissions.toString(),
              icon: Icons.calendar_month,
              color: const Color(0xFF6366F1),
              trend: '+12%',
              onTap: () => _navigateToTimeOffsWithFilter('all'),
            ),
            _buildStatCard(
              title: 'Menunggu Review',
              value: stats.pendingCount.toString(),
              icon: Icons.pending_actions,
              color: const Color(0xFFF59E0B),
              urgent: true,
              onTap: () => _navigateToTimeOffsWithFilter('Pending'),
            ),
            _buildStatCard(
              title: 'Disetujui',
              value: stats.approvedCount.toString(),
              icon: Icons.check_circle,
              color: const Color(0xFF10B981),
              trend: '+5%',
              onTap: () => _navigateToTimeOffsWithFilter('Approved'),
            ),
            _buildStatCard(
              title: 'Ditolak',
              value: stats.rejectedCount.toString(),
              icon: Icons.cancel,
              color: const Color(0xFFEF4444),
              trend: '-3%',
              onTap: () => _navigateToTimeOffsWithFilter('Rejected'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? trend,
    bool urgent = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                        color: trend.startsWith('+')
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                if (onTap != null && trend == null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 24),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 12),
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                'Overview per Departemen',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              IconButton(
                onPressed: () {
                  // Show department details
                },
                icon: const Icon(Icons.more_vert, size: 20),
                color: const Color(0xFF6B7280),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._departmentStats.entries.map((entry) {
            final percentage = (entry.value / _allTimeOffs.length * 100)
                .toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                      Text(
                        '${entry.value} pengajuan ($percentage%)',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        entry.value /
                        (_allTimeOffs.isEmpty ? 1 : _allTimeOffs.length),
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getDepartmentColor(entry.key),
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

  Color _getDepartmentColor(String department) {
    final colors = {
      'IT': const Color(0xFF3B82F6),
      'HR': const Color(0xFF8B5CF6),
      'Finance': const Color(0xFF10B981),
      'Marketing': const Color(0xFFF59E0B),
      'Operations': const Color(0xFFEF4444),
    };
    return colors[department] ?? const Color(0xFF6B7280);
  }

  Widget _buildLeaveBalanceOverview() {
    final topUsers = _users.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(2); // Go to Employees tab
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                ),
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topUsers.map((user) {
            final balance = _leaveBalances[user.userId] ?? 21.0;
            final balancePercentage = (balance / 21 * 100).toStringAsFixed(0);
            final isLow = balance < 7;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLow
                    ? Colors.red.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLow
                      ? Colors.red.withOpacity(0.2)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          user.jobs ?? 'No Position',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${balance.toInt()} hari',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: isLow ? Colors.red : const Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        'Sisa $balancePercentage%',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 11),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUrgentItems() {
    final urgentItems = _allTimeOffs
        .where(
          (item) => item.status == 'Pending' && item.daysSinceSubmitted > 2,
        )
        .take(3)
        .toList();

    if (urgentItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tidak ada pengajuan urgent yang perlu direview',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 14),
                  color: const Color(0xFF6B7280),
                ),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.warning, size: 16, color: Colors.red),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pengajuan Urgent',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                _navigateToTimeOffsWithFilter('Pending');
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...urgentItems.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildTimeOffCard(item, isUrgent: true),
          ),
        ),
      ],
    );
  }

  Widget _buildHRDQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat HRD',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            _buildQuickActionCard(
              title: 'Review Pending',
              subtitle: '${_statistics?.pendingCount ?? 0} pengajuan',
              icon: Icons.pending_actions,
              color: const Color(0xFFF59E0B),
              onTap: () => _navigateToTimeOffsWithFilter('Pending'),
            ),
            _buildQuickActionCard(
              title: 'Generate Report',
              subtitle: 'Laporan bulanan',
              icon: Icons.assessment,
              color: const Color(0xFF6366F1),
              onTap: () {
                _tabController.animateTo(3);
              },
            ),
            _buildQuickActionCard(
              title: 'Kelola Kebijakan',
              subtitle: 'Atur cuti tahunan',
              icon: Icons.rule,
              color: const Color(0xFF10B981),
              onTap: () {
                // Navigate to policy management
              },
            ),
            _buildQuickActionCard(
              title: 'Broadcast',
              subtitle: 'Kirim pengumuman',
              icon: Icons.campaign,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                // Show broadcast dialog
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
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
              color: Colors.black.withOpacity(0.05),
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
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 11),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOffsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Enhanced Search and Filter Section
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Cari berdasarkan nama, jenis cuti, atau catatan...',
                    hintStyle: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Row
                if (isTablet)
                  Row(
                    children: [
                      Expanded(child: _buildStatusFilter()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDepartmentFilter()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTimeRangeFilter()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildUserFilter()),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildStatusFilter()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDepartmentFilter()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTimeRangeFilter()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildUserFilter()),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // List Header with Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_filteredTimeOffs.length} Hasil',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Color(0xFF6B7280)),
                  onSelected: (value) {
                    // Handle sorting
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'date',
                      child: Text('Tanggal Terbaru'),
                    ),
                    const PopupMenuItem(
                      value: 'urgent',
                      child: Text('Paling Urgent'),
                    ),
                    const PopupMenuItem(
                      value: 'name',
                      child: Text('Nama Karyawan'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List Content
          Expanded(
            child: _filteredTimeOffs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    itemCount: _filteredTimeOffs.length,
                    itemBuilder: (context, index) {
                      return _buildTimeOffCard(_filteredTimeOffs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _users.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                return _buildEmployeeCard(_users[index]);
              },
            ),
    );
  }

  Widget _buildReportsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
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
                const Icon(Icons.assessment, color: Colors.white, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Laporan HRD',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 20),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Analisis dan laporan komprehensif time off karyawan',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Report Actions
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isTablet ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildReportCard(
                title: 'Laporan Bulanan',
                icon: Icons.calendar_today,
                color: const Color(0xFF3B82F6),
                onTap: () {},
              ),
              _buildReportCard(
                title: 'Laporan Tahunan',
                icon: Icons.date_range,
                color: const Color(0xFF10B981),
                onTap: () {},
              ),
              _buildReportCard(
                title: 'Per Departemen',
                icon: Icons.business,
                color: const Color(0xFFF59E0B),
                onTap: () {},
              ),
              _buildReportCard(
                title: 'Per Karyawan',
                icon: Icons.person,
                color: const Color(0xFF8B5CF6),
                onTap: () {},
              ),
              _buildReportCard(
                title: 'Tren Cuti',
                icon: Icons.trending_up,
                color: const Color(0xFFEF4444),
                onTap: () {},
              ),
              _buildReportCard(
                title: 'Export Data',
                icon: Icons.download,
                color: const Color(0xFF6B7280),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Summary Statistics
          _buildReportSummary(),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _buildSummaryItem(
            'Total Hari Cuti Digunakan',
            '${_calculateTotalDaysUsed()} hari',
          ),
          _buildSummaryItem(
            'Rata-rata Cuti per Karyawan',
            '${_calculateAverageDays()} hari',
          ),
          _buildSummaryItem(
            'Departemen Paling Aktif',
            _getMostActiveDepartment(),
          ),
          _buildSummaryItem('Tingkat Approval', '${_calculateApprovalRate()}%'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalDaysUsed() {
    return _allTimeOffs
        .where((item) => item.status == 'Approved')
        .fold(0, (sum, item) => sum + item.totalHari);
  }

  double _calculateAverageDays() {
    if (_users.isEmpty) return 0;
    return _calculateTotalDaysUsed() / _users.length;
  }

  String _getMostActiveDepartment() {
    if (_departmentStats.isEmpty) return 'N/A';
    var sorted = _departmentStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  double _calculateApprovalRate() {
    if (_statistics == null || _statistics!.totalSubmissions == 0) return 0;
    return (_statistics!.approvedCount / _statistics!.totalSubmissions * 100);
  }

  Widget _buildDepartmentFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedDepartment,
      decoration: InputDecoration(
        labelText: 'Departemen',
        labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(
        fontSize: _getResponsiveFontSize(context, 14),
        color: Colors.black,
      ),
      items: _departments.map((dept) {
        return DropdownMenuItem(
          value: dept == 'Semua Departemen' ? null : dept,
          child: Text(dept, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDepartment = value;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildTimeRangeFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedTimeRange,
      decoration: InputDecoration(
        labelText: 'Periode',
        labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(
        fontSize: _getResponsiveFontSize(context, 14),
        color: Colors.black,
      ),
      items: _timeRangeOptions.map((range) {
        return DropdownMenuItem(
          value: range,
          child: Text(range, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedTimeRange = value;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(
        fontSize: _getResponsiveFontSize(context, 14),
        color: Colors.black,
      ),
      items: _statusOptions.map((status) {
        return DropdownMenuItem(
          value: status == 'Semua Status' ? null : status,
          child: Text(
            status == 'Semua Status'
                ? status
                : TimeOffAdminService.getStatusDisplayName(status),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedStatus = value;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildUserFilter() {
    final userOptions =
        ['Semua User'] + _users.map((user) => user.name).toList();

    return DropdownButtonFormField<String>(
      value: _selectedUserId == null
          ? 'Semua User'
          : _users.firstWhere((u) => u.userId == _selectedUserId).name,
      decoration: InputDecoration(
        labelText: 'Karyawan',
        labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(
        fontSize: _getResponsiveFontSize(context, 14),
        color: Colors.black,
      ),
      isExpanded: true,
      items: userOptions.map((userName) {
        return DropdownMenuItem(
          value: userName,
          child: Text(userName, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          if (value == 'Semua User') {
            _selectedUserId = null;
          } else {
            _selectedUserId = _users.firstWhere((u) => u.name == value).userId;
          }
          _applyFilters();
        });
      },
    );
  }

  Widget _buildTimeOffCard(AdminTimeOffData item, {bool isUrgent = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with urgent indicator
              Row(
                children: [
                  if (isUrgent) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.priority_high,
                            size: 12,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 10),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(item.jenisIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.jenisTimeOff,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: item.statusColorValue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.statusText,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: item.statusColorValue,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // User info with department
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    child: Text(
                      item.userName.isNotEmpty
                          ? item.userName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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
                            fontSize: _getResponsiveFontSize(context, 14),
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${item.userJob ?? 'No Position'} • ${item.userDepartment ?? 'No Dept'}',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Date and days info
              Container(
                padding: const EdgeInsets.all(12),
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
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.formattedDate,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 13),
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.totalHari} hari',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (item.status == 'Pending') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Diajukan ${item.daysSinceSubmitted} hari yang lalu',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: item.urgencyColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (isTablet)
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _quickReview(item, 'Rejected'),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Tolak'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _quickReview(item, 'Approved'),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Setujui'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
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
  }

  Widget _buildEmployeeCard(UserWithTimeOffs user) {
    final balance = _leaveBalances[user.userId] ?? 21.0;
    final isLowBalance = balance < 7;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedUserId = user.userId;
            _tabController.animateTo(1);
            _applyFilters();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 16),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${user.jobs ?? 'No Position'} • ${user.department ?? 'No Dept'}',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLowBalance)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 12,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Low Balance',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 10),
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Leave Balance Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sisa Cuti',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '${balance.toInt()} / 21 hari',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: isLowBalance
                              ? Colors.red
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: balance / 21,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLowBalance ? Colors.red : const Color(0xFF10B981),
                    ),
                    minHeight: 6,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Statistics
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

  Widget _buildUserStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 11),
            color: const Color(0xFF6B7280),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                size: 64,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak Ada Data',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada data yang sesuai dengan filter',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTimeOffsWithFilter(String filterType) {
    _tabController.animateTo(1);

    setState(() {
      switch (filterType) {
        case 'all':
          _selectedStatus = null;
          break;
        case 'Pending':
          _selectedStatus = 'Pending';
          break;
        case 'Approved':
          _selectedStatus = 'Approved';
          break;
        case 'Rejected':
          _selectedStatus = 'Rejected';
          break;
        case 'Processed':
          _selectedStatus = 'Processed';
          break;
        default:
          _selectedStatus = null;
      }

      _selectedUserId = null;
      _selectedDepartment = null;
      _searchController.clear();
      _applyFilters();
    });

    String filterMessage = '';
    switch (filterType) {
      case 'all':
        filterMessage = 'Menampilkan semua pengajuan time off';
        break;
      case 'Pending':
        filterMessage = 'Menampilkan time off menunggu review';
        break;
      case 'Approved':
        filterMessage = 'Menampilkan time off yang disetujui';
        break;
      case 'Rejected':
        filterMessage = 'Menampilkan time off yang ditolak';
        break;
      case 'Processed':
        filterMessage = 'Menampilkan time off yang sudah diproses';
        break;
    }

    if (filterMessage.isNotEmpty) {
      _showSuccessSnackBar(filterMessage);
    }
  }

  Future<void> _quickReview(AdminTimeOffData item, String status) async {
    setState(() {
      // Update local state optimistically
    });

    try {
      final response = await TimeOffAdminService.reviewTimeOff(
        id: item.id,
        status: status,
        approvedBy: _currentUserName!,
        adminId: _currentUserId!,
      );

      if (response.success) {
        await _refreshData();
        _showSuccessSnackBar(
          status == 'Approved' ? 'Pengajuan disetujui' : 'Pengajuan ditolak',
        );
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }
}

// HRD Specific Detail Modal
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
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _reviewNotesController.dispose();
    _reviewNotesFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reviewTimeOff(String status) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
    });

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
        _showSuccessSnackBar(response.message);
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Indicator
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
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment, color: Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    const Text(
                      'Detail Pengajuan Time Off',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const Spacer(),
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

              // Content
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
                                color: widget.item.urgencyColor.withOpacity(
                                  0.1,
                                ),
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

                      // Employee Information Card
                      _buildInfoCard(
                        title: 'Informasi Karyawan',
                        icon: Icons.person,
                        children: [
                          _buildDetailRow('Nama', widget.item.userName),
                          _buildDetailRow('Email', widget.item.userEmail),
                          if (widget.item.userPhone != null)
                            _buildDetailRow('Telepon', widget.item.userPhone!),
                          if (widget.item.userJob != null)
                            _buildDetailRow('Posisi', widget.item.userJob!),
                          if (widget.item.userDepartment != null)
                            _buildDetailRow(
                              'Departemen',
                              widget.item.userDepartment!,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Time Off Details Card
                      _buildInfoCard(
                        title: 'Detail Cuti',
                        icon: Icons.calendar_today,
                        children: [
                          _buildDetailRow(
                            'Jenis Cuti',
                            widget.item.jenisTimeOff,
                          ),
                          _buildDetailRow('Periode', widget.item.formattedDate),
                          _buildDetailRow(
                            'Total Hari',
                            '${widget.item.totalHari} hari',
                          ),
                          if (widget.item.catatan != null)
                            _buildDetailRow(
                              'Alasan/Catatan',
                              widget.item.catatan!,
                            ),
                          _buildDetailRow(
                            'Tanggal Pengajuan',
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(widget.item.submittedAt),
                          ),
                        ],
                      ),

                      // File attachment if exists
                      if (widget.item.hasFile) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          title: 'Dokumen Pendukung',
                          icon: Icons.attachment,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: const Center(
                                  child: Text('Preview dokumen'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Review section for pending items
                      if (widget.item.status == 'Pending') ...[
                        const SizedBox(height: 20),
                        Text(
                          'Catatan Review HRD',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reviewNotesController,
                          focusNode: _reviewNotesFocusNode,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText:
                                'Tambahkan catatan untuk keputusan Anda...',
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

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                child: SafeArea(
                  child: _isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : _buildActionButtons(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
              Icon(icon, size: 20, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
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
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.item.status == 'Pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _reviewTimeOff('Rejected'),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Tolak'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
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
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Setujui'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox();
    }
  }
}

// Extension for UserWithTimeOffs to add department
extension UserWithTimeOffsExtension on UserWithTimeOffs {
  String? get department {
    // This would normally come from your API
    // For now, returning a mock value
    final depts = ['IT', 'HR', 'Finance', 'Marketing', 'Operations'];
    return depts[userId.hashCode % depts.length];
  }
}

// Extension for AdminTimeOffData to add department
extension AdminTimeOffDataExtension on AdminTimeOffData {
  String? get userDepartment {
    // This would normally come from your API
    // For now, returning a mock value based on job
    if (userJob?.contains('Developer') ?? false) return 'IT';
    if (userJob?.contains('HR') ?? false) return 'HR';
    if (userJob?.contains('Finance') ?? false) return 'Finance';
    if (userJob?.contains('Marketing') ?? false) return 'Marketing';
    return 'Operations';
  }
}
