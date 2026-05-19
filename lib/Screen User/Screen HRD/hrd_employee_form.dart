// File: Screen HRD/hrd_employee_form.dart
// Form tambah/edit karyawan oleh HRD — semua field + foto

// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, deprecated_member_use,
//                 use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../fitur/profile fitur/listkaryawan.dart';
import 'hrd_employee_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

/// Panggil dari mana saja:
///   HrdEmployeeFormPage(employee: emp)  → mode EDIT
///   HrdEmployeeFormPage()               → mode TAMBAH
class HrdEmployeeFormPage extends StatefulWidget {
  final EmployeeData? employee; // null = create mode

  const HrdEmployeeFormPage({super.key, this.employee});

  @override
  _HrdEmployeeFormPageState createState() => _HrdEmployeeFormPageState();
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

class _HrdEmployeeFormPageState extends State<HrdEmployeeFormPage>
    with SingleTickerProviderStateMixin {
  bool get _isEdit => widget.employee != null;

  late TabController _tabController;
  bool _isSaving = false;

  // ── Photo ────────────────────────────────────────────────────────────────────
  // Pakai Uint8List agar kompatibel Flutter Web (Image.file tidak didukung web)
  Uint8List? _newPhotoBytes;
  String? _existingPhotoBase64;

  // ── Skills list ──────────────────────────────────────────────────────────────
  final List<String> _skills = [];
  final TextEditingController _skillInputCtrl = TextEditingController();

  // ── Controllers: Personal ────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addPhoneCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _nipCtrl = TextEditingController();
  final _npwpCtrl = TextEditingController();
  final _passportNoCtrl = TextEditingController();
  final _passportExpCtrl = TextEditingController();
  final _placeOfBirthCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  String? _genderVal;
  String? _maritalVal;
  String? _bloodTypeVal;
  String? _religionVal;

  // ── Controllers: Address ─────────────────────────────────────────────────────
  final _addressCtrl = TextEditingController();
  final _citizenIdAddrCtrl = TextEditingController();
  final _residentialAddrCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();

  // ── Controllers: Employment ──────────────────────────────────────────────────
  final _departmentCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _jobLevelCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _approvalLineCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _joinDateCtrl = TextEditingController();
  final _endContractCtrl = TextEditingController();

  String? _employmentStatusVal;
  String? _statusDisplayVal;

  // ── Dropdown options ──────────────────────────────────────────────────────────
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

  // ─── LIFECYCLE ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (_isEdit) _fillFromEmployee(widget.employee!);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _allControllers()) {
      c.dispose();
    }
    _skillInputCtrl.dispose();
    super.dispose();
  }

  List<TextEditingController> _allControllers() => [
    _nameCtrl,
    _emailCtrl,
    _phoneCtrl,
    _addPhoneCtrl,
    _nikCtrl,
    _nipCtrl,
    _npwpCtrl,
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
    _jobLevelCtrl,
    _managerCtrl,
    _approvalLineCtrl,
    _gradeCtrl,
    _classCtrl,
    _branchCtrl,
    _companyCtrl,
    _joinDateCtrl,
    _endContractCtrl,
  ];

  void _fillFromEmployee(EmployeeData e) {
    _nameCtrl.text = e.nama;
    _emailCtrl.text = e.email;
    _phoneCtrl.text = e.telepon;
    _addPhoneCtrl.text = e.additionalPhone ?? '';
    _nikCtrl.text = e.nik ?? '';
    _nipCtrl.text = e.nip ?? '';
    _npwpCtrl.text = e.npwp ?? '';
    _passportNoCtrl.text = e.passportNumber ?? '';
    _passportExpCtrl.text = _formatDateDisplay(e.passportExpiry);
    _placeOfBirthCtrl.text = e.placeOfBirth ?? '';
    _birthDateCtrl.text = _formatDateDisplay(e.birthDate);
    _addressCtrl.text = e.alamat;
    _citizenIdAddrCtrl.text = e.citizenIdAddress ?? '';
    _residentialAddrCtrl.text = e.residentialAddress ?? '';
    _postalCodeCtrl.text = e.postalCode ?? '';
    _departmentCtrl.text = e.departemen;
    _positionCtrl.text = e.jabatan;
    _jobLevelCtrl.text = e.jobLevel ?? '';
    _managerCtrl.text = e.manager;
    _approvalLineCtrl.text = e.approvalLine ?? '';
    _gradeCtrl.text = e.grade ?? '';
    _classCtrl.text = e.class_ ?? '';
    _branchCtrl.text = e.branch ?? '';
    _companyCtrl.text = e.companyName ?? '';
    _joinDateCtrl.text = _formatDateDisplay(
      e.tanggalBergabung.isNotEmpty ? e.tanggalBergabung : null,
    );
    _endContractCtrl.text = _formatDateDisplay(e.endContractDate);
    _genderVal = _genderOpts.contains(e.jobs) ? e.jobs : null;
    _maritalVal = _maritalOpts.contains(e.maritalStatus)
        ? e.maritalStatus
        : null;
    _bloodTypeVal = _bloodOpts.contains(e.bloodType) ? e.bloodType : null;
    _religionVal = _religionOpts.contains(e.religion) ? e.religion : null;
    _empStatusVal(e.employmentStatus);
    _statusDisplayVal = _statusDisplayOpts.contains(e.status) ? e.status : null;
    _skills.addAll(e.skills);
    _existingPhotoBase64 = e.foto.isNotEmpty ? e.foto : null;
  }

  void _empStatusVal(String? v) {
    _employmentStatusVal = (_empStatusOpts.contains(v)) ? v : null;
  }

  String _formatDateDisplay(String? iso) {
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

  // ─── PHOTO ───────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        // readAsBytes() kompatibel web & mobile, tidak butuh dart:io
        final bytes = await picked.readAsBytes();
        setState(() => _newPhotoBytes = bytes);
      }
    } catch (e) {
      _showSnack('Gagal memilih foto: $e', isError: true);
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
                _pickPhoto(ImageSource.camera);
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
                _pickPhoto(ImageSource.gallery);
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

  // ─── SAVE ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Nama tidak boleh kosong', isError: true);
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _showSnack('Email tidak boleh kosong', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    // Encode foto baru jika ada — pakai bytes (web & mobile compat)
    String? photoBase64 = _existingPhotoBase64;
    if (_newPhotoBytes != null) {
      photoBase64 = base64Encode(_newPhotoBytes!);
    }

    try {
      ApiResponse response;

      if (_isEdit) {
        final req = HrdUpdateEmployeeRequest(
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
          passportNumber: _passportNoCtrl.text.trim(),
          passportExpiry: _toApiDate(_passportExpCtrl.text),
          address: _addressCtrl.text.trim(),
          citizenIdAddress: _citizenIdAddrCtrl.text.trim(),
          residentialAddress: _residentialAddrCtrl.text.trim(),
          postalCode: _postalCodeCtrl.text.trim(),
          department: _departmentCtrl.text.trim(),
          jobPosition: _positionCtrl.text.trim(),
          jobLevel: _jobLevelCtrl.text.trim(),
          employmentStatus: _employmentStatusVal,
          joinDate: _toApiDate(_joinDateCtrl.text),
          endContractDate: _toApiDate(_endContractCtrl.text),
          manager: _managerCtrl.text.trim(),
          approvalLine: _approvalLineCtrl.text.trim(),
          grade: _gradeCtrl.text.trim(),
          classLevel: _classCtrl.text.trim(),
          branch: _branchCtrl.text.trim(),
          companyName: _companyCtrl.text.trim(),
          statusDisplay: _statusDisplayVal,
          skills: _skills,
          profilePhotoBase64: photoBase64,
        );
        response = await HrdEmployeeService.updateEmployee(req);
      } else {
        final req = HrdCreateEmployeeRequest(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          department: _departmentCtrl.text.trim(),
          jobPosition: _positionCtrl.text.trim(),
          jobLevel: _jobLevelCtrl.text.trim(),
          employmentStatus: _employmentStatusVal,
          joinDate: _toApiDate(_joinDateCtrl.text),
          gender: _genderVal,
          nik: _nikCtrl.text.trim(),
          profilePhotoBase64: photoBase64,
          skills: _skills,
        );
        response = await HrdEmployeeService.createEmployee(req);
      }

      setState(() => _isSaving = false);

      if (response.success) {
        _showSnack(response.message, isError: false);
        await Future.delayed(const Duration(milliseconds: 400));
        Navigator.pop(context, true); // true = refresh parent
      } else {
        _showSnack(response.message, isError: true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Terjadi kesalahan: $e', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── DATE PICKER HELPER ──────────────────────────────────────────────────────

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime initial = DateTime.now();
    try {
      if (ctrl.text.isNotEmpty) {
        initial = DateFormat('dd/MM/yyyy').parse(ctrl.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
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
          // Form content
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
          // Save button
          _buildSaveBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }

  Widget _buildSaveBar() {
    return Container(
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
            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan'),
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
  }

  // ─── TAB 1: PERSONAL ─────────────────────────────────────────────────────────

  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Foto profil
          _buildPhotoSection(),
          const SizedBox(height: 20),
          _buildSection('Identitas Utama', [
            _buildTextField(
              _nameCtrl,
              'Nama Lengkap',
              Icons.person,
              required: true,
            ),
            _buildTextField(
              _emailCtrl,
              'Email',
              Icons.email,
              required: true,
              keyboardType: TextInputType.emailAddress,
            ),
            _buildTextField(
              _phoneCtrl,
              'Nomor HP Utama',
              Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              _addPhoneCtrl,
              'Nomor HP Tambahan',
              Icons.phone_android,
              keyboardType: TextInputType.phone,
            ),
            _buildDropdown(
              'Jenis Kelamin',
              Icons.wc,
              _genderOpts,
              _genderVal,
              (v) => setState(() => _genderVal = v),
            ),
            _buildStatusDropdown(),
          ]),
          const SizedBox(height: 16),
          _buildSection('Data Kelahiran', [
            _buildTextField(
              _placeOfBirthCtrl,
              'Tempat Lahir',
              Icons.location_city,
            ),
            _buildDateField(_birthDateCtrl, 'Tanggal Lahir', Icons.cake),
            _buildDropdown(
              'Status Perkawinan',
              Icons.favorite,
              _maritalOpts,
              _maritalVal,
              (v) => setState(() => _maritalVal = v),
            ),
            _buildDropdown(
              'Golongan Darah',
              Icons.bloodtype,
              _bloodOpts,
              _bloodTypeVal,
              (v) => setState(() => _bloodTypeVal = v),
            ),
            _buildDropdown(
              'Agama',
              Icons.church,
              _religionOpts,
              _religionVal,
              (v) => setState(() => _religionVal = v),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('Dokumen Identitas', [
            _buildTextField(
              _nikCtrl,
              'NIK',
              Icons.credit_card,
              keyboardType: TextInputType.number,
            ),
            _buildTextField(_nipCtrl, 'NIP', Icons.badge),
            _buildTextField(_npwpCtrl, 'NPWP', Icons.receipt),
            _buildTextField(
              _passportNoCtrl,
              'No. Paspor',
              Icons.flight_takeoff,
            ),
            _buildDateField(_passportExpCtrl, 'Exp. Paspor', Icons.date_range),
          ]),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
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
              child: ClipOval(child: _buildPhotoWidget()),
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
  }

  Widget _buildPhotoWidget() {
    // Foto baru dari picker — sudah berupa bytes, langsung Image.memory
    if (_newPhotoBytes != null) {
      return Image.memory(
        _newPhotoBytes!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    }
    // Foto lama dari server — base64 string
    if (_existingPhotoBase64 != null && _existingPhotoBase64!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(_existingPhotoBase64!),
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (_, __, ___) => _defaultAvatarIcon(),
        );
      } catch (_) {}
    }
    return _defaultAvatarIcon();
  }

  Widget _defaultAvatarIcon() =>
      Icon(Icons.person, size: 50, color: Colors.blue[300]);

  Widget _buildStatusDropdown() {
    return _buildDropdown(
      'Status Karyawan',
      Icons.circle,
      _statusDisplayOpts,
      _statusDisplayVal,
      (v) => setState(() => _statusDisplayVal = v),
    );
  }

  // ─── TAB 2: ALAMAT ───────────────────────────────────────────────────────────

  Widget _buildAddressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSection('Alamat', [
            _buildTextField(
              _addressCtrl,
              'Alamat Lengkap',
              Icons.location_on,
              maxLines: 3,
            ),
            _buildTextField(
              _citizenIdAddrCtrl,
              'Alamat KTP',
              Icons.credit_card,
              maxLines: 3,
            ),
            _buildTextField(
              _residentialAddrCtrl,
              'Alamat Domisili',
              Icons.home,
              maxLines: 3,
            ),
            _buildTextField(
              _postalCodeCtrl,
              'Kode Pos',
              Icons.local_post_office,
              keyboardType: TextInputType.number,
            ),
          ]),
        ],
      ),
    );
  }

  // ─── TAB 3: PEKERJAAN ────────────────────────────────────────────────────────

  Widget _buildEmploymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSection('Info Pekerjaan', [
            _buildTextField(_companyCtrl, 'Nama Perusahaan', Icons.business),
            _buildTextField(_branchCtrl, 'Cabang / Branch', Icons.store),
            _buildTextField(_departmentCtrl, 'Departemen', Icons.group_work),
            _buildTextField(_positionCtrl, 'Jabatan / Posisi', Icons.work),
            _buildTextField(_jobLevelCtrl, 'Level Jabatan', Icons.trending_up),
            _buildDropdown(
              'Status Kepegawaian',
              Icons.card_membership,
              _empStatusOpts,
              _employmentStatusVal,
              (v) => setState(() => _employmentStatusVal = v),
            ),
            _buildTextField(_gradeCtrl, 'Grade', Icons.grade),
            _buildTextField(_classCtrl, 'Class', Icons.class_),
          ]),
          const SizedBox(height: 16),
          _buildSection('Tanggal & Atasan', [
            _buildDateField(_joinDateCtrl, 'Tanggal Bergabung', Icons.event),
            _buildDateField(
              _endContractCtrl,
              'Akhir Kontrak (jika ada)',
              Icons.event_busy,
            ),
            _buildTextField(_managerCtrl, 'Manager', Icons.supervisor_account),
            _buildTextField(_approvalLineCtrl, 'Approval Line', Icons.approval),
          ]),
        ],
      ),
    );
  }

  // ─── TAB 4: SKILLS ───────────────────────────────────────────────────────────

  Widget _buildSkillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('Skill Karyawan', [
            // Input tambah skill
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillInputCtrl,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chips
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
                    Icon(
                      Icons.star_outline,
                      size: 48,
                      color: Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada skill ditambahkan',
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
                        (skill) => Chip(
                          label: Text(
                            skill,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          deleteIconColor: Colors.blue,
                          onDeleted: () =>
                              setState(() => _skills.remove(skill)),
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
        ],
      ),
    );
  }

  void _addSkill() {
    final v = _skillInputCtrl.text.trim();
    if (v.isNotEmpty && !_skills.contains(v)) {
      setState(() => _skills.add(v));
      _skillInputCtrl.clear();
    }
  }

  // ─── SHARED FORM WIDGETS ─────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
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
            (w) =>
                Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDateField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextFormField(
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
  }

  Widget _buildDropdown(
    String label,
    IconData icon,
    List<String> options,
    String? value,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
      items: [
        const DropdownMenuItem(value: null, child: Text('-- Pilih --')),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
    );
  }
}
