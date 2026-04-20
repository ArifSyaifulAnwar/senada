// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';

import 'package:absensikaryawan/designnya/attendancecardmodel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Ganti dengan URL API kamu
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
    } catch (e) {
      return null;
    }
  }

  Future<List<AttendanceCardModel>> fetchSummaryCards() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Gagal mendapatkan token');
    }

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
    final screenWidth = MediaQuery.of(context).size.width;
    const double baseWidth = 375;
    final double scale = screenWidth / baseWidth;
    final double horizontalPadding = screenWidth * 0.04;
    final double cardSpacing = 12 * scale;

    return FutureBuilder<List<AttendanceCardModel>>(
      future: _futureCards,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Tidak ada data summary"));
        }

        final cards = snapshot.data!;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: List.generate((cards.length / 2).ceil(), (index) {
              final first = cards[index * 2];
              final second = (index * 2 + 1 < cards.length)
                  ? cards[index * 2 + 1]
                  : null;

              return Padding(
                padding: EdgeInsets.only(bottom: cardSpacing),
                child: Row(
                  children: [
                    Expanded(child: _buildCard(context, first, scale)),
                    if (second != null) ...[
                      SizedBox(width: cardSpacing),
                      Expanded(child: _buildCard(context, second, scale)),
                    ] else
                      Expanded(child: Container()),
                  ],
                ),
              );
            }),
          ),
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
      padding: EdgeInsets.all(16 * scale),
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
                  size: 16 * scale,
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  model.title,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text(
            model.mainText,
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            model.subText,
            style: TextStyle(fontSize: 11 * scale, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
