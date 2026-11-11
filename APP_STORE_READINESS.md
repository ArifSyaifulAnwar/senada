# Kesiapan rilis SENADA untuk iOS

Pemeriksaan: 11 November 2026. Build release iOS tanpa signing berhasil; upload dan pengiriman review belum dilakukan.

## Gambaran proyek

- Nama aplikasi iOS: SENADA; paket Dart: `absensikaryawan`.
- Versi sumber: `1.4.21+36`; pastikan nomor build belum dipakai di App Store Connect sebelum upload.
- Ada 172 berkas Dart di `lib`, dengan layar karyawan, admin, dan HRD.
- Fitur mencakup login/pendaftaran OTP, PIN, absensi GPS dan foto/verifikasi wajah, riwayat absensi, cuti/izin/dinas luar, lembur, reimbursement, aktivitas harian, data karyawan, aset/inventaris, dokumen, kalender, dan notifikasi.
- `lib/main.dart` menginisialisasi Firebase, membuka splash, dan menyiapkan notifikasi. `lib/Services` memuat integrasi API dan layanan; model serta UI tersebar di folder masing-masing fitur.
- API produksi dikonfigurasi di `lib/Services/config.dart`. Backend tidak ada dalam repo ini; perilakunya harus diuji melalui akun uji.

## Kondisi lokal yang terverifikasi

- Xcode 26.6, macOS 26.5.1, CocoaPods tersedia di `/opt/homebrew/bin/pod`.
- Flutter 3.47.9 stable dan Dart 3.13.7 berhasil dipasang di `~/development/flutter`; lokasi ini sudah ada dalam `.zshrc`. VS Code proyek juga sudah diarahkan ke SDK tersebut.
- `flutter doctor -v`: Flutter, Xcode 26.6, CocoaPods 1.16.2, dan jaringan lolos. Android SDK belum terpasang; pekerjaan saat ini berfokus pada iOS. Belum ada iPhone terhubung saat pemeriksaan.
- `flutter pub get` berhasil dan `flutter analyze --no-pub` melaporkan `No issues found!`.
- Engine iOS debug/profile/release sudah diunduh. Generated.xcconfig sudah terbentuk; `pod install` berhasil memasang 31 pod dari 15 dependensi.
- `flutter build ios --release --no-codesign --no-pub` berhasil menghasilkan `build/ios/iphoneos/Runner.app` (54,3 MB). Build awal terhenti saat sesi terputus; percobaan lanjutan selesai dengan exit code 0. Ini belum merupakan archive/IPA yang ditandatangani, belum diuji berjalan pada iPhone, dan belum diunggah.
- Ruang kosong setelah build sekitar 4 GB. Periksa kapasitas sebelum archive berikutnya; jangan menghapus berkas pengguna tanpa persetujuan.
- Bundle ID: `com.senada.attendance`, cocok dengan Firebase plist.
- Podfile dan konfigurasi tingkat proyek Xcode kini menetapkan iOS 15. Flutter memperbarui deployment target ketika build pertama.
- Release memakai manual signing, team bersyarat `XDJZCBWYSP`, dan profil bernama `SENADA Attendance App Store`. Profil lokal cocok dengan `com.senada.attendance` dan berakhir 21 November 2026 pukul 14.37 WIB, tetapi tidak memiliki entitlement `aps-environment`, sehingga perlu dibuat ulang dengan Push Notifications untuk aplikasi ini. Kecocokan private key/sertifikat belum diperiksa.
- Ada dua profil lain untuk `com.asn.sdb.senada`, tetapi pengguna telah memilih tetap menggunakan `com.senada.attendance`. Pengguna menyatakan akun Apple Developer aktif dan aplikasi belum dibuat di App Store Connect.
- Konfigurasi Debug juga menunjuk sertifikat distribusi/profil App Store. Ini perlu ditinjau jika menjalankan build Debug pada iPhone.

## Perubahan awal

1. Menambahkan `GoogleService-Info.plist` ke group Runner dan Copy Bundle Resources. Sebelumnya berkas hanya ada di disk, padahal aplikasi memanggil `Firebase.initializeApp()` tanpa opsi pada iOS.
2. Mengaktifkan makro kamera, foto, lokasi, dan notifikasi untuk pod `permission_handler_apple`, sesuai pemakaian izin dalam kode.
3. Menetapkan `flutter.config.enable-swift-package-manager: false` di pubspec agar proyek tetap memakai CocoaPods dan konfigurasi makro izin di Podfile.
4. Semua berkas ikon yang dirujuk tersedia; ikon App Store berukuran 1024 × 1024, RGB tanpa alpha.

Validasi: plist dan project lolos `plutil -lint`; Podfile lolos `ruby -c`; diff lolos `git diff --check`; analyzer dan kompilasi release iOS lolos. Pengujian runtime pada iPhone belum dilakukan.

## Pekerjaan berikutnya

1. Selesai: pasang Flutter SDK dan jalankan `flutter doctor -v`.
2. Selesai: `flutter pub get`, `flutter analyze`, pemasangan pod, dan build release tanpa signing.
3. Ganti tes counter bawaan di `test/widget_test.dart` dengan tes yang relevan bila menyiapkan pengujian otomatis; tes saat ini tidak sesuai UI SENADA.
4. Uji pada iPhone: startup, login/OTP/PIN, kamera, GPS, absensi, foto/berkas, notifikasi/APNs, logout, dan jalur setiap peran. Gunakan data uji untuk operasi yang mengubah data.
5. Verifikasi signing, profil distribusi, APNs/Firebase, ikon, dan privacy manifest dari dependensi dalam hasil build.
6. Konfirmasi aplikasi di App Store Connect memakai bundle ID yang sama, serta keanggotaan Apple Developer dan akses akun aktif.
7. Lengkapi metadata: deskripsi, kategori, screenshot, support URL, privacy policy URL publik, kontak review, akun demo dan petunjuk penggunaan GPS/absensi untuk reviewer.
8. Tinjau isi kebijakan privasi: masih ada `privacy@company.com` dan alamat lain. Pemilik harus memastikan kontak yang benar serta kesesuaian pengolahan data lokasi, foto/wajah, dan data karyawan sebelum mengisi App Privacy.
9. Fitur hapus akun sudah ada di profil karyawan dan admin; pastikan backend bekerja melalui akun khusus uji. Jangan menghapus akun produksi untuk verifikasi.
10. Setelah pemeriksaan lokal selesai, buat archive/IPA (`flutter build ipa`), validasi, upload ke App Store Connect, dan uji lewat TestFlight.
11. Lengkapi informasi review dan kirim ke Apple. Upload berhasil, review disetujui, dan aplikasi terbit adalah tahap yang berbeda; catat hasil aktual tiap tahap.

## Langkah portal Apple untuk pemilik akun

Identitas yang dipilih pengguna: **com.senada.attendance**. Jangan memilih profil untuk com.asn.sdb.senada.

1. Di Apple Developer → Certificates, Identifiers & Profiles → Identifiers, pilih App ID `com.senada.attendance`, aktifkan Push Notifications, lalu simpan. Jika App ID belum tersedia pada akun/team yang benar, daftarkan explicit App ID tersebut dahulu.
2. Di Profiles, edit/buat ulang profil App Store untuk App ID itu dan sertifikat distribusi yang private key-nya tersedia di Mac. Konfigurasi proyek mengharapkan nama `SENADA Attendance App Store`. Unduh profil hasil regenerasi. Periksa entitlement produksi dan masa berlaku sebelum archive.
3. Di App Store Connect → My Apps → + → New App, pilih iOS, nama SENADA (jika tersedia), bahasa utama Indonesian, Bundle ID `com.senada.attendance`, dan SKU internal yang unik, misalnya `SENADA-IOS-001`.
4. Untuk pekerjaan Xcode, buka **ios/Runner.xcworkspace**. Setelah profil diperbarui, periksa target Runner → Signing & Capabilities untuk konfigurasi Release dan team yang benar.
5. Sesudah build, signing, dan pengujian selesai, buat archive dan validasi sebelum upload. Untuk notifikasi sungguhan, konfigurasi APNs pada Firebase juga harus sesuai App ID/team; keberhasilan kompilasi tidak membuktikan pengiriman push berhasil.

Pembuatan aplikasi di App Store Connect belum dilakukan: pengguna menyatakan akses akun masih menunggu OTP dari pemilik akun. Masukkan OTP langsung pada halaman Apple setelah tersedia. Tidak ada akses portal Apple terautentikasi yang tersedia melalui alat sesi ini; langkah portal dilakukan pemilik akun dengan panduan di atas.

## Referensi

- Flutter: https://docs.flutter.dev/deployment/ios
- Persyaratan SDK Apple: https://developer.apple.com/news/upcoming-requirements/?id=04282026a
- Firebase iOS: https://firebase.google.com/docs/ios/setup
- Permission handler: https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler/example/ios/Podfile
