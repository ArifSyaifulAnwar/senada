// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20User/fitur/ajukanreimbursement.dart';
import 'package:absensikaryawan/Services/detailmodalcontent.dart';
import 'package:absensikaryawan/Services/reimbursementmodel.dart';
import 'package:absensikaryawan/Services/reimbursementservice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HalamanReimbursement extends StatefulWidget {
  const HalamanReimbursement({super.key});

  @override
  _HalamanReimbursementState createState() => _HalamanReimbursementState();
}

class _HalamanReimbursementState extends State<HalamanReimbursement> {
  final ReimbursementService _reimbursementService = ReimbursementService();

  List<ReimbursementData> _allReimbursements = []; // Semua data dari API
  List<ReimbursementData> _filteredReimbursements =
      []; // Data yang sudah difilter
  bool _isLoading = true;
  String? _currentUserId;
  String? _selectedStatus;

  // Filter variables
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isFilterExpanded = false;

  // final List<String> _statusOptions = [
  //   'Semua',
  //   'Draft',
  //   'Menunggu',
  //   'Disetujui',
  //   'Ditolak',
  //   'Dibayar',
  // ];

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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('UserID');
    if (_currentUserId != null) {
      await _loadReimbursements();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReimbursements() async {
    if (_currentUserId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? statusFilter;
      if (_selectedStatus != null && _selectedStatus != 'Semua') {
        statusFilter = _mapStatusToApi(_selectedStatus!);
      }

      // Ambil semua data tanpa filter periode (filter dilakukan di client)
      final data = await _reimbursementService.getReimbursementList(
        userId: _currentUserId!,
        status: statusFilter,
      );

      if (data.isNotEmpty) {}
      setState(() {
        _allReimbursements = data;
        _applyClientSideFilter(); // Terapkan filter di client
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Gagal memuat data reimbursement: $e');
    }
  }

  void _applyClientSideFilter() {
    List<ReimbursementData> filtered = _allReimbursements;

    // Filter berdasarkan tahun
    filtered = filtered.where((reimbursement) {
      return reimbursement.submittedAt.year == _selectedYear;
    }).toList();

    // Filter berdasarkan bulan (jika bukan "Semua Bulan")
    if (_selectedMonth != 0) {
      filtered = filtered.where((reimbursement) {
        return reimbursement.submittedAt.month == _selectedMonth;
      }).toList();
    }

    // Urutkan berdasarkan tanggal terbaru
    filtered.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    setState(() {
      _filteredReimbursements = filtered;
      _isLoading = false;
    });
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
    final years = _allReimbursements
        .map((reimbursement) => reimbursement.submittedAt.year)
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

  // Map<String, int> _getSummary() {
  //   int draft = _filteredReimbursements
  //       .where((e) => e.status.toLowerCase() == "draft")
  //       .length;
  //   int pending = _filteredReimbursements
  //       .where((e) => e.status.toLowerCase() == "pending")
  //       .length;
  //   int approved = _filteredReimbursements
  //       .where((e) => e.status.toLowerCase() == "approved")
  //       .length;
  //   int rejected = _filteredReimbursements
  //       .where((e) => e.status.toLowerCase() == "rejected")
  //       .length;
  //   int paid = _filteredReimbursements
  //       .where((e) => e.status.toLowerCase() == "paid")
  //       .length;

  //   return {
  //     'Draft': draft,
  //     'Menunggu': pending,
  //     'Disetujui': approved,
  //     'Ditolak': rejected,
  //     'Dibayar': paid,
  //   };
  // }

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
      builder: (context) {
        return DetailModalContent(
          initialItem: item,
          reimbursementService: _reimbursementService,
          currentUserId: _currentUserId,
          getResponsiveFontSize: (context, size) => size,
          getResponsivePadding: (context, padding) => padding,
          formatDateTime: _formatDateTime,
          buildDetailRow: _buildDetailRow,
        );
      },
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToRequestPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HalamanAjukanReimbursement(),
      ),
    );

    // Refresh data jika ada perubahan
    if (result == true) {
      _loadReimbursements();
    }
  }

  @override
  Widget build(BuildContext context) {
    //final Map<String, int> count = _getSummary();

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
                    // Summary Cards
                    //_buildSummaryCards(count),
                    //const SizedBox(height: 24),

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
                          "Riwayat Reimbursement",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${_filteredReimbursements.length} data",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Status Filter Dropdown
                    //_buildStatusFilter(),
                    const SizedBox(height: 16),

                    // Content
                    if (_filteredReimbursements.isEmpty)
                      _buildEmptyState()
                    else
                      ..._filteredReimbursements.map(
                        (reimbursement) =>
                            _buildReimbursementCard(reimbursement),
                      ),

                    // Extra space for FAB
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

  // Widget _buildSummaryCards(Map<String, int> count) {
  //   return Container(
  //     padding: const EdgeInsets.all(24),
  //     decoration: BoxDecoration(
  //       gradient: const LinearGradient(
  //         colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //       ),
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: [
  //         BoxShadow(
  //           color: const Color(0xFF3B82F6).withOpacity(0.3),
  //           blurRadius: 20,
  //           offset: const Offset(0, 8),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: Colors.white.withOpacity(0.2),
  //                 borderRadius: BorderRadius.circular(16),
  //               ),
  //               child: const Icon(
  //                 Icons.access_time_filled_rounded,
  //                 size: 28,
  //                 color: Colors.white,
  //               ),
  //             ),
  //             const SizedBox(width: 16),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "Ringkasan Reimbursement",
  //                     style: TextStyle(
  //                       fontSize: 20,
  //                       fontWeight: FontWeight.w700,
  //                       color: Colors.white,
  //                       letterSpacing: -0.3,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Text(
  //                     _getFilterDisplayText(),
  //                     style: const TextStyle(
  //                       fontSize: 14,
  //                       color: Colors.white70,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),

  //         const SizedBox(height: 24),

  //         Row(
  //           children: [
  //             Expanded(
  //               child: _buildSummaryItem(
  //                 icon: Icons.drafts,
  //                 color: const Color(0xFF3B82F6),
  //                 count: count['Draft']!,
  //                 label: "Draft",
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: _buildSummaryItem(
  //                 icon: Icons.schedule,
  //                 color: const Color(0xFFF59E0B),
  //                 count: count['Menunggu']!,
  //                 label: "Menunggu",
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: _buildSummaryItem(
  //                 icon: Icons.check_circle,
  //                 color: const Color(0xFF10B981),
  //                 count: count['Disetujui']!,
  //                 label: "Disetujui",
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: _buildSummaryItem(
  //                 icon: Icons.cancel,
  //                 color: const Color(0xFFEF4444),
  //                 count: count['Ditolak']!,
  //                 label: "Ditolak",
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: _buildSummaryItem(
  //                 icon: Icons.attach_money,
  //                 color: const Color(0xFF3B82F6),
  //                 count: count['Dibayar']!,
  //                 label: "Dibayar",
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildSummaryItem({
  //   required IconData icon,
  //   required Color color,
  //   required int count,
  //   required String label,
  // }) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withOpacity(0.15),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
  //     ),
  //     child: Column(
  //       children: [
  //         Icon(icon, color: color, size: 24),
  //         const SizedBox(height: 8),
  //         Text(
  //           count.toString(),
  //           style: const TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.w700,
  //             color: Colors.white,
  //           ),
  //         ),
  //         const SizedBox(height: 4),
  //         Text(
  //           label,
  //           style: const TextStyle(
  //             fontSize: 12,
  //             color: Colors.white70,
  //             fontWeight: FontWeight.w500,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
                      item.statusText,
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
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Data Reimbursement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mulai dengan membuat reimbursement baru',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
