// screens/add_time_off_screen.dart — FULL FINAL
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:absensikaryawan/Services/time_off_file_service.dart';
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../fitur/ajukanreimbursement.dart';

bool _isWideScreen(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 768;

// ═══════════════════════════════════════════════════════════════════════════════
// PendingFile — file yang dipilih user sebelum diupload
// ═══════════════════════════════════════════════════════════════════════════════
class PendingFile {
  final XFile xfile;
  final Uint8List? bytes;
  final int size;

  const PendingFile({required this.xfile, this.bytes, required this.size});

  String get name =>
      xfile.name.isNotEmpty ? xfile.name : xfile.path.split('/').last;
  String get ext =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isImage => ['jpg', 'jpeg', 'png'].contains(ext);

  String get sizeLabel {
    final mb = size / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(size / 1024).toStringAsFixed(0)} KB';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AddTimeOffScreen
// ═══════════════════════════════════════════════════════════════════════════════
class AddTimeOffScreen extends StatefulWidget {
  final String userId;
  final TimeOffModel? editData;
  const AddTimeOffScreen({super.key, required this.userId, this.editData});

  @override
  State<AddTimeOffScreen> createState() => _AddTimeOffScreenState();
}

class _AddTimeOffScreenState extends State<AddTimeOffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catatanCtrl = TextEditingController();
  final _nominalKantorCtrl = TextEditingController();

  String? _selectedJenis;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  bool _isLoading = false;
  bool _isEditMode = false;

  // ── Multi-file state ──────────────────────────────────────────────────────
  List<PendingFile> _pendingFiles = []; // file baru, belum diupload
  List<TimeOffFileItem> _existingFiles = []; // file sudah di server (edit mode)
  int _deletingId = -1; // id file yang sedang dihapus

  // ── DL state ──────────────────────────────────────────────────────────────
  String? _selectedJenisPekerjaan;
  String? _selectedRabType;
  final List<_ReimburseRow> _reimburseRows = [];

  // DL organization (loaded from API)
  List<String> _organizationList = [];
  bool _isLoadingOrg = false;

  final List<Map<String, dynamic>> _jenisTimeOff = [
    {
      'value': 'Izin Tahunan',
      'label': 'Izin Tahunan',
      'icon': '🏖️',
      'description': 'Cuti tahunan — memotong jatah cuti',
    },
    {
      'value': 'Sakit',
      'label': 'Izin Sakit',
      'icon': '🏥',
      'description': 'Izin sakit — tidak memotong cuti tahunan',
    },
    {
      'value': 'Umrah dan Haji',
      'label': 'Umrah dan Haji',
      'icon': '🕋',
      'description': 'Izin ibadah umrah/haji',
    },
    {
      'value': 'Izin Datang Terlambat',
      'label': 'Izin Datang Terlambat',
      'icon': '⏰',
      'description': 'Harus diajukan sebelum jam 10:00 pagi',
    },
    {
      'value': 'Izin Lahiran',
      'label': 'Izin Lahiran',
      'icon': '👶',
      'description': 'Izin melahirkan / mendampingi melahirkan',
    },
    {
      'value': 'Dinas Luar',
      'label': 'Dinas Luar',
      'icon': '🧳',
      'description': 'Perjalanan dinas — 2 tahap persetujuan',
    },
    {
      'value': 'Keluarga Meninggal',
      'label': 'Keluarga Meninggal',
      'icon': '🕯️',
      'description': 'Izin duka cita',
    },
  ];

  bool get _isDinasLuar => _selectedJenis == 'Dinas Luar';
  bool get _isFileRequired => _selectedJenis == 'Sakit';
  bool get _hasAnyFile => _existingFiles.isNotEmpty || _pendingFiles.isNotEmpty;

  double _rp(BuildContext ctx, double base) =>
      (base * (MediaQuery.of(ctx).size.width / 375)).clamp(
        base * 0.85,
        base * 1.1,
      );

  // ── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _isEditMode = widget.editData != null;
    if (_isEditMode) _loadEditData();
  }

  void _loadEditData() {
    final d = widget.editData!;
    _selectedJenis = d.jenisTimeOff;
    _tanggalMulai = d.tanggalMulai;
    _tanggalSelesai = d.tanggalSelesai;
    _catatanCtrl.text = d.catatan ?? '';
    _selectedJenisPekerjaan = d.jenisPekerjaan;
    _selectedRabType = d.rabType;
    if (d.nominalUangKantor != null)
      _nominalKantorCtrl.text = d.nominalUangKantor!.toStringAsFixed(0);
    if (d.reimbursementItems != null) {
      for (final item in d.reimbursementItems!) {
        _reimburseRows.add(
          _ReimburseRow(
            namaCtrl: TextEditingController(text: item.namaItem),
            nominalCtrl: TextEditingController(
              text: item.nominal.toStringAsFixed(0),
            ),
            ketCtrl: TextEditingController(text: item.keterangan ?? ''),
          ),
        );
      }
    }
    if (d.files != null) _existingFiles = List.from(d.files!);
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedJenis == null) {
      _snack('Pilih jenis izin', err: true);
      return;
    }
    if (_tanggalMulai == null) {
      _snack('Pilih tanggal mulai', err: true);
      return;
    }
    if (_tanggalSelesai == null) {
      _snack('Pilih tanggal selesai', err: true);
      return;
    }
    if (_isFileRequired && !_hasAnyFile) {
      _snack('File surat dokter WAJIB untuk Izin Sakit', err: true);
      return;
    }
    if (_isDinasLuar &&
        (_selectedJenisPekerjaan == null || _selectedJenisPekerjaan!.isEmpty)) {
      _snack('Jenis pekerjaan wajib diisi untuk Dinas Luar', err: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final reimburseItems = _selectedRabType == 'reimbursement'
          ? _reimburseRows
                .where((r) => r.namaCtrl.text.trim().isNotEmpty)
                .map(
                  (r) => ReimbursementItem(
                    namaItem: r.namaCtrl.text.trim(),
                    nominal:
                        double.tryParse(
                          r.nominalCtrl.text.trim().replaceAll(
                            RegExp(r'[^0-9.]'),
                            '',
                          ),
                        ) ??
                        0,
                    keterangan: r.ketCtrl.text.trim().isEmpty
                        ? null
                        : r.ketCtrl.text.trim(),
                  ),
                )
                .toList()
          : null;

      final double? nominalKantor =
          _selectedRabType == 'uang_kantor' &&
              _nominalKantorCtrl.text.trim().isNotEmpty
          ? double.tryParse(
              _nominalKantorCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), ''),
            )
          : null;

      // ── File pertama: kirim via BYTES (web + mobile) ──────────────────────
      final PendingFile? firstPending = _pendingFiles.isNotEmpty
          ? _pendingFiles.first
          : null;

      // File path hanya untuk fallback mobile (tidak dipakai kalau bytes ada)
      File? firstFile;
      if (firstPending != null && !kIsWeb) {
        firstFile = File(firstPending.xfile.path);
      }

      // bytes & nama file pertama (sumber utama yang dikirim ke server)
      final List<int>? firstBytes = firstPending?.bytes;
      final String? firstName = firstPending?.name;

      int? newTimeOffId;

      if (_isEditMode) {
        final req = UpdateTimeOffRequest(
          id: widget.editData!.id!,
          userId: widget.userId,
          jenisTimeOff: _selectedJenis!.trim(),
          tanggalMulai: _tanggalMulai!,
          tanggalSelesai: _tanggalSelesai!,
          catatan: _catatanCtrl.text.trim().isEmpty
              ? null
              : _catatanCtrl.text.trim(),
          receiptFile: firstFile,
          jenisPekerjaan: _selectedJenisPekerjaan,
          rabType: _selectedRabType,
          nominalUangKantor: nominalKantor,
          reimbursementItems: reimburseItems,
        );
        final res = await TimeOffService.updateTimeOff(
          req,
          receiptBytes: firstBytes,
          receiptFileName: firstName,
        );
        if (!res.success) {
          _snack(res.message, err: true);
          return;
        }
        newTimeOffId = widget.editData!.id!;
        _snack('Izin berhasil diupdate!', err: false);
      } else {
        final req = TimeOffRequest(
          userId: widget.userId,
          jenisTimeOff: _selectedJenis!.trim(),
          tanggalMulai: _tanggalMulai!,
          tanggalSelesai: _tanggalSelesai!,
          catatan: _catatanCtrl.text.trim().isEmpty
              ? null
              : _catatanCtrl.text.trim(),
          receiptFile: firstFile,
          jenisPekerjaan: _selectedJenisPekerjaan,
          rabType: _selectedRabType,
          nominalUangKantor: nominalKantor,
          reimbursementItems: reimburseItems,
        );
        final res = await TimeOffService.submitTimeOff(
          req,
          receiptBytes: firstBytes,
          receiptFileName: firstName,
        );
        if (!res.success || res.data == null) {
          _snack(res.message, err: true);
          return;
        }
        newTimeOffId = res.data!;
        _snack('Izin berhasil diajukan!', err: false);
        await _showSuccessNotif(newTimeOffId.toString());
      }

      // ── File ke-2 dst via multi-file endpoint ─────────────────────────────
      // Catatan: uploadFiles saat ini pakai dart:io File → mobile saja.
      // Di web, file ke-2 dst belum terkirim (butuh versi bytes).
      final extraFiles = _isEditMode
          ? _pendingFiles
          : _pendingFiles.skip(1).toList();
      if (extraFiles.isNotEmpty && !kIsWeb) {
        final uploadReq = UploadTimeOffFilesRequest(
          timeOffId: newTimeOffId,
          userId: widget.userId,
          files: extraFiles.map((f) => File(f.xfile.path)).toList(),
        );
        await TimeOffFileService.uploadFiles(uploadReq);
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Terjadi kesalahan: $e', err: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Delete existing file ──────────────────────────────────────────────────

  Future<void> _deleteExistingFile(TimeOffFileItem file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus File'),
        content: Text('Hapus "${file.fileName}"?'),
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

    setState(() => _deletingId = file.id);
    final res = await TimeOffFileService.deleteFile(
      DeleteTimeOffFileRequest(
        fileId: file.id,
        timeOffId: widget.editData!.id!,
        userId: widget.userId,
      ),
    );
    if (mounted) setState(() => _deletingId = -1);
    if (res.success) {
      setState(() => _existingFiles.removeWhere((f) => f.id == file.id));
      _snack('File dihapus', err: false);
    } else {
      _snack(res.message, err: true);
    }
  }

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _loadOrganizationList() async {
    if (mounted) setState(() => _isLoadingOrg = true);
    try {
      final res = await TimeOffService.getOrganizationList(widget.userId);
      if (res.success && res.data != null && mounted) {
        setState(() {
          _organizationList = res.data!;
          if (_selectedJenisPekerjaan != null &&
              !_organizationList.contains(_selectedJenisPekerjaan)) {
            _selectedJenisPekerjaan = null;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingOrg = false);
    }
  }

  void _showPickOptions() {
    showModalBottomSheet(
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
                'Tambah File',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(),
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
              subtitle: Text(
                kIsWeb
                    ? 'Pilih / ambil foto (browser)'
                    : 'Ambil foto dari kamera',
              ),
              onTap: () {
                Navigator.pop(context);
                _pickCamera();
              },
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
              subtitle: Text(
                kIsWeb ? 'Pilih gambar (JPG, PNG)' : 'Pilih dari galeri',
              ),
              onTap: () {
                Navigator.pop(context);
                _pickGallery();
              },
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
                'File Dokumen',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('PDF, JPG, atau PNG (Max 10MB/file)'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCamera() async {
    if (kIsWeb) {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (r != null) await _addFromPicker(r.files);
    } else {
      final img = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (img != null) await _addXFile(img);
    }
  }

  Future<void> _pickGallery() async {
    if (kIsWeb) {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (r != null) await _addFromPicker(r.files);
    } else {
      final imgs = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      for (final img in imgs) {
        await _addXFile(img);
      }
    }
  }

  Future<void> _pickDocument() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (r != null) await _addFromPicker(r.files);
  }

  Future<void> _addXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (!_validateFile(file.name, bytes.length)) return;
      setState(
        () => _pendingFiles = [
          ..._pendingFiles,
          PendingFile(xfile: file, bytes: bytes, size: bytes.length),
        ],
      );
    } catch (e) {
      _snack('Gagal memproses file: $e', err: true);
    }
  }

  Future<void> _addFromPicker(List<PlatformFile> files) async {
    final newList = List<PendingFile>.from(_pendingFiles);
    for (final f in files) {
      try {
        Uint8List? bytes;
        XFile xfile;
        if (kIsWeb || f.bytes != null) {
          bytes = f.bytes;
          if (bytes == null) {
            _snack('${f.name}: tidak dapat dibaca', err: true);
            continue;
          }
          xfile = XFile.fromData(bytes, name: f.name);
        } else if (f.path != null) {
          xfile = XFile(f.path!);
          bytes = await xfile.readAsBytes();
        } else {
          continue;
        }
        if (!_validateFile(f.name, bytes.length)) continue;
        newList.add(
          PendingFile(xfile: xfile, bytes: bytes, size: bytes.length),
        );
      } catch (e) {
        _snack('${f.name}: $e', err: true);
      }
    }
    setState(() => _pendingFiles = newList);
  }

  bool _validateFile(String name, int size) {
    if (size > 10 * 1024 * 1024) {
      _snack('$name: Ukuran maksimal 10MB', err: true);
      return false;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
      _snack('$name: Format tidak didukung (JPG/PNG/PDF)', err: true);
      return false;
    }
    return true;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = _isEditMode
        ? const Color(0xFFEF4444)
        : const Color(0xFF3B82F6);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Izin' : 'Ajukan Izin',
          style: const TextStyle(
            fontSize: 22,
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
              Icons.close_rounded,
              color: Color(0xFF374151),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: _isWideScreen(context)
          ? _buildWebLayout(accent)
          : _buildMobileLayout(accent),
    );
  }

  Widget _buildMobileLayout(Color accent) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(accent),
          const SizedBox(height: 24),
          _buildSectionTitle('Jenis Izin', Icons.category_rounded),
          const SizedBox(height: 12),
          _buildJenisSelector(),
          const SizedBox(height: 24),
          _buildSectionTitle('Periode Izin', Icons.date_range_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Tanggal Mulai',
                  date: _tanggalMulai,
                  onTap: () => _selectDate(isStart: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField(
                  label: 'Tanggal Selesai',
                  date: _tanggalSelesai,
                  onTap: () => _selectDate(isStart: false),
                  enabled: _tanggalMulai != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Catatan & Alasan', Icons.note_alt_rounded),
          const SizedBox(height: 12),
          _buildCatatanField(),
          if (_isDinasLuar) ...[const SizedBox(height: 24), _buildDlSection()],
          const SizedBox(height: 24),
          _buildFileSection(),
          const SizedBox(height: 24),
          _buildSubmitButton(accent),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );

  Widget _buildWebLayout(Color accent) => Form(
    key: _formKey,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 360,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBanner(accent),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Jenis Izin', Icons.category_rounded),
                  const SizedBox(height: 12),
                  _buildJenisSelector(),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Periode Izin', Icons.date_range_rounded),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        label: 'Tanggal Mulai',
                        date: _tanggalMulai,
                        onTap: () => _selectDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateField(
                        label: 'Tanggal Selesai',
                        date: _tanggalSelesai,
                        onTap: () => _selectDate(isStart: false),
                        enabled: _tanggalMulai != null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Catatan & Alasan', Icons.note_alt_rounded),
                const SizedBox(height: 12),
                _buildCatatanField(),
                if (_isDinasLuar) ...[
                  const SizedBox(height: 24),
                  _buildDlSection(),
                ],
                const SizedBox(height: 24),
                _buildFileSection(),
                const SizedBox(height: 24),
                _buildSubmitButton(accent),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ── Header banner ─────────────────────────────────────────────────────────

  Widget _buildHeaderBanner(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isEditMode
              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
              : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditMode ? 'Edit Pengajuan' : 'Informasi Pengajuan',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isEditMode
                ? 'Pastikan data sudah benar sebelum menyimpan.'
                : 'Pengajuan akan direview oleh atasan. Pastikan data sudah benar.',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          if (_calculateDays() > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total: ${_calculateDays()} hari',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
      ),
      const SizedBox(width: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
      ),
    ],
  );

  // ── Jenis selector ────────────────────────────────────────────────────────

  Widget _buildJenisSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: _jenisTimeOff.map((jenis) {
          final isSelected = _selectedJenis == jenis['value'];
          final isLast = jenis == _jenisTimeOff.last;
          return InkWell(
            onTap: () => setState(() {
              _selectedJenis = jenis['value'];
              if (_selectedJenis != 'Dinas Luar') {
                _selectedJenisPekerjaan = null;
                _selectedRabType = null;
                _reimburseRows.clear();
                _nominalKantorCtrl.clear();
                _organizationList = [];
              } else {
                // Load organization list dari API saat pilih Dinas Luar
                _loadOrganizationList();
              }
            }),
            borderRadius: BorderRadius.vertical(
              top: jenis == _jenisTimeOff.first
                  ? const Radius.circular(12)
                  : Radius.zero,
              bottom: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3B82F6).withOpacity(0.08)
                    : Colors.transparent,
                border: !isLast
                    ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
                    : null,
              ),
              child: Row(
                children: [
                  Text(jenis['icon'], style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jenis['label'],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          jenis['description'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Date field ────────────────────────────────────────────────────────────

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 17,
                  color: enabled
                      ? (date != null
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF9CA3AF))
                      : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('dd MMM yyyy').format(date)
                        : 'Pilih tanggal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? (date != null
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF9CA3AF))
                          : const Color(0xFF9CA3AF),
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

  // ── Catatan field ─────────────────────────────────────────────────────────

  Widget _buildCatatanField() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: TextFormField(
      controller: _catatanCtrl,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Jelaskan alasan atau detail izin Anda...',
        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(16),
      ),
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1F2937),
        height: 1.5,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Catatan tidak boleh kosong';
        if (v.trim().length < 10) return 'Catatan minimal 10 karakter';
        return null;
      },
    ),
  );

  // ── DL Section ────────────────────────────────────────────────────────────

  Widget _buildDlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Detail Dinas Luar', Icons.work_outline_rounded),
        const SizedBox(height: 12),

        // Jenis pekerjaan — dynamic dari API (organization per company)
        if (_isLoadingOrg)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
              ),
            ),
          )
        else if (_organizationList.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  size: 16,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tidak ada divisi yang tersedia. Pastikan data company sudah diisi.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _loadOrganizationList,
                  child: Icon(
                    Icons.refresh,
                    color: Colors.orange[700],
                    size: 18,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedJenisPekerjaan,
                isExpanded: true,
                hint: const Text(
                  'Pilih Divisi / Departemen *',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
                items: _organizationList
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedJenisPekerjaan = v),
              ),
            ),
          ),

        const SizedBox(height: 16),
        _buildSectionTitle(
          'Rencana Anggaran Biaya',
          Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _buildRabChip('reimbursement', '💸 Reimbursement'),
            _buildRabChip('uang_kantor', '🏢 Uang Kantor'),
            _buildRabChip(null, '❌ Tidak Ada'),
          ],
        ),

        if (_selectedRabType == 'uang_kantor') ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextFormField(
              controller: _nominalKantorCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Nominal uang kantor (Rp)',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                prefixText: 'Rp ',
              ),
              style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
            ),
          ),
        ],

        if (_selectedRabType == 'reimbursement') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail Pengeluaran',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 10),
                ..._reimburseRows.asMap().entries.map(
                  (e) => _buildReimburseRow(e.key, e.value),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _reimburseRows.add(
                      _ReimburseRow(
                        namaCtrl: TextEditingController(),
                        nominalCtrl: TextEditingController(),
                        ketCtrl: TextEditingController(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Tambah Item'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dinas Luar memerlukan 2 tahap persetujuan (Manager → HRD), lalu upload laporan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRabChip(String? value, String label) => GestureDetector(
    onTap: () => setState(() => _selectedRabType = value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _selectedRabType == value
            ? const Color(0xFF3B82F6)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selectedRabType == value
              ? const Color(0xFF3B82F6)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _selectedRabType == value
              ? Colors.white
              : const Color(0xFF374151),
        ),
      ),
    ),
  );

  Widget _buildReimburseRow(int index, _ReimburseRow row) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: row.namaCtrl,
            decoration: InputDecoration(
              hintText: 'Item (Bensin, Makan...)',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: row.nominalCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Nominal',
              prefixText: 'Rp ',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(
            Icons.remove_circle_outline,
            color: Colors.red,
            size: 20,
          ),
          onPressed: () => setState(() => _reimburseRows.removeAt(index)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );

  // ── File section ──────────────────────────────────────────────────────────

  Widget _buildFileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_isFileRequired && !_hasAnyFile)
                    ? Colors.red.withOpacity(0.1)
                    : const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.upload_file_outlined,
                size: 20,
                color: (_isFileRequired && !_hasAnyFile)
                    ? Colors.red[600]
                    : const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isFileRequired
                  ? 'Upload File (Wajib)'
                  : 'Upload File (Opsional)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const Spacer(),
            if (_hasAnyFile)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_existingFiles.length + _pendingFiles.length} file',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: EdgeInsets.all(_rp(context, 16)),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isFileRequired ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isFileRequired
                        ? Colors.red[200]!
                        : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFileRequired
                          ? Icons.warning_rounded
                          : Icons.info_outline,
                      size: 16,
                      color: _isFileRequired
                          ? Colors.red[600]
                          : Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isFileRequired
                            ? 'Upload surat dokter atau keterangan medis (WAJIB)'
                            : 'Bisa upload lebih dari satu file. JPG, PNG, atau PDF (Max 10MB/file)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isFileRequired
                              ? Colors.red[700]
                              : Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Existing files (edit mode)
              if (_existingFiles.isNotEmpty) ...[
                const Text(
                  'File tersimpan:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                ..._existingFiles.map((f) => _buildExistingFileRow(f)),
                const SizedBox(height: 12),
              ],

              // Pending files
              if (_pendingFiles.isNotEmpty) ...[
                const Text(
                  'File baru:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                ..._pendingFiles.asMap().entries.map(
                  (e) => _buildPendingFileRow(e.key, e.value),
                ),
                const SizedBox(height: 12),
              ],

              // Tombol tambah
              GestureDetector(
                onTap: _showPickOptions,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_hasAnyFile && _isFileRequired
                          ? Colors.red[300]!
                          : const Color(0xFF3B82F6),
                      width: !_hasAnyFile && _isFileRequired ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: !_hasAnyFile && _isFileRequired
                            ? Colors.red[500]
                            : const Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hasAnyFile ? 'Tambah File Lagi' : '+ Upload File',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !_hasAnyFile && _isFileRequired
                              ? Colors.red[600]
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExistingFileRow(TimeOffFileItem file) {
    final isDeleting = _deletingId == file.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(_fileIcon(file.ext), color: _fileColor(file.ext), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (file.sizeLabel.isNotEmpty)
                  Text(
                    file.sizeLabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Tersimpan',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (isDeleting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            GestureDetector(
              onTap: () => _deleteExistingFile(file),
              child: Container(
                padding: const EdgeInsets.all(4),
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
  }

  Widget _buildPendingFileRow(int index, PendingFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(_fileIcon(file.ext), color: _fileColor(file.ext), size: 22),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  file.sizeLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Baru',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(
              () => _pendingFiles = [..._pendingFiles]..removeAt(index),
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
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
  }

  IconData _fileIcon(String ext) {
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

  Color _fileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red[600]!;
      case 'jpg':
      case 'jpeg':
        return Colors.blue[600]!;
      case 'png':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // ── Submit button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton(Color accent) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Memproses...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            )
          : Text(
              _isEditMode ? 'Update Izin' : 'Ajukan Izin',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    ),
  );

  // ── Utilities ─────────────────────────────────────────────────────────────

  int _calculateDays() {
    if (_tanggalMulai != null && _tanggalSelesai != null)
      return _tanggalSelesai!.difference(_tanggalMulai!).inDays + 1;
    return 0;
  }

  Future<void> _selectDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_tanggalMulai ?? DateTime.now())
          : (_tanggalSelesai ?? _tanggalMulai ?? DateTime.now()),
      firstDate: _isEditMode
          ? DateTime(2020)
          : DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF3B82F6),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1F2937),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null)
      setState(() {
        if (isStart) {
          _tanggalMulai = picked;
          if (_tanggalSelesai != null && _tanggalSelesai!.isBefore(picked))
            _tanggalSelesai = null;
        } else {
          _tanggalSelesai = picked;
        }
      });
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

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> _initNotifications() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await flutterLocalNotificationsPlugin.initialize(
      init,
      onDidReceiveNotificationResponse: (_) {},
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'timeoff_channel',
            'Time Off Notifications',
            description: 'Notifikasi pengajuan izin',
            importance: Importance.high,
          ),
        );
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final s = await Permission.notification.request();
        if (s.isPermanentlyDenied && mounted) _showSettingsDialog();
      }
    } catch (_) {}
  }

  void _showSettingsDialog() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Izin Notifikasi Diperlukan'),
      content: const Text('Buka pengaturan untuk mengaktifkan notifikasi.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings();
          },
          child: const Text('Buka Pengaturan'),
        ),
      ],
    ),
  );

  Future<void> _showSuccessNotif(String id) async {
    if (Theme.of(context).platform == TargetPlatform.android &&
        !(await Permission.notification.status).isGranted)
      return;
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Izin Berhasil Diajukan ✅',
      'Pengajuan ${_selectedJenis ?? "Izin"} telah dikirim untuk review',
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'timeoff_channel',
          'Time Off Notifications',
          channelDescription: 'Notifikasi pengajuan izin',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'timeoff_$id',
    );
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    _nominalKantorCtrl.dispose();
    for (final r in _reimburseRows) {
      r.namaCtrl.dispose();
      r.nominalCtrl.dispose();
      r.ketCtrl.dispose();
    }
    super.dispose();
  }
}

class _ReimburseRow {
  final TextEditingController namaCtrl, nominalCtrl, ketCtrl;
  _ReimburseRow({
    required this.namaCtrl,
    required this.nominalCtrl,
    required this.ketCtrl,
  });
}
