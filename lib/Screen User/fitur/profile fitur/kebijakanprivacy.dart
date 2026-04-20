// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';

class HalamanKebijakanPrivasi extends StatefulWidget {
  const HalamanKebijakanPrivasi({super.key});

  @override
  _HalamanKebijakanPrivasiState createState() =>
      _HalamanKebijakanPrivasiState();
}

class PrivacySection {
  final String id;
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  PrivacySection({
    required this.id,
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });
}

class _HalamanKebijakanPrivasiState extends State<HalamanKebijakanPrivasi> {
  final ScrollController _scrollController = ScrollController();
  String selectedSection = '';
  bool showTableOfContents = false;

  // Data kebijakan privasi
  final List<PrivacySection> privacySections = [
    PrivacySection(
      id: 'pendahuluan',
      title: 'Pendahuluan',
      content:
          '''PT. Teknologi Nusantara ("kami", "perusahaan") berkomitmen untuk melindungi dan menghormati privasi Anda. Kebijakan Privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi pribadi Anda ketika menggunakan aplikasi manajemen karyawan kami.

Dengan menggunakan layanan kami, Anda setuju dengan pengumpulan dan penggunaan informasi sesuai dengan kebijakan ini. Jika Anda tidak setuju dengan kebijakan ini, mohon untuk tidak menggunakan layanan kami.

Kebijakan ini berlaku untuk semua pengguna aplikasi, termasuk karyawan, admin, dan manajemen perusahaan.''',
      icon: Icons.info_outline,
      color: Colors.blue,
    ),
    PrivacySection(
      id: 'informasi_dikumpulkan',
      title: 'Informasi yang Kami Kumpulkan',
      content:
          '''Kami mengumpulkan beberapa jenis informasi untuk menyediakan dan meningkatkan layanan kepada Anda:

**1. Informasi Personal:**
• Nama lengkap
• Alamat email
• Nomor telepon
• Alamat rumah
• Tanggal lahir
• Nomor identitas (KTP/Passport)
• Foto profil

**2. Informasi Pekerjaan:**
• Jabatan dan departemen
• Nomor karyawan
• Tanggal bergabung
• Riwayat pekerjaan
• Gaji dan tunjangan
• Evaluasi kinerja

**3. Data Absensi:**
• Waktu masuk dan keluar
• Lokasi check-in
• Foto saat absensi
• Riwayat kehadiran
• Data cuti dan izin

**4. Informasi Teknis:**
• Alamat IP
• Jenis perangkat
• Sistem operasi
• Data lokasi (dengan persetujuan)
• Log aktivitas aplikasi''',
      icon: Icons.data_usage,
      color: Colors.orange,
    ),
    PrivacySection(
      id: 'penggunaan_informasi',
      title: 'Bagaimana Kami Menggunakan Informasi',
      content: '''Kami menggunakan informasi yang dikumpulkan untuk:

**1. Operasional Layanan:**
• Mengelola akun pengguna
• Memproses absensi dan kehadiran
• Menghitung gaji dan tunjangan
• Mengirim notifikasi penting
• Menyediakan laporan kinerja

**2. Komunikasi:**
• Mengirim pemberitahuan sistem
• Memberikan dukungan teknis
• Menginformasikan update aplikasi
• Komunikasi terkait pekerjaan

**3. Keamanan:**
• Mencegah penyalahgunaan akun
• Melindungi dari aktivitas mencurigakan
• Menjaga kerahasiaan data
• Audit dan monitoring sistem

**4. Pengembangan:**
• Meningkatkan fitur aplikasi
• Analisis penggunaan
• Penelitian dan pengembangan
• Optimisasi performa sistem''',
      icon: Icons.settings_applications,
      color: Colors.green,
    ),
    PrivacySection(
      id: 'berbagi_informasi',
      title: 'Berbagi Informasi',
      content:
          '''Kami tidak akan menjual, memperdagangkan, atau mentransfer informasi pribadi Anda kepada pihak ketiga tanpa persetujuan Anda, kecuali dalam situasi berikut:

**1. Dengan Persetujuan Anda:**
• Ketika Anda memberikan izin eksplisit
• Untuk integrasi dengan sistem pihak ketiga
• Keperluan pelatihan atau sertifikasi

**2. Keperluan Hukum:**
• Untuk mematuhi perintah pengadilan
• Memenuhi kewajiban hukum
• Melindungi hak legal perusahaan
• Investigasi tindak pidana

**3. Penyedia Layanan:**
• Cloud storage provider
• Layanan pembayaran
• Sistem backup
• Security service provider

**4. Merger atau Akuisisi:**
• Transfer bisnis
• Reorganisasi perusahaan
• Dengan perlindungan data yang sama

Semua pihak ketiga wajib menandatangani perjanjian kerahasiaan dan mematuhi standar perlindungan data yang ketat.''',
      icon: Icons.share,
      color: Colors.purple,
    ),
    PrivacySection(
      id: 'keamanan_data',
      title: 'Keamanan Data',
      content:
          '''Kami menerapkan berbagai langkah keamanan untuk melindungi informasi pribadi Anda:

**1. Enkripsi:**
• Enkripsi data end-to-end
• SSL/TLS untuk transmisi data
• Enkripsi database
• Hashing password yang kuat

**2. Kontrol Akses:**
• Autentikasi multi-faktor
• Role-based access control
• Regular access review
• Principle of least privilege

**3. Infrastruktur:**
• Server yang aman dan terpantau
• Firewall dan intrusion detection
• Regular security updates
• Disaster recovery plan

**4. Prosedur:**
• Security training untuk karyawan
• Regular security audits
• Incident response plan
• Data breach notification

**5. Sertifikasi:**
• ISO 27001 compliance
• SOC 2 Type II
• GDPR compliance
• Regular penetration testing

Meskipun kami berusaha maksimal, tidak ada sistem yang 100% aman. Kami akan segera memberitahu jika terjadi pelanggaran data.''',
      icon: Icons.security,
      color: Colors.red,
    ),
    PrivacySection(
      id: 'hak_pengguna',
      title: 'Hak-Hak Pengguna',
      content:
          '''Sebagai pengguna, Anda memiliki hak-hak berikut terkait data pribadi Anda:

**1. Hak Akses:**
• Melihat data pribadi yang kami simpan
• Mendapatkan salinan data Anda
• Informasi tentang penggunaan data
• Riwayat akses data

**2. Hak Koreksi:**
• Memperbarui informasi yang tidak akurat
• Melengkapi data yang kurang
• Mengubah preferensi privasi
• Update informasi kontak

**3. Hak Penghapusan:**
• Menghapus akun dan data (right to be forgotten)
• Menghapus data yang tidak diperlukan
• Penarikan persetujuan
• Pembatasan pemrosesan

**4. Hak Portabilitas:**
• Ekspor data dalam format standar
• Transfer data ke sistem lain
• Backup data pribadi
• Migrasi akun

**5. Hak Keberatan:**
• Menolak pemrosesan tertentu
• Opt-out dari komunikasi marketing
• Pembatasan penggunaan data
• Banding atas keputusan otomatis

Untuk menggunakan hak-hak ini, silakan hubungi tim Privacy Officer kami melalui email: privacy@company.com''',
      icon: Icons.account_balance,
      color: Colors.cyan,
    ),
    PrivacySection(
      id: 'cookies',
      title: 'Cookies dan Teknologi Pelacakan',
      content:
          '''Aplikasi kami menggunakan cookies dan teknologi serupa untuk meningkatkan pengalaman pengguna:

**1. Jenis Cookies:**
• Essential cookies (diperlukan untuk fungsi dasar)
• Performance cookies (analisis penggunaan)
• Functional cookies (preferensi pengguna)
• Targeting cookies (personalisasi konten)

**2. Tujuan Penggunaan:**
• Menjaga sesi login
• Mengingat preferensi
• Analisis performa aplikasi
• Personalisasi pengalaman

**3. Kontrol Cookies:**
• Pengaturan cookies di aplikasi
• Browser settings
• Opt-out mechanisms
• Cookie consent management

**4. Third-Party Cookies:**
• Google Analytics (dengan anonimisasi IP)
• Firebase Analytics
• Crash reporting tools
• Performance monitoring

**5. Teknologi Lain:**
• Local storage
• Session storage
• Device fingerprinting (minimal)
• Push notification tokens

Anda dapat mengonfigurasi pengaturan cookies melalui menu Settings di aplikasi atau melalui browser Anda.''',
      icon: Icons.cookie,
      color: Colors.brown,
    ),
    PrivacySection(
      id: 'retensi_data',
      title: 'Penyimpanan dan Retensi Data',
      content:
          '''Kami menyimpan data Anda hanya selama diperlukan untuk tujuan yang dijelaskan dalam kebijakan ini:

**1. Periode Retensi:**
• Data karyawan aktif: Selama masa kerja + 7 tahun
• Data absensi: 5 tahun setelah akhir masa kerja
• Data gaji: 10 tahun (sesuai regulasi)
• Log sistem: 2 tahun
• Data komunikasi: 3 tahun

**2. Kriteria Retensi:**
• Keperluan operasional bisnis
• Kewajiban hukum dan regulasi
• Kepentingan audit dan investigasi
• Hak dan kepentingan yang sah

**3. Penghapusan Otomatis:**
• Sistem automated deletion
• Regular data purging
• Secure data destruction
• Audit trail penghapusan

**4. Lokasi Penyimpanan:**
• Server di Indonesia (data center lokal)
• Backup di multiple locations
• Cloud storage dengan enkripsi
• Compliance dengan UU PDP

**5. Data Archiving:**
• Cold storage untuk data lama
• Compressed dan encrypted
• Limited access controls
• Regular integrity checks

Setelah periode retensi berakhir, data akan dihapus secara permanen menggunakan metode yang aman.''',
      icon: Icons.storage,
      color: Colors.indigo,
    ),
    PrivacySection(
      id: 'transfer_internasional',
      title: 'Transfer Data Internasional',
      content:
          '''Dalam situasi tertentu, kami mungkin perlu mentransfer data Anda ke luar negeri:

**1. Kondisi Transfer:**
• Menggunakan cloud service provider global
• Backup dan disaster recovery
• Technical support dari vendor asing
• Group company operations

**2. Negara Tujuan:**
• Singapura (regional data center)
• Amerika Serikat (cloud providers)
• Eropa (software vendors)
• Hong Kong (backup facilities)

**3. Perlindungan Data:**
• Adequacy decision compliance
• Standard Contractual Clauses (SCC)
• Binding Corporate Rules (BCR)
• Certification schemes

**4. Safeguards:**
• Encryption in transit dan at rest
• Access controls dan monitoring
• Regular compliance audits
• Data Processing Agreements

**5. Hak Anda:**
• Informasi tentang transfer
• Salinan safeguards yang digunakan
• Hak untuk keberatan
• Kompensasi jika terjadi pelanggaran

Kami memastikan bahwa semua transfer data internasional mematuhi regulasi yang berlaku dan memberikan tingkat perlindungan yang sama.''',
      icon: Icons.public,
      color: Colors.teal,
    ),
    PrivacySection(
      id: 'perubahan_kebijakan',
      title: 'Perubahan Kebijakan',
      content: '''Kebijakan Privasi ini dapat berubah dari waktu ke waktu:

**1. Alasan Perubahan:**
• Perubahan fitur aplikasi
• Update regulasi dan hukum
• Feedback dari pengguna
• Best practices industry

**2. Proses Pemberitahuan:**
• Notifikasi in-app 30 hari sebelumnya
• Email ke semua pengguna terdaftar
• Pengumuman di website perusahaan
• Highlight perubahan signifikan

**3. Jenis Perubahan:**
• Minor updates (tanpa persetujuan ulang)
• Major changes (perlu persetujuan)
• Emergency updates (security)
• Regulatory compliance

**4. Riwayat Versi:**
• Database semua versi kebijakan
• Tanggal berlaku masing-masing versi
• Summary of changes
• Archive kebijakan lama

**5. Hak Menolak:**
• Withdraw consent untuk perubahan
• Terminate account jika tidak setuju
• Data deletion request
• Grace period untuk migrasi

Tanggal berlaku kebijakan ini: 1 Januari 2024
Versi: 2.1
Last updated: 15 Desember 2023''',
      icon: Icons.update,
      color: Colors.amber,
    ),
    PrivacySection(
      id: 'kontak',
      title: 'Hubungi Kami',
      content:
          '''Jika Anda memiliki pertanyaan tentang Kebijakan Privasi ini, silakan hubungi kami:

**Privacy Officer:**
PT. Teknologi Nusantara
Email: privacy@tekinusa.co.id
Phone: +62 21 1234 5678
WhatsApp: +62 812 3456 7890

**Alamat Kantor:**
Gedung Tech Tower Lantai 15
Jl. Sudirman No. 123
Jakarta Selatan 12345
Indonesia

**Data Protection Officer (DPO):**
Sari Indah Lestari, S.H., M.H.
Email: dpo@tekinusa.co.id
Phone: +62 21 1234 5679

**Tim Legal:**
Email: legal@tekinusa.co.id
Phone: +62 21 1234 5680

**Jam Operasional:**
Senin - Jumat: 08:00 - 17:00 WIB
Sabtu: 08:00 - 12:00 WIB
Minggu & Hari Libur: Tutup

**Response Time:**
• Pertanyaan umum: 1-2 hari kerja
• Data subject requests: 7-14 hari kerja
• Incident reports: 24 jam
• Urgent matters: Same day

Kami berkomitmen untuk merespons semua pertanyaan dan keluhan Anda dengan cepat dan transparan.''',
      icon: Icons.contact_support,
      color: Colors.pink,
    ),
  ];

  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return baseFontSize * scale.clamp(0.85, 1.15);
  }

  double _getResponsivePadding(BuildContext context, double basePadding) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return basePadding * scale.clamp(0.85, 1.1);
  }

  Widget _buildTableOfContents() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: Colors.blue[700]),
              SizedBox(width: 12),
              Text(
                'Daftar Isi',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...privacySections.asMap().entries.map((entry) {
            int index = entry.key;
            PrivacySection section = entry.value;
            return GestureDetector(
              onTap: () {
                _scrollToSection(index);
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: selectedSection == section.id
                      ? Colors.blue[100]
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: section.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(section.icon, size: 16, color: section.color),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '${index + 1}. ${section.title}',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        color: selectedSection == section.id
                            ? Colors.blue[700]
                            : Colors.blue[600],
                        fontWeight: selectedSection == section.id
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSection(PrivacySection section, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: section.color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: section.color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: section.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(section.icon, color: section.color, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${section.title}',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 20),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          color: section.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Section Content
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildFormattedContent(section.content),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedContent(String content) {
    List<String> paragraphs = content.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.startsWith('**') && paragraph.endsWith(':**')) {
          // Bold headers
          return Container(
            margin: EdgeInsets.only(bottom: 12, top: 8),
            child: Text(
              paragraph.replaceAll('**', '').replaceAll(':', ''),
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          );
        } else if (paragraph.startsWith('•')) {
          // Bullet points
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    paragraph.substring(2),
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: const Color(0xFF64748B),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Regular paragraph
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Text(
              paragraph,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  void _scrollToSection(int index) {
    // Implementasi scroll ke section tertentu
    double position = index * 400.0; // Estimasi tinggi per section
    _scrollController.animateTo(
      position,
      duration: Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
    setState(() {
      selectedSection = privacySections[index].id;
    });
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.privacy_tip, color: Colors.white, size: 32),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kebijakan Privasi',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 28),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'PT. Teknologi Nusantara',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 16),
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Terakhir diperbarui: 15 Desember 2023 • Versi 2.1',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.download, 'label': 'Unduh PDF', 'color': Colors.blue},
      {'icon': Icons.share, 'label': 'Bagikan', 'color': Colors.green},
      {'icon': Icons.print, 'label': 'Cetak', 'color': Colors.orange},
      {'icon': Icons.bookmark, 'label': 'Simpan', 'color': Colors.purple},
    ];

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Row(
        children: actions.map((action) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${action['label']} - Fitur akan segera tersedia',
                      ),
                      backgroundColor: action['color'] as Color,
                    ),
                  );
                },
                icon: Icon(
                  action['icon'] as IconData,
                  size: 18,
                  color: action['color'] as Color,
                ),
                label: Text(
                  action['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: action['color'] as Color,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (action['color'] as Color).withOpacity(0.1),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Kebijakan Privasi',
          style: TextStyle(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: _getResponsiveFontSize(context, 18),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // IconButton(
          //   icon: Icon(
          //     showTableOfContents ? Icons.view_list : Icons.list,
          //     color: const Color(0xFF3B82F6),
          //   ),
          //   onPressed: () {
          //     setState(() {
          //       showTableOfContents = !showTableOfContents;
          //     });
          //   },
          // ),
          // IconButton(
          //   icon: Icon(Icons.search, color: const Color(0xFF3B82F6)),
          //   onPressed: () {
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(
          //         content: Text('Fitur pencarian akan segera tersedia'),
          //         backgroundColor: Colors.blue,
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(),

            SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(),

            // Table of Contents (conditional)
            if (showTableOfContents) _buildTableOfContents(),

            // Privacy Sections
            ...privacySections.asMap().entries.map((entry) {
              return _buildSection(entry.value, entry.key);
            }),

            // Footer
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.security, size: 48, color: Colors.blue[600]),
                  SizedBox(height: 16),
                  Text(
                    'Data Anda Aman Bersama Kami',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 18),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Kami berkomitmen untuk melindungi privasi dan keamanan data pribadi Anda dengan standar keamanan tingkat enterprise.',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to contact or support page
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Mengarahkan ke halaman kontak...'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: Icon(Icons.support_agent),
                    label: Text('Hubungi Privacy Officer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
