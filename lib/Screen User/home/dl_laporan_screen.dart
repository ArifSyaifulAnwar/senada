// screens/dl_laporan_screen.dart — FULL REPLACE
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class DlLaporanScreen extends StatefulWidget {
  final TimeOffModel timeOff;
  final String userId;

  const DlLaporanScreen({
    super.key,
    required this.timeOff,
    required this.userId,
  });

  @override
  State<DlLaporanScreen> createState() => _DlLaporanScreenState();
}

class _DlLaporanScreenState extends State<DlLaporanScreen> {
  _PickedFile? _laporanFile;
  _PickedFile? _anggaranFile;
  bool _isLoading = false;

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _pickLaporan() async {
    final f = await _pickAnyFile('laporan kerja');
    if (f != null) setState(() => _laporanFile = f);
  }

  Future<void> _pickAnggaran() async {
    final f = await _pickAnyFile('anggaran biaya');
    if (f != null) setState(() => _anggaranFile = f);
  }

  Future<_PickedFile?> _pickAnyFile(String label) async {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pilih $label',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(),
            // Kamera hanya di mobile native
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

    if (source == null) return null;

    try {
      // ── Kamera (mobile only) ────────────────────────────────────────────
      if (source == 'camera' && !kIsWeb) {
        final img = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (img == null) return null;
        final bytes = await img.readAsBytes();
        if (!_validateSize(img.name, bytes.length)) return null;
        return _PickedFile(
          name: img.name.isNotEmpty ? img.name : img.path.split('/').last,
          bytes: bytes,
          size: bytes.length,
        );
      }

      // ── Galeri ──────────────────────────────────────────────────────────
      if (source == 'gallery') {
        final img = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (img == null) return null;
        final bytes = await img
            .readAsBytes(); // ← readAsBytes support semua platform
        if (!_validateSize(img.name, bytes.length)) return null;
        return _PickedFile(
          name: img.name.isNotEmpty ? img.name : img.path.split('/').last,
          bytes: bytes,
          size: bytes.length,
        );
      }

      // ── Document (FilePicker) ────────────────────────────────────────────
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true, // ← selalu minta bytes agar support web & mobile
      );
      if (r == null || r.files.isEmpty) return null;
      final f = r.files.first;
      final bytes =
          f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) {
        _snack('Tidak dapat membaca file', err: true);
        return null;
      }
      if (!_validateSize(f.name, bytes.length)) return null;
      return _PickedFile(name: f.name, bytes: bytes, size: bytes.length);
    } catch (e) {
      _snack('Gagal memilih file: $e', err: true);
      return null;
    }
  }

  bool _validateSize(String name, int size) {
    if (size > 10 * 1024 * 1024) {
      _snack('$name: Ukuran maksimal 10MB', err: true);
      return false;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
      _snack('$name: Format tidak didukung (PDF/JPG/PNG)', err: true);
      return false;
    }
    return true;
  }

  // ── Submit — bekerja di semua platform ───────────────────────────────────

  Future<void> _submit() async {
    if (_laporanFile == null) {
      _snack('File laporan wajib diupload', err: true);
      return;
    }
    if (_anggaranFile == null) {
      _snack('File anggaran wajib diupload', err: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Kirim via bytes (support web & mobile)
      final req = DlLaporanRequest(
        timeOffId: widget.timeOff.id!,
        userId: widget.userId,
        laporanBytes: _laporanFile!.bytes,
        laporanFileName: _laporanFile!.name,
        anggaranBytes: _anggaranFile!.bytes,
        anggaranFileName: _anggaranFile!.name,
      );
      final res = await TimeOffService.submitDlLaporan(req);
      if (res.success) {
        _snack(
          'Laporan berhasil disubmit! Status Dinas Luar menjadi Disetujui.',
          err: false,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _snack(res.message, err: true);
      }
    } catch (e) {
      _snack('Terjadi kesalahan: $e', err: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final to = widget.timeOff;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Upload Laporan DL',
          style: TextStyle(
            fontSize: 20,
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
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color(0xFF374151),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dinas Luar — Upload Laporan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pengajuan Dinas Luar kamu sudah disetujui. Upload laporan hasil kerja dan laporan anggaran untuk menyelesaikan proses.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.4,
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
                        _infoRow(Icons.work_outline, to.jenisPekerjaan ?? '-'),
                        const SizedBox(height: 6),
                        _infoRow(
                          Icons.calendar_today_rounded,
                          '${DateFormat('dd MMM yyyy').format(to.tanggalMulai)} – ${DateFormat('dd MMM yyyy').format(to.tanggalSelesai)}',
                        ),
                        const SizedBox(height: 6),
                        _infoRow(Icons.access_time, '${to.totalHari} hari'),
                        if (to.rabType != null) ...[
                          const SizedBox(height: 6),
                          _infoRow(
                            Icons.account_balance_wallet_outlined,
                            to.rabType == 'reimbursement'
                                ? '💸 Reimbursement'
                                : '🏢 Uang Kantor',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Step info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Setelah laporan disubmit, status Dinas Luar akan berubah menjadi Disetujui dan absensi akan dicatat.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildUploadCard(
              label: 'Laporan Hasil Kerja',
              description: 'Upload laporan / hasil pekerjaan selama Dinas Luar',
              icon: Icons.description_outlined,
              color: const Color(0xFF3B82F6),
              file: _laporanFile,
              onTap: _pickLaporan,
              onRemove: () => setState(() => _laporanFile = null),
            ),

            const SizedBox(height: 16),

            _buildUploadCard(
              label: 'Laporan Anggaran Biaya',
              description: 'Upload rincian biaya / bukti pengeluaran selama DL',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF10B981),
              file: _anggaranFile,
              onTap: _pickAnggaran,
              onRemove: () => setState(() => _anggaranFile = null),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Mengirim...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Submit Laporan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Pastikan kedua file sudah benar sebelum submit.\nLaporan tidak dapat diubah setelah disubmit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    required _PickedFile? file,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: file != null
              ? color.withOpacity(0.5)
              : const Color(0xFFE5E7EB),
          width: file != null ? 2 : 1,
        ),
        boxShadow: file != null
            ? [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'WAJIB',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (file != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: color, size: 14),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: file == null
                ? GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red[200]!,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 34,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap untuk pilih file',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[600],
                            ),
                          ),
                          Text(
                            'PDF, JPG, atau PNG (Max 10MB)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _filePreview(file, color, onTap, onRemove),
          ),
        ],
      ),
    );
  }

  Widget _filePreview(
    _PickedFile file,
    Color color,
    VoidCallback onTap,
    VoidCallback onRemove,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_extIcon(file.ext), color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _sizeLabel(file.size),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.refresh, color: color, size: 16),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.close, color: Colors.red[600], size: 16),
          ),
        ),
      ],
    ),
  );

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

  IconData _extIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

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
  final Uint8List? bytes; // ← semua platform pakai bytes
  final int size;

  const _PickedFile({required this.name, this.bytes, required this.size});

  String get ext =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
}
