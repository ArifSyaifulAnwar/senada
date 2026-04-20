// screens/overtime_hrd_screen.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/Home/overtimeadmin.dart';
import 'package:absensikaryawan/Screen%20admin/model/overtimemodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/overtimeadminservice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OvertimeHRDScreen extends StatefulWidget {
  const OvertimeHRDScreen({super.key});

  @override
  _OvertimeHRDScreenState createState() => _OvertimeHRDScreenState();
}

class _OvertimeHRDScreenState extends State<OvertimeHRDScreen>
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

  final List<String> _statusOptions = [
    'Semua Status',
    'Pending',
    'Approved',
    'Rejected',
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

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUserId == null) {
        throw Exception('User ID tidak tersedia. Silakan login ulang.');
      }

      List<AdminOvertimeData> overtimes = [];
      List<UserWithOvertimes> users = [];
      OvertimeAdminStatistics? statistics;

      // Load semua data secara parallel
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

        overtimes =
            (futures[0] as ApiResponse<List<AdminOvertimeData>>).data ?? [];
        users = (futures[1] as ApiResponse<List<UserWithOvertimes>>).data ?? [];
        statistics = (futures[2] as ApiResponse<OvertimeAdminStatistics>).data;
      } catch (e) {
        if (e.toString().toLowerCase().contains('admin') ||
            e.toString().toLowerCase().contains('akses')) {
          _showErrorSnackBar(
            'Akses ditolak: $_currentUserName tidak memiliki hak admin. '
            'Hubungi administrator untuk mendapatkan akses.',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // For other errors, try individual loading
        await _loadDataIndividually();
        return;
      }

      setState(() {
        _allOvertimes = overtimes;
        _users = users;
        _statistics = statistics;
        _applyFilters();
        _isLoading = false;
      });

      // Show appropriate success message
      if (overtimes.isNotEmpty) {
        _showSuccessSnackBar(
          'Data berhasil dimuat: ${overtimes.length} overtime dari ${users.length} user',
        );
      } else if (users.isNotEmpty) {
        _showInfoSnackBar('Sistem siap. Belum ada overtime yang diajukan.');
      } else {
        _showInfoSnackBar('Panel HRD aktif. Menunggu data overtime.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Terjadi kesalahan sistem: $e');
    }
  }

  Future<void> _loadDataIndividually() async {
    List<AdminOvertimeData> overtimes = [];
    List<UserWithOvertimes> users = [];
    OvertimeAdminStatistics? statistics;

    // Load overtimes
    try {
      final response = await OvertimeAdminService.getAllOvertimes(
        adminId: _currentUserId!,
      );
      overtimes = response.data ?? [];
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data overtime: $e');
    }

    // Load users
    try {
      final response = await OvertimeAdminService.getUsersWithOvertimes(
        adminId: _currentUserId!,
      );
      users = response.data ?? [];
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data users: $e');
    }

    // Load statistics
    try {
      final response = await OvertimeAdminService.getAdminStatistics();
      statistics = response.data;
    } catch (e) {
      _showErrorSnackBar('Statistik menggunakan data default');
    }

    setState(() {
      _allOvertimes = overtimes;
      _users = users;
      _statistics = statistics;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
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

    // Filter by status - Case-insensitive comparison
    if (_selectedStatus != null && _selectedStatus != 'Semua Status') {
      filtered = filtered
          .where(
            (item) =>
                item.status.toLowerCase() == _selectedStatus!.toLowerCase(),
          )
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

    // Sort by urgency and date - Case-insensitive comparison
    filtered.sort((a, b) {
      if (a.status.toLowerCase() == 'pending' &&
          b.status.toLowerCase() != 'pending') {
        return -1;
      }
      if (a.status.toLowerCase() != 'pending' &&
          b.status.toLowerCase() == 'pending') {
        return 1;
      }

      if (a.status.toLowerCase() == 'pending' &&
          b.status.toLowerCase() == 'pending') {
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
    try {
      // Validate user session
      if (_currentUserId == null || _currentUserName == null) {
        await _loadUserData();
        if (_currentUserId == null || _currentUserName == null) {
          _showErrorSnackBar('Sesi login berakhir. Silakan login ulang.');
          return;
        }
      }

      await _loadAllData();
    } catch (e) {
      _showErrorSnackBar('Gagal memperbarui data: $e');
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

  void _showOvertimeDetail(AdminOvertimeData item) {
    // TAMBAHKAN NULL CHECK INI SEBELUM MEMBUKA MODAL
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
          currentAdminId:
              _currentUserId!, // Sekarang aman karena sudah di-check
          currentAdminName:
              _currentUserName!, // Sekarang aman karena sudah di-check
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
                child: const Text('Batal'),
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
        title: const Text('Alasan Penolakan'),
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
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('OK'),
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
              : 'HRD Overtime',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
          overflow: TextOverflow.ellipsis,
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
          labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 14)),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Overtime'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
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
                    'Memuat data HRD...',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
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
          onPressed: _isLoading ? null : _refreshData, // Disable saat loading
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
          label: const Text('Tolak'),
          icon: const Icon(Icons.close),
          heroTag: 'reject',
        ),
        FloatingActionButton.extended(
          onPressed: () => _bulkAction('approve'),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          label: const Text('Setujui'),
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
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7280),
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadUserData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
                          'Selamat Datang, HRD',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 18),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentUserName ?? 'HRD Manager',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Enhanced Search and Filter Section for HRD
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar with HRD features
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Cari berdasarkan nama, departemen, atau catatan...',
                    hintStyle: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          ),
                        if (!_isSelectionMode)
                          IconButton(
                            icon: const Icon(Icons.checklist),
                            onPressed: _toggleSelectionMode,
                            tooltip: 'Mode Pilih Massal',
                          ),
                      ],
                    ),
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

                // Filter Row with HRD specific filters
                if (isTablet)
                  Row(
                    children: [
                      Flexible(child: _buildStatusFilter()),
                      const SizedBox(width: 12),
                      Flexible(child: _buildDepartmentFilter()),
                      const SizedBox(width: 12),
                      Flexible(child: _buildDateRangeFilter()),
                      const SizedBox(width: 12),
                      Flexible(child: _buildUserFilter()),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Flexible(child: _buildStatusFilter()),
                          const SizedBox(width: 12),
                          Flexible(child: _buildDepartmentFilter()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Flexible(child: _buildDateRangeFilter()),
                          const SizedBox(width: 12),
                          Flexible(child: _buildUserFilter()),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // List Header with HRD insights
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_filteredOvertimes.length} Hasil',
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
                // Wrap untuk layout yang flexible
                Wrap(
                  spacing: 8,
                  children: [
                    if (_getTotalOvertimeHours() > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Total: ${_getTotalOvertimeHours().toStringAsFixed(1)} jam',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    if (_isSelectionMode && _selectedItems.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selectedItems.length} dipilih',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, color: Color(0xFF6B7280)),
                      onSelected: (value) {
                        _sortOvertimes(value);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'date_desc',
                          child: Text('Tanggal Terbaru'),
                        ),
                        const PopupMenuItem(
                          value: 'date_asc',
                          child: Text('Tanggal Terlama'),
                        ),
                        const PopupMenuItem(
                          value: 'hours_desc',
                          child: Text('Jam Terbanyak'),
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
              ],
            ),
          ),

          // List Content
          Expanded(
            child: _filteredOvertimes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    itemCount: _filteredOvertimes.length,
                    itemBuilder: (context, index) {
                      return _buildHRDOvertimeCard(_filteredOvertimes[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
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
                return _buildHRDUserCard(_users[index]);
              },
            ),
    );
  }

  Widget _buildStatisticsCards(OvertimeAdminStatistics stats) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap untuk header yang responsive
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Statistik Overtime HRD',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _showOvertimeReport();
              },
              icon: const Icon(Icons.assessment, size: 16),
              label: const Text('Lihat Laporan'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // LayoutBuilder untuk responsive grid
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
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
                  icon: Icons.access_time_filled,
                  color: const Color(0xFF6366F1),
                  trend: _calculateTrend('total'),
                  onTap: () => _navigateToOvertimesWithFilter('all'),
                ),
                _buildStatCard(
                  title: 'Menunggu Review',
                  value: stats.pendingCount.toString(),
                  icon: Icons.pending_actions,
                  color: const Color(0xFFF59E0B),
                  urgent: stats.pendingCount > 5,
                  onTap: () => _navigateToOvertimesWithFilter('Pending'),
                ),
                _buildStatCard(
                  title: 'Disetujui',
                  value: stats.approvedCount.toString(),
                  icon: Icons.check_circle,
                  color: const Color(0xFF10B981),
                  trend: _calculateTrend('approved'),
                  onTap: () => _navigateToOvertimesWithFilter('Approved'),
                ),
                _buildStatCard(
                  title: 'Ditolak',
                  value: stats.rejectedCount.toString(),
                  icon: Icons.cancel,
                  color: const Color(0xFFEF4444),
                  trend: _calculateTrend('rejected'),
                  onTap: () => _navigateToOvertimesWithFilter('Rejected'),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // Additional HRD Statistics
        _buildHRDInsights(),
      ],
    );
  }

  Widget _buildHRDInsights() {
    final totalHours = _calculateTotalOvertimeHours();
    final averageHours =
        totalHours / (_allOvertimes.isEmpty ? 1 : _allOvertimes.length);
    final topDepartment = _getTopOvertimeDepartment();

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HRD Insights',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInsightRow(
            'Total Jam Overtime',
            '${totalHours.toStringAsFixed(1)} jam',
          ),
          _buildInsightRow(
            'Rata-rata per Pengajuan',
            '${averageHours.toStringAsFixed(1)} jam',
          ),
          _buildInsightRow('Departemen Tertinggi', topDepartment),
          _buildInsightRow('Tingkat Approval', '${_calculateApprovalRate()}%'),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
            // Row dengan Expanded untuk mencegah overflow
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
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 24),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 12),
                color: const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentItems() {
    final urgentItems = _allOvertimes
        .where(
          (item) =>
              item.status.toLowerCase() == 'pending' &&
              item.daysSinceSubmitted > 2, // Case-insensitive
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
        // Wrap untuk responsive header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.red,
                  ),
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
                _navigateToOvertimesWithFilter('Pending');
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
            child: _buildHRDOvertimeCard(item, isUrgent: true),
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
          'Aksi Cepat HRD',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        // LayoutBuilder untuk responsive grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildQuickActionCard(
                  title: 'Review Pending',
                  subtitle: '${_statistics?.pendingCount ?? 0} pengajuan',
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
                _buildQuickActionCard(
                  title: 'Bulk Approval',
                  subtitle: 'Aksi massal',
                  icon: Icons.checklist,
                  color: const Color(0xFF10B981),
                  onTap: () {
                    _tabController.animateTo(1);
                    _toggleSelectionMode();
                  },
                ),
                _buildQuickActionCard(
                  title: 'Generate Report',
                  subtitle: 'Laporan overtime',
                  icon: Icons.assessment,
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    _showOvertimeReport();
                  },
                ),
                _buildQuickActionCard(
                  title: 'Policy Settings',
                  subtitle: 'Atur kebijakan',
                  icon: Icons.settings,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    _showPolicySettings();
                  },
                ),
              ],
            );
          },
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 11),
                      color: const Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentFilter() {
    final departments = [
      'Semua Departemen',
      'IT',
      'HR',
      'Finance',
      'Marketing',
      'Operations',
    ];

    return DropdownButtonFormField<String>(
      value: null,
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
      isExpanded: true, // Menambahkan isExpanded
      items: departments.map((dept) {
        return DropdownMenuItem(
          value: dept == 'Semua Departemen' ? null : dept,
          child: Text(dept, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      }).toList(),
      onChanged: (value) {
        // Handle department filter
      },
    );
  }

  Widget _buildDateRangeFilter() {
    final ranges = ['Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Custom'];

    return DropdownButtonFormField<String>(
      value: 'Bulan Ini',
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
      isExpanded: true, // Menambahkan isExpanded
      items: ranges.map((range) {
        return DropdownMenuItem(
          value: range,
          child: Text(range, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      }).toList(),
      onChanged: (value) {
        // Handle date range filter
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
      isExpanded: true, // Menambahkan isExpanded
      items: _statusOptions.map((status) {
        final value = status == 'Semua Status' ? null : status;
        return DropdownMenuItem(
          value: value,
          child: Text(
            status == 'Semua Status'
                ? status
                : OvertimeAdminService.getStatusDisplayName(status),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
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

    // Safety check untuk selected user
    String currentValue = 'Semua User';
    if (_selectedUserId != null) {
      try {
        final selectedUser = _users.firstWhere(
          (u) => u.userId == _selectedUserId,
        );
        currentValue = selectedUser.name;
      } catch (e) {
        // Jika user tidak ditemukan, reset ke Semua User
        _selectedUserId = null;
        currentValue = 'Semua User';
      }
    }

    return DropdownButtonFormField<String>(
      value: currentValue,
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
            try {
              _selectedUserId = _users
                  .firstWhere((u) => u.name == value)
                  .userId;
            } catch (e) {
              _selectedUserId = null;
            }
          }
          _applyFilters();
        });
      },
    );
  }

  Widget _buildHRDOvertimeCard(
    AdminOvertimeData item, {
    bool isUrgent = false,
  }) {
    final isSelected = _selectedItems.contains(item.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent
            ? const BorderSide(color: Color(0xFFEF4444), width: 1)
            : isSelected
            ? const BorderSide(color: Color(0xFF6366F1), width: 2)
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
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with selection and urgency - Responsive layout
              Row(
                children: [
                  if (_isSelectionMode && item.canBeModified) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleItemSelection(item.id),
                      activeColor: const Color(0xFF6366F1),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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

              // User info with department - Expanded untuk responsive
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
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '${item.userJob ?? 'No Position'} • ${_getUserDepartment(item)}',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Time and hours info - Responsive layout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.formattedTimeRange,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 13),
                                color: const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.formattedTotalJam,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6366F1),
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (item.status.toLowerCase() == 'pending') ...[
                // Case-insensitive
                const SizedBox(height: 8),
                // Responsive untuk tablet dan mobile
                if (isTablet && !_isSelectionMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Diajukan ${item.daysSinceSubmitted} hari yang lalu',
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(context, 12),
                                  color: item.urgencyColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: TextButton.icon(
                                onPressed: () => _quickReview(item, 'Rejected'),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Tolak'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: () => _quickReview(item, 'Approved'),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Setujui'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Diajukan ${item.daysSinceSubmitted} hari yang lalu',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 12),
                                color: item.urgencyColor,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      if (!_isSelectionMode) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _quickReview(item, 'Rejected'),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Tolak'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _quickReview(item, 'Approved'),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Setujui'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
              ],

              // Notes if exists
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.note,
                            size: 14,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Catatan:',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.catatan!,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 13),
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],

              // Rejection reason if exists
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.cancel,
                            size: 14,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Alasan Penolakan:',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.rejectionReason!,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 13),
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHRDUserCard(UserWithOvertimes user) {
    final overtimePercentage = _calculateUserOvertimePercentage(user);
    final isHighOvertime = user.totalApprovedHours > 40;

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
              // Row dengan Expanded untuk mencegah overflow
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
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '${user.jobs ?? 'No Position'} • ${_getUserDepartmentFromUser(user)}',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  if (isHighOvertime)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 12,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'High OT',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 10),
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Overtime Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total Overtime',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${user.totalApprovedHours.toStringAsFixed(1)} jam',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: isHighOvertime
                              ? Colors.orange
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: overtimePercentage / 100,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isHighOvertime ? Colors.orange : const Color(0xFF10B981),
                    ),
                    minHeight: 6,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Statistics - Wrap untuk responsiveness
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildUserStatItem(
                    'Total',
                    user.totalOvertime.toString(),
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
    return SizedBox(
      width: 60, // Width tetap untuk konsistensi
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w700,
                color: color,
              ),
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
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
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
              child: Icon(
                _allOvertimes.isEmpty && _users.isEmpty
                    ? Icons.cloud_off_outlined
                    : Icons.inbox_outlined,
                size: 64,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _allOvertimes.isEmpty && _users.isEmpty
                  ? 'Tidak Ada Koneksi Data'
                  : 'Tidak Ada Data',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _allOvertimes.isEmpty && _users.isEmpty
                  ? 'Periksa koneksi internet dan coba lagi'
                  : 'Belum ada data yang sesuai dengan filter',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            if (_allOvertimes.isEmpty && _users.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
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
          ],
        ),
      ),
    );
  }

  // Helper Methods
  void _navigateToOvertimesWithFilter(String filterType) async {
    _tabController.animateTo(1);

    // Tambahkan delay untuk memastikan tab berubah
    await Future.delayed(const Duration(milliseconds: 100));

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
        default:
          _selectedStatus = null;
      }

      _selectedUserId = null;
      _searchController.clear();
      _applyFilters();
    });

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

  double _getTotalOvertimeHours() {
    return _filteredOvertimes.fold(0.0, (sum, item) => sum + item.totalJam);
  }

  double _calculateTotalOvertimeHours() {
    return _allOvertimes
        .where(
          (item) => item.status.toLowerCase() == 'approved',
        ) // Case-insensitive
        .fold(0.0, (sum, item) => sum + item.totalJam);
  }

  String _calculateTrend(String type) {
    // Mock trend calculation - replace with actual logic
    switch (type) {
      case 'total':
        return '+12%';
      case 'approved':
        return '+5%';
      case 'rejected':
        return '-3%';
      default:
        return '0%';
    }
  }

  String _getTopOvertimeDepartment() {
    // Mock calculation - replace with actual logic
    return 'IT Department';
  }

  double _calculateApprovalRate() {
    if (_statistics == null || _statistics!.totalSubmissions == 0) return 0;
    return (_statistics!.approvedCount / _statistics!.totalSubmissions * 100);
  }

  double _calculateUserOvertimePercentage(UserWithOvertimes user) {
    // Calculate percentage based on max 50 hours
    return (user.totalApprovedHours / 50 * 100).clamp(0, 100);
  }

  // Helper method untuk mendapatkan department dari AdminOvertimeData
  String _getUserDepartment(AdminOvertimeData item) {
    // This would normally come from your API
    // For now, returning a mock value based on job
    if (item.userJob?.contains('Developer') ?? false) return 'IT';
    if (item.userJob?.contains('HR') ?? false) return 'HR';
    if (item.userJob?.contains('Finance') ?? false) return 'Finance';
    if (item.userJob?.contains('Marketing') ?? false) return 'Marketing';
    return 'Operations';
  }

  // Helper method untuk mendapatkan department dari UserWithOvertimes
  String _getUserDepartmentFromUser(UserWithOvertimes user) {
    // This would normally come from your API
    // For now, returning a mock value
    final depts = ['IT', 'HR', 'Finance', 'Marketing', 'Operations'];
    return depts[user.userId.hashCode % depts.length];
  }

  void _sortOvertimes(String sortBy) {
    setState(() {
      switch (sortBy) {
        case 'date_desc':
          // Gunakan submittedAt sebagai pengganti tanggal
          _filteredOvertimes.sort(
            (a, b) => b.submittedAt.compareTo(a.submittedAt),
          );
          break;
        case 'date_asc':
          // Gunakan submittedAt sebagai pengganti tanggal
          _filteredOvertimes.sort(
            (a, b) => a.submittedAt.compareTo(b.submittedAt),
          );
          break;
        case 'hours_desc':
          _filteredOvertimes.sort((a, b) => b.totalJam.compareTo(a.totalJam));
          break;
        case 'urgent':
          _filteredOvertimes.sort((a, b) {
            if (a.status.toLowerCase() == 'pending' &&
                b.status.toLowerCase() != 'pending') {
              return -1;
            }
            if (a.status.toLowerCase() != 'pending' &&
                b.status.toLowerCase() == 'pending') {
              return 1;
            }
            return b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted);
          });
          break;
        case 'name':
          _filteredOvertimes.sort((a, b) => a.userName.compareTo(b.userName));
          break;
      }
    });
  }

  Future<void> _quickReview(AdminOvertimeData item, String status) async {
    try {
      final response = await OvertimeAdminService.reviewOvertime(
        id: item.id,
        status: status,
        approvedBy: _currentUserName!,
        adminId: _currentUserId!,
      );

      if (response.success) {
        await _refreshData();
        _showSuccessSnackBar(
          status == 'Approved' ? 'Overtime disetujui' : 'Overtime ditolak',
        );
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  void _showOvertimeReport() {
    // Show overtime report dialog or navigate to report page
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Laporan Overtime'),
        content: const Text('Fitur laporan overtime akan segera tersedia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPolicySettings() {
    // Show policy settings dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan Kebijakan'),
        content: const Text(
          'Fitur pengaturan kebijakan overtime akan segera tersedia',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
