// screens/halaman_hrd_reimbursement.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/Home/reimbursementadmin.dart';
import 'package:absensikaryawan/Screen%20admin/model/reimbursementadminmodel.dart';
import 'package:absensikaryawan/Screen%20admin/service/reimburmentadminservice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isReimbursementWebLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class HalamanHRDReimbursement extends StatefulWidget {
  const HalamanHRDReimbursement({super.key});

  @override
  _HalamanHRDReimbursementState createState() =>
      _HalamanHRDReimbursementState();
}

class _HalamanHRDReimbursementState extends State<HalamanHRDReimbursement>
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
  int _webTabIndex = 0;

  final List<String> _statusOptions = [
    'Semua Status',
    'Pending',
    'Pending_Finance',
    'Approved',
    'Rejected',
    'Paid',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _webTabIndex = _tabController.index);
    });
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
        throw Exception('User  ID tidak tersedia. Silakan login ulang.');
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
        _showInfoSnackBar('Panel HRD aktif. Menunggu data reimbursement.');
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

    // Filter by status - PERBAIKAN: Case-insensitive comparison
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
        return item.title.toLowerCase().contains(searchKeyword) ||
            item.category.toLowerCase().contains(searchKeyword) ||
            item.userName.toLowerCase().contains(searchKeyword) ||
            (item.description?.toLowerCase().contains(searchKeyword) ?? false);
      }).toList();
    }

    // Sort by urgency and date - PERBAIKAN: Case-insensitive comparison
    filtered.sort((a, b) {
      // Prioritize pending items that are old
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
    final isWeb = _isReimbursementWebLayout(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isWeb),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data reimbursement...',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
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

  PreferredSizeWidget _buildAppBar(bool isWeb) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Manajemen Reimbursement',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, isWeb ? 20 : 17),
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
            tooltip: 'Perbarui data',
            icon: const Icon(Icons.refresh, color: Colors.black87, size: 18),
            onPressed: _isLoading ? null : _refreshData,
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
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDashboardTab(),
        _buildReimbursementsTab(),
        _buildUsersTab(),
        _buildReportsTab(),
      ],
    );
  }

  Widget _buildWebLayout() {
    const tabs = [
      _ReimbursementWebTab(Icons.dashboard, 'Dashboard', 0),
      _ReimbursementWebTab(Icons.list_alt, 'Pengajuan', 1),
      _ReimbursementWebTab(Icons.people, 'Karyawan', 2),
      _ReimbursementWebTab(Icons.analytics, 'Laporan', 3),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 218,
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
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...tabs.map((tab) {
                final selected = _webTabIndex == tab.index;
                return InkWell(
                  onTap: () {
                    setState(() => _webTabIndex = tab.index);
                    _tabController.animateTo(tab.index);
                  },
                  borderRadius: BorderRadius.circular(10),
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
                      color: selected
                          ? const Color(0xFF6366F1).withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(
                              color: const Color(0xFF6366F1).withOpacity(0.20),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 17,
                          color: selected
                              ? const Color(0xFF6366F1)
                              : Colors.grey[500],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
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
              _buildReimbursementsTab(),
              _buildUsersTab(),
              _buildReportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  int get _pendingCountLive => _allReimbursements.where((item) {
    final status = item.status.toLowerCase().replaceAll(' ', '_');
    return status == 'pending' || status == 'pending_finance';
  }).length;

  int get _approvedCountLive => _allReimbursements.where((item) {
    final status = item.status.toLowerCase();
    return status == 'approved' || status == 'paid';
  }).length;

  int get _rejectedCountLive => _allReimbursements
      .where((item) => item.status.toLowerCase() == 'rejected')
      .length;

  Widget _buildWebStatsSummary() {
    final data = [
      {
        'label': 'Total',
        'value': _allReimbursements.length,
        'color': Colors.blue,
      },
      {'label': 'Pending', 'value': _pendingCountLive, 'color': Colors.orange},
      {
        'label': 'Disetujui',
        'value': _approvedCountLive,
        'color': Colors.green,
      },
      {'label': 'Ditolak', 'value': _rejectedCountLive, 'color': Colors.red},
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
        ...data.map((item) {
          final color = item['color'] as Color;
          final count = item['value'] as int;
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
                  '$count',
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

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 24),
            if (_statistics != null) _buildStatisticsCards(_statistics!),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 800;
                if (!wide) {
                  return Column(
                    children: [
                      _buildUrgentItems(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildUrgentItems()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildQuickActions()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
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
            color: const Color(0xFF6366F1).withOpacity(0.30),
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
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
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
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 11),
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUserName ?? 'HRD Manager',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 17),
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
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('Karyawan', '${_users.length}', Icons.people),
                Container(width: 1, height: 36, color: Colors.white24),
                _buildQuickStat(
                  'Menunggu',
                  '$_pendingCountLive',
                  Icons.pending_actions,
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                _buildQuickStat(
                  'Nilai Disetujui',
                  _formatCompactCurrency(_calculateTotalReimbursementAmount()),
                  Icons.payments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 10),
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000) {
      final value = amount / 1000000;
      return 'Rp ${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} jt';
    }
    if (amount >= 1000) {
      final value = amount / 1000;
      return 'Rp ${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} rb';
    }
    return _formatCurrency(amount);
  }

  Widget _buildReimbursementsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final search = TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari judul, kategori, atau nama karyawan...',
                    hintStyle: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
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
                );

                if (wide) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: search),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatusFilter()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildUserFilter()),
                    ],
                  );
                }

                return Column(
                  children: [
                    search,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatusFilter()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildUserFilter()),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Daftar Pengajuan Reimbursement',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredReimbursements.length} data',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 12),
                      color: const Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredReimbursements.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredReimbursements.length,
                    itemBuilder: (context, index) => _buildHRDReimbursementCard(
                      _filteredReimbursements[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_users.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100
              ? 3
              : constraints.maxWidth >= 700
              ? 2
              : 1;
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: columns == 1 ? 1.0 : 1.20,
            ),
            itemBuilder: (context, index) => _buildHRDUserCard(_users[index]),
          );
        },
      ),
    );
  }

  Widget _buildReportsTab() {
    final totalNominal = _calculateTotalReimbursementAmount();
    final average = _allReimbursements.isEmpty
        ? 0.0
        : totalNominal / _allReimbursements.length;
    final approvalRate = _calculateApprovalRate();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan & Anggaran',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ringkasan reimbursement dan akses laporan terperinci.',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 13),
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 850 ? 3 : 1;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  childAspectRatio: columns == 1 ? 3.7 : 1.7,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildReportMetricCard(
                      'Total disetujui',
                      _formatCurrency(totalNominal),
                      Icons.payments,
                      const Color(0xFF10B981),
                    ),
                    _buildReportMetricCard(
                      'Rata-rata per pengajuan',
                      _formatCurrency(average),
                      Icons.insights,
                      const Color(0xFF6366F1),
                    ),
                    _buildReportMetricCard(
                      'Tingkat persetujuan',
                      '${approvalRate.toStringAsFixed(1)}%',
                      Icons.check_circle,
                      const Color(0xFF0EA5E9),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final reportCard = _buildReportActionCard(
                  title: 'Laporan Reimbursement',
                  subtitle:
                      'Analisis bulanan, kategori, departemen, dan karyawan.',
                  icon: Icons.assessment,
                  color: const Color(0xFF6366F1),
                  buttonLabel: 'Buka Laporan',
                  onTap: _showReimbursementReport,
                );
                final budgetCard = _buildReportActionCard(
                  title: 'Overview Anggaran',
                  subtitle:
                      'Pantau penggunaan anggaran serta peringatan biaya.',
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF8B5CF6),
                  buttonLabel: 'Lihat Anggaran',
                  onTap: _showBudgetOverview,
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: reportCard),
                          const SizedBox(width: 16),
                          Expanded(child: budgetCard),
                        ],
                      )
                    : Column(
                        children: [
                          reportCard,
                          const SizedBox(height: 16),
                          budgetCard,
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 13),
              height: 1.4,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                ),
                ElevatedButton.icon(
                  onPressed: _loadUserData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
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

  Widget _buildStatisticsCards(AdminReimbursementStatistics stats) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PERBAIKAN: Menggunakan Wrap untuk header yang responsive
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Statistik Reimbursement HRD',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _showReimbursementReport();
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

        // Overview Cards dengan navigasi - PERBAIKAN: Menggunakan LayoutBuilder
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
                  icon: Icons.receipt_long,
                  color: const Color(0xFF6366F1),
                  trend: _calculateTrend('total'),
                  onTap: () => _navigateToReimbursementsWithFilter('all'),
                ),
                _buildStatCard(
                  title: 'Menunggu Review',
                  value: stats.pendingCount.toString(),
                  icon: Icons.pending_actions,
                  color: const Color(0xFFF59E0B),
                  isHighlighted: stats.pendingCount > 5,
                  urgent: stats.pendingCount > 10,
                  onTap: () => _navigateToReimbursementsWithFilter('pending'),
                ),
                _buildStatCard(
                  title: 'Disetujui',
                  value: stats.approvedCount.toString(),
                  icon: Icons.check_circle,
                  color: const Color(0xFF10B981),
                  trend: _calculateTrend('approved'),
                  onTap: () => _navigateToReimbursementsWithFilter('approved'),
                ),
                _buildStatCard(
                  title: 'Ditolak',
                  value: stats.rejectedCount.toString(),
                  icon: Icons.cancel,
                  color: const Color(0xFFEF4444),
                  trend: _calculateTrend('rejected'),
                  onTap: () => _navigateToReimbursementsWithFilter('rejected'),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // HRD Financial Insights
        _buildHRDFinancialInsights(),
      ],
    );
  }

  Widget _buildHRDFinancialInsights() {
    final totalAmount = _calculateTotalReimbursementAmount();
    final averageAmount =
        totalAmount /
        (_allReimbursements.isEmpty ? 1 : _allReimbursements.length);
    final topCategory = _getTopReimbursementCategory();
    final approvalRate = _calculateApprovalRate();

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
                  'HRD Financial Insights',
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
          _buildInsightRow('Total Amount', _formatCurrency(totalAmount)),
          _buildInsightRow(
            'Average per Request',
            _formatCurrency(averageAmount),
          ),
          _buildInsightRow('Top Category', topCategory),
          _buildInsightRow(
            'Approval Rate',
            '${approvalRate.toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 12),
          // Budget Warning if needed
          if (totalAmount > 50000000) // Example threshold
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget threshold reached. Review pending approvals carefully.',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w500,
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
    bool isHighlighted = false,
    bool urgent = false,
    String? trend,
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
            color: urgent
                ? Colors.red.withOpacity(0.5)
                : isHighlighted
                ? color.withOpacity(0.5)
                : const Color(0xFFE5E7EB),
            width: urgent || isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (urgent)
              BoxShadow(
                color: Colors.red.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // PERBAIKAN: Row dengan Expanded untuk mencegah overflow
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
                      if (urgent)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.priority_high,
                            size: 12,
                            color: Colors.red,
                          ),
                        ),
                      if (onTap != null && trend == null && !urgent)
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
                  color: urgent ? Colors.red : const Color(0xFF1F2937),
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

  void _navigateToReimbursementsWithFilter(String filterType) async {
    // PERBAIKAN: Tambahkan async
    // Pindah ke tab Reimbursements dulu
    _tabController.animateTo(1);

    // PERBAIKAN: Tambahkan delay untuk memastikan tab sudah berubah
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      switch (filterType) {
        case 'all':
          _selectedStatus = null;
          break;
        case 'pending':
          _selectedStatus =
              'Pending'; // PERBAIKAN: Gunakan kapitalisasi yang sama dengan _statusOptions
          break;
        case 'approved':
          _selectedStatus =
              'Approved'; // PERBAIKAN: Gunakan kapitalisasi yang sama dengan _statusOptions
          break;
        case 'rejected':
          _selectedStatus =
              'Rejected'; // PERBAIKAN: Gunakan kapitalisasi yang sama dengan _statusOptions
          break;
        case 'paid':
          _selectedStatus =
              'Paid'; // PERBAIKAN: Gunakan kapitalisasi yang sama dengan _statusOptions
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
          (item) =>
              item.status.toLowerCase() == 'pending' &&
              item.daysSinceSubmitted >
                  2, // PERBAIKAN: Case-insensitive comparison
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
        // PERBAIKAN: Menggunakan Wrap untuk responsive header
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
                _navigateToReimbursementsWithFilter('pending');
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
            child: _buildHRDReimbursementCard(item, isUrgent: true),
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
        // PERBAIKAN: Menggunakan LayoutBuilder untuk responsive grid
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
                  onTap: () => _navigateToReimbursementsWithFilter('pending'),
                ),
                _buildQuickActionCard(
                  title: 'Process Payment',
                  subtitle: '${_statistics?.approvedCount ?? 0} approved',
                  icon: Icons.payments,
                  color: const Color(0xFF10B981),
                  onTap: () => _navigateToReimbursementsWithFilter('approved'),
                ),
                _buildQuickActionCard(
                  title: 'Generate Report',
                  subtitle: 'Monthly report',
                  icon: Icons.assessment,
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    _showReimbursementReport();
                  },
                ),
                _buildQuickActionCard(
                  title: 'Budget Overview',
                  subtitle: 'Check budget',
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    _showBudgetOverview();
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
      isExpanded: true, // PERBAIKAN: Menambahkan isExpanded
      items: _statusOptions.map((status) {
        final value = status == 'Semua Status' ? null : status;
        return DropdownMenuItem(
          value: value,
          child: Text(
            status == 'Semua Status' ? status : _getStatusDisplayName(status),
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

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu HRD';
      case 'pending_finance':
        return 'Menunggu Finance';
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

  Widget _buildHRDReimbursementCard(
    AdminReimbursementData item, {
    bool isUrgent = false,
  }) {
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
        onTap: () => _showReimbursementDetail(item),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with urgent indicator - PERBAIKAN: Menggunakan Flexible
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
                  Expanded(
                    child: Text(
                      item.title,
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

              // User info with avatar - PERBAIKAN: Menggunakan Flexible
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

              // Category and amount in card - PERBAIKAN: Menggunakan Flexible
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
                            Icons.category,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.category,
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
                          item.formattedAmount,
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
                // PERBAIKAN: Case-insensitive comparison
                const SizedBox(height: 8),
                // PERBAIKAN: Membuat responsive untuk tablet dan mobile
                if (isTablet)
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
                                onPressed: () => _quickReview(item, 'rejected'),
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
                                onPressed: () => _quickReview(item, 'approved'),
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                label: const Text('→ Finance'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _quickReview(item, 'rejected'),
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
                              onPressed: () => _quickReview(item, 'approved'),
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
                  ),
              ],

              // Description if exists
              if (item.description != null && item.description!.isNotEmpty) ...[
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
                            'Deskripsi:',
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
                        item.description!,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHRDUserCard(UserWithReimbursements user) {
    final reimbursementPercentage = _calculateUserReimbursementPercentage(user);
    final isHighAmount = user.totalAmount > 10000000;

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
              // PERBAIKAN: Row dengan Expanded untuk mencegah overflow
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
                  if (isHighAmount)
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
                            Icons.trending_up,
                            size: 12,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'High',
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

              // Reimbursement Amount Progress
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total Reimbursement',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        user.formattedTotalAmount,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: isHighAmount
                              ? Colors.orange
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: reimbursementPercentage / 100,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isHighAmount ? Colors.orange : const Color(0xFF10B981),
                    ),
                    minHeight: 6,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Statistics - PERBAIKAN: Menggunakan Wrap untuk responsiveness
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildUserStatItem(
                    'Total',
                    user.totalReimbursements.toString(),
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
      width: 60, // PERBAIKAN: Memberikan width tetap untuk konsistensi
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
                _allReimbursements.isEmpty && _users.isEmpty
                    ? Icons.cloud_off_outlined
                    : Icons.inbox_outlined,
                size: 64,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _allReimbursements.isEmpty && _users.isEmpty
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
              _allReimbursements.isEmpty && _users.isEmpty
                  ? 'Periksa koneksi internet dan coba lagi'
                  : 'Belum ada data yang sesuai dengan filter',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            if (_allReimbursements.isEmpty && _users.isEmpty) ...[
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
  double _calculateTotalReimbursementAmount() {
    return _allReimbursements
        .where(
          (item) =>
              item.status.toLowerCase() == 'approved' ||
              item.status.toLowerCase() == 'paid',
        ) // PERBAIKAN: Case-insensitive comparison
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  String _formatCurrency(double amount) {
    // Format to Indonesian Rupiah
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String _getTopReimbursementCategory() {
    if (_allReimbursements.isEmpty) return 'N/A';

    Map<String, int> categoryCount = {};
    for (var item in _allReimbursements) {
      categoryCount[item.category] = (categoryCount[item.category] ?? 0) + 1;
    }

    var sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  double _calculateApprovalRate() {
    if (_statistics == null || _statistics!.totalSubmissions == 0) return 0;
    return (_statistics!.approvedCount / _statistics!.totalSubmissions * 100);
  }

  String _calculateTrend(String type) {
    // Mock trend calculation - replace with actual logic
    switch (type) {
      case 'total':
        return '+15%';
      case 'approved':
        return '+8%';
      case 'rejected':
        return '-5%';
      default:
        return '0%';
    }
  }

  double _calculateUserReimbursementPercentage(UserWithReimbursements user) {
    // Calculate percentage based on max 20M threshold
    return ((user.totalAmount) / 20000000 * 100).clamp(0, 100);
  }

  // Helper method untuk mendapatkan department dari AdminReimbursementData
  String _getUserDepartment(AdminReimbursementData item) {
    // This would normally come from your API
    // For now, returning a mock value based on job
    if (item.userJob?.contains('Developer') ?? false) return 'IT';
    if (item.userJob?.contains('HR') ?? false) return 'HR';
    if (item.userJob?.contains('Finance') ?? false) return 'Finance';
    if (item.userJob?.contains('Marketing') ?? false) return 'Marketing';
    return 'Operations';
  }

  // Helper method untuk mendapatkan department dari UserWithReimbursements
  String _getUserDepartmentFromUser(dynamic user) {
    // This would normally come from your API
    // For now, returning a mock value
    final depts = ['IT', 'HR', 'Finance', 'Marketing', 'Operations'];
    final userId = user.userId ?? user.toString();
    return depts[userId.hashCode % depts.length];
  }

  Future<void> _quickReview(AdminReimbursementData item, String status) async {
    try {
      final response = await _adminService.reviewReimbursement(
        id: item.id,
        status: status,
        reviewedBy: _currentUserName!,
      );
      if (response.success) {
        await _refreshData();
        _showSuccessSnackBar(
          status == 'approved'
              ? 'Disetujui HRD — diteruskan ke Finance'
              : 'Reimbursement ditolak',
        );
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  void _showReimbursementReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ReimbursementReportModal(
          allReimbursements: _allReimbursements,
          users: _users,
          statistics: _statistics,
          currentUserId: _currentUserId ?? '',
          currentUserName: _currentUserName ?? '',
        );
      },
    );
  }

  void _showBudgetOverview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return BudgetOverviewModal(
          allReimbursements: _allReimbursements,
          users: _users,
          statistics: _statistics,
          currentUserId: _currentUserId ?? '',
          currentUserName: _currentUserName ?? '',
        );
      },
    );
  }
}

// Reimbursement Report Modal Class
class ReimbursementReportModal extends StatefulWidget {
  final List<dynamic>
  allReimbursements; // Changed to dynamic to avoid type issues
  final List<dynamic> users; // Changed to dynamic to avoid type issues
  final dynamic statistics; // Changed to dynamic to avoid type issues
  final String currentUserId;
  final String currentUserName;

  const ReimbursementReportModal({
    super.key,
    required this.allReimbursements,
    required this.users,
    required this.statistics,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ReimbursementReportModal> createState() =>
      _ReimbursementReportModalState();
}

class _ReimbursementReportModalState extends State<ReimbursementReportModal> {
  String _selectedReportType = 'monthly';
  String _selectedMonth = DateTime.now().month.toString();
  String _selectedYear = DateTime.now().year.toString();

  final List<String> _reportTypes = [
    'monthly',
    'yearly',
    'category',
    'department',
    'user',
    'summary',
  ];

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Laporan Reimbursement',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _exportReport,
                    icon: const Icon(Icons.download, color: Color(0xFF6366F1)),
                    tooltip: 'Export Report',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Report Type Selection
          _buildReportTypeSelection(),
          const SizedBox(height: 20),

          // Report Content
          Expanded(child: SingleChildScrollView(child: _buildReportContent())),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelection() {
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
            'Jenis Laporan',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reportTypes.map((type) {
              final isSelected = type == _selectedReportType;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedReportType = type;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    _getReportTypeName(type),
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedReportType == 'monthly') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(12, (index) {
                      final month = (index + 1).toString();
                      return DropdownMenuItem(
                        value: month,
                        child: Text(_getMonthName(month)),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(5, (index) {
                      final year = (DateTime.now().year - 2 + index).toString();
                      return DropdownMenuItem(value: year, child: Text(year));
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_selectedReportType) {
      case 'monthly':
        return _buildMonthlyReport();
      case 'yearly':
        return _buildYearlyReport();
      case 'category':
        return _buildCategoryReport();
      case 'department':
        return _buildDepartmentReport();
      case 'user':
        return _buildUserReport();
      case 'summary':
        return _buildSummaryReport();
      default:
        return _buildSummaryReport();
    }
  }

  Widget _buildMonthlyReport() {
    final monthData = _getMonthlyData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader(
          'Laporan Bulanan - ${_getMonthName(_selectedMonth)} $_selectedYear',
        ),
        const SizedBox(height: 20),

        // Monthly Statistics
        _buildStatisticsGrid(monthData['statistics']),
        const SizedBox(height: 20),

        // Monthly Trends
        _buildTrendsSection(monthData['trends']),
        const SizedBox(height: 20),

        // Top Requesters
        _buildTopRequestersSection(monthData['topRequesters']),
        const SizedBox(height: 20),

        // Category Breakdown
        _buildCategoryBreakdownSection(monthData['categories']),
      ],
    );
  }

  Widget _buildYearlyReport() {
    final yearData = _getYearlyData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan Tahunan $_selectedYear'),
        const SizedBox(height: 20),

        // Yearly Statistics
        _buildStatisticsGrid(yearData['statistics']),
        const SizedBox(height: 20),

        // Monthly Comparison
        _buildMonthlyComparisonSection(yearData['monthlyComparison']),
        const SizedBox(height: 20),

        // Department Performance
        _buildDepartmentPerformanceSection(yearData['departments']),
      ],
    );
  }

  Widget _buildCategoryReport() {
    final categoryData = _getCategoryData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan per Kategori'),
        const SizedBox(height: 20),

        ...categoryData.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildCategoryCard(entry.key, entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildDepartmentReport() {
    final departmentData = _getDepartmentData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan per Departemen'),
        const SizedBox(height: 20),

        ...departmentData.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildDepartmentCard(entry.key, entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildUserReport() {
    final sortedUsers = List<dynamic>.from(
      widget.users,
    )..sort((a, b) => ((b.totalAmount ?? 0.0).compareTo(a.totalAmount ?? 0.0)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan per Karyawan'),
        const SizedBox(height: 20),

        ...sortedUsers.map((user) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildUserCard(user),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryReport() {
    final summaryData = _getSummaryData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Ringkasan Laporan HRD'),
        const SizedBox(height: 20),

        // Executive Summary
        _buildExecutiveSummary(summaryData),
        const SizedBox(height: 20),

        // Key Metrics
        _buildKeyMetrics(summaryData),
        const SizedBox(height: 20),

        // Recommendations
        _buildRecommendations(summaryData),
      ],
    );
  }

  Widget _buildReportHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assessment, color: Color(0xFF6366F1), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Dibuat pada ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} oleh ${widget.currentUserName}',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Pengajuan',
          stats['totalCount'].toString(),
          Icons.receipt_long,
          const Color(0xFF6366F1),
        ),
        _buildStatCard(
          'Total Nilai',
          _formatCurrency(stats['totalAmount']),
          Icons.attach_money,
          const Color(0xFF10B981),
        ),
        _buildStatCard(
          'Rata-rata',
          _formatCurrency(stats['averageAmount']),
          Icons.trending_up,
          const Color(0xFFF59E0B),
        ),
        _buildStatCard(
          'Approval Rate',
          '${stats['approvalRate']}%',
          Icons.check_circle,
          const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 20),
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
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsSection(Map<String, dynamic> trends) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tren Pengajuan',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTrendItem(
                  'Peningkatan',
                  trends['increase'],
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildTrendItem(
                  'Penurunan',
                  trends['decrease'],
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 18),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 12),
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildTopRequestersSection(List<Map<String, dynamic>> topRequesters) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Requesters',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ...topRequesters.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getRankColor(index),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user['name'],
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _formatCurrency(user['amount']),
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownSection(Map<String, dynamic> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown per Kategori',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ...categories.entries.map((entry) {
            final percentage = entry.value['percentage'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
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

  Widget _buildCategoryCard(String category, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: const Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Total', data['count'].toString()),
              ),
              Expanded(
                child: _buildInfoItem('Nilai', _formatCurrency(data['amount'])),
              ),
              Expanded(
                child: _buildInfoItem('Avg', _formatCurrency(data['average'])),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(String department, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: const Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  department,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Karyawan',
                  data['employeeCount'].toString(),
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Pengajuan',
                  data['requestCount'].toString(),
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Total',
                  _formatCurrency(data['totalAmount']),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserWithReimbursements user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  '${user.jobs ?? 'No Position'} • ${user.department}',
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
                user.formattedTotalAmount,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
              ),
              Text(
                '${user.totalReimbursements} pengajuan',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 12),
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 12),
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveSummary(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Executive Summary',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data['summary'],
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: const Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Performance Metrics',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ...data['metrics'].map<Widget>((metric) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    metric['label'],
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    metric['value'],
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendations(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Rekomendasi HRD',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data['recommendations'].map<Widget>((recommendation) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Helper Methods
  String _getReportTypeName(String type) {
    switch (type) {
      case 'monthly':
        return 'Bulanan';
      case 'yearly':
        return 'Tahunan';
      case 'category':
        return 'Kategori';
      case 'department':
        return 'Departemen';
      case 'user':
        return 'Karyawan';
      case 'summary':
        return 'Ringkasan';
      default:
        return type;
    }
  }

  String _getMonthName(String month) {
    final months = [
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
    return months[int.parse(month) - 1];
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Map<String, dynamic> _getMonthlyData() {
    final selectedDate = DateTime(
      int.parse(_selectedYear),
      int.parse(_selectedMonth),
    );
    final monthlyReimbursements = widget.allReimbursements.where((item) {
      return item.submittedAt.year == selectedDate.year &&
          item.submittedAt.month == selectedDate.month;
    }).toList();

    final totalAmount = monthlyReimbursements.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final approvedCount = monthlyReimbursements
        .where((item) => item.status.toLowerCase() == 'approved')
        .length;
    final approvalRate = monthlyReimbursements.isNotEmpty
        ? (approvedCount / monthlyReimbursements.length * 100)
        : 0;

    // Top requesters
    Map<String, double> userAmounts = {};
    for (var item in monthlyReimbursements) {
      userAmounts[item.userName] =
          (userAmounts[item.userName] ?? 0) + item.amount;
    }
    final topRequesters =
        userAmounts.entries
            .map((e) => {'name': e.key, 'amount': e.value})
            .toList()
          ..sort(
            (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
          );

    // Categories
    Map<String, int> categoryCount = {};
    for (var item in monthlyReimbursements) {
      categoryCount[item.category] = (categoryCount[item.category] ?? 0) + 1;
    }
    final totalItems = monthlyReimbursements.length;
    Map<String, Map<String, double>> categories = {};
    categoryCount.forEach((key, value) {
      categories[key] = {
        'count': value.toDouble(),
        'percentage': totalItems > 0 ? (value / totalItems * 100) : 0.0,
      };
    });

    return {
      'statistics': {
        'totalCount': monthlyReimbursements.length,
        'totalAmount': totalAmount,
        'averageAmount': monthlyReimbursements.isNotEmpty
            ? totalAmount / monthlyReimbursements.length
            : 0,
        'approvalRate': approvalRate.round(),
      },
      'trends': {'increase': '+15%', 'decrease': '-5%'},
      'topRequesters': topRequesters.take(5).toList(),
      'categories': categories,
    };
  }

  Map<String, dynamic> _getYearlyData() {
    final selectedYear = int.parse(_selectedYear);
    final yearlyReimbursements = widget.allReimbursements.where((item) {
      return item.submittedAt.year == selectedYear;
    }).toList();

    final totalAmount = yearlyReimbursements.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final approvedCount = yearlyReimbursements
        .where((item) => item.status.toLowerCase() == 'approved')
        .length;
    final approvalRate = yearlyReimbursements.isNotEmpty
        ? (approvedCount / yearlyReimbursements.length * 100)
        : 0;

    // Monthly comparison
    Map<int, int> monthlyComparison = {};
    for (int i = 1; i <= 12; i++) {
      monthlyComparison[i] = yearlyReimbursements
          .where((item) => item.submittedAt.month == i)
          .length;
    }

    // Department data
    Map<String, Map<String, dynamic>> departments = {};
    for (var user in widget.users) {
      final dept = _getUserDepartmentFromUser(user);
      if (!departments.containsKey(dept)) {
        departments[dept] = {
          'employeeCount': 0,
          'requestCount': 0,
          'totalAmount': 0.0,
        };
      }
      departments[dept]!['employeeCount']++;
      departments[dept]!['requestCount'] += (user.totalReimbursements ?? 0);
      departments[dept]!['totalAmount'] += (user.totalAmount ?? 0.0);
    }

    return {
      'statistics': {
        'totalCount': yearlyReimbursements.length,
        'totalAmount': totalAmount,
        'averageAmount': yearlyReimbursements.isNotEmpty
            ? totalAmount / yearlyReimbursements.length
            : 0,
        'approvalRate': approvalRate.round(),
      },
      'monthlyComparison': monthlyComparison,
      'departments': departments,
    };
  }

  Map<String, Map<String, dynamic>> _getCategoryData() {
    Map<String, Map<String, dynamic>> categories = {};

    for (var item in widget.allReimbursements) {
      if (!categories.containsKey(item.category)) {
        categories[item.category] = {'count': 0, 'amount': 0.0, 'average': 0.0};
      }
      categories[item.category]!['count']++;
      categories[item.category]!['amount'] += item.amount;
    }

    // Calculate averages
    categories.forEach((key, value) {
      value['average'] = value['count'] > 0
          ? value['amount'] / value['count']
          : 0.0;
    });

    return categories;
  }

  Map<String, Map<String, dynamic>> _getDepartmentData() {
    Map<String, Map<String, dynamic>> departments = {};

    for (var user in widget.users) {
      final dept = _getUserDepartmentFromUser(user);
      if (!departments.containsKey(dept)) {
        departments[dept] = {
          'employeeCount': 0,
          'requestCount': 0,
          'totalAmount': 0.0,
        };
      }
      departments[dept]!['employeeCount']++;
      departments[dept]!['requestCount'] += (user.totalReimbursements ?? 0);
      departments[dept]!['totalAmount'] += (user.totalAmount ?? 0.0);
    }

    return departments;
  }

  // Helper method untuk mendapatkan department dari UserWithReimbursements
  String _getUserDepartmentFromUser(UserWithReimbursements user) {
    // This would normally come from your API
    // For now, returning a mock value
    final depts = ['IT', 'HR', 'Finance', 'Marketing', 'Operations'];
    return depts[user.userId.hashCode % depts.length];
  }

  Map<String, dynamic> _getSummaryData() {
    final totalReimbursements = widget.allReimbursements.length;
    final totalAmount = widget.allReimbursements.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final averageProcessingTime = _calculateAverageProcessingTime();
    final topCategory = _getTopCategory();

    return {
      'summary':
          'Pada periode ini, sistem reimbursement menunjukkan performa yang baik dengan total $totalReimbursements pengajuan senilai ${_formatCurrency(totalAmount)}. Kategori terbanyak adalah $topCategory dengan rata-rata waktu proses $averageProcessingTime hari.',
      'metrics': [
        {'label': 'Total Pengajuan', 'value': totalReimbursements.toString()},
        {'label': 'Total Nilai', 'value': _formatCurrency(totalAmount)},
        {
          'label': 'Rata-rata per Pengajuan',
          'value': _formatCurrency(
            totalReimbursements > 0 ? totalAmount / totalReimbursements : 0,
          ),
        },
        {
          'label': 'Approval Rate',
          'value':
              '${widget.statistics?.approvedCount ?? 0}/$totalReimbursements',
        },
        {
          'label': 'Avg Processing Time',
          'value': '$averageProcessingTime hari',
        },
      ],
      'recommendations': [
        'Pertimbangkan untuk meningkatkan limit kategori $topCategory',
        'Implementasikan approval otomatis untuk pengajuan di bawah Rp 500.000',
        'Buat training untuk departemen dengan tingkat penolakan tinggi',
        'Review kebijakan reimbursement setiap 6 bulan',
        'Implementasikan digital receipt untuk mempercepat proses',
      ],
    };
  }

  int _calculateAverageProcessingTime() {
    final processedItems = widget.allReimbursements
        .where(
          (item) =>
              item.status.toLowerCase() == 'approved' ||
              item.status.toLowerCase() == 'rejected',
        )
        .toList();

    if (processedItems.isEmpty) return 0;

    // Mock calculation - replace with actual processing time logic
    return 3; // Average 3 days
  }

  String _getTopCategory() {
    if (widget.allReimbursements.isEmpty) return 'N/A';

    Map<String, int> categoryCount = {};
    for (var item in widget.allReimbursements) {
      categoryCount[item.category] = (categoryCount[item.category] ?? 0) + 1;
    }

    var sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  Widget _buildMonthlyComparisonSection(Map<int, int> monthlyComparison) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perbandingan Bulanan',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final count = monthlyComparison[month] ?? 0;
                final maxCount = monthlyComparison.values.isNotEmpty
                    ? monthlyComparison.values.reduce((a, b) => a > b ? a : b)
                    : 1;
                final height = maxCount > 0 ? (count / maxCount * 150) : 0.0;

                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: height,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getMonthName(month.toString()).substring(0, 3),
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 10),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentPerformanceSection(
    Map<String, Map<String, dynamic>> departments,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performa Departemen',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ...departments.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value['employeeCount']} emp',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value['requestCount']} req',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatCurrency(entry.value['totalAmount']),
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6366F1),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _exportReport() {
    // Show export options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Export as Text'),
              onTap: () {
                Navigator.pop(context);
                _exportAsText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Report'),
              onTap: () {
                Navigator.pop(context);
                _shareReport();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportAsText() {
    // Generate text report
    final reportText = _generateTextReport();

    // Show the generated report in a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Text Report'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              reportText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Copy to clipboard
              // Clipboard.setData(ClipboardData(text: reportText));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _shareReport() {
    _generateTextReport();
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality will be implemented')),
    );
    // Note: reportText is prepared for future sharing implementation
  }

  String _generateTextReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== LAPORAN REIMBURSEMENT HRD ===');
    buffer.writeln('Dibuat pada: ${DateTime.now()}');
    buffer.writeln('Dibuat oleh: ${widget.currentUserName}');
    buffer.writeln('Jenis: ${_getReportTypeName(_selectedReportType)}');
    buffer.writeln();

    if (_selectedReportType == 'monthly') {
      buffer.writeln('Period: ${_getMonthName(_selectedMonth)} $_selectedYear');
    } else if (_selectedReportType == 'yearly') {
      buffer.writeln('Period: Tahun $_selectedYear');
    }

    buffer.writeln();
    buffer.writeln('STATISTIK UTAMA:');
    buffer.writeln('- Total Pengajuan: ${widget.allReimbursements.length}');
    buffer.writeln(
      '- Total Nilai: ${_formatCurrency(widget.allReimbursements.fold(0.0, (sum, item) => sum + item.amount))}',
    );
    buffer.writeln('- Pending: ${widget.statistics?.pendingCount ?? 0}');
    buffer.writeln('- Approved: ${widget.statistics?.approvedCount ?? 0}');
    buffer.writeln('- Rejected: ${widget.statistics?.rejectedCount ?? 0}');
    buffer.writeln();

    buffer.writeln('TOP CATEGORIES:');
    final categoryData = _getCategoryData();
    categoryData.entries.take(5).forEach((entry) {
      buffer.writeln(
        '- ${entry.key}: ${entry.value['count']} (${_formatCurrency(entry.value['amount'])})',
      );
    });

    buffer.writeln();
    buffer.writeln('=== END OF REPORT ===');

    return buffer.toString();
  }
}

// Budget Overview Modal Class
class BudgetOverviewModal extends StatefulWidget {
  final List<dynamic> allReimbursements;
  final List<dynamic> users;
  final dynamic statistics;
  final String currentUserId;
  final String currentUserName;

  const BudgetOverviewModal({
    super.key,
    required this.allReimbursements,
    required this.users,
    required this.statistics,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<BudgetOverviewModal> createState() => _BudgetOverviewModalState();
}

class _BudgetOverviewModalState extends State<BudgetOverviewModal> {
  String _selectedPeriod = 'monthly';
  String _selectedMonth = DateTime.now().month.toString();
  String _selectedYear = DateTime.now().year.toString();

  final List<String> _periods = ['monthly', 'quarterly', 'yearly'];

  // Mock budget data - In real app, this would come from API
  final Map<String, double> _budgetLimits = {
    'Transport': 50000000, // 50M
    'Meal': 30000000, // 30M
    'Medical': 40000000, // 40M
    'Office Supplies': 20000000, // 20M
    'Training': 25000000, // 25M
    'Other': 15000000, // 15M
  };

  final Map<String, double> _departmentBudgets = {
    'IT': 80000000, // 80M
    'HR': 40000000, // 40M
    'Finance': 30000000, // 30M
    'Marketing': 60000000, // 60M
    'Operations': 50000000, // 50M
  };

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Overview',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _exportBudgetReport,
                    icon: const Icon(Icons.download, color: Color(0xFF8B5CF6)),
                    tooltip: 'Export Budget Report',
                  ),
                  IconButton(
                    onPressed: _editBudgets,
                    icon: const Icon(Icons.edit, color: Color(0xFF6366F1)),
                    tooltip: 'Edit Budget Limits',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Period Selection
          _buildPeriodSelection(),
          const SizedBox(height: 20),

          // Budget Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Budget Status
                  _buildOverallBudgetStatus(),
                  const SizedBox(height: 20),

                  // Category Budget Analysis
                  _buildCategoryBudgetAnalysis(),
                  const SizedBox(height: 20),

                  // Department Budget Analysis
                  _buildDepartmentBudgetAnalysis(),
                  const SizedBox(height: 20),

                  // Budget Trends
                  _buildBudgetTrends(),
                  const SizedBox(height: 20),

                  // Budget Alerts
                  _buildBudgetAlerts(),
                  const SizedBox(height: 20),

                  // Budget Forecast
                  _buildBudgetForecast(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelection() {
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
            'Period Analysis',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: _periods.map((period) {
                    final isSelected = period == _selectedPeriod;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedPeriod = period;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF8B5CF6)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          _getPeriodName(period),
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (_selectedPeriod == 'monthly') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(12, (index) {
                      final month = (index + 1).toString();
                      return DropdownMenuItem(
                        value: month,
                        child: Text(_getMonthName(month)),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(5, (index) {
                      final year = (DateTime.now().year - 2 + index).toString();
                      return DropdownMenuItem(value: year, child: Text(year));
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverallBudgetStatus() {
    final budgetData = _getOverallBudgetData();
    final utilizationPercentage = budgetData['utilizationPercentage'];
    final statusColor = _getBudgetStatusColor(utilizationPercentage);

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Budget Status',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 18),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '${_getPeriodName(_selectedPeriod)} Budget Analysis',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getBudgetStatus(utilizationPercentage),
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Budget Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget Utilization',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    '${utilizationPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: utilizationPercentage / 100,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 8,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Used',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        _formatCurrency(budgetData['usedAmount']),
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Budget',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        _formatCurrency(budgetData['totalBudget']),
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'Remaining',
                  _formatCurrency(budgetData['remainingAmount']),
                  Icons.savings,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStat(
                  'Avg Monthly',
                  _formatCurrency(budgetData['avgMonthly']),
                  Icons.trending_up,
                  const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 10),
                    color: const Color(0xFF6B7280),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
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

  Widget _buildCategoryBudgetAnalysis() {
    final categoryData = _getCategoryBudgetData();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Text(
                'Budget per Kategori',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categoryData.entries.map((entry) {
            final category = entry.key;
            final data = entry.value;
            final utilizationPercentage =
                data['utilizationPercentage'] as double;
            final statusColor = _getBudgetStatusColor(utilizationPercentage);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: utilizationPercentage > 85
                      ? Colors.red.withOpacity(0.3)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (utilizationPercentage > 85)
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 16,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            '${utilizationPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 14),
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (utilizationPercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatCurrency(data['used'])} / ${_formatCurrency(data['budget'])}',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        'Sisa: ${_formatCurrency(data['remaining'])}',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w500,
                          color: data['remaining'] > 0
                              ? const Color(0xFF10B981)
                              : Colors.red,
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

  Widget _buildDepartmentBudgetAnalysis() {
    final departmentData = _getDepartmentBudgetData();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text(
                'Budget per Departemen',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...departmentData.entries.map((entry) {
            final department = entry.key;
            final data = entry.value;
            final utilizationPercentage =
                data['utilizationPercentage'] as double;
            final statusColor = _getBudgetStatusColor(utilizationPercentage);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: utilizationPercentage > 85
                      ? Colors.red.withOpacity(0.3)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              department,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 14),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              '${data['employeeCount']} karyawan',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 12),
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (utilizationPercentage > 85)
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 16,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            '${utilizationPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 14),
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (utilizationPercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatCurrency(data['used'])} / ${_formatCurrency(data['budget'])}',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        'Sisa: ${_formatCurrency(data['remaining'])}',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w500,
                          color: data['remaining'] > 0
                              ? const Color(0xFF10B981)
                              : Colors.red,
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

  Widget _buildBudgetTrends() {
    final trendsData = _getBudgetTrendsData();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text(
                'Budget Trends',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTrendCard(
                  'This Month',
                  trendsData['currentMonth'],
                  trendsData['currentMonthTrend'],
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendCard(
                  'Last Month',
                  trendsData['lastMonth'],
                  trendsData['lastMonthTrend'],
                  Icons.history,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTrendCard(
                  'YTD Average',
                  trendsData['ytdAverage'],
                  trendsData['ytdTrend'],
                  Icons.insights,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendCard(
                  'Projected',
                  trendsData['projected'],
                  trendsData['projectedTrend'],
                  Icons.show_chart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(
    String title,
    String value,
    String trend,
    IconData icon,
  ) {
    final isPositive = trend.startsWith('+');
    final trendColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6B7280), size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 11),
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: trendColor,
                size: 12,
              ),
              const SizedBox(width: 2),
              Text(
                trend,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 10),
                  fontWeight: FontWeight.w600,
                  color: trendColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAlerts() {
    final alerts = _getBudgetAlerts();

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Semua budget dalam kondisi baik! Tidak ada peringatan saat ini.',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 14),
                  color: Colors.green[800],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Budget Alerts',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${alerts.length}',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...alerts.map((alert) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getAlertColor(alert['severity']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getAlertColor(alert['severity']).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getAlertIcon(alert['severity']),
                    color: _getAlertColor(alert['severity']),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'],
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          alert['message'],
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _handleAlert(alert),
                    child: const Text('Action'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBudgetForecast() {
    final forecastData = _getBudgetForecastData();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Budget Forecast',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Forecast Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proyeksi 3 Bulan Kedepan',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  forecastData['summary'],
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Monthly Forecast
          ...forecastData['months'].map<Widget>((month) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        month['month'],
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Proyeksi: ${_formatCurrency(month['projected'])}',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${month['confidence']}%',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: _getConfidenceColor(month['confidence']),
                        ),
                      ),
                      Text(
                        'Confidence',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 10),
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

  // Helper Methods
  String _getPeriodName(String period) {
    switch (period) {
      case 'monthly':
        return 'Bulanan';
      case 'quarterly':
        return 'Kuartalan';
      case 'yearly':
        return 'Tahunan';
      default:
        return period;
    }
  }

  String _getMonthName(String month) {
    final months = [
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
    return months[int.parse(month) - 1];
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Color _getBudgetStatusColor(double percentage) {
    if (percentage >= 90) return Colors.red;
    if (percentage >= 75) return Colors.orange;
    if (percentage >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _getBudgetStatus(double percentage) {
    if (percentage >= 100) return 'Over Budget';
    if (percentage >= 90) return 'Critical';
    if (percentage >= 75) return 'Warning';
    if (percentage >= 50) return 'Caution';
    return 'Healthy';
  }

  Color _getAlertColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return const Color(0xFF10B981);
    if (confidence >= 60) return const Color(0xFFF59E0B);
    return Colors.red;
  }

  // Data calculation methods
  Map<String, dynamic> _getOverallBudgetData() {
    final totalBudget = _budgetLimits.values.fold(
      0.0,
      (sum, budget) => sum + budget,
    );
    final totalUsed = widget.allReimbursements.fold(
      0.0,
      (sum, item) => sum + (item.amount ?? 0.0),
    );
    final utilizationPercentage = totalBudget > 0
        ? (totalUsed / totalBudget * 100)
        : 0.0;

    return {
      'totalBudget': totalBudget,
      'usedAmount': totalUsed,
      'remainingAmount': totalBudget - totalUsed,
      'utilizationPercentage': utilizationPercentage,
      'avgMonthly': totalUsed / 12, // Assuming yearly data
    };
  }

  Map<String, Map<String, dynamic>> _getCategoryBudgetData() {
    Map<String, double> categoryUsage = {};

    // Calculate actual usage per category
    for (var item in widget.allReimbursements) {
      final category = item.category ?? 'Other';
      categoryUsage[category] =
          (categoryUsage[category] ?? 0.0) + (item.amount ?? 0.0);
    }

    Map<String, Map<String, dynamic>> result = {};

    _budgetLimits.forEach((category, budget) {
      final used = categoryUsage[category] ?? 0.0;
      final remaining = budget - used;
      final utilizationPercentage = budget > 0 ? (used / budget * 100) : 0.0;

      result[category] = {
        'budget': budget,
        'used': used,
        'remaining': remaining,
        'utilizationPercentage': utilizationPercentage,
      };
    });

    return result;
  }

  Map<String, Map<String, dynamic>> _getDepartmentBudgetData() {
    Map<String, double> departmentUsage = {};
    Map<String, int> employeeCount = {};

    // Calculate actual usage per department
    for (var user in widget.users) {
      final dept = _getUserDepartmentFromUser(user);
      departmentUsage[dept] =
          (departmentUsage[dept] ?? 0.0) + (user.totalAmount ?? 0.0);
      employeeCount[dept] = (employeeCount[dept] ?? 0) + 1;
    }

    Map<String, Map<String, dynamic>> result = {};

    _departmentBudgets.forEach((department, budget) {
      final used = departmentUsage[department] ?? 0.0;
      final remaining = budget - used;
      final utilizationPercentage = budget > 0 ? (used / budget * 100) : 0.0;

      result[department] = {
        'budget': budget,
        'used': used,
        'remaining': remaining,
        'utilizationPercentage': utilizationPercentage,
        'employeeCount': employeeCount[department] ?? 0,
      };
    });

    return result;
  }

  String _getUserDepartmentFromUser(dynamic user) {
    final depts = ['IT', 'HR', 'Finance', 'Marketing', 'Operations'];
    final userId = user.userId ?? user.toString();
    return depts[userId.hashCode % depts.length];
  }

  Map<String, dynamic> _getBudgetTrendsData() {
    // Mock data - in real app, calculate from historical data
    return {
      'currentMonth': 'Rp 45.2M',
      'currentMonthTrend': '+12%',
      'lastMonth': 'Rp 40.3M',
      'lastMonthTrend': '+8%',
      'ytdAverage': 'Rp 42.7M',
      'ytdTrend': '+15%',
      'projected': 'Rp 48.1M',
      'projectedTrend': '+6%',
    };
  }

  List<Map<String, dynamic>> _getBudgetAlerts() {
    final alerts = <Map<String, dynamic>>[];
    final categoryData = _getCategoryBudgetData();
    final departmentData = _getDepartmentBudgetData();

    // Check category alerts
    categoryData.forEach((category, data) {
      final utilization = data['utilizationPercentage'] as double;
      if (utilization >= 95) {
        alerts.add({
          'severity': 'critical',
          'title': '$category Budget Critical',
          'message':
              'Budget utilization ${utilization.toStringAsFixed(1)}% - Immediate action required',
          'type': 'category',
          'target': category,
        });
      } else if (utilization >= 85) {
        alerts.add({
          'severity': 'warning',
          'title': '$category Budget Warning',
          'message':
              'Budget utilization ${utilization.toStringAsFixed(1)}% - Monitor closely',
          'type': 'category',
          'target': category,
        });
      }
    });

    // Check department alerts
    departmentData.forEach((department, data) {
      final utilization = data['utilizationPercentage'] as double;
      if (utilization >= 95) {
        alerts.add({
          'severity': 'critical',
          'title': '$department Dept Critical',
          'message':
              'Department budget ${utilization.toStringAsFixed(1)}% utilized',
          'type': 'department',
          'target': department,
        });
      } else if (utilization >= 85) {
        alerts.add({
          'severity': 'warning',
          'title': '$department Dept Warning',
          'message':
              'Department budget ${utilization.toStringAsFixed(1)}% utilized',
          'type': 'department',
          'target': department,
        });
      }
    });

    return alerts;
  }

  Map<String, dynamic> _getBudgetForecastData() {
    final currentTrend = 0.12; // 12% growth
    final currentMonthlyAvg = 45200000; // 45.2M

    return {
      'summary':
          'Berdasarkan trend saat ini, proyeksi budget untuk 3 bulan kedepan menunjukkan peningkatan 12% per bulan. Disarankan untuk menyesuaikan budget limit kategori Transport dan Medical.',
      'months': [
        {
          'month': 'Next Month',
          'projected': currentMonthlyAvg * (1 + currentTrend),
          'confidence': 85,
        },
        {
          'month': '2 Months',
          'projected': currentMonthlyAvg * (1 + currentTrend * 2),
          'confidence': 78,
        },
        {
          'month': '3 Months',
          'projected': currentMonthlyAvg * (1 + currentTrend * 3),
          'confidence': 65,
        },
      ],
    };
  }

  void _handleAlert(Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['message']),
            const SizedBox(height: 16),
            Text(
              'Recommended Actions:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (alert['type'] == 'category') ...[
              Text('• Review and approve pending ${alert['target']} requests'),
              Text('• Consider increasing ${alert['target']} budget limit'),
              Text('• Implement approval workflow for ${alert['target']}'),
            ] else ...[
              Text('• Meet with ${alert['target']} department head'),
              Text('• Review department spending patterns'),
              Text('• Consider budget reallocation'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _takeAction(alert);
            },
            child: const Text('Take Action'),
          ),
        ],
      ),
    );
  }

  void _takeAction(Map<String, dynamic> alert) {
    // Implement specific actions based on alert type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action initiated for ${alert['title']}'),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
  }

  void _editBudgets() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Budget Limits'),
        content: const Text(
          'Budget editing interface will be implemented here',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _exportBudgetReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Budget Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportAsExcel();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportAsPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF export will be implemented'),
        backgroundColor: Color(0xFF8B5CF6),
      ),
    );
  }

  void _exportAsExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Excel export will be implemented'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }
}

class _ReimbursementWebTab {
  final IconData icon;
  final String label;
  final int index;

  const _ReimbursementWebTab(this.icon, this.label, this.index);
}
