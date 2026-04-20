// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/Screen%20User/home/overtimeformscreen.dart';
import 'package:absensikaryawan/Services/overtimeservice.dart';
import 'package:flutter/material.dart';

class OvertimeScreen extends StatefulWidget {
  const OvertimeScreen({super.key});

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  final OvertimeService _overtimeService = OvertimeService();

  List<Overtime> _allOvertimeList = []; // Semua data dari API
  List<Overtime> _filteredOvertimeList = []; // Data yang sudah difilter
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();

  // Filter variables
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isFilterExpanded = false;

  // Month names
  final List<String> _monthNames = [
    'Semua Bulan',
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

  @override
  void initState() {
    super.initState();
    _loadOvertimeData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOvertimeData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Ambil semua data dari API tanpa filter
      final response = await _overtimeService.getMyOvertime(
        page: 1,
        pageSize: 100, // Ambil lebih banyak data sekaligus
      );

      if (response.success && response.data != null) {
        if (mounted) {
          setState(() {
            _allOvertimeList = response.data!.data;
            _applyClientSideFilter(); // Terapkan filter di client
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = response.message;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Terjadi kesalahan: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyClientSideFilter() {
    List<Overtime> filtered = _allOvertimeList;

    // Filter berdasarkan tahun
    filtered = filtered.where((overtime) {
      return overtime.tanggalOvertime.year == _selectedYear;
    }).toList();

    // Filter berdasarkan bulan (jika bukan "Semua Bulan")
    if (_selectedMonth != 0) {
      filtered = filtered.where((overtime) {
        return overtime.tanggalOvertime.month == _selectedMonth;
      }).toList();
    }

    // Urutkan berdasarkan tanggal terbaru
    filtered.sort((a, b) => b.tanggalOvertime.compareTo(a.tanggalOvertime));

    setState(() {
      _filteredOvertimeList = filtered;
    });
  }

  Future<void> _refreshData() async {
    await _loadOvertimeData();
  }

  void _applyFilter() {
    setState(() {
      _isFilterExpanded = false;
    });
    _applyClientSideFilter();
  }

  void _resetFilter() {
    setState(() {
      _selectedYear = DateTime.now().year;
      _selectedMonth = DateTime.now().month;
      _isFilterExpanded = false;
    });
    _applyClientSideFilter();
  }

  String _getFilterDisplayText() {
    final monthName = _selectedMonth == 0
        ? 'Semua'
        : _monthNames[_selectedMonth];
    return '$monthName $_selectedYear';
  }

  // Mendapatkan tahun yang tersedia dari data
  List<int> _getAvailableYears() {
    final years = _allOvertimeList
        .map((overtime) => overtime.tanggalOvertime.year)
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a)); // Urutkan dari terbaru

    // Jika tidak ada data, gunakan 5 tahun terakhir
    if (years.isEmpty) {
      final currentYear = DateTime.now().year;
      return List.generate(5, (index) => currentYear - 2 + index);
    }

    return years;
  }

  Color _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return const Color(0xFF10B981);
      case "rejected":
        return const Color(0xFFEF4444);
      case "pending":
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _iconForStatus(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Icons.check_circle_rounded;
      case "rejected":
        return Icons.cancel_rounded;
      case "pending":
      default:
        return Icons.schedule_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return "Disetujui";
      case "rejected":
        return "Ditolak";
      case "pending":
      default:
        return "Menunggu";
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
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
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showDeleteDialog(Overtime overtime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Konfirmasi Hapus',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin menghapus pengajuan lembur ini?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 ${overtime.formattedDate}'),
                  const SizedBox(height: 4),
                  Text(
                    '⏰ ${overtime.formattedMulai} - ${overtime.formattedSelesai}',
                  ),
                  const SizedBox(height: 4),
                  Text('⏱️ ${overtime.totalJam.toStringAsFixed(1)} jam'),
                  if (overtime.catatan != null &&
                      overtime.catatan!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('📝 ${overtime.catatan}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data yang dihapus tidak dapat dikembalikan.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOvertime(overtime.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOvertime(int id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _overtimeService.deleteOvertime(id);
      Navigator.pop(context);

      _showSnackBar(response.message, isError: !response.success);

      if (response.success) {
        _refreshData();
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Gagal menghapus: $e', isError: true);
    }
  }

  void _navigateToFormSubmit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OvertimeFormScreen()),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  void _navigateToEdit(Overtime overtime) {
    if (!overtime.canBeModified) {
      _showSnackBar(
        'Data lembur yang sudah diproses tidak dapat diedit',
        isError: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OvertimeFormScreen(overtime: overtime),
      ),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    //final Map<String, int> count = _getSummary();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Lembur',
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
              onPressed: _refreshData,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              // _buildSummaryCards(count),

              // const SizedBox(height: 24),

              // Filter Section
              _buildFilterSection(),

              const SizedBox(height: 24),

              // Section Header
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
                    "Riwayat Lembur",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${_filteredOvertimeList.length} data",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Content
              if (_isLoading)
                _buildLoadingState()
              else if (_hasError && _allOvertimeList.isEmpty)
                _buildErrorState()
              else if (_filteredOvertimeList.isEmpty)
                _buildEmptyState()
              else
                ..._filteredOvertimeList.map(
                  (overtime) => _buildOvertimeCard(overtime),
                ),
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
          onPressed: _navigateToFormSubmit,
          label: const Text(
            'Ajukan Lembur',
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
    final availableYears = _getAvailableYears();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
          // Filter Header
          InkWell(
            onTap: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
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
                      Icons.filter_list_rounded,
                      size: 20,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter Periode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  Container(
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
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

          // Filter Content
          if (_isFilterExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Year Selector
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today, // Ganti dengan icon yang tersedia
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
                              value: availableYears.contains(_selectedYear)
                                  ? _selectedYear
                                  : (availableYears.isNotEmpty
                                        ? availableYears.first
                                        : DateTime.now().year),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value!;
                                });
                              },
                              items: availableYears.map((year) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(year.toString()),
                                  ),
                                );
                              }).toList(),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Month Selector
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Bulan:',
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
                              value: _selectedMonth,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value!;
                                });
                              },
                              items: List.generate(_monthNames.length, (index) {
                                return DropdownMenuItem(
                                  value: index,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(_monthNames[index]),
                                  ),
                                );
                              }),
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetFilter,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Reset',
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
                          onPressed: _applyFilter,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text(
                            'Terapkan Filter',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
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

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Terjadi Kesalahan",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              "Coba Lagi",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.access_time_outlined,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Tidak ada data Lembur",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tidak ada data Lembur untuk periode ${_getFilterDisplayText()}.\nCoba ubah filter periode atau buat pengajuan baru.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToFormSubmit,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              "Ajukan Lembur",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeCard(Overtime overtime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _colorForStatus(overtime.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text("⏰", style: TextStyle(fontSize: 20)),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              overtime.formattedDate,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF1F2937),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _colorForStatus(
                                overtime.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _colorForStatus(
                                  overtime.status,
                                ).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _iconForStatus(overtime.status),
                                  size: 14,
                                  color: _colorForStatus(overtime.status),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getStatusText(overtime.status),
                                  style: TextStyle(
                                    color: _colorForStatus(overtime.status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Time Range
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${overtime.formattedMulai} - ${overtime.formattedSelesai}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${overtime.totalJam.toStringAsFixed(1)} jam",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Menu for Pending Status
                if (overtime.canBeModified) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToEdit(overtime);
                      } else if (value == 'delete') {
                        _showDeleteDialog(overtime);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: Color(0xFF3B82F6),
                            ),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Hapus',
                              style: TextStyle(color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Catatan
            if (overtime.catatan != null && overtime.catatan!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.note_alt_rounded,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Catatan",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overtime.catatan!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Rejection Reason
            if (overtime.rejectionReason != null &&
                overtime.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_rounded,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Alasan Ditolak",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overtime.rejectionReason!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFEF4444),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
