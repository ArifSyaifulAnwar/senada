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
  String _levelFilter = 'Semua';

  static const _levelFilters = ['Semua', 'Verbal', 'SP1', 'SP2', 'SP3'];

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
    if (_hrdUserId == null || _hrdUserId!.isEmpty) {
      setState(() => _loadingList = false);
      return;
    }
    final list = await TeguranService.getAllTeguran(_hrdUserId!);
    if (!mounted) return;
    setState(() {
      _allTeguran = list;
      _loadingList = false;
    });
  }

  List<TeguranData> get _filteredTeguran {
    final q = _searchKeyword.trim().toLowerCase();
    return _allTeguran.where((t) {
      final matchesLevel = _levelFilter == 'Semua' || t.level == _levelFilter;
      final matchesSearch =
          q.isEmpty ||
          (t.userName ?? '').toLowerCase().contains(q) ||
          t.judul.toLowerCase().contains(q) ||
          t.noSurat.toLowerCase().contains(q);
      return matchesLevel && matchesSearch;
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _levelFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final lvl = _levelFilters[i];
                  final selected = _levelFilter == lvl;
                  return ChoiceChip(
                    label: Text(lvl),
                    selected: selected,
                    onSelected: (_) => setState(() => _levelFilter = lvl),
                  );
                },
              ),
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
                    itemBuilder: (context, i) => _TeguranListCard(
                      data: _filteredTeguran[i],
                      onUpdated: _loadTeguranList,
                    ),
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

  final List<EmployeeApiData> _selectedEmployees = [];
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
    if (_selectedEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 karyawan yang akan ditegur.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    // Buat 1 teguran (1 surat) per karyawan — judul/deskripsi/level/tanggal
    // sama untuk semua, tapi tetap N baris teguran terpisah (N no_surat, N
    // notifikasi, N PDF), bukan 1 surat gabungan.
    final failedNames = <String>[];
    for (final emp in _selectedEmployees) {
      final result = await TeguranService.createTeguran(
        userId: emp.userId,
        level: _level,
        judul: _judulController.text.trim(),
        deskripsi: _deskripsiController.text.trim(),
        tanggal: _tanggal,
        issuedBy: widget.hrdUserId,
        issuedByName: widget.hrdUserName,
      );
      if (!result.success) failedNames.add(emp.name);
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final total = _selectedEmployees.length;
    final successCount = total - failedNames.length;
    final message = failedNames.isEmpty
        ? (total > 1
            ? 'Berhasil membuat $total teguran.'
            : 'Teguran berhasil dibuat.')
        : '$successCount/$total teguran berhasil dibuat. Gagal: ${failedNames.join(', ')}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failedNames.isEmpty ? Colors.green : Colors.orange,
      ),
    );

    if (failedNames.isEmpty) {
      setState(() {
        _selectedEmployees.clear();
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
            else ...[
              if (_selectedEmployees.isNotEmpty) ...[
                Text(
                  '${_selectedEmployees.length} karyawan dipilih — teguran ini akan dibuat terpisah untuk masing-masing (1 surat per orang).',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedEmployees
                      .map(
                        (emp) => Chip(
                          backgroundColor: const Color(0xFFEFF6FF),
                          label: Text(
                            emp.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () =>
                              setState(() => _selectedEmployees.remove(emp)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
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
                          final isSelected = _selectedEmployees.any(
                            (e) => e.userId == emp.userId,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(emp.name),
                            subtitle: Text(
                              [
                                emp.jobPosition,
                                emp.department,
                              ].where((e) => (e ?? '').isNotEmpty).join(' • '),
                            ),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selectedEmployees.add(emp);
                              } else {
                                _selectedEmployees.removeWhere(
                                  (e) => e.userId == emp.userId,
                                );
                              }
                            }),
                          );
                        },
                        ),
                        ),
                      ),
              ),
            ],
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
  final VoidCallback onUpdated;

  const _TeguranListCard({required this.data, required this.onUpdated});

  @override
  State<_TeguranListCard> createState() => _TeguranListCardState();
}

class _TeguranListCardState extends State<_TeguranListCard> {
  bool _downloading = false;

  TeguranData get data => widget.data;

  Future<void> _showEditSheet() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditTeguranSheet(data: data),
    );
    if (updated == true) widget.onUpdated();
  }

  Future<void> _downloadAndOpenSurat() async {
    setState(() => _downloading = true);
    try {
      final bytes = await TeguranService.downloadTeguranPdf(data.id);
      final fileName = TeguranService.buildSuratFileName(
        userName: data.userName,
        userId: data.userId,
        level: data.level,
      );

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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _showEditSheet,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 12),
                _downloading
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit teguran (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _EditTeguranSheet extends StatefulWidget {
  final TeguranData data;

  const _EditTeguranSheet({required this.data});

  @override
  State<_EditTeguranSheet> createState() => _EditTeguranSheetState();
}

class _EditTeguranSheetState extends State<_EditTeguranSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judulController;
  late final TextEditingController _deskripsiController;
  late String _level;
  late DateTime _tanggal;
  bool _submitting = false;

  static const _levels = ['Verbal', 'SP1', 'SP2', 'SP3'];

  @override
  void initState() {
    super.initState();
    _judulController = TextEditingController(text: widget.data.judul);
    _deskripsiController = TextEditingController(text: widget.data.deskripsi ?? '');
    _level = widget.data.level;
    _tanggal = widget.data.tanggal;
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final result = await TeguranService.updateTeguran(
      id: widget.data.id,
      level: _level,
      judul: _judulController.text.trim(),
      deskripsi: _deskripsiController.text.trim(),
      tanggal: _tanggal,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    if (result.success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit Teguran',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              Text(
                widget.data.userName ?? widget.data.userId,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),

              const Text(
                'Level Teguran',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
              const SizedBox(height: 16),

              const Text(
                'Judul',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _judulController,
                decoration: InputDecoration(
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
              const SizedBox(height: 16),

              const Text(
                'Deskripsi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deskripsiController,
                maxLines: 4,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Tanggal',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
              const SizedBox(height: 24),

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
                          'Simpan Perubahan',
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
      ),
    );
  }
}
