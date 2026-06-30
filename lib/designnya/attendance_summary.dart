// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:absensikaryawan/Services/company_calendar_service.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/time_off_service.dart';
import 'package:absensikaryawan/designnya/attendancecardmodel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiUrl = '$baseURL/api/asn/file/summary/all/data';

class AttendanceSummary extends StatefulWidget {
  const AttendanceSummary({super.key});

  @override
  State<AttendanceSummary> createState() => _AttendanceSummaryState();
}

class _AttendanceSummaryState extends State<AttendanceSummary>
    with WidgetsBindingObserver {
  List<AttendanceCardModel> _cards = [];
  bool _isLoading = true;
  String? _error;

  // Tanggal terakhir fetch — deteksi pergantian hari/periode
  DateTime _lastFetchDate = DateTime(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final today = DateTime.now();
      // Refresh jika hari sudah berganti → mungkin periode baru dimulai
      if (today.year != _lastFetchDate.year ||
          today.month != _lastFetchDate.month ||
          today.day != _lastFetchDate.day) {
        _fetchData();
      }
    }
  }

  static Future<String?> _getToken() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('access_token') && data['access_token'] != null) {
          return data['access_token'];
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Gagal mendapatkan token');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) throw Exception('Gagal memuat data summary');

      final List<dynamic> raw = json.decode(response.body);
      final cards = raw.map((e) => AttendanceCardModel.fromJson(e)).toList();

      // Override "Total Hari" dengan kalkulasi client-side yang sama
      // dengan yang dipakai di kalender HRD
      await _overrideTotalHari(cards);

      if (mounted) {
        setState(() {
          _cards = cards;
          _isLoading = false;
          _lastFetchDate = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Cari periode aktif, hitung hari kerja = total - weekend - libur(weekday),
  // lalu replace mainText kartu "Total Hari".
  Future<void> _overrideTotalHari(List<AttendanceCardModel> cards) async {
    try {
      // Cari kartu "Total Hari" (by title atau subText)
      final idx = cards.indexWhere(
        (c) =>
            c.title.toLowerCase().contains('total') ||
            c.subText.toLowerCase().contains('hari kerja'),
      );
      if (idx == -1) return;

      // Ambil periode kerja
      final periodsRes = await TimeOffService.getWorkPeriods();
      if (!periodsRes.success || periodsRes.data == null || periodsRes.data!.isEmpty) return;

      // Cari periode yang sedang aktif
      final today = DateTime.now();
      final todayNorm = DateTime(today.year, today.month, today.day);

      final activePeriod = periodsRes.data!.cast<dynamic>().firstWhere(
        (p) {
          final start = DateTime(
            p.tanggalMulai.year, p.tanggalMulai.month, p.tanggalMulai.day,
          );
          final end = DateTime(
            p.tanggalSelesai.year, p.tanggalSelesai.month, p.tanggalSelesai.day,
          );
          return !todayNorm.isBefore(start) && !todayNorm.isAfter(end);
        },
        orElse: () => null,
      );
      if (activePeriod == null) return;

      // Hitung total hari dan weekend dalam periode
      final start = DateTime(
        activePeriod.tanggalMulai.year,
        activePeriod.tanggalMulai.month,
        activePeriod.tanggalMulai.day,
      );
      final end = DateTime(
        activePeriod.tanggalSelesai.year,
        activePeriod.tanggalSelesai.month,
        activePeriod.tanggalSelesai.day,
      );
      final totalDays = end.difference(start).inDays + 1;

      int weekendDays = 0;
      for (int i = 0; i < totalDays; i++) {
        final d = start.add(Duration(days: i));
        if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
          weekendDays++;
        }
      }

      // Ambil event LIBUR tahun ini
      final events = await CompanyCalendarService.getByYear(today.year);

      // Hitung LIBUR yang jatuh di hari kerja dalam periode
      int holidayCount = 0;
      for (final event in events) {
        if (event.tipe != 'LIBUR') continue;
        final d = DateTime(event.tanggal.year, event.tanggal.month, event.tanggal.day);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
            holidayCount++;
          }
        }
      }

      final workDays = totalDays - weekendDays - holidayCount;

      // Update kartu
      cards[idx].mainText = '$workDays';
      cards[idx].subText = 'Hari Kerja';
    } catch (_) {
      // Gagal override — biarkan nilai dari API tetap tampil
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gagal memuat data',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (_cards.isEmpty) {
      return const Center(child: Text('Tidak ada data summary'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth >= 768
            ? (constraints.maxWidth >= 1024 ? 4 : 3)
            : 2;

        final double scale = constraints.maxWidth >= 768
            ? 1.0
            : (constraints.maxWidth / 375.0).clamp(0.8, 1.2);

        final double spacing = 12 * scale;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: constraints.maxWidth >= 768 ? 1.6 : 1.4,
          ),
          itemCount: _cards.length,
          itemBuilder: (context, index) =>
              _buildCard(context, _cards[index], scale),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    AttendanceCardModel model,
    double scale,
  ) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6 * scale),
                decoration: BoxDecoration(
                  color: model.getIconColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Icon(
                  model.getIconData(),
                  color: model.getIconColor(),
                  size: 15 * scale,
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  model.title,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.mainText,
                style: TextStyle(
                  fontSize: 17 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3 * scale),
              Text(
                model.subText,
                style: TextStyle(
                  fontSize: 10 * scale,
                  color: Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
