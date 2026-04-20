// screens/time_off_admin_screen.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/model/timeoffmodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/timeoffserviceadmin.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _selectedStatus;
  String? _selectedUserId;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusOptions = [
    'Semua Status',
    'Pending',
    'Approved',
    'Rejected',
    'Processed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                style: TextStyle(fontWeight: FontWeight.w500),
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
        return TimeOffDetailModal(
          item: item,
          currentAdminId: _currentUserId!,
          currentAdminName: _currentUserName!,
          onActionCompleted: _refreshData,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Admin Time Off',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: 0.3,
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
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Time Offs'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B82F6),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data admin...',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 16),
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : _currentUserId == null || _currentUserName == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data User Tidak Ditemukan',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 20),
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Silakan login ulang untuk mengakses halaman admin.',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        color: Color(0xFF6B7280),
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
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
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

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: const EdgeInsets.all(20),
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
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat Datang, Admin',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _currentUserName ?? 'Administrator',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Statistics Cards
            if (_statistics != null) _buildStatisticsCards(_statistics!),

            const SizedBox(height: 24),

            // Recent Urgent Items
            _buildUrgentItems(),

            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOffsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan judul, kategori, atau nama...',
                    hintStyle: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Row
                Row(
                  children: [
                    Expanded(child: _buildStatusFilter()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildUserFilter()),
                  ],
                ),
              ],
            ),
          ),

          // List Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Text(
                  'Daftar Time Off',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filteredTimeOffs.length} data',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // List Content
          Expanded(
            child: _filteredTimeOffs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
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

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _users.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                return _buildUserCard(_users[index]);
              },
            ),
    );
  }

  Widget _buildStatisticsCards(TimeOffAdminStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik Time Off',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),

        // Overview Cards dengan navigasi
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Pengajuan',
                value: stats.totalSubmissions.toString(),
                icon: Icons.calendar_month,
                color: const Color(0xFF3B82F6),
                onTap: () =>
                    _navigateToTimeOffsWithFilter('all'), // ← Tambahkan onTap
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Menunggu Review',
                value: stats.pendingCount.toString(),
                icon: Icons.pending_actions,
                color: const Color(0xFFF59E0B),
                onTap: () => _navigateToTimeOffsWithFilter(
                  'Pending',
                ), // ← Tambahkan onTap
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Status Cards dengan navigasi
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Disetujui',
                value: stats.approvedCount.toString(),
                icon: Icons.check_circle,
                color: const Color(0xFF10B981),
                onTap: () => _navigateToTimeOffsWithFilter(
                  'Approved',
                ), // ← Tambahkan onTap
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Ditolak',
                value: stats.rejectedCount.toString(),
                icon: Icons.cancel,
                color: const Color(0xFFEF4444),
                onTap: () => _navigateToTimeOffsWithFilter(
                  'Rejected',
                ), // ← Tambahkan onTap
              ),
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
    VoidCallback? onTap, // ← Tambahkan parameter onTap
  }) {
    return InkWell(
      // ← Wrap dengan InkWell untuk tap functionality
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          // Tambahkan shadow subtle saat bisa diklik
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                // Tambahkan icon arrow jika bisa diklik
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Color(0xFF9CA3AF),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTimeOffsWithFilter(String filterType) {
    // Pindah ke tab Time Offs (index 1)
    _tabController.animateTo(1);

    // Set filter sesuai tipe yang diklik
    setState(() {
      switch (filterType) {
        case 'all':
          _selectedStatus = null; // Semua Status
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

      // Reset user filter dan search
      _selectedUserId = null;
      _searchController.clear();

      // Apply filters
      _applyFilters();
    });

    // Tampilkan feedback ke user
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

  Widget _buildUrgentItems() {
    final urgentItems = _allTimeOffs
        .where(
          (item) => item.status == 'Pending' && item.daysSinceSubmitted > 3,
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
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 12),
            Text(
              'Tidak ada item urgent yang perlu direview',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Urgent',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
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

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aksi Cepat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Review Pending',
                subtitle: '${_statistics?.pendingCount ?? 0} item',
                icon: Icons.pending_actions,
                color: const Color(0xFFF59E0B),
                onTap: () => _navigateToTimeOffsWithFilter(
                  'Pending',
                ), // ← Konsisten dengan navigasi
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Mark Processed',
                subtitle: '${_statistics?.approvedCount ?? 0} approved',
                icon: Icons.check_circle,
                color: const Color(0xFF10B981),
                onTap: () => _navigateToTimeOffsWithFilter(
                  'Approved',
                ), // ← Konsisten dengan navigasi
              ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 14)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        labelText: 'User',
        labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 14)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: TextStyle(
        fontSize: _getResponsiveFontSize(context, 14),
        color: Colors.black,
      ),
      items: userOptions.map((userName) {
        return DropdownMenuItem(value: userName, child: Text(userName));
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
          padding: const EdgeInsets.all(16),
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
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(item.jenisIcon, style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.jenisTimeOff,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.statusColorValue,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // User info
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.userName} - ${item.userJob ?? 'No Job'}',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date and days
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.formattedDate,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${item.totalHari} hari',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Submitted date and urgency
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.formattedSubmittedDate,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  if (item.status == 'Pending')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.urgencyColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.daysSinceSubmitted} hari',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.urgencyColor,
                        ),
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

  Widget _buildUserCard(UserWithTimeOffs user) {
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
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (user.jobs != null)
                          Text(
                            user.jobs!,
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 14),
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildUserStatItem(
                      'Total',
                      user.totalTimeOff.toString(),
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildUserStatItem(
                      'Pending',
                      user.pendingCount.toString(),
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildUserStatItem(
                      'Approved',
                      user.approvedCount.toString(),
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildUserStatItem(
                      'Days',
                      '${user.totalApprovedDays}',
                      Colors.purple,
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

  Widget _buildUserStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Tidak Ada Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Belum ada data yang sesuai dengan filter',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimeOffDetailModal extends StatefulWidget {
  final AdminTimeOffData item;
  final String currentAdminId;
  final String currentAdminName;
  final VoidCallback onActionCompleted;

  const TimeOffDetailModal({
    super.key,
    required this.item,
    required this.currentAdminId,
    required this.currentAdminName,
    required this.onActionCompleted,
  });

  @override
  _TimeOffDetailModalState createState() => _TimeOffDetailModalState();
}

class _TimeOffDetailModalState extends State<TimeOffDetailModal> {
  final TextEditingController _reviewNotesController = TextEditingController();
  final FocusNode _reviewNotesFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _textFieldKey = GlobalKey();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Listen to focus changes
    _reviewNotesFocusNode.addListener(() {
      if (_reviewNotesFocusNode.hasFocus) {
        _scrollToTextField();
      }
    });
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    _reviewNotesFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Improved scroll function dengan delay yang lebih panjang
  void _scrollToTextField() {
    // Delay untuk memastikan keyboard sudah sepenuhnya muncul
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

      if (keyboardHeight > 0 && _scrollController.hasClients) {
        // Scroll ke posisi maksimum + padding ekstra untuk memastikan TextField terlihat
        final maxScrollExtent = _scrollController.position.maxScrollExtent;
        final extraPadding =
            keyboardHeight *
            0.5; // 50% dari tinggi keyboard sebagai padding ekstra

        _scrollController.animateTo(
          maxScrollExtent + extraPadding,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
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
        approvedBy: widget.currentAdminName, // Kirim nama admin
        rejectionReason: _reviewNotesController.text.trim().isNotEmpty
            ? _reviewNotesController.text.trim()
            : null,
        adminId: widget.currentAdminId,
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

  Future<void> _markAsProcessed() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await TimeOffAdminService.markAsProcessed(
        id: widget.item.id,
        processedBy: widget.currentAdminName, // Kirim nama, bukan ID
        adminId: widget.currentAdminId,
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

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // Gunakan MediaQuery untuk menghitung tinggi yang tersedia
        height:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).viewInsets.bottom,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header - Fixed at top
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Detail Time Off',
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

            // Scrollable content yang akan menggunakan sisa ruang yang tersedia
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and urgency
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

                    // User Information
                    _buildInfoSection('Informasi Pengaju', [
                      _buildDetailRow('Nama', widget.item.userName),
                      _buildDetailRow('Email', widget.item.userEmail),
                      if (widget.item.userPhone != null)
                        _buildDetailRow('Telepon', widget.item.userPhone!),
                      if (widget.item.userJob != null)
                        _buildDetailRow('Pekerjaan', widget.item.userJob!),
                    ]),

                    const SizedBox(height: 20),

                    // Time Off Details
                    _buildInfoSection('Detail Time Off', [
                      _buildDetailRow('Jenis', widget.item.jenisTimeOff),
                      _buildDetailRow('Periode', widget.item.formattedDate),
                      _buildDetailRow(
                        'Total Hari',
                        '${widget.item.totalHari} hari',
                      ),
                      if (widget.item.catatan != null)
                        _buildDetailRow('Catatan', widget.item.catatan!),
                      _buildDetailRow(
                        'Tanggal Pengajuan',
                        _formatDateTime(widget.item.submittedAt),
                      ),
                      _buildDetailRow(
                        'Hari Sejak Pengajuan',
                        '${widget.item.daysSinceSubmitted} hari',
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // File attachment
                    if (widget.item.hasFile) ...[
                      _buildInfoSection('File Lampiran', [
                        _buildDetailRow(
                          'Nama File',
                          widget.item.fileName ?? 'Unknown',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FutureBuilder<Map<String, String>>(
                              future: TimeOffAdminService.getAdminHeaders(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.network(
                                    TimeOffAdminService.getFileImageUrl(
                                      widget.item.id,
                                    ),
                                    headers: snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.error,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 8),
                                            Text('Gagal memuat file'),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // Review History
                    if (widget.item.approvedAt != null) ...[
                      _buildInfoSection('Riwayat Review', [
                        _buildDetailRow(
                          'Direview oleh',
                          widget.item.approvedBy ?? 'Unknown',
                        ),
                        _buildDetailRow(
                          'Tanggal Review',
                          _formatDateTime(widget.item.approvedAt!),
                        ),
                        if (widget.item.rejectionReason != null)
                          _buildDetailRow(
                            'Alasan Penolakan',
                            widget.item.rejectionReason!,
                          ),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // Review Notes Input (for pending items)
                    if (widget.item.status == 'Pending') ...[
                      const Text(
                        'Catatan Review (Opsional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // TextField dengan key untuk tracking
                      TextFormField(
                        key: _textFieldKey,
                        controller: _reviewNotesController,
                        focusNode: _reviewNotesFocusNode,
                        maxLines: 4,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Tambahkan catatan untuk keputusan review...',
                          hintStyle: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(
                            Icons.note_add,
                            color: Color(0xFF3B82F6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 2.0,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          errorStyle: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Extra space untuk memastikan ada ruang scroll yang cukup
                      SizedBox(height: isKeyboardVisible ? 200 : 80),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons - akan otomatis naik ketika keyboard muncul
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
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
            child: ElevatedButton.icon(
              onPressed: () => _reviewTimeOff('Rejected'),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Tolak'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.3),
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
                  borderRadius: BorderRadius.circular(15.0),
                ),
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
        ],
      );
    } else if (widget.item.status == 'Approved') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _markAsProcessed,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Tandai Sebagai Diproses'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.3),
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }
}
