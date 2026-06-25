// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:absensikaryawan/Screen%20admin/model/timeoffmodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/timeoffserviceadmin.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Screen admin/service/web_preview.dart';
import '../../Services/time_off_model.dart' hide ApiResponse;
import '../../Services/time_off_service.dart';

bool _isWebLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class TimeOffHRDScreen extends StatefulWidget {
  const TimeOffHRDScreen({super.key});

  @override
  _TimeOffHRDScreenState createState() => _TimeOffHRDScreenState();
}

class _TimeOffHRDScreenState extends State<TimeOffHRDScreen>
    with SingleTickerProviderStateMixin {
  List<WorkPeriodModel> _workPeriods = [];
  WorkPeriodModel? _selectedWorkPeriod; // null = semua periode
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

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _webTabIndex = 0;

  final Map<String, int> _departmentStats = {};
  final Map<String, double> _leaveBalances = {};

  List<String> get _departments {
    final departments =
        _users
            .map((u) => u.department)
            .where((d) => d != null && d.trim().isNotEmpty)
            .map((d) => d!.trim())
            .toSet()
            .toList()
          ..sort();

    return ['Semua Departemen', ...departments];
  }

  void _openEmployeesTab() {
    setState(() {
      _webTabIndex = 2;
      _selectedUserId = null;
      _selectedDepartment = null;
    });

    _tabController.animateTo(2);
  }

  final List<String> _statusOptions = [
    'Semua Status',
    'Pending',
    'Pending HRD',
    'Pending Director',
    'Approved',
    'Rejected',
    'Processed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _webTabIndex = _tabController.index);
    });
    _loadUserData();
    _loadWorkPeriods();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _loadWorkPeriods() async {
    final res = await TimeOffService.getWorkPeriods();
    if (mounted && res.success && res.data != null) {
      setState(() {
        _workPeriods = res.data!;
        // Default: semua periode (null = tidak filter)
        _selectedWorkPeriod = null;
      });
    }
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
      final d = (u.department?.trim().isNotEmpty ?? false)
          ? u.department!.trim()
          : (u.jobs?.trim().isNotEmpty ?? false)
          ? u.jobs!.trim()
          : (u.jobPosition?.trim().isNotEmpty ?? false)
          ? u.jobPosition!.trim()
          : 'Tidak Ada Departemen';

      _departmentStats[d] = (_departmentStats[d] ?? 0) + u.totalTimeOff;
    }
  }

  void _showSetQuotaDialog(UserWithTimeOffs user) {
    final year = DateTime.now().year;
    // Ambil nilai kuota saat ini dari _leaveBalances atau default
    final annualCtrl = TextEditingController(text: user.annualQuota.toString());
    final birthCtrl = TextEditingController(text: '5');
    final bereavCtrl = TextEditingController(text: '2');

    // Load kuota aktual dari server dulu
    TimeOffAdminService.getEmployeeDetail(
      adminId: _currentUserId!,
      userId: user.userId,
      year: year,
    ).then((data) {
      final quotas = List<Map<String, dynamic>>.from(data['quotas'] ?? []);
      for (final q in quotas) {
        final qt = (q['quotaType'] ?? '').toString();
        final qa = (q['quotaAwal'] as num?)?.toInt() ?? 0;

        if (qt == 'annual') annualCtrl.text = qa.toString();
        if (qt == 'birth_leave') birthCtrl.text = qa.toString();
        if (qt == 'bereavement') bereavCtrl.text = qa.toString();
      }
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Atur Kuota Izin',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _quotaInputTile(
                icon: '🏖️',
                label: 'Izin Tahunan',
                desc: 'Cuti tahunan berbayar',
                ctrl: annualCtrl,
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 10),
              _quotaInputTile(
                icon: '👶',
                label: 'Izin Lahiran',
                desc: 'Cuti melahirkan/lahiran',
                ctrl: birthCtrl,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 10),
              _quotaInputTile(
                icon: '🕯️',
                label: 'Keluarga Meninggal',
                desc: 'Cuti duka keluarga',
                ctrl: bereavCtrl,
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              annualCtrl.dispose();
              birthCtrl.dispose();
              bereavCtrl.dispose();
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final annual = int.tryParse(annualCtrl.text.trim()) ?? -1;
              final birth = int.tryParse(birthCtrl.text.trim()) ?? -1;
              final bereav = int.tryParse(bereavCtrl.text.trim()) ?? -1;
              if (annual < 0 || birth < 0 || bereav < 0) {
                _snackErr('Nilai kuota tidak valid');
                return;
              }
              Navigator.pop(context);
              annualCtrl.dispose();
              birthCtrl.dispose();
              bereavCtrl.dispose();
              final res = await TimeOffAdminService.setUserQuotaAll(
                adminId: _currentUserId!,
                userId: user.userId,
                year: year,
                annualDays: annual,
                birthDays: birth,
                bereavDays: bereav,
              );

              if (res.success) {
                _snackOk(res.message);
                await _refreshData();
              } else {
                _snackErr(res.message);
              }
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Simpan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quotaInputTile({
    required String icon,
    required String label,
    required String desc,
    required TextEditingController ctrl,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              Text(
                desc,
                style: TextStyle(fontSize: 11, color: const Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 70,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            decoration: InputDecoration(
              suffixText: 'hr',
              suffixStyle: TextStyle(fontSize: 11, color: color),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );

  void _calculateLeaveBalances() {
    _leaveBalances.clear();

    for (var u in _users) {
      _leaveBalances[u.userId] = u.remainingDays.toDouble();
    }
  }

  Widget _buildWorkPeriodFilter() {
    if (_workPeriods.isEmpty) return const SizedBox.shrink();

    final items = <DropdownMenuItem<int>>[
      const DropdownMenuItem<int>(
        value: 0,
        child: Text('Semua Periode', overflow: TextOverflow.ellipsis),
      ),
      ..._workPeriods.map(
        (p) => DropdownMenuItem<int>(
          value: p.id,
          child: Text(p.label, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    final currentId = _selectedWorkPeriod?.id ?? 0;

    return DropdownButtonFormField<int>(
      value: currentId,
      decoration: InputDecoration(
        labelText: 'Periode Kerja',
        labelStyle: TextStyle(fontSize: _fs(12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(fontSize: _fs(13), color: Colors.black),
      isExpanded: true,
      items: items,
      onChanged: (v) {
        setState(() {
          _selectedWorkPeriod = (v == null || v == 0)
              ? null
              : _workPeriods.firstWhere((p) => p.id == v);
          _applyFilters();
        });
      },
    );
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

    // Filter periode kerja — ganti _selectedTimeRange dengan periode kalender
    if (_selectedWorkPeriod != null) {
      final start = _selectedWorkPeriod!.tanggalMulai;
      final end = _selectedWorkPeriod!.tanggalSelesai;
      f = f.where((i) {
        return !i.tanggalSelesai.isBefore(start) &&
            !i.tanggalMulai.isAfter(end);
      }).toList();
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

    // Sort: Pending HRD dulu → Pending Director → lainnya
    f.sort((a, b) {
      int priority(AdminTimeOffData x) {
        if (x.isPendingHrd) return 0;
        if (x.isPendingDirector) return 1;
        if (x.status.toLowerCase() == 'pending') return 2;
        return 3;
      }

      final pa = priority(a);
      final pb = priority(b);
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

  int get _pendingCountLive => _allTimeOffs.where((i) {
    final s = i.status.toLowerCase();
    return s == 'pending' ||
        s == 'pending hrd' ||
        s == 'pending director' ||
        s == 'menunggu hrd' ||
        s == 'menunggu director' ||
        s == 'menunggu org' ||
        s == 'menunggu laporan' ||
        s == 'menunggu verifikasi head' ||
        s == 'menunggu verifikasi hrd' ||
        s == 'menunggu transfer' ||
        s == 'pending finance';
  }).length;

  int get _approvedCountLive => _allTimeOffs.where((i) {
    final s = i.status.toLowerCase();
    return s == 'approved' || s == 'disetujui' || s == 'processed';
  }).length;

  int get _rejectedCountLive => _allTimeOffs.where((i) {
    final s = i.status.toLowerCase();
    return s == 'rejected' || s == 'ditolak';
  }).length;

  Widget _buildWebStatsSummary() {
    final items = [
      {'label': 'Total', 'value': _allTimeOffs.length, 'color': Colors.blue},
      {
        'label': 'Pending',
        // Pakai _pendingCountLive agar akurat
        'value': _pendingCountLive,
        'color': Colors.orange,
      },
      {'label': 'Approved', 'value': _approvedCountLive, 'color': Colors.green},
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
        ...items.map((item) {
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
              _buildQuickStat('Menunggu', '$_pendingCountLive', Icons.pending),
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
              value: _allTimeOffs.length.toString(),
              icon: Icons.calendar_month,
              color: const Color(0xFF6366F1),
              trend: '+12%',
              onTap: () => _navFilter('all'),
            ),
            _buildStatCard(
              title: 'Menunggu Review',
              // Pakai _pendingCountLive agar akurat include semua status
              value: _pendingCountLive.toString(),
              icon: Icons.pending_actions,
              color: const Color(0xFFF59E0B),
              urgent: _pendingCountLive > 0,
              onTap: () => _navFilter('Pending'),
            ),
            _buildStatCard(
              title: 'Disetujui',
              value: _approvedCountLive.toString(),
              icon: Icons.check_circle,
              color: const Color(0xFF10B981),
              trend: '+5%',
              onTap: () => _navFilter('Approved'),
            ),
            _buildStatCard(
              title: 'Ditolak',
              value: _rejectedCountLive.toString(),
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
              'Dashboard Izin Karyawan',
              style: TextStyle(
                fontSize: _fs(15),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            TextButton(
              onPressed: _openEmployeesTab,
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
                      Text(u.jobPosition ?? u.jobs ?? u.department ?? '-'),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${bal.toInt()} hr',
                      style: TextStyle(
                        fontSize: _fs(13),
                        fontWeight: FontWeight.w700,
                        color: low ? Colors.red : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showSetQuotaDialog(u),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.settings,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
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

  Widget _buildUrgentItems() {
    final urgent = _allTimeOffs
        .where((i) => i.needsReview && i.daysSinceSubmitted > 2)
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
              onPressed: () => _navFilter('Pending HRD'),
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
    setState(() => _webTabIndex = 3);
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
                    onChanged: (v) => setDialogState(() => annualQuota = v),
                  ),
                  const SizedBox(height: 14),
                  _buildPolicySlider(
                    title: 'Maksimal Cuti Berturut-turut',
                    value: maxConsecutive,
                    min: 1,
                    max: 30,
                    suffix: 'hari',
                    onChanged: (v) => setDialogState(() => maxConsecutive = v),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wajib lampiran untuk izin sakit'),
                    value: requireSickAttachment,
                    onChanged: (v) =>
                        setDialogState(() => requireSickAttachment = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Izinkan pengajuan tanggal mundur'),
                    value: allowBackdate,
                    onChanged: (v) => setDialogState(() => allowBackdate = v),
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
          _buildWorkPeriodFilter(), // ← ganti _buildTimeRangeFilter()
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

  Widget _buildStatusFilter() {
    final validValues = _statusOptions
        .where((s) => s != 'Semua Status')
        .toSet();

    final safeValue = validValues.contains(_selectedStatus)
        ? _selectedStatus
        : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: TextStyle(fontSize: _fs(12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(fontSize: _fs(13), color: Colors.black),
      items: _statusOptions.map((s) {
        final value = s == 'Semua Status' ? null : s;

        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            s == 'Semua Status'
                ? s
                : TimeOffAdminService.getStatusDisplayName(s),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (v) {
        setState(() {
          _selectedStatus = v;
          _applyFilters();
        });
      },
    );
  }

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
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (_, i) => _buildEmployeeCard(_users[i]),
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
      final excel = xl.Excel.createExcel();

      // Sheet1 harus dihapus SETELAH ada sheet lain yang dibuat.
      // Kalau dihapus duluan saat masih satu-satunya sheet, tidak akan
      // terhapus karena Excel tidak boleh punya 0 sheet.
      // Penghapusan dilakukan di bawah setelah sheetName dibuat.

      String fileName;
      String sheetName;
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      // Warna header — biru HRD
      final headerBg = xl.ExcelColor.fromHexString('#1E3A5F');
      final headerFg = xl.ExcelColor.fromHexString('#FFFFFF');
      final altRowBg = xl.ExcelColor.fromHexString('#F0F4F8');
      final boldStyle = xl.CellStyle(
        fontColorHex: xl.ExcelColor.fromHexString('#1E3A5F'),
        bold: true,
      );

      xl.CellStyle headerStyle() => xl.CellStyle(
        backgroundColorHex: headerBg,
        fontColorHex: headerFg,
        bold: true,
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      );

      xl.CellStyle altStyle() => xl.CellStyle(backgroundColorHex: altRowBg);

      // Helper: set header row
      void setHeaders(xl.Sheet sheet, List<String> headers) {
        for (int i = 0; i < headers.length; i++) {
          final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          );
          cell.value = xl.TextCellValue(headers[i]);
          cell.cellStyle = headerStyle();
        }
      }

      // Helper: set data row dengan alt-row coloring
      void setRow(
        xl.Sheet sheet,
        int rowIndex,
        List<xl.CellValue?> values, {
        bool isAlt = false,
      }) {
        for (int i = 0; i < values.length; i++) {
          final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
          );
          cell.value = values[i];
          if (isAlt) cell.cellStyle = altStyle();
        }
      }

      // Helper: format tanggal
      String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
      String fmtMonth(int month) => _getMonthName(month);

      // ── Normalize status ──────────────────────────────────────────────────
      String normalizeStatus(String s) => s.trim();
      bool isPendingLike(String s) {
        final sl = s.toLowerCase();
        return sl == 'pending' ||
            sl == 'menunggu laporan' ||
            sl == 'menunggu org';
      }

      bool isApprovedLike(String s) {
        final sl = s.toLowerCase();
        return sl == 'approved' || sl == 'processed' || sl == 'submitted';
      }

      bool isRejectedLike(String s) => s.toLowerCase() == 'rejected';
      String getDept(AdminTimeOffData item) =>
          item.userDepartment ?? 'Tidak Ada Departemen';

      // ── Tentukan sheet & data sesuai reportType ───────────────────────────

      if (reportType == 'bulanan') {
        fileName = 'laporan_bulanan_timeoff_hrd_$now.xlsx';
        sheetName = 'Laporan Bulanan';
        final sheet = excel[sheetName];

        setHeaders(sheet, [
          'Periode',
          'Tgl Mulai Periode',
          'Tgl Selesai Periode',
          'Total Pengajuan',
          'Menunggu',
          'Approved',
          'Rejected',
          'Total Hari',
        ]);

        int row = 1;

        if (_workPeriods.isNotEmpty) {
          // ── Grouping berdasarkan periode kerja dari kalender ─────────────
          // Urutan dari yang paling lama ke terbaru (asc)
          final sortedPeriods = List<WorkPeriodModel>.from(_workPeriods)
            ..sort((a, b) => a.tanggalMulai.compareTo(b.tanggalMulai));

          for (final period in sortedPeriods) {
            // Izin yang tanggalnya OVERLAP dengan periode ini
            final items = _allTimeOffs.where((x) {
              return !x.tanggalSelesai.isBefore(period.tanggalMulai) &&
                  !x.tanggalMulai.isAfter(period.tanggalSelesai);
            }).toList();

            final menunggu = items
                .where((x) => isPendingLike(normalizeStatus(x.status)))
                .length;
            final approved = items
                .where((x) => isApprovedLike(normalizeStatus(x.status)))
                .length;
            final rejected = items
                .where((x) => isRejectedLike(normalizeStatus(x.status)))
                .length;
            final totalHari = items.fold<int>(0, (s, x) => s + x.totalHari);

            setRow(sheet, row, [
              xl.TextCellValue(period.label),
              xl.TextCellValue(fmtDate(period.tanggalMulai)),
              xl.TextCellValue(fmtDate(period.tanggalSelesai)),
              xl.IntCellValue(items.length),
              xl.IntCellValue(menunggu),
              xl.IntCellValue(approved),
              xl.IntCellValue(rejected),
              xl.IntCellValue(totalHari),
            ], isAlt: row % 2 == 0);
            row++;
          }
        } else {
          // ── Fallback: grouping bulan/tahun biasa (kalau periode belum diset)
          final Map<String, List<AdminTimeOffData>> grouped = {};
          for (final item in _allTimeOffs) {
            final key =
                '${item.tanggalMulai.year}-${item.tanggalMulai.month.toString().padLeft(2, '0')}';
            grouped.putIfAbsent(key, () => []);
            grouped[key]!.add(item);
          }
          final entries = grouped.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          for (final e in entries) {
            final items = e.value;
            final first = items.first.tanggalMulai;
            final menunggu = items
                .where((x) => isPendingLike(normalizeStatus(x.status)))
                .length;
            final approved = items
                .where((x) => isApprovedLike(normalizeStatus(x.status)))
                .length;
            final rejected = items
                .where((x) => isRejectedLike(normalizeStatus(x.status)))
                .length;
            final totalHari = items.fold<int>(0, (s, x) => s + x.totalHari);

            final mulai = DateTime(first.year, first.month, 1);
            final selesai = DateTime(first.year, first.month + 1, 0);

            setRow(sheet, row, [
              xl.TextCellValue('${fmtMonth(first.month)} ${first.year}'),
              xl.TextCellValue(fmtDate(mulai)),
              xl.TextCellValue(fmtDate(selesai)),
              xl.IntCellValue(items.length),
              xl.IntCellValue(menunggu),
              xl.IntCellValue(approved),
              xl.IntCellValue(rejected),
              xl.IntCellValue(totalHari),
            ], isAlt: row % 2 == 0);
            row++;
          }
        }

        sheet.setColumnWidth(0, 20);
        sheet.setColumnWidth(1, 18);
        sheet.setColumnWidth(2, 18);
        for (int i = 3; i <= 7; i++) {
          sheet.setColumnWidth(i, 16);
        }
      } else if (reportType == 'tahunan') {
        fileName = 'laporan_tahunan_timeoff_hrd_$now.xlsx';
        sheetName = 'Laporan Tahunan';
        final sheet = excel[sheetName];

        setHeaders(sheet, [
          'Tahun',
          'Total Pengajuan',
          'Menunggu',
          'Approved',
          'Rejected',
          'Total Hari',
        ]);

        final Map<int, List<AdminTimeOffData>> grouped = {};
        for (final item in _allTimeOffs) {
          grouped.putIfAbsent(item.tanggalMulai.year, () => []);
          grouped[item.tanggalMulai.year]!.add(item);
        }
        final entries = grouped.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        int row = 1;
        for (final e in entries) {
          final items = e.value;
          final menunggu = items
              .where((x) => isPendingLike(normalizeStatus(x.status)))
              .length;
          final approved = items
              .where((x) => isApprovedLike(normalizeStatus(x.status)))
              .length;
          final rejected = items
              .where((x) => isRejectedLike(normalizeStatus(x.status)))
              .length;
          final totalHari = items.fold<int>(0, (s, x) => s + x.totalHari);

          setRow(sheet, row, [
            xl.IntCellValue(e.key),
            xl.IntCellValue(items.length),
            xl.IntCellValue(menunggu),
            xl.IntCellValue(approved),
            xl.IntCellValue(rejected),
            xl.IntCellValue(totalHari),
          ], isAlt: row % 2 == 0);
          row++;
        }

        sheet.setColumnWidth(0, 10);
        for (int i = 1; i <= 5; i++) {
          sheet.setColumnWidth(i, 16);
        }
      } else if (reportType == 'departemen') {
        fileName = 'laporan_per_departemen_timeoff_hrd_$now.xlsx';
        sheetName = 'Per Departemen';
        final sheet = excel[sheetName];

        setHeaders(sheet, [
          'Departemen',
          'Total Pengajuan',
          'Menunggu',
          'Approved',
          'Rejected',
          'Total Hari',
        ]);

        final Map<String, List<AdminTimeOffData>> grouped = {};
        for (final item in _allTimeOffs) {
          final key = getDept(item);
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(item);
        }
        final entries = grouped.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

        int row = 1;
        for (final e in entries) {
          final items = e.value;
          final menunggu = items
              .where((x) => isPendingLike(normalizeStatus(x.status)))
              .length;
          final approved = items
              .where((x) => isApprovedLike(normalizeStatus(x.status)))
              .length;
          final rejected = items
              .where((x) => isRejectedLike(normalizeStatus(x.status)))
              .length;
          final totalHari = items.fold<int>(0, (s, x) => s + x.totalHari);

          setRow(sheet, row, [
            xl.TextCellValue(e.key),
            xl.IntCellValue(items.length),
            xl.IntCellValue(menunggu),
            xl.IntCellValue(approved),
            xl.IntCellValue(rejected),
            xl.IntCellValue(totalHari),
          ], isAlt: row % 2 == 0);
          row++;
        }

        sheet.setColumnWidth(0, 28);
        for (int i = 1; i <= 5; i++) {
          sheet.setColumnWidth(i, 16);
        }
      } else if (reportType == 'karyawan') {
        fileName = 'laporan_per_karyawan_timeoff_hrd_$now.xlsx';
        sheetName = 'Per Karyawan';
        final sheet = excel[sheetName];

        setHeaders(sheet, [
          'User ID',
          'Nama',
          'Jabatan',
          'Departemen',
          'Total Pengajuan',
          'Menunggu',
          'Approved',
          'Rejected',
          'Total Hari',
        ]);

        final Map<String, List<AdminTimeOffData>> grouped = {};
        for (final item in _allTimeOffs) {
          grouped.putIfAbsent(item.userId, () => []);
          grouped[item.userId]!.add(item);
        }
        final entries = grouped.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

        int row = 1;
        for (final e in entries) {
          final items = e.value;
          final first = items.first;
          final menunggu = items
              .where((x) => isPendingLike(normalizeStatus(x.status)))
              .length;
          final approved = items
              .where((x) => isApprovedLike(normalizeStatus(x.status)))
              .length;
          final rejected = items
              .where((x) => isRejectedLike(normalizeStatus(x.status)))
              .length;
          final totalHari = items.fold<int>(0, (s, x) => s + x.totalHari);

          setRow(sheet, row, [
            xl.TextCellValue(first.userId),
            xl.TextCellValue(first.userName),
            xl.TextCellValue(first.userJob ?? '-'),
            xl.TextCellValue(first.userDepartment ?? '-'),
            xl.IntCellValue(items.length),
            xl.IntCellValue(menunggu),
            xl.IntCellValue(approved),
            xl.IntCellValue(rejected),
            xl.IntCellValue(totalHari),
          ], isAlt: row % 2 == 0);
          row++;
        }

        sheet.setColumnWidth(0, 16);
        sheet.setColumnWidth(1, 28);
        sheet.setColumnWidth(2, 22);
        sheet.setColumnWidth(3, 22);
        for (int i = 4; i <= 8; i++) {
          sheet.setColumnWidth(i, 14);
        }
      } else if (reportType == 'tren') {
        fileName = 'laporan_tren_cuti_timeoff_hrd_$now.xlsx';
        sheetName = 'Tren Cuti';
        final sheet = excel[sheetName];

        setHeaders(sheet, ['Periode', 'Total Pengajuan', 'Total Hari']);

        final Map<String, List<AdminTimeOffData>> grouped = {};
        for (final item in _allTimeOffs) {
          final key =
              '${item.tanggalMulai.year}-${item.tanggalMulai.month.toString().padLeft(2, '0')}';
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(item);
        }
        final entries = grouped.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        int row = 1;
        for (final e in entries) {
          final items = e.value;
          final totalHari = items.fold<int>(0, (s, x) => s + x.totalHari);
          setRow(sheet, row, [
            xl.TextCellValue(e.key),
            xl.IntCellValue(items.length),
            xl.IntCellValue(totalHari),
          ], isAlt: row % 2 == 0);
          row++;
        }

        sheet.setColumnWidth(0, 16);
        sheet.setColumnWidth(1, 18);
        sheet.setColumnWidth(2, 14);
      } else {
        // Detail — semua data dari _filteredTimeOffs
        fileName = 'laporan_detail_timeoff_hrd_$now.xlsx';
        sheetName = 'Detail Lengkap';
        final sheet = excel[sheetName];

        setHeaders(sheet, [
          'ID',
          'User ID',
          'Nama',
          'Jenis Cuti',
          'Tgl Mulai',
          'Tgl Selesai',
          'Total Hari',
          'Status',
          'Departemen',
          'Jabatan',
          'Catatan',
          'Laporan',
          'Tgl Pengajuan',
        ]);

        int row = 1;
        for (final item in _filteredTimeOffs) {
          setRow(sheet, row, [
            xl.IntCellValue(item.id),
            xl.TextCellValue(item.userId),
            xl.TextCellValue(item.userName),
            xl.TextCellValue(item.jenisTimeOff),
            xl.TextCellValue(fmtDate(item.tanggalMulai)),
            xl.TextCellValue(fmtDate(item.tanggalSelesai)),
            xl.IntCellValue(item.totalHari),
            xl.TextCellValue(item.statusText),
            xl.TextCellValue(item.userDepartment ?? '-'),
            xl.TextCellValue(item.userJob ?? '-'),
            xl.TextCellValue(item.catatan ?? '-'),
            xl.TextCellValue(item.hasLaporan ? 'Ada Laporan' : '-'),
            xl.TextCellValue(fmtDate(item.submittedAt)),
          ], isAlt: row % 2 == 0);
          row++;
        }

        sheet.setColumnWidth(0, 8);
        sheet.setColumnWidth(1, 14);
        sheet.setColumnWidth(2, 26);
        sheet.setColumnWidth(3, 20);
        sheet.setColumnWidth(4, 14);
        sheet.setColumnWidth(5, 14);
        sheet.setColumnWidth(6, 10);
        sheet.setColumnWidth(7, 22);
        sheet.setColumnWidth(8, 20);
        sheet.setColumnWidth(9, 20);
        sheet.setColumnWidth(10, 28);
        sheet.setColumnWidth(11, 14);
        sheet.setColumnWidth(12, 16);
      }

      // ── Tambah sheet Ringkasan di semua report ─────────────────────────────
      final summarySheet = excel['Ringkasan'];
      summarySheet.cell(xl.CellIndex.indexByString('A1')).value =
          xl.TextCellValue('Laporan HRD — $sheetName');
      summarySheet.cell(xl.CellIndex.indexByString('A1')).cellStyle = boldStyle;

      summarySheet.cell(xl.CellIndex.indexByString('A3')).value =
          xl.TextCellValue('Dicetak');
      summarySheet
          .cell(xl.CellIndex.indexByString('B3'))
          .value = xl.TextCellValue(
        DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(DateTime.now()),
      );

      summarySheet.cell(xl.CellIndex.indexByString('A4')).value =
          xl.TextCellValue('Total Data');
      summarySheet.cell(xl.CellIndex.indexByString('B4')).value =
          xl.IntCellValue(_allTimeOffs.length);

      summarySheet.cell(xl.CellIndex.indexByString('A5')).value =
          xl.TextCellValue('Total Karyawan');
      summarySheet.cell(xl.CellIndex.indexByString('B5')).value =
          xl.IntCellValue(_users.length);

      summarySheet.cell(xl.CellIndex.indexByString('A6')).value =
          xl.TextCellValue('Approved');
      summarySheet.cell(xl.CellIndex.indexByString('B6')).value =
          xl.IntCellValue(_statistics?.approvedCount ?? 0);

      summarySheet.cell(xl.CellIndex.indexByString('A7')).value =
          xl.TextCellValue('Pending');
      summarySheet.cell(xl.CellIndex.indexByString('B7')).value =
          xl.IntCellValue(_statistics?.pendingCount ?? 0);

      summarySheet.cell(xl.CellIndex.indexByString('A8')).value =
          xl.TextCellValue('Rejected');
      summarySheet.cell(xl.CellIndex.indexByString('B8')).value =
          xl.IntCellValue(_statistics?.rejectedCount ?? 0);

      summarySheet.setColumnWidth(0, 20);
      summarySheet.setColumnWidth(1, 24);

      // Hapus Sheet1 default sekarang — sudah aman karena sudah ada
      // sheet data (sheetName) + sheet Ringkasan
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        _snackErr('Gagal membuat file Excel');
        return;
      }

      final fileBytes = Uint8List.fromList(bytes);

      if (kIsWeb) {
        downloadFileWeb(fileBytes, fileName);
        _snackOk('Laporan Excel berhasil diunduh');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      _snackOk('Laporan berhasil dibuat: $fileName');
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
          : item.isPendingDirector
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
            // ── Row 1: Badge urgent + jenis + status ──────────────────
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

            // ── Badge requires director (kalau izin butuh direktur) ───
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
                      'Sudah disetujui HRD — menunggu Direktur',
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

            // ── Row 2: Avatar + nama + posisi ─────────────────────────
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

            // ── Row 3: Tanggal + total hari ───────────────────────────
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

            // ── Badge lampiran (non-DL) ───────────────────────────────
            if (!item.isDinasLuar && item.hasFile) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.attach_file,
                      size: 12,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ada lampiran',
                      style: TextStyle(
                        fontSize: _fs(10),
                        color: const Color(0xFF059669),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Badge laporan DL siap direview ────────────────────────
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
                    Expanded(
                      child: Text(
                        'Laporan DL sudah diupload — siap direview',
                        style: TextStyle(
                          fontSize: _fs(11),
                          color: const Color(0xFF5B21B6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Baris aksi: tombol approve/reject ─────────────────────
            if (item.needsReview) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Info waktu tunggu
                  Flexible(
                    child: Row(
                      children: [
                        Icon(
                          item.isPendingDirector
                              ? Icons.account_balance
                              : Icons.access_time,
                          size: 13,
                          color: item.isPendingDirector
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            item.isPendingDirector
                                ? 'Menunggu Direktur — ${item.daysSinceSubmitted} hari'
                                : 'Diajukan ${item.daysSinceSubmitted} hari lalu',
                            style: TextStyle(
                              fontSize: _fs(11),
                              color: item.isPendingDirector
                                  ? const Color(0xFF8B5CF6)
                                  : item.urgencyColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tombol hanya kalau user berhak review
                  if (_canReview(item))
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
                            backgroundColor: item.isPendingDirector
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF10B981),
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

  // ── Helper: apakah user saat ini berhak review item ini ──────────────────────
  bool _canReview(AdminTimeOffData item) {
    if (_currentUserId == null) return false;
    return item.needsReview;
  }

  void _showEmployeeDetail(UserWithTimeOffs user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeDetailModal(
        user: user,
        adminId: _currentUserId!,
        onEditQuota: (selectedUser) {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 200), () {
            _showSetQuotaDialog(selectedUser);
          });
        },
      ),
    );
  }

  Widget _buildEmployeeCard(UserWithTimeOffs user) {
    final bal = _leaveBalances[user.userId] ?? user.remainingDays.toDouble();
    final low = bal < 7;

    return InkWell(
      onTap: () => _showEmployeeDetail(user),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: avatar + nama + tombol setting ──
            Row(
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
                // Tombol set kuota
                InkWell(
                  onTap: () => _showSetQuotaDialog(user),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune,
                      size: 17,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Kuota badges ──
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildQuotaBadge(
                  'Cuti Tahunan',
                  '${bal.toInt()}/${user.annualQuota}',
                  low ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                ),
                _buildQuotaBadge(
                  'Total Izin',
                  '${user.totalTimeOff} req',
                  const Color(0xFFF59E0B),
                ),
                _buildQuotaBadge(
                  'Disetujui',
                  '${user.approvedCount}',
                  const Color(0xFF10B981),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Progress bar kuota tahunan ──
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: user.annualQuota <= 0
                          ? 0
                          : (user.usedDays / user.annualQuota).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        low ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${user.usedDays}/${user.annualQuota} hari',
                  style: TextStyle(
                    fontSize: _fs(11),
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Footer: tap untuk detail ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Lihat riwayat izin',
                  style: TextStyle(
                    fontSize: _fs(11),
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: Color(0xFF6366F1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaBadge(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: _fs(10),
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: _fs(10),
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
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

  void _navFilter(String status) {
    setState(() {
      _webTabIndex = 1;
      _tabController.animateTo(1);

      if (status.toLowerCase() == 'all') {
        _selectedStatus = null;
      } else {
        _selectedStatus = status;
      }

      _applyFilters();
    });
  }

  // timeoffhrd.dart — REPLACE method _quickReview yang lama

  Future<void> _quickReview(AdminTimeOffData item, String status) async {
    try {
      dynamic resp;

      if (item.status.toLowerCase() == 'pending director') {
        // Direktur yang review
        resp = await TimeOffService.directorReview(
          id: item.id,
          status: status,
          directorUserId: _currentUserId!,
        );
      } else {
        // HRD yang review (Pending HRD atau Pending untuk DL)
        resp = await TimeOffService.hrdReview(
          id: item.id,
          status: status,
          hrdUserId: _currentUserId!,
        );
      }

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
// Model file lampiran HRD (multi-file + legacy)
// ══════════════════════════════════════════════════════════════════════════════
class _HrdAttachment {
  final int id; // 0 = file legacy (kolom file_name di udt_timeoff)
  final String fileName;
  final int? fileSize;
  final String? fileType;

  const _HrdAttachment({
    required this.id,
    required this.fileName,
    this.fileSize,
    this.fileType,
  });

  String get ext =>
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  bool get isImage => ['jpg', 'jpeg', 'png'].contains(ext);
  bool get isPdf => ext == 'pdf';
  bool get isLegacy => id == 0;

  String get sizeLabel {
    if (fileSize == null || fileSize! <= 0) return '';
    final b = fileSize!;
    return b >= 1024 * 1024
        ? '${(b / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(b / 1024).toStringAsFixed(0)} KB';
  }
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

  List<_HrdAttachment> _attachments = [];
  bool _filesLoading = true;
  int? _downloadingFileId;
  bool _isDownloadingDl = false;

  @override
  void initState() {
    super.initState();
    if (!widget.item.isDinasLuar) {
      _loadAttachments();
    } else {
      _filesLoading = false;
    }
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    _reviewNotesFocusNode.dispose();
    super.dispose();
  }

  Future<void> _exportFormulirHrd() async {
    if (widget.item.status.toLowerCase() != 'approved') {
      _snack(
        'Formulir hanya bisa diexport setelah pengajuan disetujui',
        err: true,
      );
      return;
    }

    try {
      setState(() => _isProcessing = true);

      final res = await TimeOffAdminService.exportTimeOffFormAdmin(
        timeOffId: widget.item.id,
        adminId: widget.currentHRDId,
      );

      if (!res.success || res.data == null) {
        _snack(res.message, err: true);
        return;
      }

      final safeName = widget.item.userName.replaceAll(' ', '_');
      final safeJenis = widget.item.jenisTimeOff.replaceAll(' ', '_');
      final fileName =
          'Formulir_${safeJenis}_${safeName}_${widget.item.id}.pdf'; // ← .pdf

      if (kIsWeb) {
        downloadFileWeb(res.data!, fileName);
      } else {
        // Mobile: buka PDF viewer
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(res.data!);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _snack('Tidak dapat membuka PDF: ${result.message}', err: true);
          return;
        }
      }

      _snack('Formulir PDF berhasil diexport', err: false);
    } catch (e) {
      _snack('Gagal export formulir: $e', err: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

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

  // Ambil semua file: multi-file (udt_timeoff_files) + fallback legacy
  Future<void> _loadAttachments() async {
    setState(() => _filesLoading = true);
    final List<_HrdAttachment> result = [];

    try {
      final token = await _getToken();
      if (token != null) {
        final res = await http
            .post(
              Uri.parse('$baseURL/api/timeoff/files/list'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'timeOffId': widget.item.id,
                'userId': widget.currentHRDId,
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (res.statusCode == 200) {
          final body = json.decode(res.body) as Map<String, dynamic>;
          final ok = body['success'] == true || body['Success'] == true;
          final data = body['data'] ?? body['Data'];
          if (ok && data is List) {
            for (final e in data) {
              final m = e as Map<String, dynamic>;
              result.add(
                _HrdAttachment(
                  id: (m['id'] ?? m['Id'] ?? 0) as int,
                  fileName:
                      (m['fileName'] ?? m['FileName'] ?? m['file_name'] ?? '')
                          .toString(),
                  fileSize:
                      (m['fileSize'] ?? m['FileSize'] ?? m['file_size'])
                          as int?,
                  fileType: (m['fileType'] ?? m['FileType'] ?? m['file_type'])
                      ?.toString(),
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // Fallback legacy (kolom file_name) bila multi-file kosong
    if (result.isEmpty &&
        widget.item.hasFile &&
        widget.item.fileName != null &&
        widget.item.fileName!.isNotEmpty) {
      result.add(
        _HrdAttachment(
          id: 0,
          fileName: widget.item.fileName!,
          fileSize: widget.item.fileSize,
          fileType: widget.item.fileType,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _attachments = result;
        _filesLoading = false;
      });
    }
  }

  Future<void> _downloadAttachment(
    _HrdAttachment file, {
    required bool preview,
  }) async {
    if (widget.item.id <= 0) {
      _snack('ID pengajuan tidak valid', err: true);
      return;
    }

    setState(() => _downloadingFileId = file.id);
    _snack(
      preview ? 'Memuat pratinjau...' : 'Mengunduh file...',
      err: false,
      dur: 1,
    );

    try {
      final token = await _getToken();
      if (token == null) {
        _snack('Gagal mendapatkan token', err: true);
        return;
      }

      final Uri url;
      final Map<String, dynamic> bodyData;
      if (file.isLegacy) {
        url = Uri.parse('$baseURL/api/timeoff/admin/download-file');
        bodyData = {
          'timeOffId': widget.item.id,
          'adminId': widget.currentHRDId,
        };
      } else {
        url = Uri.parse('$baseURL/api/timeoff/admin/download-multi-file');
        bodyData = {
          'timeOffId': widget.item.id,
          'fileId': file.id,
          'adminId': widget.currentHRDId,
        };
      }

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(bodyData),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (preview) {
          // ── PREVIEW: tampilkan, jangan download ──
          await _previewBytes(response.bodyBytes, file.fileName);
        } else {
          // ── UNDUH: benar-benar simpan/download ──
          if (kIsWeb) {
            downloadFileWeb(response.bodyBytes, file.fileName);
            _snack('File "${file.fileName}" diunduh', err: false);
          } else {
            final dir = await getApplicationDocumentsDirectory();
            final f = File('${dir.path}/${file.fileName}');
            await f.writeAsBytes(response.bodyBytes);
            _snack('Tersimpan: ${file.fileName}', err: false);
          }
        }
      } else {
        String errMsg = 'Gagal mengambil file (${response.statusCode})';
        try {
          final body = json.decode(response.body) as Map;
          errMsg = (body['message'] ?? body['Message'] ?? errMsg).toString();
        } catch (_) {}
        _snack(errMsg, err: true);
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    } finally {
      if (mounted) setState(() => _downloadingFileId = null);
    }
  }

  Future<void> _downloadDlFile(String fileType) async {
    setState(() => _isDownloadingDl = true);
    _snack('Memuat pratinjau...', err: false, dur: 1);
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
        await _previewBytes(response.bodyBytes, fileName);
      } else {
        final body = response.body.isNotEmpty ? json.decode(response.body) : {};
        _snack(
          (body as Map)['Message'] ??
              body['message'] ??
              'Gagal memuat (${response.statusCode})',
          err: true,
        );
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    } finally {
      if (mounted) setState(() => _isDownloadingDl = false);
    }
  }

  Future<void> _previewBytes(List<int> bytes, String fileName) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    final isPdf = ext == 'pdf';

    // Gambar → tampil langsung di dalam aplikasi (web + mobile)
    if (isImage) {
      await _showImagePreview(Uint8List.fromList(bytes), fileName);
      return;
    }

    if (kIsWeb) {
      // PDF / lainnya di web → buka inline di tab baru (blob), bukan download
      final mime = isPdf ? 'application/pdf' : 'application/octet-stream';
      openBytesInBrowser(bytes, fileName, mime);
      return;
    }

    // Mobile → buka di viewer sistem (ini "melihat", bukan menyimpan ke unduhan)
    final tempDir = await getTemporaryDirectory();
    final f = File('${tempDir.path}/$fileName');
    await f.writeAsBytes(bytes);
    final r = await OpenFile.open(f.path);
    if (r.type != ResultType.done) {
      _snack('Tidak dapat membuka: ${r.message}', err: true);
    }
  }

  // Dialog preview gambar in-app (zoom + pan)
  Future<void> _showImagePreview(Uint8List bytes, String fileName) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'Gambar tidak dapat ditampilkan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Text(
                fileName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HRDTimeOffDetailModal — REPLACE method _reviewTimeOff yang lama

  Future<void> _reviewTimeOff(String status) async {
    FocusScope.of(context).unfocus();
    setState(() => _isProcessing = true);
    try {
      dynamic response;

      if (widget.item.status.toLowerCase() == 'pending director') {
        // Direktur review
        response = await TimeOffService.directorReview(
          id: widget.item.id,
          status: status,
          directorUserId: widget.currentHRDId,
          rejectionReason: _reviewNotesController.text.trim().isNotEmpty
              ? _reviewNotesController.text.trim()
              : null,
        );
      } else {
        // HRD review
        response = await TimeOffService.hrdReview(
          id: widget.item.id,
          status: status,
          hrdUserId: widget.currentHRDId,
          rejectionReason: _reviewNotesController.text.trim().isNotEmpty
              ? _reviewNotesController.text.trim()
              : null,
        );
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
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    // File lampiran non-DL
                    if (!widget.item.isDinasLuar) ...[
                      const SizedBox(height: 16),
                      _buildAttachmentSection(),
                    ],

                    // Laporan DL
                    if (widget.item.isDinasLuar) ...[
                      const SizedBox(height: 16),
                      _buildDlLaporanSection(),
                    ],

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

  Widget _buildAttachmentSection() {
    return _buildInfoCard(
      title:
          'File Lampiran'
          '${(!_filesLoading && _attachments.isNotEmpty) ? ' (${_attachments.length})' : ''}',
      icon: Icons.attach_file,
      children: [
        if (_filesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_attachments.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
                const SizedBox(width: 8),
                Text(
                  'Tidak ada file lampiran',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < _attachments.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _buildAttachmentRow(_attachments[i]),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildAttachmentRow(_HrdAttachment file) {
    final IconData fileIcon;
    final Color fileColor;
    if (file.isImage) {
      fileIcon = Icons.image_rounded;
      fileColor = const Color(0xFF10B981);
    } else if (file.isPdf) {
      fileIcon = Icons.picture_as_pdf_rounded;
      fileColor = const Color(0xFFEF4444);
    } else {
      fileIcon = Icons.insert_drive_file_rounded;
      fileColor = const Color(0xFF6B7280);
    }

    final isThisDownloading = _downloadingFileId == file.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fileColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fileColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(fileIcon, color: fileColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (file.sizeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${file.ext.toUpperCase()} • ${file.sizeLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isThisDownloading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fileColor),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _downloadAttachment(file, preview: true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: 14,
                          color: Color(0xFF3B82F6),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Lihat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _downloadAttachment(file, preview: false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: fileColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 14,
                          color: fileColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Unduh',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: fileColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

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
          _buildDlFileRow(
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
          _buildDlFileRow(
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

  Widget _buildDlFileRow({
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
        _isDownloadingDl
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
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
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
    final status = widget.item.status.toLowerCase();
    if (status == 'approved' || status == 'disetujui') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isProcessing ? null : _exportFormulirHrd,
          icon: const Icon(
            Icons.picture_as_pdf_rounded,
            size: 18,
          ), // ← ganti icon
          label: const Text(
            'Export Formulir PDF',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444), // ← merah untuk PDF
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      );
    }

    // Kalau bukan pending, tidak ada tombol action
    if (status != 'pending' &&
        status != 'pending hrd' &&
        status != 'pending director') {
      return const SizedBox.shrink();
    }

    // Kalau masih pending, tampilkan tombol tolak/setujui
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => _reviewTimeOff('Rejected'),
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
            onPressed: _isProcessing ? null : () => _reviewTimeOff('Approved'),
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

class _EmployeeDetailModal extends StatefulWidget {
  final UserWithTimeOffs user;
  final String adminId;
  final Function(UserWithTimeOffs user) onEditQuota;

  const _EmployeeDetailModal({
    required this.user,
    required this.adminId,
    required this.onEditQuota,
  });

  @override
  State<_EmployeeDetailModal> createState() => _EmployeeDetailModalState();
}

class _EmployeeDetailModalState extends State<_EmployeeDetailModal> {
  bool _loading = true;
  List<Map<String, dynamic>> _quotas = [];
  List<Map<String, dynamic>> _history = [];
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    final data = await TimeOffAdminService.getEmployeeDetail(
      adminId: widget.adminId,
      userId: widget.user.userId,
      year: _selectedYear,
    );
    if (mounted) {
      setState(() {
        _quotas = List<Map<String, dynamic>>.from(data['quotas'] ?? []);
        _history = List<Map<String, dynamic>>.from(data['history'] ?? []);
        _loading = false;
      });
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending hrd':
      case 'pending director':
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'pending hrd':
        return 'Menunggu HRD';
      case 'pending director':
        return 'Menunggu Direktur';
      case 'pending':
        return 'Menunggu Review';
      default:
        return s;
    }
  }

  String _jenisIcon(String jenis) {
    switch (jenis) {
      case 'Izin Tahunan':
        return '🏖️';
      case 'Sakit':
        return '🏥';
      case 'Umrah dan Haji':
        return '🕋';
      case 'Izin Datang Terlambat':
        return '⏰';
      case 'Izin Lahiran':
        return '👶';
      case 'Dinas Luar':
        return '🧳';
      case 'Keluarga Meninggal':
        return '🕯️';
      default:
        return '📅';
    }
  }

  // Kelompokkan history berdasarkan uses_quota dan jenis
  Map<String, List<Map<String, dynamic>>> _groupHistory() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final h in _history) {
      final key = h['jenisTimeOff']?.toString() ?? '-';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(h);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
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
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    child: Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          '${widget.user.jobPosition ?? widget.user.jobs ?? '-'}'
                          '${widget.user.department != null ? ' • ${widget.user.department}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Year picker
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isDense: true,
                      underline: const SizedBox(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                      items: List.generate(3, (i) {
                        final y = DateTime.now().year - 1 + i;
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }),
                      onChanged: (y) {
                        if (y == null) return;
                        setState(() => _selectedYear = y);
                        _loadDetail();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── KUOTA ──────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kuota Izin $_selectedYear',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  widget.onEditQuota(widget.user);
                                },
                                icon: const Icon(Icons.tune, size: 14),
                                label: const Text('Edit Kuota'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF6366F1),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          _quotas.isEmpty
                              ? _buildEmptyQuota()
                              : Column(
                                  children: _quotas
                                      .map((q) => _buildQuotaCard(q))
                                      .toList(),
                                ),

                          const SizedBox(height: 24),

                          // ── RIWAYAT ────────────────────────────────
                          Text(
                            'Riwayat Izin $_selectedYear',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _history.isEmpty
                              ? _buildEmptyHistory()
                              : _buildHistoryGrouped(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Getter untuk tahun yang dipilih di dalam build
  // (workaround karena _selectedYear tidak bisa dipakai langsung di Text widget)

  Widget _buildEmptyQuota() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange[200]!),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber, color: Colors.orange[700], size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Kuota belum diset untuk tahun $_selectedYear.\nTekan "Edit Kuota" untuk mengatur.',
            style: TextStyle(fontSize: 13, color: Colors.orange[700]),
          ),
        ),
      ],
    ),
  );

  Widget _buildEmptyHistory() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        const Icon(Icons.inbox_outlined, color: Color(0xFF9CA3AF), size: 18),
        const SizedBox(width: 10),
        Text(
          'Belum ada pengajuan izin di tahun $_selectedYear.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ],
    ),
  );

  Widget _buildQuotaCard(Map<String, dynamic> q) {
    final qType = q['quotaType']?.toString() ?? '';
    final qName = q['quotaName']?.toString() ?? qType;
    final awal = (q['quotaAwal'] as num?)?.toInt() ?? 0;
    final pakai = (q['quotaTerpakai'] as num?)?.toInt() ?? 0;
    final sisa = (q['quotaSisa'] as num?)?.toInt() ?? 0;
    final pct = awal <= 0 ? 0.0 : (pakai / awal).clamp(0.0, 1.0);
    final low = sisa < 3;

    final Color color;
    final String icon;
    switch (qType) {
      case 'annual':
        color = const Color(0xFF6366F1);
        icon = '🏖️';
        break;
      case 'birth_leave':
        color = const Color(0xFF10B981);
        icon = '👶';
        break;
      case 'bereavement':
        color = const Color(0xFF8B5CF6);
        icon = '🕯️';
        break;
      default:
        color = const Color(0xFF6B7280);
        icon = '📅';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: low ? color.withOpacity(0.5) : const Color(0xFFE5E7EB),
          width: low ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  qName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              if (low)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hampir habis',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$pakai/$awal hr',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _quotaMiniStat('Kuota', '$awal hr', const Color(0xFF6B7280)),
              const SizedBox(width: 12),
              _quotaMiniStat('Terpakai', '$pakai hr', color),
              const SizedBox(width: 12),
              _quotaMiniStat(
                'Sisa',
                '$sisa hr',
                low ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quotaMiniStat(String label, String value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label: ',
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );

  Widget _buildHistoryGrouped() {
    final grouped = _groupHistory();
    return Column(
      children: grouped.entries.map((entry) {
        final jenis = entry.key;
        final items = entry.value;
        final usesQuota = items.first['usesQuota'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header grup
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Text(
                      _jenisIcon(jenis),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        jenis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: usesQuota
                            ? const Color(0xFF6366F1).withOpacity(0.1)
                            : const Color(0xFF6B7280).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        usesQuota ? 'Pakai Kuota' : 'Non-Kuota',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: usesQuota
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${items.length}x',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Item list
              ...items.asMap().entries.map((e) {
                final i = e.key;
                final h = e.value;
                final mulai = _fmtDate(h['tanggalMulai']?.toString());
                final selesai = _fmtDate(h['tanggalSelesai']?.toString());
                final hari = (h['totalHari'] as num?)?.toInt() ?? 0;
                final status = h['status']?.toString() ?? '';
                final catatan = h['catatan']?.toString() ?? '';
                final isLast = i == items.length - 1;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Color(0xFFF3F4F6)),
                          ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Garis waktu
                      Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 1,
                              height: 30,
                              color: const Color(0xFFE5E7EB),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    mulai == selesai
                                        ? mulai
                                        : '$mulai – $selesai',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$hari hr',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      status,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ),
                                if (catatan.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      catatan,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}
