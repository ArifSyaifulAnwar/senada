// screens/doa_karyawan_screen.dart — FULL REPLACE
// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Model
// ══════════════════════════════════════════════════════════════════════════════

class DoaKaryawanItem {
  final String userId;
  final String name;
  final String? mail;
  final String? employeeId;
  final String? organization;
  final String? jobPosition;

  const DoaKaryawanItem({
    required this.userId,
    required this.name,
    this.mail,
    this.employeeId,
    this.organization,
    this.jobPosition,
  });

  factory DoaKaryawanItem.fromJson(Map<String, dynamic> j) => DoaKaryawanItem(
    userId: j['UserId']?.toString() ?? j['userId']?.toString() ?? '',
    name: j['Name']?.toString() ?? j['name']?.toString() ?? '',
    mail: j['Mail']?.toString() ?? j['mail']?.toString(),
    employeeId: j['EmployeeID']?.toString() ?? j['employeeID']?.toString(),
    organization:
        j['Organization']?.toString() ?? j['organization']?.toString(),
    jobPosition: j['JobPosition']?.toString() ?? j['job_position']?.toString(),
  );
}

class DoaRecord {
  final int? id;
  final DateTime tanggal;
  final String pemimpinDoaId;
  final String pemimpinDoaName;
  final List<String> pesertaIds;
  final List<String> pesertaNames;
  final String? catatan;
  final DateTime? createdAt;

  const DoaRecord({
    this.id,
    required this.tanggal,
    required this.pemimpinDoaId,
    required this.pemimpinDoaName,
    required this.pesertaIds,
    required this.pesertaNames,
    this.catatan,
    this.createdAt,
  });

  factory DoaRecord.fromJson(Map<String, dynamic> j) {
    dynamic f(String a, String b) => j[a] ?? j[b];
    return DoaRecord(
      id: j['id'] as int?,
      tanggal:
          DateTime.tryParse(f('tanggal', 'tanggal')?.toString() ?? '') ??
          DateTime.now(),
      pemimpinDoaId: f('pemimpinDoaId', 'pemimpin_doa_id')?.toString() ?? '',
      pemimpinDoaName:
          f('pemimpinDoaName', 'pemimpin_doa_name')?.toString() ?? '',
      pesertaIds: ((j['pesertaIds'] ?? j['peserta_ids'] ?? []) as List)
          .map((e) => e.toString())
          .toList(),
      pesertaNames: ((j['pesertaNames'] ?? j['peserta_names'] ?? []) as List)
          .map((e) => e.toString())
          .toList(),
      catatan: f('catatan', 'catatan')?.toString(),
      createdAt: DateTime.tryParse(
        f('createdAt', 'created_at')?.toString() ?? '',
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Service
// ══════════════════════════════════════════════════════════════════════════════

class DoaService {
  static Future<String?> _getToken() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return json.decode(res.body)['access_token'];
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Ambil dropdown karyawan
  static Future<List<DoaKaryawanItem>> getKaryawan(
    String hrdUserId, {
    String? search,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/employee/list-karyawan'),
            headers: await _headers(),
            body: json.encode({'hrdUserId': hrdUserId, 'search': search}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final data = body['data'] ?? body['Data'] ?? [];
        return (data as List).map((e) => DoaKaryawanItem.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Simpan data doa
  static Future<Map<String, dynamic>> saveDoa({
    required String hrdUserId,
    required DateTime tanggal,
    required String pemimpinDoaId,
    required List<String> pesertaIds,
    String? catatan,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/employee/doa-save'),
            headers: await _headers(),
            body: json.encode({
              'hrdUserId': hrdUserId,
              'tanggal': DateFormat('yyyy-MM-dd').format(tanggal),
              'pemimpinDoaId': pemimpinDoaId,
              'pesertaIds': pesertaIds,
              'catatan': catatan,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = json.decode(res.body);
      return {
        'success':
            res.statusCode == 200 &&
            (body['success'] ?? body['Success'] ?? false),
        'message': body['message'] ?? body['Message'] ?? 'Terjadi kesalahan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi bermasalah: $e'};
    }
  }

  // Ambil riwayat doa berdasarkan tanggal
  static Future<List<DoaRecord>> getDoaByTanggal(
    String hrdUserId,
    DateTime tanggal,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/employee/doa-list'),
            headers: await _headers(),
            body: json.encode({
              'hrdUserId': hrdUserId,
              'tanggal': DateFormat('yyyy-MM-dd').format(tanggal),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final data = body['data'] ?? body['Data'] ?? [];
        return (data as List).map((e) => DoaRecord.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DoaKaryawanScreen
// ══════════════════════════════════════════════════════════════════════════════

class DoaKaryawanScreen extends StatefulWidget {
  final String? initialHrdUserId;
  final VoidCallback? onDoaSaved; // callback setelah doa disimpan
  const DoaKaryawanScreen({super.key, this.initialHrdUserId, this.onDoaSaved});

  @override
  State<DoaKaryawanScreen> createState() => _DoaKaryawanScreenState();
}

class _DoaKaryawanScreenState extends State<DoaKaryawanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _hrdUserId;
  DateTime _selectedDate = DateTime.now();
  List<DoaKaryawanItem> _karyawan = [];
  bool _isLoadingKaryawan = false;
  bool _isSaving = false;
  bool _isLoadingRiwayat = false;

  // Form state
  DoaKaryawanItem? _pemimpinDoa;
  final Set<String> _selectedPeserta = {};
  final TextEditingController _catatanCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Riwayat
  List<DoaRecord> _riwayat = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserId();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _catatanCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    if (widget.initialHrdUserId != null) {
      _hrdUserId = widget.initialHrdUserId;
    } else {
      final prefs = await SharedPreferences.getInstance();
      _hrdUserId = prefs.getString('UserID');
    }
    if (_hrdUserId != null) {
      await _loadKaryawan();
      await _loadRiwayat();
    }
    setState(() {});
  }

  Future<void> _loadKaryawan() async {
    if (_hrdUserId == null) return;
    setState(() => _isLoadingKaryawan = true);
    final list = await DoaService.getKaryawan(_hrdUserId!);
    setState(() {
      _karyawan = list;
      _isLoadingKaryawan = false;
    });
  }

  Future<void> _loadRiwayat() async {
    if (_hrdUserId == null) return;
    setState(() => _isLoadingRiwayat = true);
    final list = await DoaService.getDoaByTanggal(_hrdUserId!, _selectedDate);
    setState(() {
      _riwayat = list;
      _isLoadingRiwayat = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadRiwayat();
    }
  }

  Future<void> _save() async {
    if (_pemimpinDoa == null) {
      _snack('Pemimpin doa wajib dipilih', err: true);
      return;
    }
    if (_selectedPeserta.isEmpty) {
      _snack('Pilih minimal 1 peserta doa', err: true);
      return;
    }

    setState(() => _isSaving = true);
    final result = await DoaService.saveDoa(
      hrdUserId: _hrdUserId!,
      tanggal: _selectedDate,
      pemimpinDoaId: _pemimpinDoa!.userId,
      pesertaIds: _selectedPeserta.toList(),
      catatan: _catatanCtrl.text.trim().isNotEmpty
          ? _catatanCtrl.text.trim()
          : null,
    );
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      _snack('Data doa berhasil disimpan!', err: false);
      _resetForm();
      _tabController.animateTo(1); // pindah ke tab riwayat
      await _loadRiwayat();
      widget.onDoaSaved?.call(); // notif parent untuk refresh doaMap
    } else {
      _snack(result['message'] ?? 'Gagal menyimpan', err: true);
    }
  }

  void _resetForm() {
    setState(() {
      _pemimpinDoa = null;
      _selectedPeserta.clear();
      _catatanCtrl.clear();
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  List<DoaKaryawanItem> get _filteredKaryawan {
    if (_searchQuery.isEmpty) return _karyawan;
    return _karyawan
        .where(
          (k) =>
              k.name.toLowerCase().contains(_searchQuery) ||
              (k.organization?.toLowerCase().contains(_searchQuery) ?? false) ||
              (k.jobPosition?.toLowerCase().contains(_searchQuery) ?? false),
        )
        .toList();
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
      backgroundColor: err ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Input Doa Karyawan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Colors.black87),
              onPressed: () async {
                await _loadKaryawan();
                await _loadRiwayat();
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Input Doa'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildInputTab(), _buildRiwayatTab()],
      ),
    );
  }

  // ── Tab Input ────────────────────────────────────────────────────
  Widget _buildInputTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.volunteer_activism,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 10),
              const Text(
                'Input Doa Karyawan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Catat pemimpin dan peserta doa hari ini',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Pilih Tanggal
        _sectionLabel('Tanggal Doa', Icons.calendar_today),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat(
                    'EEEE, dd MMMM yyyy',
                    'id_ID',
                  ).format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Pemimpin Doa
        _sectionLabel('Pemimpin Doa', Icons.record_voice_over),
        const SizedBox(height: 4),
        Text(
          'Pilih 1 orang yang memimpin doa',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),
        _isLoadingKaryawan
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              )
            : _buildPemimpinSelector(),
        const SizedBox(height: 20),

        // Peserta Doa
        _sectionLabel('Peserta Doa', Icons.people),
        const SizedBox(height: 4),
        Text(
          'Pilih semua karyawan yang mengikuti doa (${_selectedPeserta.length} dipilih)',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),

        // Search karyawan
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Cari nama, departemen...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: Color(0xFF6B7280),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6366F1)),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),

        // Select all / clear
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(
                () => _selectedPeserta.addAll(
                  _filteredKaryawan.map((k) => k.userId),
                ),
              ),
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Pilih Semua'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                visualDensity: VisualDensity.compact,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedPeserta.clear()),
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Batal Semua'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[400],
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        _isLoadingKaryawan
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              )
            : _buildPesertaList(),
        const SizedBox(height: 20),

        // Catatan
        _sectionLabel('Catatan (Opsional)', Icons.note_alt_outlined),
        const SizedBox(height: 8),
        TextField(
          controller: _catatanCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Tambahkan catatan tentang doa hari ini...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1)),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 24),

        // Summary card sebelum save
        if (_pemimpinDoa != null || _selectedPeserta.isNotEmpty)
          _buildSummaryCard(),
        const SizedBox(height: 16),

        // Tombol Simpan
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan Data Doa',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset Form'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );

  Widget _buildPemimpinSelector() {
    final list = _filteredKaryawan;
    if (list.isEmpty) return _emptyKaryawan();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: list.map((k) {
          final selected = _pemimpinDoa?.userId == k.userId;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _pemimpinDoa = selected ? null : k),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF6366F1).withOpacity(0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: selected
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF6366F1).withOpacity(0.1),
                    child: Text(
                      k.name.isNotEmpty ? k.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          k.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (k.organization != null || k.jobPosition != null)
                          Text(
                            '${k.jobPosition ?? ''} ${k.organization != null ? '• ${k.organization}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.mic_rounded,
                      size: 20,
                      color: Color(0xFF6366F1),
                    ),
                  Radio<String>(
                    value: k.userId,
                    groupValue: _pemimpinDoa?.userId,
                    onChanged: (v) => setState(() => _pemimpinDoa = k),
                    activeColor: const Color(0xFF6366F1),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPesertaList() {
    final list = _filteredKaryawan;
    if (list.isEmpty) return _emptyKaryawan();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: list.asMap().entries.map((entry) {
          final idx = entry.key;
          final k = entry.value;
          final checked = _selectedPeserta.contains(k.userId);
          final isPemimpin = _pemimpinDoa?.userId == k.userId;
          return Column(
            children: [
              if (idx > 0) const Divider(height: 1, indent: 56),
              InkWell(
                onTap: () => setState(() {
                  if (checked) {
                    _selectedPeserta.remove(k.userId);
                  } else {
                    _selectedPeserta.add(k.userId);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  color: checked
                      ? const Color(0xFF10B981).withOpacity(0.04)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: checked
                            ? const Color(0xFF10B981)
                            : Colors.grey[200],
                        child: Text(
                          k.name.isNotEmpty ? k.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: checked ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    k.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                if (isPemimpin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Pemimpin',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (k.organization != null || k.jobPosition != null)
                              Text(
                                '${k.jobPosition ?? ''} ${k.organization != null ? '• ${k.organization}' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: checked,
                        onChanged: (_) => setState(() {
                          if (checked) {
                            _selectedPeserta.remove(k.userId);
                          } else {
                            _selectedPeserta.add(k.userId);
                          }
                        }),
                        activeColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFBBF7D0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.summarize_rounded, size: 16, color: Color(0xFF16A34A)),
            SizedBox(width: 6),
            Text(
              'Ringkasan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _summaryRow(
          'Tanggal',
          DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
        ),
        if (_pemimpinDoa != null)
          _summaryRow('Pemimpin Doa', _pemimpinDoa!.name),
        _summaryRow('Peserta', '${_selectedPeserta.length} orang'),
      ],
    ),
  );

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Tab Riwayat ──────────────────────────────────────────────────
  Widget _buildRiwayatTab() => Column(
    children: [
      // Date picker strip
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: Color(0xFF6366F1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.edit_calendar, size: 16),
              label: const Text('Ganti'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: _isLoadingRiwayat
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              )
            : _riwayat.isEmpty
            ? _buildEmptyRiwayat()
            : RefreshIndicator(
                onRefresh: _loadRiwayat,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _riwayat.length,
                  itemBuilder: (_, i) => _buildRiwayatCard(_riwayat[i]),
                ),
              ),
      ),
    ],
  );

  Widget _buildRiwayatCard(DoaRecord rec) => Container(
    margin: const EdgeInsets.only(bottom: 14),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.volunteer_activism,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy', 'id_ID').format(rec.tanggal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${rec.pesertaNames.length} peserta',
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
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pemimpin
              Row(
                children: [
                  const Icon(
                    Icons.mic_rounded,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Pemimpin Doa:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rec.pemimpinDoaName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Peserta
              Row(
                children: [
                  const Icon(
                    Icons.people_rounded,
                    size: 16,
                    color: Color(0xFF374151),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Peserta (${rec.pesertaNames.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: rec.pesertaNames
                    .map(
                      (name) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: const Color(
                                0xFF6366F1,
                              ).withOpacity(0.15),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),

              // Catatan
              if (rec.catatan != null && rec.catatan!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note_rounded,
                        size: 14,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rec.catatan!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Waktu input
              if (rec.createdAt != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Diinput: ${DateFormat('dd MMM yyyy HH:mm').format(rec.createdAt!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildEmptyRiwayat() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.volunteer_activism,
              size: 56,
              color: Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Data Doa',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada data doa untuk tanggal ${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(0),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Input Doa Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyKaryawan() => Container(
    padding: const EdgeInsets.all(20),
    alignment: Alignment.center,
    child: Text(
      _isLoadingKaryawan ? 'Memuat data...' : 'Tidak ada karyawan ditemukan',
      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
    ),
  );

  Widget _sectionLabel(String label, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF6366F1)),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
      ),
    ],
  );
}
