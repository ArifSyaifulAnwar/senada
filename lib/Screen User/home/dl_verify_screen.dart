// ignore_for_file: deprecated_member_use

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../fitur/org_approval_screen.dart';

// ── Mode enum ─────────────────────────────────────────────────────────────────
enum DlVerifyMode { head, hrd, finance }

// ═══════════════════════════════════════════════════════════════════════════════
// DlVerifyListScreen — daftar pengajuan DL yang perlu diproses
// ═══════════════════════════════════════════════════════════════════════════════
class DlVerifyListScreen extends StatefulWidget {
  final String userId;
  final DlVerifyMode mode;

  const DlVerifyListScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  @override
  State<DlVerifyListScreen> createState() => _DlVerifyListScreenState();
}

class _DlVerifyListScreenState extends State<DlVerifyListScreen> {
  List<PendingOrgItem> _items = [];
  bool _isLoading = true;
  String _errorMsg = '';

  String get _title {
    switch (widget.mode) {
      case DlVerifyMode.head:
        return 'Verifikasi Laporan (Head)';
      case DlVerifyMode.hrd:
        return 'Verifikasi Laporan (HRD)';
      case DlVerifyMode.finance:
        return 'Upload Bukti Transfer';
    }
  }

  Color get _accentColor {
    switch (widget.mode) {
      case DlVerifyMode.head:
        return const Color(0xFF0EA5E9);
      case DlVerifyMode.hrd:
        return const Color(0xFF7C3AED);
      case DlVerifyMode.finance:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    try {
      ApiResponse<List<PendingOrgItem>> res;
      switch (widget.mode) {
        case DlVerifyMode.head:
          res = await TimeOffService.getPendingHeadVerify(widget.userId);
          break;
        case DlVerifyMode.hrd:
          res = await TimeOffService.getPendingHrdVerify(widget.userId);
          break;
        case DlVerifyMode.finance:
          res = await TimeOffService.getPendingTransfer(widget.userId);
          break;
      }
      if (res.success && res.data != null) {
        setState(() => _items = res.data!);
      } else {
        setState(() => _errorMsg = res.message);
      }
    } catch (e) {
      setState(() => _errorMsg = 'Koneksi bermasalah: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title,
              style: const TextStyle(
                fontSize: 18,
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMsg.isNotEmpty
            ? _buildError()
            : _items.isEmpty
            ? _buildEmpty()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (_, i) => _buildCard(_items[i]),
              ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 56, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
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

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: _accentColor,
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
            'Semua laporan DL sudah diproses.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    ),
  );

  Widget _buildCard(PendingOrgItem item) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DlVerifyDetailScreen(
                item: item,
                userId: widget.userId,
                mode: widget.mode,
              ),
            ),
          ).then((res) {
            if (res == true) _load();
          }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accentColor,
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
                  if (item.userJob?.isNotEmpty == true)
                    Text(
                      item.userJob!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd MMM').format(item.tanggalMulai)} – '
                    '${DateFormat('dd MMM yyyy').format(item.tanggalSelesai)} '
                    '(${item.totalHari} hari)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                    ),
                  ),
                  if (item.jenisPekerjaan?.isNotEmpty == true)
                    Text(
                      '📍 ${item.jenisPekerjaan}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                const SizedBox(height: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DlVerifyDetailScreen — detail + action (approve/reject / upload transfer)
// ═══════════════════════════════════════════════════════════════════════════════
class DlVerifyDetailScreen extends StatefulWidget {
  final PendingOrgItem item;
  final String userId;
  final DlVerifyMode mode;

  const DlVerifyDetailScreen({
    super.key,
    required this.item,
    required this.userId,
    required this.mode,
  });

  @override
  State<DlVerifyDetailScreen> createState() => _DlVerifyDetailScreenState();
}

class _DlVerifyDetailScreenState extends State<DlVerifyDetailScreen> {
  bool _isProcessing = false;
  _PickedFile? _transferFile;

  Color get _accentColor {
    switch (widget.mode) {
      case DlVerifyMode.head:
        return const Color(0xFF0EA5E9);
      case DlVerifyMode.hrd:
        return const Color(0xFF7C3AED);
      case DlVerifyMode.finance:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _approve() async {
    final confirm = await _showConfirm(
      title: 'Setujui Laporan',
      content: 'Setujui laporan Dinas Luar ${widget.item.userName}?',
      confirmLabel: 'Setujui',
      confirmColor: _accentColor,
    );
    if (!confirm) return;
    await _doAction('Approved', null);
  }

  Future<void> _reject() async {
    final reason = await _showRejectDialog();
    if (reason == null) return;
    await _doAction('Rejected', reason);
  }

  Future<void> _doAction(String status, String? reason) async {
    setState(() => _isProcessing = true);
    try {
      ApiResponse<void> res;
      switch (widget.mode) {
        case DlVerifyMode.head:
          res = await TimeOffService.dlHeadVerify(
            timeOffId: widget.item.id,
            headUserId: widget.userId,
            status: status,
            rejectionReason: reason,
          );
          break;
        case DlVerifyMode.hrd:
          res = await TimeOffService.dlHrdVerify(
            timeOffId: widget.item.id,
            hrdUserId: widget.userId,
            status: status,
            rejectionReason: reason,
          );
          break;
        case DlVerifyMode.finance:
          // Finance tidak pakai approve/reject — pakai upload transfer
          return;
      }

      if (res.success) {
        _snack(
          status == 'Approved' ? '✅ Laporan disetujui' : '❌ Laporan ditolak',
          err: false,
        );
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _snack(res.message, err: true);
      }
    } catch (e) {
      _snack('Gagal: $e', err: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickTransferFile() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final bytes =
          f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) return;
      setState(
        () => _transferFile = _PickedFile(
          name: f.name,
          bytes: bytes,
          size: bytes.length,
        ),
      );
    } catch (e) {
      _snack('Gagal pilih file: $e', err: true);
    }
  }

  Future<void> _uploadTransfer() async {
    if (_transferFile == null) {
      _snack('Pilih file bukti transfer terlebih dahulu', err: true);
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final res = await TimeOffService.dlUploadTransfer(
        timeOffId: widget.item.id,
        financeUserId: widget.userId,
        fileBytes: _transferFile!.bytes!,
        fileName: _transferFile!.name,
      );
      if (res.success) {
        _snack('✅ Bukti transfer diupload. Dinas Luar selesai!', err: false);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _snack(res.message, err: true);
      }
    } catch (e) {
      _snack('Gagal upload: $e', err: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _showConfirm({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async =>
      await showDialog<bool>(
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

  Future<String?> _showRejectDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tolak Laporan ${widget.item.userName}'),
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
                hintText: 'Masukkan alasan...',
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.mode == DlVerifyMode.finance
              ? 'Upload Transfer'
              : 'Detail Laporan DL',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accentColor, _accentColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (item.userJob?.isNotEmpty == true)
                    Text(
                      item.userJob!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          Icons.work_outline,
                          item.jenisPekerjaan ?? item.orgTarget ?? '-',
                        ),
                        const SizedBox(height: 6),
                        _infoRow(
                          Icons.calendar_today_rounded,
                          '${DateFormat('dd MMM yyyy').format(item.tanggalMulai)} – '
                          '${DateFormat('dd MMM yyyy').format(item.tanggalSelesai)}',
                        ),
                        const SizedBox(height: 6),
                        _infoRow(Icons.access_time, '${item.totalHari} hari'),
                        if (item.rabType != null) ...[
                          const SizedBox(height: 6),
                          _infoRow(
                            Icons.account_balance_wallet_outlined,
                            item.rabType == 'reimbursement'
                                ? '💸 Reimbursement'
                                : '🏢 Uang Kantor (Rp ${_fmt(item.nominalUangKantor ?? 0)})',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (item.catatan?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Catatan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.catatan!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Finance: upload transfer ──────────────────────────────────────
            if (widget.mode == DlVerifyMode.finance) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green[700],
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Laporan sudah diverifikasi Head & HRD. Upload bukti transfer ke pengaju untuk menyelesaikan proses.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isProcessing ? null : _pickTransferFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _transferFile != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE5E7EB),
                      width: _transferFile != null ? 2 : 1,
                    ),
                  ),
                  child: _transferFile == null
                      ? Column(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap untuk pilih bukti transfer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            Text(
                              'PDF, JPG, atau PNG (Max 10MB)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file,
                              color: Color(0xFF10B981),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _transferFile!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _sizeLabel(_transferFile!.size),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.red[400],
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _transferFile = null),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isProcessing || _transferFile == null)
                      ? null
                      : _uploadTransfer,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 20),
                  label: Text(
                    _isProcessing ? 'Mengupload...' : 'Upload Bukti Transfer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],

            // ── Head & HRD: approve / reject ──────────────────────────────────
            if (widget.mode != DlVerifyMode.finance) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: _accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.mode == DlVerifyMode.head
                            ? 'Review laporan perjalanan dinas yang disubmit karyawan. Setujui jika laporan sudah sesuai.'
                            : 'Verifikasi akhir laporan DL. Setujui untuk ${item.rabType != null ? "melanjutkan ke proses transfer" : "mencatat absensi"}.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _accentColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text(
                          'Tolak',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _approve,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text(
                          'Setujui',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 14, color: Colors.white70),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  String _sizeLabel(int size) {
    final mb = size / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(size / 1024).toStringAsFixed(0)} KB';
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

class _PickedFile {
  final String name;
  final Uint8List? bytes;
  final int size;
  const _PickedFile({required this.name, this.bytes, required this.size});
}
