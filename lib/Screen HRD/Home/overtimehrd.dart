// screens/overtime_hrd_screen.dart
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:absensikaryawan/Screen%20admin/Home/overtimeadmin.dart';
import 'package:absensikaryawan/Screen%20admin/model/overtimemodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/overtimeadminservice.dart';
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── helper ──────────────────────────────────────────────────────────
bool _isWebLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

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
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _selectedStatus;
  String? _selectedUserId;
  bool _isSelectionMode = false;
  Set<int> _selectedItems = {};
  double _policyMaxDailyHours = 4;
  double _policyMaxMonthlyHours = 40;
  double _policyAutoApproveUnderHours = 1;
  double _policyRequireApprovalAboveHours = 2;
  bool _policyAllowWeekend = false;
  bool _policyRequireNote = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Web: tab index aktif
  int _webTabIndex = 0;

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

      await _loadPolicySettings();

      if (_currentUserId != null && _currentUserName != null) {
        await _loadAllData();
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Data user tidak ditemukan. Silakan login ulang.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal memuat data user: $e');
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      if (_currentUserId == null) {
        throw Exception('User ID tidak tersedia.');
      }
      try {
        final futures =
            await Future.wait([
              OvertimeAdminService.getAllOvertimes(
                adminId: _currentUserId!,
                yearFilter: _selectedYear,
                monthFilter: _selectedMonth,
              ),
              OvertimeAdminService.getUsersWithOvertimes(
                adminId: _currentUserId!,
                year: _selectedYear,
                month: _selectedMonth,
              ),
              OvertimeAdminService.getAdminStatistics(
                adminId: _currentUserId!,
                year: _selectedYear,
                month: _selectedMonth,
              ),
            ]).timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Request timeout.'),
            );
        final overtimes =
            (futures[0] as ApiResponse<List<AdminOvertimeData>>).data ?? [];
        final users =
            (futures[1] as ApiResponse<List<UserWithOvertimes>>).data ?? [];
        final statistics =
            (futures[2] as ApiResponse<OvertimeAdminStatistics>).data;

        setState(() {
          _allOvertimes = overtimes;
          _users = users;
          _statistics = statistics;
          _applyFilters();
          _isLoading = false;
        });
      } catch (e) {
        if (e.toString().toLowerCase().contains('admin') ||
            e.toString().toLowerCase().contains('akses')) {
          _showErrorSnackBar('Akses ditolak. Hubungi administrator.');
          setState(() => _isLoading = false);
          return;
        }
        await _loadDataIndividually();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Terjadi kesalahan sistem: $e');
    }
  }

  Widget _buildMonthYearFilter() {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(6, (index) => currentYear - index);

    final months = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Semua Bulan')),
      const DropdownMenuItem<int?>(value: 1, child: Text('Januari')),
      const DropdownMenuItem<int?>(value: 2, child: Text('Februari')),
      const DropdownMenuItem<int?>(value: 3, child: Text('Maret')),
      const DropdownMenuItem<int?>(value: 4, child: Text('April')),
      const DropdownMenuItem<int?>(value: 5, child: Text('Mei')),
      const DropdownMenuItem<int?>(value: 6, child: Text('Juni')),
      const DropdownMenuItem<int?>(value: 7, child: Text('Juli')),
      const DropdownMenuItem<int?>(value: 8, child: Text('Agustus')),
      const DropdownMenuItem<int?>(value: 9, child: Text('September')),
      const DropdownMenuItem<int?>(value: 10, child: Text('Oktober')),
      const DropdownMenuItem<int?>(value: 11, child: Text('November')),
      const DropdownMenuItem<int?>(value: 12, child: Text('Desember')),
    ];

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            value: _selectedMonth,
            decoration: InputDecoration(
              labelText: 'Bulan',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            items: months,
            onChanged: (value) async {
              setState(() {
                _selectedMonth = value;
              });
              await _loadAllData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: InputDecoration(
              labelText: 'Tahun',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            items: years.map((year) {
              return DropdownMenuItem<int>(
                value: year,
                child: Text(year.toString()),
              );
            }).toList(),
            onChanged: (value) async {
              if (value == null) return;

              setState(() {
                _selectedYear = value;
              });
              await _loadAllData();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadDataIndividually() async {
    List<AdminOvertimeData> overtimes = [];
    List<UserWithOvertimes> users = [];
    OvertimeAdminStatistics? statistics;

    try {
      overtimes =
          (await OvertimeAdminService.getAllOvertimes(
            adminId: _currentUserId!,
            yearFilter: _selectedYear,
            monthFilter: _selectedMonth,
          )).data ??
          [];
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data overtime: $e');
    }

    try {
      users =
          (await OvertimeAdminService.getUsersWithOvertimes(
            adminId: _currentUserId!,
            year: _selectedYear,
            month: _selectedMonth,
          )).data ??
          [];
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data user overtime: $e');
    }

    try {
      statistics = (await OvertimeAdminService.getAdminStatistics(
        adminId: _currentUserId!,
        year: _selectedYear,
        month: _selectedMonth,
      )).data;
    } catch (_) {}

    setState(() {
      _allOvertimes = overtimes;
      _users = users;
      _statistics = statistics;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _onSearchChanged() => _applyFilters();

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return baseSize - 2;
    if (w < 400) return baseSize - 1;
    return baseSize;
  }

  void _applyFilters() {
    List<AdminOvertimeData> filtered = _allOvertimes;

    if (_selectedStatus != null && _selectedStatus != 'Semua Status') {
      filtered = filtered
          .where(
            (i) => i.status.toLowerCase() == _selectedStatus!.toLowerCase(),
          )
          .toList();
    }
    if (_selectedUserId != null) {
      filtered = filtered.where((i) => i.userId == _selectedUserId).toList();
    }
    final kw = _searchController.text.toLowerCase();
    if (kw.isNotEmpty) {
      filtered = filtered.where((i) {
        return i.userName.toLowerCase().contains(kw) ||
            (i.userJob?.toLowerCase().contains(kw) ?? false) ||
            (i.catatan?.toLowerCase().contains(kw) ?? false);
      }).toList();
    }

    filtered.sort((a, b) {
      if (a.status.toLowerCase() == 'pending' &&
          b.status.toLowerCase() != 'pending') {
        return -1;
      }
      if (a.status.toLowerCase() != 'pending' &&
          b.status.toLowerCase() == 'pending') {
        return 1;
      }
      if (a.status.toLowerCase() == 'pending') {
        return b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted);
      }
      return b.submittedAt.compareTo(a.submittedAt);
    });

    setState(() {
      _filteredOvertimes = filtered;
      _selectedItems.clear();
    });
  }

  Future<void> _refreshData() async {
    if (_currentUserId == null || _currentUserName == null) {
      await _loadUserData();
      return;
    }
    await _loadAllData();
  }

  void _showSuccessSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

  void _showErrorSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

  void _showOvertimeDetail(AdminOvertimeData item) {
    if (_currentUserId == null || _currentUserName == null) {
      _showErrorSnackBar('Data user belum dimuat.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OvertimeDetailModal(
        item: item,
        currentAdminId: _currentUserId!,
        currentAdminName: _currentUserName!,
        onActionCompleted: _refreshData,
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedItems.clear();
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

  void _selectAll() => setState(() {
    _selectedItems = _filteredOvertimes
        .where((i) => i.canBeModified)
        .map((i) => i.id)
        .toSet();
  });

  void _deselectAll() => setState(() => _selectedItems.clear());

  Future<void> _bulkAction(String action) async {
    if (_selectedItems.isEmpty) {
      _showErrorSnackBar('Pilih minimal satu item');
      return;
    }
    String? rejectionReason;
    if (action == 'reject') {
      rejectionReason = await _showRejectionReasonDialog();
      if (rejectionReason == null) return;
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
    final txt = action == 'approve' ? 'menyetujui' : 'menolak';
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Konfirmasi $txt'),
            content: Text('Apakah Anda yakin ingin $txt $count item?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(txt == 'menyetujui' ? 'Setujui' : 'Tolak'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showRejectionReasonDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alasan Penolakan'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Masukkan alasan penolakan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);

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
          : isWeb
          ? _buildWebLayout()
          : _buildMobileLayout(),
      floatingActionButton: _isSelectionMode && _selectedItems.isNotEmpty
          ? _buildBulkActionButtons()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(bool isWeb) {
    return AppBar(
      title: Text(
        _isSelectionMode ? '${_selectedItems.length} dipilih' : 'HRD Overtime',
        style: TextStyle(
          fontSize: _getResponsiveFontSize(context, 20),
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: isWeb ? false : true,
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
      // TabBar hanya di mobile
      bottom: isWeb
          ? null
          : TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF3B82F6),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF3B82F6),
              labelStyle: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
              ),
              tabs: const [
                Tab(text: 'Dashboard'),
                Tab(text: 'Overtime'),
                Tab(text: 'Users'),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [_buildDashboardTab(), _buildOvertimesTab(), _buildUsersTab()],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB LAYOUT — sidebar kiri + IndexedStack kanan
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    final tabs = [
      _WebTab(Icons.dashboard, 'Dashboard', 0),
      _WebTab(Icons.access_time_filled, 'Overtime', 1),
      _WebTab(Icons.people, 'Users', 2),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sidebar kiri ────────────────────────────────────
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
              // Statistik ringkas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildWebStatsSummary(),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              // Nav items
              ...tabs.map((tab) {
                final isSel = _webTabIndex == tab.index;
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
                      color: isSel
                          ? const Color(0xFF3B82F6).withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSel
                          ? Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 16,
                          color: isSel
                              ? const Color(0xFF3B82F6)
                              : Colors.grey[500],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSel
                                ? const Color(0xFF3B82F6)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (_isSelectionMode && _selectedItems.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        '${_selectedItems.length} dipilih',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _bulkAction('approve'),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text(
                            'Setujui',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _bulkAction('reject'),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text(
                            'Tolak',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Konten kanan ─────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: _webTabIndex,
            children: [
              _buildDashboardTab(),
              _buildOvertimesTab(),
              _buildUsersTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats ringkas sidebar ──────────────────────────────
  Widget _buildWebStatsSummary() {
    final items = [
      {
        'label': 'Total',
        'value': _statistics?.totalSubmissions ?? _allOvertimes.length,
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

  List<Widget> _buildNormalActions() => [
    Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.refresh, color: Colors.black87, size: 18),
        onPressed: _isLoading ? null : _refreshData,
      ),
    ),
  ];

  List<Widget> _buildSelectionActions() => [
    TextButton(
      onPressed:
          _selectedItems.length ==
              _filteredOvertimes.where((i) => i.canBeModified).length
          ? _deselectAll
          : _selectAll,
      child: Text(
        _selectedItems.length ==
                _filteredOvertimes.where((i) => i.canBeModified).length
            ? 'Batal Pilih'
            : 'Pilih Semua',
      ),
    ),
  ];

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

  // ─────────────────────────────────────────────────────────────────
  // DASHBOARD TAB
  // ─────────────────────────────────────────────────────────────────
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
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
                    size: 36,
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
                            fontSize: _getResponsiveFontSize(context, 17),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUserName ?? 'HRD Manager',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 13),
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

            const SizedBox(height: 20),

            // Filter Periode
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          size: 17,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Periode Data Overtime',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMonthYearFilter(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Statistics Cards
            if (_statistics != null) _buildStatisticsCards(_statistics!),

            if (_statistics == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Statistik belum tersedia untuk periode ini.',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 13),
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Dashboard 2 kolom di web / 1 kolom di mobile
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildUrgentItems()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildQuickActions()),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUrgentItems(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // OVERTIME TAB — web: filter sidebar + list
  // ─────────────────────────────────────────────────────────────────
  Widget _buildOvertimesTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          return Column(
            children: [
              // Filter area
              Container(
                padding: EdgeInsets.all(isWide ? 16 : 14),
                color: Colors.white,
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari nama, departemen, atau catatan...',
                        hintStyle: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 13),
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
                                icon: const Icon(Icons.clear, size: 16),
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
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Filter dropdowns
                    if (isWide)
                      Column(
                        children: [
                          Row(
                            children: [
                              Flexible(child: _buildStatusFilter()),
                              const SizedBox(width: 10),
                              Flexible(child: _buildDepartmentFilter()),
                              const SizedBox(width: 10),
                              Flexible(child: _buildUserFilter()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildMonthYearFilter(),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Flexible(child: _buildStatusFilter()),
                              const SizedBox(width: 10),
                              Flexible(child: _buildDepartmentFilter()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildUserFilter(),
                          const SizedBox(height: 10),
                          _buildMonthYearFilter(),
                        ],
                      ),
                  ],
                ),
              ),
              // List header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_list,
                            size: 14,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_filteredOvertimes.length} Hasil',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 13),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_getTotalOvertimeHours() > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Total: ${_getTotalOvertimeHours().toStringAsFixed(1)} jam',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    if (_isSelectionMode && _selectedItems.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_selectedItems.length} dipilih',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.sort,
                        color: Color(0xFF6B7280),
                        size: 18,
                      ),
                      onSelected: _sortOvertimes,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'date_desc',
                          child: Text('Tanggal Terbaru'),
                        ),
                        PopupMenuItem(
                          value: 'date_asc',
                          child: Text('Tanggal Terlama'),
                        ),
                        PopupMenuItem(
                          value: 'hours_desc',
                          child: Text('Jam Terbanyak'),
                        ),
                        PopupMenuItem(
                          value: 'urgent',
                          child: Text('Paling Urgent'),
                        ),
                        PopupMenuItem(
                          value: 'name',
                          child: Text('Nama Karyawan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: _filteredOvertimes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _filteredOvertimes.length,
                        itemBuilder: (_, i) =>
                            _buildHRDOvertimeCard(_filteredOvertimes[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // USERS TAB — web: GridView 2 kolom
  // ─────────────────────────────────────────────────────────────────
  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: _buildMonthYearFilter(),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const Text(
                  'Daftar User Overtime',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_users.length} user',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _users.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      return _buildHRDUserCard(_users[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // STATISTICS CARDS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStatisticsCards(OvertimeAdminStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Statistik Overtime HRD',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 17),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            TextButton.icon(
              onPressed: _showOvertimeReport,
              icon: const Icon(Icons.assessment, size: 14),
              label: const Text('Laporan'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 600 ? 4 : 2;
            final ratio = constraints.maxWidth > 600 ? 1.5 : 1.3;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                _buildStatCard(
                  title: 'Total Pengajuan',
                  value: stats.totalSubmissions.toString(),
                  icon: Icons.access_time_filled,
                  color: const Color(0xFF6366F1),
                  trend: '+12%',
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
                  trend: '+5%',
                  onTap: () => _navigateToOvertimesWithFilter('Approved'),
                ),
                _buildStatCard(
                  title: 'Ditolak',
                  value: stats.rejectedCount.toString(),
                  icon: Icons.cancel,
                  color: const Color(0xFFEF4444),
                  trend: '-3%',
                  onTap: () => _navigateToOvertimesWithFilter('Rejected'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _buildHRDInsights(),
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
                            borderRadius: BorderRadius.circular(10),
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
                  fontSize: _getResponsiveFontSize(context, 22),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
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
    );
  }

  Widget _buildHRDInsights() {
    final totalHours = _calculateTotalOvertimeHours();
    final avgHours =
        totalHours / (_allOvertimes.isEmpty ? 1 : _allOvertimes.length);

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
              const Icon(Icons.insights, color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 8),
              Text(
                'HRD Insights',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInsightRow(
            'Total Jam Overtime',
            '${totalHours.toStringAsFixed(1)} jam',
          ),
          _buildInsightRow(
            'Rata-rata per Pengajuan',
            '${avgHours.toStringAsFixed(1)} jam',
          ),
          _buildInsightRow('Departemen Tertinggi', _getTopOvertimeDepartment()),
          _buildInsightRow(
            'Tingkat Approval',
            '${_calculateApprovalRate().toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 13),
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
                fontSize: _getResponsiveFontSize(context, 13),
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

  Widget _buildUrgentItems() {
    final urgent = _allOvertimes
        .where(
          (i) =>
              i.status.toLowerCase() == 'pending' && i.daysSinceSubmitted > 2,
        )
        .take(3)
        .toList();

    if (urgent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tidak ada pengajuan urgent',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 13),
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
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pengajuan Urgent',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 15),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _navigateToOvertimesWithFilter('Pending'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...urgent.map(
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
            fontSize: _getResponsiveFontSize(context, 15),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 400 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: [
                _buildQuickActionCard(
                  title: 'Review Pending',
                  subtitle: '${_statistics?.pendingCount ?? 0} pengajuan',
                  icon: Icons.pending_actions,
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    setState(() => _webTabIndex = 1);
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
                    setState(() => _webTabIndex = 1);
                    _tabController.animateTo(1);
                    _toggleSelectionMode();
                  },
                ),
                _buildQuickActionCard(
                  title: 'Generate Report',
                  subtitle: 'Laporan overtime',
                  icon: Icons.assessment,
                  color: const Color(0xFF6366F1),
                  onTap: _showOvertimeReport,
                ),
                _buildQuickActionCard(
                  title: 'Policy Settings',
                  subtitle: 'Atur kebijakan',
                  icon: Icons.settings,
                  color: const Color(0xFF8B5CF6),
                  onTap: _showPolicySettings,
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
                      fontSize: _getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 10),
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
  }

  // ─────────────────────────────────────────────────────────────────
  // FILTER WIDGETS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStatusFilter() => DropdownButtonFormField<String>(
    value: _selectedStatus,
    decoration: InputDecoration(
      labelText: 'Status',
      labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 11)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
    ),
    style: TextStyle(
      fontSize: _getResponsiveFontSize(context, 13),
      color: Colors.black,
    ),
    isExpanded: true,
    items: _statusOptions.map((s) {
      final v = s == 'Semua Status' ? null : s;
      return DropdownMenuItem(
        value: v,
        child: Text(
          s == 'Semua Status'
              ? s
              : OvertimeAdminService.getStatusDisplayName(s),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList(),
    onChanged: (v) => setState(() {
      _selectedStatus = v;
      _applyFilters();
    }),
  );

  Widget _buildDepartmentFilter() => DropdownButtonFormField<String>(
    value: null,
    decoration: InputDecoration(
      labelText: 'Departemen',
      labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 11)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
    ),
    style: TextStyle(
      fontSize: _getResponsiveFontSize(context, 13),
      color: Colors.black,
    ),
    isExpanded: true,
    items:
        ['Semua Departemen', 'IT', 'HR', 'Finance', 'Marketing', 'Operations']
            .map(
              (d) => DropdownMenuItem(
                value: d == 'Semua Departemen' ? null : d,
                child: Text(d, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
    onChanged: (_) {},
  );


  Widget _buildUserFilter() {
    final opts = ['Semua User'] + _users.map((u) => u.name).toList();
    String cur = 'Semua User';
    if (_selectedUserId != null) {
      try {
        cur = _users.firstWhere((u) => u.userId == _selectedUserId).name;
      } catch (_) {
        _selectedUserId = null;
      }
    }
    return DropdownButtonFormField<String>(
      value: cur,
      decoration: InputDecoration(
        labelText: 'Karyawan',
        labelStyle: TextStyle(fontSize: _getResponsiveFontSize(context, 11)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(
        fontSize: _getResponsiveFontSize(context, 13),
        color: Colors.black,
      ),
      isExpanded: true,
      items: opts
          .map(
            (name) => DropdownMenuItem(
              value: name,
              child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() {
        _selectedUserId = v == 'Semua User'
            ? null
            : _users.firstWhere((u) => u.name == v).userId;
        _applyFilters();
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // CARD OVERTIME
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHRDOvertimeCard(
    AdminOvertimeData item, {
    bool isUrgent = false,
  }) {
    final isSelected = _selectedItems.contains(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  if (_isSelectionMode && item.canBeModified) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleItemSelection(item.id),
                      activeColor: const Color(0xFF6366F1),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 6),
                  ],
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
                              fontSize: _getResponsiveFontSize(context, 9),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    item.overtimeIcon,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 18),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item.formattedDate,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: item.statusColorValue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      item.statusText,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: item.statusColorValue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // User info
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
                            fontSize: _getResponsiveFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.userJob ?? 'No Position'} • ${_getUserDepartment(item)}',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 11),
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Time info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              item.formattedTimeRange,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 12),
                                color: const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.formattedTotalJam,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Pending actions
              if (item.status.toLowerCase() == 'pending') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Diajukan ${item.daysSinceSubmitted} hari lalu',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 11),
                                color: item.urgencyColor,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isSelectionMode)
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
              // Catatan
              if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
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
                            size: 12,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Catatan:',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 11),
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
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              // Rejection reason
              if (item.rejectionReason != null &&
                  item.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
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
                            size: 12,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Alasan Penolakan:',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 11),
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
                          fontSize: _getResponsiveFontSize(context, 12),
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

  // ─────────────────────────────────────────────────────────────────
  // USER CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHRDUserCard(UserWithOvertimes user) {
    final pct = _calculateUserOvertimePercentage(user);
    final isHigh = user.totalApprovedHours > 40;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selectedUserId = user.userId;
          _webTabIndex = 1;
          _tabController.animateTo(1);
          _applyFilters();
        }),
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
                        fontSize: 14,
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
                            fontSize: _getResponsiveFontSize(context, 14),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${user.jobs ?? '-'} • ${_getUserDepartmentFromUser(user)}',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isHigh)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 11,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 3),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Overtime',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 11),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    '${user.totalApprovedHours.toStringAsFixed(1)} jam',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 11),
                      fontWeight: FontWeight.w600,
                      color: isHigh ? Colors.orange : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isHigh ? Colors.orange : const Color(0xFF10B981),
                ),
                minHeight: 5,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
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
      width: 56,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 15),
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 10),
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
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
                size: 60,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _allOvertimes.isEmpty && _users.isEmpty
                  ? 'Tidak Ada Koneksi Data'
                  : 'Tidak Ada Data',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 17),
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
                fontSize: _getResponsiveFontSize(context, 13),
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            if (_allOvertimes.isEmpty && _users.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
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

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────
  void _navigateToOvertimesWithFilter(String filterType) async {
    setState(() => _webTabIndex = 1);
    _tabController.animateTo(1);
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _selectedStatus = filterType == 'all' ? null : filterType;
      _selectedUserId = null;
      _searchController.clear();
      _applyFilters();
    });
  }

  double _getTotalOvertimeHours() =>
      _filteredOvertimes.fold(0.0, (s, i) => s + i.totalJam);

  double _calculateTotalOvertimeHours() => _allOvertimes
      .where((i) => i.status.toLowerCase() == 'approved')
      .fold(0.0, (s, i) => s + i.totalJam);

  String _getTopOvertimeDepartment() => 'IT Department';

  double _calculateApprovalRate() {
    if (_statistics == null || _statistics!.totalSubmissions == 0) return 0;
    return _statistics!.approvedCount / _statistics!.totalSubmissions * 100;
  }

  double _calculateUserOvertimePercentage(UserWithOvertimes user) =>
      (user.totalApprovedHours / 50 * 100).clamp(0, 100);

  String _getUserDepartment(AdminOvertimeData item) {
    if (item.userJob?.contains('Developer') ?? false) return 'IT';
    if (item.userJob?.contains('HR') ?? false) return 'HR';
    if (item.userJob?.contains('Finance') ?? false) return 'Finance';
    if (item.userJob?.contains('Marketing') ?? false) return 'Marketing';
    return 'Operations';
  }

  String _getUserDepartmentFromUser(UserWithOvertimes user) {
    const depts = ['IT', 'HR', 'Finance', 'Marketing', 'Operations'];
    return depts[user.userId.hashCode % depts.length];
  }

  void _sortOvertimes(String sortBy) {
    setState(() {
      switch (sortBy) {
        case 'date_desc':
          _filteredOvertimes.sort(
            (a, b) => b.submittedAt.compareTo(a.submittedAt),
          );
          break;
        case 'date_asc':
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
      final resp = await OvertimeAdminService.reviewOvertime(
        id: item.id,
        status: status,
        approvedBy: _currentUserName!,
        adminId: _currentUserId!,
      );
      if (resp.success) {
        await _refreshData();
        _showSuccessSnackBar(
          status == 'Approved' ? 'Overtime disetujui' : 'Overtime ditolak',
        );
      } else {
        _showErrorSnackBar(resp.message);
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  Future<void> _loadPolicySettings() async {
    final prefs = await SharedPreferences.getInstance();

    _policyMaxDailyHours =
        prefs.getDouble('overtime_policy_max_daily_hours') ?? 4;
    _policyMaxMonthlyHours =
        prefs.getDouble('overtime_policy_max_monthly_hours') ?? 40;
    _policyAutoApproveUnderHours =
        prefs.getDouble('overtime_policy_auto_approve_under_hours') ?? 1;
    _policyRequireApprovalAboveHours =
        prefs.getDouble('overtime_policy_require_approval_above_hours') ?? 2;
    _policyAllowWeekend =
        prefs.getBool('overtime_policy_allow_weekend') ?? false;
    _policyRequireNote = prefs.getBool('overtime_policy_require_note') ?? true;
  }

  Future<void> _savePolicySettings({
    required double maxDailyHours,
    required double maxMonthlyHours,
    required double autoApproveUnderHours,
    required double requireApprovalAboveHours,
    required bool allowWeekend,
    required bool requireNote,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('overtime_policy_max_daily_hours', maxDailyHours);
    await prefs.setDouble('overtime_policy_max_monthly_hours', maxMonthlyHours);
    await prefs.setDouble(
      'overtime_policy_auto_approve_under_hours',
      autoApproveUnderHours,
    );
    await prefs.setDouble(
      'overtime_policy_require_approval_above_hours',
      requireApprovalAboveHours,
    );
    await prefs.setBool('overtime_policy_allow_weekend', allowWeekend);
    await prefs.setBool('overtime_policy_require_note', requireNote);

    setState(() {
      _policyMaxDailyHours = maxDailyHours;
      _policyMaxMonthlyHours = maxMonthlyHours;
      _policyAutoApproveUnderHours = autoApproveUnderHours;
      _policyRequireApprovalAboveHours = requireApprovalAboveHours;
      _policyAllowWeekend = allowWeekend;
      _policyRequireNote = requireNote;
    });

    _showSuccessSnackBar('Policy overtime berhasil disimpan');
  }

  String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatReportDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(date);
  }

  Future<void> _downloadOvertimeReportCsv(List<AdminOvertimeData> data) async {
    if (data.isEmpty) {
      _showErrorSnackBar('Tidak ada data overtime untuk dibuat laporan');
      return;
    }

    final totalJam = data.fold<double>(0, (sum, item) => sum + item.totalJam);
    final pending = data
        .where((e) => e.status.toLowerCase() == 'pending')
        .length;
    final approved = data
        .where((e) => e.status.toLowerCase() == 'approved')
        .length;
    final rejected = data
        .where((e) => e.status.toLowerCase() == 'rejected')
        .length;

    final Map<String, double> jamByUser = {};
    final Map<String, int> countByUser = {};
    final Map<String, double> jamByDept = {};

    for (final item in data) {
      jamByUser[item.userName] =
          (jamByUser[item.userName] ?? 0) + item.totalJam;
      countByUser[item.userName] = (countByUser[item.userName] ?? 0) + 1;

      final dept = _getUserDepartment(item);
      jamByDept[dept] = (jamByDept[dept] ?? 0) + item.totalJam;
    }

    final topUsers = jamByUser.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topDepartments = jamByDept.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer();

    buffer.writeln('\uFEFFLAPORAN OVERTIME HRD');
    buffer.writeln(
      'Tanggal Export,${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.now())}',
    );
    buffer.writeln('Dibuat Oleh,${_csv(_currentUserName ?? '-')}');
    buffer.writeln('Total Data,${data.length}');
    buffer.writeln('');

    buffer.writeln('RINGKASAN');
    buffer.writeln('Total Pengajuan,${data.length}');
    buffer.writeln('Pending,$pending');
    buffer.writeln('Approved,$approved');
    buffer.writeln('Rejected,$rejected');
    buffer.writeln('Total Jam Overtime,${totalJam.toStringAsFixed(1)} jam');
    buffer.writeln(
      'Rata-rata Jam per Pengajuan,${(totalJam / data.length).toStringAsFixed(1)} jam',
    );
    buffer.writeln('');

    buffer.writeln('POLICY YANG BERLAKU');
    buffer.writeln(
      'Maksimal Overtime Harian,${_policyMaxDailyHours.toStringAsFixed(1)} jam',
    );
    buffer.writeln(
      'Maksimal Overtime Bulanan,${_policyMaxMonthlyHours.toStringAsFixed(1)} jam',
    );
    buffer.writeln(
      'Auto Approve Di Bawah,${_policyAutoApproveUnderHours.toStringAsFixed(1)} jam',
    );
    buffer.writeln(
      'Wajib Approval Di Atas,${_policyRequireApprovalAboveHours.toStringAsFixed(1)} jam',
    );
    buffer.writeln('Boleh Weekend,${_policyAllowWeekend ? "Ya" : "Tidak"}');
    buffer.writeln('Wajib Catatan,${_policyRequireNote ? "Ya" : "Tidak"}');
    buffer.writeln('');

    buffer.writeln('REKAP PER KARYAWAN');
    buffer.writeln('Nama,Jumlah Pengajuan,Total Jam');
    for (final entry in topUsers) {
      buffer.writeln(
        '${_csv(entry.key)},${countByUser[entry.key] ?? 0},${entry.value.toStringAsFixed(1)}',
      );
    }
    buffer.writeln('');

    buffer.writeln('REKAP PER DEPARTEMEN');
    buffer.writeln('Departemen,Total Jam');
    for (final entry in topDepartments) {
      buffer.writeln('${_csv(entry.key)},${entry.value.toStringAsFixed(1)}');
    }
    buffer.writeln('');

    buffer.writeln('DETAIL DATA OVERTIME');
    buffer.writeln(
      'ID,Nama,Departemen,Jabatan,Tanggal,Jam Mulai - Selesai,Total Jam,Status,Catatan,Alasan Penolakan,Diajukan',
    );

    for (final item in data) {
      buffer.writeln(
        [
          item.id,
          _csv(item.userName),
          _csv(_getUserDepartment(item)),
          _csv(item.userJob ?? '-'),
          _csv(item.formattedDate),
          _csv(item.formattedTimeRange),
          item.totalJam.toStringAsFixed(1),
          _csv(item.statusText),
          _csv(item.catatan ?? '-'),
          _csv(item.rejectionReason ?? '-'),
          _csv(_formatReportDate(item.submittedAt)),
        ].join(','),
      );
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Laporan_Overtime_HRD_$timestamp.csv';

    try {
      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
        _showSuccessSnackBar('Laporan overtime berhasil diunduh');
        return;
      }

      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final permission = info.version.sdkInt >= 33
            ? Permission.photos
            : Permission.storage;

        var status = await permission.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          status = await permission.request();
        }

        if (!status.isGranted) {
          _showErrorSnackBar(
            'Izin penyimpanan diperlukan untuk export laporan',
          );
          return;
        }
      }

      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        throw Exception('Direktori penyimpanan tidak ditemukan');
      }

      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      final open = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Laporan Berhasil Dibuat'),
          content: Text('File tersimpan di:\n$path\n\nBuka sekarang?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buka'),
            ),
          ],
        ),
      );

      if (open == true) {
        await OpenFile.open(path);
      }

      _showSuccessSnackBar('Laporan overtime berhasil dibuat');
    } catch (e) {
      _showErrorSnackBar('Gagal membuat laporan: $e');
    }
  }

  void _showOvertimeReport() {
    String selectedScope = 'filtered';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final reportData = selectedScope == 'all'
                ? _allOvertimes
                : _filteredOvertimes;

            final totalJam = reportData.fold<double>(
              0,
              (sum, item) => sum + item.totalJam,
            );

            final pending = reportData
                .where((e) => e.status.toLowerCase() == 'pending')
                .length;
            final approved = reportData
                .where((e) => e.status.toLowerCase() == 'approved')
                .length;
            final rejected = reportData
                .where((e) => e.status.toLowerCase() == 'rejected')
                .length;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.assessment, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Generate Laporan Overtime')),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih data yang ingin dijadikan laporan:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      RadioListTile<String>(
                        value: 'filtered',
                        groupValue: selectedScope,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Data sesuai filter saat ini'),
                        subtitle: Text('${_filteredOvertimes.length} data'),
                        onChanged: (value) {
                          setDialogState(() => selectedScope = value!);
                        },
                      ),

                      RadioListTile<String>(
                        value: 'all',
                        groupValue: selectedScope,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Semua data overtime'),
                        subtitle: Text('${_allOvertimes.length} data'),
                        onChanged: (value) {
                          setDialogState(() => selectedScope = value!);
                        },
                      ),

                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _reportPreviewRow(
                              'Total Data',
                              '${reportData.length}',
                            ),
                            _reportPreviewRow(
                              'Total Jam',
                              '${totalJam.toStringAsFixed(1)} jam',
                            ),
                            _reportPreviewRow('Pending', '$pending'),
                            _reportPreviewRow('Approved', '$approved'),
                            _reportPreviewRow('Rejected', '$rejected'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF6366F1),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Laporan akan digenerate dalam format CSV dan bisa dibuka di Excel.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  onPressed: reportData.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await _downloadOvertimeReportCsv(reportData);
                        },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _reportPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicySettings() {
    final maxDailyCtrl = TextEditingController(
      text: _policyMaxDailyHours.toStringAsFixed(1),
    );
    final maxMonthlyCtrl = TextEditingController(
      text: _policyMaxMonthlyHours.toStringAsFixed(1),
    );
    final autoApproveCtrl = TextEditingController(
      text: _policyAutoApproveUnderHours.toStringAsFixed(1),
    );
    final requireApprovalCtrl = TextEditingController(
      text: _policyRequireApprovalAboveHours.toStringAsFixed(1),
    );

    bool allowWeekend = _policyAllowWeekend;
    bool requireNote = _policyRequireNote;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.settings, color: Color(0xFF8B5CF6)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Policy Settings Overtime')),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _policyNumberField(
                        controller: maxDailyCtrl,
                        label: 'Maksimal Overtime Harian',
                        suffix: 'jam',
                        icon: Icons.today,
                      ),
                      const SizedBox(height: 12),
                      _policyNumberField(
                        controller: maxMonthlyCtrl,
                        label: 'Maksimal Overtime Bulanan',
                        suffix: 'jam',
                        icon: Icons.calendar_month,
                      ),
                      const SizedBox(height: 12),
                      _policyNumberField(
                        controller: autoApproveCtrl,
                        label: 'Auto Approve Jika Di Bawah',
                        suffix: 'jam',
                        icon: Icons.check_circle,
                      ),
                      const SizedBox(height: 12),
                      _policyNumberField(
                        controller: requireApprovalCtrl,
                        label: 'Wajib Approval Jika Di Atas',
                        suffix: 'jam',
                        icon: Icons.admin_panel_settings,
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: allowWeekend,
                        title: const Text('Izinkan Overtime Weekend'),
                        subtitle: const Text(
                          'Sabtu/Minggu boleh mengajukan overtime',
                        ),
                        activeColor: const Color(0xFF8B5CF6),
                        onChanged: (value) {
                          setDialogState(() => allowWeekend = value);
                        },
                      ),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: requireNote,
                        title: const Text('Catatan Wajib Diisi'),
                        subtitle: const Text(
                          'Karyawan wajib mengisi alasan overtime',
                        ),
                        activeColor: const Color(0xFF8B5CF6),
                        onChanged: (value) {
                          setDialogState(() => requireNote = value);
                        },
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF7C3AED),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Setting ini disimpan di perangkat/app HRD. Kalau ingin berlaku global ke semua user, nanti perlu dibuatkan API dan tabel policy di database.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6D28D9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final maxDaily = double.tryParse(
                      maxDailyCtrl.text.replaceAll(',', '.'),
                    );
                    final maxMonthly = double.tryParse(
                      maxMonthlyCtrl.text.replaceAll(',', '.'),
                    );
                    final autoApprove = double.tryParse(
                      autoApproveCtrl.text.replaceAll(',', '.'),
                    );
                    final requireApproval = double.tryParse(
                      requireApprovalCtrl.text.replaceAll(',', '.'),
                    );

                    if (maxDaily == null ||
                        maxMonthly == null ||
                        autoApprove == null ||
                        requireApproval == null) {
                      _showErrorSnackBar('Semua angka policy wajib valid');
                      return;
                    }

                    if (maxDaily <= 0 || maxMonthly <= 0) {
                      _showErrorSnackBar('Maksimal jam harus lebih dari 0');
                      return;
                    }

                    if (autoApprove > requireApproval) {
                      _showErrorSnackBar(
                        'Auto approve tidak boleh lebih besar dari batas wajib approval',
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    await _savePolicySettings(
                      maxDailyHours: maxDaily,
                      maxMonthlyHours: maxMonthly,
                      autoApproveUnderHours: autoApprove,
                      requireApprovalAboveHours: requireApproval,
                      allowWeekend: allowWeekend,
                      requireNote: requireNote,
                    );
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Simpan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _policyNumberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

// ── Helper class ───────────────────────────────────────────────────
class _WebTab {
  final IconData icon;
  final String label;
  final int index;
  const _WebTab(this.icon, this.label, this.index);
}
