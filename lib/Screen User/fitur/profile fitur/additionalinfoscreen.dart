// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AdditionalInfoScreen extends StatelessWidget {
  const AdditionalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Contoh data, bisa diganti dengan data dari API/DB
    final Map<String, String> info = {
      "Status Pernikahan": "Menikah",
      "Jumlah Tanggungan": "2 Anak",
      "Nomor KTP": "3174xxxxxxxxxxxx",
      "NPWP": "12.345.678.9-012.345",
      "Alamat Domisili": "Jl. Melati No. 123, Jakarta Selatan",
      "Kontak Darurat": "0812-3456-7890 (Istri)",
      "Hobi": "Futsal, Membaca",
      "Keahlian": "Flutter, Laravel, Public Speaking",
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Informasi Tambahan',
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
                      Icons.info_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Data Lainnya',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // List Informasi Tambahan
            ...info.entries.map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: _iconForLabel(e.key),
                  title: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(e.value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper untuk memilih icon sesuai label
  static Icon _iconForLabel(String label) {
    switch (label) {
      case "Status Pernikahan":
        return const Icon(Icons.favorite, color: Colors.pink);
      case "Jumlah Tanggungan":
        return const Icon(Icons.family_restroom, color: Colors.orange);
      case "Nomor KTP":
        return const Icon(Icons.credit_card, color: Colors.blue);
      case "NPWP":
        return const Icon(Icons.receipt_long, color: Colors.green);
      case "Alamat Domisili":
        return const Icon(Icons.home, color: Colors.indigo);
      case "Kontak Darurat":
        return const Icon(Icons.phone_in_talk, color: Colors.red);
      case "Hobi":
        return const Icon(Icons.sports_soccer, color: Colors.teal);
      case "Keahlian":
        return const Icon(Icons.star, color: Colors.amber);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }
}
