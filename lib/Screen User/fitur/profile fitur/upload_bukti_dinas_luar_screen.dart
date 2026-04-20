// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../Services/dlservice.dart';
class UploadBuktiDinasLuarScreen extends StatefulWidget {
  final int requestId;
  final String attendanceType;
  final String officeName;

  const UploadBuktiDinasLuarScreen({
    super.key,
    required this.requestId,
    required this.attendanceType,
    required this.officeName,
  });

  @override
  State<UploadBuktiDinasLuarScreen> createState() =>
      _UploadBuktiDinasLuarScreenState();
}

class _UploadBuktiDinasLuarScreenState
    extends State<UploadBuktiDinasLuarScreen> {
  // Kamera (untuk opsi foto langsung)
  CameraController? _cam;

  // Bukti yang dipilih
  String? _proofType; // 'photo' / 'document'
  Uint8List? _proofBytes;
  String? _proofBase64;
  String? _proofFilename;
  String? _proofMime;

  bool _isUploading = false;
  bool _isUploaded = false;
  String _uploadMsg = '';

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _cam = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cam!.initialize();
      if (mounted) {}
    } catch (_) {}
  }

  // ── Ambil foto dengan kamera ─────────────────────────────────────────────
  Future<void> _takePhoto() async {
    if (_cam == null || !_cam!.value.isInitialized) {
      _snack('Kamera tidak tersedia');
      return;
    }
    try {
      final xf = await _cam!.takePicture();
      final bytes = await xf.readAsBytes();
      setState(() {
        _proofType = 'photo';
        _proofBytes = bytes;
        _proofBase64 = base64Encode(bytes);
        _proofFilename =
            'bukti_dinas_luar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _proofMime = 'image/jpeg';
      });
    } catch (e) {
      _snack('Gagal mengambil foto: $e');
    }
  }

  // ── Upload file dari storage ─────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final f = result.files.first;
      final bytes =
          f.bytes ?? (kIsWeb ? null : await File(f.path!).readAsBytes());

      if (bytes == null) {
        _snack('Gagal membaca file');
        return;
      }
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _snack('Ukuran file maksimal 5 MB');
        return;
      }

      final ext = (f.extension ?? '').toLowerCase();
      String mime = 'application/octet-stream';
      if (ext == 'pdf') {
        mime = 'application/pdf';
      } else if (ext == 'jpg' || ext == 'jpeg')
        mime = 'image/jpeg';
      else if (ext == 'png')
        mime = 'image/png';
      else if (ext == 'doc')
        mime = 'application/msword';
      else if (ext == 'docx')
        mime =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      setState(() {
        _proofType = 'document';
        _proofBytes = Uint8List.fromList(bytes);
        _proofBase64 = base64Encode(bytes);
        _proofFilename = f.name;
        _proofMime = mime;
      });
    } catch (e) {
      _snack('Gagal memilih file: $e');
    }
  }

  // ── Hapus bukti yang sudah dipilih ───────────────────────────────────────
  void _clearProof() {
    setState(() {
      _proofType = null;
      _proofBytes = null;
      _proofBase64 = null;
      _proofFilename = null;
      _proofMime = null;
    });
  }

  // ── Submit upload ────────────────────────────────────────────────────────
  Future<void> _upload() async {
    if (_proofBase64 == null) {
      _snack('Pilih bukti terlebih dahulu');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadMsg = 'Mengupload bukti...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID') ?? '';

      final result = await DinasLuarService.uploadProof(
        requestId: widget.requestId,
        userId: userId,
        proofType: _proofType!,
        proofData: _proofBase64!,
        proofFilename: _proofFilename,
        proofMimeType: _proofMime,
      );

      setState(() {
        _isUploading = false;
        _isUploaded = result['success'] ?? false;
        _uploadMsg = result['message'] ?? '';
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadMsg = 'Error: $e';
      });
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isUploaded) return _buildSuccessView();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Upload Bukti Dinas Luar',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            _buildInfoBanner(),
            const SizedBox(height: 20),

            // Judul
            const Text(
              'Pilih Bukti Kegiatan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih salah satu: foto langsung atau upload dokumen',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Jika belum ada bukti → tampilkan opsi
            if (_proofType == null) ...[
              _optionCard(
                icon: Icons.camera_alt,
                label: 'Foto Kegiatan',
                sub: 'Ambil foto langsung sebagai bukti',
                color: Colors.blue,
                onTap: _takePhoto,
              ),
              const SizedBox(height: 12),
              _optionCard(
                icon: Icons.upload_file,
                label: 'Upload Dokumen',
                sub: 'PDF, Word, atau gambar dari penyimpanan (max 5 MB)',
                color: Colors.purple,
                onTap: _pickFile,
              ),
            ],

            // Jika sudah ada bukti → preview + opsi ganti
            if (_proofType != null) ...[
              _buildProofPreview(),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _clearProof,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Ganti Bukti'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: Colors.red,
                ),
              ),
            ],

            // Pesan error
            if (_uploadMsg.isNotEmpty && !_isUploading && !_isUploaded) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  _uploadMsg,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Tombol upload
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_proofType == null || _isUploading)
                    ? null
                    : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Upload & Selesaikan Absensi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                'Setelah upload, absensi Anda akan tercatat secara otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permintaan Dinas Luar Disetujui ✅',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upload bukti kegiatan Anda di ${widget.officeName} '
                  'untuk menyelesaikan absensi ${widget.attendanceType == "checkin" ? "Masuk" : "Pulang"}.',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
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
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProofPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.teal.withOpacity(0.08),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.teal, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Bukti dipilih',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          // Preview
          if (_proofType == 'photo' && _proofBytes != null)
            Image.memory(
              _proofBytes!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    color: Colors.purple[300],
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _proofFilename ?? 'Dokumen',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _proofMime ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.task_alt, color: Colors.green[600], size: 72),
              ),
              const SizedBox(height: 24),
              const Text(
                'Absensi Dinas Luar\nBerhasil Dicatat!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _uploadMsg,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Catatan',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Absensi ${widget.attendanceType == "checkin" ? "Masuk" : "Pulang"} '
                      'Anda telah tercatat di sistem dengan keterangan Dinas Luar.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
