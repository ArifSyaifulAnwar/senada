// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import '../../../Services/calendar_event_service.dart';
import '../../../Services/company_calendar_service.dart';
import '../../../models/calendermodel.dart';

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

  // ── Load events: libur nasional + company calendar ────────────────
  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      // 1. Libur nasional
      var events = await CalendarEventService.getDayoffEvents(
        _focusedDate.year,
      );
      // 2. Merge dengan company calendar (HRD custom)
      events = await CalendarEventService.mergeWithCompanyCalendar(
        events,
        _focusedDate.year,
      );
      if (mounted) setState(() => _events = events);
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _loadEventsForYear(int year) async {
    var events = await CalendarEventService.getDayoffEvents(year);
    events = await CalendarEventService.mergeWithCompanyCalendar(events, year);
    if (mounted) setState(() => _events.addAll(events));
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  bool _isSaturday(DateTime date) => date.weekday == DateTime.saturday;
  bool _isSunday(DateTime date) => date.weekday == DateTime.sunday;
  bool _isWeekend(DateTime date) => _isSaturday(date) || _isSunday(date);

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  // Merah: weekend + libur nasional + libur company
  bool _isHariMerah(DateTime date) {
    if (_isWeekend(date)) return true;
    final events = _getEventsForDay(date);
    return events.any((e) => e.isHoliday || e.isCutiBersama);
  }

  // WFH: dari company calendar
  bool _isWfh(DateTime date) {
    final events = _getEventsForDay(date);
    return events.any((e) => e.isWfh);
  }

  // Label keterangan hari
  String? _getDayLabel(DateTime date) {
    if (_isSunday(date)) return 'Minggu';
    if (_isSaturday(date)) return 'Sabtu';
    final events = _getEventsForDay(date);
    final libur = events.where((e) => e.isHoliday || e.isCutiBersama).toList();
    if (libur.isNotEmpty) return libur.first.title;
    final wfh = events.where((e) => e.isWfh).toList();
    if (wfh.isNotEmpty) return 'WFH';
    return null;
  }

  void _previousMonth() {
    final newDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
    setState(() => _focusedDate = newDate);
    if (newDate.year != _focusedDate.year) _loadEventsForYear(newDate.year);
  }

  void _nextMonth() {
    final newDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
    setState(() => _focusedDate = newDate);
    if (newDate.year != _focusedDate.year) _loadEventsForYear(newDate.year);
  }

  void _goToToday() => setState(() {
    _focusedDate = DateTime.now();
    _selectedDate = DateTime.now();
  });

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
              CompanyCalendarService.clearCache();
              _loadEvents();
            },
            tooltip: 'Refresh',
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
            tooltip: 'Hari Ini',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarHeader(),
            const SizedBox(height: 16),
            _buildLegend(),
            const SizedBox(height: 16),
            _buildCalendarGrid(),
            const SizedBox(height: 24),
            _buildEventsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                const SizedBox(height: 16),
                _buildLegend(),
                const SizedBox(height: 16),
                _buildCalendarGrid(),
              ],
            ),
          ),
        ),
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

  // ── Legend ────────────────────────────────────────────────────────
  Widget _buildLegend() {
    final items = [
      {'color': const Color(0xFF3B82F6), 'label': 'Hari ini'},
      {'color': Colors.red, 'label': 'Libur / Merah'},
      {'color': Colors.orange, 'label': 'Cuti Bersama'},
      {'color': const Color(0xFF10B981), 'label': 'WFH'},
      {'color': Colors.grey[300]!, 'label': 'Sabtu'},
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: items
          .map(
            (item) => Row(
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
                const SizedBox(width: 5),
                Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  // ── Calendar Header ───────────────────────────────────────────────
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

  // ── Calendar Grid ─────────────────────────────────────────────────
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
            // Header hari
            Row(
              children: _dayNames.map((dayName) {
                final isMin = dayName == 'Min';
                final isSab = dayName == 'Sab';
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      dayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isMin
                            ? Colors.red
                            : isSab
                            ? Colors.red[300]
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
      final isToday = _isToday(date);
      final isHariMerah = _isHariMerah(date);
      final isWfh = _isWfh(date);
      final isSaturday = date.weekday == DateTime.saturday;
      final isSelected =
          _selectedDate.day == day &&
          _selectedDate.month == _focusedDate.month &&
          _selectedDate.year == _focusedDate.year;

      // Warna teks tanggal
      Color dateColor;
      if (isToday) {
        dateColor = Colors.white;
      } else if (isHariMerah) {
        dateColor = Colors.red;
      } else if (isSaturday) {
        dateColor = Colors.red[300]!;
      } else if (isWfh) {
        dateColor = const Color(0xFF059669);
      } else {
        dateColor = const Color(0xFF1F2937);
      }

      // Warna background tanggal
      Color? bgColor;
      if (isToday) {
        bgColor = const Color(0xFF3B82F6);
      } else if (isWfh && !isHariMerah) {
        bgColor = const Color(0xFF10B981).withOpacity(0.12);
      } else if (isSaturday && !isHariMerah) {
        bgColor = Colors.grey[100];
      } else if (isSelected) {
        bgColor = const Color(0xFF3B82F6).withOpacity(0.1);
      } else {
        bgColor = Colors.transparent;
      }

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
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: const Color(0xFF3B82F6), width: 2)
                    : isWfh && !isHariMerah
                    ? Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        width: 1,
                      )
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
                      color: dateColor,
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

  // ── Events Section ────────────────────────────────────────────────
  Widget _buildEventsSection() {
    final today = DateTime.now();
    final isCurrentMonth =
        _focusedDate.year == today.year && _focusedDate.month == today.month;
    final todayEvents = isCurrentMonth
        ? _getEventsForDay(today)
        : <CalendarEvent>[];

    final thisMonthEvents = <DateTime, List<CalendarEvent>>{};
    for (final entry in _events.entries) {
      final date = entry.key;
      if (date.year == _focusedDate.year && date.month == _focusedDate.month) {
        thisMonthEvents[date] = entry.value;
      }
    }

    final sortedEntries = thisMonthEvents.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        if (todayEvents.isNotEmpty) ...[
          _buildTodayEventsCard(todayEvents),
          const SizedBox(height: 16),
        ],

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
    // Prioritas tampilan badge: libur company > cuti bersama > libur nasional > WFH
    final hasCompanyLibur = events.any((e) => e.type == 'company_libur');
    final hasCuti = events.any((e) => e.isCutiBersama);
    final hasLibur = events.any((e) => e.isHoliday);
    final hasWfh = events.any((e) => e.isWfh);

    Widget? badge;
    if (hasCompanyLibur) {
      badge = _badge('Libur', Colors.red[700]!);
    } else if (hasCuti) {
      badge = _badge('Cuti', Colors.red);
    } else if (hasLibur) {
      badge = _badge('Libur', Colors.orange);
    } else if (hasWfh) {
      badge = _badge('WFH', const Color(0xFF10B981));
    }

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
            if (badge != null) badge,
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _buildEmptyEvents() => Container(
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

  Widget _buildEventBadge(CalendarEvent event) {
    if (event.type == 'company_libur') return _badge('Libur', Colors.red[700]!);
    if (event.isCutiBersama) return _badge('Cuti', Colors.red);
    if (event.isHoliday) return _badge('Libur', Colors.orange);
    if (event.isWfh) return _badge('WFH', const Color(0xFF10B981));
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
            // Label hari (Minggu / Sabtu / nama libur / WFH)
            if (_getDayLabel(date) != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isHariMerah(date)
                      ? Colors.red.withOpacity(0.1)
                      : const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getDayLabel(date)!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isHariMerah(date)
                        ? Colors.red
                        : const Color(0xFF10B981),
                  ),
                ),
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
