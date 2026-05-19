// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/designnya/attendancecardmodel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiUrl = '$baseURL/api/asn/file/summary/all/data';

class AttendanceSummary extends StatefulWidget {
  const AttendanceSummary({super.key});

  @override
  State<AttendanceSummary> createState() => _AttendanceSummaryState();
}

class _AttendanceSummaryState extends State<AttendanceSummary> {
  late Future<List<AttendanceCardModel>> _futureCards;

  @override
  void initState() {
    super.initState();
    _futureCards = fetchSummaryCards();
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

  Future<List<AttendanceCardModel>> fetchSummaryCards() async {
    final token = await _getToken();
    if (token == null) throw Exception('Gagal mendapatkan token');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => AttendanceCardModel.fromJson(e)).toList();
    } else {
      throw Exception('Gagal memuat data summary');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AttendanceCardModel>>(
      future: _futureCards,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada data summary'));
        }

        final cards = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Tentukan jumlah kolom berdasarkan lebar
            final int crossAxisCount = constraints.maxWidth >= 768
                ? (constraints.maxWidth >= 1024 ? 4 : 3)
                : 2;

            // Scale hanya dipakai di mobile untuk menyesuaikan ukuran font/padding
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
                // Ratio lebih tinggi di web (konten tidak terlalu besar)
                childAspectRatio: constraints.maxWidth >= 768 ? 1.6 : 1.4,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) =>
                  _buildCard(context, cards[index], scale),
            );
          },
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
                style: TextStyle(fontSize: 10 * scale, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
