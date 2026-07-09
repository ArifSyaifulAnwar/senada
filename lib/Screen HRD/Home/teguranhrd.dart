// lib/Screen HRD/Home/teguranhrd.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:absensikaryawan/Services/teguran_service.dart';
import 'package:absensikaryawan/Screen%20User/Screen%20HRD/hrd_employee_service.dart';
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:absensikaryawan/utils/web_file_download.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeguranHrdScreen extends StatefulWidget {
  const TeguranHrdScreen({super.key});

  @override
  State<TeguranHrdScreen> createState() => _TeguranHrdScreenState();
}

class _TeguranHrdScreenState extends State<TeguranHrdScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String? _hrdUserId;
  String? _hrdUserName;

  List<EmployeeApiData> _allActiveEmployees = [];
  bool _loadingEmployees = true;

  List<TeguranData> _allTeguran = [];
  bool _loadingList = true;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHrdIdentity().then((_) {
      _loadEmployees();
      _loadTeguranList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHrdIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _hrdUserId = prefs.getString('UserID');
    _hrdUserName = prefs.getString('Name');
  }

  Future<void> _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final res = await HrdEmployeeService.getEmployeeList(
        status: 'Aktif',
        pageSize: 1000,
      );
      if (res.success && res.data != null) {
        _allActiveEmployees = res.data!.data;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingEmployees = false);
  }

  Future<void> _loadTeguranList() async {
    setState(() => _loadingList = true);
    final list = await TeguranService.getAllTeguran();
    if (!mounted) return;
    setState(() {
      _allTeguran = list;
      _loadingList = false;
    });
  }

  List<TeguranData> get _filteredTeguran {
    if (_searchKeyword.trim().isEmpty) return _allTeguran;
    final q = _searchKeyword.trim().toLowerCase();
    return _allTeguran.where((t) {
      return (t.userName ?? '').toLowerCase().contains(q) ||
          t.judul.toLowerCase().contains(q) ||
          t.noSurat.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Teguran Karyawan',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF007AFF),
          tabs: const [
            Tab(text: 'Buat Teguran'),
            Tab(text: 'Daftar Teguran'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CreateTeguranTab(
            allActiveEmployees: _allActiveEmployees,
            loadingEmployees: _loadingEmployees,
            hrdUserId: _hrdUserId,
            hrdUserName: _hrdUserName,
            onCreated: _loadTeguranList,
          ),
          _buildListTab(),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    return RefreshIndicator(
      onRefresh: _loadTeguranList,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama karyawan / judul / no. surat...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              onChanged: (v) => setState(() => _searchKeyword = v),
            ),
          ),
          Expanded(
            child: _loadingList
                ? const Center(child: CircularProgressIndicator())
                : _filteredTeguran.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'Belum ada teguran yang dibuat.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _filteredTeguran.length,
                    itemBuilder: (context, i) =>
                        _TeguranListCard(data: _filteredTeguran[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Buat Teguran
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTeguranTab extends StatefulWidget {
  final List<EmployeeApiData> allActiveEmployees;
  final bool loadingEmployees;
  final String? hrdUserId;
  final String? hrdUserName;
  final VoidCallback onCreated;

  const _CreateTeguranTab({
    required this.allActiveEmployees,
    required this.loadingEmployees,
    required this.hrdUserId,
    required this.hrdUserName,
    required this.onCreated,
  });

  @override
  State<_CreateTeguranTab> createState() => _CreateTeguranTabState();
}

class _CreateTeguranTabState extends State<_CreateTeguranTab> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  EmployeeApiData? _selectedEmployee;
  String _level = 'SP1';
  DateTime _tanggal = DateTime.now();
  bool _submitting = false;

  static const _levels = ['Verbal', 'SP1', 'SP2', 'SP3'];

  @override
  void dispose() {
    _searchController.dispose();
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  List<EmployeeApiData> get _filteredEmployees {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.allActiveEmployees;
    return widget.allActiveEmployees.where((e) {
      return e.name.toLowerCase().contains(q) ||
          (e.department ?? '').toLowerCase().contains(q) ||
          (e.jobPosition ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'SP1':
        return Colors.orange;
      case 'SP2':
        return Colors.deepOrange;
      case 'SP3':
        return Colors.red;
      default:
        return Colors.blueAccent;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _submit() async {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih karyawan yang akan ditegur.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final result = await TeguranService.createTeguran(
      userId: _selectedEmployee!.userId,
      level: _level,
      judul: _judulController.text.trim(),
      deskripsi: _deskripsiController.text.trim(),
      tanggal: _tanggal,
      issuedBy: widget.hrdUserId,
      issuedByName: widget.hrdUserName,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    if (result.success) {
      setState(() {
        _selectedEmployee = null;
        _searchController.clear();
        _judulController.clear();
        _deskripsiController.clear();
        _level = 'SP1';
        _tanggal = DateTime.now();
      });
      widget.onCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Karyawan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama karyawan...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (widget.loadingEmployees)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selectedEmployee != null)
              Card(
                color: const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Color(0xFF007AFF)),
                  title: Text(
                    _selectedEmployee!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      _selectedEmployee!.jobPosition,
                      _selectedEmployee!.department,
                    ].where((e) => (e ?? '').isNotEmpty).join(' • '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedEmployee = null),
                  ),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: _filteredEmployees.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Karyawan tidak ditemukan.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Material(
                        color: Colors.white,
                        child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredEmployees.length,
                        itemBuilder: (context, i) {
                          final emp = _filteredEmployees[i];
                          return ListTile(
                            title: Text(emp.name),
                            subtitle: Text(
                              [
                                emp.jobPosition,
                                emp.department,
                              ].where((e) => (e ?? '').isNotEmpty).join(' • '),
                            ),
                            onTap: () => setState(() => _selectedEmployee = emp),
                          );
                        },
                        ),
                        ),
                      ),
              ),
            const SizedBox(height: 20),

            const Text(
              'Level Teguran',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _levels.map((lvl) {
                final selected = _level == lvl;
                final color = _colorForLevel(lvl);
                return ChoiceChip(
                  label: Text(lvl),
                  selected: selected,
                  selectedColor: color.withOpacity(0.18),
                  labelStyle: TextStyle(
                    color: selected ? color : Colors.black87,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                  onSelected: (_) => setState(() => _level = lvl),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text(
              'Judul',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _judulController,
              decoration: InputDecoration(
                hintText: 'Contoh: Terlambat Masuk Kerja',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Judul wajib diisi.' : null,
            ),
            const SizedBox(height: 20),

            const Text(
              'Deskripsi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _deskripsiController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Jelaskan detail pelanggaran / alasan teguran...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Tanggal',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Text(DateFormat('d MMMM yyyy', 'id_ID').format(_tanggal)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Kirim Teguran',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card list item
// ─────────────────────────────────────────────────────────────────────────────

class _TeguranListCard extends StatefulWidget {
  final TeguranData data;

  const _TeguranListCard({required this.data});

  @override
  State<_TeguranListCard> createState() => _TeguranListCardState();
}

class _TeguranListCardState extends State<_TeguranListCard> {
  bool _downloading = false;

  TeguranData get data => widget.data;

  Future<void> _downloadAndOpenSurat() async {
    setState(() => _downloading = true);
    try {
      final bytes = await TeguranService.downloadTeguranPdf(data.id);
      final fileName = 'SuratTeguran_${data.id}.pdf';

      if (kIsWeb) {
        downloadFileWeb(fileName, bytes);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka surat: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'SP1':
        return Colors.orange;
      case 'SP2':
        return Colors.deepOrange;
      case 'SP3':
        return Colors.red;
      default:
        return Colors.blueAccent;
    }
  }

  IconData _iconForLevel(String level) {
    switch (level) {
      case 'SP1':
        return Icons.warning_amber_rounded;
      case 'SP2':
        return Icons.error_outline;
      case 'SP3':
        return Icons.report;
      default:
        return Icons.record_voice_over;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(data.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.13),
                  child: Icon(_iconForLevel(data.level), color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.userName ?? data.userId,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if ((data.jobPosition ?? '').isNotEmpty || (data.department ?? '').isNotEmpty)
                        Text(
                          [data.jobPosition, data.department]
                              .where((e) => (e ?? '').isNotEmpty)
                              .join(' • '),
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.level,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.judul,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            if ((data.deskripsi ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                data.deskripsi!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM yyyy', 'id_ID').format(data.tanggal),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 14),
                Icon(Icons.confirmation_number, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    data.noSurat,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: _downloadAndOpenSurat,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Lihat/Unduh Surat'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
