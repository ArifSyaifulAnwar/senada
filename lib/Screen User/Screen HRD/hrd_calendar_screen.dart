// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Services/company_calendar_service.dart';

class HrdCalendarScreen extends StatefulWidget {
  const HrdCalendarScreen({super.key});

  @override
  State<HrdCalendarScreen> createState() => _HrdCalendarScreenState();
}

class _HrdCalendarScreenState extends State<HrdCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _hrdUserId;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  List<CompanyCalendarEvent> _events = [];
  bool _isLoading = false;
  String _filterTipe = 'SEMUA';

  final List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final List<String> _dayNames = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _hrdUserId = prefs.getString('UserID'));
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await CompanyCalendarService.getByYear(
      _selectedYear,
      forceRefresh: true,
    );
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  List<CompanyCalendarEvent> get _filteredEvents {
    var list = _filterTipe == 'SEMUA'
        ? _events
        : _events.where((e) => e.tipe == _filterTipe).toList();
    list.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return list;
  }

  // Events untuk bulan tertentu
  List<CompanyCalendarEvent> _eventsForMonth(int month) => _events
      .where((e) => e.tanggal.year == _selectedYear && e.tanggal.month == month)
      .toList();

  // Events untuk tanggal tertentu
  List<CompanyCalendarEvent> _eventsForDate(DateTime date) => _events
      .where(
        (e) =>
            e.tanggal.year == date.year &&
            e.tanggal.month == date.month &&
            e.tanggal.day == date.day,
      )
      .toList();

  Color _tipeColor(String tipe) {
    switch (tipe) {
      case 'LIBUR':
        return const Color(0xFFEF4444);
      case 'WFH':
        return const Color(0xFF10B981);
      case 'LEMBUR':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData _tipeIcon(String tipe) {
    switch (tipe) {
      case 'LIBUR':
        return Icons.beach_access_rounded;
      case 'WFH':
        return Icons.home_work_rounded;
      case 'LEMBUR':
        return Icons.access_time_rounded;
      default:
        return Icons.event;
    }
  }

  void _snack(
    String msg, {
    bool err = false,
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

  // ── DIALOG TAMBAH / EDIT ────────────────────────────────────────
  Future<void> _showFormDialog({
    CompanyCalendarEvent? existing,
    DateTime? initialDate,
  }) async {
    DateTime selectedDate = existing?.tanggal ?? initialDate ?? DateTime.now();
    String selectedTipe = existing?.tipe ?? 'LIBUR';
    final keteranganCtrl = TextEditingController(
      text: existing?.keterangan ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            existing == null ? 'Tambah Event Kalender' : 'Edit Event',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tanggal
                const Text(
                  'Tanggal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (_, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF6366F1),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setDlg(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat(
                            'EEEE, dd MMMM yyyy',
                            'id_ID',
                          ).format(selectedDate),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tipe
                const Text(
                  'Tipe',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: ['LIBUR', 'WFH', 'LEMBUR'].map((tipe) {
                    final sel = selectedTipe == tipe;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setDlg(() => selectedTipe = tipe),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? _tipeColor(tipe).withOpacity(0.1)
                                : const Color(0xFFF9FAFB),
                            border: Border.all(
                              color: sel
                                  ? _tipeColor(tipe)
                                  : const Color(0xFFE5E7EB),
                              width: sel ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _tipeIcon(tipe),
                                size: 18,
                                color: sel ? _tipeColor(tipe) : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tipe,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? _tipeColor(tipe) : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Keterangan
                const Text(
                  'Keterangan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: keteranganCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Hari Raya Idul Fitri',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
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
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (keteranganCtrl.text.trim().isEmpty) {
                  _snack('Keterangan wajib diisi', err: true);
                  return;
                }
                Navigator.pop(ctx);
                final result = await CompanyCalendarService.save(
                  id: existing?.id,
                  tanggal: DateFormat('yyyy-MM-dd').format(selectedDate),
                  tipe: selectedTipe,
                  keterangan: keteranganCtrl.text.trim(),
                  createdBy: _hrdUserId ?? '',
                );
                if (result['success'] == true) {
                  _snack(
                    existing == null
                        ? 'Event berhasil ditambahkan!'
                        : 'Event berhasil diupdate!',
                  );
                  await _loadEvents();
                } else {
                  _snack(result['message'] ?? 'Gagal', err: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(existing == null ? 'Simpan' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  // ── DELETE ──────────────────────────────────────────────────────
  Future<void> _confirmDelete(CompanyCalendarEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Event?'),
        content: Text(
          'Yakin hapus "${event.keterangan}" pada '
          '${DateFormat('dd MMM yyyy', 'id_ID').format(event.tanggal)}?',
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

    if (confirm == true) {
      final result = await CompanyCalendarService.delete(
        id: event.id,
        deletedBy: _hrdUserId ?? '',
        tahun: event.tanggal.year,
      );
      if (result['success'] == true) {
        _snack('Event berhasil dihapus!');
        await _loadEvents();
      } else {
        _snack(result['message'] ?? 'Gagal', err: true);
      }
    }
  }

  // ── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Kelola Kalender',
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
              onPressed: _loadEvents,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Daftar Event'),
            Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Kalender'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Event',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildListTab(), _buildCalendarTab()],
      ),
    );
  }

  // ── TAB 1: LIST ─────────────────────────────────────────────────
  Widget _buildListTab() {
    return Column(
      children: [
        // Year selector + filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _selectedYear--);
                  _loadEvents();
                },
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$_selectedYear',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _selectedYear++);
                  _loadEvents();
                },
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              ...[
                ('SEMUA', Colors.grey),
                ('LIBUR', const Color(0xFFEF4444)),
                ('WFH', const Color(0xFF10B981)),
                ('LEMBUR', const Color(0xFFF59E0B)),
              ].map((item) {
                final sel = _filterTipe == item.$1;
                return GestureDetector(
                  onTap: () => setState(() => _filterTipe = item.$1),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? item.$2.withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: sel ? item.$2 : const Color(0xFFE5E7EB),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? item.$2 : Colors.grey,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),

        // Stats bar
        if (!_isLoading && _events.isNotEmpty) _buildStatsBar(),

        // List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                )
              : _filteredEvents.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (_, i) => _buildEventCard(_filteredEvents[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    final liburCount = _events.where((e) => e.tipe == 'LIBUR').length;
    final wfhCount = _events.where((e) => e.tipe == 'WFH').length;
    final lemburCount = _events.where((e) => e.tipe == 'LEMBUR').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _statChip('$liburCount Libur', const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _statChip('$wfhCount WFH', const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _statChip('$lemburCount Lembur', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _buildEventCard(CompanyCalendarEvent event) {
    final color = _tipeColor(event.tipe);
    final isSabtu = event.tanggal.weekday == DateTime.saturday;
    final isMinggu = event.tanggal.weekday == DateTime.sunday;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Tanggal box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${event.tanggal.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    _monthNames[event.tanggal.month - 1].substring(0, 3),
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.keterangan,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 11,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat(
                          'EEEE, dd MMM yyyy',
                          'id_ID',
                        ).format(event.tanggal),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      if (isSabtu || isMinggu) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isSabtu ? 'Sabtu' : 'Minggu',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.red[400],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Badge tipe
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                event.tipe,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Menu edit/delete
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showFormDialog(existing: event);
                if (val == 'delete') _confirmDelete(event);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16, color: Color(0xFF6366F1)),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Hapus'),
                    ],
                  ),
                ),
              ],
              child: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 2: KALENDER GRID ────────────────────────────────────────
  Widget _buildCalendarTab() {
    return Column(
      children: [
        // Month + Year navigator
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  if (_selectedMonth == 1) {
                    _selectedMonth = 12;
                    _selectedYear--;
                    _loadEvents();
                  } else {
                    _selectedMonth--;
                  }
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedMonth = DateTime.now().month;
                  _selectedYear = DateTime.now().year;
                }),
                child: Column(
                  children: [
                    Text(
                      '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${_eventsForMonth(_selectedMonth).length} event',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  if (_selectedMonth == 12) {
                    _selectedMonth = 1;
                    _selectedYear++;
                    _loadEvents();
                  } else {
                    _selectedMonth++;
                  }
                }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Kalender grid + event list bulan ini
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              children: [
                _buildMonthGrid(_selectedMonth),
                const SizedBox(height: 20),
                _buildMonthEventList(_selectedMonth),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Grid kalender 1 bulan
  Widget _buildMonthGrid(int month) {
    final firstDay = DateTime(_selectedYear, month, 1);
    final lastDay = DateTime(_selectedYear, month + 1, 0);
    final startWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header hari
            Row(
              children: _dayNames
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: d == 'Min'
                                ? Colors.red
                                : d == 'Sab'
                                ? Colors.red[300]
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 8),

            // Grid hari
            ..._buildGridRows(firstDay, lastDay, startWeekday),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGridRows(
    DateTime firstDay,
    DateTime lastDay,
    int startWeekday,
  ) {
    final List<Widget> rows = [];
    List<Widget> cells = [];

    // Empty cells awal
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const Expanded(child: SizedBox(height: 48)));
    }

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_selectedYear, firstDay.month, day);
      final events = _eventsForDate(date);
      final isToday =
          date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;
      final isSunday = date.weekday == DateTime.sunday;
      final isSaturday = date.weekday == DateTime.saturday;
      final isWeekend = isSunday || isSaturday;

      // Warna background
      Color? bgColor;
      Color textColor;
      if (isToday) {
        bgColor = const Color(0xFF6366F1);
        textColor = Colors.white;
      } else if (events.any((e) => e.tipe == 'LIBUR')) {
        bgColor = const Color(0xFFEF4444).withOpacity(0.1);
        textColor = const Color(0xFFEF4444);
      } else if (events.any((e) => e.tipe == 'WFH')) {
        bgColor = const Color(0xFF10B981).withOpacity(0.1);
        textColor = const Color(0xFF10B981);
      } else if (events.any((e) => e.tipe == 'LEMBUR')) {
        bgColor = const Color(0xFFF59E0B).withOpacity(0.1);
        textColor = const Color(0xFFF59E0B);
      } else if (isWeekend) {
        textColor = Colors.red[300]!;
      } else {
        textColor = const Color(0xFF1E293B);
      }

      cells.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (events.isNotEmpty) {
                _showDayEventsSheet(date, events);
              } else {
                // Langsung buka form tambah dengan tanggal ini
                _showFormDialog(initialDate: date);
              }
            },
            onLongPress: () => _showFormDialog(initialDate: date),
            child: Container(
              height: 48,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: const Color(0xFF6366F1), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  // Dot indicator event
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events
                          .take(3)
                          .map(
                            (e) => Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.white
                                    : _tipeColor(e.tipe),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      // Akhir minggu atau akhir bulan
      if ((startWeekday + day) % 7 == 0 || day == lastDay.day) {
        if (day == lastDay.day) {
          final rem = 7 - cells.length;
          for (int i = 0; i < rem; i++) {
            cells.add(const Expanded(child: SizedBox(height: 48)));
          }
        }
        rows.add(Row(children: List.from(cells)));
        cells.clear();
      }
    }
    return rows;
  }

  // List event dalam 1 bulan (di bawah grid)
  Widget _buildMonthEventList(int month) {
    final events = _eventsForMonth(month)
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'Tidak ada event di bulan ini',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _showFormDialog(
                initialDate: DateTime(_selectedYear, month, 1),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Event'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Event ${_monthNames[month - 1]} $_selectedYear',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        ...events.map((e) => _buildEventCard(e)),
      ],
    );
  }

  // Bottom sheet detail event per hari (saat tap tanggal yang ada event)
  void _showDayEventsSheet(DateTime date, List<CompanyCalendarEvent> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      // Tombol tambah event di hari ini
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showFormDialog(initialDate: date);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...events.map(
                    (e) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _tipeColor(e.tipe).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _tipeColor(e.tipe).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _tipeIcon(e.tipe),
                            color: _tipeColor(e.tipe),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.keterangan,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  e.tipe,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _tipeColor(e.tipe),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Edit
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showFormDialog(existing: e);
                            },
                            icon: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Color(0xFF6366F1),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          // Delete
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDelete(e);
                            },
                            icon: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Color(0xFFEF4444),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
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
              Icons.event_note,
              size: 56,
              color: Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Event',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap tombol + untuk menambah hari libur, WFH, atau lembur',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    ),
  );
}
