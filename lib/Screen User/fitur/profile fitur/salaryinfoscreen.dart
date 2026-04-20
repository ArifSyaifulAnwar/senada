// ignore_for_file: deprecated_member_use

import 'package:absensikaryawan/Services/salaryinfo.dart';
import 'package:flutter/material.dart';

class SalaryScreen extends StatelessWidget {
  SalaryScreen({super.key});

  final List<SalaryInfo> salaryHistory = [
    SalaryInfo(
      bulan: "Juni 2024",
      gajiPokok: 7500000,
      tunjangan: 1250000,
      potongan: 500000,
      totalDiterima: 8250000,
    ),
    SalaryInfo(
      bulan: "Mei 2024",
      gajiPokok: 7500000,
      tunjangan: 1200000,
      potongan: 400000,
      totalDiterima: 8300000,
    ),
    SalaryInfo(
      bulan: "April 2024",
      gajiPokok: 7500000,
      tunjangan: 1200000,
      potongan: 350000,
      totalDiterima: 8350000,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final latest = salaryHistory.first;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Informasi Gaji',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gaji Terakhir',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latest.bulan,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Rp ${latest.totalDiterima.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Total diterima",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Rincian Gaji Terakhir
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Rincian Gaji Bulan Ini",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _salaryDetailRow(
                      "Gaji Pokok",
                      latest.gajiPokok,
                      Colors.blue,
                    ),
                    _salaryDetailRow(
                      "Tunjangan",
                      latest.tunjangan,
                      Colors.green,
                    ),
                    _salaryDetailRow("Potongan", latest.potongan, Colors.red),
                    const Divider(height: 32),
                    _salaryDetailRow(
                      "Total Diterima",
                      latest.totalDiterima,
                      Colors.indigo,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),

            // Riwayat Gaji
            const Text(
              "Riwayat Gaji",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...salaryHistory.map(
              (s) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.calendar_month, color: Colors.blue[700]),
                  title: Text(
                    s.bulan,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Total diterima: Rp ${s.totalDiterima.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Bisa tampilkan detail gaji bulan tsb
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text("Rincian Gaji ${s.bulan}"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _salaryDetailRow(
                              "Gaji Pokok",
                              s.gajiPokok,
                              Colors.blue,
                            ),
                            _salaryDetailRow(
                              "Tunjangan",
                              s.tunjangan,
                              Colors.green,
                            ),
                            _salaryDetailRow(
                              "Potongan",
                              s.potongan,
                              Colors.red,
                            ),
                            const Divider(height: 24),
                            _salaryDetailRow(
                              "Total Diterima",
                              s.totalDiterima,
                              Colors.indigo,
                              bold: true,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Tutup"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _salaryDetailRow(
    String label,
    int value,
    Color color, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Text(
            "${label == "Potongan" ? "- " : ""}Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}",
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
