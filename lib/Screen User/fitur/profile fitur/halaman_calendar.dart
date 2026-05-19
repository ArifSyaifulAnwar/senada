// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import '../../../Services/calendar_event_service.dart';
import '../../../models/calendermodel.dart';

// ── helper ──────────────────────────────────────────────────────────
bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class HalamanCalendar extends StatefulWidget {
  const HalamanCalendar({super.key});

  @override
  _HalamanCalendarState createState() => _HalamanCalendarState();
}

class _HalamanCalendarState extends State<HalamanCalendar> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  Map<DateTime, List<CalendarEvent>> _events = {};
  bool _isLoadingEvents = false;

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
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    // Service sudah handle semua error secara internal dan
    // selalu return map (bisa kosong atau fallback), tidak pernah throw.
    final events = await CalendarEventService.getDayoffEvents(
      _focusedDate.year,
    );
    if (mounted) {
      setState(() {
        _events = events;
        _isLoadingEvents = false;
      });
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  bool _isSunday(DateTime date) => date.weekday == 7;

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  bool _hasHolidayOrCuti(DateTime date) {
    final events = _getEventsForDay(date);
    return events.any((e) => e.isHoliday || e.isCutiBersama);
  }

  void _previousMonth() {
    final newDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
    setState(() => _focusedDate = newDate);
    if (newDate.year != _selectedDate.year) _loadEventsForYear(newDate.year);
  }

  void _nextMonth() {
    final newDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
    setState(() => _focusedDate = newDate);
    if (newDate.year != _selectedDate.year) _loadEventsForYear(newDate.year);
  }

  Future<void> _loadEventsForYear(int year) async {
    final events = await CalendarEventService.getDayoffEvents(year);
    if (mounted) setState(() => _events.addAll(events));
  }

  void _goToToday() {
    setState(() {
      _focusedDate = DateTime.now();
      _selectedDate = DateTime.now();
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWeb = _isWideScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoadingEvents
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
          : isWeb
          ? _buildWebLayout()
          : _buildMobileLayout(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Calendar',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          letterSpacing: 0.3,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87, size: 18),
            onPressed: () async {
              await CalendarEventService.refreshEvents(_focusedDate.year);
              _loadEvents();
            },
            tooltip: 'Refresh Events',
          ),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.today, color: Colors.black87, size: 18),
            onPressed: _goToToday,
            tooltip: 'Go to Today',
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (layout asli, scroll vertikal)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarHeader(),
            const SizedBox(height: 24),
            _buildCalendarGrid(),
            const SizedBox(height: 24),
            _buildEventsSection(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB LAYOUT (2 kolom: kalender kiri | event list kanan)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Kolom kiri: Header + Grid kalender ─────────────
        Container(
          width: 420,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildCalendarHeader(),
                const SizedBox(height: 20),
                _buildCalendarGrid(),
                const SizedBox(height: 16),
                _buildWebLegend(),
              ],
            ),
          ),
        ),

        // ── Kolom kanan: Event list ─────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadEvents,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildEventsSection(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Legend kecil di bawah kalender (web only) ─────────
  Widget _buildWebLegend() {
    final items = [
      {'color': const Color(0xFF3B82F6), 'label': 'Hari ini'},
      {'color': Colors.red, 'label': 'Minggu / Libur'},
      {'color': Colors.orange, 'label': 'Cuti Bersama'},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item['color'] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item['label'] as String,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          ),
          Column(
            children: [
              Text(
                '${_monthNames[_focusedDate.month - 1]} ${_focusedDate.year}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _focusedDate.year == DateTime.now().year &&
                        _focusedDate.month == DateTime.now().month
                    ? 'Bulan Ini'
                    : '',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: _dayNames.map((dayName) {
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      dayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dayName == 'Min'
                            ? Colors.red
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(color: Color(0xFFE5E7EB)),
            ..._buildCalendarDays(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCalendarDays() {
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth = DateTime(
      _focusedDate.year,
      _focusedDate.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday == 7
        ? 0
        : firstDayOfMonth.weekday;

    List<Widget> weeks = [];
    List<Widget> days = [];

    for (int i = 0; i < firstWeekday; i++) {
      days.add(const Expanded(child: SizedBox()));
    }

    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_focusedDate.year, _focusedDate.month, day);
      final events = _getEventsForDay(date);
      final isSunday = _isSunday(date);
      final isToday = _isToday(date);
      final hasHolidayOrCuti = _hasHolidayOrCuti(date);
      final isSelected =
          _selectedDate.day == day &&
          _selectedDate.month == _focusedDate.month &&
          _selectedDate.year == _focusedDate.year;

      days.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              if (events.isNotEmpty) _showEventDialog(date, events);
            },
            child: Container(
              height: 56,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFF3B82F6)
                    : isSelected
                    ? const Color(0xFF3B82F6).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: const Color(0xFF3B82F6), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? Colors.white
                          : (isSunday || hasHolidayOrCuti)
                          ? Colors.red
                          : const Color(0xFF1F2937),
                    ),
                  ),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isToday ? Colors.white : events.first.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (events.length > 1) ...[
                          const SizedBox(width: 2),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.white70
                                  : events[1].color.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      if ((firstWeekday + day) % 7 == 0 || day == lastDayOfMonth.day) {
        // Padding sisa akhir minggu
        if (day == lastDayOfMonth.day) {
          final remaining = 7 - days.length;
          for (int i = 0; i < remaining; i++) {
            days.add(const Expanded(child: SizedBox()));
          }
        }
        weeks.add(Row(children: List.from(days)));
        days.clear();
      }
    }

    return weeks;
  }

  Widget _buildEventsSection() {
    final today = DateTime.now();
    // "Hari Ini" hanya ditampilkan kalau sedang melihat bulan yang sama
    final isCurrentMonth =
        _focusedDate.year == today.year && _focusedDate.month == today.month;
    final todayEvents = isCurrentMonth
        ? _getEventsForDay(today)
        : <CalendarEvent>[];

    // Filter event untuk bulan yang sedang dilihat
    final thisMonthEvents = <DateTime, List<CalendarEvent>>{};
    for (final entry in _events.entries) {
      final date = entry.key;
      if (date.year == _focusedDate.year && date.month == _focusedDate.month) {
        thisMonthEvents[date] = entry.value;
      }
    }

    // Sort by tanggal
    final sortedEntries = thisMonthEvents.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Event & Hari Penting',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1F2937),
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Text(
              '${sortedEntries.length} event',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Hari ini
        if (todayEvents.isNotEmpty) ...[
          _buildTodayEventsCard(todayEvents),
          const SizedBox(height: 16),
        ],

        // Event bulan ini
        if (sortedEntries.isNotEmpty)
          ...sortedEntries.map(
            (entry) => _buildEventCard(entry.key, entry.value),
          )
        else
          _buildEmptyEvents(),
      ],
    );
  }

  Widget _buildTodayEventsCard(List<CalendarEvent> todayEvents) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hari Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 8),
          ...todayEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(event.typeIcon, size: 16, color: event.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  _buildEventBadge(event),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DateTime date, List<CalendarEvent> events) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: events.first.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: events.first.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    events.first.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        events.first.typeIcon,
                        size: 13,
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        events.first.typeDescription,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day} ${_monthNames[date.month - 1]} ${date.year}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  if (events.length > 1)
                    Text(
                      '+${events.length - 1} event lainnya',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            if (_isSunday(date) ||
                events.any((e) => e.isHoliday || e.isCutiBersama))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: events.any((e) => e.isCutiBersama)
                      ? Colors.red.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  events.any((e) => e.isCutiBersama) ? 'Cuti' : 'Libur',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: events.any((e) => e.isCutiBersama)
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEvents() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 60, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              'Tidak ada event bulan ini',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventBadge(CalendarEvent event) {
    if (event.isCutiBersama) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Cuti',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      );
    }
    if (event.isHoliday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Libur',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showEventDialog(DateTime date, List<CalendarEvent> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day} ${_monthNames[date.month - 1]} ${date.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (events.isNotEmpty && events.first.displayDate != null)
              Text(
                events.first.displayDate!,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: events
              .map(
                (event) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(event.typeIcon, size: 18, color: event.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              event.typeDescription,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildEventBadge(event),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Tutup',
              style: TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
