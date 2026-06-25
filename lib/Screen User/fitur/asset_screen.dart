// Screen User/fitur/asset_screen.dart — FULL REPLACE
// Terhubung ke AssetService. Kategori dinamis dari DB. Desain diperbarui.
// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:absensikaryawan/Services/asset_service.dart';
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:absensikaryawan/Services/inventory_service.dart';

enum AssetCategory { dipinjam, diambil }

enum AssetStatus { pending, approved, rejected, dikembalikan }

extension AssetStatusX on AssetStatus {
  Color get color {
    switch (this) {
      case AssetStatus.pending:
        return const Color(0xFFD97706);
      case AssetStatus.approved:
        return const Color(0xFF10B981);
      case AssetStatus.rejected:
        return const Color(0xFFEF4444);
      case AssetStatus.dikembalikan:
        return const Color(0xFF6366F1);
    }
  }

  String get label {
    switch (this) {
      case AssetStatus.pending:
        return 'Menunggu';
      case AssetStatus.approved:
        return 'Disetujui';
      case AssetStatus.rejected:
        return 'Ditolak';
      case AssetStatus.dikembalikan:
        return 'Dikembalikan';
    }
  }

  IconData get icon {
    switch (this) {
      case AssetStatus.pending:
        return Icons.hourglass_top_rounded;
      case AssetStatus.approved:
        return Icons.check_circle_rounded;
      case AssetStatus.rejected:
        return Icons.cancel_rounded;
      case AssetStatus.dikembalikan:
        return Icons.assignment_return_rounded;
    }
  }

  static AssetStatus fromApi(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'approved':
        return AssetStatus.approved;
      case 'rejected':
        return AssetStatus.rejected;
      case 'dikembalikan':
        return AssetStatus.dikembalikan;
      default:
        return AssetStatus.pending;
    }
  }
}

extension AssetCategoryX on AssetCategory {
  String get label => this == AssetCategory.dipinjam ? 'Dipinjam' : 'Diambil';
  Color get color => this == AssetCategory.dipinjam
      ? const Color(0xFF6366F1)
      : const Color(0xFF10B981);
  IconData get icon => this == AssetCategory.dipinjam
      ? Icons.swap_horiz_rounded
      : Icons.shopping_basket_rounded;
  String get apiValue =>
      this == AssetCategory.dipinjam ? 'dipinjam' : 'diambil';

  static AssetCategory fromApi(String? s) =>
      s == 'diambil' ? AssetCategory.diambil : AssetCategory.dipinjam;
}

const _heroGradient = LinearGradient(
  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AssetScreen extends StatefulWidget {
  final String userId;
  const AssetScreen({super.key, required this.userId});

  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  List<AssetItemModel> _catalogItems = [];
  List<AssetItemModel> _allItems = [];
  List<AssetRequestModel> _myRequests = [];
  List<AssetCategoryModel> _categories = [];

  bool _isLoadingCatalog = false;
  bool _isLoadingRequests = false;
  bool _isLoadingStock = false;
  bool _isCheckingAccess = true;
  bool _canManageStock = false;
  bool _isHeadHrd = false;

  AssetCategoryModel? _filterKategori; // filter aktif di tab Katalog
  List<AssetOfficeModel> _offices = [];

  // Laporan (Head HRD only)
  List<AssetReportPeriodModel> _reportPeriods = [];
  List<AssetReportEmployeeModel> _reportEmployees = [];
  AssetReportPeriodModel? _selectedReportPeriod;
  AssetReportEmployeeModel? _selectedReportEmployee;
  bool _isLoadingReportPeriods = false;
  bool _isLoadingReportEmployees = false;
  bool _isGeneratingReport = false;

  // Inventaris (Head HRD only)
  List<InventoryItemModel> _inventoryItems = [];
  bool _isLoadingInventory = false;
  String? _inventoryStatusFilter; // null = semua
  int? _exportingItemId;

  int get _tabCount => 2 + (_canManageStock ? 1 : 0) + (_isHeadHrd ? 2 : 0);

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  /// Serialize initial loads supaya tidak ada race condition di
  /// TokenService.getToken() saat banyak request dipanggil bersamaan
  /// pada kondisi token belum ter-cache atau sudah expire.
  /// Token di-fetch sekali dulu (warmUp), baru semua request jalan.
  Future<void> _initialLoad() async {
    // Step 1: pastikan token valid sebelum semua request
    await AssetService.warmUpToken();
    if (!mounted) return;

    // Step 2: cek akses (sequential, karena hasil ini menentukan tab count)
    await _initAccessAndTabs();
    if (!mounted) return;

    // Step 3: load data dasar secara paralel (token sudah pasti valid)
    await Future.wait([
      _loadCategories(),
      _loadCatalog(),
      _loadMyRequests(),
      _loadOffices(),
    ]);
  }

  Future<void> _loadOffices() async {
    final res = await AssetService.getOffices();
    if (mounted && res.success && res.data != null) {
      setState(() => _offices = res.data!);
    }
  }

  Future<void> _initAccessAndTabs() async {
    final results = await Future.wait([
      AssetService.canManageStock(userId: widget.userId),
      AssetService.isHeadHrd(userId: widget.userId),
    ]);
    if (!mounted) return;
    final canManage = results[0];
    final isHead = results[1];
    setState(() {
      _canManageStock = canManage;
      _isHeadHrd = isHead;
      _isCheckingAccess = false;
      _tabController = TabController(length: _tabCount, vsync: this);
    });

    // Jalankan load data tambahan secara paralel — token sudah pasti valid
    // karena warmUpToken() sudah dipanggil sebelum method ini.
    await Future.wait([
      if (canManage) _loadAllItems(),
      if (isHead) _loadReportPeriods(),
      if (isHead) _loadInventoryItems(),
    ]);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final res = await AssetService.getCategories(userId: widget.userId);
    if (mounted && res.success && res.data != null) {
      setState(() => _categories = res.data!);
    }
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoadingCatalog = true);
    final res = await AssetService.getCatalog(
      userId: widget.userId,
      kategoriId: _filterKategori?.id,
    );
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) _catalogItems = res.data!;
        _isLoadingCatalog = false;
      });
    }
  }

  Future<void> _loadMyRequests() async {
    setState(() => _isLoadingRequests = true);
    final res = await AssetService.getMyRequests(userId: widget.userId);
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) _myRequests = res.data!;
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _loadAllItems() async {
    setState(() => _isLoadingStock = true);
    final res = await AssetService.getAllItems(userId: widget.userId);
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) _allItems = res.data!;
        _isLoadingStock = false;
      });
    }
  }

  // ── Laporan (Head HRD only) ──────────────────────────────────────────────
  Future<void> _loadReportPeriods() async {
    setState(() => _isLoadingReportPeriods = true);
    final res = await AssetService.getReportPeriods();
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) _reportPeriods = res.data!;
        _isLoadingReportPeriods = false;
      });
    }
  }

  Future<void> _loadReportEmployees(AssetReportPeriodModel period) async {
    setState(() {
      _selectedReportPeriod = period;
      _selectedReportEmployee = null;
      _reportEmployees = [];
      _isLoadingReportEmployees = true;
    });
    final res = await AssetService.getReportEmployees(workPeriodId: period.id);
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) _reportEmployees = res.data!;
        _isLoadingReportEmployees = false;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedReportPeriod == null || _selectedReportEmployee == null) {
      _snack('Pilih periode dan karyawan terlebih dahulu', err: true);
      return;
    }

    setState(() => _isGeneratingReport = true);
    final res = await AssetService.generateReport(
      userId: _selectedReportEmployee!.userId,
      workPeriodId: _selectedReportPeriod!.id,
      requestedBy: widget.userId,
    );
    if (!mounted) return;
    setState(() => _isGeneratingReport = false);

    if (!res.success || res.data == null) {
      _snack(res.message, err: true);
      return;
    }

    final fileName =
        'Laporan_Asset_${_selectedReportEmployee!.name.replaceAll(' ', '_')}_'
        '${_selectedReportPeriod!.bulan.toString().padLeft(2, '0')}${_selectedReportPeriod!.tahun}.pdf';
    final bytes = res.data!;

    try {
      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
        _snack('Laporan berhasil diunduh');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _snack(
            'File tersimpan, tapi tidak bisa dibuka otomatis: ${result.message}',
          );
        } else {
          _snack('Laporan berhasil dibuat');
        }
      }
    } catch (e) {
      _snack('Gagal menyimpan file: $e', err: true);
    }
  }

  // ── Inventaris (Head HRD only) ───────────────────────────────────────────
  Future<void> _loadInventoryItems() async {
    setState(() => _isLoadingInventory = true);
    final res = await InventoryService.getAllItems(
      userId: widget.userId,
      status: _inventoryStatusFilter,
    );
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) _inventoryItems = res.data!;
        _isLoadingInventory = false;
      });
    }
  }

  void _openInventoryForm({InventoryItemModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventoryItemForm(
        userId: widget.userId,
        existing: existing,
        offices: _offices,
        onSaved: _loadInventoryItems,
      ),
    );
  }

  Future<void> _deleteInventoryItem(InventoryItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Barang Inventaris'),
        content: Text(
          'Hapus "${item.namaBarang}" (${item.kodeAset}) dari inventaris?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await InventoryService.deleteItem(
      id: item.id,
      userId: widget.userId,
    );
    if (!mounted) return;
    _snack(res.message, err: !res.success);
    if (res.success) _loadInventoryItems();
  }

  void _openAssignSheet(InventoryItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventoryAssignSheet(
        userId: widget.userId,
        item: item,
        onDone: _loadInventoryItems,
      ),
    );
  }

  Future<void> _returnInventoryItem(InventoryItemModel item) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tarik Kembali Barang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tarik "${item.namaBarang}" dari ${item.penanggungJawabName ?? "-"}?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Catatan (opsional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tarik'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await InventoryService.returnItem(
      inventoryItemId: item.id,
      catatan: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
      userId: widget.userId,
    );
    if (!mounted) return;
    _snack(res.message, err: !res.success);
    if (res.success) _loadInventoryItems();
  }

  Future<void> _exportHandoverDoc(InventoryItemModel item) async {
    setState(() => _exportingItemId = item.id);
    final res = await InventoryService.generateHandoverDoc(
      inventoryItemId: item.id,
      userId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _exportingItemId = null);

    if (!res.success || res.data == null) {
      _snack(res.message, err: true);
      return;
    }

    final fileName =
        'BA_Serah_Terima_${item.kodeAset.replaceAll('/', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final bytes = res.data!;

    try {
      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
        _snack('Dokumen berhasil diunduh');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _snack(
            'File tersimpan, tapi tidak bisa dibuka otomatis: ${result.message}',
          );
        } else {
          _snack('Dokumen berhasil dibuat');
        }
      }
    } catch (e) {
      _snack('Gagal menyimpan file: $e', err: true);
    }
  }

  Future<void> _markConditionDialog(InventoryItemModel item) async {
    String selectedKondisi = 'Rusak Ringan';
    final ctrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Tandai Kondisi Barang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.namaBarang} (${item.kodeAset})'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedKondisi,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Rusak Ringan',
                    child: Text('Rusak Ringan'),
                  ),
                  DropdownMenuItem(
                    value: 'Rusak Berat',
                    child: Text('Rusak Berat'),
                  ),
                  DropdownMenuItem(value: 'Hilang', child: Text('Hilang')),
                ],
                onChanged: (v) =>
                    setDlg(() => selectedKondisi = v ?? selectedKondisi),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Catatan (opsional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    final res = await InventoryService.markCondition(
      inventoryItemId: item.id,
      kondisiBaru: selectedKondisi,
      catatan: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
      userId: widget.userId,
    );
    if (!mounted) return;
    _snack(res.message, err: !res.success);
    if (res.success) _loadInventoryItems();
  }

  void _showHandoverLog(InventoryItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventoryHandoverLogSheet(item: item),
    );
  }

  Future<void> _refreshAll() async {
    // Warmup token dulu sebelum semua request paralel — mencegah
    // race condition kalau token kebetulan expire saat refresh.
    await AssetService.warmUpToken();
    if (!mounted) return;

    await Future.wait([
      _loadCategories(),
      _loadCatalog(),
      _loadMyRequests(),
      if (_canManageStock) _loadAllItems(),
      if (_isHeadHrd) _loadReportPeriods(),
      if (_isHeadHrd) _loadInventoryItems(),
    ]);
  }

  void _openRequestForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssetRequestForm(
        userId: widget.userId,
        catalogItems: _catalogItems,
        categories: _categories,
        onSubmitted: () {
          _loadCatalog();
          _loadMyRequests();
        },
      ),
    );
  }

  void _openStockForm({AssetItemModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockItemForm(
        userId: widget.userId,
        existing: existing,
        categories: _categories,
        offices: _offices,
        onSaved: () {
          _loadAllItems();
          _loadCatalog();
        },
        onCategoryChanged: _loadCategories,
      ),
    );
  }

  Future<void> _deleteStockItem(AssetItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Barang'),
        content: Text('Hapus "${item.namaBarang}" dari daftar stok?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await AssetService.deleteItem(
      id: item.id,
      userId: widget.userId,
    );
    if (!mounted) return;
    _snack(res.message, err: !res.success);
    if (res.success) _loadAllItems();
  }

  Future<void> _toggleAktif(AssetItemModel item) async {
    final res = await AssetService.toggleItemAktif(
      id: item.id,
      userId: widget.userId,
    );
    if (!mounted) return;
    _snack(res.message, err: !res.success);
    if (res.success) {
      _loadAllItems();
      _loadCatalog();
    }
  }

  void _snack(
    String msg, {
    bool err = false,
  }) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            err ? Icons.error_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      backgroundColor: err ? const Color(0xFFEF4444) : const Color(0xFF10B981),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess || _tabController == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Container(
          decoration: const BoxDecoration(gradient: _heroGradient),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 132,
            backgroundColor: const Color(0xFF4F46E5),
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _refreshAll,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 56),
              title: const Text(
                'Asset Kantor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(gradient: _heroGradient),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 160,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: const Color(0xFF4F46E5),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: _canManageStock,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    const Tab(text: 'Katalog'),
                    const Tab(text: 'Pengajuan Saya'),
                    if (_canManageStock) const Tab(text: 'Kelola Stok'),
                    if (_isHeadHrd) const Tab(text: 'Laporan'),
                    if (_isHeadHrd) const Tab(text: 'Inventaris'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCatalogTab(),
            _buildMyRequestsTab(),
            if (_canManageStock) _buildStockManagementTab(),
            if (_isHeadHrd) _buildReportTab(),
            if (_isHeadHrd) _buildInventoryTab(),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController!,
        builder: (_, __) {
          final stockTabIndex = _canManageStock ? 2 : -1;
          final reportTabIndex = _isHeadHrd
              ? (2 + (_canManageStock ? 1 : 0))
              : -1;
          final inventoryTabIndex = _isHeadHrd
              ? (3 + (_canManageStock ? 1 : 0))
              : -1;
          final idx = _tabController!.index;

          if (idx == reportTabIndex) {
            // Tab Laporan tidak butuh FAB — generate via tombol di body
            return const SizedBox.shrink();
          }

          if (idx == inventoryTabIndex) {
            return FloatingActionButton.extended(
              onPressed: () => _openInventoryForm(),
              backgroundColor: const Color(0xFF0EA5E9),
              elevation: 3,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Tambah Inventaris',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final onKelolaStok = idx == stockTabIndex;
          return FloatingActionButton.extended(
            onPressed: onKelolaStok ? () => _openStockForm() : _openRequestForm,
            backgroundColor: onKelolaStok
                ? const Color(0xFFEA580C)
                : const Color(0xFF4F46E5),
            elevation: 3,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              onKelolaStok ? 'Tambah Barang' : 'Ajukan',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── TAB 1: Katalog ──────────────────────────────────────────────────────
  Widget _buildCatalogTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        slivers: [
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(child: _buildCategoryFilterChips()),
          if (_isLoadingCatalog)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              ),
            )
          else if (_catalogItems.isEmpty)
            SliverFillRemaining(child: _buildEmptyCatalog())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  // Adaptif: makin lebar layar, makin banyak kolom,
                  // supaya card tidak raksasa di web/tablet.
                  final crossAxisCount = width >= 1100
                      ? 6
                      : width >= 850
                      ? 5
                      : width >= 600
                      ? 4
                      : width >= 420
                      ? 3
                      : 2;
                  const spacing = 12.0;
                  final columnWidth =
                      (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
                  // Tinggi = gambar persegi (columnWidth) + area teks tetap
                  // (nama 1 baris + badge stok + padding). Dihitung eksplisit
                  // supaya tidak overflow di ukuran layar manapun, beda
                  // dengan childAspectRatio yang gampang meleset.
                  const textAreaHeight = 62.0;
                  final mainAxisExtent = columnWidth + textAreaHeight;

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: mainAxisExtent,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildCatalogGridCard(_catalogItems[i]),
                      childCount: _catalogItems.length,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _filterChip(
              null,
              'Semua',
              const Color(0xFF4F46E5),
              Icons.apps_rounded,
            ),
            ..._categories.map(
              (c) => _filterChip(c, c.namaKategori, c.color, c.icon),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    AssetCategoryModel? cat,
    String label,
    Color color,
    IconData icon,
  ) {
    final selected = _filterKategori?.id == cat?.id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _filterKategori = cat);
          _loadCatalog();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCatalog() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Barang',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _canManageStock
                ? 'Tambahkan barang via tab "Kelola Stok"'
                : 'Belum ada barang yang tersedia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    ),
  );

  Widget _buildCatalogGridCard(AssetItemModel item) {
    final lowStock = item.stok <= 5;
    final c = item.categoryColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gambar dibatasi rasio tetap (1:1), TIDAK pakai Expanded —
          // supaya tidak ikut membesar di grid kolom sedikit / layar lebar.
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.withOpacity(0.18), c.withOpacity(0.06)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: item.hasGambar
                  ? _AssetThumbImage(itemId: item.id)
                  : Center(child: Icon(item.categoryIcon, color: c, size: 32)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.namaBarang,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lowStock
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Stok ${item.stok}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: lowStock
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
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

  // ── TAB 2: Pengajuan Saya ────────────────────────────────────────────────
  Widget _buildMyRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }
    if (_myRequests.isEmpty) return _buildEmptyRequests();

    return RefreshIndicator(
      onRefresh: _loadMyRequests,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _myRequests.length,
        itemBuilder: (_, i) => _buildRequestCard(_myRequests[i]),
      ),
    );
  }

  Widget _buildRequestCard(AssetRequestModel req) {
    final kategori = AssetCategoryX.fromApi(req.kategori);
    final status = AssetStatusX.fromApi(req.status);
    final c = kategori.color;
    final sc = status.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.withOpacity(0.10), c.withOpacity(0.02)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(kategori.icon, size: 15, color: c),
                ),
                const SizedBox(width: 8),
                Text(
                  kategori.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.icon, size: 11, color: sc),
                      const SizedBox(width: 4),
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: sc,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.namaBarang,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jumlah: ${req.jumlah}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Diajukan ${DateFormat('dd MMM yyyy').format(req.tanggalPengajuan)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (req.tanggalKembali != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_return_rounded,
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Dikembalikan ${DateFormat('dd MMM yyyy').format(req.tanggalKembali!)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
                if (req.catatan?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      req.catatan!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
                if (status == AssetStatus.rejected &&
                    req.rejectionReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            req.rejectionReason!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFB91C1C),
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
        ],
      ),
    );
  }

  Widget _buildEmptyRequests() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Pengajuan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ajukan peminjaman atau pengambilan barang via tombol +',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    ),
  );

  // ── TAB 3: Kelola Stok ───────────────────────────────────────────────────
  Widget _buildStockManagementTab() {
    if (_isLoadingStock) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFEA580C)),
      );
    }
    if (_allItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllItems,
        child: ListView(children: [_buildEmptyStock()]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllItems,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _allItems.length,
        itemBuilder: (_, i) => _buildStockCard(_allItems[i]),
      ),
    );
  }

  Widget _buildEmptyStock() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.warehouse_rounded,
            size: 48,
            color: Color(0xFFEA580C),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Belum Ada Barang',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tambahkan barang via tombol "Tambah Barang"',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    ),
  );

  Widget _buildStockCard(AssetItemModel item) {
    final lowStock = item.stok <= 5;
    final c = item.categoryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.withOpacity(0.18), c.withOpacity(0.06)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.hasGambar
                      ? _AssetThumbImage(itemId: item.id)
                      : Icon(item.categoryIcon, color: c, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.namaBarang,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          if (!item.aktif)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Nonaktif',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.kategori,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: c,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (item.deskripsi?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.deskripsi!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: lowStock
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 13,
                        color: lowStock
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Stok: ${item.stok}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: lowStock
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _iconBtn(
                  item.aktif
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  item.aktif ? const Color(0xFF10B981) : Colors.grey[400]!,
                  30,
                  () => _toggleAktif(item),
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  Icons.edit_outlined,
                  const Color(0xFF4F46E5),
                  19,
                  () => _openStockForm(existing: item),
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  Icons.delete_outline_rounded,
                  Colors.red[400]!,
                  19,
                  () => _deleteStockItem(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    Color color,
    double size,
    VoidCallback onTap,
  ) => Material(
    color: color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, size: size, color: color),
      ),
    ),
  );

  // ── TAB 4: Laporan (Head HRD only) ───────────────────────────────────────
  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: _heroGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan Asset Karyawan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pilih periode kerja & karyawan untuk unduh laporan .pdf',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            '1. Pilih Periode Kerja',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _isLoadingReportPeriods
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                )
              : _reportPeriods.isEmpty
              ? _reportEmptyHint(
                  'Belum ada periode kerja. Atur dulu di menu Kelola Kalender → Periode.',
                )
              : _buildReportPeriodDropdown(),

          if (_selectedReportPeriod != null) ...[
            const SizedBox(height: 20),
            const Text(
              '2. Pilih Karyawan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Hanya karyawan dengan pengajuan disetujui pada periode ini.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 10),
            _isLoadingReportEmployees
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  )
                : _reportEmployees.isEmpty
                ? _reportEmptyHint(
                    'Tidak ada karyawan dengan transaksi disetujui pada periode ini.',
                  )
                : _buildReportEmployeeList(),
          ],

          const SizedBox(height: 24),

          if (_selectedReportPeriod != null && _selectedReportEmployee != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingReport ? null : _generateReport,
                icon: _isGeneratingReport
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _isGeneratingReport
                      ? 'Membuat laporan...'
                      : 'Unduh Laporan (.pdf)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _reportEmptyHint(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 17, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ],
    ),
  );

  Widget _buildReportPeriodDropdown() {
    // Pakai id (int) sebagai value dropdown, BUKAN objek model langsung —
    // karena AssetReportPeriodModel tidak override ==/hashCode, jadi
    // setiap reload list bikin objek baru yang identity-nya beda walau
    // datanya sama, menyebabkan assertion error "should be exactly one item".
    final selectedId = _selectedReportPeriod?.id;
    final validIds = _reportPeriods.map((p) => p.id).toSet();
    final dropdownValue = (selectedId != null && validIds.contains(selectedId))
        ? selectedId
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: dropdownValue,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemHeight: 56,
          hint: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Pilih periode...',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ),
          selectedItemBuilder: (context) => _reportPeriods
              .map(
                (p) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    p.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          items: _reportPeriods
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (p.keterangan?.isNotEmpty == true)
                        Text(
                          p.keterangan!,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (selectedPeriodId) {
            if (selectedPeriodId == null) return;
            final period = _reportPeriods.firstWhere(
              (p) => p.id == selectedPeriodId,
            );
            _loadReportEmployees(period);
          },
        ),
      ),
    );
  }

  Widget _buildReportEmployeeList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: _reportEmployees.asMap().entries.map((entry) {
          final i = entry.key;
          final emp = entry.value;
          final selected = _selectedReportEmployee?.userId == emp.userId;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1, indent: 56),
              InkWell(
                onTap: () => setState(() => _selectedReportEmployee = emp),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  color: selected
                      ? const Color(0xFF4F46E5).withOpacity(0.06)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: selected
                            ? const Color(0xFF4F46E5)
                            : Colors.grey[200],
                        child: Text(
                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (emp.jobPosition?.isNotEmpty == true)
                              Text(
                                emp.jobPosition!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${emp.jumlahTransaksi} transaksi',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── TAB 5: Inventaris (Head HRD only) ────────────────────────────────────
  Widget _buildInventoryTab() {
    return RefreshIndicator(
      onRefresh: _loadInventoryItems,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Header Inventaris: ringkasan total barang ────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inventaris Kantor',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_inventoryItems.length} barang terdaftar',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Filter status ──────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _inventoryFilterChip(null, 'Semua', const Color(0xFF0EA5E9)),
                _inventoryFilterChip(
                  'Tersedia',
                  'Tersedia',
                  const Color(0xFF10B981),
                ),
                _inventoryFilterChip(
                  'Dipinjam',
                  'Dipinjam',
                  const Color(0xFF6366F1),
                ),
                _inventoryFilterChip('Rusak', 'Rusak', const Color(0xFFF59E0B)),
                _inventoryFilterChip(
                  'Hilang',
                  'Hilang',
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoadingInventory)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
              ),
            )
          else if (_inventoryItems.isEmpty)
            _buildEmptyInventory()
          else
            ..._inventoryItems.map(_buildInventoryCard),
        ],
      ),
    );
  }

  Widget _inventoryFilterChip(String? status, String label, Color color) {
    final selected = _inventoryStatusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _inventoryStatusFilter = status);
          _loadInventoryItems();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInventory() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_rounded,
              size: 48,
              color: Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Barang Inventaris',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tambahkan via tombol "Tambah Inventaris"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    ),
  );

  Widget _buildInventoryCard(InventoryItemModel item) {
    final c = item.statusColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.withOpacity(0.18), c.withOpacity(0.06)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.hasGambar
                      ? _InventoryThumbImage(itemId: item.id)
                      : Icon(item.kategoriIcon, color: c, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaBarang,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.kodeAset} • ${item.kategori}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (item.merk?.isNotEmpty == true)
                        Text(
                          item.merk!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: c,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (item.dipinjam && item.penanggungJawabName != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 13,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Dipegang: ${item.penanggungJawabName}${item.penanggungJawabJob != null ? " (${item.penanggungJawabJob})" : ""}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (item.tersedia)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAssignSheet(item),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 14,
                      ),
                      label: const Text(
                        'Serahkan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                if (item.dipinjam) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _returnInventoryItem(item),
                      icon: const Icon(
                        Icons.assignment_return_rounded,
                        size: 14,
                      ),
                      label: const Text(
                        'Tarik',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportingItemId == item.id
                          ? null
                          : () => _exportHandoverDoc(item),
                      icon: _exportingItemId == item.id
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 14),
                      label: Text(
                        _exportingItemId == item.id ? '...' : 'Export PDF',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                _iconBtn(
                  Icons.history_rounded,
                  Colors.grey[600]!,
                  18,
                  () => _showHandoverLog(item),
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  Icons.report_problem_outlined,
                  Colors.orange[700]!,
                  18,
                  () => _markConditionDialog(item),
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  Icons.edit_outlined,
                  const Color(0xFF4F46E5),
                  18,
                  () => _openInventoryForm(existing: item),
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  Icons.delete_outline_rounded,
                  Colors.red[400]!,
                  18,
                  () => _deleteInventoryItem(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryThumbImage extends StatefulWidget {
  final int itemId;
  const _InventoryThumbImage({required this.itemId});

  @override
  State<_InventoryThumbImage> createState() => _InventoryThumbImageState();
}

class _InventoryThumbImageState extends State<_InventoryThumbImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await InventoryService.getItemImage(id: widget.itemId);
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) {
          _bytes = Uint8List.fromList(res.data!);
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_bytes == null) {
      return Icon(Icons.broken_image_outlined, color: Colors.grey[400]);
    }
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _AssetThumbImage extends StatefulWidget {
  final int itemId;
  const _AssetThumbImage({required this.itemId});

  @override
  State<_AssetThumbImage> createState() => _AssetThumbImageState();
}

class _AssetThumbImageState extends State<_AssetThumbImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await AssetService.getItemImage(id: widget.itemId);
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) {
          _bytes = Uint8List.fromList(res.data!);
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_bytes == null) {
      return Icon(Icons.broken_image_outlined, color: Colors.grey[400]);
    }
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

// ── Bottom Sheet Form Pengajuan ─────────────────────────────────────────────
class _AssetRequestForm extends StatefulWidget {
  final String userId;
  final List<AssetItemModel> catalogItems;
  final List<AssetCategoryModel> categories;
  final VoidCallback onSubmitted;

  const _AssetRequestForm({
    required this.userId,
    required this.catalogItems,
    required this.categories,
    required this.onSubmitted,
  });

  @override
  State<_AssetRequestForm> createState() => _AssetRequestFormState();
}

class _AssetRequestFormState extends State<_AssetRequestForm> {
  AssetCategory _kategori = AssetCategory.dipinjam;
  AssetItemModel? _selectedItem;
  int _jumlah = 1;
  final _catatanCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  // Heuristik: "Diambil (habis pakai)" -> tampilkan kategori bernama mengandung "ATK"
  // kalau ada; kalau tidak ada, tampilkan semua barang stok kecil. Simplifikasi:
  // kategori barang sekarang dinamis, jadi filter berdasar nama kategori yang dipilih user.
  List<AssetItemModel> get _filteredItems => widget.catalogItems;

  Future<void> _submit() async {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih barang terlebih dahulu')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final res = await AssetService.createRequest(
      userId: widget.userId,
      assetItemId: _selectedItem!.id,
      kategori: _kategori.apiValue,
      jumlah: _jumlah,
      catatan: _catatanCtrl.text.trim().isEmpty
          ? null
          : _catatanCtrl.text.trim(),
    );

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context);
      final autoApproved = res.data?['autoApproved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  autoApproved
                      ? 'Pengajuan otomatis disetujui'
                      : 'Pengajuan berhasil dikirim',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      widget.onSubmitted();
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _kategori.color;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: _heroGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Ajukan Asset',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  const Text(
                    'Jenis Pengajuan',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKategoriChip(
                          AssetCategory.dipinjam,
                          'Dipinjam',
                          'Wajib dikembalikan',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildKategoriChip(
                          AssetCategory.diambil,
                          'Diambil',
                          'Habis pakai',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Pilih Barang',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _showItemPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: _selectedItem == null ? Colors.grey[400] : c,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedItem?.namaBarang ??
                                  'Pilih barang dari katalog',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedItem == null
                                    ? FontWeight.w400
                                    : FontWeight.w700,
                                color: _selectedItem == null
                                    ? Colors.grey[500]
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedItem != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Stok tersedia: ${_selectedItem!.stok}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Jumlah',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _qtyButton(Icons.remove_rounded, () {
                        if (_jumlah > 1) setState(() => _jumlah--);
                      }),
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(
                          '$_jumlah',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _qtyButton(Icons.add_rounded, () {
                        final max = _selectedItem?.stok ?? 999;
                        if (_jumlah < max) setState(() => _jumlah++);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Catatan / Keperluan',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _catatanCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Contoh: untuk presentasi klien...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Kirim Pengajuan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriChip(AssetCategory kat, String label, String sub) {
    final selected = _kategori == kat;
    final c = kat.color;
    return GestureDetector(
      onTap: () => setState(() {
        _kategori = kat;
        _selectedItem = null;
        _jumlah = 1;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(kat.icon, color: selected ? c : Colors.grey[400], size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? c : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) => Material(
    color: const Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF374151)),
      ),
    ),
  );

  void _showItemPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Pilih Barang',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Tidak ada barang tersedia',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filteredItems.length,
                      itemBuilder: (_, i) {
                        final item = _filteredItems[i];
                        final ic = item.categoryColor;
                        return ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  ic.withOpacity(0.18),
                                  ic.withOpacity(0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item.hasGambar
                                ? _AssetThumbImage(itemId: item.id)
                                : Icon(item.categoryIcon, color: ic, size: 19),
                          ),
                          title: Text(
                            item.namaBarang,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Stok: ${item.stok}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedItem = item;
                              _jumlah = 1;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet Form Tambah/Edit Barang ────────────────────────────────────
class _StockItemForm extends StatefulWidget {
  final String userId;
  final AssetItemModel? existing;
  final List<AssetCategoryModel> categories;
  final List<AssetOfficeModel> offices;
  final VoidCallback onSaved;
  final VoidCallback onCategoryChanged;

  const _StockItemForm({
    required this.userId,
    this.existing,
    required this.categories,
    required this.offices,
    required this.onSaved,
    required this.onCategoryChanged,
  });

  @override
  State<_StockItemForm> createState() => _StockItemFormState();
}

class _StockItemFormState extends State<_StockItemForm> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _stokCtrl;
  late final TextEditingController _deskripsiCtrl;
  AssetCategoryModel? _kategori;
  AssetOfficeModel? _office;
  bool _isSaving = false;
  Uint8List? _pickedImageBytes;
  String? _pickedImageFileName;
  bool _hadExistingImage = false;
  bool _imageChanged = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.existing?.namaBarang ?? '');
    _stokCtrl = TextEditingController(
      text: widget.existing?.stok.toString() ?? '',
    );
    _deskripsiCtrl = TextEditingController(
      text: widget.existing?.deskripsi ?? '',
    );

    if (widget.existing?.kategoriId != null) {
      _kategori =
          widget.categories
              .where((c) => c.id == widget.existing!.kategoriId)
              .isNotEmpty
          ? widget.categories.firstWhere(
              (c) => c.id == widget.existing!.kategoriId,
            )
          : (widget.categories.isNotEmpty ? widget.categories.first : null);
    } else {
      _kategori = widget.categories.isNotEmpty ? widget.categories.first : null;
    }

    if (widget.existing?.officeLocationId != null) {
      _office =
          widget.offices
              .where((o) => o.id == widget.existing!.officeLocationId)
              .isNotEmpty
          ? widget.offices.firstWhere(
              (o) => o.id == widget.existing!.officeLocationId,
            )
          : (widget.offices.isNotEmpty ? widget.offices.first : null);
    } else {
      _office = widget.offices.isNotEmpty ? widget.offices.first : null;
    }

    _hadExistingImage = widget.existing?.hasGambar ?? false;
    if (_hadExistingImage) _loadExistingImage();
  }

  Future<void> _loadExistingImage() async {
    final res = await AssetService.getItemImage(id: widget.existing!.id);
    if (mounted && res.success && res.data != null) {
      setState(() => _pickedImageBytes = Uint8List.fromList(res.data!));
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _stokCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pilih sumber gambar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final img = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageFileName = img.name.isNotEmpty ? img.name : 'gambar.jpg';
        _imageChanged = true;
      });
    } catch (e) {
      _snack('Gagal memilih gambar: $e');
    }
  }

  void _removeImage() => setState(() {
    _pickedImageBytes = null;
    _pickedImageFileName = null;
    _imageChanged = true;
  });

  Future<void> _addNewCategory() async {
    final namaCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Kategori Baru'),
        content: TextField(
          controller: namaCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Contoh: Kendaraan',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true && namaCtrl.text.trim().isNotEmpty) {
      final res = await AssetService.createCategory(
        userId: widget.userId,
        namaKategori: namaCtrl.text.trim(),
      );
      if (mounted) {
        _snack(res.message, err: !res.success);
        if (res.success) widget.onCategoryChanged();
      }
    }
    namaCtrl.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final stokStr = _stokCtrl.text.trim();

    if (nama.isEmpty) {
      _snack('Nama barang wajib diisi');
      return;
    }
    if (_kategori == null) {
      _snack('Pilih kategori terlebih dahulu');
      return;
    }
    if (_office == null) {
      _snack('Pilih lokasi kantor terlebih dahulu');
      return;
    }
    final stok = int.tryParse(stokStr);
    if (stok == null || stok < 0) {
      _snack('Jumlah stok tidak valid');
      return;
    }

    setState(() => _isSaving = true);

    if (isEdit) {
      final res = await AssetService.updateItem(
        id: widget.existing!.id,
        userId: widget.userId,
        namaBarang: nama,
        kategoriId: _kategori!.id,
        officeLocationId: _office!.id,
        deskripsi: _deskripsiCtrl.text.trim().isEmpty
            ? null
            : _deskripsiCtrl.text.trim(),
        stok: stok,
        gantiGambar: _imageChanged,
        gambarBytes: _imageChanged ? _pickedImageBytes : null,
        gambarFileName: _pickedImageFileName,
      );
      if (!mounted) return;
      if (res.success) {
        Navigator.pop(context);
        widget.onSaved();
      } else {
        setState(() => _isSaving = false);
        _snack(res.message);
      }
    } else {
      final res = await AssetService.createItem(
        userId: widget.userId,
        namaBarang: nama,
        kategoriId: _kategori!.id,
        officeLocationId: _office!.id,
        deskripsi: _deskripsiCtrl.text.trim().isEmpty
            ? null
            : _deskripsiCtrl.text.trim(),
        stok: stok,
        gambarBytes: _pickedImageBytes,
        gambarFileName: _pickedImageFileName,
      );
      if (!mounted) return;
      if (res.success) {
        Navigator.pop(context);
        widget.onSaved();
      } else {
        setState(() => _isSaving = false);
        _snack(res.message);
      }
    }
  }

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          backgroundColor: err ? const Color(0xFFEF4444) : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.add_box_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit Barang' : 'Tambah Barang Baru',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto Barang',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImagePicker(),
                    const SizedBox(height: 16),
                    const Text(
                      'Nama Barang',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _namaCtrl,
                      decoration: _inputDecoration(
                        'Contoh: Laptop Lenovo ThinkPad',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Lokasi Kantor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stok barang ini khusus untuk kantor yang dipilih.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    widget.offices.isEmpty
                        ? Text(
                            'Memuat daftar kantor...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          )
                        : DropdownButtonFormField<AssetOfficeModel>(
                            value: _office,
                            decoration: _inputDecoration(null),
                            items: widget.offices
                                .map(
                                  (o) => DropdownMenuItem(
                                    value: o,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: Color(0xFF4F46E5),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          o.officeName,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _office = v),
                          ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kategori',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addNewCategory,
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            'Baru',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    widget.categories.isEmpty
                        ? Text(
                            'Belum ada kategori — tambah dulu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          )
                        : DropdownButtonFormField<AssetCategoryModel>(
                            value: _kategori,
                            decoration: _inputDecoration(null),
                            items: widget.categories
                                .map(
                                  (cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          cat.icon,
                                          size: 16,
                                          color: cat.color,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cat.namaKategori,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _kategori = v),
                          ),
                    const SizedBox(height: 16),
                    const Text(
                      'Jumlah Stok',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _stokCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Contoh: 10'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Deskripsi (opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deskripsiCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration('Contoh: i5, 16GB RAM'),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          isEdit ? 'Simpan Perubahan' : 'Tambah Barang',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _pickedImageBytes != null;
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_pickedImageBytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 34,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap untuk tambah foto',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.all(12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
    ),
  );
}

// ── Bottom Sheet Form Tambah/Edit Barang Inventaris ─────────────────────────
class _InventoryItemForm extends StatefulWidget {
  final String userId;
  final InventoryItemModel? existing;
  final List<AssetOfficeModel> offices;
  final VoidCallback onSaved;

  const _InventoryItemForm({
    required this.userId,
    this.existing,
    required this.offices,
    required this.onSaved,
  });

  @override
  State<_InventoryItemForm> createState() => _InventoryItemFormState();
}

class _InventoryItemFormState extends State<_InventoryItemForm> {
  late final TextEditingController _kodeAsetCtrl;
  late final TextEditingController _namaCtrl;
  late final TextEditingController _kategoriCtrl;
  late final TextEditingController _merkCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _spesifikasiCtrl;
  late final TextEditingController _hargaCtrl;
  AssetOfficeModel? _office;
  String _kondisi = 'Baik';
  DateTime? _tanggalPembelian;
  bool _isSaving = false;
  Uint8List? _pickedImageBytes;
  String? _pickedImageFileName;
  bool _imageChanged = false;

  bool get isEdit => widget.existing != null;

  static const _kategoriPreset = [
    'Laptop',
    'Printer',
    'Mouse',
    'Monitor',
    'Keyboard',
    'Handphone',
    'Kamera',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _kodeAsetCtrl = TextEditingController(
      text: widget.existing?.kodeAset ?? '',
    );
    _namaCtrl = TextEditingController(text: widget.existing?.namaBarang ?? '');
    _kategoriCtrl = TextEditingController(
      text: widget.existing?.kategori ?? '',
    );
    _merkCtrl = TextEditingController(text: widget.existing?.merk ?? '');
    _serialCtrl = TextEditingController(
      text: widget.existing?.serialNumber ?? '',
    );
    _spesifikasiCtrl = TextEditingController(
      text: widget.existing?.spesifikasi ?? '',
    );
    _hargaCtrl = TextEditingController(
      text: widget.existing?.hargaBeli?.toStringAsFixed(0) ?? '',
    );
    _kondisi = widget.existing?.kondisi ?? 'Baik';
    _tanggalPembelian = widget.existing?.tanggalPembelian;

    if (widget.existing?.officeLocationId != null) {
      _office =
          widget.offices
              .where((o) => o.id == widget.existing!.officeLocationId)
              .isNotEmpty
          ? widget.offices.firstWhere(
              (o) => o.id == widget.existing!.officeLocationId,
            )
          : (widget.offices.isNotEmpty ? widget.offices.first : null);
    } else {
      _office = widget.offices.isNotEmpty ? widget.offices.first : null;
    }

    if (widget.existing?.hasGambar == true) _loadExistingImage();
  }

  Future<void> _loadExistingImage() async {
    final res = await InventoryService.getItemImage(id: widget.existing!.id);
    if (mounted && res.success && res.data != null) {
      setState(() => _pickedImageBytes = Uint8List.fromList(res.data!));
    }
  }

  @override
  void dispose() {
    _kodeAsetCtrl.dispose();
    _namaCtrl.dispose();
    _kategoriCtrl.dispose();
    _merkCtrl.dispose();
    _serialCtrl.dispose();
    _spesifikasiCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final img = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageFileName = img.name.isNotEmpty ? img.name : 'gambar.jpg';
        _imageChanged = true;
      });
    } catch (e) {
      _snack('Gagal memilih gambar: $e');
    }
  }

  Future<void> _pickTanggalPembelian() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalPembelian ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _tanggalPembelian = picked);
  }

  Future<void> _save() async {
    final kodeAset = _kodeAsetCtrl.text.trim();
    final nama = _namaCtrl.text.trim();
    final kategori = _kategoriCtrl.text.trim();

    if (kodeAset.isEmpty) return _snack('Kode aset wajib diisi');
    if (nama.isEmpty) return _snack('Nama barang wajib diisi');
    if (kategori.isEmpty) return _snack('Kategori wajib diisi');
    if (_office == null) return _snack('Pilih lokasi kantor terlebih dahulu');

    final harga = _hargaCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_hargaCtrl.text.trim());

    setState(() => _isSaving = true);

    if (isEdit) {
      final res = await InventoryService.updateItem(
        id: widget.existing!.id,
        userId: widget.userId,
        kodeAset: kodeAset,
        namaBarang: nama,
        kategori: kategori,
        officeLocationId: _office!.id,
        merk: _merkCtrl.text.trim().isEmpty ? null : _merkCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim().isEmpty
            ? null
            : _serialCtrl.text.trim(),
        spesifikasi: _spesifikasiCtrl.text.trim().isEmpty
            ? null
            : _spesifikasiCtrl.text.trim(),
        kondisi: _kondisi,
        tanggalPembelian: _tanggalPembelian,
        hargaBeli: harga,
        gantiGambar: _imageChanged,
        gambarBytes: _imageChanged ? _pickedImageBytes : null,
        gambarFileName: _pickedImageFileName,
      );
      _handleResult(res.success, res.message);
    } else {
      final res = await InventoryService.createItem(
        userId: widget.userId,
        kodeAset: kodeAset,
        namaBarang: nama,
        kategori: kategori,
        officeLocationId: _office!.id,
        merk: _merkCtrl.text.trim().isEmpty ? null : _merkCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim().isEmpty
            ? null
            : _serialCtrl.text.trim(),
        spesifikasi: _spesifikasiCtrl.text.trim().isEmpty
            ? null
            : _spesifikasiCtrl.text.trim(),
        kondisi: _kondisi,
        tanggalPembelian: _tanggalPembelian,
        hargaBeli: harga,
        gambarBytes: _pickedImageBytes,
        gambarFileName: _pickedImageFileName,
      );
      _handleResult(res.success, res.message);
    }
  }

  void _handleResult(bool success, String message) {
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      widget.onSaved();
    } else {
      setState(() => _isSaving = false);
      _snack(message);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.add_box_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit Inventaris' : 'Tambah Inventaris',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto Barang',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImagePicker(),
                    const SizedBox(height: 16),
                    const Text(
                      'Kode Aset',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _kodeAsetCtrl,
                      decoration: _inputDecoration('Contoh: LPT-001'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nama Barang',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _namaCtrl,
                      decoration: _inputDecoration(
                        'Contoh: Laptop Dell Latitude 5420',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kategori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kategoriPreset
                          .map(
                            (k) => GestureDetector(
                              onTap: () =>
                                  setState(() => _kategoriCtrl.text = k),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _kategoriCtrl.text == k
                                      ? const Color(0xFF0EA5E9)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  k,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: _kategoriCtrl.text == k
                                        ? Colors.white
                                        : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _kategoriCtrl,
                      decoration: _inputDecoration('Atau ketik kategori lain'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Lokasi Kantor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    widget.offices.isEmpty
                        ? Text(
                            'Memuat daftar kantor...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          )
                        : DropdownButtonFormField<AssetOfficeModel>(
                            value: _office,
                            decoration: _inputDecoration(null),
                            items: widget.offices
                                .map(
                                  (o) => DropdownMenuItem(
                                    value: o,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: Color(0xFF0EA5E9),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          o.officeName,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _office = v),
                          ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Merk',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _merkCtrl,
                                decoration: _inputDecoration('Dell, HP...'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Serial Number',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _serialCtrl,
                                decoration: _inputDecoration('SN-xxxxx'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Spesifikasi (opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _spesifikasiCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration('i5, 16GB RAM, 512GB SSD'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kondisi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _kondisi,
                      decoration: _inputDecoration(null),
                      items: const [
                        DropdownMenuItem(value: 'Baik', child: Text('Baik')),
                        DropdownMenuItem(
                          value: 'Rusak Ringan',
                          child: Text('Rusak Ringan'),
                        ),
                        DropdownMenuItem(
                          value: 'Rusak Berat',
                          child: Text('Rusak Berat'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _kondisi = v ?? 'Baik'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tgl Pembelian (opsional)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickTanggalPembelian,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    _tanggalPembelian != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_tanggalPembelian!)
                                        : 'Pilih tanggal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _tanggalPembelian != null
                                          ? const Color(0xFF1F2937)
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Harga Beli (opsional)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _hargaCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Rp'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          isEdit ? 'Simpan Perubahan' : 'Tambah Barang',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _pickedImageBytes != null;
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_pickedImageBytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _pickedImageBytes = null;
                        _pickedImageFileName = null;
                        _imageChanged = true;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 34,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap untuk tambah foto',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.all(12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
    ),
  );
}

// ── Bottom Sheet Serahkan Barang ke Karyawan ─────────────────────────────────
// ── Bottom Sheet Serahkan Barang ke Karyawan (2 pihak: Penanggung Jawab +
// Admin Inventaris, dipilih per-transaksi oleh Head HRD) ───────────────────
class _InventoryAssignSheet extends StatefulWidget {
  final String userId;
  final InventoryItemModel item;
  final VoidCallback onDone;

  const _InventoryAssignSheet({
    required this.userId,
    required this.item,
    required this.onDone,
  });

  @override
  State<_InventoryAssignSheet> createState() => _InventoryAssignSheetState();
}

class _InventoryAssignSheetState extends State<_InventoryAssignSheet> {
  List<InventoryEligibleUserModel> _users = [];
  List<InventoryEligibleUserModel> _adminInventarisUsers = [];
  InventoryEligibleUserModel? _selectedPic;
  InventoryEligibleUserModel? _selectedAdmin;
  final _catatanCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      InventoryService.getAllActiveEmployees(
        userId: widget.userId,
      ), // semua karyawan -> penanggung jawab
      InventoryService.getEligibleAdminInventaris(
        userId: widget.userId,
      ), // khusus org 'Inventaris'
    ]);
    if (mounted) {
      setState(() {
        final picRes = results[0];
        final adminRes = results[1];
        if (picRes.success && picRes.data != null) _users = picRes.data!;
        if (adminRes.success && adminRes.data != null) {
          _adminInventarisUsers = adminRes.data!;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedPic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih penanggung jawab terlebih dahulu')),
      );
      return;
    }
    if (_selectedAdmin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih admin inventaris terlebih dahulu')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final res = await InventoryService.assign(
      inventoryItemId: widget.item.id,
      penanggungJawabUserId: _selectedPic!.userId,
      adminInventarisUserId: _selectedAdmin!.userId,
      catatan: _catatanCtrl.text.trim().isEmpty
          ? null
          : _catatanCtrl.text.trim(),
      userId: widget.userId,
    );
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context);
      widget.onDone();
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Widget _userPickerList({
    required String title,
    required List<InventoryEligibleUserModel> users,
    required InventoryEligibleUserModel? selected,
    required ValueChanged<InventoryEligibleUserModel> onSelect,
    required Color color,
    String? emptyHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (users.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    emptyHint ?? 'Tidak ada data',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          )
        else
          ...users.map((u) {
            final isSelected = selected?.userId == u.userId;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.06)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFE2E8F0),
                ),
              ),
              child: ListTile(
                onTap: () => onSelect(u),
                leading: CircleAvatar(
                  backgroundColor: isSelected ? color : Colors.grey[300],
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  u.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: u.jobPosition != null
                    ? Text(u.jobPosition!, style: const TextStyle(fontSize: 11))
                    : null,
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: color)
                    : null,
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Serahkan Barang',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.item.namaBarang} (${widget.item.kodeAset})',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      children: [
                        _userPickerList(
                          title: '1. Pilih Penanggung Jawab',
                          users: _users,
                          selected: _selectedPic,
                          onSelect: (u) => setState(() => _selectedPic = u),
                          color: const Color(0xFF6366F1),
                        ),
                        const SizedBox(height: 20),
                        _userPickerList(
                          title: '2. Pilih Admin Inventaris',
                          users: _adminInventarisUsers,
                          selected: _selectedAdmin,
                          onSelect: (u) => setState(() => _selectedAdmin = u),
                          color: const Color(0xFF0EA5E9),
                          emptyHint:
                              'Belum ada user dengan jabatan Admin Inventaris. Set organization karyawan terkait agar mengandung kata "Inventaris".',
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Catatan (opsional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _catatanCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Keperluan, kondisi saat serah terima...',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Serahkan Barang',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryHandoverLogSheet extends StatefulWidget {
  final InventoryItemModel item;
  const _InventoryHandoverLogSheet({required this.item});

  @override
  State<_InventoryHandoverLogSheet> createState() =>
      _InventoryHandoverLogSheetState();
}

class _InventoryHandoverLogSheetState
    extends State<_InventoryHandoverLogSheet> {
  List<InventoryHandoverLogModel> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await InventoryService.getHandoverLog(
      inventoryItemId: widget.item.id,
    );
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) _logs = res.data!;
        _isLoading = false;
      });
    }
  }

  Color _aksiColor(String aksi) {
    switch (aksi) {
      case 'Serah Terima':
        return const Color(0xFF6366F1);
      case 'Ditarik':
        return const Color(0xFF10B981);
      case 'Hilang':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _aksiIcon(String aksi) {
    switch (aksi) {
      case 'Serah Terima':
        return Icons.person_add_alt_1_rounded;
      case 'Ditarik':
        return Icons.assignment_return_rounded;
      case 'Hilang':
        return Icons.error_outline_rounded;
      default:
        return Icons.report_problem_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riwayat Serah Terima',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.item.namaBarang} (${widget.item.kodeAset})',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0EA5E9),
                      ),
                    )
                  : _logs.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      itemCount: _logs.length,
                      itemBuilder: (_, i) {
                        final log = _logs[i];
                        final c = _aksiColor(log.aksi);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.withOpacity(0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_aksiIcon(log.aksi), size: 18, color: c),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.aksi,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: c,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (log.penanggungJawabName != null)
                                      Text(
                                        'Penanggung jawab: ${log.penanggungJawabName}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    if (log.catatan?.isNotEmpty == true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          log.catatan!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('dd MMM yyyy, HH:mm').format(log.tanggal)} • oleh ${log.createdByName ?? log.createdBy}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }
}
