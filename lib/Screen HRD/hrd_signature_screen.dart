// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:typed_data';
import 'package:absensikaryawan/Screen%20admin/model/timeoffmodeladmin.dart';
import 'package:absensikaryawan/Screen%20admin/service/timeoffserviceadmin.dart';
import 'package:absensikaryawan/Services/signature_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HrdSignatureScreen extends StatefulWidget {
  const HrdSignatureScreen({super.key});

  @override
  State<HrdSignatureScreen> createState() => _HrdSignatureScreenState();
}

class _HrdSignatureScreenState extends State<HrdSignatureScreen> {
  List<UserWithTimeOffs> _users = [];
  Map<String, SignatureInfo?> _signatureMap = {};
  bool _isLoading = true;
  bool _isUploading = false;
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _adminId = prefs.getString('UserID');
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await TimeOffAdminService.getUsersWithTimeOffs(
        adminId: _adminId!,
      );
      _users = res.data ?? [];

      // Load status TTD semua karyawan paralel
      final futures = _users.map((u) async {
        final info = await SignatureService.check(u.userId);
        return MapEntry(u.userId, info);
      });
      final entries = await Future.wait(futures);
      _signatureMap = Map.fromEntries(entries);
    } catch (e) {
      _snack('Gagal memuat data: $e', err: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Upload single TTD untuk 1 karyawan ───────────────────────────────
  Future<void> _uploadSingle(UserWithTimeOffs user) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _snack('File tidak dapat dibaca', err: true);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final r = await SignatureService.upload(
        userId: user.userId,
        fileBytes: file.bytes!,
        fileName: file.name,
      );
      if (r.success) {
        _snack('TTD ${user.name} berhasil disimpan');
        // Refresh status 1 user
        final info = await SignatureService.check(user.userId);
        setState(() => _signatureMap[user.userId] = info);
      } else {
        _snack(r.message, err: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Upload bulk — pilih banyak file sekaligus ─────────────────────────
  // Nama file HARUS = userId.png (mis: USR001.png)
  Future<void> _uploadBulk() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    // Validasi nama file = userId
    final validFiles = <({String userId, List<int> bytes, String fileName})>[];
    final invalidNames = <String>[];

    for (final f in result.files) {
      if (f.bytes == null) continue;
      final userId = f.name.contains('.')
          ? f.name.substring(0, f.name.lastIndexOf('.'))
          : f.name;
      if (userId.trim().isEmpty) {
        invalidNames.add(f.name);
        continue;
      }
      validFiles.add((
        userId: userId.trim(),
        bytes: f.bytes!,
        fileName: f.name,
      ));
    }

    if (validFiles.isEmpty) {
      _snack('Tidak ada file valid untuk diupload', err: true);
      return;
    }

    // Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Upload TTD Bulk',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${validFiles.length} file siap diupload:'),
            const SizedBox(height: 8),
            ...validFiles
                .take(5)
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Text(f.fileName, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            if (validFiles.length > 5)
              Text(
                '... dan ${validFiles.length - 5} lainnya',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            if (invalidNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${invalidNames.length} file dilewati (nama tidak valid)',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ],
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
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploading = true);
    try {
      final r = await SignatureService.uploadBulk(
        adminId: _adminId!,
        files: validFiles,
      );
      _snack(
        '${r.message} (Berhasil: ${r.sukses}, Gagal: ${r.gagal})',
        err: r.gagal > 0,
      );
      await _loadData();
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Preview TTD ───────────────────────────────────────────────────────
  Future<void> _previewTtd(UserWithTimeOffs user) async {
    _snack('Memuat TTD...', err: false);
    final bytes = await SignatureService.getImage(user.userId);
    if (bytes == null) {
      _snack('TTD tidak dapat dimuat', err: true);
      return;
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TTD — ${user.name}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      Uint8List.fromList(bytes),
                      fit: BoxFit.contain,
                      height: 200,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hapus TTD ─────────────────────────────────────────────────────────
  Future<void> _deleteTtd(UserWithTimeOffs user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus TTD?'),
        content: Text(
          'Hapus TTD ${user.name}? Tindakan tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final r = await SignatureService.delete(
      userId: user.userId,
      adminId: _adminId!,
    );
    _snack(r.message, err: !r.success);
    if (r.success) {
      final info = await SignatureService.check(user.userId);
      setState(() => _signatureMap[user.userId] = info);
    }
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              err ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
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
        backgroundColor: err
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hitung statistik
    final total = _users.length;
    final sudahAda = _signatureMap.values
        .where((i) => i?.hasTtd == true)
        .length;
    final belumAda = total - sudahAda;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Kelola TTD Karyawan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          // Upload bulk
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Upload TTD Bulk',
              icon: const Icon(
                Icons.upload_file,
                color: Color(0xFF6366F1),
                size: 20,
              ),
              onPressed: _isUploading ? null : _uploadBulk,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black87, size: 18),
              onPressed: _isLoading ? null : _loadData,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            )
          : Column(
              children: [
                // ── Stats banner ─────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _statBox('Total', total, Colors.blue),
                      const SizedBox(width: 10),
                      _statBox('Sudah Ada', sudahAda, const Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      _statBox('Belum Ada', belumAda, const Color(0xFFF59E0B)),
                    ],
                  ),
                ),

                // ── Info cara upload bulk ─────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload Bulk: nama file harus = UserID karyawan '
                          '(contoh: USR001.png). '
                          'Tap ikon upload di kanan atas.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── List karyawan ─────────────────────────────────────
                Expanded(
                  child: _isUploading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6366F1),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Mengupload TTD...',
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _users.length,
                            itemBuilder: (_, i) => _buildUserCard(_users[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statBox(String label, int value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    ),
  );

  Widget _buildUserCard(UserWithTimeOffs user) {
    final info = _signatureMap[user.userId];
    final hasTtd = info?.hasTtd == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasTtd
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.jobPosition ?? user.jobs ?? '-',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hasTtd
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasTtd ? Icons.check_circle : Icons.warning_rounded,
                            size: 11,
                            color: hasTtd
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasTtd ? 'TTD tersedia' : 'Belum ada TTD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: hasTtd
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasTtd && info?.sizeLabel.isNotEmpty == true) ...[
                      const SizedBox(width: 6),
                      Text(
                        info!.sizeLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTtd)
                _iconBtn(
                  Icons.visibility_rounded,
                  const Color(0xFF3B82F6),
                  'Preview',
                  () => _previewTtd(user),
                ),
              _iconBtn(
                Icons.upload_rounded,
                const Color(0xFF6366F1),
                'Upload TTD',
                () => _uploadSingle(user),
              ),
              if (hasTtd)
                _iconBtn(
                  Icons.delete_outline,
                  const Color(0xFFEF4444),
                  'Hapus TTD',
                  () => _deleteTtd(user),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    ),
  );
}
