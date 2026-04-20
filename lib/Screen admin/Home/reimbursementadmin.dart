// halaman_admin_reimbursement.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/model/reimbursementadminmodel.dart';
import 'package:absensikaryawan/Screen%20admin/service/reimburmentadminservice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HalamanAdminReimbursement extends StatefulWidget {
  const HalamanAdminReimbursement({super.key});

  @override
  _HalamanAdminReimbursementState createState() =>
      _HalamanAdminReimbursementState();
}

class _HalamanAdminReimbursementState extends State<HalamanAdminReimbursement>
    with SingleTickerProviderStateMixin {
  final AdminReimbursementService _adminService = AdminReimbursementService();

  List<AdminReimbursementData> _allReimbursements = [];
  List<AdminReimbursementData> _filteredReimbursements = [];
  List<UserWithReimbursements> _users = [];
  AdminReimbursementStatistics? _statistics;

  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _selectedStatus;
  String? _selectedUserId;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusOptions = [
    'Semua Status',
    'pending',
    'approved',
    'rejected',
    'paid',
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
      List<AdminReimbursementData> reimbursements = [];
      List<UserWithReimbursements> users = [];
      AdminReimbursementStatistics? statistics;

      // Load semua data secara parallel
      try {
        final futures =
            await Future.wait([
              _adminService.getAllReimbursementsAdmin(
                currentUserId: _currentUserId!,
              ),
              _adminService.getUsersWithReimbursements(),
              _adminService.getAdminStatistics(),
            ]).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout. Silakan coba lagi.');
              },
            );

        reimbursements = futures[0] as List<AdminReimbursementData>;
        users = futures[1] as List<UserWithReimbursements>;
        statistics = futures[2] as AdminReimbursementStatistics?;
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
        _allReimbursements = reimbursements;
        _users = users;
        _statistics = statistics;
        _applyFilters();
        _isLoading = false;
      });

      // Show appropriate success message
      if (reimbursements.isNotEmpty) {
        _showSuccessSnackBar(
          'Data berhasil dimuat: ${reimbursements.length} reimbursement dari ${users.length} user',
        );
      } else if (users.isNotEmpty) {
        _showInfoSnackBar(
          'Sistem siap. Belum ada reimbursement yang diajukan.',
        );
      } else {
        _showInfoSnackBar('Panel admin aktif. Menunggu data reimbursement.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Terjadi kesalahan sistem: $e');
    }
  }

  Future<void> _loadDataIndividually() async {
    List<AdminReimbursementData> reimbursements = [];
    List<UserWithReimbursements> users = [];
    AdminReimbursementStatistics? statistics;

    // Load reimbursements
    try {
      reimbursements = await _adminService.getAllReimbursementsAdmin(
        currentUserId: _currentUserId!,
      );
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data reimbursement: $e');
    }

    // Load users
    try {
      users = await _adminService.getUsersWithReimbursements();
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data users: $e');
    }

    // Load statistics
    try {
      statistics = await _adminService.getAdminStatistics();
    } catch (e) {
      _showErrorSnackBar('Statistik menggunakan data default');
    }

    setState(() {
      _allReimbursements = reimbursements;
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
    List<AdminReimbursementData> filtered = _allReimbursements;
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
        return item.title.toLowerCase().contains(searchKeyword) ||
            item.category.toLowerCase().contains(searchKeyword) ||
            item.userName.toLowerCase().contains(searchKeyword) ||
            (item.description?.toLowerCase().contains(searchKeyword) ?? false);
      }).toList();
    }

    // Sort by urgency and date
    filtered.sort((a, b) {
      // Prioritize pending items that are old
      if (a.status == 'pending' && b.status != 'pending') return -1;
      if (a.status != 'pending' && b.status == 'pending') return 1;

      if (a.status == 'pending' && b.status == 'pending') {
        return b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted);
      }

      return b.submittedAt.compareTo(a.submittedAt);
    });

    setState(() {
      _filteredReimbursements = filtered;
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

  void _showReimbursementDetail(AdminReimbursementData item) {
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
        return AdminReimbursementDetailModal(
          item: item,
          adminService: _adminService,
          currentAdminId:
              _currentUserId!, // Sekarang aman karena sudah di-check
          currentAdminName:
              _currentUserName!, // Sekarang aman karena sudah di-check
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
          'Admin Reimbursement',
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
              onPressed: _isLoading
                  ? null
                  : _refreshData, // PERBAIKAN: Disable saat loading
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF3B82F6),
          labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 14)),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Reimbursements'),
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
                    'Memuat data admin...',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Kembali'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B7280),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
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
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildReimbursementsTab(),
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
            // Enhanced Welcome Section
            //_buildWelcomeCard(),
            //const SizedBox(height: 24),

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

  Widget _buildReimbursementsTab() {
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
                  'Daftar Reimbursement',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filteredReimbursements.length} data',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // List Content
          Expanded(
            child: _filteredReimbursements.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredReimbursements.length,
                    itemBuilder: (context, index) {
                      return _buildAdminReimbursementCard(
                        _filteredReimbursements[index],
                      );
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

  Widget _buildStatisticsCards(AdminReimbursementStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Statistik Reimbursement',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const Spacer(),
            // Indikator jika data tidak lengkap
            if (stats.totalSubmissions == 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Data terbatas',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Overview Cards dengan navigasi
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Pengajuan',
                value: stats.totalSubmissions.toString(),
                icon: Icons.receipt_long,
                color: const Color(0xFF3B82F6),
                onTap: () => _navigateToReimbursementsWithFilter(
                  'all',
                ), // ← Tambahkan onTap
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Menunggu Review',
                value: stats.pendingCount.toString(),
                icon: Icons.pending_actions,
                color: const Color(0xFFF59E0B),
                isHighlighted: stats.pendingCount > 0,
                onTap: () => _navigateToReimbursementsWithFilter(
                  'pending',
                ), // ← Tambahkan onTap
              ),
            ),
          ],
        ),

        const SizedBox(width: 12),

        // Status Cards dengan navigasi
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Disetujui',
                value: stats.approvedCount.toString(),
                icon: Icons.check_circle,
                color: const Color(0xFF10B981),
                onTap: () => _navigateToReimbursementsWithFilter(
                  'approved',
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
                onTap: () => _navigateToReimbursementsWithFilter(
                  'rejected',
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
    bool isHighlighted = false,
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
          border: Border.all(
            color: isHighlighted
                ? color.withOpacity(0.5)
                : const Color(0xFFE5E7EB),
            width: isHighlighted ? 2 : 1,
          ),
          // Enhanced shadow untuk clickable cards
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                  if (isHighlighted)
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ]
              : isHighlighted
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                // Badge jika highlighted
                if (isHighlighted && onTap == null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 24),
                fontWeight: FontWeight.w700,
                color: isHighlighted ? color : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Tambahkan method untuk navigasi dengan filter otomatis
  void _navigateToReimbursementsWithFilter(String filterType) {
    // Pindah ke tab Reimbursements (index 1)
    _tabController.animateTo(1);

    // Set filter sesuai tipe yang diklik
    setState(() {
      switch (filterType) {
        case 'all':
          _selectedStatus = null; // Semua Status
          break;
        case 'pending':
          _selectedStatus = 'pending';
          break;
        case 'approved':
          _selectedStatus = 'approved';
          break;
        case 'rejected':
          _selectedStatus = 'rejected';
          break;
        case 'paid':
          _selectedStatus = 'paid';
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
        filterMessage = 'Menampilkan semua pengajuan reimbursement';
        break;
      case 'pending':
        filterMessage = 'Menampilkan reimbursement menunggu review';
        break;
      case 'approved':
        filterMessage = 'Menampilkan reimbursement yang disetujui';
        break;
      case 'rejected':
        filterMessage = 'Menampilkan reimbursement yang ditolak';
        break;
      case 'paid':
        filterMessage = 'Menampilkan reimbursement yang sudah dibayar';
        break;
    }

    if (filterMessage.isNotEmpty) {
      _showSuccessSnackBar(filterMessage);
    }
  }

  Widget _buildUrgentItems() {
    final urgentItems = _allReimbursements
        .where(
          (item) => item.status == 'pending' && item.daysSinceSubmitted > 3,
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
                'Tidak ada item urgent yang perlu direview',
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
            child: _buildAdminReimbursementCard(item, isUrgent: true),
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
                onTap: () => _navigateToReimbursementsWithFilter(
                  'pending',
                ), // ← Konsisten dengan navigasi
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Mark Paid',
                subtitle: '${_statistics?.approvedCount ?? 0} approved',
                icon: Icons.payments,
                color: const Color(0xFF10B981),
                onTap: () => _navigateToReimbursementsWithFilter(
                  'approved',
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
            status == 'Semua Status' ? status : _getStatusDisplayName(status),
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

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu Review';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'paid':
        return 'Dibayar';
      default:
        return status;
    }
  }

  Widget _buildAdminReimbursementCard(
    AdminReimbursementData item, {
    bool isUrgent = false,
  }) {
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
        onTap: () => _showReimbursementDetail(item),
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
                      child: Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 10),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      item.title,
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

              // Category and amount
              Row(
                children: [
                  const Icon(
                    Icons.category,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.category,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.formattedAmount,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date and days info
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
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
                  if (item.status == 'pending')
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserWithReimbursements user) {
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
                      style: const TextStyle(
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
                      user.totalReimbursements.toString(),
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
                      'Total Amount',
                      user.formattedTotalAmount,
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
            Icon(
              _allReimbursements.isEmpty && _users.isEmpty
                  ? Icons.cloud_off_outlined
                  : Icons.inbox_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _allReimbursements.isEmpty && _users.isEmpty
                  ? 'Tidak Ada Koneksi Data'
                  : 'Tidak Ada Data',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _allReimbursements.isEmpty && _users.isEmpty
                  ? 'Periksa koneksi internet dan coba lagi'
                  : 'Belum ada data yang sesuai dengan filter',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            // PERBAIKAN: Tambah action button untuk empty state
            if (_allReimbursements.isEmpty && _users.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
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
}

// Detail Modal Component
class AdminReimbursementDetailModal extends StatefulWidget {
  final AdminReimbursementData item;
  final AdminReimbursementService adminService;
  final String currentAdminId;
  final String currentAdminName;
  final VoidCallback onActionCompleted;

  const AdminReimbursementDetailModal({
    super.key,
    required this.item,
    required this.adminService,
    required this.currentAdminId,
    required this.currentAdminName,
    required this.onActionCompleted,
  });

  @override
  _AdminReimbursementDetailModalState createState() =>
      _AdminReimbursementDetailModalState();
}

class _AdminReimbursementDetailModalState
    extends State<AdminReimbursementDetailModal> {
  final TextEditingController _reviewNotesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _reviewNotesController.dispose();
    super.dispose();
  }

  Future<void> _reviewReimbursement(String status) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await widget.adminService.reviewReimbursement(
        id: widget.item.id,
        status: status,
        reviewedBy: widget.currentAdminName,
        reviewNotes: _reviewNotesController.text.trim().isNotEmpty
            ? _reviewNotesController.text.trim()
            : null,
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

  Future<void> _markAsPaid() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await widget.adminService.markReimbursementPaid(
        id: widget.item.id,
        paidBy: widget.currentAdminName,
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
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Detail Reimbursement',
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
                            fontSize: 14,
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
                              fontSize: 14,
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

                  // Reimbursement Details
                  _buildInfoSection('Detail Reimbursement', [
                    _buildDetailRow('Judul', widget.item.title),
                    _buildDetailRow('Kategori', widget.item.category),
                    _buildDetailRow('Nominal', widget.item.formattedAmount),
                    _buildDetailRow(
                      'Tanggal Pengeluaran',
                      widget.item.formattedDate,
                    ),
                    if (widget.item.description != null)
                      _buildDetailRow('Deskripsi', widget.item.description!),
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

                  // Receipt
                  if (widget.item.hasReceipt) ...[
                    _buildInfoSection('Bukti Pembayaran', [
                      _buildDetailRow(
                        'File',
                        widget.item.receiptFilename ?? 'receipt',
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
                            future: widget.adminService.getAdminHeaders(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.network(
                                  widget.adminService.getAdminReceiptImageUrl(
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
                                          Text('Gagal memuat gambar'),
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
                  if (widget.item.reviewedAt != null) ...[
                    _buildInfoSection('Riwayat Review', [
                      _buildDetailRow(
                        'Direview oleh',
                        widget.item.reviewedBy ?? 'Unknown',
                      ),
                      _buildDetailRow(
                        'Tanggal Review',
                        _formatDateTime(widget.item.reviewedAt!),
                      ),
                      if (widget.item.reviewNotes != null)
                        _buildDetailRow(
                          'Catatan Review',
                          widget.item.reviewNotes!,
                        ),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // Payment History
                  if (widget.item.paidAt != null) ...[
                    _buildInfoSection('Riwayat Pembayaran', [
                      _buildDetailRow(
                        'Dibayar oleh',
                        widget.item.paidBy ?? 'Unknown',
                      ),
                      _buildDetailRow(
                        'Tanggal Pembayaran',
                        _formatDateTime(widget.item.paidAt!),
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // Review Notes Input (for pending items)
                  if (widget.item.status == 'pending') ...[
                    const Text(
                      'Catatan Review (Opsional)',
                      style: TextStyle(
                        fontSize: 16,
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
    if (widget.item.status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _reviewReimbursement('rejected'),
              icon: const Icon(Icons.close),
              label: const Text('Tolak'),
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
              onPressed: () => _reviewReimbursement('approved'),
              icon: const Icon(Icons.check),
              label: const Text('Setujui'),
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
    } else if (widget.item.status == 'approved') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _markAsPaid,
          icon: const Icon(Icons.payments),
          label: const Text('Tandai Sebagai Dibayar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
