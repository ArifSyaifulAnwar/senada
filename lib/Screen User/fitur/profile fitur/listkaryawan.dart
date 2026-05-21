// ignore_for_file: curly_braces_in_flow_control_structures, library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';

import 'package:absensikaryawan/Services/employee_service.dart';
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

bool _isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 768;

class HalamanListEmployee extends StatefulWidget {
  const HalamanListEmployee({super.key});

  @override
  _HalamanListEmployeeState createState() => _HalamanListEmployeeState();
}

// ── EmployeeData ──────────────────────────────────────────────────────────────
class EmployeeData {
  final int id;
  final String userId; // ← BARU: userid dari udt_users
  final String nama;
  final String email;
  final String telepon;
  final String jabatan;
  final String departemen;
  final String status;
  final String tanggalBergabung;
  final String alamat;
  final String foto;
  final String nomorKaryawan;
  final String manager;
  final String? managerUserId; // ← BARU: userid manager (untuk dropdown)
  final List<String> skills;

  // personal
  final String? gender; // ← BARU: dari kolom gender (bukan jobs)
  final String? additionalPhone;
  final String? citizenIdAddress;
  final String? residentialAddress;
  final String? postalCode;
  final String? jobs; // jabatan teks bebas
  final String? placeOfBirth;
  final String? birthDate;
  final String? maritalStatus;
  final String? bloodType;
  final String? religion;
  final String? nik;
  final String? nip;
  final String? npwp;
  final String? bpjsKetenagakerjaan; // ← BARU
  final String? passportNumber;
  final String? passportExpiry;

  // company
  final String? barcode;
  final String? branch;
  final String? companyName;
  final String? jobLevel;
  final String? employmentStatus;
  final String? endContractDate;
  final int? workingPeriodYear;
  final int? workingPeriodMonth;
  final int? workingPeriodDay;

  EmployeeData({
    required this.id,
    required this.userId,
    required this.nama,
    required this.email,
    required this.telepon,
    required this.jabatan,
    required this.departemen,
    required this.status,
    required this.tanggalBergabung,
    required this.alamat,
    required this.foto,
    required this.nomorKaryawan,
    required this.manager,
    this.managerUserId,
    required this.skills,
    this.gender,
    this.additionalPhone,
    this.citizenIdAddress,
    this.residentialAddress,
    this.postalCode,
    this.jobs,
    this.placeOfBirth,
    this.birthDate,
    this.maritalStatus,
    this.bloodType,
    this.religion,
    this.nik,
    this.nip,
    this.npwp,
    this.bpjsKetenagakerjaan,
    this.passportNumber,
    this.passportExpiry,
    this.barcode,
    this.branch,
    this.companyName,
    this.jobLevel,
    this.employmentStatus,
    this.endContractDate,
    this.workingPeriodYear,
    this.workingPeriodMonth,
    this.workingPeriodDay,
  });
}

// ── State ─────────────────────────────────────────────────────────────────────
class _HalamanListEmployeeState extends State<HalamanListEmployee> {
  bool isLoading = false;
  String errorMessage = '';
  String searchQuery = '';
  String selectedDepartment = 'Semua';
  String selectedStatus = 'Semua';
  String sortBy = 'Nama A-Z';

  List<EmployeeData> allEmployeeData = [];
  EmployeeStats? employeeStats;
  int currentPage = 1;
  int totalPages = 1;
  int totalCount = 0;

  final TextEditingController _searchController = TextEditingController();

  EmployeeData? _selectedEmployee;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadEmployeeData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final response = await EmployeeService.getEmployeeList(
        searchQuery: searchQuery.isEmpty ? null : searchQuery,
        department: selectedDepartment == 'Semua' ? null : selectedDepartment,
        status: selectedStatus == 'Semua' ? null : selectedStatus,
        sortBy: _convertSort(sortBy),
        page: currentPage,
        pageSize: 50,
      );
      if (response.success && response.data != null) {
        setState(() {
          allEmployeeData = response.data!.data
              .map((e) => e.toEmployeeData())
              .toList();
          employeeStats = response.data!.stats;
          totalPages = response.data!.totalPages;
          totalCount = response.data!.totalCount;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response.message;
          isLoading = false;
        });
        _snackError(response.message);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
      _snackError('Terjadi kesalahan: $e');
    }
  }

  String _convertSort(String s) {
    switch (s) {
      case 'Nama A-Z':
        return 'name_asc';
      case 'Nama Z-A':
        return 'name_desc';
      case 'Tanggal Bergabung (Terbaru)':
        return 'join_date_desc';
      case 'Tanggal Bergabung (Terlama)':
        return 'join_date_asc';
      default:
        return 'name_asc';
    }
  }

  Future<void> _refreshData() async {
    currentPage = 1;
    await _loadEmployeeData();
  }

  void _onSearchChanged(String v) {
    setState(() => searchQuery = v);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (searchQuery == v) _refreshData();
    });
  }

  List<EmployeeData> getFilteredEmployeeData() => allEmployeeData;

  Map<String, int> getEmployeeStats() {
    if (employeeStats != null) {
      return {
        'Total': employeeStats!.totalEmployees,
        'Aktif': employeeStats!.activeEmployees,
        'Cuti': employeeStats!.onLeaveEmployees,
        'Non-Aktif': employeeStats!.inactiveEmployees,
      };
    }
    return {
      'Total': allEmployeeData.length,
      'Aktif': 0,
      'Cuti': 0,
      'Non-Aktif': 0,
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtTanggal(String t) {
    try {
      if (t.isEmpty) return '-';
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(t));
    } catch (_) {
      return t;
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'aktif':
        return Colors.green;
      case 'cuti':
        return Colors.orange;
      case 'non-aktif':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'aktif':
        return Icons.check_circle;
      case 'cuti':
        return Icons.access_time;
      case 'non-aktif':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _snackError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isWeb(context) ? _buildWebLayout() : _buildMobileLayout(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: const Text(
      'Daftar Karyawan',
      style: TextStyle(
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 16),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.filter_list,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          onPressed: _showFilterSheet,
        ),
      ),
      Container(
        margin: const EdgeInsets.only(right: 16),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.refresh,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          onPressed: _refreshData,
        ),
      ),
    ],
  );

  // ── Mobile layout ──────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    final data = getFilteredEmployeeData();
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildErrorBanner(),
            _buildStatsGrid(crossAxisCount: 2, ratio: 1.2),
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildListHeader(data.length),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B82F6),
                    ),
                  ),
                ),
              )
            else if (data.isEmpty && errorMessage.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                itemBuilder: (ctx, i) =>
                    _buildEmployeeCard(data[i], isWeb: false),
              ),
          ],
        ),
      ),
    );
  }

  // ── Web layout ─────────────────────────────────────────────────────────────

  Widget _buildWebLayout() {
    final data = getFilteredEmployeeData();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar kiri
        SizedBox(
          width: 220,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebStatsColumn(),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildWebFilterPanel(),
                ],
              ),
            ),
          ),
        ),
        // Kolom tengah
        SizedBox(
          width: 340,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 8),
                      _buildListHeader(data.length),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF3B82F6),
                            ),
                          ),
                        )
                      : data.isEmpty && errorMessage.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          itemCount: data.length,
                          itemBuilder: (ctx, i) =>
                              _buildEmployeeCard(data[i], isWeb: true),
                        ),
                ),
              ],
            ),
          ),
        ),
        // Detail panel
        Expanded(
          child: _selectedEmployee == null
              ? _buildWebDetailEmpty()
              : _isLoadingDetail
              ? const Center(child: CircularProgressIndicator())
              : _buildWebDetailPanel(_selectedEmployee!),
        ),
      ],
    );
  }

  // ── Stats sidebar web ──────────────────────────────────────────────────────

  Widget _buildWebStatsColumn() {
    final stats = getEmployeeStats();
    final items = [
      {'title': 'Total', 'value': stats['Total'], 'color': Colors.blue},
      {'title': 'Aktif', 'value': stats['Aktif'], 'color': Colors.green},
      {'title': 'Cuti', 'value': stats['Cuti'], 'color': Colors.orange},
      {'title': 'Non-Aktif', 'value': stats['Non-Aktif'], 'color': Colors.red},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((item) {
          final color = item['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${item['value']}',
                  style: TextStyle(
                    fontSize: 14,
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

  // ── Filter panel web ───────────────────────────────────────────────────────

  Widget _buildWebFilterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Departemen',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              [
                'Semua',
                'IT Development',
                'Design',
                'Human Resources',
                'Marketing',
              ].map((d) {
                final sel = selectedDepartment == d;
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedDepartment = d);
                    _refreshData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF3B82F6)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'Status',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ['Semua', 'Aktif', 'Cuti', 'Non-Aktif'].map((s) {
            final sel = selectedStatus == s;
            return GestureDetector(
              onTap: () {
                setState(() => selectedStatus = s);
                _refreshData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF3B82F6) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'Urutkan',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        ...['Nama A-Z', 'Nama Z-A', 'Terbaru', 'Terlama'].map((s) {
          final key = s == 'Terbaru'
              ? 'Tanggal Bergabung (Terbaru)'
              : s == 'Terlama'
              ? 'Tanggal Bergabung (Terlama)'
              : s;
          final sel = sortBy == key;
          return GestureDetector(
            onTap: () {
              setState(() => sortBy = key);
              _refreshData();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: sel
                    ? const Color(0xFF3B82F6).withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    sel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: sel ? const Color(0xFF3B82F6) : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: 12,
                      color: sel ? const Color(0xFF3B82F6) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Web detail empty ───────────────────────────────────────────────────────

  Widget _buildWebDetailEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            size: 40,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pilih karyawan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Klik nama karyawan di kiri\nuntuk melihat detail',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    ),
  );

  // ── Web detail panel ───────────────────────────────────────────────────────

  Widget _buildWebDetailPanel(EmployeeData emp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(36),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: _buildProfileImage(emp.foto, 72),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.nama,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      emp.jabatan,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    Text(
                      emp.departemen,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusBadge(emp.status),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildIconBtn(
                    Icons.email_outlined,
                    Colors.blue,
                    () => _sendEmail(emp.email),
                    tooltip: 'Email',
                  ),
                  const SizedBox(width: 6),
                  if (emp.telepon.isNotEmpty)
                    _buildIconBtn(
                      Icons.chat,
                      Colors.green,
                      () => _sendWhatsApp(emp.telepon),
                      tooltip: 'WhatsApp',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildWebDetailGrid(emp),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _statusColor(status).withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_statusIcon(status), size: 12, color: _statusColor(status)),
        const SizedBox(width: 5),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _statusColor(status),
          ),
        ),
      ],
    ),
  );

  Widget _buildIconBtn(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? tooltip,
  }) => Tooltip(
    message: tooltip ?? '',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    ),
  );

  Widget _buildWebDetailGrid(EmployeeData emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Informasi Personal
        const Text(
          'Informasi Personal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        ...[
          _detailRow(
            'ID Karyawan',
            emp.nomorKaryawan,
            Icons.badge,
            Colors.blue,
          ),
          _detailRow('Email', emp.email, Icons.email, Colors.green),
          _detailRow(
            'Telepon',
            emp.telepon.isNotEmpty ? emp.telepon : '-',
            Icons.phone,
            Colors.orange,
          ),
          if (emp.gender?.isNotEmpty == true)
            _detailRow('Jenis Kelamin', emp.gender!, Icons.wc, Colors.purple),
          if (emp.birthDate?.isNotEmpty == true)
            _detailRow(
              'Tanggal Lahir',
              _fmtTanggal(emp.birthDate!),
              Icons.cake,
              Colors.purple,
            ),
          if (emp.nik?.isNotEmpty == true)
            _detailRow('NIK', emp.nik!, Icons.credit_card, Colors.indigo),
          if (emp.bpjsKetenagakerjaan?.isNotEmpty == true)
            _detailRow(
              'BPJS Ketenagakerjaan',
              emp.bpjsKetenagakerjaan!,
              Icons.health_and_safety,
              Colors.teal,
            ),
          if (emp.alamat.isNotEmpty)
            _detailRow('Alamat', emp.alamat, Icons.location_on, Colors.red),
        ].whereType<Widget>(),
        const SizedBox(height: 16),
        // ── Informasi Pekerjaan
        const Text(
          'Informasi Pekerjaan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        ...[
          _detailRow(
            'Departemen',
            emp.departemen,
            Icons.business,
            Colors.purple,
          ),
          _detailRow(
            'Posisi',
            emp.jabatan.isNotEmpty ? emp.jabatan : '-',
            Icons.work,
            Colors.blue,
          ),
          _detailRow(
            'Manager',
            emp.manager.isNotEmpty ? emp.manager : '-',
            Icons.supervisor_account,
            Colors.cyan,
          ),
          _detailRow(
            'Bergabung',
            emp.tanggalBergabung.isNotEmpty
                ? _fmtTanggal(emp.tanggalBergabung)
                : '-',
            Icons.calendar_today,
            Colors.teal,
          ),
          if (emp.workingPeriodYear != null)
            _detailRow(
              'Masa Kerja',
              '${emp.workingPeriodYear} thn ${emp.workingPeriodMonth} bln',
              Icons.schedule,
              Colors.amber,
            ),
        ].whereType<Widget>(),
        if (emp.skills.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Skills',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: emp.skills
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget? _detailRow(String label, String value, IconData icon, Color color) {
    final empty = value.isEmpty || value == '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: empty ? Colors.grey.shade50 : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: empty ? Colors.grey.shade200 : color.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: empty ? Colors.grey[400] : color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: empty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  empty ? '-' : value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: empty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    if (errorMessage.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => errorMessage = ''),
            icon: const Icon(Icons.close, color: Colors.red, size: 18),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({required int crossAxisCount, required double ratio}) {
    final stats = getEmployeeStats();
    final data = [
      {
        'title': 'Total Karyawan',
        'value': stats['Total'].toString(),
        'color': Colors.blue,
        'icon': Icons.people,
      },
      {
        'title': 'Karyawan Aktif',
        'value': stats['Aktif'].toString(),
        'color': Colors.green,
        'icon': Icons.check_circle,
      },
      {
        'title': 'Sedang Cuti',
        'value': stats['Cuti'].toString(),
        'color': Colors.orange,
        'icon': Icons.access_time,
      },
      {
        'title': 'Non-Aktif',
        'value': stats['Non-Aktif'].toString(),
        'color': Colors.red,
        'icon': Icons.cancel,
      },
    ];
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: ratio,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (ctx, i) => _buildStatBox(
        data[i]['title'] as String,
        data[i]['value'] as String,
        data[i]['color'] as Color,
        data[i]['icon'] as IconData,
      ),
    );
  }

  Widget _buildStatBox(
    String title,
    String value,
    Color color,
    IconData icon,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _buildSearchBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Cari karyawan...',
              border: InputBorder.none,
              isDense: true,
              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: _onSearchChanged,
          ),
        ),
        if (searchQuery.isNotEmpty)
          GestureDetector(
            onTap: () {
              setState(() {
                searchQuery = '';
                _searchController.clear();
              });
              _refreshData();
            },
            child: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 16),
          ),
      ],
    ),
  );

  Widget _buildListHeader(int count) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'Daftar Karyawan',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count karyawan',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _showSortSheet,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.sort, size: 16, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    ],
  );

  // ── Employee card ──────────────────────────────────────────────────────────

  Widget _buildEmployeeCard(EmployeeData emp, {required bool isWeb}) {
    final isSelected = isWeb && _selectedEmployee?.id == emp.id;
    return GestureDetector(
      onTap: () => isWeb ? _selectEmployeeWeb(emp) : _showDetailEmployee(emp),
      child: Container(
        margin: EdgeInsets.only(bottom: isWeb ? 6 : 10),
        padding: EdgeInsets.all(isWeb ? 12 : 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6).withOpacity(0.3)
                : Colors.transparent,
          ),
          boxShadow: isWeb
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: isWeb ? 40 : 52,
              height: isWeb ? 40 : 52,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(isWeb ? 20 : 26),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isWeb ? 20 : 26),
                child: _buildProfileImage(emp.foto, isWeb ? 40 : 52),
              ),
            ),
            SizedBox(width: isWeb ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.nama,
                    style: TextStyle(
                      fontSize: isWeb ? 13 : 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    emp.jabatan,
                    style: TextStyle(
                      fontSize: isWeb ? 11 : 12,
                      color: const Color(0xFF3B82F6),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isWeb)
                    Text(
                      emp.departemen,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isWeb)
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400])
            else
              _buildStatusBadge(emp.status),
          ],
        ),
      ),
    );
  }

  Future<void> _selectEmployeeWeb(EmployeeData emp) async {
    setState(() {
      _selectedEmployee = emp;
      _isLoadingDetail = true;
    });
    try {
      final r = await EmployeeService.getEmployeeDetail(id: emp.id);
      if (r.success && r.data != null) {
        setState(() {
          _selectedEmployee = r.data!.toEmployeeData();
          _isLoadingDetail = false;
        });
      } else {
        setState(() => _isLoadingDetail = false);
      }
    } catch (_) {
      setState(() => _isLoadingDetail = false);
    }
  }

  // ── Mobile detail bottom sheet ─────────────────────────────────────────────

  void _showDetailEmployee(EmployeeData emp) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final r = await EmployeeService.getEmployeeDetail(id: emp.id);
      if (!mounted) return;
      Navigator.pop(context);
      _showDetailBottomSheet(
        r.success && r.data != null ? r.data!.toEmployeeData() : emp,
      );
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        _showDetailBottomSheet(emp);
      }
    }
  }

  void _showDetailBottomSheet(EmployeeData emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (ctx, scroll) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: _buildProfileImage(emp.foto, 72),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.nama,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          emp.jabatan,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        Text(
                          emp.departemen,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStatusBadge(emp.status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    _buildDetailSection('Informasi Personal', [
                      _buildDetailItem(
                        'ID Karyawan',
                        emp.nomorKaryawan,
                        Icons.badge,
                        Colors.blue,
                      ),
                      _buildDetailItemAction(
                        'Email',
                        emp.email,
                        Icons.email,
                        Colors.green,
                        onTap: () => _sendEmail(emp.email),
                        actionIcon: Icons.mail_outline,
                        actionColor: Colors.blue,
                      ),
                      _buildDetailItemAction(
                        'Telepon',
                        emp.telepon.isNotEmpty ? emp.telepon : 'Tidak ada data',
                        Icons.phone,
                        Colors.orange,
                        onTap: emp.telepon.isNotEmpty
                            ? () => _sendWhatsApp(emp.telepon)
                            : null,
                        actionIcon: Icons.chat,
                        actionColor: Colors.green,
                      ),
                      if (emp.gender?.isNotEmpty == true)
                        _buildDetailItem(
                          'Jenis Kelamin',
                          emp.gender!,
                          Icons.wc,
                          Colors.purple,
                        ),
                      if (emp.birthDate?.isNotEmpty == true)
                        _buildDetailItem(
                          'Tanggal Lahir',
                          _fmtTanggal(emp.birthDate!),
                          Icons.cake,
                          Colors.purple,
                        ),
                      if (emp.nik?.isNotEmpty == true)
                        _buildDetailItem(
                          'NIK',
                          emp.nik!,
                          Icons.credit_card,
                          Colors.indigo,
                        ),
                      if (emp.bpjsKetenagakerjaan?.isNotEmpty == true)
                        _buildDetailItem(
                          'BPJS Ketenagakerjaan',
                          emp.bpjsKetenagakerjaan!,
                          Icons.health_and_safety,
                          Colors.teal,
                        ),
                      if (emp.alamat.isNotEmpty)
                        _buildDetailItem(
                          'Alamat',
                          emp.alamat,
                          Icons.location_on,
                          Colors.red,
                        ),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Informasi Pekerjaan', [
                      _buildDetailItem(
                        'Departemen',
                        emp.departemen,
                        Icons.business,
                        Colors.purple,
                      ),
                      _buildDetailItem(
                        'Posisi',
                        emp.jabatan.isNotEmpty ? emp.jabatan : '-',
                        Icons.work,
                        Colors.blue,
                      ),
                      _buildDetailItem(
                        'Manager',
                        emp.manager.isNotEmpty ? emp.manager : '-',
                        Icons.supervisor_account,
                        Colors.cyan,
                      ),
                      _buildDetailItem(
                        'Tanggal Bergabung',
                        emp.tanggalBergabung.isNotEmpty
                            ? _fmtTanggal(emp.tanggalBergabung)
                            : '-',
                        Icons.calendar_today,
                        Colors.teal,
                      ),
                      if (emp.workingPeriodYear != null)
                        _buildDetailItem(
                          'Masa Kerja',
                          '${emp.workingPeriodYear} tahun ${emp.workingPeriodMonth} bulan',
                          Icons.schedule,
                          Colors.amber,
                        ),
                    ]),
                    if (emp.skills.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection('Skills', [
                        _buildSkillsList(emp.skills),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Tutup'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildIconBtn(
                    Icons.email_outlined,
                    Colors.blue,
                    () => _sendEmail(emp.email),
                  ),
                  const SizedBox(width: 6),
                  if (emp.telepon.isNotEmpty)
                    _buildIconBtn(
                      Icons.chat,
                      Colors.green,
                      () => _sendWhatsApp(emp.telepon),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      const SizedBox(height: 10),
      ...children,
    ],
  );

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildDetailItemAction(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    IconData? actionIcon,
    Color? actionColor,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null && actionIcon != null && value != 'Tidak ada data')
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (actionColor ?? color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(actionIcon, size: 18, color: actionColor ?? color),
            ),
          ),
      ],
    ),
  );

  Widget _buildSkillsList(List<String> skills) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.withOpacity(0.2)),
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                s,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _buildProfileImage(String? b64, double size) {
    if (b64 != null && b64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(b64),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(size),
        );
      } catch (_) {}
    }
    return _buildDefaultAvatar(size);
  }

  Widget _buildDefaultAvatar(double size) => Container(
    width: size,
    height: size,
    color: Colors.blue[100],
    child: Icon(Icons.person, size: size * 0.5, color: Colors.blue[600]),
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.people_outline, size: 72, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text(
          'Tidak ada karyawan ditemukan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Coba ubah filter atau kata kunci pencarian',
          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
          label: const Text('Muat Ulang'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Actions ────────────────────────────────────────────────────────────────

  void _sendEmail(String email) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {'subject': 'Hello'},
      );
      if (!await launchUrl(uri)) {
        _snackError('Tidak dapat membuka aplikasi email');
      }
    } catch (e) {
      _snackError('Error: $e');
    }
  }

  void _sendWhatsApp(String phone) async {
    try {
      String c = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (!c.startsWith('+')) {
        if (c.startsWith('0')) {
          c = '+62${c.substring(1)}';
        } else if (c.startsWith('62'))
          c = '+$c';
        else
          c = '+62$c';
      }
      if (!await launchUrl(
        Uri.parse('https://wa.me/$c'),
        mode: LaunchMode.externalApplication,
      )) {
        _snackError('WhatsApp tidak terinstall');
      }
    } catch (e) {
      _snackError('Error: $e');
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filter Karyawan',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Departemen',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                      [
                            'Semua',
                            'IT Development',
                            'Design',
                            'Human Resources',
                            'Marketing',
                          ]
                          .map(
                            (d) => FilterChip(
                              label: Text(d),
                              selected: selectedDepartment == d,
                              onSelected: (_) =>
                                  setM(() => selectedDepartment = d),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ['Semua', 'Aktif', 'Cuti', 'Non-Aktif']
                      .map(
                        (s) => FilterChip(
                          label: Text(s),
                          selected: selectedStatus == s,
                          onSelected: (_) => setM(() => selectedStatus = s),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                      _refreshData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Terapkan Filter',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Urutkan Berdasarkan',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            ...[
              'Nama A-Z',
              'Nama Z-A',
              'Tanggal Bergabung (Terbaru)',
              'Tanggal Bergabung (Terlama)',
            ].map(
              (s) => ListTile(
                leading: Icon(
                  sortBy == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: sortBy == s ? const Color(0xFF3B82F6) : Colors.grey,
                ),
                title: Text(s),
                onTap: () {
                  setState(() => sortBy = s);
                  Navigator.pop(context);
                  _refreshData();
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
