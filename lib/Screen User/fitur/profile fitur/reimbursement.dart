// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';

import 'package:absensikaryawan/Screen%20User/fitur/ajukanreimbursement.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/detailmodalcontent.dart';
import 'package:absensikaryawan/Services/reimbursementmodel.dart';
import 'package:absensikaryawan/Services/reimbursementservice.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/halaman_finance_reimbursement.dart';

class HalamanReimbursement extends StatefulWidget {
  const HalamanReimbursement({super.key});

  @override
  _HalamanReimbursementState createState() => _HalamanReimbursementState();
}

class _HalamanReimbursementState extends State<HalamanReimbursement> {
  final ReimbursementService _reimbursementService = ReimbursementService();

  List<ReimbursementData> _allReimbursements = [];
  List<ReimbursementData> _filteredReimbursements = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _selectedStatus;

  // ── Finance role check ────────────────────────────────────────────────
  bool _isHeadFinance = false;
  bool _isCheckingRole = false;

  // Filter periode mengikuti periode kerja yang dibuat HRD pada Kalender.
  int _selectedPeriodYear = DateTime.now().year;
  List<_ReimbursementWorkPeriod> _workPeriods = const [];
  _ReimbursementWorkPeriod? _selectedWorkPeriod;
  bool _isLoadingPeriods = false;
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ── Auth token ────────────────────────────────────────────────────────
  static Future<String?> _getToken() async {
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
        return d['access_token'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ── Check Head Finance via API ─────────────────────────────────────────
  Future<void> _checkIsHeadFinance(String userId) async {
    if (!mounted) return;
    setState(() => _isCheckingRole = true);
    try {
      final tok = await _getToken();
      final res = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/is-head-finance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tok',
        },
        body: json.encode({'userId': userId}),
      );
      if (res.statusCode == 200 && mounted) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        setState(() => _isHeadFinance = body['isHeadFinance'] == true);
      }
    } catch (_) {}
    if (mounted) setState(() => _isCheckingRole = false);
  }

  // ── Load ──────────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('UserID');

    if (_currentUserId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Ambil periode kerja HRD dulu supaya filter awal langsung mengikuti
    // kalender/Periode yang dibuat HRD, bukan bulan kalender biasa.
    await _loadWorkPeriodsForYear(
      DateTime.now().year,
      applyFilterAfterLoad: false,
    );

    await Future.wait([
      _loadReimbursements(),
      _checkIsHeadFinance(_currentUserId!),
    ]);
  }

  Future<void> _loadReimbursements() async {
    if (_currentUserId == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      String? statusFilter;

      if (_selectedStatus != null && _selectedStatus != 'Semua') {
        statusFilter = _mapStatusToApi(_selectedStatus!);
      }

      final data = await _reimbursementService.getReimbursementList(
        userId: _currentUserId!,
        status: statusFilter,
      );

      if (!mounted) return;

      setState(() => _allReimbursements = data);
      _applyClientSideFilter();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal memuat data reimbursement: $e');
    }
  }

  Future<void> _loadWorkPeriodsForYear(
    int year, {
    bool applyFilterAfterLoad = true,
  }) async {
    if (mounted) {
      setState(() {
        _isLoadingPeriods = true;
        _selectedPeriodYear = year;
      });
    }

    try {
      final token = await _getToken();

      final response = await http
          .post(
            Uri.parse('$baseURL/api/calendar/period/list'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.trim().isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'tahun': year}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);

      final body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};

      final success = body['success'] ?? body['Success'] ?? false;
      final rawData = body['data'] ?? body['Data'] ?? const [];

      final periods = success == true && rawData is List
          ? rawData
                .whereType<Map>()
                .map(
                  (item) => _ReimbursementWorkPeriod.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where(
                  (item) => !item.tanggalSelesai.isBefore(item.tanggalMulai),
                )
                .toList()
          : <_ReimbursementWorkPeriod>[];

      periods.sort((a, b) => a.tanggalMulai.compareTo(b.tanggalMulai));

      final previousId = _selectedWorkPeriod?.id;
      _ReimbursementWorkPeriod? selected;

      for (final period in periods) {
        if (period.id == previousId) {
          selected = period;
          break;
        }
      }

      selected ??= _getRunningOrNearestPeriod(periods);

      if (!mounted) return;

      setState(() {
        _workPeriods = periods;
        _selectedWorkPeriod = selected;
        _isLoadingPeriods = false;
      });

      if (applyFilterAfterLoad) {
        _applyClientSideFilter();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _workPeriods = const [];
        _selectedWorkPeriod = null;
        _isLoadingPeriods = false;
      });

      if (applyFilterAfterLoad) {
        _applyClientSideFilter();
      }

      _showErrorSnackBar('Gagal memuat periode kerja HRD: $e');
    }
  }

  _ReimbursementWorkPeriod? _getRunningOrNearestPeriod(
    List<_ReimbursementWorkPeriod> periods,
  ) {
    if (periods.isEmpty) return null;

    final today = _dateOnly(DateTime.now());

    // Prioritaskan periode yang sedang berjalan.
    for (final period in periods) {
      if (!today.isBefore(period.tanggalMulai) &&
          !today.isAfter(period.tanggalSelesai)) {
        return period;
      }
    }

    // Jika belum ada periode aktif, gunakan periode terakhir yang sudah lewat.
    final passed =
        periods
            .where((period) => !period.tanggalSelesai.isAfter(today))
            .toList()
          ..sort((a, b) => b.tanggalSelesai.compareTo(a.tanggalSelesai));

    if (passed.isNotEmpty) return passed.first;

    // Jika semuanya periode mendatang, pilih periode paling awal.
    return periods.first;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _applyClientSideFilter() {
    List<ReimbursementData> filtered = List.of(_allReimbursements);
    final period = _selectedWorkPeriod;

    if (period != null) {
      final start = _dateOnly(period.tanggalMulai);
      final end = _dateOnly(period.tanggalSelesai);

      // Tetap memakai submittedAt karena filter lama reimbursement memang
      // berdasarkan tanggal pengajuan. Bila kelak ingin berdasarkan tanggal
      // pengeluaran, cukup ganti r.submittedAt menjadi r.expenseDate.
      filtered = filtered.where((r) {
        final submittedDate = _dateOnly(r.submittedAt);

        return !submittedDate.isBefore(start) && !submittedDate.isAfter(end);
      }).toList();
    }

    filtered.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    if (!mounted) return;

    setState(() {
      _filteredReimbursements = filtered;
      _isLoading = false;
    });
  }

  void _applyFilter() {
    setState(() => _isFilterExpanded = false);
    _applyClientSideFilter();
  }

  Future<void> _resetFilter() async {
    await _loadWorkPeriodsForYear(DateTime.now().year);
    if (!mounted) return;
    setState(() => _isFilterExpanded = false);
  }

  String _getFilterDisplayText() {
    final period = _selectedWorkPeriod;

    if (period == null) {
      return _isLoadingPeriods
          ? 'Memuat periode HRD...'
          : 'Belum ada periode HRD';
    }

    return period.displayLabel;
  }

  String _getPeriodRangeText(_ReimbursementWorkPeriod period) {
    return '${_formatShortDate(period.tanggalMulai)} – '
        '${_formatShortDate(period.tanggalSelesai)}';
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  List<int> _getAvailablePeriodYears() {
    final currentYear = DateTime.now().year;

    final years = <int>{
      currentYear - 1,
      currentYear,
      currentYear + 1,
      _selectedPeriodYear,
      ..._workPeriods.map((period) => period.tahun),
    }.toList()..sort((a, b) => b.compareTo(a));

    return years;
  }

  String _mapStatusToApi(String displayStatus) {
    switch (displayStatus) {
      case 'Draft':
        return 'draft';
      case 'Menunggu':
        return 'pending';
      case 'Disetujui':
        return 'approved';
      case 'Ditolak':
        return 'rejected';
      case 'Dibayar':
        return 'paid';
      default:
        return 'pending';
    }
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

  void _showDetail(ReimbursementData item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DetailModalContent(
        initialItem: item,
        reimbursementService: _reimbursementService,
        currentUserId: _currentUserId,
        getResponsiveFontSize: (context, size) => size,
        getResponsivePadding: (context, padding) => padding,
        formatDateTime: _formatDateTime,
        buildDetailRow: _buildDetailRow,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
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
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';

  void _navigateToRequestPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HalamanAjukanReimbursement()),
    );
    if (result == true) _loadReimbursements();
  }

  // ── Finance Panel Button ──────────────────────────────────────────────
  Widget _buildFinancePanelButton() {
    // Tidak tampil: sedang loading role, atau bukan Head Finance
    if (_isCheckingRole || !_isHeadFinance) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HalamanFinanceReimbursement(),
          ),
        ),
        icon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
        label: const Text(
          'Panel Finance — Review Reimbursement',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Reimbursement',
          style: TextStyle(
            fontSize: 20,
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
              onPressed: _loadReimbursements,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReimbursements,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Tombol Finance Panel (hanya untuk Head Finance) ──
                    _buildFinancePanelButton(),

                    // ── Filter Section ───────────────────────────────────
                    _buildFilterSection(),
                    const SizedBox(height: 24),

                    // ── Section Header ───────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Riwayat Reimbursement',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_filteredReimbursements.length} data',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Content ──────────────────────────────────────────
                    if (_filteredReimbursements.isEmpty)
                      _buildEmptyState()
                    else
                      ..._filteredReimbursements.map(_buildReimbursementCard),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _navigateToRequestPage,
          label: const Text(
            'Ajukan Reimbursement',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final availableYears = _getAvailablePeriodYears();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: _isFilterExpanded
                  ? Radius.zero
                  : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      size: 20,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Periode HRD',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getFilterDisplayText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (_isFilterExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tahun:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedPeriodYear,
                              onChanged: (year) async {
                                if (year == null ||
                                    year == _selectedPeriodYear) {
                                  return;
                                }

                                await _loadWorkPeriodsForYear(year);
                              },
                              items: availableYears
                                  .map(
                                    (year) => DropdownMenuItem(
                                      value: year,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(year.toString()),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Periode:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isLoadingPeriods
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              : DropdownButtonHideUnderline(
                                  child:
                                      DropdownButton<_ReimbursementWorkPeriod>(
                                        value: _selectedWorkPeriod,
                                        hint: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text('Belum ada periode HRD'),
                                        ),
                                        onChanged: _workPeriods.isEmpty
                                            ? null
                                            : (period) {
                                                if (period == null) return;

                                                setState(
                                                  () => _selectedWorkPeriod =
                                                      period,
                                                );
                                                _applyClientSideFilter();
                                              },
                                        items: _workPeriods
                                            .map(
                                              (period) => DropdownMenuItem(
                                                value: period,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  child: Text(
                                                    period.displayLabel,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        icon: const Icon(Icons.arrow_drop_down),
                                        isExpanded: true,
                                      ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedWorkPeriod != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rentang periode: '
                              '${_getPeriodRangeText(_selectedWorkPeriod!)}'
                              '${_selectedWorkPeriod!.keterangan.trim().isEmpty ? '' : '\n${_selectedWorkPeriod!.keterangan.trim()}'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1D4ED8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!_isLoadingPeriods) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'HRD belum menetapkan periode kerja untuk tahun ini. '
                        'Data tetap ditampilkan tanpa filter periode.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _resetFilter(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Periode Berjalan',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _selectedWorkPeriod == null
                              ? null
                              : _applyFilter,
                          icon: const Icon(Icons.filter_alt_rounded, size: 18),
                          label: const Text(
                            'Terapkan Periode',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReimbursementCard(ReimbursementData item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
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
                      // Pakai statusLabel agar tampil "Menunggu HRD" / "Menunggu Finance"
                      item.statusLabel,
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
              Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.formattedDate,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.attach_money_outlined,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.formattedAmount,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Belum Ada Data Reimbursement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mulai dengan membuat reimbursement baru',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReimbursementWorkPeriod {
  final int id;
  final int tahun;
  final int bulan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String keterangan;

  const _ReimbursementWorkPeriod({
    required this.id,
    required this.tahun,
    required this.bulan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.keterangan,
  });

  factory _ReimbursementWorkPeriod.fromJson(Map<String, dynamic> json) {
    int readInt(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime readDate(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;

        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) {
          return DateTime(parsed.year, parsed.month, parsed.day);
        }
      }

      return DateTime.now();
    }

    return _ReimbursementWorkPeriod(
      id: readInt('id', 'Id'),
      tahun: readInt('tahun', 'Tahun'),
      bulan: readInt('bulan', 'Bulan'),
      tanggalMulai: readDate(const [
        'tanggalMulai',
        'TanggalMulai',
        'tanggal_mulai',
      ]),
      tanggalSelesai: readDate(const [
        'tanggalSelesai',
        'TanggalSelesai',
        'tanggal_selesai',
      ]),
      keterangan: (json['keterangan'] ?? json['Keterangan'] ?? '').toString(),
    );
  }

  String get displayLabel {
    const monthNames = [
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

    final defaultLabel = bulan >= 1 && bulan <= 12
        ? 'Periode ${monthNames[bulan]} $tahun'
        : 'Periode Kerja';

    final note = keterangan.trim();
    return note.isEmpty ? defaultLabel : note;
  }
}
