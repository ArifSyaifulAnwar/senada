import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:absensikaryawan/Screen%20admin/service/web_preview.dart';
import 'package:absensikaryawan/Services/company_calendar_service.dart';
import 'package:absensikaryawan/Services/excel_export_service.dart';
import 'package:absensikaryawan/Services/employee_service.dart';
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dailyactivitymodels.dart';
import '../models/employee_models.dart';
import 'service/daily_activity_service.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class _EmployeeFilterOption {
  final String id;
  final String name;
  final String job;

  const _EmployeeFilterOption({
    required this.id,
    required this.name,
    required this.job,
  });
}

class AllEmployeeActivitiesScreen extends StatefulWidget {
  const AllEmployeeActivitiesScreen({super.key});

  @override
  State<AllEmployeeActivitiesScreen> createState() =>
      _AllEmployeeActivitiesScreenState();
}

class _AllEmployeeActivitiesScreenState
    extends State<AllEmployeeActivitiesScreen> {
  bool _isLoading = true;
  bool _accessDenied = false;
  String? _accessMessage;
  bool _isAttachmentProcessing = false;
  bool _isExporting = false;

  List<DailyActivityHRDItem> _activities = [];
  List<EmployeeApiData> _companyEmployees = [];
  String _searchQuery = '';
  String _categoryFilter = 'Semua';
  String _employeeFilter = 'Semua';
  String _selectedTimeRange = 'Periode Kerja';
  List<WorkPeriod> _workPeriods = [];
  WorkPeriod? _selectedWorkPeriod;

  // Null berarti semua tanggal. Data tetap langsung dimuat ketika halaman dibuka.
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initializePeriodFilter();
    _loadCompanyEmployees();
  }

  Future<void> _loadCompanyEmployees() async {
    final response = await EmployeeService.getEmployeeList(
      page: 1,
      pageSize: 1000,
      sortBy: 'name_asc',
    );
    if (!mounted || !response.success || response.data == null) return;
    setState(() => _companyEmployees = response.data!.data
        .where((employee) => employee.userId.trim().isNotEmpty)
        .toList());
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String get _dateFilterLabel {
    if (_selectedWorkPeriod != null) {
      return _workPeriodLabel(_selectedWorkPeriod!);
    }

    if (_selectedTimeRange != 'Pilih Periode') return _selectedTimeRange;

    if (_startDate == null || _endDate == null) return 'Pilih Periode';

    if (DateUtils.isSameDay(_startDate, _endDate)) {
      return _formatDate(_startDate!);
    }

    return '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}';
  }

  Future<void> _initializePeriodFilter() async {
    await _loadWorkPeriods();
    await _loadData();
  }

  Future<void> _loadWorkPeriods() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID') ?? '';
    if (userId.isEmpty) return;

    try {
      final results = await Future.wait([
        CompanyCalendarService.getWorkPeriodsByYear(now.year, userId: userId),
        CompanyCalendarService.getWorkPeriodsByYear(now.year - 1, userId: userId),
      ]);
      final periodsById = <int, WorkPeriod>{};
      for (final periods in results) {
        for (final period in periods) {
          periodsById[period.id] = period;
        }
      }
      final periods = periodsById.values.toList()
        ..sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));
      final today = _dateOnly(now);
      final active = periods.cast<WorkPeriod?>().firstWhere(
            (period) =>
                period != null &&
                !today.isBefore(_dateOnly(period.tanggalMulai)) &&
                !today.isAfter(_dateOnly(period.tanggalSelesai)),
            orElse: () => periods.isNotEmpty ? periods.first : null,
          );
      if (!mounted) return;
      setState(() {
        _workPeriods = periods;
        _selectedWorkPeriod = active;
        if (active != null) {
          _selectedTimeRange = 'Periode Kerja';
          _startDate = _dateOnly(active.tanggalMulai);
          _endDate = _dateOnly(active.tanggalSelesai);
        } else {
          _applyRelativeRange('30 Hari Terakhir');
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _applyRelativeRange('30 Hari Terakhir'));
    }
  }

  String _workPeriodLabel(WorkPeriod period) {
    final description = period.keterangan.trim();
    return description.isNotEmpty
        ? description
        : 'Periode ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime(period.tahun, period.bulan))}';
  }

  void _applyRelativeRange(String range) {
    final today = _dateOnly(DateTime.now());
    final days = switch (range) {
      '1 Hari' => 0,
      '7 Hari Terakhir' => 6,
      '30 Hari Terakhir' => 29,
      _ => 364,
    };
    _selectedTimeRange = range;
    _selectedWorkPeriod = null;
    _startDate = today.subtract(Duration(days: days));
    _endDate = today;
  }

  Future<void> _selectRelativeRange(String range) async {
    setState(() => _applyRelativeRange(range));
    await _loadData();
  }

  Future<void> _selectWorkPeriod(WorkPeriod period) async {
    setState(() {
      _selectedTimeRange = 'Periode Kerja';
      _selectedWorkPeriod = period;
      _startDate = _dateOnly(period.tanggalMulai);
      _endDate = _dateOnly(period.tanggalSelesai);
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _accessDenied = false;
    });

    final result = await DailyActivityService.getAllActivitiesHRD(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;

    setState(() {
      _accessDenied = result['accessDenied'] ?? false;
      _accessMessage = result['message'];
      _activities = List<DailyActivityHRDItem>.from(result['activities'] ?? []);
      _isLoading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final now = _dateOnly(DateTime.now());

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: 'Pilih rentang tanggal aktivitas',
      confirmText: 'Terapkan',
      cancelText: 'Batal',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _startDate = _dateOnly(picked.start);
      _endDate = _dateOnly(picked.end);
      _selectedTimeRange = 'Pilih Periode';
      _selectedWorkPeriod = null;
    });

    // Saat pengguna memilih tanggal, data langsung dimuat ulang.
    await _loadData();
  }


  List<DailyActivityHRDItem> get _filteredActivities {
    return _activities.where((a) {
      final q = _searchQuery.toLowerCase();
      final activityDate = _dateOnly(a.activityDate);

      final matchSearch =
          q.isEmpty ||
          a.employeeName.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          a.categoryLabel.toLowerCase().contains(q);

      final matchCategory =
          _categoryFilter == 'Semua' || a.categoryLabel == _categoryFilter;
      // API versi baru mengirim UserId. Saat server lama belum dipublish,
      // gunakan nama sebagai fallback yang sama dengan nilai dropdown agar
      // memilih karyawan tidak menghasilkan daftar kosong.
      final employeeKey =
          a.employeeUserId.isNotEmpty ? a.employeeUserId : a.employeeName;
      final selectedEmployee = _employeeOptions.cast<_EmployeeFilterOption?>().firstWhere(
            (employee) => employee?.id == _employeeFilter,
            orElse: () => null,
          );
      final matchEmployee =
          _employeeFilter == 'Semua' ||
          employeeKey == _employeeFilter ||
          (a.employeeUserId.isEmpty &&
              selectedEmployee != null &&
              a.employeeName == selectedEmployee.name);

      // Filter lokal sebagai pengaman agar hasil tetap benar walaupun API lama
      // belum menerapkan StartDate dan EndDate di query database.
      final matchStart =
          _startDate == null || !activityDate.isBefore(_dateOnly(_startDate!));
      final matchEnd =
          _endDate == null || !activityDate.isAfter(_dateOnly(_endDate!));

      return matchSearch &&
          matchCategory &&
          matchEmployee &&
          matchStart &&
          matchEnd;
    }).toList();
  }

  List<String> get _categoryOptions {
    final set = <String>{'Semua'};
    for (final a in _activities) {
      if (a.categoryLabel.isNotEmpty) set.add(a.categoryLabel);
    }
    return set.toList();
  }

  List<_EmployeeFilterOption> get _employeeOptions {
    final employees = <String, _EmployeeFilterOption>{};
    for (final employee in _companyEmployees) {
      final id = employee.userId.trim();
      if (id.isEmpty) continue;
      employees[id] = _EmployeeFilterOption(
        id: id,
        name: employee.name,
        job: (employee.jobPosition ?? employee.jobs ?? '').trim(),
      );
    }
    for (final activity in _activities) {
      final key = activity.employeeUserId.isNotEmpty
          ? activity.employeeUserId
          : activity.employeeName;
      employees.putIfAbsent(
        key,
        () => _EmployeeFilterOption(
          id: key,
          name: activity.employeeName,
          job: activity.jobPosition,
        ),
      );
    }
    final result = employees.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  int get _employeeCount =>
      _filteredActivities.map((e) => e.employeeUserId.isNotEmpty ? e.employeeUserId : e.employeeName).toSet().length;
  int get _attachmentCount =>
      _filteredActivities.fold<int>(0, (sum, e) => sum + e.attachments.length);

  Widget _buildTeamOverview({bool compact = false}) => Container(
    margin: EdgeInsets.fromLTRB(compact ? 16 : 0, 0, compact ? 16 : 0, 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE0E7FF)),
      boxShadow: [BoxShadow(color: const Color(0xFF1D4ED8).withValues(alpha: .07), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.insights_rounded, color: Color(0xFF4F46E5))),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ringkasan aktivitas tim', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF182230))),
          SizedBox(height: 2), Text('Pantau aktivitas dan bukti kerja karyawan PT Anda', style: TextStyle(fontSize: 11, color: Color(0xFF667085))),
        ])),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        _teamMetric('${_filteredActivities.length}', 'Aktivitas', const Color(0xFF155EEF)),
        _teamMetric('$_employeeCount', 'Karyawan', const Color(0xFF12B76A)),
        _teamMetric('$_attachmentCount', 'Bukti', const Color(0xFFF79009)),
      ]),
    ]),
  );

  Widget _teamMetric(String value, String label, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
    child: Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF667085)))]),
  ));

  String _formatDate(DateTime d) =>
      DateFormat('dd MMM yyyy', 'id_ID').format(d);

  IconData _fileIcon(String fileType) {
    if (fileType.startsWith('image/')) return Icons.image_rounded;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (fileType.contains('word')) return Icons.description_rounded;
    if (fileType.contains('excel')) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Aktivitas Karyawan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Export Excel',
            onPressed: _isExporting || _filteredActivities.isEmpty
                ? null
                : _exportExcel,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accessDenied
          ? _buildAccessDenied()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _isWideScreen(context)
                  ? _buildWebBody()
                  : _buildMobileBody(),
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _accessMessage ?? 'Anda tidak memiliki akses ke fitur ini',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: Column(children: [_buildTeamOverview(compact: true), _buildFilters()])),
        if (_filteredActivities.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildActivityCard(_filteredActivities[i]),
                childCount: _filteredActivities.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildTeamOverview(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 290, child: _buildWebFilterPanel()),
                    const SizedBox(width: 18),
                    Expanded(child: _buildWebResultsPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebFilterPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.tune_rounded, color: Color(0xFF155EEF), size: 19),
              SizedBox(width: 8),
              Text('Filter laporan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Cari aktivitas...',
                prefixIcon: const Icon(Icons.search, size: 19),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _filterTitle('Periode'),
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showPeriodSelector,
              icon: const Icon(Icons.calendar_month_rounded, size: 17),
              label: Text(_dateFilterLabel, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: const Color(0xFF155EEF),
                minimumSize: const Size.fromHeight(43),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            _filterTitle('Karyawan'),
            const SizedBox(height: 7),
            _buildEmployeeDropdown(compact: true),
            const SizedBox(height: 16),
            _filterTitle('Kategori'),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categoryOptions.map((category) {
                final selected = category == _categoryFilter;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _categoryFilter = category),
                  selectedColor: const Color(0xFF155EEF),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF344054),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF155EEF)
                        : const Color(0xFFD0D5DD),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isExporting || _filteredActivities.isEmpty
                    ? null
                    : _exportExcel,
                icon: _isExporting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined, size: 18),
                label: Text(_isExporting ? 'Membuat Excel...' : 'Export Excel'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF155EEF),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text('Export tanpa file lampiran.',
                style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _filterTitle(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFF344054), fontSize: 12, fontWeight: FontWeight.w700));

  Widget _buildWebResultsPanel() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: _filteredActivities.isEmpty
            ? _buildEmptyState()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 10),
                    child: Row(children: [
                      const Expanded(
                        child: Text('Daftar aktivitas',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(18)),
                        child: Text('${_filteredActivities.length} aktivitas',
                            style: const TextStyle(
                                color: Color(0xFF155EEF),
                                fontWeight: FontWeight.w700,
                                fontSize: 11)),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _filteredActivities.length,
                      itemBuilder: (_, index) =>
                          _buildActivityCard(_filteredActivities[index]),
                    ),
                  ),
                ],
              ),
      );

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan / deskripsi / kategori...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: _isLoading ? null : _showPeriodSelector,
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(_dateFilterLabel, overflow: TextOverflow.ellipsis),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF007AFF),
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _employeeOptions.any((item) => item.id == _employeeFilter)
                ? _employeeFilter
                : 'Semua',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Karyawan',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            items: [
              const DropdownMenuItem(value: 'Semua', child: Text('Semua karyawan')),
              ..._employeeOptions.map((employee) {
                final subtitle = employee.job;
                return DropdownMenuItem(
                  value: employee.id,
                  child: Text(
                    subtitle.isEmpty || subtitle == '-'
                        ? employee.name
                        : '${employee.name} - $subtitle',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (value) =>
                setState(() => _employeeFilter = value ?? 'Semua'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categoryOptions.map((c) {
                final sel = c == _categoryFilter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (_) => setState(() => _categoryFilter = c),
                    selectedColor: const Color(0xFF007AFF),
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filteredActivities.length} aktivitas ditemukan',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDropdown({bool compact = false}) {
    final currentValue = _employeeOptions.any((item) => item.id == _employeeFilter)
        ? _employeeFilter
        : 'Semua';
    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: compact ? null : 'Karyawan',
        hintText: compact ? 'Semua karyawan' : null,
        prefixIcon: const Icon(Icons.person_outline_rounded),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: [
        const DropdownMenuItem(value: 'Semua', child: Text('Semua karyawan')),
        ..._employeeOptions.map((employee) {
          final subtitle = employee.job;
          return DropdownMenuItem(
            value: employee.id,
            child: Text(
              subtitle.isEmpty || subtitle == '-'
                  ? employee.name
                  : '${employee.name} - $subtitle',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) => setState(() => _employeeFilter = value ?? 'Semua'),
    );
  }

  Future<void> _exportExcel() async {
    final data = _filteredActivities;
    if (data.isEmpty) {
      _showSnack('Tidak ada aktivitas sesuai filter untuk diexport.', Colors.red);
      return;
    }
    setState(() => _isExporting = true);
    try {
      _EmployeeFilterOption? selectedEmployee;
      for (final employee in _employeeOptions) {
        if (employee.id == _employeeFilter) {
          selectedEmployee = employee;
          break;
        }
      }
      final bytes = ExcelExportService.buildDailyActivityExcel(
        data,
        periodLabel: _dateFilterLabel,
        employeeLabel: selectedEmployee?.name ?? 'Semua karyawan',
        categoryLabel:
            _categoryFilter == 'Semua' ? 'Semua kategori' : _categoryFilter,
      );
      if (bytes == null) throw Exception('Gagal membuat berkas Excel.');
      final fileName =
          'Laporan_Aktivitas_Harian_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        await OpenFile.open(file.path);
      }
      if (mounted) _showSnack('Laporan Excel berhasil dibuat.', Colors.green);
    } catch (error) {
      if (mounted) _showSnack('Gagal export Excel: $error', Colors.red);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showPeriodSelector() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Periode aktivitas',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Pilih rentang data aktivitas yang ingin ditampilkan.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 14),
              _periodOption(
                icon: Icons.event_note_rounded,
                title: _selectedWorkPeriod != null
                    ? _workPeriodLabel(_selectedWorkPeriod!)
                    : 'Periode kerja HRD',
                subtitle: _selectedWorkPeriod == null
                    ? 'Periode kerja belum tersedia'
                    : '${_formatDate(_selectedWorkPeriod!.tanggalMulai)} - ${_formatDate(_selectedWorkPeriod!.tanggalSelesai)}',
                selected: _selectedWorkPeriod != null,
                onTap: _workPeriods.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(sheetContext);
                        await _showWorkPeriodPicker();
                      },
              ),
              const SizedBox(height: 8),
              for (final range in const [
                '1 Hari',
                '7 Hari Terakhir',
                '30 Hari Terakhir',
                '1 Tahun Terakhir',
              ])
                _periodOption(
                  icon: Icons.radio_button_checked_rounded,
                  title: range,
                  selected: _selectedTimeRange == range && _selectedWorkPeriod == null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _selectRelativeRange(range);
                  },
                ),
              _periodOption(
                icon: Icons.date_range_rounded,
                title: 'Pilih Periode',
                subtitle: _selectedTimeRange == 'Pilih Periode' && _startDate != null
                    ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                    : null,
                selected: _selectedTimeRange == 'Pilih Periode',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickDateRange();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWorkPeriodPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text('Pilih periode kerja HRD',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ..._workPeriods.map((period) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    period.id == _selectedWorkPeriod?.id
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: const Color(0xFF007AFF),
                  ),
                  title: Text(_workPeriodLabel(period)),
                  subtitle: Text(
                      '${_formatDate(period.tanggalMulai)} - ${_formatDate(period.tanggalSelesai)}'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _selectWorkPeriod(period);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _periodOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF007AFF).withValues(alpha: .08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            size: 18, color: selected ? const Color(0xFF007AFF) : Colors.grey[400]),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: selected ? const Color(0xFF007AFF) : Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? const Color(0xFF007AFF) : const Color(0xFF1F2937))),
          if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ])),
      ]),
    ),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              'Belum ada aktivitas',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(DailyActivityHRDItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showDetail(item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        item.icon,
                        size: 16,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.employeeName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            '${item.categoryLabel} • ${_formatDate(item.activityDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF374151),
                  ),
                ),
                if (item.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.attachments.length} lampiran',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(DailyActivityHRDItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(
                              0xFF007AFF,
                            ).withValues(alpha: 0.1),
                            child: Text(
                              item.employeeName.isNotEmpty
                                  ? item.employeeName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFF007AFF),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.employeeName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  item.jobPosition,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(bottomContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _detailSection(
                        title: 'Detail Aktivitas',
                        icon: Icons.event_note_rounded,
                        children: [
                          _detailRow('Kategori', item.categoryLabel),
                          _detailRow('Tanggal', _formatDate(item.activityDate)),
                          if (item.startTime != null && item.endTime != null)
                            _detailRow(
                              'Jam Kerja',
                              '${item.startTime!.formatted} - ${item.endTime!.formatted}',
                            ),
                          if (item.displayLocation.isNotEmpty)
                            _detailRow('Lokasi', item.displayLocation),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _detailSection(
                        title: 'Deskripsi',
                        icon: Icons.notes_rounded,
                        children: [
                          Text(
                            item.description,
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ],
                      ),
                      if (item.attachments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildAttachmentSection(item),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF007AFF), size: 17),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentSection(DailyActivityHRDItem item) {
    return _detailSection(
      title: item.attachments.length > 1
          ? 'Lampiran (${item.attachments.length} file)'
          : 'Lampiran',
      icon: Icons.attach_file_rounded,
      children: List.generate(item.attachments.length, (i) {
        final att = item.attachments[i];
        return Padding(
          padding: EdgeInsets.only(
            bottom: i < item.attachments.length - 1 ? 12 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _fileIcon(att.fileType),
                        color: const Color(0xFF007AFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        att.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAttachmentProcessing
                          ? null
                          : () => _handleAttachment(att, preview: true),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF007AFF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isAttachmentProcessing
                          ? null
                          : () => _handleAttachment(att, preview: false),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _handleAttachment(
    DailyActivityAttachment att, {
    required bool preview,
  }) async {
    if (att.id == null || _isAttachmentProcessing) return;
    setState(() => _isAttachmentProcessing = true);
    try {
      final bytes = await DailyActivityService.downloadAttachmentBytesHRD(
        att.id!,
      );
      if (bytes == null) {
        _showSnack('Gagal mengambil file.', Colors.red);
        return;
      }
      if (preview) {
        await _previewAttachment(bytes, att.fileName, att.fileType);
      } else {
        await _downloadAttachment(bytes, att.fileName);
      }
    } catch (e) {
      _showSnack('Gagal memproses lampiran: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isAttachmentProcessing = false);
    }
  }

  Future<void> _previewAttachment(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    if (mimeType.startsWith('image/')) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      );
      return;
    }
    if (kIsWeb) {
      openBytesInBrowser(bytes, fileName, mimeType);
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final localFile = File('${tempDir.path}/${_safeFileName(fileName)}');
    await localFile.writeAsBytes(bytes, flush: true);
    await OpenFile.open(localFile.path);
  }

  Future<void> _downloadAttachment(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName);
      _showSnack('File sedang diunduh.', Colors.green);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/${_safeFileName(fileName)}');
    await localFile.writeAsBytes(bytes, flush: true);
    _showSnack('File tersimpan: ${localFile.path}', Colors.green);
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.trim().isEmpty ? 'lampiran' : sanitized;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
