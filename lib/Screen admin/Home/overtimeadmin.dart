// screens/overtime_admin_screen.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/model/overtimemodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/overtimeadminservice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OvertimeAdminScreen extends StatefulWidget {
  const OvertimeAdminScreen({super.key});

  @override
  _OvertimeAdminScreenState createState() => _OvertimeAdminScreenState();
}

class _OvertimeAdminScreenState extends State<OvertimeAdminScreen>
    with SingleTickerProviderStateMixin {
  List<AdminOvertimeData> _allOvertimes = [];
  List<AdminOvertimeData> _filteredOvertimes = [];
  List<UserWithOvertimes> _users = [];
  OvertimeAdminStatistics? _statistics;

  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _selectedStatus;
  String? _selectedUserId;
  bool _isSelectionMode = false;
  Set<int> _selectedItems = {};

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusOptions = OvertimeFilterOptions.statusOptions;

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

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures =
          await Future.wait([
            OvertimeAdminService.getAllOvertimes(adminId: _currentUserId!),
            OvertimeAdminService.getUsersWithOvertimes(
              adminId: _currentUserId!,
            ),
            OvertimeAdminService.getAdminStatistics(),
          ]).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. Silakan coba lagi.');
            },
          );

      setState(() {
        _allOvertimes =
            (futures[0] as ApiResponse<List<AdminOvertimeData>>).data ?? [];
        _users =
            (futures[1] as ApiResponse<List<UserWithOvertimes>>).data ?? [];
        _statistics = (futures[2] as ApiResponse<OvertimeAdminStatistics>).data;
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

  void _applyFilters() {
    List<AdminOvertimeData> filtered = _allOvertimes;

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
        return item.userName.toLowerCase().contains(searchKeyword) ||
            (item.userJob?.toLowerCase().contains(searchKeyword) ?? false) ||
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
      _filteredOvertimes = filtered;
      _selectedItems.clear(); // Clear selection when filter changes
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

  void _showOvertimeDetail(AdminOvertimeData item) {
    if (_currentUserId == null || _currentUserName == null) {
      _showErrorSnackBar('Data user belum dimuat. Silakan tunggu sebentar.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return OvertimeDetailModal(
          item: item,
          currentAdminId: _currentUserId!,
          currentAdminName: _currentUserName!,
          onActionCompleted: _refreshData,
        );
      },
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(int id) {
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
      } else {
        _selectedItems.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedItems = _filteredOvertimes
          .where((item) => item.canBeModified)
          .map((item) => item.id)
          .toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedItems.clear();
    });
  }

  Future<void> _bulkAction(String action) async {
    if (_selectedItems.isEmpty) {
      _showErrorSnackBar('Pilih minimal satu item');
      return;
    }

    String? rejectionReason;
    if (action == 'reject') {
      rejectionReason = await _showRejectionReasonDialog();
      if (rejectionReason == null) return; // User cancelled
    }

    final confirmed = await _showBulkActionDialog(
      action,
      _selectedItems.length,
    );
    if (!confirmed) return;

    try {
      final response = await OvertimeAdminService.bulkAction(
        ids: _selectedItems.toList(),
        action: action,
        approvedBy: _currentUserId!,
        rejectionReason: rejectionReason,
        adminId: _currentUserId!,
      );

      if (response.success) {
        _showSuccessSnackBar(response.message);
        setState(() {
          _isSelectionMode = false;
          _selectedItems.clear();
        });
        _refreshData();
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  Future<bool> _showBulkActionDialog(String action, int count) async {
    final actionText = action == 'approve' ? 'menyetujui' : 'menolak';
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Konfirmasi $actionText'),
            content: Text(
              'Apakah Anda yakin ingin $actionText $count item yang dipilih?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(actionText == 'menyetujui' ? 'Setujui' : 'Tolak'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showRejectionReasonDialog() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alasan Penolakan'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Masukkan alasan penolakan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedItems.length} dipilih'
              : 'Admin Overtime',
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
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.arrow_back_ios,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () {
              if (_isSelectionMode) {
                _toggleSelectionMode();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        actions: _isSelectionMode
            ? _buildSelectionActions()
            : _buildNormalActions(),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Overtimes'),
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
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildOvertimesTab(),
                _buildUsersTab(),
              ],
            ),
      floatingActionButton: _isSelectionMode && _selectedItems.isNotEmpty
          ? _buildBulkActionButtons()
          : null,
    );
  }

  List<Widget> _buildNormalActions() {
    return [
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
    ];
  }

  List<Widget> _buildSelectionActions() {
    return [
      TextButton(
        onPressed:
            _selectedItems.length ==
                _filteredOvertimes.where((item) => item.canBeModified).length
            ? _deselectAll
            : _selectAll,
        child: Text(
          _selectedItems.length ==
                  _filteredOvertimes.where((item) => item.canBeModified).length
              ? 'Batal Pilih'
              : 'Pilih Semua',
        ),
      ),
    ];
  }

  Widget _buildBulkActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FloatingActionButton.extended(
          onPressed: () => _bulkAction('reject'),
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,
          label: Text('Tolak'),
          icon: const Icon(Icons.close),
          heroTag: 'reject',
        ),
        FloatingActionButton.extended(
          onPressed: () => _bulkAction('approve'),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          label: Text('Setujui'),
          icon: const Icon(Icons.check),
          heroTag: 'approve',
        ),
      ],
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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text('Kembali'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
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
                            fontSize: _getResponsiveFontSize(context, 18),
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

  Widget _buildOvertimesTab() {
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
                    hintText: 'Cari berdasarkan nama, jabatan, atau catatan...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSelectionMode
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.checklist),
                            onPressed: _toggleSelectionMode,
                            tooltip: 'Mode Pilih',
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
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
                  'Daftar Overtime',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filteredOvertimes.length} data',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (_isSelectionMode && _selectedItems.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${_selectedItems.length} dipilih)',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // List Content
          Expanded(
            child: _filteredOvertimes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredOvertimes.length,
                    itemBuilder: (context, index) {
                      return _buildOvertimeCard(_filteredOvertimes[index]);
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

  Widget _buildStatisticsCards(OvertimeAdminStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik Overtime',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 18),
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
                icon: Icons.access_time,
                color: const Color(0xFF3B82F6),
                onTap: () =>
                    _navigateToOvertimesWithFilter('all'), // ← Tambahkan onTap
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Menunggu Review',
                value: stats.pendingCount.toString(),
                icon: Icons.pending_actions,
                color: const Color(0xFFF59E0B),
                onTap: () => _navigateToOvertimesWithFilter(
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
                onTap: () => _navigateToOvertimesWithFilter(
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
                onTap: () => _navigateToOvertimesWithFilter(
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
                fontSize: _getResponsiveFontSize(context, 24),
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

  void _navigateToOvertimesWithFilter(String filterType) {
    // Pindah ke tab Overtimes (index 1)
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
        filterMessage = 'Menampilkan semua pengajuan overtime';
        break;
      case 'Pending':
        filterMessage = 'Menampilkan overtime menunggu review';
        break;
      case 'Approved':
        filterMessage = 'Menampilkan overtime yang disetujui';
        break;
      case 'Rejected':
        filterMessage = 'Menampilkan overtime yang ditolak';
        break;
    }

    if (filterMessage.isNotEmpty) {
      _showSuccessSnackBar(filterMessage);
    }
  }

  // Widget _buildHoursRow(String label, String hours, Color color) {
  //   return Row(
  //     children: [
  //       Container(
  //         width: 12,
  //         height: 12,
  //         decoration: BoxDecoration(
  //           color: color,
  //           borderRadius: BorderRadius.circular(6),
  //         ),
  //       ),
  //       const SizedBox(width: 12),
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: _getResponsiveFontSize(context, 14),
  //           color: Color(0xFF6B7280),
  //         ),
  //       ),
  //       const Spacer(),
  //       Text(
  //         hours,
  //         style: TextStyle(
  //           fontSize: _getResponsiveFontSize(context, 14),
  //           fontWeight: FontWeight.w600,
  //           color: Color(0xFF1F2937),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildUrgentItems() {
    final urgentItems = _allOvertimes
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
        Text(
          'Item Urgent',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 18),
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        ...urgentItems.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildOvertimeCard(item, isUrgent: true),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 18),
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
                onTap: () {
                  _tabController.animateTo(1);
                  setState(() {
                    _selectedStatus = 'Pending';
                    _applyFilters();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Bulk Action',
                subtitle: 'Aksi massal',
                icon: Icons.checklist,
                color: const Color(0xFF10B981),
                onTap: () {
                  _tabController.animateTo(1);
                  _toggleSelectionMode();
                },
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
                fontSize: _getResponsiveFontSize(context, 16),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _statusOptions.map((status) {
        return DropdownMenuItem(
          value: status == 'Semua Status' ? null : status,
          child: Text(
            status == 'Semua Status'
                ? status
                : OvertimeAdminService.getStatusDisplayName(status),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildOvertimeCard(AdminOvertimeData item, {bool isUrgent = false}) {
    final isSelected = _selectedItems.contains(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent
            ? const BorderSide(color: Color(0xFFEF4444), width: 1)
            : isSelected
            ? const BorderSide(color: Color(0xFF3B82F6), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_isSelectionMode && item.canBeModified) {
            _toggleItemSelection(item.id);
          } else if (!_isSelectionMode) {
            _showOvertimeDetail(item);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with urgent indicator and selection
              Row(
                children: [
                  if (_isSelectionMode && item.canBeModified) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleItemSelection(item.id),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                  ],
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
                      child: Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 10),
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    item.overtimeIcon,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.formattedDate,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 16),
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
                        fontSize: _getResponsiveFontSize(context, 12),
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

              // Time range and total hours
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.formattedTimeRange,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.formattedTotalJam,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 15),
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
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: item.urgencyColor,
                        ),
                      ),
                    ),
                ],
              ),

              // Catatan
              if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Catatan: ${item.catatan}',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 13),
                      color: Color(0xFF374151),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              // Rejection reason
              if (item.rejectionReason != null &&
                  item.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Alasan ditolak: ${item.rejectionReason}',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 13),
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserWithOvertimes user) {
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
                            fontSize: _getResponsiveFontSize(context, 16),
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
                      user.totalOvertime.toString(),
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
                      'Hours',
                      user.totalApprovedHours.toStringAsFixed(1),
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
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 12),
              color: Color(0xFF6B7280),
            ),
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
                fontSize: _getResponsiveFontSize(context, 18),
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

// Detail Modal Component
class OvertimeDetailModal extends StatefulWidget {
  final AdminOvertimeData item;
  final String currentAdminId;
  final String currentAdminName;
  final VoidCallback onActionCompleted;

  const OvertimeDetailModal({
    super.key,
    required this.item,
    required this.currentAdminId,
    required this.currentAdminName,
    required this.onActionCompleted,
  });

  @override
  _OvertimeDetailModalState createState() => _OvertimeDetailModalState();
}

class _OvertimeDetailModalState extends State<OvertimeDetailModal> {
  final TextEditingController _reviewNotesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _reviewNotesController.dispose();
    super.dispose();
  }

  Future<void> _reviewOvertime(String status) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await OvertimeAdminService.reviewOvertime(
        id: widget.item.id,
        status: status,
        approvedBy: widget.currentAdminName,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Detail Overtime',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Content
          Expanded(
            child: SingleChildScrollView(
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
                          color: widget.item.statusColorValue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.item.statusText,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
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
                              fontSize: _getResponsiveFontSize(context, 14),
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

                  // Overtime Details
                  _buildInfoSection('Detail Overtime', [
                    _buildDetailRow('Tanggal', widget.item.formattedDate),
                    _buildDetailRow('Jam Mulai', widget.item.formattedMulai),
                    _buildDetailRow(
                      'Jam Selesai',
                      widget.item.formattedSelesai,
                    ),
                    _buildDetailRow('Total Jam', widget.item.formattedTotalJam),
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
                    Text(
                      'Catatan Review (Opsional)',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewNotesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tambahkan catatan untuk keputusan review...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons
          if (!_isProcessing) _buildActionButtons(),
          if (_isProcessing) const Center(child: CircularProgressIndicator()),
        ],
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
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
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
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Color(0xFF1E293B),
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
            child: ElevatedButton.icon(
              onPressed: () => _reviewOvertime('Rejected'),
              icon: const Icon(Icons.close),
              label: Text('Tolak'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _reviewOvertime('Approved'),
              icon: const Icon(Icons.check),
              label: Text('Setujui'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
