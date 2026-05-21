// screens/org_approval_screen.dart — FILE BARU
// Screen untuk user approve/reject DL dari divisi yang sama
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Model lokal ───────────────────────────────────────────────────────────────
class PendingOrgItem {
  final int id;
  final String userId;
  final String userName;
  final String? userJob;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final int totalHari;
  final String? catatan;
  final String? jenisPekerjaan;
  final String? rabType;
  final double? nominalUangKantor;
  final String? orgTarget;
  final int daysWaiting;

  const PendingOrgItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userJob,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.totalHari,
    this.catatan,
    this.jenisPekerjaan,
    this.rabType,
    this.nominalUangKantor,
    this.orgTarget,
    required this.daysWaiting,
  });

  factory PendingOrgItem.fromJson(Map<String, dynamic> j) => PendingOrgItem(
    id: (j['id'] ?? j['Id']) as int,
    userId: j['userId']?.toString() ?? j['userid']?.toString() ?? '',
    userName: j['userName']?.toString() ?? j['user_name']?.toString() ?? '',
    userJob: j['userJob']?.toString() ?? j['user_job']?.toString(),
    jenisTimeOff:
        j['jenisTimeOff']?.toString() ?? j['jenis_timeoff']?.toString() ?? '',
    tanggalMulai: DateTime.parse(
      (j['tanggalMulai'] ?? j['tanggal_mulai']).toString(),
    ),
    tanggalSelesai: DateTime.parse(
      (j['tanggalSelesai'] ?? j['tanggal_selesai']).toString(),
    ),
    totalHari: (j['totalHari'] ?? j['total_hari'] ?? 0) as int,
    catatan: j['catatan']?.toString(),
    jenisPekerjaan:
        j['jenisPekerjaan']?.toString() ?? j['jenis_pekerjaan']?.toString(),
    rabType: j['rabType']?.toString() ?? j['rab_type']?.toString(),
    nominalUangKantor:
        (j['nominalUangKantor'] ?? j['nominal_uang_kantor'] as num?)
            ?.toDouble(),
    orgTarget: j['orgTarget']?.toString() ?? j['org_target']?.toString(),
    daysWaiting: (j['daysWaiting'] ?? j['days_waiting'] ?? 0) as int,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// OrgApprovalScreen
// ═══════════════════════════════════════════════════════════════════════════════
class OrgApprovalScreen extends StatefulWidget {
  final String userId;
  const OrgApprovalScreen({super.key, required this.userId});

  @override
  State<OrgApprovalScreen> createState() => _OrgApprovalScreenState();
}

class _OrgApprovalScreenState extends State<OrgApprovalScreen> {
  List<PendingOrgItem> _items = [];
  bool _isLoading = true;
  String _errorMsg = '';
  // id yang sedang diproses
  int _processingId = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load data ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    try {
      final res = await TimeOffService.getPendingOrgReview(widget.userId);
      if (res.success && res.data != null) {
        setState(() => _items = res.data!);
      } else {
        setState(() => _errorMsg = res.message);
      }
    } catch (e) {
      setState(() => _errorMsg = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Approve / Reject ──────────────────────────────────────────────────────

  Future<void> _approve(PendingOrgItem item) async {
    final confirm = await _showConfirmDialog(
      title: 'Setujui Pengajuan',
      content: 'Setujui Dinas Luar ${item.userName} (${item.totalHari} hari)?',
      confirmLabel: 'Setujui',
      confirmColor: const Color(0xFF10B981),
    );
    if (!confirm) return;
    await _doReview(item, 'Approved', null);
  }

  Future<void> _reject(PendingOrgItem item) async {
    final reason = await _showRejectDialog(item.userName);
    if (reason == null) return;
    await _doReview(item, 'Rejected', reason);
  }

  Future<void> _doReview(
    PendingOrgItem item,
    String status,
    String? reason,
  ) async {
    setState(() => _processingId = item.id);
    try {
      final res = await TimeOffService.orgReview(
        timeOffId: item.id,
        reviewerUserId: widget.userId,
        status: status,
        rejectionReason: reason,
      );
      if (res.success) {
        _snack(
          status == 'Approved'
              ? '✅ Disetujui — menunggu persetujuan HRD'
              : '❌ Ditolak',
          err: false,
        );
        setState(() => _items.removeWhere((i) => i.id == item.id));
      } else {
        _snack(res.message, err: true);
      }
    } catch (e) {
      _snack('Gagal: $e', err: true);
    } finally {
      if (mounted) setState(() => _processingId = -1);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showRejectDialog(String name) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tolak Pengajuan $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan alasan penolakan:',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Alasan penolakan...',
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

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Persetujuan Divisi',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            if (!_isLoading && _items.isNotEmpty)
              Text(
                '${_items.length} menunggu persetujuan',
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
          ),
        ),
      );
    }

    if (_errorMsg.isNotEmpty) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) => _buildCard(_items[i]),
    );
  }

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(height: 20),
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
            'Semua pengajuan Dinas Luar dari divisi kamu sudah diproses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard(PendingOrgItem item) {
    final isProcessing = _processingId == item.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: user info ──────────────────────────────────────
            Row(
              children: [
                // Avatar inisial
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      item.userName.isNotEmpty
                          ? item.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.userName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (item.userJob != null && item.userJob!.isNotEmpty)
                        Text(
                          item.userJob!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                // Badge waiting days
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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
                    item.daysWaiting == 0
                        ? 'Hari ini'
                        : '${item.daysWaiting}h lalu',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.daysWaiting >= 3
                          ? Colors.red[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Detail izin ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                children: [
                  _detailRow(
                    Icons.work_outline,
                    'Dinas Luar',
                    item.jenisPekerjaan ?? '-',
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    Icons.calendar_today_rounded,
                    DateFormat('dd MMM yyyy').format(item.tanggalMulai),
                    '– ${DateFormat('dd MMM yyyy').format(item.tanggalSelesai)}',
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    Icons.access_time_rounded,
                    '${item.totalHari} hari',
                    null,
                  ),
                  if (item.rabType != null) ...[
                    const SizedBox(height: 8),
                    _detailRow(
                      Icons.account_balance_wallet_outlined,
                      item.rabType == 'reimbursement'
                          ? '💸 Reimbursement'
                          : '🏢 Uang Kantor',
                      item.nominalUangKantor != null
                          ? 'Rp ${_formatNumber(item.nominalUangKantor!)}'
                          : null,
                    ),
                  ],
                ],
              ),
            ),

            // ── Catatan ────────────────────────────────────────────────
            if (item.catatan != null && item.catatan!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_alt_outlined,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.catatan!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Action buttons ─────────────────────────────────────────
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF0EA5E9),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Tolak
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(item),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'Tolak',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Setujui
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(item),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Setujui',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _detailRow(
    IconData icon,
    String label,
    String? value, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF0284C7)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            color: const Color(0xFF0369A1),
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
        ],
      ],
    );
  }

  String _formatNumber(double val) {
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
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
}
