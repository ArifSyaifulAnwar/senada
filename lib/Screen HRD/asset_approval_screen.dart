// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Screen User/fitur/asset_screen.dart'
    show AssetCategory, AssetCategoryX;

// ── DUMMY MODEL (nanti diganti API) ─────────────────────────────────────────
class PendingAssetRequest {
  final int id;
  final String userId;
  final String userName;
  final String? userJob;
  final String namaBarang;
  final int jumlah;
  final AssetCategory kategori;
  final DateTime tanggalPengajuan;
  final String? catatan;
  final int daysWaiting;
  final int stokTersedia;

  const PendingAssetRequest({
    required this.id,
    required this.userId,
    required this.userName,
    this.userJob,
    required this.namaBarang,
    required this.jumlah,
    required this.kategori,
    required this.tanggalPengajuan,
    this.catatan,
    required this.daysWaiting,
    required this.stokTersedia,
  });
}

final _dummyPending = <PendingAssetRequest>[
  PendingAssetRequest(
    id: 1,
    userId: '24090029',
    userName: 'ARIF SYAIFUL ANWAR',
    userJob: 'STAFF OF IT',
    namaBarang: 'Laptop Lenovo ThinkPad',
    jumlah: 1,
    kategori: AssetCategory.dipinjam,
    tanggalPengajuan: DateTime.now().subtract(const Duration(days: 1)),
    catatan: 'Untuk presentasi klien minggu depan',
    daysWaiting: 1,
    stokTersedia: 3,
  ),
  PendingAssetRequest(
    id: 2,
    userId: '19020007',
    userName: 'KGS ABDUL MUJIB',
    userJob: 'STAFF OF IT',
    namaBarang: 'Kertas A4 80gr',
    jumlah: 10,
    kategori: AssetCategory.diambil,
    tanggalPengajuan: DateTime.now().subtract(const Duration(days: 4)),
    daysWaiting: 4,
    stokTersedia: 45,
  ),
  PendingAssetRequest(
    id: 3,
    userId: '23120024',
    userName: 'SATRIA AGUSTIAN',
    userJob: 'STAFF OF OPERATIONAL',
    namaBarang: 'Kamera DSLR Canon',
    jumlah: 1,
    kategori: AssetCategory.dipinjam,
    tanggalPengajuan: DateTime.now(),
    catatan: 'Dokumentasi acara perusahaan',
    daysWaiting: 0,
    stokTersedia: 1,
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
class AssetApprovalScreen extends StatefulWidget {
  final String userId;
  const AssetApprovalScreen({super.key, required this.userId});

  @override
  State<AssetApprovalScreen> createState() => _AssetApprovalScreenState();
}

class _AssetApprovalScreenState extends State<AssetApprovalScreen> {
  final List<PendingAssetRequest> _items = List.of(_dummyPending);
  bool _isLoading = false;
  int _processingId = -1;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _approve(PendingAssetRequest item) async {
    if (item.jumlah > item.stokTersedia) {
      _snack('Stok tidak mencukupi untuk disetujui', err: true);
      return;
    }
    final confirm = await _confirmDialog(
      'Setujui ${item.kategori.label.toLowerCase()} "${item.namaBarang}" '
      '(${item.jumlah}) oleh ${item.userName}?',
      item.kategori.color,
    );
    if (!confirm) return;
    await _doAction(item, true, null);
  }

  Future<void> _reject(PendingAssetRequest item) async {
    final reason = await _rejectDialog(item.userName);
    if (reason == null) return;
    await _doAction(item, false, reason);
  }

  Future<void> _doAction(
    PendingAssetRequest item,
    bool approved,
    String? reason,
  ) async {
    setState(() => _processingId = item.id);

    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() {
        _items.removeWhere((i) => i.id == item.id);
        _processingId = -1;
      });
      _snack(
        approved ? '✅ Berhasil disetujui' : '❌ Berhasil ditolak',
        err: false,
      );
    }
  }

  Future<bool> _confirmDialog(String content, Color color) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Konfirmasi'),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: const Text('Setujui'),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> _rejectDialog(String name) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tolak — $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Alasan penolakan:',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Alasan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
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
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(context, ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  void _snack(
    String msg, {
    required bool err,
  }) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            err ? Icons.error_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: err ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Persetujuan Asset',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            if (!_isLoading && _items.isNotEmpty)
              Text(
                '${_items.length} menunggu',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
              onPressed: _load,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF607D8B)),
          ),
        ),
      );
    }
    if (_items.isEmpty) return _buildEmpty();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) => _buildCard(_items[i]),
    );
  }

  Widget _buildCard(PendingAssetRequest item) {
    final isProcessing = _processingId == item.id;
    final c = item.kategori.color;
    final stokKurang = item.jumlah > item.stokTersedia;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      item.userName.isNotEmpty
                          ? item.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (item.userJob?.isNotEmpty == true)
                        Text(
                          item.userJob!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: item.daysWaiting >= 3
                        ? Colors.red[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.daysWaiting >= 3
                          ? Colors.red[200]!
                          : Colors.orange[200]!,
                    ),
                  ),
                  child: Text(
                    item.daysWaiting == 0 ? 'Hari ini' : '${item.daysWaiting}h',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item.daysWaiting >= 3
                          ? Colors.red[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.withOpacity(0.12)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        item.kategori.icon,
                        size: 12,
                        color: c.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.kategori.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 12,
                        color: c.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${item.namaBarang} • ${item.jumlah} unit',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: c.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy').format(item.tanggalPengajuan),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  if (stokKurang) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: Colors.red[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Stok tidak cukup (tersedia: ${item.stokTersedia})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (item.catatan?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.catatan!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (isProcessing)
              Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(c),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(item),
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text(
                        'Tolak',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(item),
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: const Text(
                        'Setujui',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: Color(0xFF607D8B),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada yang Menunggu',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Semua pengajuan asset sudah diproses.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    ),
  );
}
