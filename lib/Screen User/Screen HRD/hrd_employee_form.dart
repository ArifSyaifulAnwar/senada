// Screen HRD/hrd_employee_form.dart — FULL REPLACE
// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, deprecated_member_use

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../fitur/profile fitur/listkaryawan.dart';
import 'hrd_employee_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOM CROP DIALOG — bekerja di semua platform (Web, Desktop, Mobile)
// ═══════════════════════════════════════════════════════════════════════════════
class _CropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropDialog({required this.imageBytes});

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  // Posisi & ukuran crop box (normalized 0.0–1.0 relatif terhadap gambar)
  double _left = 0.1;
  double _top = 0.1;
  double _size = 0.8; // selalu square

  final GlobalKey _imgKey = GlobalKey();
  ui.Image? _uiImage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadUiImage();
  }

  Future<void> _loadUiImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _uiImage = frame.image);
  }

  // Clamp agar crop box tidak keluar batas
  void _clamp() {
    _size = _size.clamp(0.1, 1.0);
    _left = _left.clamp(0.0, 1.0 - _size);
    _top = _top.clamp(0.0, 1.0 - _size);
  }

  // Ganti seluruh method _crop() dengan ini:
  Future<Uint8List?> _crop() async {
    if (_uiImage == null) return null;
    setState(() => _isProcessing = true);

    final iw = _uiImage!.width.toDouble();
    final ih = _uiImage!.height.toDouble();

    // Ambil ukuran render box dari key
    final box = _imgKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      setState(() => _isProcessing = false);
      return null;
    }
    final boxW = box.size.width;
    final boxH = box.size.height;

    // Hitung imageRect setelah BoxFit.contain (letterbox)
    final imageAspect = iw / ih;
    final boxAspect = boxW / boxH;

    double renderedW, renderedH, offsetX, offsetY;
    if (imageAspect > boxAspect) {
      // Pillar box (bar di atas & bawah)
      renderedW = boxW;
      renderedH = boxW / imageAspect;
      offsetX = 0;
      offsetY = (boxH - renderedH) / 2;
    } else {
      // Letter box (bar di kiri & kanan)
      renderedH = boxH;
      renderedW = boxH * imageAspect;
      offsetX = (boxW - renderedW) / 2;
      offsetY = 0;
    }

    // Konversi normalized crop box ke koordinat dalam rendered image
    // _left/_top/_size dinormalisasi terhadap boxW/boxH
    final cropXInBox = _left * boxW;
    final cropYInBox = _top * boxH;
    final cropWInBox = _size * boxW;
    final cropHInBox = _size * boxH;

    // Konversi ke koordinat dalam rendered image (hilangkan letterbox offset)
    final cropXInImg = (cropXInBox - offsetX) / renderedW;
    final cropYInImg = (cropYInBox - offsetY) / renderedH;
    final cropWInImg = cropWInBox / renderedW;
    final cropHInImg = cropHInBox / renderedH;

    // Clamp agar tidak keluar gambar
    final srcX = (cropXInImg * iw).clamp(0.0, iw).round();
    final srcY = (cropYInImg * ih).clamp(0.0, ih).round();
    final srcW = (cropWInImg * iw).clamp(1.0, iw - srcX).round();
    final srcH = (cropHInImg * ih).clamp(1.0, ih - srcY).round();

    // Render ke offscreen canvas 400×400
    const out = 400.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      _uiImage!,
      Rect.fromLTWH(
        srcX.toDouble(),
        srcY.toDouble(),
        srcW.toDouble(),
        srcH.toDouble(),
      ),
      Rect.fromLTWH(0, 0, out, out),
      Paint()..filterQuality = FilterQuality.high,
    );
    final pic = recorder.endRecording();
    final img = await pic.toImage(out.toInt(), out.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    setState(() => _isProcessing = false);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final maxBox = math.min(screenW * 0.85, screenH * 0.65);

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────────────
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.crop, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Crop Foto',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
          ),

          // ── Canvas area ───────────────────────────────────────────
          SizedBox(
            width: maxBox,
            height: maxBox,
            child: _uiImage == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : LayoutBuilder(
                    builder: (ctx, constraints) {
                      final boxW = constraints.maxWidth;
                      final boxH = constraints.maxHeight;
                      return Stack(
                        children: [
                          // Gambar
                          Positioned.fill(
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                              key: _imgKey,
                            ),
                          ),

                          // Overlay gelap di luar crop
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _OverlayPainter(
                                left: _left,
                                top: _top,
                                size: _size,
                              ),
                            ),
                          ),

                          // Crop handle (drag untuk pindah & resize)
                          Positioned(
                            left: _left * boxW,
                            top: _top * boxH,
                            width: _size * boxW,
                            height: _size * boxH,
                            child: GestureDetector(
                              // Drag box untuk geser
                              onPanUpdate: (d) => setState(() {
                                _left += d.delta.dx / boxW;
                                _top += d.delta.dy / boxH;
                                _clamp();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF3B82F6),
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Grid lines
                                    CustomPaint(
                                      painter: _GridPainter(),
                                      child: const SizedBox.expand(),
                                    ),
                                    // Corner handles
                                    ..._corners(boxW, boxH),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // ── Controls ──────────────────────────────────────────────
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                    Expanded(
                      child: Slider(
                        value: _size,
                        min: 0.1,
                        max: 1.0,
                        activeColor: const Color(0xFF3B82F6),
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() {
                          _size = v;
                          _clamp();
                        }),
                      ),
                    ),
                    const Icon(Icons.zoom_out, color: Colors.white70, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                final result = await _crop();
                                if (mounted) Navigator.pop(context, result);
                              },
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _isProcessing ? 'Memproses...' : 'Gunakan Foto',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Corner resize handles
  List<Widget> _corners(double boxW, double boxH) {
    const hSize = 20.0;
    final corners = [
      [Alignment.topLeft, 0.0, 0.0],
      [Alignment.topRight, 1.0, 0.0],
      [Alignment.bottomLeft, 0.0, 1.0],
      [Alignment.bottomRight, 1.0, 1.0],
    ];
    return corners.map((c) {
      final ax = c[1] as double;
      final ay = c[2] as double;
      return Positioned(
        left: ax == 0 ? -hSize / 2 : null,
        right: ax == 1 ? -hSize / 2 : null,
        top: ay == 0 ? -hSize / 2 : null,
        bottom: ay == 1 ? -hSize / 2 : null,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() {
            final dx = d.delta.dx / boxW;
            final dy = d.delta.dy / boxH;
            final ds =
                (dx.abs() > dy.abs() ? dx : dy) * (ax + ay == 0 ? -1 : 1);
            if (ax == 0) _left += dx;
            if (ay == 0) _top += dy;
            _size += ds;
            _clamp();
          }),
          child: Container(
            width: hSize,
            height: hSize,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ── Overlay gelap di luar crop box ────────────────────────────────────────────
class _OverlayPainter extends CustomPainter {
  final double left, top, size;
  const _OverlayPainter({
    required this.left,
    required this.top,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    final paint = Paint()..color = Colors.black54;
    final rect = Rect.fromLTWH(
      left * sz.width,
      top * sz.height,
      size * sz.width,
      size * sz.height,
    );
    final full = Rect.fromLTWH(0, 0, sz.width, sz.height);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRect(rect),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter o) =>
      o.left != left || o.top != top || o.size != size;
}

// ── Grid lines di dalam crop box ──────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

class HrdEmployeeFormPage extends StatefulWidget {
  final EmployeeData? employee;
  const HrdEmployeeFormPage({super.key, this.employee});

  @override
  _HrdEmployeeFormPageState createState() => _HrdEmployeeFormPageState();
}

class _HrdEmployeeFormPageState extends State<HrdEmployeeFormPage>
    with SingleTickerProviderStateMixin {
  bool get _isEdit => widget.employee != null;
  late TabController _tabController;
  bool _isSaving = false;

  // ── Photo ──────────────────────────────────────────────────────────────────
  Uint8List? _newPhotoBytes;
  String? _existingPhotoBase64;

  // ── Manager dropdown ───────────────────────────────────────────────────────
  List<ManagerItem> _managerList = [];
  bool _loadingMgr = false;
  String? _selectedMgrUserId;

  // ── Controllers: Personal ─────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addPhoneCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _nipCtrl = TextEditingController();
  final _npwpCtrl = TextEditingController();
  final _bpjsCtrl = TextEditingController();
  final _passportNoCtrl = TextEditingController();
  final _passportExpCtrl = TextEditingController();
  final _placeOfBirthCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  String? _genderVal;
  String? _maritalVal;
  String? _bloodTypeVal;
  String? _religionVal;

  // ── Controllers: Address ──────────────────────────────────────────────────
  final _addressCtrl = TextEditingController();
  final _citizenIdAddrCtrl = TextEditingController();
  final _residentialAddrCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();

  // ── Controllers: Employment ───────────────────────────────────────────────
  final _departmentCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _joinDateCtrl = TextEditingController();
  final _endContractCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();

  String? _employmentStatusVal;
  String? _statusDisplayVal;

  // ── Skills ─────────────────────────────────────────────────────────────────
  final List<String> _skills = [];
  final TextEditingController _skillCtrl = TextEditingController();

  // ── Dropdown options ───────────────────────────────────────────────────────
  static const _genderOpts = ['Laki-laki', 'Perempuan'];
  static const _maritalOpts = ['Belum Menikah', 'Menikah', 'Cerai'];
  static const _bloodOpts = ['A', 'B', 'AB', 'O'];
  static const _religionOpts = [
    'Islam',
    'Kristen',
    'Katolik',
    'Hindu',
    'Buddha',
    'Konghucu',
  ];
  static const _empStatusOpts = [
    'Tetap',
    'Kontrak',
    'Percobaan',
    'Magang',
    'Freelance',
  ];
  static const _statusDisplayOpts = ['Aktif', 'Cuti', 'Non-Aktif'];

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (_isEdit) _fillFromEmployee(widget.employee!);
    _loadManagerList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _allCtrl()) {
      c.dispose();
    }
    _skillCtrl.dispose();
    super.dispose();
  }

  List<TextEditingController> _allCtrl() => [
    _nameCtrl,
    _emailCtrl,
    _phoneCtrl,
    _addPhoneCtrl,
    _nikCtrl,
    _nipCtrl,
    _npwpCtrl,
    _bpjsCtrl,
    _passportNoCtrl,
    _passportExpCtrl,
    _placeOfBirthCtrl,
    _birthDateCtrl,
    _addressCtrl,
    _citizenIdAddrCtrl,
    _residentialAddrCtrl,
    _postalCodeCtrl,
    _departmentCtrl,
    _positionCtrl,
    _branchCtrl,
    _companyCtrl,
    _joinDateCtrl,
    _endContractCtrl,
    _bankNameCtrl,
    _bankAccountNumberCtrl,
    _bankAccountNameCtrl,
  ];

  void _fillFromEmployee(EmployeeData e) {
    _nameCtrl.text = e.nama;
    _emailCtrl.text = e.email;
    _phoneCtrl.text = e.telepon;
    _addPhoneCtrl.text = e.additionalPhone ?? '';
    _nikCtrl.text = e.nik ?? '';
    _nipCtrl.text = e.nip ?? '';
    _npwpCtrl.text = e.npwp ?? '';
    _bpjsCtrl.text = (e as dynamic).bpjsKetenagakerjaan ?? '';
    _passportNoCtrl.text = e.passportNumber ?? '';
    _passportExpCtrl.text = _fmtDisplay(e.passportExpiry);
    _placeOfBirthCtrl.text = e.placeOfBirth ?? '';
    _birthDateCtrl.text = _fmtDisplay(e.birthDate);
    _addressCtrl.text = e.alamat;
    _citizenIdAddrCtrl.text = e.citizenIdAddress ?? '';
    _residentialAddrCtrl.text = e.residentialAddress ?? '';
    _postalCodeCtrl.text = e.postalCode ?? '';
    _departmentCtrl.text = e.departemen;
    _positionCtrl.text = e.jabatan;
    _branchCtrl.text = e.branch ?? '';
    _companyCtrl.text = e.companyName ?? '';
    _joinDateCtrl.text = _fmtDisplay(
      e.tanggalBergabung.isNotEmpty ? e.tanggalBergabung : null,
    );
    _endContractCtrl.text = _fmtDisplay(e.endContractDate);
    _bankNameCtrl.text = e.bankName ?? '';
    _bankAccountNumberCtrl.text = e.bankAccountNumber ?? '';
    _bankAccountNameCtrl.text = e.bankAccountName ?? '';
    // ── Fix: gender dari field 'gender', bukan 'jobs' ──────────────────────
    _genderVal = _genderOpts.contains(e.gender) ? e.gender : null;
    _maritalVal = _maritalOpts.contains(e.maritalStatus)
        ? e.maritalStatus
        : null;
    _bloodTypeVal = _bloodOpts.contains(e.bloodType) ? e.bloodType : null;
    _religionVal = _religionOpts.contains(e.religion) ? e.religion : null;
    _employmentStatusVal = _empStatusOpts.contains(e.employmentStatus)
        ? e.employmentStatus
        : null;
    _statusDisplayVal = _statusDisplayOpts.contains(e.status) ? e.status : null;

    _skills.addAll(e.skills);
    _existingPhotoBase64 = e.foto.isNotEmpty ? e.foto : null;
    // manager userid — resolve dari nama jika perlu setelah list loaded
    _selectedMgrUserId = null; // akan di-match setelah manager list loaded
  }

  // ── Load manager list ──────────────────────────────────────────────────────
  Future<void> _loadManagerList() async {
    setState(() => _loadingMgr = true);
    try {
      final res = await HrdEmployeeService.getManagerList(
        excludeUserId: _isEdit ? widget.employee?.userId : null,
      );
      if (res.success && res.data != null && mounted) {
        setState(() {
          _managerList = res.data!;
          // Coba match nama manager ke userid
          if (_isEdit && widget.employee?.manager.isNotEmpty == true) {
            final match = _managerList
                .where((m) => m.name == widget.employee!.manager)
                .firstOrNull;
            _selectedMgrUserId = match?.userId;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMgr = false);
  }

  // ── Photo ──────────────────────────────────────────────────────────────────
  Future<void> _pickAndCropPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1500,
        maxHeight: 1500,
        imageQuality: 90,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // Tampilkan custom crop dialog — bekerja di semua platform
      if (!mounted) return;
      final cropped = await showDialog<Uint8List?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CropDialog(imageBytes: bytes),
      );

      if (cropped != null && mounted) {
        setState(() => _newPhotoBytes = cropped);
      }
    } catch (e) {
      _snack('Gagal memilih foto: $e', err: true);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF3B82F6),
              ),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropPhoto(ImageSource.gallery);
              },
            ),
            if (_newPhotoBytes != null || _existingPhotoBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Hapus Foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _newPhotoBytes = null;
                    _existingPhotoBase64 = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Nama tidak boleh kosong', err: true);
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _snack('Email tidak boleh kosong', err: true);
      return;
    }
    setState(() => _isSaving = true);

    String? photoBase64 = _existingPhotoBase64;
    if (_newPhotoBytes != null) photoBase64 = base64Encode(_newPhotoBytes!);

    try {
      ApiResponse res;
      if (_isEdit) {
        res = await HrdEmployeeService.updateEmployee(
          HrdUpdateEmployeeRequest(
            id: widget.employee!.id,
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            additionalPhone: _addPhoneCtrl.text.trim(),
            gender: _genderVal,
            placeOfBirth: _placeOfBirthCtrl.text.trim(),
            birthDate: _toApiDate(_birthDateCtrl.text),
            maritalStatus: _maritalVal,
            bloodType: _bloodTypeVal,
            religion: _religionVal,
            nik: _nikCtrl.text.trim(),
            nip: _nipCtrl.text.trim(),
            npwp: _npwpCtrl.text.trim(),
            bpjsKetenagakerjaan: _bpjsCtrl.text.trim(),
            passportNumber: _passportNoCtrl.text.trim(),
            passportExpiry: _toApiDate(_passportExpCtrl.text),
            address: _addressCtrl.text.trim(),
            citizenIdAddress: _citizenIdAddrCtrl.text.trim(),
            residentialAddress: _residentialAddrCtrl.text.trim(),
            postalCode: _postalCodeCtrl.text.trim(),
            department: _departmentCtrl.text.trim(),
            jobPosition: _positionCtrl.text.trim(),
            employmentStatus: _employmentStatusVal,
            joinDate: _toApiDate(_joinDateCtrl.text),
            endContractDate: _toApiDate(_endContractCtrl.text),
            managerUserId: _selectedMgrUserId,
            branch: _branchCtrl.text.trim(),
            companyName: _companyCtrl.text.trim(),
            statusDisplay: _statusDisplayVal,
            bankName: _bankNameCtrl.text.trim(),
            bankAccountNumber: _bankAccountNumberCtrl.text.trim(),
            bankAccountName: _bankAccountNameCtrl.text.trim(),
            skills: _skills,
            profilePhotoBase64: photoBase64,
          ),
        );
      } else {
        res = await HrdEmployeeService.createEmployee(
          HrdCreateEmployeeRequest(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            department: _departmentCtrl.text.trim(),
            jobPosition: _positionCtrl.text.trim(),
            employmentStatus: _employmentStatusVal,
            joinDate: _toApiDate(_joinDateCtrl.text),
            gender: _genderVal,
            nik: _nikCtrl.text.trim(),
            bpjsKetenagakerjaan: _bpjsCtrl.text.trim(),
            profilePhotoBase64: photoBase64,
            skills: _skills,
          ),
        );
      }
      setState(() => _isSaving = false);
      if (res.success) {
        _snack(
          res.message.isNotEmpty
              ? res.message
              : (_isEdit
                    ? 'Data berhasil diperbarui'
                    : 'Karyawan berhasil ditambah'),
          err: false,
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, true);
      } else {
        _snack(res.message, err: true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _snack('Terjadi kesalahan: $e', err: true);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Karyawan' : 'Tambah Karyawan',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF3B82F6),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF3B82F6),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.person, size: 18), text: 'Personal'),
                Tab(icon: Icon(Icons.home, size: 18), text: 'Alamat'),
                Tab(icon: Icon(Icons.work, size: 18), text: 'Pekerjaan'),
                Tab(icon: Icon(Icons.star, size: 18), text: 'Skills'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalTab(),
                _buildAddressTab(),
                _buildEmploymentTab(),
                _buildSkillsTab(),
              ],
            ),
          ),
          _buildSaveBar(),
        ],
      ),
    );
  }

  // ── Tab 1: Personal ────────────────────────────────────────────────────────
  Widget _buildPersonalTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _buildPhotoSection(),
        const SizedBox(height: 20),
        _buildSection('Identitas Utama', [
          _tf(_nameCtrl, 'Nama Lengkap', Icons.person, required: true),
          _tf(
            _emailCtrl,
            'Email',
            Icons.email,
            required: true,
            type: TextInputType.emailAddress,
          ),
          _tf(
            _phoneCtrl,
            'Nomor HP Utama',
            Icons.phone,
            type: TextInputType.phone,
          ),
          _tf(
            _addPhoneCtrl,
            'Nomor HP Tambahan',
            Icons.phone_android,
            type: TextInputType.phone,
          ),
          _dd(
            'Jenis Kelamin',
            Icons.wc,
            _genderOpts,
            _genderVal,
            (v) => setState(() => _genderVal = v),
          ),
          _dd(
            'Status Karyawan',
            Icons.circle,
            _statusDisplayOpts,
            _statusDisplayVal,
            (v) => setState(() => _statusDisplayVal = v),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSection('Data Kelahiran', [
          _tf(_placeOfBirthCtrl, 'Tempat Lahir', Icons.location_city),
          _dateTf(_birthDateCtrl, 'Tanggal Lahir', Icons.cake),
          _dd(
            'Status Perkawinan',
            Icons.favorite,
            _maritalOpts,
            _maritalVal,
            (v) => setState(() => _maritalVal = v),
          ),
          _dd(
            'Golongan Darah',
            Icons.bloodtype,
            _bloodOpts,
            _bloodTypeVal,
            (v) => setState(() => _bloodTypeVal = v),
          ),
          _dd(
            'Agama',
            Icons.church,
            _religionOpts,
            _religionVal,
            (v) => setState(() => _religionVal = v),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSection('Dokumen Identitas', [
          _tf(_nikCtrl, 'NIK', Icons.credit_card, type: TextInputType.number),
          _tf(_nipCtrl, 'NIP', Icons.badge),
          _tf(_npwpCtrl, 'NPWP', Icons.receipt),
          _tf(
            _bpjsCtrl,
            'No. BPJS Ketenagakerjaan',
            Icons.health_and_safety,
            type: TextInputType.number,
          ),
          _tf(_passportNoCtrl, 'No. Paspor', Icons.flight_takeoff),
          _dateTf(_passportExpCtrl, 'Exp. Paspor', Icons.date_range),
        ]),
      ],
    ),
  );

  // ── Tab 2: Alamat ──────────────────────────────────────────────────────────
  Widget _buildAddressTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: _buildSection('Alamat', [
      _tf(_addressCtrl, 'Alamat Lengkap', Icons.location_on, lines: 3),
      _tf(_citizenIdAddrCtrl, 'Alamat KTP', Icons.credit_card, lines: 3),
      _tf(_residentialAddrCtrl, 'Alamat Domisili', Icons.home, lines: 3),
      _tf(
        _postalCodeCtrl,
        'Kode Pos',
        Icons.local_post_office,
        type: TextInputType.number,
      ),
    ]),
  );

  // ── Tab 3: Pekerjaan ───────────────────────────────────────────────────────
  Widget _buildEmploymentTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _buildSection('Info Pekerjaan', [
          _tf(_companyCtrl, 'Nama Perusahaan', Icons.business),
          _tf(_branchCtrl, 'Cabang / Branch', Icons.store),
          _tf(_departmentCtrl, 'Departemen / Divisi', Icons.group_work),
          _tf(_positionCtrl, 'Jabatan / Posisi', Icons.work),
          _dd(
            'Status Kepegawaian',
            Icons.card_membership,
            _empStatusOpts,
            _employmentStatusVal,
            (v) => setState(() => _employmentStatusVal = v),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSection('Tanggal & Atasan', [
          _dateTf(_joinDateCtrl, 'Tanggal Bergabung', Icons.event),
          _dateTf(
            _endContractCtrl,
            'Akhir Kontrak (jika ada)',
            Icons.event_busy,
          ),
          _buildManagerDropdown(),
        ]),
        const SizedBox(height: 16),
        // ── BARU: section bank ───────────────────────────────────────────────
        _buildSection('Informasi Bank', [
          _bankNameField(),
          _tf(
            _bankAccountNumberCtrl,
            'Nomor Rekening',
            Icons.credit_card,
            type: TextInputType.number,
          ),
          _tf(_bankAccountNameCtrl, 'Atas Nama Rekening', Icons.person_outline),
        ]),
      ],
    ),
  );
  static const _bankOpts = [
    'BCA',
    'BRI',
    'BNI',
    'Mandiri',
    'BSI',
    'CIMB Niaga',
    'Danamon',
    'Permata',
    'BTN',
    'Maybank',
    'OCBC',
    'Panin',
    'BII Maybank',
    'Mega',
    'Bukopin',
    'Lainnya',
  ];
  Widget _bankNameField() {
    // Cek apakah nilai saat ini ada di list atau tidak
    final inList =
        _bankOpts.contains(_bankNameCtrl.text) || _bankNameCtrl.text.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: inList && _bankNameCtrl.text.isNotEmpty
              ? _bankNameCtrl.text
              : null,
          onChanged: (v) {
            if (v == 'Lainnya') {
              // kosongkan supaya user bisa ketik manual
              setState(() => _bankNameCtrl.text = '');
            } else {
              setState(() => _bankNameCtrl.text = v ?? '');
            }
          },
          decoration: InputDecoration(
            labelText: 'Nama Bank',
            prefixIcon: const Icon(
              Icons.account_balance,
              size: 18,
              color: Color(0xFF64748B),
            ),
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
              borderSide: const BorderSide(color: Color(0xFF3B82F6)),
            ),
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('-- Pilih Bank --'),
            ),
            ..._bankOpts.map((b) => DropdownMenuItem(value: b, child: Text(b))),
          ],
        ),
        // Kalau pilih "Lainnya" atau nilai tidak ada di list → tampilkan TextField
        if (!inList || _bankNameCtrl.text == '')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _tf(_bankNameCtrl, 'Nama Bank (isi manual)', Icons.edit),
          ),
      ],
    );
  }

  Widget _buildManagerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedMgrUserId,
          onChanged: (v) => setState(() => _selectedMgrUserId = v),
          decoration: InputDecoration(
            labelText: 'Manager',
            prefixIcon: _loadingMgr
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(
                    Icons.supervisor_account,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
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
              borderSide: const BorderSide(color: Color(0xFF3B82F6)),
            ),
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('-- Tidak Ada Manager --'),
            ),
            ..._managerList.map(
              (m) => DropdownMenuItem(
                value: m.userId,
                child: Text(m.displayName, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 4: Skills ──────────────────────────────────────────────────────────
  Widget _buildSkillsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: _buildSection('Skill Karyawan', [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _skillCtrl,
              decoration: InputDecoration(
                hintText: 'Tambah skill (contoh: Flutter)',
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
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _addSkill(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _addSkill,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_skills.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            children: [
              Icon(Icons.star_outline, size: 48, color: Color(0xFFCBD5E1)),
              SizedBox(height: 8),
              Text(
                'Belum ada skill',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        )
      else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills
                .map(
                  (s) => Chip(
                    label: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    deleteIconColor: Colors.blue,
                    onDeleted: () => setState(() => _skills.remove(s)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
        ),
    ]),
  );

  void _addSkill() {
    final v = _skillCtrl.text.trim();
    if (v.isNotEmpty && !_skills.contains(v)) {
      setState(() => _skills.add(v));
      _skillCtrl.clear();
    }
  }

  // ── Photo section ──────────────────────────────────────────────────────────
  Widget _buildPhotoSection() => Center(
    child: Stack(
      children: [
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: const Color(0xFF3B82F6), width: 2),
            ),
            child: ClipOval(child: _photoWidget()),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _showPhotoOptions,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _photoWidget() {
    if (_newPhotoBytes != null) {
      return Image.memory(
        _newPhotoBytes!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    }
    if (_existingPhotoBase64 != null && _existingPhotoBase64!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(_existingPhotoBase64!),
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (_, __, ___) => _defaultAvatar(),
        );
      } catch (_) {}
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() =>
      Icon(Icons.person, size: 50, color: Colors.blue[300]);

  // ── Save bar ───────────────────────────────────────────────────────────────
  Widget _buildSaveBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 20),
          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );

  // ── Shared form widgets ────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 14),
        ...children.map(
          (w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
        ),
      ],
    ),
  );

  Widget _tf(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType type = TextInputType.text,
    int lines = 1,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: type,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
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
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    style: const TextStyle(fontSize: 13),
  );

  Widget _dateTf(TextEditingController ctrl, String label, IconData icon) =>
      TextFormField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickDate(ctrl),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
          suffixIcon: const Icon(
            Icons.calendar_month,
            size: 18,
            color: Color(0xFF3B82F6),
          ),
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
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      );

  Widget _dd(
    String label,
    IconData icon,
    List<String> opts,
    String? val,
    void Function(String?) onChange,
  ) => DropdownButtonFormField<String>(
    value: val,
    onChanged: onChange,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
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
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
    items: [
      const DropdownMenuItem(value: null, child: Text('-- Pilih --')),
      ...opts.map((o) => DropdownMenuItem(value: o, child: Text(o))),
    ],
  );

  // ── Utilities ──────────────────────────────────────────────────────────────
  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime init = DateTime.now();
    try {
      if (ctrl.text.isNotEmpty) {
        init = DateFormat('dd/MM/yyyy').parse(ctrl.text);
      }
    } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
  }

  String _fmtDisplay(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String? _toApiDate(String display) {
    if (display.isEmpty) return null;
    try {
      return DateFormat(
        'yyyy-MM-dd',
      ).format(DateFormat('dd/MM/yyyy').parse(display));
    } catch (_) {
      return null;
    }
  }

  void _snack(String msg, {required bool err}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: err ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
}
