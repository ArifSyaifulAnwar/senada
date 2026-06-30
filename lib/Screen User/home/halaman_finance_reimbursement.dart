// lib/Screen finance/halaman_finance_reimbursement.dart
//
// Tampilan Head Finance untuk mereview dan membayar reimbursement.
// Struktur UI dibuat searah dengan Time Off HRD:
// - Desktop: sidebar + konten dengan IndexedStack
// - Mobile: TabBar
// - Dashboard, daftar pengajuan, dan pembayaran dipisahkan jelas.

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:absensikaryawan/Screen%20admin/service/web_preview.dart';
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Services/finance_reimbursement_service.dart';
import '../../Services/reimbursementservice.dart' show ReimbursementAttachmentMeta;
import '../../Services/time_off_model.dart' show WorkPeriodModel;
import '../../Services/time_off_service.dart';
import '../../models/finance_reimbursement_model.dart';

bool _isWebLayout(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class HalamanFinanceReimbursement extends StatefulWidget {
  const HalamanFinanceReimbursement({super.key});

  @override
  State<HalamanFinanceReimbursement> createState() =>
      _HalamanFinanceReimbursementState();
}

class _HalamanFinanceReimbursementState
    extends State<HalamanFinanceReimbursement>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF6366F1);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);

  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  String? _currentUserId;
  String? _currentUserName;

  bool _isLoading = true;
  String? _loadError;

  int _webTabIndex = 0;
  String? _selectedStatus;

  List<WorkPeriodModel> _workPeriods = [];
  WorkPeriodModel? _selectedPeriod;
  bool _isLoadingPeriods = false;

  /// Mencegah user menekan Preview / Download berulang kali pada lampiran.
  bool _isAttachmentProcessing = false;
  bool _isPaymentProcessing = false;

  List<FinanceReimbursementItem> _allItems = const [];
  List<FinanceReimbursementItem> _filteredItems = const [];

  final List<_StatusFilter> _statusOptions = const [
    _StatusFilter(null, 'Semua'),
    _StatusFilter('pending_finance', 'Menunggu Review'),
    _StatusFilter('approved', 'Disetujui'),
    _StatusFilter('rejected', 'Ditolak'),
    _StatusFilter('paid', 'Dibayar'),
  ];

  int get _totalCount => _allItems.length;
  int get _pendingCount =>
      _allItems.where((item) => item.isPendingFinance).length;
  int get _approvedCount => _allItems.where((item) => item.isApproved).length;
  int get _rejectedCount => _allItems.where((item) => item.isRejected).length;
  int get _paidCount => _allItems.where((item) => item.isPaid).length;

  double get _pendingAmount => _sumWhere((item) => item.isPendingFinance);
  double get _approvedAmount => _sumWhere((item) => item.isApproved);
  double get _paidAmount => _sumWhere((item) => item.isPaid);
  double get _rejectedAmount => _sumWhere((item) => item.isRejected);

  double _sumWhere(bool Function(FinanceReimbursementItem item) test) =>
      _allItems
          .where(test)
          .fold<double>(0, (total, item) => total + item.amount);

  List<FinanceReimbursementItem> get _urgentItems =>
      _allItems.where((item) => item.isUrgent).toList()
        ..sort((a, b) => b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted));

  List<FinanceReimbursementItem> get _paymentItems {
    final keyword = _searchController.text.trim().toLowerCase();

    final result = _allItems.where((item) {
      if (!item.isApproved && !item.isPaid) return false;
      return _matchesKeyword(item, keyword);
    }).toList();

    result.sort((a, b) {
      if (a.isApproved && !b.isApproved) return -1;
      if (!a.isApproved && b.isApproved) return 1;
      return b.submittedAt.compareTo(a.submittedAt);
    });

    return result;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _searchController.addListener(_applyFilters);
    _loadUserAndData();
    _loadWorkPeriods();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _searchController
      ..removeListener(_applyFilters)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      setState(() => _webTabIndex = _tabController.index);
    }
  }

  Future<void> _loadUserAndData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _currentUserId = preferences.getString('UserID');
      _currentUserName = preferences.getString('Name');

      if (_currentUserId == null || _currentUserId!.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loadError = 'Data user tidak ditemukan. Silakan login ulang.';
        });
        return;
      }

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Gagal memuat data user: $e';
      });
    }
  }

  Future<void> _loadWorkPeriods() async {
    if (!mounted) return;
    setState(() => _isLoadingPeriods = true);
    try {
      final res = await TimeOffService.getWorkPeriods();
      if (mounted && res.success && res.data != null) {
        final today = DateTime.now();
        final todayNorm = DateTime(today.year, today.month, today.day);
        WorkPeriodModel? active;
        for (final p in res.data!) {
          final start = DateTime(
            p.tanggalMulai.year,
            p.tanggalMulai.month,
            p.tanggalMulai.day,
          );
          final end = DateTime(
            p.tanggalSelesai.year,
            p.tanggalSelesai.month,
            p.tanggalSelesai.day,
          );
          if (!todayNorm.isBefore(start) && !todayNorm.isAfter(end)) {
            active = p;
            break;
          }
        }
        setState(() {
          _workPeriods = res.data!;
          _selectedPeriod = active;
          _isLoadingPeriods = false;
        });
        _applyFilters();
      } else {
        if (mounted) setState(() => _isLoadingPeriods = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPeriods = false);
    }
  }

  Future<void> _loadData({bool showSuccessMessage = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final items = await FinanceReimbursementService.getList();

      if (!mounted) return;
      setState(() {
        _allItems = items;
        _filteredItems = _filterItems(items);
        _isLoading = false;
      });

      if (showSuccessMessage) {
        _showSuccess('Data reimbursement berhasil diperbarui.');
      }
    } on FinanceServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Gagal memuat data reimbursement: $e';
      });
    }
  }

  Future<void> _refreshData() => _loadData(showSuccessMessage: true);

  void _applyFilters() {
    if (!mounted) return;
    setState(() => _filteredItems = _filterItems(_allItems));
  }

  void _showFinanceReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FinanceReimbursementReportModal(
        allItems: _allItems,
        workPeriods: _workPeriods,
        currentUserId: _currentUserId ?? '',
        currentUserName: _currentUserName ?? '',
      ),
    );
  }

  List<FinanceReimbursementItem> _filterItems(
    List<FinanceReimbursementItem> source,
  ) {
    final keyword = _searchController.text.trim().toLowerCase();

    DateTime? periodStart;
    DateTime? periodEnd;
    if (_selectedPeriod != null) {
      periodStart = DateTime(
        _selectedPeriod!.tanggalMulai.year,
        _selectedPeriod!.tanggalMulai.month,
        _selectedPeriod!.tanggalMulai.day,
      );
      periodEnd = DateTime(
        _selectedPeriod!.tanggalSelesai.year,
        _selectedPeriod!.tanggalSelesai.month,
        _selectedPeriod!.tanggalSelesai.day,
      );
    }

    final result = source.where((item) {
      final matchesStatus =
          _selectedStatus == null || item.normalizedStatus == _selectedStatus;

      bool matchesPeriod = true;
      if (periodStart != null && periodEnd != null) {
        final d = DateTime(
          item.submittedAt.year,
          item.submittedAt.month,
          item.submittedAt.day,
        );
        matchesPeriod = !d.isBefore(periodStart) && !d.isAfter(periodEnd);
      }

      return matchesStatus && matchesPeriod && _matchesKeyword(item, keyword);
    }).toList();

    result.sort((a, b) {
      final priorityA = _sortPriority(a);
      final priorityB = _sortPriority(b);

      if (priorityA != priorityB) return priorityA.compareTo(priorityB);

      if (a.isPendingFinance && b.isPendingFinance) {
        return b.daysSinceSubmitted.compareTo(a.daysSinceSubmitted);
      }

      return b.submittedAt.compareTo(a.submittedAt);
    });

    return result;
  }

  bool _matchesKeyword(FinanceReimbursementItem item, String keyword) {
    if (keyword.isEmpty) return true;

    return item.title.toLowerCase().contains(keyword) ||
        item.userName.toLowerCase().contains(keyword) ||
        (item.userJob?.toLowerCase().contains(keyword) ?? false) ||
        item.category.toLowerCase().contains(keyword) ||
        (item.description?.toLowerCase().contains(keyword) ?? false);
  }

  int _sortPriority(FinanceReimbursementItem item) {
    if (item.isPendingFinance) return 0;
    if (item.isApproved) return 1;
    if (item.isPaid) return 2;
    if (item.isRejected) return 3;
    return 4;
  }

  void _navigateToTab(int index, {String? status}) {
    setState(() {
      _webTabIndex = index;
      _selectedStatus = status;
      _filteredItems = _filterItems(_allItems);
    });
    _tabController.animateTo(index);
  }

  Future<void> _reviewWithNotes(
    FinanceReimbursementItem item,
    String status,
  ) async {
    if (_currentUserId == null || _currentUserId!.trim().isEmpty) {
      _showError('Data user Finance tidak ditemukan. Silakan login ulang.');
      return;
    }

    final notesController = TextEditingController();
    final isApprove = status == 'approved';

    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isApprove ? _success : _danger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isApprove ? 'Setujui Reimbursement' : 'Tolak Reimbursement',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogItemSummary(item),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: isApprove
                      ? 'Catatan Finance (opsional)'
                      : 'Alasan penolakan (wajib)',
                  hintText: isApprove
                      ? 'Tambahkan catatan bila diperlukan'
                      : 'Tulis alasan penolakan dengan jelas',
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (!isApprove && notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan penolakan wajib diisi.'),
                    backgroundColor: _danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            icon: Icon(isApprove ? Icons.check : Icons.close, size: 18),
            label: Text(isApprove ? 'Setujui' : 'Tolak'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? _success : _danger,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (isConfirmed != true) {
      notesController.dispose();
      return;
    }

    final result = await FinanceReimbursementService.review(
      reimbursementId: item.id,
      status: status,
      financeUserId: _currentUserId!,
      reviewNotes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );
    notesController.dispose();

    if (!mounted) return;

    if (result.success) {
      _showSuccess(
        isApprove
            ? 'Reimbursement berhasil disetujui Finance.'
            : 'Reimbursement berhasil ditolak.',
      );
      await _loadData();
    } else {
      _showError(
        result.message.isEmpty
            ? 'Aksi review gagal dilakukan.'
            : result.message,
      );
    }
  }

  Future<void> _markPaid(FinanceReimbursementItem item) async {
    if (_isPaymentProcessing) return;
    if (_currentUserId == null || _currentUserId!.trim().isEmpty) {
      _showError('Data user Finance tidak ditemukan. Silakan login ulang.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      withData: true,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    Uint8List? fileBytes = file.bytes;
    if (fileBytes == null && !kIsWeb && file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    }
    if (fileBytes == null || fileBytes.isEmpty) {
      _showError('File bukti transfer tidak dapat dibaca.');
      return;
    }
    final proofBytes = fileBytes;
    const maxSize = 10 * 1024 * 1024;
    if (proofBytes.length > maxSize) {
      _showError('Ukuran file maksimal 10 MB.');
      return;
    }

    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upload_file_rounded, color: _primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upload Bukti Transfer',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogItemSummary(item),
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(color: _info.withOpacity(0.28)),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Icon(
                      _attachmentIcon(_extensionOf(file.name)),
                      color: _info,
                      size: 22,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatFileSize(proofBytes.length),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Catatan transfer (opsional)',
                  hintText: 'Contoh: Transfer BCA 1234567890',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Setelah dikirim, status berubah menjadi Selesai dan bukti dapat dilihat oleh pengaju serta Head HRD.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Upload & Selesaikan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    final notes = notesController.text.trim();
    notesController.dispose();
    if (confirmed != true) return;

    setState(() => _isPaymentProcessing = true);
    _showInfo('Mengunggah bukti transfer dan menyelesaikan reimbursement...');
    try {
      final result = await FinanceReimbursementService.completePayment(
        reimbursementId: item.id,
        financeUserId: _currentUserId!,
        paymentProofBytes: proofBytes,
        paymentProofFileName: file.name,
        paymentProofContentType: _mimeTypeFromFileName(file.name),
        paymentNotes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      if (result.success) {
        _showSuccess('Bukti transfer tersimpan. Reimbursement selesai.');
        await _loadData();
      } else {
        _showError(
          result.message.isEmpty
              ? 'Gagal menyimpan bukti transfer.'
              : result.message,
        );
      }
    } catch (e) {
      if (mounted) _showError('Gagal mengunggah bukti transfer: $e');
    } finally {
      if (mounted) setState(() => _isPaymentProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isWeb),
      body: _isLoading
          ? _buildLoadingState()
          : _loadError != null
          ? _buildErrorState()
          : isWeb
          ? _buildWebLayout()
          : _buildMobileLayout(),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isWeb) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: !isWeb,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 20,
              color: _primary,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Manajemen Reimbursement',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
                fontSize: isWeb ? 20 : 17,
              ),
            ),
          ),
        ],
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 19),
            ),
          ),
        ),
      ],
      bottom: isWeb
          ? null
          : TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _primary,
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: _primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard_rounded, size: 18),
                  text: 'Dashboard',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long_rounded, size: 18),
                  text: 'Pengajuan',
                ),
                Tab(
                  icon: Icon(Icons.payments_rounded, size: 18),
                  text: 'Pembayaran',
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 16),
          Text(
            'Memuat data Finance...',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 42,
                  color: _danger,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Data belum dapat dimuat',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError ?? 'Terjadi kesalahan yang tidak diketahui.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadUserAndData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDashboardTab(),
        _buildRequestsTab(),
        _buildPaymentsTab(),
      ],
    );
  }

  Widget _buildWebLayout() {
    const tabs = [
      _FinanceTab(Icons.dashboard_rounded, 'Dashboard', 0),
      _FinanceTab(Icons.receipt_long_rounded, 'Pengajuan', 1),
      _FinanceTab(Icons.payments_rounded, 'Pembayaran', 2),
    ];

    return Row(
      children: [
        Container(
          width: 220,
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
                  onTap: () => _navigateToTab(tab.index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _primary.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: _primary.withOpacity(0.20))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 17,
                          color: selected ? _primary : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? _primary
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSidebarUser(),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _webTabIndex,
            children: [
              _buildDashboardTab(),
              _buildRequestsTab(),
              _buildPaymentsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarUser() {
    final name = _currentUserName?.trim().isNotEmpty == true
        ? _currentUserName!.trim()
        : 'Finance';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _primary.withOpacity(0.12),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Text(
                  'Finance Department',
                  style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStatsSummary() {
    final stats = [
      _SideStat('Total', _totalCount, _info),
      _SideStat('Review', _pendingCount, _warning),
      _SideStat('Disetujui', _approvedCount, _success),
      _SideStat('Dibayar', _paidCount, _primary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik Finance',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 9),
        ...stats.map(
          (stat) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: stat.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: stat.color.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: stat.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stat.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                Text(
                  '${stat.value}',
                  style: TextStyle(
                    color: stat.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _buildWelcomeBanner(),
          const SizedBox(height: 24),
          _buildFinanceStatistics(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              final children = [
                Expanded(child: _buildAmountOverview()),
                const SizedBox(width: 20),
                Expanded(child: _buildPaymentOverview()),
              ];

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    )
                  : Column(
                      children: [
                        _buildAmountOverview(),
                        const SizedBox(height: 20),
                        _buildPaymentOverview(),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              final children = [
                Expanded(child: _buildUrgentItems()),
                const SizedBox(width: 20),
                Expanded(child: _buildQuickActions()),
              ];

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    )
                  : Column(
                      children: [
                        _buildUrgentItems(),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    final name = _currentUserName?.trim().isNotEmpty == true
        ? _currentUserName!.trim()
        : 'Finance Manager';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.28),
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
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Finance Department',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
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
              color: Colors.white.withOpacity(0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildQuickStat(
                  'Masuk',
                  '$_totalCount',
                  Icons.receipt_long_rounded,
                ),
                _divider(),
                _buildQuickStat(
                  'Review',
                  '$_pendingCount',
                  Icons.pending_actions_rounded,
                ),
                _divider(),
                _buildQuickStat(
                  'Dibayar',
                  '$_paidCount',
                  Icons.payments_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 36,
    color: Colors.white24,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Statistik Reimbursement',
              style: TextStyle(
                fontSize: 17,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              onPressed: _showFinanceReport,
              icon: const Icon(Icons.assessment, size: 16),
              label: const Text('Lihat Laporan'),
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth >= 850 ? 4 : 2;
            return GridView.count(
              crossAxisCount: count,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: constraints.maxWidth >= 650 ? 1.55 : 1.30,
              children: [
                _buildStatCard(
                  title: 'Total Masuk',
                  value: '$_totalCount',
                  icon: Icons.receipt_long_rounded,
                  color: _primary,
                  onTap: () => _navigateToTab(1),
                ),
                _buildStatCard(
                  title: 'Menunggu Review',
                  value: '$_pendingCount',
                  icon: Icons.pending_actions_rounded,
                  color: _warning,
                  urgent: _pendingCount > 0,
                  onTap: () => _navigateToTab(1, status: 'pending_finance'),
                ),
                _buildStatCard(
                  title: 'Disetujui',
                  value: '$_approvedCount',
                  icon: Icons.check_circle_rounded,
                  color: _success,
                  onTap: () => _navigateToTab(1, status: 'approved'),
                ),
                _buildStatCard(
                  title:
                      int.tryParse('$_paidCount') != null &&
                          int.parse('$_paidCount') > 0
                      ? 'Pembayaran Selesai'
                      : 'Dibayar',
                  value: '$_paidCount',
                  icon: Icons.payments_rounded,
                  color: _info,
                  onTap: () => _navigateToTab(2),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
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
            color: urgent ? color.withOpacity(0.55) : const Color(0xFFE5E7EB),
            width: urgent ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w800,
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountOverview() {
    return _sectionCard(
      title: 'Nilai Reimbursement',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        children: [
          _moneyRow(
            label: 'Menunggu Review',
            value: _pendingAmount,
            color: _warning,
            icon: Icons.pending_actions_rounded,
          ),
          const SizedBox(height: 10),
          _moneyRow(
            label: 'Siap Dibayarkan',
            value: _approvedAmount,
            color: _success,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: 10),
          _moneyRow(
            label: 'Sudah Dibayar',
            value: _paidAmount,
            color: _info,
            icon: Icons.payments_rounded,
          ),
          if (_rejectedAmount > 0) ...[
            const SizedBox(height: 10),
            _moneyRow(
              label: 'Ditolak',
              value: _rejectedAmount,
              color: _danger,
              icon: Icons.cancel_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _moneyRow({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.045),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.13)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _currency(value),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOverview() {
    final latestPaid = _allItems.where((item) => item.isPaid).toList()
      ..sort((a, b) {
        final dateA = a.paidAt ?? a.submittedAt;
        final dateB = b.paidAt ?? b.submittedAt;
        return dateB.compareTo(dateA);
      });

    return _sectionCard(
      title: 'Pembayaran Terbaru',
      icon: Icons.payments_rounded,
      trailing: TextButton(
        onPressed: () => _navigateToTab(2),
        child: const Text('Lihat Semua'),
      ),
      child: latestPaid.isEmpty
          ? _emptyInline(
              icon: Icons.payments_outlined,
              message: 'Belum ada reimbursement yang dibayar.',
            )
          : Column(
              children: latestPaid
                  .take(4)
                  .map((item) => _compactPaymentRow(item))
                  .toList(),
            ),
    );
  }

  Widget _compactPaymentRow(FinanceReimbursementItem item) {
    return InkWell(
      onTap: () => _showDetail(item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: _info.withOpacity(0.12),
              child: Text(
                item.initials,
                style: const TextStyle(
                  color: _info,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.userName.isEmpty ? 'Karyawan' : item.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currency(item.amount),
              style: const TextStyle(
                color: _info,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentItems() {
    final urgent = _urgentItems.take(3).toList();

    return _sectionCard(
      title: 'Pengajuan Urgent',
      icon: Icons.warning_amber_rounded,
      iconColor: _danger,
      trailing: TextButton(
        onPressed: () => _navigateToTab(1, status: 'pending_finance'),
        child: const Text('Lihat Semua'),
      ),
      child: urgent.isEmpty
          ? _emptyInline(
              icon: Icons.check_circle_rounded,
              iconColor: _success,
              message: 'Tidak ada pengajuan yang perlu diprioritaskan.',
            )
          : Column(
              children: urgent
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildReimbursementCard(item, compact: true),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildQuickActions() {
    return _sectionCard(
      title: 'Aksi Cepat Finance',
      icon: Icons.bolt_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 340 ? 2 : 1;

          return GridView.count(
            crossAxisCount: count,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: count == 2 ? 2.45 : 3.35,
            children: [
              _quickAction(
                title: 'Review Pending',
                subtitle: '$_pendingCount pengajuan',
                icon: Icons.pending_actions_rounded,
                color: _warning,
                onTap: () => _navigateToTab(1, status: 'pending_finance'),
              ),
              _quickAction(
                title: 'Proses Bayar',
                subtitle: '$_approvedCount siap bayar',
                icon: Icons.payments_rounded,
                color: _success,
                onTap: () => _navigateToTab(2),
              ),
              _quickAction(
                title: 'Pengajuan Ditolak',
                subtitle: '$_rejectedCount pengajuan',
                icon: Icons.cancel_rounded,
                color: _danger,
                onTap: () => _navigateToTab(1, status: 'rejected'),
              ),
              _quickAction(
                title: 'Perbarui Data',
                subtitle: 'Sinkronkan data terbaru',
                icon: Icons.refresh_rounded,
                color: _primary,
                onTap: _refreshData,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.045),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.16)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return Column(
      children: [
        _buildFilterPanel(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          color: const Color(0xFFF8FAFC),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Daftar Pengajuan',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_filteredItems.length} data',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredItems.isEmpty
              ? _buildEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Tidak ada pengajuan',
                  message: 'Belum ada reimbursement yang sesuai dengan filter.',
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final grid = constraints.maxWidth >= 1050;

                      if (!grid) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) =>
                              _buildReimbursementCard(_filteredItems[index]),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _filteredItems.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.72,
                            ),
                        itemBuilder: (context, index) =>
                            _buildReimbursementCard(_filteredItems[index]),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPeriodDropdown() {
    return DropdownButtonFormField<WorkPeriodModel?>(
      value: _selectedPeriod,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Periode',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<WorkPeriodModel?>(
          value: null,
          child: Text('Semua Periode', overflow: TextOverflow.ellipsis),
        ),
        ..._workPeriods.map(
          (p) => DropdownMenuItem<WorkPeriodModel?>(
            value: p,
            child: Text(p.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: _isLoadingPeriods
          ? null
          : (value) {
              setState(() {
                _selectedPeriod = value;
                _filteredItems = _filterItems(_allItems);
              });
            },
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;

              final search = TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama, judul, kategori, atau jabatan...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
              );

              final statusFilter = DropdownButtonFormField<String?>(
                value: _selectedStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  isDense: true,
                ),
                items: _statusOptions
                    .map(
                      (option) => DropdownMenuItem<String?>(
                        value: option.value,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                    _filteredItems = _filterItems(_allItems);
                  });
                },
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: 180, child: _buildPeriodDropdown()),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: statusFilter),
                  ],
                );
              }

              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  _buildPeriodDropdown(),
                  const SizedBox(height: 10),
                  statusFilter,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusOptions.map((option) {
                  final selected = _selectedStatus == option.value;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(option.label),
                      onSelected: (_) {
                        setState(() {
                          _selectedStatus = option.value;
                          _filteredItems = _filterItems(_allItems);
                        });
                      },
                      selectedColor: _primary.withOpacity(0.12),
                      checkmarkColor: _primary,
                      labelStyle: TextStyle(
                        color: selected ? _primary : const Color(0xFF6B7280),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    final paymentItems = _paymentItems;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: _success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proses Pembayaran',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pengajuan yang telah disetujui Finance.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${paymentItems.length} data',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: paymentItems.isEmpty
              ? _buildEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'Belum ada pembayaran',
                  message:
                      'Tidak ada reimbursement yang siap atau sudah dibayar.',
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final grid = constraints.maxWidth >= 1050;

                      if (!grid) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: paymentItems.length,
                          itemBuilder: (context, index) =>
                              _buildPaymentCard(paymentItems[index]),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: paymentItems.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 2.10,
                            ),
                        itemBuilder: (context, index) =>
                            _buildPaymentCard(paymentItems[index]),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(FinanceReimbursementItem item) {
    return InkWell(
      onTap: () => _showDetail(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isApproved
                ? _success.withOpacity(0.42)
                : const Color(0xFFE5E7EB),
            width: item.isApproved ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _statusColor(item).withOpacity(0.12),
                  child: Text(
                    item.initials,
                    style: TextStyle(
                      color: _statusColor(item),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.userName.isEmpty ? 'Karyawan' : item.userName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                _statusBadge(item),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title.isEmpty ? 'Reimbursement' : item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.category.isEmpty ? '-' : item.category,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currency(item.amount),
                  style: TextStyle(
                    color: item.isApproved ? _success : _info,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.isApproved)
                  ElevatedButton.icon(
                    onPressed: () => _markPaid(item),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Upload Bukti TF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  )
                else
                  Text(
                    item.paidAt != null
                        ? (item.hasPaymentProof
                              ? 'Selesai • ${_dateTime(item.paidAt!)}'
                              : _dateTime(item.paidAt!))
                        : 'Sudah dibayar',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReimbursementCard(
    FinanceReimbursementItem item, {
    bool compact = false,
  }) {
    _statusColor(item);
    final urgent = item.isUrgent;

    return InkWell(
      onTap: () => _showDetail(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: urgent
                ? _danger.withOpacity(0.40)
                : item.isPendingFinance
                ? _warning.withOpacity(0.34)
                : const Color(0xFFE5E7EB),
            width: urgent ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title.isEmpty ? 'Reimbursement' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF1F2937),
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(item),
              ],
            ),
            SizedBox(height: compact ? 8 : 11),
            Row(
              children: [
                CircleAvatar(
                  radius: compact ? 15 : 17,
                  backgroundColor: _primary.withOpacity(0.10),
                  child: Text(
                    item.initials,
                    style: TextStyle(
                      color: _primary,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.userName.isEmpty ? 'Karyawan' : item.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1F2937),
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.userJob?.isNotEmpty == true
                            ? item.userJob!
                            : 'Tidak ada jabatan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: compact ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Container(
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 15,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.category.isEmpty ? '-' : item.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currency(item.amount),
                    style: TextStyle(
                      color: _primary,
                      fontSize: compact ? 12 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (!compact && item.reviewedBy != null) ...[
              const SizedBox(height: 9),
              _approvalInfo(
                icon: Icons.verified_rounded,
                color: _success,
                text:
                    'HRD: ${item.reviewedBy}${item.reviewedAt != null ? ' • ${_date(item.reviewedAt!)}' : ''}',
              ),
            ],
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  urgent
                      ? Icons.warning_amber_rounded
                      : Icons.access_time_rounded,
                  color: _urgencyColor(item),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.daysSinceSubmitted <= 0
                        ? 'Diajukan hari ini'
                        : 'Diajukan ${item.daysSinceSubmitted} hari lalu',
                    style: TextStyle(
                      color: _urgencyColor(item),
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!compact && item.hasReceipt)
                  const Icon(
                    Icons.attach_file_rounded,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
              ],
            ),
            if (!compact && item.isPendingFinance) ...[
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewWithNotes(item, 'rejected'),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _danger,
                        side: BorderSide(color: _danger.withOpacity(0.55)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reviewWithNotes(item, 'approved'),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Setujui'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (!compact && item.isApproved) ...[
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markPaid(item),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Upload Bukti Transfer & Selesaikan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _approvalInfo({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(FinanceReimbursementItem item) {
    final color = _statusColor(item);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(item),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
    Widget? trailing,
  }) {
    final color = iconColor ?? _primary;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _emptyInline({
    required IconData icon,
    required String message,
    Color? iconColor,
  }) {
    final color = iconColor ?? const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 46, color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(FinanceReimbursementItem item) {
    // null = masih loading, [] = tidak ada attachment baru (fallback ke single receipt)
    final attachmentsNotifier =
        ValueNotifier<List<ReimbursementAttachmentMeta>?>(null);

    if (_currentUserId?.isNotEmpty == true) {
      FinanceReimbursementService.getAttachmentsMeta(
        reimbursementId: item.id,
        viewerUserId: _currentUserId!,
      ).then((metas) {
        attachmentsNotifier.value = metas;
      }).catchError((_) {
        attachmentsNotifier.value = [];
      });
    } else {
      attachmentsNotifier.value = [];
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.55,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _statusColor(item).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: _statusColor(item),
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title.isEmpty
                                      ? 'Detail Reimbursement'
                                      : item.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _statusBadge(item),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(bottomContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _detailSection(
                        title: 'Informasi Pengaju',
                        icon: Icons.person_outline_rounded,
                        children: [
                          _detailRow(
                            'Nama',
                            item.userName.isEmpty ? '-' : item.userName,
                          ),
                          _detailRow(
                            'Jabatan',
                            item.userJob?.isNotEmpty == true
                                ? item.userJob!
                                : '-',
                          ),
                          if (item.userEmail?.isNotEmpty == true)
                            _detailRow('Email', item.userEmail!),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _detailSection(
                        title: 'Detail Pengajuan',
                        icon: Icons.receipt_long_rounded,
                        children: [
                          _detailRow(
                            'Kategori',
                            item.category.isEmpty ? '-' : item.category,
                          ),
                          _detailRow(
                            'Nominal',
                            _currency(item.amount),
                            highlight: true,
                          ),
                          _detailRow(
                            'Tanggal Pengeluaran',
                            _date(item.expenseDate),
                          ),
                          _detailRow('Diajukan', _dateTime(item.submittedAt)),
                          if (item.description?.isNotEmpty == true)
                            _detailRow('Keterangan', item.description!),
                        ],
                      ),
                      ValueListenableBuilder<
                        List<ReimbursementAttachmentMeta>?
                      >(
                        valueListenable: attachmentsNotifier,
                        builder: (context, metas, _) {
                          final hasOldReceipt = item.hasReceipt ||
                              item.receiptFilename?.isNotEmpty == true;
                          if (metas != null && metas.isNotEmpty) {
                            return Column(
                              children: [
                                const SizedBox(height: 14),
                                _buildMultiAttachmentSection(item, metas),
                              ],
                            );
                          }
                          if (!hasOldReceipt) return const SizedBox.shrink();
                          return Column(
                            children: [
                              const SizedBox(height: 14),
                              _buildAttachmentSection(
                                item,
                                title: 'Bukti Pengajuan User',
                                subtitle:
                                    'Struk, invoice, atau bukti pembayaran dari pengaju',
                                fileName: item.receiptFilename,
                                contentType: item.receiptContentType,
                                kind: _AttachmentKind.userReceipt,
                              ),
                            ],
                          );
                        },
                      ),
                      if (item.hasPaymentProof ||
                          item.paymentProofFilename?.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        _buildAttachmentSection(
                          item,
                          title: 'Bukti Transfer Finance',
                          subtitle:
                              item.paymentProofUploadedBy?.isNotEmpty == true
                              ? 'Diupload oleh ${item.paymentProofUploadedBy}${item.paymentProofUploadedAt != null ? ' • ${_dateTime(item.paymentProofUploadedAt!)}' : ''}'
                              : 'Bukti pembayaran dari Finance',
                          fileName: item.paymentProofFilename,
                          contentType: item.paymentProofContentType,
                          kind: _AttachmentKind.paymentProof,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _detailSection(
                        title: 'Riwayat Persetujuan',
                        icon: Icons.history_rounded,
                        children: [
                          _timelineRow(
                            title: 'Diajukan',
                            subtitle: _dateTime(item.submittedAt),
                            icon: Icons.send_rounded,
                            color: _primary,
                          ),
                          if (item.reviewedBy != null)
                            _timelineRow(
                              title: 'Review HRD',
                              subtitle:
                                  '${item.reviewedBy}${item.reviewedAt != null ? ' • ${_dateTime(item.reviewedAt!)}' : ''}'
                                  '${item.reviewNotes?.isNotEmpty == true ? '\n${item.reviewNotes}' : ''}',
                              icon: Icons.verified_rounded,
                              color: _success,
                            ),
                          if (item.financeReviewedBy != null)
                            _timelineRow(
                              title: 'Review Finance',
                              subtitle:
                                  '${item.financeReviewedBy}${item.financeReviewedAt != null ? ' • ${_dateTime(item.financeReviewedAt!)}' : ''}'
                                  '${item.financeReviewNotes?.isNotEmpty == true ? '\n${item.financeReviewNotes}' : ''}',
                              icon: Icons.account_balance_wallet_rounded,
                              color: item.isRejected ? _danger : _success,
                            ),
                          if (item.paidAt != null || item.paidBy != null)
                            _timelineRow(
                              title: item.hasPaymentProof
                                  ? 'Pembayaran Selesai'
                                  : 'Dibayar',
                              subtitle:
                                  '${item.paidBy ?? 'Finance'}${item.paidAt != null ? ' • ${_dateTime(item.paidAt!)}' : ''}${item.paymentNotes?.isNotEmpty == true ? '\n${item.paymentNotes}' : ''}',
                              icon: Icons.payments_rounded,
                              color: _info,
                              isLast: true,
                            ),
                        ],
                      ),
                      if (item.isPendingFinance || item.isApproved) ...[
                        const SizedBox(height: 20),
                        _detailActions(item, bottomContext),
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

  Widget _buildAttachmentSection(
    FinanceReimbursementItem item, {
    required String title,
    required String subtitle,
    required String? fileName,
    required String? contentType,
    required _AttachmentKind kind,
  }) {
    final shownFileName = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : kind == _AttachmentKind.userReceipt
        ? 'Bukti reimbursement'
        : 'Bukti transfer Finance';
    final extension = _extensionOf(shownFileName);
    final icon = _attachmentIcon(extension);
    final iconColor = kind == _AttachmentKind.paymentProof
        ? _success
        : _attachmentColor(extension);

    return _detailSection(
      title: title,
      icon: kind == _AttachmentKind.paymentProof
          ? Icons.account_balance_rounded
          : Icons.attach_file_rounded,
      children: [
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: kind == _AttachmentKind.paymentProof
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: kind == _AttachmentKind.paymentProof
                  ? _success.withOpacity(0.25)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shownFileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      extension.isEmpty
                          ? 'File lampiran'
                          : extension.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAttachmentProcessing
                    ? null
                    : () => _handleAttachment(item, kind: kind, preview: true),
                icon: _isAttachmentProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: BorderSide(color: _primary.withOpacity(0.45)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isAttachmentProcessing
                    ? null
                    : () => _handleAttachment(item, kind: kind, preview: false),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAttachment(
    FinanceReimbursementItem item, {
    required _AttachmentKind kind,
    required bool preview,
  }) async {
    if (_isAttachmentProcessing) return;
    if (_currentUserId == null || _currentUserId!.trim().isEmpty) {
      _showError('Data user tidak ditemukan. Silakan login ulang.');
      return;
    }
    setState(() => _isAttachmentProcessing = true);
    _showInfo(
      preview ? 'Memuat pratinjau file...' : 'Menyiapkan download file...',
    );
    try {
      final attachment = kind == _AttachmentKind.userReceipt
          ? await FinanceReimbursementService.downloadUserReceipt(
              reimbursementId: item.id,
              viewerUserId: _currentUserId!,
              fallbackFileName: item.receiptFilename,
            )
          : await FinanceReimbursementService.downloadPaymentProof(
              reimbursementId: item.id,
              viewerUserId: _currentUserId!,
              fallbackFileName: item.paymentProofFilename,
            );
      if (preview) {
        await _previewAttachment(attachment);
      } else {
        await _downloadAttachment(attachment);
      }
    } on FinanceServiceException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Gagal memproses lampiran: $e');
    } finally {
      if (mounted) setState(() => _isAttachmentProcessing = false);
    }
  }

  Future<void> _handleAttachmentById(
    int attachmentId, {
    required String? fallbackFileName,
    required bool preview,
  }) async {
    if (_isAttachmentProcessing) return;
    if (_currentUserId == null || _currentUserId!.trim().isEmpty) {
      _showError('Data user tidak ditemukan. Silakan login ulang.');
      return;
    }
    setState(() => _isAttachmentProcessing = true);
    _showInfo(
      preview ? 'Memuat pratinjau file...' : 'Menyiapkan download file...',
    );
    try {
      final attachment = await FinanceReimbursementService.downloadAttachmentById(
        attachmentId: attachmentId,
        viewerUserId: _currentUserId!,
        fallbackFileName: fallbackFileName,
      );
      if (preview) {
        await _previewAttachment(attachment);
      } else {
        await _downloadAttachment(attachment);
      }
    } on FinanceServiceException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Gagal memproses lampiran: $e');
    } finally {
      if (mounted) setState(() => _isAttachmentProcessing = false);
    }
  }

  Widget _buildMultiAttachmentSection(
    FinanceReimbursementItem item,
    List<ReimbursementAttachmentMeta> metas,
  ) {
    return _detailSection(
      title: metas.length > 1
          ? 'Bukti Pengajuan User (${metas.length} file)'
          : 'Bukti Pengajuan User',
      icon: Icons.attach_file_rounded,
      children: [
        const Text(
          'Struk, invoice, atau bukti pembayaran dari pengaju',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 9),
        ...List.generate(metas.length, (index) {
          final meta = metas[index];
          final ext = meta.extension;
          final icon = _attachmentIcon(ext);
          final iconColor = _attachmentColor(ext);

          return Padding(
            padding: EdgeInsets.only(
              bottom: index < metas.length - 1 ? 12 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metas.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      'File ${index + 1} dari ${metas.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 21),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta.fileName.isEmpty
                                  ? 'File ${index + 1}'
                                  : meta.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ext.isEmpty
                                  ? 'File lampiran'
                                  : '${ext.toUpperCase()} • ${meta.fileSizeMb.toStringAsFixed(1)} MB',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10,
                              ),
                            ),
                          ],
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
                            : () => _handleAttachmentById(
                                meta.id,
                                fallbackFileName: meta.fileName,
                                preview: true,
                              ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Preview'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: BorderSide(color: _primary.withOpacity(0.45)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isAttachmentProcessing
                            ? null
                            : () => _handleAttachmentById(
                                meta.id,
                                fallbackFileName: meta.fileName,
                                preview: false,
                              ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
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
      ],
    );
  }

  Future<void> _previewAttachment(
    FinanceReimbursementAttachment attachment,
  ) async {
    if (attachment.isImage) {
      await _showImagePreview(
        Uint8List.fromList(attachment.bytes),
        attachment.fileName,
      );
      return;
    }

    if (kIsWeb) {
      // PDF/dokumen di Web: buka sebagai pratinjau di tab baru, bukan download.
      openBytesInBrowser(
        attachment.bytes,
        attachment.fileName,
        attachment.mimeType,
      );
      return;
    }

    // Android/iOS: simpan file sementara lalu buka memakai viewer sistem.
    final tempDirectory = await getTemporaryDirectory();
    final localFile = File(
      '${tempDirectory.path}/${_safeFileName(attachment.fileName)}',
    );
    await localFile.writeAsBytes(attachment.bytes, flush: true);

    final result = await OpenFile.open(localFile.path);
    if (result.type != ResultType.done && mounted) {
      _showError(
        result.message.isEmpty
            ? 'Tidak ada aplikasi untuk membuka file ini.'
            : result.message,
      );
    }
  }

  Future<void> _downloadAttachment(
    FinanceReimbursementAttachment attachment,
  ) async {
    if (kIsWeb) {
      downloadFileWeb(attachment.bytes, attachment.fileName);
      if (mounted) _showSuccess('File sedang diunduh.');
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final localFile = File(
      '${directory.path}/${_safeFileName(attachment.fileName)}',
    );
    await localFile.writeAsBytes(attachment.bytes, flush: true);

    if (mounted) {
      _showSuccess('File tersimpan: ${localFile.path}');
    }
  }

  Future<void> _showImagePreview(Uint8List bytes, String fileName) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined, color: _primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 4,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('Gambar tidak dapat ditampilkan.'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _attachmentIcon(String extension) {
    if (const [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension)) {
      return Icons.image_outlined;
    }
    if (extension == 'pdf') return Icons.picture_as_pdf_outlined;
    if (const ['doc', 'docx'].contains(extension)) {
      return Icons.description_outlined;
    }
    if (const ['xls', 'xlsx', 'csv'].contains(extension)) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _attachmentColor(String extension) {
    if (const [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension)) {
      return const Color(0xFF8B5CF6);
    }
    if (extension == 'pdf') return _danger;
    if (const ['doc', 'docx'].contains(extension)) return _info;
    if (const ['xls', 'xlsx', 'csv'].contains(extension)) return _success;
    return const Color(0xFF6B7280);
  }

  String _extensionOf(String fileName) {
    final cleanName = fileName.split('?').first;
    if (!cleanName.contains('.')) return '';
    return cleanName.split('.').last.toLowerCase();
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '_');
    return sanitized.trim().isEmpty ? 'lampiran_reimbursement' : sanitized;
  }

  String _formatFileSize(int size) {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024).toStringAsFixed(0)} KB';
  }

  String _mimeTypeFromFileName(String name) {
    switch (_extensionOf(name)) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
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
              Icon(icon, color: _primary, size: 17),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
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

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? _primary : const Color(0xFF1F2937),
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 13),
                ),
                if (!isLast)
                  Container(
                    width: 1,
                    height: 38,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: const Color(0xFFD1D5DB),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailActions(
    FinanceReimbursementItem item,
    BuildContext bottomContext,
  ) {
    if (item.isPendingFinance) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(bottomContext);
                _reviewWithNotes(item, 'rejected');
              },
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Tolak'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: BorderSide(color: _danger.withOpacity(0.55)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(bottomContext);
                _reviewWithNotes(item, 'approved');
              },
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Setujui'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _success,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(bottomContext);
          _markPaid(item);
        },
        icon: const Icon(Icons.payments_rounded, size: 18),
        label: const Text('Upload Bukti Transfer & Selesaikan'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _dialogItemSummary(FinanceReimbursementItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primary.withOpacity(0.10),
            child: Text(
              item.initials,
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.userName} • ${_currency(item.amount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(FinanceReimbursementItem item) {
    if (item.isCompleted) return _success;
    switch (item.normalizedStatus) {
      case 'pending_finance':
        return _warning;
      case 'approved':
        return _success;
      case 'rejected':
        return _danger;
      case 'paid':
        return _info;
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _urgencyColor(FinanceReimbursementItem item) {
    if (item.daysSinceSubmitted >= 7) return _danger;
    if (item.daysSinceSubmitted >= 3) return _warning;
    return const Color(0xFF6B7280);
  }

  String _statusLabel(FinanceReimbursementItem item) {
    if (item.isCompleted) return 'Selesai';
    if (item.statusText.trim().isNotEmpty) return item.statusText.trim();

    switch (item.normalizedStatus) {
      case 'pending_finance':
        return 'Menunggu Finance';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'paid':
        return 'Dibayar';
      default:
        return item.status.isEmpty ? '-' : item.status;
    }
  }

  String _currency(double value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String _date(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  String _dateTime(DateTime date) =>
      DateFormat('dd MMM yyyy, HH:mm').format(date);

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Finance Reimbursement Report Modal
// ─────────────────────────────────────────────────────────────────────────────

class FinanceReimbursementReportModal extends StatefulWidget {
  final List<FinanceReimbursementItem> allItems;
  final List<WorkPeriodModel> workPeriods;
  final String currentUserId;
  final String currentUserName;

  const FinanceReimbursementReportModal({
    super.key,
    required this.allItems,
    required this.workPeriods,
    this.currentUserId = '',
    this.currentUserName = '',
  });

  @override
  State<FinanceReimbursementReportModal> createState() =>
      _FinanceReimbursementReportModalState();
}

class _FinanceReimbursementReportModalState
    extends State<FinanceReimbursementReportModal> {
  static const Color _primary = Color(0xFF6366F1);

  String _selectedReportType = 'period';
  WorkPeriodModel? _selectedPeriod;

  final List<({String key, String label})> _reportTypes = const [
    (key: 'period', label: 'Periode'),
    (key: 'yearly', label: 'Tahunan'),
    (key: 'category', label: 'Kategori'),
    (key: 'status', label: 'Status'),
    (key: 'summary', label: 'Ringkasan'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.workPeriods.isNotEmpty) {
      final today = DateTime.now();
      final todayNorm = DateTime(today.year, today.month, today.day);
      for (final p in widget.workPeriods) {
        final s = DateTime(p.tanggalMulai.year, p.tanggalMulai.month, p.tanggalMulai.day);
        final e = DateTime(p.tanggalSelesai.year, p.tanggalSelesai.month, p.tanggalSelesai.day);
        if (!todayNorm.isBefore(s) && !todayNorm.isAfter(e)) {
          _selectedPeriod = p;
          break;
        }
      }
      _selectedPeriod ??= widget.workPeriods.first;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<FinanceReimbursementItem> get _filteredItems {
    if (_selectedReportType == 'period' && _selectedPeriod != null) {
      final s = DateTime(_selectedPeriod!.tanggalMulai.year,
          _selectedPeriod!.tanggalMulai.month, _selectedPeriod!.tanggalMulai.day);
      final e = DateTime(_selectedPeriod!.tanggalSelesai.year,
          _selectedPeriod!.tanggalSelesai.month, _selectedPeriod!.tanggalSelesai.day);
      return widget.allItems.where((r) {
        final d = DateTime(r.submittedAt.year, r.submittedAt.month, r.submittedAt.day);
        return !d.isBefore(s) && !d.isAfter(e);
      }).toList();
    }
    if (_selectedReportType == 'yearly') {
      final y = _selectedPeriod?.tanggalMulai.year ?? DateTime.now().year;
      return widget.allItems.where((r) => r.submittedAt.year == y).toList();
    }
    return List.from(widget.allItems);
  }

  String get _periodLabel {
    if (_selectedReportType == 'period') return _selectedPeriod?.label ?? 'Semua Periode';
    if (_selectedReportType == 'yearly') {
      return 'Tahun ${_selectedPeriod?.tanggalMulai.year ?? DateTime.now().year}';
    }
    return 'Semua Data';
  }

  String _fmtCurr(double v) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(v);

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Laporan Finance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _exportExcel,
                    icon: const Icon(Icons.download, color: _primary),
                    tooltip: 'Export Excel',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTypeAndPeriodSelector(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(child: _buildReportContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeAndPeriodSelector() {
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
          const Text(
            'Jenis Laporan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reportTypes.map((t) {
              final sel = t.key == _selectedReportType;
              return InkWell(
                onTap: () => setState(() => _selectedReportType = t.key),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _primary : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if ((_selectedReportType == 'period' || _selectedReportType == 'yearly') &&
              widget.workPeriods.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkPeriodModel?>(
              value: _selectedPeriod,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Periode',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<WorkPeriodModel?>(
                  value: null,
                  child: Text('Semua Periode', overflow: TextOverflow.ellipsis),
                ),
                ...widget.workPeriods.map((p) => DropdownMenuItem<WorkPeriodModel?>(
                      value: p,
                      child: Text(p.label, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedPeriod = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_selectedReportType) {
      case 'period':
        return _buildPeriodReport();
      case 'yearly':
        return _buildYearlyReport();
      case 'category':
        return _buildCategoryReport();
      case 'status':
        return _buildStatusReport();
      default:
        return _buildSummaryReport();
    }
  }

  // ── Report sections ────────────────────────────────────────────────────────

  Widget _buildPeriodReport() {
    final items = _filteredItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan Periode — $_periodLabel'),
        const SizedBox(height: 16),
        _buildStatsGrid(items),
        const SizedBox(height: 16),
        _buildAmountBreakdown(items),
        const SizedBox(height: 16),
        _buildTopRequesterSection(items),
        const SizedBox(height: 16),
        _buildCategoryBreakdown(items),
      ],
    );
  }

  Widget _buildYearlyReport() {
    final items = _filteredItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan Tahunan — $_periodLabel'),
        const SizedBox(height: 16),
        _buildStatsGrid(items),
        const SizedBox(height: 16),
        _buildMonthlyBreakdown(items),
        const SizedBox(height: 16),
        _buildCategoryBreakdown(items),
      ],
    );
  }

  Widget _buildCategoryReport() {
    final items = widget.allItems;
    final Map<String, ({int count, double total})> catMap = {};
    for (final r in items) {
      final cur = catMap[r.category];
      catMap[r.category] = (
        count: (cur?.count ?? 0) + 1,
        total: (cur?.total ?? 0) + r.amount,
      );
    }
    final cats = catMap.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan per Kategori'),
        const SizedBox(height: 16),
        ...cats.map((e) => _buildCategoryCard(e.key, e.value.count, e.value.total)),
      ],
    );
  }

  Widget _buildStatusReport() {
    final items = widget.allItems;
    final statuses = <String, ({int count, double total})>{};
    for (final r in items) {
      final cur = statuses[r.statusText];
      statuses[r.statusText] = (
        count: (cur?.count ?? 0) + 1,
        total: (cur?.total ?? 0) + r.amount,
      );
    }
    final list = statuses.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Laporan per Status'),
        const SizedBox(height: 16),
        ...list.map((e) => _buildCategoryCard(e.key, e.value.count, e.value.total)),
      ],
    );
  }

  Widget _buildSummaryReport() {
    final all = widget.allItems;
    final paid = all.where((r) => r.isPaid).toList();
    final pending = all.where((r) => r.isPendingFinance).toList();
    final approved = all.where((r) => r.isApproved).toList();
    final rejected = all.where((r) => r.isRejected).toList();
    final totalAmount = all.fold(0.0, (s, r) => s + r.amount);
    final paidAmount = paid.fold(0.0, (s, r) => s + r.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader('Ringkasan Finance — Semua Data'),
        const SizedBox(height: 16),
        _buildStatsGrid(all),
        const SizedBox(height: 16),
        _infoCard('Ringkasan Nilai', [
          _infoRow('Total Nilai Pengajuan', _fmtCurr(totalAmount)),
          _infoRow('Sudah Dibayar', _fmtCurr(paidAmount)),
          _infoRow('Menunggu Pembayaran',
              _fmtCurr(approved.fold(0.0, (s, r) => s + r.amount))),
          _infoRow('Belum Diproses',
              _fmtCurr(pending.fold(0.0, (s, r) => s + r.amount))),
          _infoRow('Ditolak',
              _fmtCurr(rejected.fold(0.0, (s, r) => s + r.amount))),
        ]),
        const SizedBox(height: 16),
        _buildCategoryBreakdown(all),
      ],
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _buildReportHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assessment, color: _primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937))),
                Text(
                  'Dicetak: ${_fmtDate(DateTime.now())} oleh ${widget.currentUserName}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(List<FinanceReimbursementItem> items) {
    final total = items.length;
    final pending = items.where((r) => r.isPendingFinance).length;
    final approved = items.where((r) => r.isApproved).length;
    final paid = items.where((r) => r.isPaid).length;
    final rejected = items.where((r) => r.isRejected).length;
    final totalAmt = items.fold(0.0, (s, r) => s + r.amount);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _statTile('Total', '$total', const Color(0xFF6366F1), Icons.receipt_long_rounded),
        _statTile('Pending', '$pending', const Color(0xFFF59E0B), Icons.pending_actions_rounded),
        _statTile('Disetujui', '$approved', const Color(0xFF10B981), Icons.check_circle_rounded),
        _statTile('Dibayar', '$paid', const Color(0xFF3B82F6), Icons.payments_rounded),
        _statTile('Ditolak', '$rejected', const Color(0xFFEF4444), Icons.cancel_rounded),
        _statTile('Total Nilai', _fmtCurr(totalAmt),
            const Color(0xFF8B5CF6), Icons.account_balance_wallet_rounded,
            smallText: true),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color, IconData icon,
      {bool smallText = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: smallText ? 12 : 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildAmountBreakdown(List<FinanceReimbursementItem> items) {
    final paid = items.where((r) => r.isPaid).fold(0.0, (s, r) => s + r.amount);
    final approved = items.where((r) => r.isApproved).fold(0.0, (s, r) => s + r.amount);
    final pending = items.where((r) => r.isPendingFinance).fold(0.0, (s, r) => s + r.amount);
    final rejected = items.where((r) => r.isRejected).fold(0.0, (s, r) => s + r.amount);
    return _infoCard('Rincian Nilai', [
      _infoRow('Dibayar', _fmtCurr(paid)),
      _infoRow('Siap Bayar (Approved)', _fmtCurr(approved)),
      _infoRow('Menunggu Review', _fmtCurr(pending)),
      _infoRow('Ditolak', _fmtCurr(rejected)),
    ]);
  }

  Widget _buildTopRequesterSection(List<FinanceReimbursementItem> items) {
    final Map<String, double> byUser = {};
    for (final r in items) {
      byUser[r.userName] = (byUser[r.userName] ?? 0) + r.amount;
    }
    final top = (byUser.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5);
    return _infoCard(
      'Top 5 Pengaju (Nilai)',
      top.map((e) => _infoRow(e.key, _fmtCurr(e.value))).toList(),
    );
  }

  Widget _buildCategoryBreakdown(List<FinanceReimbursementItem> items) {
    final Map<String, ({int count, double total})> catMap = {};
    for (final r in items) {
      final cur = catMap[r.category];
      catMap[r.category] = (count: (cur?.count ?? 0) + 1, total: (cur?.total ?? 0) + r.amount);
    }
    final sorted = catMap.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));
    return _infoCard(
      'Per Kategori',
      sorted.map((e) => _infoRow('${e.key} (${e.value.count}x)', _fmtCurr(e.value.total))).toList(),
    );
  }

  Widget _buildMonthlyBreakdown(List<FinanceReimbursementItem> items) {
    final Map<String, ({int count, double total})> byMonth = {};
    for (final r in items) {
      final key = DateFormat('MMM yyyy', 'id_ID').format(r.submittedAt);
      final cur = byMonth[key];
      byMonth[key] = (count: (cur?.count ?? 0) + 1, total: (cur?.total ?? 0) + r.amount);
    }
    final sorted = byMonth.entries.toList()
      ..sort((a, b) {
        final da = DateFormat('MMM yyyy', 'id_ID').parse(a.key);
        final db = DateFormat('MMM yyyy', 'id_ID').parse(b.key);
        return db.compareTo(da);
      });
    return _infoCard(
      'Per Bulan',
      sorted.map((e) => _infoRow('${e.key} (${e.value.count}x)', _fmtCurr(e.value.total))).toList(),
    );
  }

  Widget _buildCategoryCard(String label, int count, double total) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('$count pengajuan', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(width: 12),
          Text(_fmtCurr(total),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          const Divider(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Membuat file Excel...'),
        ]),
        duration: Duration(seconds: 30),
        backgroundColor: Color(0xFF3949AB),
      ),
    );

    try {
      final data = List<FinanceReimbursementItem>.from(_filteredItems)
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      final now = DateTime.now();
      final printDate = 'Dicetak: ${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(now)}';

      final cHeaderBg = xl.ExcelColor.fromHexString('#1E3A5F');
      final cHeaderFg = xl.ExcelColor.fromHexString('#FFFFFF');
      final cColHdr = xl.ExcelColor.fromHexString('#E8EAF6');
      final cColHdrFg = xl.ExcelColor.fromHexString('#1A237E');
      final cAlt = xl.ExcelColor.fromHexString('#F5F5FF');
      final cWhite = xl.ExcelColor.fromHexString('#FFFFFF');
      final cBorder = xl.ExcelColor.fromHexString('#C5CAE9');
      final cGreen = xl.ExcelColor.fromHexString('#C8E6C9');
      final cYellow = xl.ExcelColor.fromHexString('#FFF9C4');
      final cRed = xl.ExcelColor.fromHexString('#FFCDD2');
      final cBlue = xl.ExcelColor.fromHexString('#B3E5FC');
      final cTotalRow = xl.ExcelColor.fromHexString('#283593');

      xl.Border thin() => xl.Border(
          borderStyle: xl.BorderStyle.Thin, borderColorHex: cBorder);

      xl.CellStyle style({
        xl.ExcelColor? bg,
        xl.ExcelColor? fg,
        bool bold = false,
        int fs = 10,
        xl.HorizontalAlign hAlign = xl.HorizontalAlign.Left,
        bool wrap = false,
        bool border = true,
      }) {
        final b = border ? thin() : xl.Border(borderStyle: xl.BorderStyle.None);
        return xl.CellStyle(
          backgroundColorHex: bg ?? cWhite,
          fontColorHex: fg ?? xl.ExcelColor.fromHexString('#212121'),
          bold: bold,
          fontSize: fs,
          horizontalAlign: hAlign,
          verticalAlign: xl.VerticalAlign.Center,
          textWrapping: wrap ? xl.TextWrapping.WrapText : null,
          leftBorder: b, rightBorder: b, topBorder: b, bottomBorder: b,
        );
      }

      void setC(xl.Sheet s, int col, int row, dynamic val, xl.CellStyle st) {
        final c = s.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        if (val is int) {
          c.value = xl.IntCellValue(val);
        } else if (val is double) {
          c.value = xl.DoubleCellValue(val);
        } else {
          c.value = xl.TextCellValue(val?.toString() ?? '');
        }
        c.cellStyle = st;
      }

      void titleRow(xl.Sheet s, String title, String mergeEnd, int row) {
        s.cell(xl.CellIndex.indexByString('A${row + 1}'))
          ..value = xl.TextCellValue(title)
          ..cellStyle = style(
              bg: cHeaderBg, fg: cHeaderFg, bold: true,
              fs: 14, hAlign: xl.HorizontalAlign.Center, border: false);
        s.merge(xl.CellIndex.indexByString('A${row + 1}'),
            xl.CellIndex.indexByString('$mergeEnd${row + 1}'));
      }

      void subRow(xl.Sheet s, String sub, String date, String endSub,
          String endDate, int row) {
        s.cell(xl.CellIndex.indexByString('A${row + 1}'))
          ..value = xl.TextCellValue('Periode: $sub')
          ..cellStyle =
              style(bg: cColHdr, fg: cColHdrFg, bold: true, fs: 11, border: false);
        s.merge(xl.CellIndex.indexByString('A${row + 1}'),
            xl.CellIndex.indexByString('$endSub${row + 1}'));
        s.cell(xl.CellIndex.indexByString('${endDate.substring(0, 1)}${row + 1}'))
          ..value = xl.TextCellValue(date)
          ..cellStyle = style(
              bg: cColHdr,
              fg: xl.ExcelColor.fromHexString('#6B7280'),
              fs: 10,
              hAlign: xl.HorizontalAlign.Right,
              border: false);
        s.merge(
            xl.CellIndex.indexByString('${endDate.substring(0, 1)}${row + 1}'),
            xl.CellIndex.indexByString('$endDate${row + 1}'));
      }

      final excel = xl.Excel.createExcel();

      // ── SHEET 1 — RINGKASAN ──────────────────────────────────────────────
      final s1 = excel['Ringkasan'];
      titleRow(s1, 'LAPORAN FINANCE REIMBURSEMENT', 'E', 0);
      subRow(s1, _periodLabel, printDate, 'C', 'E', 1);

      final totalAmt = data.fold(0.0, (s, r) => s + r.amount);
      final paidItems = data.where((r) => r.isPaid).toList();
      final approvedItems = data.where((r) => r.isApproved).toList();
      final pendingItems = data.where((r) => r.isPendingFinance).toList();
      final rejectedItems = data.where((r) => r.isRejected).toList();

      final summaryData = [
        ['Total Pengajuan', data.length, totalAmt],
        ['Dibayar', paidItems.length, paidItems.fold(0.0, (s, r) => s + r.amount)],
        ['Disetujui (Siap Bayar)', approvedItems.length, approvedItems.fold(0.0, (s, r) => s + r.amount)],
        ['Menunggu Review', pendingItems.length, pendingItems.fold(0.0, (s, r) => s + r.amount)],
        ['Ditolak', rejectedItems.length, rejectedItems.fold(0.0, (s, r) => s + r.amount)],
      ];

      const s1Hdrs = ['Status', 'Jumlah Pengajuan', 'Total Nilai'];
      final hSt = style(bg: cColHdr, fg: cColHdrFg, bold: true, fs: 10, hAlign: xl.HorizontalAlign.Center);
      for (int c = 0; c < s1Hdrs.length; c++) { setC(s1, c, 3, s1Hdrs[c], hSt); }

      for (int i = 0; i < summaryData.length; i++) {
        final row = 4 + i;
        final bg = i == 0 ? cColHdr : (i.isOdd ? cAlt : cWhite);
        final bold = i == 0;
        setC(s1, 0, row, summaryData[i][0], style(bg: bg, bold: bold));
        setC(s1, 1, row, summaryData[i][1], style(bg: bg, bold: bold, hAlign: xl.HorizontalAlign.Center));
        setC(s1, 2, row, _fmtCurr(summaryData[i][2] as double), style(bg: bg, bold: bold, hAlign: xl.HorizontalAlign.Right));
      }

      s1.setColumnWidth(0, 30); s1.setColumnWidth(1, 20); s1.setColumnWidth(2, 25);

      // ── SHEET 2 — DATA DETAIL ────────────────────────────────────────────
      final s2 = excel['Data Detail'];
      titleRow(s2, 'DETAIL REIMBURSEMENT FINANCE', 'J', 0);
      subRow(s2, _periodLabel, printDate, 'E', 'J', 1);

      const s2Hdrs = ['No', 'Nama Karyawan', 'Jabatan', 'Judul', 'Kategori',
          'Nilai', 'Tanggal Pengajuan', 'Status', 'Direview Finance', 'Dibayar'];
      final cHdrSt = style(bg: cColHdr, fg: cColHdrFg, bold: true, fs: 10, hAlign: xl.HorizontalAlign.Center);
      for (int c = 0; c < s2Hdrs.length; c++) { setC(s2, c, 3, s2Hdrs[c], cHdrSt); }

      xl.ExcelColor statusColor(FinanceReimbursementItem r) {
        if (r.isPaid) { return cBlue; }
        if (r.isApproved) { return cGreen; }
        if (r.isRejected) { return cRed; }
        return cYellow;
      }

      for (int i = 0; i < data.length; i++) {
        final r = data[i];
        final row = 4 + i;
        final bg = i.isOdd ? cAlt : cWhite;
        final sc = statusColor(r);
        setC(s2, 0, row, i + 1, style(bg: bg, hAlign: xl.HorizontalAlign.Center));
        setC(s2, 1, row, r.userName, style(bg: bg, bold: true));
        setC(s2, 2, row, r.userJob ?? '-', style(bg: bg));
        setC(s2, 3, row, r.title, style(bg: bg, wrap: true));
        setC(s2, 4, row, r.category, style(bg: bg));
        setC(s2, 5, row, _fmtCurr(r.amount), style(bg: bg, bold: true, hAlign: xl.HorizontalAlign.Right));
        setC(s2, 6, row, _fmtDate(r.submittedAt), style(bg: bg, hAlign: xl.HorizontalAlign.Center));
        setC(s2, 7, row, r.statusText, style(bg: sc, bold: true, hAlign: xl.HorizontalAlign.Center));
        setC(s2, 8, row, r.financeReviewedAt != null ? _fmtDate(r.financeReviewedAt!) : '-', style(bg: bg, hAlign: xl.HorizontalAlign.Center));
        setC(s2, 9, row, r.paidAt != null ? _fmtDate(r.paidAt!) : '-', style(bg: bg, hAlign: xl.HorizontalAlign.Center));
      }

      if (data.isNotEmpty) {
        final tRow = 4 + data.length;
        setC(s2, 0, tRow, 'TOTAL', style(bg: cTotalRow, fg: cHeaderFg, bold: true, hAlign: xl.HorizontalAlign.Center));
        s2.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: tRow),
            xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: tRow));
        setC(s2, 5, tRow, _fmtCurr(totalAmt), style(bg: cTotalRow, fg: cHeaderFg, bold: true, hAlign: xl.HorizontalAlign.Right));
        s2.merge(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: tRow),
            xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: tRow));
      }

      s2.setColumnWidth(0, 5); s2.setColumnWidth(1, 25); s2.setColumnWidth(2, 18);
      s2.setColumnWidth(3, 28); s2.setColumnWidth(4, 16); s2.setColumnWidth(5, 20);
      s2.setColumnWidth(6, 16); s2.setColumnWidth(7, 16); s2.setColumnWidth(8, 18);
      s2.setColumnWidth(9, 14);

      // ── SHEET 3 — PER KATEGORI ───────────────────────────────────────────
      final s3 = excel['Per Kategori'];
      titleRow(s3, 'RINGKASAN PER KATEGORI', 'E', 0);
      subRow(s3, _periodLabel, printDate, 'C', 'E', 1);

      final Map<String, ({int count, double total})> catMap = {};
      for (final r in data) {
        final cur = catMap[r.category];
        catMap[r.category] = (count: (cur?.count ?? 0) + 1, total: (cur?.total ?? 0) + r.amount);
      }
      final catList = catMap.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));

      const s3Hdrs = ['No', 'Kategori', 'Jumlah', 'Total Nilai', 'Rata-rata', 'Proporsi (%)'];
      final s3Hst = style(bg: cColHdr, fg: cColHdrFg, bold: true, fs: 10, hAlign: xl.HorizontalAlign.Center);
      for (int c = 0; c < s3Hdrs.length; c++) { setC(s3, c, 3, s3Hdrs[c], s3Hst); }

      for (int i = 0; i < catList.length; i++) {
        final e = catList[i];
        final row = 4 + i;
        final bg = i.isOdd ? cAlt : cWhite;
        final pct = totalAmt > 0 ? (e.value.total / totalAmt * 100).toStringAsFixed(1) : '0.0';
        setC(s3, 0, row, i + 1, style(bg: bg, hAlign: xl.HorizontalAlign.Center));
        setC(s3, 1, row, e.key, style(bg: bg, bold: true));
        setC(s3, 2, row, e.value.count, style(bg: bg, hAlign: xl.HorizontalAlign.Center));
        setC(s3, 3, row, _fmtCurr(e.value.total), style(bg: bg, bold: true, hAlign: xl.HorizontalAlign.Right));
        setC(s3, 4, row, e.value.count > 0 ? _fmtCurr(e.value.total / e.value.count) : '-', style(bg: bg, hAlign: xl.HorizontalAlign.Right));
        setC(s3, 5, row, '$pct%', style(bg: bg, hAlign: xl.HorizontalAlign.Center));
      }

      if (catList.isNotEmpty) {
        final tRow = 4 + catList.length;
        setC(s3, 0, tRow, 'TOTAL', style(bg: cTotalRow, fg: cHeaderFg, bold: true, hAlign: xl.HorizontalAlign.Center));
        s3.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: tRow),
            xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: tRow));
        setC(s3, 3, tRow, _fmtCurr(totalAmt), style(bg: cTotalRow, fg: cHeaderFg, bold: true, hAlign: xl.HorizontalAlign.Right));
        s3.merge(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: tRow),
            xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: tRow));
      }

      s3.setColumnWidth(0, 5); s3.setColumnWidth(1, 28); s3.setColumnWidth(2, 14);
      s3.setColumnWidth(3, 22); s3.setColumnWidth(4, 22); s3.setColumnWidth(5, 14);

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
      excel.setDefaultSheet('Ringkasan');

      final Uint8List? bytes = excel.encode() != null
          ? Uint8List.fromList(excel.encode()!)
          : null;
      if (bytes == null) throw Exception('Gagal encode Excel');

      messenger.hideCurrentSnackBar();

      final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'laporan_finance_reimbursement_$ts.xlsx';

      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }

      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Excel berhasil dibuat — ${data.length} data, $_periodLabel')),
        ]),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Gagal membuat Excel: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }
}

class _StatusFilter {
  final String? value;
  final String label;

  const _StatusFilter(this.value, this.label);
}

enum _AttachmentKind { userReceipt, paymentProof }

class _FinanceTab {
  final IconData icon;
  final String label;
  final int index;

  const _FinanceTab(this.icon, this.label, this.index);
}

class _SideStat {
  final String label;
  final int value;
  final Color color;

  const _SideStat(this.label, this.value, this.color);
}
