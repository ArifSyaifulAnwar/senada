// ignore_for_file: library_private_types_in_public_api, deprecated_member_use,
//                 use_build_context_synchronously

import 'dart:convert';

import 'package:absensikaryawan/models/employee_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// import form page (sesuaikan path dengan struktur project kamu)

import '../fitur/profile fitur/listkaryawan.dart';
import 'hrd_employee_service.dart';
import 'hrd_employee_form.dart';

// ── helper ──────────────────────────────────────────────────────────
bool _isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 768;

// ─────────────────────────────────────────────────────────────────────────────

class HrdListKaryawanPage extends StatefulWidget {
  const HrdListKaryawanPage({super.key});

  @override
  _HrdListKaryawanPageState createState() => _HrdListKaryawanPageState();
}

// ─────────────────────────────────────────────────────────────────────────────

class _HrdListKaryawanPageState extends State<HrdListKaryawanPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedDepartment = 'Semua';
  String _selectedStatus = 'Semua';
  String _sortBy = 'name_asc';

  List<EmployeeData> _employees = [];
  EmployeeStats? _stats;
  int _currentPage = 1;

  // Web: detail panel
  EmployeeData? _selectedEmployee;
  bool _isLoadingDetail = false;

  final TextEditingController _searchCtrl = TextEditingController();

  // ─── LIFECYCLE ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── DATA ────────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await HrdEmployeeService.getEmployeeList(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      department: _selectedDepartment == 'Semua' ? null : _selectedDepartment,
      status: _selectedStatus == 'Semua' ? null : _selectedStatus,
      sortBy: _sortBy,
      page: _currentPage,
      pageSize: 50,
    );

    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _employees = res.data!.data.map((e) => e.toEmployeeData()).toList();
        _stats = res.data!.stats;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    _selectedEmployee = null;
    await _loadData();
  }

  void _onSearch(String v) {
    setState(() => _searchQuery = v);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == v) _refresh();
    });
  }

  // ─── CRUD ACTIONS ────────────────────────────────────────────────────────────

  Future<void> _openForm({EmployeeData? employee}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HrdEmployeeFormPage(employee: employee),
      ),
    );
    if (result == true) _refresh();
  }

  Future<void> _confirmDelete(EmployeeData emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Karyawan'),
          ],
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus karyawan "${emp.nama}"?\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await HrdEmployeeService.deleteEmployee(emp.id);
    if (res.success) {
      _showSnack('Karyawan berhasil dihapus', isError: false);
      _refresh();
    } else {
      _showSnack(res.message, isError: true);
    }
  }

  Future<void> _selectEmployeeDetail(EmployeeData emp) async {
    setState(() {
      _selectedEmployee = emp;
      _isLoadingDetail = true;
    });

    final res = await HrdEmployeeService.getEmployeeDetail(emp.id);
    if (!mounted) return;

    setState(() {
      _isLoadingDetail = false;
      if (res.success && res.data != null) {
        _selectedEmployee = res.data!.toEmployeeData();
      }
    });
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWebLayout = _isWeb(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Tambah Karyawan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: isWebLayout ? _buildWebLayout() : _buildMobileLayout(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Manajemen Karyawan',
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: 'Filter',
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
        IconButton(
          tooltip: 'Muat ulang',
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
          onPressed: _refresh,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─── MOBILE ──────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage.isNotEmpty) _buildErrorBanner(),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildListHeader(),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                ),
              )
            else if (_employees.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _employees.length,
                itemBuilder: (ctx, i) =>
                    _buildEmployeeCard(_employees[i], isWeb: false),
              ),
            // Beri ruang untuk FAB
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ─── WEB ─────────────────────────────────────────────────────────────────────

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar
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
                  _buildWebStats(),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildWebFilterPanel(),
                ],
              ),
            ),
          ),
        ),

        // List tengah
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
                      _buildListHeader(),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF3B82F6),
                          ),
                        )
                      : _employees.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          itemCount: _employees.length,
                          itemBuilder: (ctx, i) =>
                              _buildEmployeeCard(_employees[i], isWeb: true),
                        ),
                ),
              ],
            ),
          ),
        ),

        // Panel detail
        Expanded(
          child: _selectedEmployee == null
              ? _buildDetailEmpty()
              : _isLoadingDetail
              ? const Center(child: CircularProgressIndicator())
              : _buildDetailPanel(_selectedEmployee!),
        ),
      ],
    );
  }

  // ─── STATS ───────────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final s = _getStats();
    final items = [
      {
        'label': 'Total',
        'value': s['Total'],
        'color': Colors.blue,
        'icon': Icons.people,
      },
      {
        'label': 'Aktif',
        'value': s['Aktif'],
        'color': Colors.green,
        'icon': Icons.check_circle,
      },
      {
        'label': 'Cuti',
        'value': s['Cuti'],
        'color': Colors.orange,
        'icon': Icons.access_time,
      },
      {
        'label': 'Non-Aktif',
        'value': s['Non-Aktif'],
        'color': Colors.red,
        'icon': Icons.cancel,
      },
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final color = item['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${item['value']}',
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
                item['label'] as String,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebStats() {
    final s = _getStats();
    final items = [
      {'label': 'Total', 'value': s['Total'], 'color': Colors.blue},
      {'label': 'Aktif', 'value': s['Aktif'], 'color': Colors.green},
      {'label': 'Cuti', 'value': s['Cuti'], 'color': Colors.orange},
      {'label': 'Non-Aktif', 'value': s['Non-Aktif'], 'color': Colors.red},
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
                    item['label'] as String,
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

  Map<String, int> _getStats() {
    if (_stats != null) {
      return {
        'Total': _stats!.totalEmployees,
        'Aktif': _stats!.activeEmployees,
        'Cuti': _stats!.onLeaveEmployees,
        'Non-Aktif': _stats!.inactiveEmployees,
      };
    }
    return {'Total': _employees.length, 'Aktif': 0, 'Cuti': 0, 'Non-Aktif': 0};
  }

  // ─── WEB FILTER ──────────────────────────────────────────────────────────────

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
        _filterChipsRow(
          'Departemen',
          ['Semua', 'IT Development', 'Design', 'Human Resources', 'Marketing'],
          _selectedDepartment,
          (v) {
            setState(() => _selectedDepartment = v);
            _refresh();
          },
        ),
        const SizedBox(height: 14),
        _filterChipsRow(
          'Status',
          ['Semua', 'Aktif', 'Cuti', 'Non-Aktif'],
          _selectedStatus,
          (v) {
            setState(() => _selectedStatus = v);
            _refresh();
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'Urutkan',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        ...[
          ['Nama A-Z', 'name_asc'],
          ['Nama Z-A', 'name_desc'],
          ['Terbaru', 'join_date_desc'],
          ['Terlama', 'join_date_asc'],
        ].map((item) {
          final label = item[0];
          final val = item[1];
          final selected = _sortBy == val;
          return GestureDetector(
            onTap: () {
              setState(() => _sortBy = val);
              _refresh();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF3B82F6).withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: selected
                        ? const Color(0xFF3B82F6)
                        : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? const Color(0xFF3B82F6)
                          : Colors.grey[700],
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

  Widget _filterChipsRow(
    String label,
    List<String> opts,
    String current,
    Function(String) onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: opts.map((o) {
            final sel = current == o;
            return GestureDetector(
              onTap: () => onTap(o),
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
                  o,
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
      ],
    );
  }

  // ─── SEARCH & HEADER ─────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Cari karyawan...',
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: _onSearch,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _searchQuery = '';
                  _searchCtrl.clear();
                });
                _refresh();
              },
              child: const Icon(
                Icons.clear,
                color: Color(0xFF94A3B8),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      children: [
        const Text(
          'Daftar Karyawan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_employees.length} karyawan',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── EMPLOYEE CARD ───────────────────────────────────────────────────────────

  Widget _buildEmployeeCard(EmployeeData emp, {required bool isWeb}) {
    final isSelected = isWeb && _selectedEmployee?.id == emp.id;

    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 6 : 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF3B82F6).withOpacity(0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.35)
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isWeb) {
            _selectEmployeeDetail(emp);
          } else {
            _showMobileDetail(emp);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 12 : 14),
          child: Row(
            children: [
              // Avatar
              _buildAvatar(emp.foto, isWeb ? 42 : 52),
              SizedBox(width: isWeb ? 10 : 12),
              // Info
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
              // Action buttons
              if (!isWeb)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionBtn(
                      Icons.edit_outlined,
                      Colors.blue,
                      () => _openForm(employee: emp),
                    ),
                    const SizedBox(width: 6),
                    _actionBtn(
                      Icons.delete_outline,
                      Colors.red,
                      () => _confirmDelete(emp),
                    ),
                  ],
                )
              else
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  // ─── DETAIL PANEL (WEB) ──────────────────────────────────────────────────────

  Widget _buildDetailEmpty() {
    return Center(
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
            'Klik nama karyawan di kiri untuk melihat detail',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(EmployeeData emp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header profil + action buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(emp.foto, 72),
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
              // Edit & Delete buttons
              Column(
                children: [
                  _actionBtn(Icons.edit, Colors.blue, () {
                    _openForm(employee: emp);
                  }),
                  const SizedBox(height: 6),
                  _actionBtn(Icons.delete, Colors.red, () {
                    _confirmDelete(emp);
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Detail sections
          _buildDetailSection('Informasi Personal', [
            _detailRow(
              'NIP',
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
            if (emp.birthDate != null && emp.birthDate!.isNotEmpty)
              _detailRow(
                'Tanggal Lahir',
                _fmtDate(emp.birthDate!),
                Icons.cake,
                Colors.purple,
              ),
            if (emp.nik != null && emp.nik!.isNotEmpty)
              _detailRow('NIK', emp.nik!, Icons.credit_card, Colors.indigo),
            if (emp.maritalStatus != null && emp.maritalStatus!.isNotEmpty)
              _detailRow(
                'Status Nikah',
                emp.maritalStatus!,
                Icons.favorite,
                Colors.pink,
              ),
            if (emp.religion != null && emp.religion!.isNotEmpty)
              _detailRow('Agama', emp.religion!, Icons.church, Colors.teal),
          ]),
          const SizedBox(height: 16),
          _buildDetailSection('Informasi Pekerjaan', [
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
            if (emp.jobLevel != null && emp.jobLevel!.isNotEmpty)
              _detailRow(
                'Level',
                emp.jobLevel!,
                Icons.trending_up,
                Colors.teal,
              ),
            if (emp.employmentStatus != null &&
                emp.employmentStatus!.isNotEmpty)
              _detailRow(
                'Status Kepegawaian',
                emp.employmentStatus!,
                Icons.card_membership,
                Colors.indigo,
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
                  ? _fmtDate(emp.tanggalBergabung)
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
          ]),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: emp.skills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget?> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        ...children.whereType<Widget>(),
      ],
    );
  }

  Widget _detailRow(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (value.isEmpty || value == '-')
            ? Colors.grey.shade50
            : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (value.isEmpty || value == '-')
              ? Colors.grey.shade200
              : color.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: (value.isEmpty || value == '-') ? Colors.grey[400] : color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: (value.isEmpty || value == '-')
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

  // ─── MOBILE DETAIL BOTTOM SHEET ──────────────────────────────────────────────

  void _showMobileDetail(EmployeeData emp) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await HrdEmployeeService.getEmployeeDetail(emp.id);
    if (!mounted) return;
    Navigator.pop(context);

    final detail = (res.success && res.data != null)
        ? res.data!.toEmployeeData()
        : emp;
    _showDetailSheet(detail);
  }

  void _showDetailSheet(EmployeeData emp) {
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
        builder: (ctx, scrollCtrl) => Container(
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
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  _buildAvatar(emp.foto, 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.nama,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          emp.jabatan,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          emp.departemen,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusBadge(emp.status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Edit / Hapus
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(employee: emp);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(emp);
                      },
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Hapus'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Scroll detail
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    _mobileDetailItem(
                      'NIP',
                      emp.nomorKaryawan,
                      Icons.badge,
                      Colors.blue,
                    ),
                    _mobileDetailItem(
                      'Email',
                      emp.email,
                      Icons.email,
                      Colors.green,
                    ),
                    _mobileDetailItem(
                      'Telepon',
                      emp.telepon.isNotEmpty ? emp.telepon : '-',
                      Icons.phone,
                      Colors.orange,
                    ),
                    if (emp.nik != null && emp.nik!.isNotEmpty)
                      _mobileDetailItem(
                        'NIK',
                        emp.nik!,
                        Icons.credit_card,
                        Colors.indigo,
                      ),
                    if (emp.birthDate != null && emp.birthDate!.isNotEmpty)
                      _mobileDetailItem(
                        'Tanggal Lahir',
                        _fmtDate(emp.birthDate!),
                        Icons.cake,
                        Colors.purple,
                      ),
                    _mobileDetailItem(
                      'Departemen',
                      emp.departemen,
                      Icons.business,
                      Colors.purple,
                    ),
                    _mobileDetailItem(
                      'Posisi',
                      emp.jabatan.isNotEmpty ? emp.jabatan : '-',
                      Icons.work,
                      Colors.blue,
                    ),
                    _mobileDetailItem(
                      'Bergabung',
                      emp.tanggalBergabung.isNotEmpty
                          ? _fmtDate(emp.tanggalBergabung)
                          : '-',
                      Icons.calendar_today,
                      Colors.teal,
                    ),
                    if (emp.skills.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Skills',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: emp.skills.map((s) {
                          return Container(
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
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
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
                  ),
                ),
                const SizedBox(height: 2),
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
  }

  // ─── FILTER SHEET (MOBILE) ───────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => SafeArea(
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
                              selected: _selectedDepartment == d,
                              onSelected: (_) =>
                                  setModal(() => _selectedDepartment = d),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
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
                          selected: _selectedStatus == s,
                          onSelected: (_) =>
                              setModal(() => _selectedStatus = s),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                      _refresh();
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
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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

  // ─── SHARED HELPERS ──────────────────────────────────────────────────────────

  Widget _buildAvatar(String? b64, double size) {
    Widget inner;
    if (b64 != null && b64.isNotEmpty) {
      try {
        inner = Image.memory(
          base64Decode(b64),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(size),
        );
      } catch (_) {
        inner = _defaultAvatar(size);
      }
    } else {
      inner = _defaultAvatar(size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: inner,
    );
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.blue[100],
      child: Icon(Icons.person, size: size * 0.5, color: Colors.blue[600]),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildErrorBanner() {
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
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = ''),
            icon: const Icon(Icons.close, color: Colors.red, size: 18),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refresh,
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
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
