// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';

class HalamanBantuanDukungan extends StatefulWidget {
  const HalamanBantuanDukungan({super.key});

  @override
  _HalamanBantuanDukunganState createState() => _HalamanBantuanDukunganState();
}

class FAQItem {
  final String id;
  final String question;
  final String answer;
  final String category;
  final IconData icon;
  final Color color;
  bool isExpanded;

  FAQItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.icon,
    required this.color,
    this.isExpanded = false,
  });
}

class SupportChannel {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String contactInfo;
  final String availability;
  final VoidCallback onTap;

  SupportChannel({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.contactInfo,
    required this.availability,
    required this.onTap,
  });
}

class GuideItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> steps;

  GuideItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.steps,
  });
}

class _HalamanBantuanDukunganState extends State<HalamanBantuanDukungan>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();

  String searchQuery = '';
  String selectedCategory = 'Semua';
  int _selectedTabIndex = 0;

  final List<String> categories = [
    'Semua',
    'Akun & Login',
    'Absensi',
    'Laporan',
    'Notifikasi',
    'Teknis',
    'Lainnya',
  ];

  List<FAQItem> faqItems = [
    FAQItem(
      id: '1',
      question: 'Bagaimana cara login ke aplikasi?',
      answer: '''Untuk login ke aplikasi, ikuti langkah berikut:

1. Buka aplikasi di smartphone Anda
2. Masukkan email dan password yang telah diberikan oleh HRD
3. Tap tombol "Masuk"
4. Jika ini pertama kali login, Anda akan diminta untuk mengubah password default
5. Setelah berhasil login, Anda akan diarahkan ke halaman beranda

**Catatan:** Jika mengalami kesulitan login, pastikan koneksi internet stabil dan periksa kembali email/password yang dimasukkan.''',
      category: 'Akun & Login',
      icon: Icons.login,
      color: Colors.blue,
    ),
    FAQItem(
      id: '2',
      question: 'Lupa password, bagaimana cara reset?',
      answer: '''Jika Anda lupa password, ikuti langkah berikut:

1. Di halaman login, tap "Lupa Password?"
2. Masukkan email yang terdaftar
3. Cek email Anda untuk mendapatkan link reset password
4. Klik link tersebut dan buat password baru
5. Gunakan password baru untuk login

**Tips Keamanan:**
• Gunakan kombinasi huruf besar, kecil, angka, dan simbol
• Minimal 8 karakter
• Jangan gunakan informasi pribadi yang mudah ditebak
• Simpan password di tempat yang aman''',
      category: 'Akun & Login',
      icon: Icons.lock_reset,
      color: Colors.orange,
    ),
    FAQItem(
      id: '3',
      question: 'Bagaimana cara melakukan absensi?',
      answer: '''Untuk melakukan absensi, ikuti langkah berikut:

**Absensi Masuk:**
1. Buka aplikasi dan pastikan GPS aktif
2. Tap tombol "Absen Masuk" di halaman utama
3. Aplikasi akan meminta izin akses lokasi
4. Pastikan Anda berada di area kantor yang diizinkan
5. Ambil foto selfie untuk verifikasi
6. Tap "Konfirmasi" untuk menyelesaikan absensi

**Absensi Keluar:**
1. Tap tombol "Absen Keluar"
2. Ikuti prosedur yang sama seperti absen masuk
3. Pastikan semua tugas harian telah selesai

**Catatan Penting:**
• Absensi hanya bisa dilakukan dalam radius yang telah ditentukan
• Foto harus jelas dan menampilkan wajah dengan baik
• Jika ada masalah teknis, segera hubungi IT Support''',
      category: 'Absensi',
      icon: Icons.fingerprint,
      color: Colors.green,
    ),
    FAQItem(
      id: '4',
      question: 'Kenapa lokasi saya tidak terdeteksi saat absensi?',
      answer: '''Jika lokasi tidak terdeteksi, coba solusi berikut:

**Periksaan Awal:**
1. Pastikan GPS/Location Services aktif
2. Berikan izin lokasi ke aplikasi (Always Allow)
3. Pastikan koneksi internet stabil
4. Restart aplikasi dan coba lagi

**Jika masih bermasalah:**
• Restart smartphone Anda
• Update aplikasi ke versi terbaru
• Clear cache aplikasi
• Logout dan login kembali

**Area Absensi:**
• Pastikan Anda berada dalam radius 100 meter dari kantor
• Jika bekerja dari rumah, pastikan lokasi rumah sudah terdaftar di sistem
• Untuk lokasi meeting external, ajukan permintaan absensi manual melalui atasan

**Hubungi Support:**
Jika semua cara di atas tidak berhasil, hubungi IT Support dengan menyertakan screenshot error yang muncul.''',
      category: 'Absensi',
      icon: Icons.location_off,
      color: Colors.red,
    ),
    FAQItem(
      id: '5',
      question: 'Bagaimana cara mengajukan cuti?',
      answer: '''Untuk mengajukan cuti, ikuti prosedur berikut:

**Melalui Aplikasi:**
1. Buka menu "Cuti & Izin"
2. Pilih jenis cuti (tahunan, sakit, dll)
3. Tentukan tanggal mulai dan selesai
4. Isi alasan cuti dengan jelas
5. Upload dokumen pendukung jika diperlukan
6. Submit pengajuan dan tunggu persetujuan

**Jenis Cuti:**
• Cuti Tahunan: 12 hari per tahun
• Cuti Sakit: Dengan surat dokter
• Cuti Melahirkan: 3 bulan
• Cuti Menikah: 3 hari
• Cuti Khusus: Sesuai kebijakan perusahaan

**Timeline Persetujuan:**
• Cuti tahunan: 3-5 hari kerja
• Cuti mendadak: Maksimal 1 hari (dengan syarat)
• Cuti khusus: 1-2 minggu

**Tips:**
• Ajukan cuti minimal 1 minggu sebelumnya
• Pastikan tidak ada project urgent
• Koordinasi dengan tim untuk handover pekerjaan''',
      category: 'Absensi',
      icon: Icons.event_busy,
      color: Colors.purple,
    ),
    FAQItem(
      id: '6',
      question: 'Di mana saya bisa melihat laporan kehadiran?',
      answer: '''Untuk melihat laporan kehadiran, ikuti langkah berikut:

**Akses Laporan:**
1. Buka menu "Laporan" di aplikasi
2. Pilih "Riwayat Absensi"
3. Tentukan periode yang ingin dilihat
4. Gunakan filter untuk menyaring data
5. Tap pada item untuk melihat detail

**Informasi yang Tersedia:**
• Jam masuk dan keluar harian
• Total jam kerja per bulan
• Jumlah hari hadir, terlambat, dan absen
• Riwayat pengajuan cuti dan izin
• Status persetujuan

**Export Data:**
• Download laporan dalam format PDF
• Email laporan ke alamat pribadi
• Print laporan untuk keperluan administrasi

**Periode Laporan:**
• Harian: Data hari ini
• Mingguan: 7 hari terakhir
• Bulanan: Bulan berjalan atau bulan sebelumnya
• Custom: Tentukan tanggal sendiri

**Akses Manajer:**
Jika Anda seorang manajer, Anda juga bisa melihat laporan kehadiran tim Anda melalui menu "Tim Saya".''',
      category: 'Laporan',
      icon: Icons.assessment,
      color: Colors.teal,
    ),
    FAQItem(
      id: '7',
      question: 'Kenapa notifikasi tidak muncul?',
      answer: '''Jika notifikasi tidak muncul, coba langkah berikut:

**Pengaturan Aplikasi:**
1. Buka Settings aplikasi
2. Pastikan "Izinkan Notifikasi" aktif
3. Aktifkan semua jenis notifikasi yang diperlukan
4. Atur waktu reminder sesuai kebutuhan

**Pengaturan Perangkat (Android):**
• Masuk ke Settings > Apps > [Nama Aplikasi]
• Tap "Notifications" dan pastikan semua aktif
• Cek "Battery Optimization" dan exclude aplikasi
• Pastikan "Do Not Disturb" tidak aktif

**Pengaturan Perangkat (iOS):**
• Masuk ke Settings > Notifications > [Nama Aplikasi]
• Aktifkan "Allow Notifications"
• Pilih style notifikasi yang diinginkan
• Aktifkan "Badge App Icon"

**Jenis Notifikasi:**
• Reminder absensi masuk (08:00)
• Reminder absensi keluar (17:00)
• Update status cuti
• Pengumuman dari HRD
• System maintenance

**Troubleshooting:**
• Restart aplikasi dan perangkat
• Update aplikasi ke versi terbaru
• Re-login ke akun Anda
• Contact IT Support jika masih bermasalah''',
      category: 'Notifikasi',
      icon: Icons.notifications_off,
      color: Colors.amber,
    ),
    FAQItem(
      id: '8',
      question: 'Aplikasi sering crash atau lemot, bagaimana solusinya?',
      answer: '''Jika aplikasi sering crash atau lemot, coba solusi berikut:

**Quick Fix:**
1. Tutup aplikasi sepenuhnya dan buka kembali
2. Restart smartphone Anda
3. Pastikan koneksi internet stabil
4. Close aplikasi lain yang tidak diperlukan

**Advanced Solutions:**
• Clear cache aplikasi di Settings
• Update aplikasi ke versi terbaru
• Update OS smartphone ke versi terbaru
• Free up storage space (minimal 1GB kosong)

**Minimum Requirements:**
• Android 7.0+ atau iOS 12.0+
• RAM minimal 3GB
• Storage kosong minimal 500MB
• Koneksi internet stabil

**Performance Tips:**
• Jangan buka terlalu banyak aplikasi bersamaan
• Restart smartphone minimal seminggu sekali
• Update sistem operasi secara berkala
• Uninstall aplikasi yang tidak perlu

**Report Bug:**
Jika masalah berlanjut, laporkan ke IT Support dengan informasi:
• Model smartphone dan versi OS
• Versi aplikasi yang digunakan
• Screenshot atau video error
• Langkah-langkah yang menyebabkan error

**Temporary Solution:**
Jika aplikasi tidak bisa digunakan sama sekali, Anda bisa melakukan absensi manual dengan menghubungi supervisor atau HRD.''',
      category: 'Teknis',
      icon: Icons.bug_report,
      color: Colors.red,
    ),
    FAQItem(
      id: '9',
      question: 'Bagaimana cara mengubah informasi profil?',
      answer: '''Untuk mengubah informasi profil, ikuti langkah berikut:

**Data yang Bisa Diubah:**
1. Buka menu "Profil" atau "Akun"
2. Tap "Edit Profil"
3. Ubah informasi yang diizinkan:
   • Foto profil
   • Nomor telepon
   • Alamat email alternatif
   • Alamat rumah
   • Emergency contact

**Data yang Memerlukan Approval:**
• Nama lengkap
• Email utama
• Nomor KTP
• Informasi keluarga
Untuk mengubah data ini, submit request melalui HRD.

**Upload Foto Profil:**
• Ukuran maksimal 2MB
• Format JPG, PNG
• Resolusi minimal 300x300 px
• Foto harus jelas dan profesional

**Verifikasi Perubahan:**
• Beberapa perubahan memerlukan verifikasi email
• Check email untuk konfirmasi
• Perubahan akan aktif setelah disetujui

**Keamanan:**
• Perubahan password memerlukan password lama
• SMS OTP untuk perubahan nomor telepon
• Email verification untuk perubahan email

**Timeline:**
• Perubahan data pribadi: Langsung aktif
• Perubahan yang perlu approval: 1-3 hari kerja
• Upload foto baru: Langsung terlihat''',
      category: 'Akun & Login',
      icon: Icons.edit,
      color: Colors.indigo,
    ),
    FAQItem(
      id: '10',
      question: 'Bagaimana cara melaporkan bug atau request fitur?',
      answer: '''Untuk melaporkan bug atau request fitur baru:

**Melaporkan Bug:**
1. Buka menu "Bantuan & Dukungan"
2. Pilih "Laporkan Masalah"
3. Isi form dengan detail:
   • Deskripsi masalah
   • Langkah untuk reproduce bug
   • Screenshot/video jika ada
   • Device information

**Request Fitur Baru:**
1. Gunakan channel "Feedback & Saran"
2. Jelaskan fitur yang diinginkan
3. Berikan alasan mengapa fitur ini penting
4. Estimasi berapa banyak user yang akan terbantu

**Bug Priority:**
• Critical: Tidak bisa login/absensi
• High: Fitur utama tidak berjalan
• Medium: Minor issues yang mengganggu
• Low: Cosmetic issues

**Response Time:**
• Critical bugs: 4-8 jam
• High priority: 1-2 hari
• Medium priority: 3-5 hari
• Feature requests: 2-4 minggu

**Follow Up:**
• Anda akan mendapat ticket number
• Check status melalui email notification
• Tim development akan menghubungi jika perlu info tambahan

**Contribution:**
User yang aktif melaporkan bug atau memberikan feedback konstruktif akan mendapat appreciation dari management.''',
      category: 'Lainnya',
      icon: Icons.feedback,
      color: Colors.cyan,
    ),
  ];

  List<GuideItem> quickGuides = [
    GuideItem(
      title: 'Panduan Login Pertama Kali',
      description: 'Langkah-langkah untuk login pertama kali dan setup akun',
      icon: Icons.login,
      color: Colors.blue,
      steps: [
        'Download aplikasi dari Play Store atau App Store',
        'Buka aplikasi dan pilih "Login"',
        'Masukkan email dan password yang diberikan HRD',
        'Ganti password default dengan password baru yang kuat',
        'Lengkapi profil dan foto profil',
        'Aktifkan notifikasi dan izin lokasi',
        'Selesai! Anda sudah siap menggunakan aplikasi',
      ],
    ),
    GuideItem(
      title: 'Cara Absensi yang Benar',
      description: 'Tutorial lengkap melakukan absensi masuk dan keluar',
      icon: Icons.fingerprint,
      color: Colors.green,
      steps: [
        'Pastikan GPS dan internet aktif',
        'Buka aplikasi di lokasi kantor',
        'Tap tombol "Absen Masuk" (pagi) atau "Absen Keluar" (sore)',
        'Izinkan aplikasi mengakses lokasi',
        'Ambil foto selfie dengan pencahayaan yang cukup',
        'Pastikan wajah terlihat jelas di foto',
        'Tap "Konfirmasi" untuk menyelesaikan absensi',
        'Cek notifikasi konfirmasi absensi berhasil',
      ],
    ),
    GuideItem(
      title: 'Mengajukan Cuti/Izin',
      description: 'Proses pengajuan cuti dan izin melalui aplikasi',
      icon: Icons.event_busy,
      color: Colors.purple,
      steps: [
        'Buka menu "Cuti & Izin"',
        'Pilih "Ajukan Cuti Baru"',
        'Pilih jenis cuti (tahunan, sakit, dll)',
        'Tentukan tanggal mulai dan selesai',
        'Isi alasan cuti dengan jelas dan lengkap',
        'Upload dokumen pendukung jika diperlukan',
        'Review semua informasi',
        'Submit pengajuan dan tunggu persetujuan atasan',
      ],
    ),
    GuideItem(
      title: 'Melihat Laporan Kehadiran',
      description: 'Cara mengakses dan memahami data kehadiran Anda',
      icon: Icons.assessment,
      color: Colors.teal,
      steps: [
        'Buka menu "Laporan"',
        'Pilih "Riwayat Absensi"',
        'Pilih periode laporan yang diinginkan',
        'Gunakan filter untuk menyaring data',
        'Tap item untuk melihat detail harian',
        'Download laporan jika diperlukan',
        'Bagikan atau print laporan',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  List<FAQItem> getFilteredFAQ() {
    List<FAQItem> filteredItems = faqItems;

    // Filter by category
    if (selectedCategory != 'Semua') {
      filteredItems = filteredItems
          .where((item) => item.category == selectedCategory)
          .toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        return item.question.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            item.answer.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.category.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    return filteredItems;
  }

  List<SupportChannel> getSupportChannels() {
    return [
      SupportChannel(
        name: 'Live Chat',
        description: 'Chat langsung dengan tim support',
        icon: Icons.chat,
        color: Colors.blue,
        contactInfo: 'Dalam aplikasi',
        availability: '24/7',
        onTap: () => _openLiveChat(),
      ),
      SupportChannel(
        name: 'Email Support',
        description: 'Kirim email untuk bantuan detail',
        icon: Icons.email,
        color: Colors.green,
        contactInfo: 'support@tekinusa.co.id',
        availability: 'Response dalam 24 jam',
        onTap: () => _openEmailSupport(),
      ),
      SupportChannel(
        name: 'WhatsApp',
        description: 'Hubungi via WhatsApp',
        icon: Icons.message,
        color: Colors.green[600]!,
        contactInfo: '+62 812 3456 7890',
        availability: 'Senin-Jumat 08:00-17:00',
        onTap: () => _openWhatsAppSupport(),
      ),
      SupportChannel(
        name: 'Telepon',
        description: 'Hubungi hotline support',
        icon: Icons.phone,
        color: Colors.orange,
        contactInfo: '021-1234-5678',
        availability: 'Senin-Jumat 08:00-17:00',
        onTap: () => _openPhoneSupport(),
      ),
      SupportChannel(
        name: 'Remote Support',
        description: 'Bantuan akses remote untuk masalah teknis',
        icon: Icons.desktop_access_disabled,
        color: Colors.purple,
        contactInfo: 'Melalui appointment',
        availability: 'Atas permintaan',
        onTap: () => _openRemoteSupport(),
      ),
      SupportChannel(
        name: 'IT Helpdesk',
        description: 'Datang langsung ke kantor IT',
        icon: Icons.location_on,
        color: Colors.red,
        contactInfo: 'Lantai 3, Ruang IT',
        availability: 'Senin-Jumat 08:00-17:00',
        onTap: () => _openITHelpdesk(),
      ),
    ];
  }

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

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(_getResponsivePadding(context, 20)),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: const Color(0xFF94A3B8), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari pertanyaan atau topik bantuan...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: _getResponsiveFontSize(context, 14),
                ),
              ),
              style: TextStyle(fontSize: _getResponsiveFontSize(context, 14)),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  searchQuery = '';
                  _searchController.clear();
                });
              },
              child: Icon(
                Icons.clear,
                color: const Color(0xFF94A3B8),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(
        horizontal: _getResponsivePadding(context, 20),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;

          return Container(
            margin: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedCategory = category;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.blue[100],
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[700] : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: _getResponsiveFontSize(context, 12),
              ),
              side: BorderSide(
                color: isSelected ? Colors.blue : const Color(0xFFE2E8F0),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAQList() {
    final filteredFAQ = getFilteredFAQ();

    if (filteredFAQ.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
      itemCount: filteredFAQ.length,
      itemBuilder: (context, index) {
        final faq = filteredFAQ[index];
        return _buildFAQCard(faq);
      },
    );
  }

  Widget _buildFAQCard(FAQItem faq) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: faq.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(faq.icon, color: faq.color, size: 20),
        ),
        title: Text(
          faq.question,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 15),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        subtitle: Container(
          margin: EdgeInsets.only(top: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: faq.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            faq.category,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 11),
              color: faq.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: _buildFormattedAnswer(faq.answer),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedAnswer(String answer) {
    List<String> paragraphs = answer.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.startsWith('**') && paragraph.endsWith(':**')) {
          // Bold headers
          return Container(
            margin: EdgeInsets.only(bottom: 8, top: 12),
            child: Text(
              paragraph.replaceAll('**', '').replaceAll(':', ''),
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          );
        } else if (paragraph.startsWith('• ')) {
          // Bullet points
          return Container(
            margin: EdgeInsets.only(bottom: 4),
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
                      fontSize: _getResponsiveFontSize(context, 13),
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Regular paragraph
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            child: Text(
              paragraph,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 13),
                color: const Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Tidak ada hasil ditemukan',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coba gunakan kata kunci lain atau pilih kategori berbeda',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: const Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportChannels() {
    final channels = getSupportChannels();

    return ListView.builder(
      padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _buildSupportChannelCard(channel);
      },
    );
  }

  Widget _buildSupportChannelCard(SupportChannel channel) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
        child: InkWell(
          onTap: channel.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: channel.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(channel.icon, color: channel.color, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        channel.description,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 13),
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: channel.color,
                          ),
                          SizedBox(width: 4),
                          Text(
                            channel.contactInfo,
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              color: channel.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                          SizedBox(width: 4),
                          Text(
                            channel.availability,
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickGuides() {
    return ListView.builder(
      padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
      itemCount: quickGuides.length,
      itemBuilder: (context, index) {
        final guide = quickGuides[index];
        return _buildGuideCard(guide);
      },
    );
  }

  Widget _buildGuideCard(GuideItem guide) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: guide.color.withOpacity(0.3)),
        ),
        child: InkWell(
          onTap: () => _showGuideDetail(guide),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  guide.color.withOpacity(0.05),
                  guide.color.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: guide.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(guide.icon, color: guide.color, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.title,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        guide.description,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 13),
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.list_alt, size: 14, color: guide.color),
                          SizedBox(width: 4),
                          Text(
                            '${guide.steps.length} langkah',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              color: guide.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    return Padding(
      padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.feedback, color: Colors.blue[700], size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feedback & Saran',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 18),
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      Text(
                        'Bantu kami meningkatkan layanan',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          Text(
            'Kategori Feedback',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),

          SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  'Bug Report',
                  'Feature Request',
                  'UI/UX',
                  'Performance',
                  'Lainnya',
                ].map((category) {
                  return FilterChip(
                    label: Text(category),
                    selected: false,
                    onSelected: (selected) {
                      // Handle category selection
                    },
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 12),
                    ),
                  );
                }).toList(),
          ),

          SizedBox(height: 20),

          Text(
            'Pesan Feedback',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),

          SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _feedbackController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText:
                    'Tulis feedback atau saran Anda di sini...\n\nJika melaporkan bug, mohon sertakan:\n• Langkah untuk reproduce masalah\n• Device yang digunakan\n• Screenshot jika memungkinkan',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintStyle: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: _getResponsiveFontSize(context, 14),
                ),
              ),
              style: TextStyle(fontSize: _getResponsiveFontSize(context, 14)),
            ),
          ),

          SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _feedbackController.clear();
                  },
                  icon: Icon(Icons.clear),
                  label: Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_feedbackController.text.trim().isNotEmpty) {
                      _submitFeedback();
                    }
                  },
                  icon: Icon(Icons.send),
                  label: Text('Kirim Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tips: Feedback yang detail dan konstruktif akan membantu kami memberikan solusi yang lebih baik.',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 12),
                      color: Colors.amber[700],
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

  void _showGuideDetail(GuideItem guide) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: guide.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(guide.icon, color: guide.color, size: 30),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guide.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          guide.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Steps
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: guide.steps.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: guide.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: guide.color),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: guide.color,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                guide.steps[index],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: guide.color,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tutup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Support channel methods
  void _openLiveChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Membuka live chat...'),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _openEmailSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Membuka aplikasi email...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openWhatsAppSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Membuka WhatsApp...'),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  void _openPhoneSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Membuka aplikasi telepon...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _openRemoteSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengarahkan ke booking remote support...'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _openITHelpdesk() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menampilkan peta lokasi IT Helpdesk...'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _submitFeedback() {
    if (_feedbackController.text.trim().isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
              SizedBox(width: 20),
              Text('Mengirim feedback...'),
            ],
          ),
        );
      },
    );

    // Simulate API call
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading dialog

      // Show success
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 16),
                Text(
                  'Feedback Terkirim!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Terima kasih atas feedback Anda. Tim kami akan meresponnya dalam 1-2 hari kerja.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _feedbackController.clear();
                },
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Bantuan & Dukungan',
          style: TextStyle(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: _getResponsiveFontSize(context, 18),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF3B82F6),
          labelStyle: TextStyle(
            fontSize: _getResponsiveFontSize(context, 12),
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: 'FAQ'),
            Tab(text: 'Kontak'),
            Tab(text: 'Panduan'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedTabIndex == 0) ...[
            _buildSearchBar(),
            _buildCategoryFilter(),
            SizedBox(height: 20),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // FAQ Tab
                SingleChildScrollView(child: _buildFAQList()),
                // Kontak Tab
                _buildSupportChannels(),
                // Panduan Tab
                _buildQuickGuides(),
                // Feedback Tab
                SingleChildScrollView(child: _buildFeedbackForm()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }
}
