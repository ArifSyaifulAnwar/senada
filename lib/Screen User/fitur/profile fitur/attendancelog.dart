// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Model untuk Attendance
class AttendanceRecord {
  final String id;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? breakStart;
  final DateTime? breakEnd;
  final String status;
  final String location;
  final double? workingHours;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.breakStart,
    this.breakEnd,
    required this.status,
    required this.location,
    this.workingHours,
    this.notes,
  });

  String get formattedDate => DateFormat('dd MMM yyyy').format(date);
  String get formattedCheckIn =>
      checkIn != null ? DateFormat('HH:mm').format(checkIn!) : '-';
  String get formattedCheckOut =>
      checkOut != null ? DateFormat('HH:mm').format(checkOut!) : '-';
  String get formattedBreakStart =>
      breakStart != null ? DateFormat('HH:mm').format(breakStart!) : '-';
  String get formattedBreakEnd =>
      breakEnd != null ? DateFormat('HH:mm').format(breakEnd!) : '-';

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Colors.green;
      case 'terlambat':
        return Colors.orange;
      case 'tidak hadir':
        return Colors.red;
      case 'izin':
        return Colors.blue;
      case 'sakit':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Model untuk Shift
class ShiftRecord {
  final String id;
  final String shiftName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String location;
  final String status;
  final String? description;

  ShiftRecord({
    required this.id,
    required this.shiftName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.status,
    this.description,
  });

  String get formattedDate => DateFormat('dd MMM yyyy').format(date);
  String get formattedStartTime =>
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  String get formattedEndTime =>
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'aktif':
        return Colors.green;
      case 'selesai':
        return Colors.blue;
      case 'dibatalkan':
        return Colors.red;
      case 'menunggu':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class AttendanceLogScreen extends StatefulWidget {
  final int initialTabIndex;

  const AttendanceLogScreen({super.key, this.initialTabIndex = 0});

  @override
  _AttendanceLogScreenState createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  int _selectedTabIndex = 0;
  final List<String> _tabs = ["Attendance", "Shift"];

  bool _isLoading = true;
  List<AttendanceRecord> _attendanceRecords = [];
  List<ShiftRecord> _shiftRecords = [];

  // Filter options
  String _selectedMonth = '';
  String _selectedStatus = 'Semua';
  final List<String> _attendanceStatuses = [
    'Semua',
    'Hadir',
    'Terlambat',
    'Tidak Hadir',
    'Izin',
    'Sakit',
  ];
  final List<String> _shiftStatuses = [
    'Semua',
    'Aktif',
    'Selesai',
    'Dibatalkan',
    'Menunggu',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();

    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // Generate dummy data
    _generateDummyAttendanceData();
    _generateDummyShiftData();

    setState(() => _isLoading = false);
  }

  void _generateDummyAttendanceData() {
    _attendanceRecords = [
      AttendanceRecord(
        id: '1',
        date: DateTime.now().subtract(const Duration(days: 1)),
        checkIn: DateTime.now().subtract(
          const Duration(days: 1, hours: 16, minutes: 30),
        ),
        checkOut: DateTime.now().subtract(
          const Duration(days: 1, hours: 8, minutes: 15),
        ),
        breakStart: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
        breakEnd: DateTime.now().subtract(const Duration(days: 1, hours: 11)),
        status: 'Hadir',
        location: 'Kantor Pusat',
        workingHours: 8.25,
        notes: 'Hari kerja normal',
      ),
      AttendanceRecord(
        id: '2',
        date: DateTime.now().subtract(const Duration(days: 2)),
        checkIn: DateTime.now().subtract(
          const Duration(days: 2, hours: 16, minutes: 45),
        ),
        checkOut: DateTime.now().subtract(const Duration(days: 2, hours: 8)),
        breakStart: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
        breakEnd: DateTime.now().subtract(const Duration(days: 2, hours: 11)),
        status: 'Terlambat',
        location: 'Kantor Pusat',
        workingHours: 8.0,
        notes: 'Terlambat 15 menit',
      ),
      AttendanceRecord(
        id: '3',
        date: DateTime.now().subtract(const Duration(days: 3)),
        checkIn: null,
        checkOut: null,
        status: 'Izin',
        location: '-',
        notes: 'Izin keperluan keluarga',
      ),
      AttendanceRecord(
        id: '4',
        date: DateTime.now().subtract(const Duration(days: 4)),
        checkIn: DateTime.now().subtract(
          const Duration(days: 4, hours: 16, minutes: 30),
        ),
        checkOut: DateTime.now().subtract(
          const Duration(days: 4, hours: 8, minutes: 30),
        ),
        breakStart: DateTime.now().subtract(const Duration(days: 4, hours: 12)),
        breakEnd: DateTime.now().subtract(const Duration(days: 4, hours: 11)),
        status: 'Hadir',
        location: 'Work From Home',
        workingHours: 8.0,
        notes: 'WFH - Meeting online',
      ),
      AttendanceRecord(
        id: '5',
        date: DateTime.now().subtract(const Duration(days: 5)),
        checkIn: null,
        checkOut: null,
        status: 'Sakit',
        location: '-',
        notes: 'Sakit demam',
      ),
    ];
  }

  void _generateDummyShiftData() {
    _shiftRecords = [
      ShiftRecord(
        id: '1',
        shiftName: 'Shift Pagi',
        date: DateTime.now().add(const Duration(days: 1)),
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0),
        location: 'Kantor Pusat',
        status: 'Menunggu',
        description: 'Shift regular pagi hari',
      ),
      ShiftRecord(
        id: '2',
        shiftName: 'Shift Pagi',
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0),
        location: 'Kantor Pusat',
        status: 'Aktif',
        description: 'Shift sedang berlangsung',
      ),
      ShiftRecord(
        id: '3',
        shiftName: 'Shift Siang',
        date: DateTime.now().subtract(const Duration(days: 1)),
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 22, minute: 0),
        location: 'Kantor Cabang',
        status: 'Selesai',
        description: 'Shift siang selesai',
      ),
      ShiftRecord(
        id: '4',
        shiftName: 'Shift Malam',
        date: DateTime.now().subtract(const Duration(days: 2)),
        startTime: const TimeOfDay(hour: 22, minute: 0),
        endTime: const TimeOfDay(hour: 6, minute: 0),
        location: 'Kantor Pusat',
        status: 'Selesai',
        description: 'Shift malam weekend',
      ),
      ShiftRecord(
        id: '5',
        shiftName: 'Shift Pagi',
        date: DateTime.now().add(const Duration(days: 3)),
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0),
        location: 'Work From Home',
        status: 'Menunggu',
        description: 'WFH shift pagi',
      ),
    ];
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedTabIndex = index;
              _selectedStatus = index == 0 ? 'Semua' : 'Semua';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: const Color(0xFF007AFF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMonth,
                          isExpanded: true,
                          items: _generateMonthOptions(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value!;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          items:
                              (_selectedTabIndex == 0
                                      ? _attendanceStatuses
                                      : _shiftStatuses)
                                  .map(
                                    (status) => DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _generateMonthOptions() {
    List<DropdownMenuItem<String>> items = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 12; i++) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String value = DateFormat('yyyy-MM').format(month);
      String label = DateFormat('MMMM yyyy', 'id_ID').format(month);

      items.add(DropdownMenuItem<String>(value: value, child: Text(label)));
    }

    return items;
  }

  Widget _buildAttendanceTab() {
    List<AttendanceRecord> filteredRecords = _attendanceRecords.where((record) {
      bool matchesMonth =
          DateFormat('yyyy-MM').format(record.date) == _selectedMonth;
      bool matchesStatus =
          _selectedStatus == 'Semua' || record.status == _selectedStatus;
      return matchesMonth && matchesStatus;
    }).toList();

    return Column(
      children: [
        _buildFilterSection(),

        if (filteredRecords.isEmpty)
          _buildEmptyState(
            'Tidak ada data absensi',
            'untuk periode yang dipilih',
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredRecords.length,
              itemBuilder: (context, index) {
                return _buildAttendanceCard(filteredRecords[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildShiftTab() {
    List<ShiftRecord> filteredRecords = _shiftRecords.where((record) {
      bool matchesMonth =
          DateFormat('yyyy-MM').format(record.date) == _selectedMonth;
      bool matchesStatus =
          _selectedStatus == 'Semua' || record.status == _selectedStatus;
      return matchesMonth && matchesStatus;
    }).toList();

    return Column(
      children: [
        _buildFilterSection(),

        if (filteredRecords.isEmpty)
          _buildEmptyState('Tidak ada data shift', 'untuk periode yang dipilih')
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredRecords.length,
              itemBuilder: (context, index) {
                return _buildShiftCard(filteredRecords[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _showAttendanceDetail(record),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record.formattedDate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: record.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: record.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.login,
                      'Masuk',
                      record.formattedCheckIn,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.logout,
                      'Keluar',
                      record.formattedCheckOut,
                      Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.location_on,
                      'Lokasi',
                      record.location,
                      Colors.blue,
                    ),
                  ),
                  if (record.workingHours != null)
                    Expanded(
                      child: _buildInfoItem(
                        Icons.schedule,
                        'Jam Kerja',
                        '${record.workingHours!.toStringAsFixed(1)} jam',
                        Colors.orange,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftCard(ShiftRecord record) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _showShiftDetail(record),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.shiftName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
                      color: record.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: record.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.access_time,
                      'Mulai',
                      record.formattedStartTime,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.access_time_filled,
                      'Selesai',
                      record.formattedEndTime,
                      Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              _buildInfoItem(
                Icons.location_on,
                'Lokasi',
                record.location,
                Colors.blue,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value,
    Color color, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          if (isFullWidth)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedTabIndex == 0 ? Icons.event_busy : Icons.schedule_send,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttendanceDetail(AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detail Absensi',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: record.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: record.statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),

              _buildDetailRow('Tanggal', record.formattedDate),
              _buildDetailRow('Waktu Masuk', record.formattedCheckIn),
              _buildDetailRow('Waktu Keluar', record.formattedCheckOut),
              _buildDetailRow('Istirahat Mulai', record.formattedBreakStart),
              _buildDetailRow('Istirahat Selesai', record.formattedBreakEnd),
              _buildDetailRow('Lokasi', record.location),

              if (record.workingHours != null)
                _buildDetailRow(
                  'Total Jam Kerja',
                  '${record.workingHours!.toStringAsFixed(2)} jam',
                ),

              if (record.notes != null)
                _buildDetailRow('Catatan', record.notes!),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showShiftDetail(ShiftRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detail Shift',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: record.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: record.statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),

              _buildDetailRow('Nama Shift', record.shiftName),
              _buildDetailRow('Tanggal', record.formattedDate),
              _buildDetailRow('Waktu Mulai', record.formattedStartTime),
              _buildDetailRow('Waktu Selesai', record.formattedEndTime),
              _buildDetailRow('Lokasi', record.location),

              if (record.description != null)
                _buildDetailRow('Deskripsi', record.description!),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildAttendanceTab();
      case 1:
        return _buildShiftTab();
      default:
        return _buildAttendanceTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Memuat data absensi...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Attendance Log',
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with shadow
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(_tabs[0], 0),
                      _buildTabButton(_tabs[1], 1),
                    ],
                  ),
                ),
              ),
            ),

            // Content Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
