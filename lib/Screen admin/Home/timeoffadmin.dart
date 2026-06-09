// screens/time_off_admin_screen.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/model/timeoffmodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/timeoffserviceadmin.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Screen HRD/Home/timeoffhrd.dart';

class TimeOffAdminScreen extends StatefulWidget {
  const TimeOffAdminScreen({super.key});

  @override
  _TimeOffAdminScreenState createState() => _TimeOffAdminScreenState();
}

class _TimeOffAdminScreenState extends State<TimeOffAdminScreen>
    with SingleTickerProviderStateMixin {
  List<AdminTimeOffData> _allTimeOffs = [];
  List<AdminTimeOffData> _filteredTimeOffs = [];
  List<UserWithTimeOffs> _users = [];
  TimeOffAdminStatistics? _statistics;

  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;
  String? _selectedStatus;
  String? _selectedUserId;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusOptions = [
    'Semua Status',
    'Pending HRD',
    'Pending Director',
    'Approved',
    'Rejected',
    'Processed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    _searchController.addListener(_applyFilters);
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
      _currentUserRole = prefs.getString('Role');

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

  double _fs(double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return base - 2;
    if (w < 400) return base - 1;
    return base;
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
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _snackErr('Gagal memuat data: $e');
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
      int priority(AdminTimeOffData x) {
        if (x.isPendingDirector) return 0;
        if (x.isPendingHrd) return 1;
        if (x.status.toLowerCase() == 'pending') return 2;
        return 3;
      }

      final pa = priority(a), pb = priority(b);
      if (pa != pb) return pa.compareTo(pb);
      return b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted);
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
      builder: (_) => TimeOffDetailModal(
        item: item,
        currentAdminId: _currentUserId!,
        currentAdminName: _currentUserName!,
        currentAdminRole: _currentUserRole ?? '',
        onActionCompleted: _refreshData,
      ),
    );
  }

  void _navFilter(String filter) {
    _tabController.animateTo(1);
    setState(() {
      _selectedStatus = filter == 'all' ? null : filter;
      _selectedUserId = null;
      _searchController.clear();
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Manajemen Izin',
          style: TextStyle(
            fontSize: _fs(20),
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
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
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Pengajuan'),
            Tab(icon: Icon(Icons.people, size: 18), text: 'Karyawan'),
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
                    'Memuat data...',
                    style: TextStyle(
                      fontSize: _fs(16),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : _currentUserId == null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildTimeOffsTab(),
                _buildUsersTab(),
              ],
            ),
    );
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Widget _buildDashboardTab() => RefreshIndicator(
    onRefresh: _refreshData,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(),
          const SizedBox(height: 24),
          if (_statistics != null) _buildStatisticsCards(_statistics!),
          const SizedBox(height: 24),
          _buildPendingDirectorSection(),
          const SizedBox(height: 24),
          _buildQuickActions(),
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
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
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
                'Selamat Datang',
                style: TextStyle(fontSize: _fs(12), color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                _currentUserName ?? 'Administrator',
                style: TextStyle(
                  fontSize: _fs(17),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentUserRole?.toUpperCase() ?? 'ADMIN',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildStatisticsCards(TimeOffAdminStatistics stats) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Statistik Pengajuan',
        style: TextStyle(
          fontSize: _fs(17),
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1F2937),
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (_, c) => GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: c.maxWidth > 500 ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: c.maxWidth > 500 ? 1.4 : 1.3,
          children: [
            _buildStatCard(
              title: 'Total',
              value: stats.totalSubmissions.toString(),
              icon: Icons.calendar_month,
              color: const Color(0xFF6366F1),
              onTap: () => _navFilter('all'),
            ),
            _buildStatCard(
              title: 'Pending Director',
              value: _allTimeOffs
                  .where((i) => i.isPendingDirector)
                  .length
                  .toString(),
              icon: Icons.account_balance,
              color: const Color(0xFF8B5CF6),
              urgent: true,
              onTap: () => _navFilter('Pending Director'),
            ),
            _buildStatCard(
              title: 'Disetujui',
              value: stats.approvedCount.toString(),
              icon: Icons.check_circle,
              color: const Color(0xFF10B981),
              onTap: () => _navFilter('Approved'),
            ),
            _buildStatCard(
              title: 'Ditolak',
              value: stats.rejectedCount.toString(),
              icon: Icons.cancel,
              color: const Color(0xFFEF4444),
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
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
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

  Widget _buildPendingDirectorSection() {
    final pendingDir = _allTimeOffs
        .where((i) => i.isPendingDirector)
        .take(3)
        .toList();

    if (pendingDir.isEmpty) {
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
              'Tidak ada pengajuan yang menunggu persetujuan Anda',
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    size: 16,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Menunggu Persetujuan Anda',
                  style: TextStyle(
                    fontSize: _fs(15),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _navFilter('Pending Director'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pendingDir.map(
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildTimeOffCard(i),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Aksi Cepat',
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
              title: 'Pending Director',
              subtitle:
                  '${_allTimeOffs.where((i) => i.isPendingDirector).length} menunggu persetujuan',
              icon: Icons.account_balance,
              color: const Color(0xFF8B5CF6),
              onTap: () => _navFilter('Pending Director'),
            ),
            _buildQuickActionCard(
              title: 'Semua Pengajuan',
              subtitle: '${_allTimeOffs.length} total pengajuan',
              icon: Icons.list_alt,
              color: const Color(0xFF6366F1),
              onTap: () => _navFilter('all'),
            ),
          ],
        ),
      ),
    ],
  );

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

  // ── Time Offs Tab ─────────────────────────────────────────────────────────

  Widget _buildTimeOffsTab() => RefreshIndicator(
    onRefresh: _refreshData,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama, jenis izin...',
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
              Row(
                children: [
                  Expanded(child: _buildStatusFilter()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildUserFilter()),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filteredTimeOffs.length} Hasil',
                  style: TextStyle(
                    fontSize: _fs(13),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
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
              s == 'Semua Status' ? s : _getStatusLabel(s),
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

  Widget _buildUserFilter() {
    final opts = ['Semua User'] + _users.map((u) => u.name).toList();
    final currentName = _selectedUserId == null
        ? 'Semua User'
        : (_users.any((u) => u.userId == _selectedUserId)
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

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending hrd':
        return 'Menunggu HRD';
      case 'pending director':
        return 'Menunggu Direktur';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'processed':
        return 'Diproses';
      default:
        return status;
    }
  }

  Widget _buildTimeOffCard(AdminTimeOffData item) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: item.isPendingDirector ? 4 : 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: item.isPendingDirector
          ? const BorderSide(color: Color(0xFF8B5CF6), width: 1)
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
            // ── Row 1: icon + jenis + status badge ──────────────
            Row(
              children: [
                Text(item.jenisIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
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

            // ── Badge pending director ───────────────────────────
            if (item.isPendingDirector) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance,
                      size: 11,
                      color: Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sudah disetujui HRD — menunggu persetujuan Anda',
                      style: TextStyle(
                        fontSize: _fs(10),
                        color: const Color(0xFF6D28D9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Row 2: avatar + nama + posisi ────────────────────
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

            // ── Row 3: tanggal + total hari ──────────────────────
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

            // ── Tombol approve/reject (hanya Pending Director) ───
            if (item.isPendingDirector) ...[
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
                        'Diajukan ${item.daysSinceSubmitted} hari lalu',
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
                        onPressed: () => _quickApprove(item, 'Rejected'),
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Tolak'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _quickApprove(item, 'Approved'),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Setujui'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
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

  Future<void> _quickApprove(AdminTimeOffData item, String status) async {
    try {
      final resp = await TimeOffService.directorReview(
        id: item.id,
        status: status,
        directorUserId: _currentUserId!,
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

  // ── Users Tab ─────────────────────────────────────────────────────────────

  Widget _buildUsersTab() => RefreshIndicator(
    onRefresh: _refreshData,
    child: _users.isEmpty
        ? _buildEmptyState()
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (_, i) => _buildUserCard(_users[i]),
          ),
  );

  Widget _buildUserCard(UserWithTimeOffs user) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w700,
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
                  fontSize: _fs(14),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                user.jobPosition ?? user.jobs ?? '-',
                style: TextStyle(
                  fontSize: _fs(11),
                  color: const Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMiniStat(
              'Total',
              user.totalTimeOff.toString(),
              const Color(0xFF6366F1),
            ),
            const SizedBox(height: 4),
            _buildMiniStat(
              'Approved',
              user.approvedCount.toString(),
              const Color(0xFF10B981),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildMiniStat(String label, String value, Color color) => Row(
    children: [
      Text(
        '$label: ',
        style: TextStyle(fontSize: _fs(11), color: const Color(0xFF6B7280)),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: _fs(11),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );

  // ── Empty / Error State ───────────────────────────────────────────────────

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
}

// ══════════════════════════════════════════════════════════════════════════════
// TimeOffDetailModal — untuk Direktur/Admin
// ══════════════════════════════════════════════════════════════════════════════

class TimeOffDetailModal extends StatefulWidget {
  final AdminTimeOffData item;
  final String currentAdminId;
  final String currentAdminName;
  final String currentAdminRole;
  final VoidCallback onActionCompleted;

  const TimeOffDetailModal({
    super.key,
    required this.item,
    required this.currentAdminId,
    required this.currentAdminName,
    required this.currentAdminRole,
    required this.onActionCompleted,
  });

  @override
  _TimeOffDetailModalState createState() => _TimeOffDetailModalState();
}

class _TimeOffDetailModalState extends State<TimeOffDetailModal> {
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _review(String status) async {
    FocusScope.of(context).unfocus();
    setState(() => _isProcessing = true);
    try {
      // Direktur hanya bisa review Pending Director
      dynamic response;
      if (widget.item.isPendingDirector) {
        response = await TimeOffService.directorReview(
          id: widget.item.id,
          status: status,
          directorUserId: widget.currentAdminId,
          rejectionReason: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      } else {
        // Status lain tidak bisa direview dari screen ini
        _snack(
          'Pengajuan ini tidak dalam status yang bisa Anda review.',
          err: true,
        );
        setState(() => _isProcessing = false);
        return;
      }

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

  void _snack(String msg, {required bool err}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
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
            // Handle
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
                      'Detail Pengajuan',
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
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
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
                        if (widget.item.isPendingDirector) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Menunggu Persetujuan Anda',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Info Karyawan
                    _buildInfoCard('Informasi Karyawan', Icons.person, [
                      _row('Nama', widget.item.userName),
                      _row('Email', widget.item.userEmail),
                      if (widget.item.userPhone != null)
                        _row('Telepon', widget.item.userPhone!),
                      if (widget.item.userJob != null)
                        _row('Posisi', widget.item.userJob!),
                    ]),
                    const SizedBox(height: 16),

                    // Detail Izin
                    _buildInfoCard('Detail Izin', Icons.calendar_today, [
                      _row('Jenis Izin', widget.item.jenisTimeOff),
                      _row('Periode', widget.item.formattedDate),
                      _row('Total Hari', '${widget.item.totalHari} hari'),
                      if (widget.item.catatan != null)
                        _row('Catatan', widget.item.catatan!),
                      _row(
                        'Tanggal Pengajuan',
                        widget.item.formattedSubmittedDate,
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Info approval HRD
                    if (widget.item.isPendingDirector) ...[
                      _buildInfoCard('Riwayat Approval HRD', Icons.how_to_reg, [
                        _row('Status HRD', 'Sudah Disetujui ✅'),
                        if (widget.item.approvedBy != null)
                          _row('Disetujui oleh', widget.item.approvedBy!),
                        if (widget.item.approvedAt != null)
                          _row(
                            'Tanggal',
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(widget.item.approvedAt!),
                          ),
                      ]),
                      const SizedBox(height: 20),

                      // Catatan review
                      const Text(
                        'Catatan Penolakan (Opsional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Isi jika ingin menambah catatan penolakan...',
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                            Icons.note_add,
                            color: Color(0xFF8B5CF6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
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
            // Action buttons
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

  Widget _buildActionButtons() {
    if (!widget.item.isPendingDirector) return const SizedBox();
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance,
                size: 15,
                color: Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengajuan ini sudah disetujui HRD dan menunggu persetujuan Anda sebagai Direktur.',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF6D28D9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _review('Rejected'),
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
                onPressed: () => _review('Approved'),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Setujui'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
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
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) =>
      Container(
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

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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
}
