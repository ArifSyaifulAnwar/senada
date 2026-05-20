// screens/add_time_off_screen.dart — FULL REPLACE
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously, deprecated_member_use

import 'dart:io' show File;

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

// ── Jenis pekerjaan DL ──────────────────────────────────────────────────────
const List<String> _jenisPekerjaanOptions = [
  'Legal',
  'IT',
  'Finance',
  'Marketing',
  'Operasional',
  'Pengadaan',
  'SDM',
  'Teknis',
  'Lainnya',
];

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

  // File receipt
  XFile? _selectedImage;
  int _selectedImageSize = 0;
  bool _hasExistingFile = false;
  String? _existingFileName;
  bool _keepExistingFile = true;
  bool _isDownloadingFile = false;

  // ── DL fields ──────────────────────────────────────────────────────────────
  String? _selectedJenisPekerjaan;
  String? _selectedRabType; // 'reimbursement' | 'uang_kantor' | null
  final List<_ReimburseRow> _reimburseRows = [];

  // ── Jenis list ─────────────────────────────────────────────────────────────
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
      'description': 'Perjalanan dinas — memerlukan laporan',
    },
    {
      'value': 'Keluarga Meninggal',
      'label': 'Keluarga Meninggal',
      'icon': '🕯️',
      'description': 'Izin duka cita',
    },
  ];

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _isDinasLuar => _selectedJenis == 'Dinas Luar';

  bool _isFileRequired() =>
      _selectedJenis == 'Sakit' || _selectedJenis == 'Izin Khusus';

  String _fileUploadInfo() {
    if (_selectedJenis == 'Sakit') return 'Upload surat dokter (WAJIB)';
    if (_selectedJenis == null) {
      return 'Pilih jenis izin untuk melihat persyaratan file';
    }
    return 'Upload dokumen pendukung (OPSIONAL)';
  }

  // ignore: unused_element
  double _getResponsiveFontSize(BuildContext ctx, double base) =>
      (base * (MediaQuery.of(ctx).size.width / 375)).clamp(
        base * 0.85,
        base * 1.15,
      );

  double _getResponsivePadding(BuildContext ctx, double base) =>
      (base * (MediaQuery.of(ctx).size.width / 375)).clamp(
        base * 0.85,
        base * 1.1,
      );

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
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
    if (d.nominalUangKantor != null) {
      _nominalKantorCtrl.text = d.nominalUangKantor!.toStringAsFixed(0);
    }
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
    if (d.fileName != null && d.fileName!.isNotEmpty) {
      _hasExistingFile = true;
      _existingFileName = d.fileName;
      _keepExistingFile = true;
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedJenis == null) {
      _showSnackBar('Pilih jenis izin', isError: true);
      return;
    }
    if (_tanggalMulai == null) {
      _showSnackBar('Pilih tanggal mulai', isError: true);
      return;
    }
    if (_tanggalSelesai == null) {
      _showSnackBar('Pilih tanggal selesai', isError: true);
      return;
    }
    if (!_isEditMode && _isFileRequired() && _selectedImage == null) {
      _showSnackBar(
        'File pendukung WAJIB untuk "$_selectedJenis".',
        isError: true,
      );
      return;
    }
    if (_isDinasLuar &&
        (_selectedJenisPekerjaan == null || _selectedJenisPekerjaan!.isEmpty)) {
      _showSnackBar(
        'Jenis pekerjaan wajib diisi untuk Dinas Luar',
        isError: true,
      );
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
          receiptFile: (!_keepExistingFile && _selectedImage != null && !kIsWeb)
              ? File(_selectedImage!.path)
              : null,
          jenisPekerjaan: _selectedJenisPekerjaan,
          rabType: _selectedRabType,
          nominalUangKantor: nominalKantor,
          reimbursementItems: reimburseItems,
        );
        final res = await TimeOffService.updateTimeOff(req);
        if (res.success) {
          _showSnackBar('Izin berhasil diupdate!', isError: false);
          Navigator.of(context).pop(true);
        } else {
          _showSnackBar(res.message, isError: true);
        }
      } else {
        final req = TimeOffRequest(
          userId: widget.userId,
          jenisTimeOff: _selectedJenis!.trim(),
          tanggalMulai: _tanggalMulai!,
          tanggalSelesai: _tanggalSelesai!,
          catatan: _catatanCtrl.text.trim().isEmpty
              ? null
              : _catatanCtrl.text.trim(),
          receiptFile: (_selectedImage != null && !kIsWeb)
              ? File(_selectedImage!.path)
              : null,
          jenisPekerjaan: _selectedJenisPekerjaan,
          rabType: _selectedRabType,
          nominalUangKantor: nominalKantor,
          reimbursementItems: reimburseItems,
        );
        final res = await TimeOffService.submitTimeOff(req);
        if (res.success && res.data != null) {
          _showSnackBar('Izin berhasil diajukan!', isError: false);
          await _showSuccessNotification(res.data.toString());
          Navigator.of(context).pop(true);
        } else {
          _showSnackBar(res.message, isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
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

  // ── Mobile layout ──────────────────────────────────────────────────────────
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
                  onTap: () => _selectDate(isStartDate: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField(
                  label: 'Tanggal Selesai',
                  date: _tanggalSelesai,
                  onTap: () => _selectDate(isStartDate: false),
                  enabled: _tanggalMulai != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Catatan & Alasan', Icons.note_alt_rounded),
          const SizedBox(height: 12),
          _buildCatatanField(),
          // ── DL section ─────────────────────────────────────────────────
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

  // ── Web layout ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout(Color accent) => Form(
    key: _formKey,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kolom kiri
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
        // Kolom kanan
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
                        onTap: () => _selectDate(isStartDate: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateField(
                        label: 'Tanggal Selesai',
                        date: _tanggalSelesai,
                        onTap: () => _selectDate(isStartDate: false),
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

  // ── DL Section ─────────────────────────────────────────────────────────────
  Widget _buildDlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Detail Dinas Luar', Icons.work_outline_rounded),
        const SizedBox(height: 12),

        // Jenis pekerjaan dropdown
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
                'Pilih Jenis Pekerjaan *',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
              items: _jenisPekerjaanOptions
                  .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedJenisPekerjaan = v),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // RAB type
        _buildSectionTitle(
          'Rencana Anggaran Biaya',
          Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRabChip('reimbursement', '💸 Reimbursement'),
            const SizedBox(width: 10),
            _buildRabChip('uang_kantor', '🏢 Uang Kantor'),
            const SizedBox(width: 10),
            _buildRabChip(null, '❌ Tidak Ada'),
          ],
        ),

        // Uang kantor nominal
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

        // Reimbursement items
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

        // Info multi-step approval
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
                  'Dinas Luar memerlukan 2 tahap persetujuan: Manager → HRD. Setelah selesai, upload laporan & anggaran.',
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
              prefixText: 'Rp ',
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

  // ── Shared Widgets (preserved from original) ───────────────────────────────

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
                ? 'Anda sedang mengedit pengajuan izin. Pastikan data sudah benar.'
                : 'Pastikan data yang Anda masukkan sudah benar. Pengajuan akan direview.',
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
              // Reset DL fields when switching away
              if (_selectedJenis != 'Dinas Luar') {
                _selectedJenisPekerjaan = null;
                _selectedRabType = null;
                _reimburseRows.clear();
                _nominalKantorCtrl.clear();
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

  Widget _buildFileSection() {
    final isRequired = _isFileRequired();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          isRequired ? 'Upload File (Wajib)' : 'Upload File (Opsional)',
          Icons.upload_file_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRequired ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRequired ? Colors.red[200]! : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isRequired ? Icons.warning_rounded : Icons.info_outline,
                      size: 16,
                      color: isRequired ? Colors.red[600] : Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileUploadInfo(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isRequired
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
              if (_isEditMode && _hasExistingFile) ...[
                _buildExistingFilePreview(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _keepExistingFile
                            ? null
                            : _keepExistingFileOption,
                        icon: Icon(
                          _keepExistingFile
                              ? Icons.check_circle
                              : Icons.restore,
                          size: 17,
                        ),
                        label: const Text(
                          'Pertahankan',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _keepExistingFile
                              ? Colors.green[100]
                              : Colors.grey[100],
                          foregroundColor: _keepExistingFile
                              ? Colors.green[700]
                              : Colors.grey[700],
                          side: BorderSide(
                            color: _keepExistingFile
                                ? Colors.green[300]!
                                : Colors.grey[300]!,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: !_keepExistingFile ? null : _chooseNewFile,
                        icon: Icon(
                          !_keepExistingFile
                              ? Icons.check_circle
                              : Icons.refresh_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'Ganti File',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_keepExistingFile
                              ? Colors.blue[100]
                              : Colors.grey[100],
                          foregroundColor: !_keepExistingFile
                              ? Colors.blue[700]
                              : Colors.grey[700],
                          side: BorderSide(
                            color: !_keepExistingFile
                                ? Colors.blue[300]!
                                : Colors.grey[300]!,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!_isEditMode || !_keepExistingFile) _buildFilePreview(),
            ],
          ),
        ),
      ],
    );
  }

  // ── (file preview widgets identical to original — paste from original) ─────
  Widget _buildExistingFilePreview() {
    if (!_hasExistingFile || _existingFileName == null) {
      return const SizedBox.shrink();
    }
    final ext = _existingFileName!.split('.').last.toLowerCase();
    IconData icon;
    Color iconColor;
    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        iconColor = Colors.red[600]!;
        break;
      case 'jpg':
      case 'jpeg':
        icon = Icons.image;
        iconColor = Colors.blue[600]!;
        break;
      case 'png':
        icon = Icons.image;
        iconColor = Colors.green[600]!;
        break;
      default:
        icon = Icons.insert_drive_file;
        iconColor = Colors.grey[600]!;
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _keepExistingFile ? Colors.green[300]! : Colors.grey[300]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _existingFileName!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    ext.toUpperCase(),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (_isDownloadingFile)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: Icon(Icons.download, color: Colors.grey[600], size: 18),
                onPressed: _downloadExistingFile,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    final isRequired = _isFileRequired();
    if (_selectedImage == null) {
      return GestureDetector(
        onTap: () => _showFileSourceOptions(context),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          height: 110,
          decoration: BoxDecoration(
            border: Border.all(
              color: isRequired ? Colors.red[300]! : Colors.grey[300]!,
              width: isRequired ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.upload_file_outlined,
                size: 28,
                color: isRequired ? Colors.red[400] : Colors.grey[500],
              ),
              const SizedBox(height: 6),
              Text(
                isRequired
                    ? 'Tap untuk upload (WAJIB)'
                    : 'Tap untuk upload (OPSIONAL)',
                style: TextStyle(
                  fontSize: 13,
                  color: isRequired ? Colors.red[600] : Colors.grey[600],
                ),
              ),
              Text(
                'JPG, PNG, atau PDF (Max 10MB)',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }
    final fileName = _selectedImage!.name.isNotEmpty
        ? _selectedImage!.name
        : _selectedImage!.path.split('/').last;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue[300]!, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_getFileIcon(ext), color: Colors.blue[600], size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${(_selectedImageSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red[600], size: 18),
              onPressed: () => setState(() {
                _selectedImage = null;
                if (_isEditMode && _hasExistingFile) _keepExistingFile = true;
              }),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String ext) {
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

  // ── Utility methods (preserved from original) ──────────────────────────────

  int _calculateDays() {
    if (_tanggalMulai != null && _tanggalSelesai != null) {
      return _tanggalSelesai!.difference(_tanggalMulai!).inDays + 1;
    }
    return 0;
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_tanggalMulai ?? DateTime.now())
          : (_tanggalSelesai ?? _tanggalMulai ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
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
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _tanggalMulai = picked;
          if (_tanggalSelesai != null && _tanggalSelesai!.isBefore(picked)) {
            _tanggalSelesai = null;
          }
        } else {
          _tanggalSelesai = picked;
        }
      });
    }
  }

  Future<void> _downloadExistingFile() async {
    if (!_hasExistingFile || widget.editData?.id == null) {
      _showErrorSnackBar('File tidak tersedia');
      return;
    }
    setState(() => _isDownloadingFile = true);
    try {
      final res = await TimeOffService.downloadFile(
        widget.editData!.id!,
        widget.userId,
      );
      _showSnackBar(
        res.success ? 'File berhasil didownload' : res.message,
        isError: !res.success,
      );
    } catch (e) {
      _showErrorSnackBar('Gagal mendownload: $e');
    } finally {
      setState(() => _isDownloadingFile = false);
    }
  }

  void _chooseNewFile() {
    setState(() {
      _keepExistingFile = false;
      _selectedImage = null;
    });
    _showFileSourceOptions(context);
  }

  void _keepExistingFileOption() {
    setState(() {
      _keepExistingFile = true;
      _selectedImage = null;
    });
  }

  void _showFileSourceOptions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
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
                'Pilih Sumber File',
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
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
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
                'Galeri',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
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
              onTap: () {
                Navigator.pop(ctx);
                _pickFromFiles();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    if (kIsWeb) {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );
      if (r != null && r.files.isNotEmpty) {
        await _validateAndSetFileFromPicker(r.files.first);
      }
    } else {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (img != null) await _validateAndSetFile(img);
    }
  }

  Future<void> _pickFromCamera() async {
    if (kIsWeb) {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (r != null && r.files.isNotEmpty) {
        await _validateAndSetFileFromPicker(r.files.first);
      }
    } else {
      final img = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (img != null) await _validateAndSetFile(img);
    }
  }

  Future<void> _pickFromFiles() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (r != null && r.files.isNotEmpty) {
      final f = r.files.first;
      if (kIsWeb) {
        await _validateAndSetFileFromPicker(f);
      } else if (f.path != null)
        await _validateAndSetFile(XFile(f.path!));
      else if (f.bytes != null)
        await _validateAndSetFileFromPicker(f);
    }
  }

  Future<void> _validateAndSetFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        _showErrorSnackBar('Ukuran file maksimal 10MB');
        return;
      }
      final ext = file.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
        _showErrorSnackBar('Format tidak didukung');
        return;
      }
      setState(() {
        _selectedImage = file;
        _selectedImageSize = bytes.length;
        if (_isEditMode) _keepExistingFile = false;
      });
      _showSuccessSnackBar('File berhasil dipilih');
    } catch (e) {
      _showErrorSnackBar('Gagal memproses file: $e');
    }
  }

  Future<void> _validateAndSetFileFromPicker(PlatformFile file) async {
    try {
      final bytes = file.bytes;
      if (bytes == null) {
        _showErrorSnackBar('Tidak dapat membaca file');
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        _showErrorSnackBar('Ukuran file maksimal 10MB');
        return;
      }
      final ext = (file.extension ?? '').toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
        _showErrorSnackBar('Format tidak didukung');
        return;
      }
      final xf = XFile.fromData(
        bytes,
        name: file.name,
        mimeType: _getMimeType(ext),
      );
      setState(() {
        _selectedImage = xf;
        _selectedImageSize = bytes.length;
        if (_isEditMode) _keepExistingFile = false;
      });
      _showSuccessSnackBar('File berhasil dipilih: ${file.name}');
    } catch (e) {
      _showErrorSnackBar('Gagal memproses file: $e');
    }
  }

  String _getMimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

  // ── Notifications (unchanged from original) ────────────────────────────────

  Future<void> _initializeNotifications() async {
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
    await _createNotificationChannel();
    await _requestNotificationPermission();
  }

  Future<void> _createNotificationChannel() async {
    const ch = AndroidNotificationChannel(
      'timeoff_channel',
      'Time Off Notifications',
      description: 'Notifikasi pengajuan izin',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(ch);
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final s = await Permission.notification.request();
        if (s.isDenied && mounted) _showPermissionDialog();
        if (s.isPermanentlyDenied && mounted) _showSettingsDialog();
      }
    } catch (_) {}
  }

  void _showPermissionDialog() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Izin Notifikasi'),
      content: const Text('Diperlukan untuk notifikasi status izin.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nanti'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _requestNotificationPermission();
          },
          child: const Text('Berikan Izin'),
        ),
      ],
    ),
  );

  void _showSettingsDialog() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Izin Notifikasi Diperlukan'),
      content: const Text(
        'Buka pengaturan aplikasi untuk mengaktifkan notifikasi.',
      ),
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

  Future<void> _showSuccessNotification(String timeOffId) async {
    if (!await _checkNotificationPermission()) return;
    final jenis = _selectedJenis ?? 'Izin';
    const title = 'Izin Berhasil Diajukan ✅';
    final body = 'Pengajuan $jenis telah dikirim untuk review';
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
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
      payload: 'timeoff_success_$timeOffId',
    );
  }

  Future<bool> _checkNotificationPermission() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        return (await Permission.notification.status).isGranted;
      }
    } catch (_) {}
    return false;
  }

  // ── SnackBars ──────────────────────────────────────────────────────────────
  void _showSnackBar(String msg, {required bool isError}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_rounded : Icons.check_circle_rounded,
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
          backgroundColor: isError
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

  void _showErrorSnackBar(String msg) => _showSnackBar(msg, isError: true);
  void _showSuccessSnackBar(String msg) => _showSnackBar(msg, isError: false);

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

// ── Helper class untuk baris reimbursement ────────────────────────────────────
class _ReimburseRow {
  final TextEditingController namaCtrl;
  final TextEditingController nominalCtrl;
  final TextEditingController ketCtrl;

  _ReimburseRow({
    required this.namaCtrl,
    required this.nominalCtrl,
    required this.ketCtrl,
  });
}
