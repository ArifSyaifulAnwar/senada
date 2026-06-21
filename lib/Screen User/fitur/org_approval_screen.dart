// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:absensikaryawan/Services/time_off_file_service.dart';
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;

import '../../Services/asset_service.dart' hide ApiResponse;
import 'asset_screen.dart';

// ── Tipe pending ──────────────────────────────────────────────────────────────
enum PendingType { org, finance, hrdApproval, headVerify, hrdVerify, transfer }

extension PendingTypeX on PendingType {
  Color get color {
    switch (this) {
      case PendingType.org:
        return const Color(0xFF2563EB);
      case PendingType.finance:
        return const Color(0xFF059669);
      case PendingType.hrdApproval:
        return const Color(0xFF7C3AED);
      case PendingType.headVerify:
        return const Color(0xFFD97706);
      case PendingType.hrdVerify:
        return const Color(0xFF6366F1);
      case PendingType.transfer:
        return const Color(0xFFDC2626);
    }
  }

  IconData get icon {
    switch (this) {
      case PendingType.org:
        return Icons.business_center_outlined;
      case PendingType.finance:
        return Icons.account_balance_wallet_outlined;
      case PendingType.hrdApproval:
        return Icons.admin_panel_settings_outlined;
      case PendingType.headVerify:
        return Icons.verified_outlined;
      case PendingType.hrdVerify:
        return Icons.rate_review_outlined;
      case PendingType.transfer:
        return Icons.swap_horiz_outlined;
    }
  }

  String get label {
    switch (this) {
      case PendingType.org:
        return 'Persetujuan Dinas Luar';
      case PendingType.finance:
        return 'Persetujuan Biaya';
      case PendingType.hrdApproval:
        return 'Persetujuan HRD';
      case PendingType.headVerify:
        return 'Verifikasi Kepala';
      case PendingType.hrdVerify:
        return 'Verifikasi Laporan (HRD)';
      case PendingType.transfer:
        return 'Bukti Transfer';
    }
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
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
  final PendingType pendingType;
  final String? currentStatus;

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
    this.pendingType = PendingType.org,
    this.currentStatus,
  });

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  factory PendingOrgItem.fromJson(
    Map<String, dynamic> j, {
    PendingType type = PendingType.org,
  }) => PendingOrgItem(
    id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
    userId:
        j['UserId']?.toString() ??
        j['userId']?.toString() ??
        j['userid']?.toString() ??
        '',
    userName:
        j['UserName']?.toString() ??
        j['userName']?.toString() ??
        j['user_name']?.toString() ??
        '',
    userJob:
        j['UserJob']?.toString() ??
        j['userJob']?.toString() ??
        j['user_job']?.toString(),
    jenisTimeOff:
        j['JenisTimeOff']?.toString() ??
        j['jenisTimeOff']?.toString() ??
        j['jenis_timeoff']?.toString() ??
        '',
    tanggalMulai: _parseDate(
      j['TanggalMulai'] ?? j['tanggalMulai'] ?? j['tanggal_mulai'],
    ),
    tanggalSelesai: _parseDate(
      j['TanggalSelesai'] ?? j['tanggalSelesai'] ?? j['tanggal_selesai'],
    ),
    totalHari:
        ((j['TotalHari'] ?? j['totalHari'] ?? j['total_hari'] ?? 0) as num)
            .toInt(),
    catatan: (j['Catatan'] ?? j['catatan'])?.toString(),
    jenisPekerjaan:
        j['JenisPekerjaan']?.toString() ??
        j['jenisPekerjaan']?.toString() ??
        j['jenis_pekerjaan']?.toString(),
    rabType:
        j['RabType']?.toString() ??
        j['rabType']?.toString() ??
        j['rab_type']?.toString(),
    nominalUangKantor:
        ((j['NominalUangKantor'] ??
                    j['nominalUangKantor'] ??
                    j['nominal_uang_kantor'])
                as num?)
            ?.toDouble(),
    orgTarget:
        j['OrgTarget']?.toString() ??
        j['orgTarget']?.toString() ??
        j['org_target']?.toString(),
    daysWaiting:
        ((j['DaysWaiting'] ?? j['daysWaiting'] ?? j['days_waiting'] ?? 0)
                as num)
            .toInt(),
    pendingType: type,
    currentStatus: j['Status']?.toString() ?? j['status']?.toString(),
  );

  PendingOrgItem copyWith({PendingType? pendingType}) => PendingOrgItem(
    id: id,
    userId: userId,
    userName: userName,
    userJob: userJob,
    jenisTimeOff: jenisTimeOff,
    tanggalMulai: tanggalMulai,
    tanggalSelesai: tanggalSelesai,
    totalHari: totalHari,
    catatan: catatan,
    jenisPekerjaan: jenisPekerjaan,
    rabType: rabType,
    nominalUangKantor: nominalUangKantor,
    orgTarget: orgTarget,
    daysWaiting: daysWaiting,
    pendingType: pendingType ?? this.pendingType,
    currentStatus: currentStatus,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
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
  int _processingId = -1;
  PendingType? _processingType;
  List<AssetRequestModel> _assetItems = [];
  int _processingAssetId = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load semua pending ────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    final all = <PendingOrgItem>[];

    await Future.wait([
      TimeOffService.getPendingOrgReview(widget.userId)
          .then((r) {
            if (r.success && r.data != null) {
              all.addAll(
                r.data!.map((i) => i.copyWith(pendingType: PendingType.org)),
              );
            }
          })
          .catchError((_) {}),

      TimeOffService.getPendingFinance(widget.userId)
          .then((r) {
            if (r.success && r.data != null) {
              all.addAll(
                r.data!.map(
                  (i) => i.copyWith(pendingType: PendingType.finance),
                ),
              );
            }
          })
          .catchError((_) {}),

      TimeOffService.getPendingHeadVerify(widget.userId)
          .then((r) {
            if (r.success && r.data != null) {
              all.addAll(
                r.data!.map(
                  (i) => i.copyWith(pendingType: PendingType.headVerify),
                ),
              );
            }
          })
          .catchError((_) {}),

      TimeOffService.getPendingHrdVerify(widget.userId)
          .then((r) {
            if (r.success && r.data != null) {
              for (final i in r.data!) {
                final t = i.currentStatus == 'Pending HRD'
                    ? PendingType.hrdApproval
                    : PendingType.hrdVerify;
                all.add(i.copyWith(pendingType: t));
              }
            }
          })
          .catchError((_) {}),

      TimeOffService.getPendingTransfer(widget.userId)
          .then((r) {
            if (r.success && r.data != null) {
              all.addAll(
                r.data!.map(
                  (i) => i.copyWith(pendingType: PendingType.transfer),
                ),
              );
            }
          })
          .catchError((_) {}),

      // ── Persetujuan Asset (Head HRD only — backend yang validasi) ────────
      AssetService.getPendingRequests(userId: widget.userId)
          .then((r) {
            if (r.success && r.data != null && mounted) {
              setState(() => _assetItems = r.data!);
            }
          })
          .catchError((_) {}),
    ]);

    all.sort((a, b) => b.daysWaiting.compareTo(a.daysWaiting));
    if (mounted) {
      setState(() {
        _items = all;
        _isLoading = false;
      });
    }
  }

  Future<void> _approveAsset(AssetRequestModel item) async {
    final confirm = await _confirmDialog(
      'Setujui ${AssetCategoryX.fromApi(item.kategori).label.toLowerCase()} '
      '"${item.namaBarang}" (${item.jumlah}) oleh ${item.userName}?',
      const Color(0xFF8B5CF6),
    );
    if (!confirm) return;
    await _doAssetAction(item, 'Approved', null);
  }

  Future<void> _rejectAsset(AssetRequestModel item) async {
    final reason = await _rejectDialog(item.userName ?? '-');
    if (reason == null) return;
    await _doAssetAction(item, 'Rejected', reason);
  }

  Future<void> _doAssetAction(
    AssetRequestModel item,
    String status,
    String? reason,
  ) async {
    setState(() => _processingAssetId = item.id);
    try {
      final res = await AssetService.reviewRequest(
        id: item.id,
        hrdUserId: widget.userId,
        status: status,
        rejectionReason: reason,
      );
      if (res.success) {
        _snack(
          status == 'Approved' ? '✅ Berhasil disetujui' : '❌ Berhasil ditolak',
          err: false,
        );
        setState(() => _assetItems.removeWhere((i) => i.id == item.id));
      } else {
        _snack(res.message, err: true);
      }
    } catch (e) {
      _snack('Gagal: $e', err: true);
    } finally {
      if (mounted) setState(() => _processingAssetId = -1);
    }
  }

  int get totalPending => _items.length + _assetItems.length;
  // int get totalPending => _items.length;

  // ── Approve / Reject ──────────────────────────────────────────────────────
  Future<void> _approve(PendingOrgItem item) async {
    if (item.pendingType == PendingType.transfer) {
      _snack('Pilih file bukti transfer terlebih dahulu', err: true);
      return;
    }
    final confirm = await _confirmDialog(
      _approveText(item),
      item.pendingType.color,
    );
    if (!confirm) return;
    await _doAction(item, 'Approved', null);
  }

  Future<void> _reject(PendingOrgItem item) async {
    final reason = await _rejectDialog(item.userName);
    if (reason == null) return;
    await _doAction(item, 'Rejected', reason);
  }

  String _approveText(PendingOrgItem item) {
    switch (item.pendingType) {
      case PendingType.org:
        return 'Setujui Dinas Luar ${item.userName} (${item.totalHari} hari)?';
      case PendingType.finance:
        return 'Setujui pengajuan biaya DL ${item.userName}?';
      case PendingType.hrdApproval:
        return 'Setujui pengajuan DL ${item.userName}?\nDiteruskan ke Finance atau Laporan.';
      case PendingType.headVerify:
        return 'Setujui laporan DL ${item.userName}?\nDiteruskan ke HRD.';
      case PendingType.hrdVerify:
        return 'Setujui laporan DL ${item.userName}?\n'
            '${(item.rabType != null && item.rabType!.isNotEmpty) ? "Finance akan melakukan transfer." : "Absensi akan tercatat."}';
      case PendingType.transfer:
        return '';
    }
  }

  Future<void> _doAction(
    PendingOrgItem item,
    String status,
    String? reason,
  ) async {
    setState(() {
      _processingId = item.id;
      _processingType = item.pendingType;
    });
    try {
      ApiResponse<void> res;
      switch (item.pendingType) {
        case PendingType.org:
          res = await TimeOffService.orgReview(
            timeOffId: item.id,
            reviewerUserId: widget.userId,
            status: status,
            rejectionReason: reason,
          );
          break;

        case PendingType.finance:
          res = await TimeOffService.financeReview(
            id: item.id,
            status: status,
            financeUserId: widget.userId,
            rejectionReason: reason,
          );
          break;

        case PendingType.hrdApproval:
          // Pending HRD → hrd-review (approval DL baru setelah Head Divisi approve)
          res = await TimeOffService.hrdReview(
            id: item.id,
            status: status,
            hrdUserId: widget.userId,
            rejectionReason: reason,
          );
          break;

        case PendingType.headVerify:
          res = await TimeOffService.dlHeadVerify(
            timeOffId: item.id,
            headUserId: widget.userId,
            status: status,
            rejectionReason: reason,
          );
          break;

        case PendingType.hrdVerify:
          // Menunggu Verifikasi HRD → dl-hrd-verify (verifikasi laporan DL)
          res = await TimeOffService.dlHrdVerify(
            timeOffId: item.id,
            hrdUserId: widget.userId,
            status: status,
            rejectionReason: reason,
          );
          break;

        case PendingType.transfer:
          return;
      }

      if (res.success) {
        _snack(
          status == 'Approved' ? '✅ Berhasil disetujui' : '❌ Berhasil ditolak',
          err: false,
        );
        setState(
          () => _items.removeWhere(
            (i) => i.id == item.id && i.pendingType == item.pendingType,
          ),
        );
      } else {
        _snack(res.message, err: true);
      }
    } catch (e) {
      _snack('Gagal: $e', err: true);
    } finally {
      if (mounted) {
        setState(() {
          _processingId = -1;
          _processingType = null;
        });
      }
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

  void _showDetail(PendingOrgItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        item: item,
        userId: widget.userId,
        onAction: (status, reason) => _doAction(item, status, reason),
      ),
    );
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
              'Persetujuan',
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
            onPressed: () => Navigator.of(context).pop(totalPending),
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
    if (_errorMsg.isNotEmpty) return _buildError();
    if (_items.isEmpty && _assetItems.isEmpty) return _buildEmpty();

    final grouped = <PendingType, List<PendingOrgItem>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.pendingType, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grouped.entries) ...[
          _sectionHeader(entry.key, entry.value.length),
          const SizedBox(height: 8),
          ...entry.value.map(_buildCard),
          const SizedBox(height: 8),
        ],
        if (_assetItems.isNotEmpty) ...[
          _assetSectionHeader(_assetItems.length),
          const SizedBox(height: 8),
          ..._assetItems.map(_buildAssetCard),
        ],
      ],
    );
  }

  Widget _assetSectionHeader(int count) {
    const c = Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, size: 15, color: c),
          const SizedBox(width: 8),
          const Text(
            'Persetujuan Asset',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(AssetRequestModel item) {
    const c = Color(0xFF8B5CF6);
    final kategori = AssetCategoryX.fromApi(item.kategori);
    final isProcessing = _processingAssetId == item.id;
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
                  decoration: const BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (item.userName?.isNotEmpty == true)
                          ? item.userName![0].toUpperCase()
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
                        item.userName ?? '-',
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
                      Icon(kategori.icon, size: 12, color: c.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(
                        kategori.label,
                        style: const TextStyle(
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
              const Center(
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
                      onPressed: () => _rejectAsset(item),
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
                      onPressed: () => _approveAsset(item),
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

  Widget _sectionHeader(PendingType t, int count) {
    final c = t.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(t.icon, size: 15, color: c),
          const SizedBox(width: 8),
          Text(
            t.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PendingOrgItem item) {
    final isProcessing =
        _processingId == item.id && _processingType == item.pendingType;
    final c = item.pendingType.color;
    final isTransfer = item.pendingType == PendingType.transfer;

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
                  _row(
                    Icons.work_outline,
                    '${item.jenisPekerjaan ?? item.orgTarget ?? "-"} • ${item.totalHari} hari',
                    c,
                  ),
                  const SizedBox(height: 5),
                  _row(
                    Icons.calendar_today_rounded,
                    '${DateFormat('dd MMM').format(item.tanggalMulai)} – ${DateFormat('dd MMM yyyy').format(item.tanggalSelesai)}',
                    c,
                  ),
                  if (item.rabType != null && item.rabType!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _row(
                      Icons.account_balance_wallet_outlined,
                      item.rabType == 'reimbursement'
                          ? '💸 Reimbursement'
                          : '🏢 Uang Kantor',
                      c,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showDetail(item),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: c),
                    const SizedBox(width: 6),
                    Text(
                      'Lihat Detail Lengkap',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: c),
                  ],
                ),
              ),
            ),
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
            else if (isTransfer)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDetail(item),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text(
                    'Upload Bukti Transfer',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

  Widget _row(IconData icon, String text, Color c) => Row(
    children: [
      Icon(icon, size: 12, color: c.withOpacity(0.7)),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
        ),
      ),
    ],
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
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
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: Color(0xFF0EA5E9),
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
            'Semua pengajuan sudah diproses.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    ),
  );

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

// ── Detail Bottom Sheet ───────────────────────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final PendingOrgItem item;
  final String userId;
  final Function(String status, String? reason) onAction;

  const _DetailSheet({
    required this.item,
    required this.userId,
    required this.onAction,
  });

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  List<Map<String, dynamic>> _reimburseItems = [];
  List<Map<String, dynamic>> _fileItems = [];
  bool _loadingItems = false;
  bool _loadingFiles = false;
  bool _isProcessing = false;
  TimeOffModel? _fullTimeOff;
  bool _loadingFullData = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.rabType != null && widget.item.rabType!.isNotEmpty) {
      _loadReimburseItems();
    }
    _loadFiles();
    _loadFullData();
  }

  Future<void> _loadFullData() async {
    if (widget.item.pendingType != PendingType.headVerify &&
        widget.item.pendingType != PendingType.hrdVerify &&
        widget.item.pendingType != PendingType.transfer) {
      return;
    }

    setState(() => _loadingFullData = true);
    try {
      final res = await TimeOffService.getMyTimeOff(widget.item.userId);
      if (res.success && res.data != null && mounted) {
        final found = res.data!.data
            .where((t) => t.id == widget.item.id)
            .toList();
        if (found.isNotEmpty && mounted) {
          setState(() => _fullTimeOff = found.first);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFullData = false);
    }
  }

  Widget _buildLaporanSection(Color c) {
    if (widget.item.pendingType != PendingType.headVerify &&
        widget.item.pendingType != PendingType.hrdVerify &&
        widget.item.pendingType != PendingType.transfer) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 14),
        _section('Laporan yang Disubmit Karyawan', c, [
          if (_loadingFullData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_fullTimeOff == null ||
              (_fullTimeOff!.laporanFileName == null &&
                  _fullTimeOff!.anggaranFileName == null))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Laporan belum tersedia.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else ...[
            if (_fullTimeOff!.laporanFileName != null)
              _buildLaporanFileRow(
                icon: Icons.description_outlined,
                color: const Color(0xFF3B82F6),
                label: 'Laporan Perjalanan Dinas',
                fileName: _fullTimeOff!.laporanFileName!,
                fileType: 'laporan',
                accentColor: c,
              ),
            if (_fullTimeOff!.anggaranFileName != null) ...[
              const SizedBox(height: 8),
              _buildLaporanFileRow(
                icon: Icons.receipt_outlined,
                color: const Color(0xFF10B981),
                label: widget.item.rabType == 'reimbursement'
                    ? 'Bukti Pembayaran'
                    : 'Bukti Penggunaan Uang Kantor',
                fileName: _fullTimeOff!.anggaranFileName!,
                fileType: 'anggaran',
                accentColor: c,
              ),
            ],
          ],
        ]),
      ],
    );
  }

  Future<void> _uploadTransfer() async {
    // Pick file
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                'Pilih bukti transfer',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(),
            if (!kIsWeb)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.blue[600]),
                ),
                title: const Text(
                  'Kamera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.green[600]),
              ),
              title: const Text(
                'Galeri / Foto',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.insert_drive_file, color: Colors.orange[600]),
              ),
              title: const Text(
                'File Dokumen (PDF)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, 'document'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (source == null) return;

    Uint8List? bytes;
    String? fileName;

    try {
      if (source == 'camera' && !kIsWeb) {
        final img = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (img == null) return;
        bytes = await img.readAsBytes();
        fileName = img.name.isNotEmpty ? img.name : img.path.split('/').last;
      } else if (source == 'gallery') {
        final img = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (img == null) return;
        bytes = await img.readAsBytes();
        fileName = img.name.isNotEmpty ? img.name : img.path.split('/').last;
      } else {
        final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          allowMultiple: false,
          withData: true,
        );
        if (r == null || r.files.isEmpty) return;
        final f = r.files.first;
        bytes =
            f.bytes ??
            (f.path != null ? await File(f.path!).readAsBytes() : null);
        fileName = f.name;
      }
    } catch (e) {
      _snack('Gagal memilih file: $e');
      return;
    }

    if (bytes == null) return;

    // Validasi ukuran
    if (bytes.length > 10 * 1024 * 1024) {
      _snack('Ukuran maksimal 10MB');
      return;
    }

    // Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Upload Bukti Transfer'),
        content: Text(
          'Upload "$fileName" sebagai bukti transfer untuk ${widget.item.userName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.item.pendingType.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await TimeOffService.dlUploadTransfer(
        timeOffId: widget.item.id,
        financeUserId: widget.userId,
        fileBytes: bytes,
        fileName: fileName,
      );
      if (res.success) {
        _snack('Bukti transfer berhasil diupload');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(); // tutup detail sheet
          widget.onAction('Approved', null); // refresh list
        }
      } else {
        _snack('Gagal: ${res.message}');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildBottomActions(Color c, bool isTransfer) {
    if (_isProcessing) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(c),
          ),
        ),
      );
    }

    if (isTransfer) {
      // Transfer: hanya tombol upload bukti transfer
      return Container(
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
          child: ElevatedButton.icon(
            onPressed: _uploadTransfer,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text(
              'Upload Bukti Transfer',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    // Approve / Reject biasa
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _doReject,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text(
                'Tolak',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[600],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _doApprove,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text(
                'Setujui',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaporanFileRow({
    required IconData icon,
    required Color color,
    required String label,
    required String fileName,
    required String fileType,
    required Color accentColor,
  }) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final typeLabel = ext.isNotEmpty ? ext.toUpperCase() : 'FILE';
    final isImg = ['jpg', 'jpeg', 'png'].contains(ext);
    final isPdf = ext == 'pdf';
    final canPreview = isImg || isPdf;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : isImg
                  ? Icons.image_rounded
                  : icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  '$typeLabel • $fileName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // Preview button — hanya kalau image atau PDF
          if (canPreview) ...[
            IconButton(
              icon: Icon(
                Icons.visibility_rounded,
                size: 20,
                color: accentColor,
              ),
              onPressed: () => _previewLaporanFile(
                fileType,
                fileName,
                isImg: isImg,
                isPdf: isPdf,
              ),
              tooltip: 'Preview',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
          // Download button
          IconButton(
            icon: Icon(Icons.download_rounded, size: 20, color: accentColor),
            onPressed: () => _downloadLaporanFile(fileType, fileName),
            tooltip: 'Download',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _previewLaporanFile(
    String fileType,
    String fileName, {
    required bool isImg,
    required bool isPdf,
  }) async {
    _snack('Membuka preview...');
    try {
      final res = await TimeOffService.dlDownloadLaporan(
        timeOffId: widget.item.id,
        userId: widget.userId,
        fileType: fileType,
      );
      if (!res.success || res.data == null) {
        _snack('Gagal: ${res.message}');
        return;
      }
      final bytes = Uint8List.fromList(res.data!);

      if (isImg) {
        _showImagePreview(bytes, fileName);
      } else if (isPdf) {
        if (kIsWeb) {
          previewFileWeb(bytes, fileName);
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done) {
            _snack('Tidak dapat membuka PDF: ${result.message}');
          }
        }
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _downloadLaporanFile(String fileType, String fileName) async {
    _snack('Mengunduh $fileName...');
    try {
      final res = await TimeOffService.dlDownloadLaporan(
        timeOffId: widget.item.id,
        userId: widget.userId,
        fileType: fileType,
      );
      if (res.success && res.data != null) {
        final bytes = Uint8List.fromList(res.data!);
        if (kIsWeb) {
          downloadFileWeb(bytes, fileName);
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          await OpenFile.open(file.path);
        }
      } else {
        _snack('Gagal download: ${res.message}');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<Uint8List?> _fetchFileBytes(int fileId, String fileName) async {
    try {
      if (fileId > 0) {
        final res = await TimeOffFileService.downloadFile(
          fileId,
          widget.item.id,
          widget.userId,
        );
        if (!res.success || res.data == null) {
          _snack('Gagal: ${res.message}');
          return null;
        }
        return Uint8List.fromList(res.data!);
      } else {
        final res = await TimeOffService.downloadFile(
          widget.item.id,
          widget.userId,
        );
        if (!res.success || res.data == null) {
          _snack('Gagal: ${res.message}');
          return null;
        }
        return Uint8List.fromList(res.data!);
      }
    } catch (e) {
      _snack('Error: $e');
      return null;
    }
  }

  Future<void> _loadReimburseItems() async {
    setState(() => _loadingItems = true);
    try {
      final res = await TimeOffService.getReimburseItems(
        widget.item.id,
        widget.userId,
      );
      if (res.success && res.data != null && mounted) {
        setState(
          () => _reimburseItems = List<Map<String, dynamic>>.from(res.data!),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final res = await TimeOffFileService.getFiles(
        widget.item.id,
        widget.userId,
      );
      if (res.success && res.data != null && mounted) {
        setState(() {
          _fileItems = res.data!
              .map(
                (f) => {
                  'id': f.id,
                  'fileName': f.fileName,
                  'fileSize': f.fileSize,
                  'fileType': f.fileType,
                  'urutan': f.urutan,
                },
              )
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _doApprove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Persetujuan'),
        content: Text(
          'Setujui pengajuan ${widget.item.userName}?\n(${widget.item.totalHari} hari)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.item.pendingType.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isProcessing = true);
    Navigator.of(context).pop();
    widget.onAction('Approved', null);
  }

  Future<void> _doReject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tolak — ${widget.item.userName}'),
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
    if (reason == null) return;
    Navigator.of(context).pop();
    widget.onAction('Rejected', reason);
  }

  Future<void> _downloadFile(int fileId, String fileName) async {
    _snack('Mengunduh $fileName...');
    final bytes = await _fetchFileBytes(fileId, fileName);
    if (bytes == null) return;
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName);
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _snack('Tidak dapat membuka: ${result.message}');
        }
      } catch (e) {
        _snack('Gagal: $e');
      }
    }
  }

  Future<void> _previewFile(
    int fileId,
    String fileName, {
    required bool isImg,
    required bool isPdf,
  }) async {
    _snack('Membuka preview...');
    final bytes = await _fetchFileBytes(fileId, fileName);
    if (bytes == null) return;
    if (isImg) {
      _showImagePreview(bytes, fileName);
    } else if (isPdf) {
      if (kIsWeb) {
        previewFileWeb(bytes, fileName);
      } else {
        try {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done) {
            _snack('Tidak dapat membuka PDF: ${result.message}');
          }
        } catch (e) {
          _snack('Gagal: $e');
        }
      }
    }
  }

  void _showImagePreview(Uint8List bytes, String fileName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final screenH = MediaQuery.of(ctx).size.height;
        final screenW = MediaQuery.of(ctx).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: screenW,
                  height: screenH,
                  color: Colors.transparent,
                ),
              ),
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: screenW * 0.95,
                    maxHeight: screenH * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1F2937),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              width: screenW * 0.95,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final item = widget.item;
    final c = item.pendingType.color;
    final isTransfer = item.pendingType == PendingType.transfer;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.userJob ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.withOpacity(0.3)),
                    ),
                    child: Text(
                      item.pendingType.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // Info DL
                  _section('Informasi Dinas Luar', c, [
                    _dRow(
                      'Jenis Pekerjaan',
                      item.jenisPekerjaan ?? item.orgTarget ?? '-',
                    ),
                    _dRow(
                      'Tanggal',
                      '${_fmtDate(item.tanggalMulai)} – ${_fmtDate(item.tanggalSelesai)}',
                    ),
                    _dRow('Durasi', '${item.totalHari} hari'),
                    if (item.catatan?.isNotEmpty == true)
                      _dRow('Catatan', item.catatan!),
                  ]),

                  // Info biaya
                  if (item.rabType != null && item.rabType!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('Informasi Biaya', c, [
                      _dRow(
                        'Tipe Biaya',
                        item.rabType == 'reimbursement'
                            ? '💸 Reimbursement'
                            : '🏢 Uang Kantor',
                      ),
                      if (item.nominalUangKantor != null)
                        _dRow('Nominal', _fmtRp(item.nominalUangKantor!)),
                    ]),
                    const SizedBox(height: 14),
                    _section('Detail Pengeluaran', c, [
                      if (_loadingItems)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_reimburseItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Belum ada detail item pengeluaran.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Item',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Nominal',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._reimburseItems.asMap().entries.map((e) {
                          final it = e.value;
                          final nama =
                              it['NamaItem']?.toString() ??
                              it['nama_item']?.toString() ??
                              '-';
                          final ket =
                              it['Keterangan']?.toString() ??
                              it['keterangan']?.toString();
                          final nominal =
                              ((it['Nominal'] ?? it['nominal']) as num?)
                                  ?.toDouble() ??
                              0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: e.key % 2 == 0
                                  ? Colors.white
                                  : const Color(0xFFF9FAFB),
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nama,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (ket != null && ket.isNotEmpty)
                                        Text(
                                          ket,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _fmtRp(nominal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.08),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _fmtRp(
                                    _reimburseItems.fold(
                                      0.0,
                                      (s, i) =>
                                          s +
                                          (((i['Nominal'] ?? i['nominal'])
                                                      as num?)
                                                  ?.toDouble() ??
                                              0),
                                    ),
                                  ),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]),
                  ],

                  // File Lampiran
                  const SizedBox(height: 14),
                  _section('File Lampiran Pengaju', c, [
                    if (_loadingFiles)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_fileItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Tidak ada file lampiran.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      )
                    else
                      ..._fileItems.map((f) {
                        final fId = (f['id'] as num).toInt();
                        final fName = f['fileName']?.toString() ?? '';
                        final fSize = (f['fileSize'] as num?)?.toInt();
                        final ext = fName.contains('.')
                            ? fName.split('.').last.toLowerCase()
                            : '';
                        final isImg = ['jpg', 'jpeg', 'png'].contains(ext);
                        final isPdf = ext == 'pdf';
                        final iconColor = isPdf
                            ? Colors.red[600]!
                            : isImg
                            ? Colors.blue[600]!
                            : Colors.grey[600]!;
                        final iconData = isPdf
                            ? Icons.picture_as_pdf_rounded
                            : isImg
                            ? Icons.image_rounded
                            : Icons.insert_drive_file_rounded;
                        String sizeLabel = '';
                        if (fSize != null) {
                          final mb = fSize / (1024 * 1024);
                          sizeLabel = mb >= 1
                              ? '${mb.toStringAsFixed(1)} MB'
                              : '${(fSize / 1024).toStringAsFixed(0)} KB';
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (sizeLabel.isNotEmpty)
                                      Text(
                                        '${ext.toUpperCase()} • $sizeLabel',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isImg || isPdf)
                                IconButton(
                                  icon: Icon(
                                    Icons.visibility_rounded,
                                    size: 20,
                                    color: c,
                                  ),
                                  onPressed: () => _previewFile(
                                    fId,
                                    fName,
                                    isImg: isImg,
                                    isPdf: isPdf,
                                  ),
                                  tooltip: 'Preview',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  Icons.download_rounded,
                                  size: 20,
                                  color: c,
                                ),
                                onPressed: () => _downloadFile(fId, fName),
                                tooltip: 'Download',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }),
                  ]),
                  _buildLaporanSection(c),
                ],
              ),
            ),

            // Bottom action buttons
            _buildBottomActions(c, isTransfer),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Color c, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: children),
        ),
      ],
    ),
  );

  Widget _dRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    ),
  );

  String _fmtDate(DateTime d) {
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
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _fmtRp(double v) {
    final s = v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $s';
  }
}
