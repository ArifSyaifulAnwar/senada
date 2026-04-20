import 'package:absensikaryawan/Screen%20HRD/homehrd.dart';
import 'package:absensikaryawan/Screen%20admin/homeadmin.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/keamanan/pininput.dart';
import 'package:absensikaryawan/Screen%20User/splashscreen/intro1.dart';
import 'package:absensikaryawan/Screen%20User/home.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Untuk kIsWeb
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    // Delay sedikit lebih lama untuk web karena loading initial bisa lebih lama
    final delay = kIsWeb
        ? const Duration(seconds: 4)
        : const Duration(seconds: 3);

    Future.delayed(delay, () {
      _checkLoginStatus();
    });
  }

  // Fungsi untuk mengecek status login dan PIN
  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email');
      final userId = prefs.getString('UserID');
      final role = prefs.getString('Role');

      // Jika ada email atau userId tersimpan, berarti user sudah login
      if (email != null &&
          email.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty) {
        // Cek status PIN user dengan role
        await _checkPinStatus(userId, role ?? '');
      } else {
        _navigateToSignIn();
      }
    } catch (e) {
      _navigateToSignIn();
    }
  }

  // Fungsi untuk mengecek status PIN dari server
  Future<void> _checkPinStatus(String userId, String role) async {
    try {
      // Get access token
      final tokenResponse = await http.post(
        Uri.parse('$baseURL/api/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'password', 'password': 'ASN_DBS'},
      );

      if (tokenResponse.statusCode == 200) {
        final tokenData = json.decode(tokenResponse.body);
        final accessToken = tokenData['access_token'];

        if (accessToken != null) {
          // Check PIN status
          final pinResponse = await http.post(
            Uri.parse('$baseURL/api/pin/status'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'UserId': userId}),
          );

          if (pinResponse.statusCode == 200) {
            final pinData = json.decode(pinResponse.body);

            if (pinData['Success'] == true) {
              final bool pinEnabled = pinData['Data']['Enabled'] ?? false;
              final bool hasPin = pinData['Data']['HasPin'] ?? false;

              // Simpan status PIN ke SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('PinEnabled', pinEnabled);
              await prefs.setBool('HasPin', hasPin);

              // Logika navigasi berdasarkan status PIN
              if (pinEnabled && hasPin) {
                // PIN aktif dan user punya PIN, arahkan ke halaman input PIN
                // Simpan role untuk digunakan di PIN input screen
                await prefs.setString('PendingRole', role);
                _navigateToPinInput();
              } else {
                // PIN tidak aktif atau user belum set PIN, navigasi berdasarkan role
                _navigateByRole(role);
              }
            } else {
              // Gagal get status PIN, navigasi berdasarkan role
              _navigateByRole(role);
            }
          } else {
            // Error response, navigasi berdasarkan role
            _navigateByRole(role);
          }
        } else {
          _navigateByRole(role);
        }
      } else {
        _navigateByRole(role);
      }
    } catch (e) {
      // Jika terjadi error, navigasi berdasarkan role
      _navigateByRole(role);
    }
  }

  void _navigateByRole(String role) {
    Widget destination;

    switch (role.toLowerCase()) {
      case 'admin':
        destination = const HomePageAdmin();
        break;
      case 'hrd':
        destination = const HomePageHRD(); // Halaman HRD
        break;
      case 'user':
      default:
        destination = const HomePage();
        break;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          final scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          );
        },
      ),
    );
  }

  void _navigateToPinInput() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (_, __, ___) => const PinInputScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          final scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          );
        },
      ),
    );
  }

  void _navigateToSignIn() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (_, __, ___) => const IntroScreenOne(),
        transitionsBuilder: (_, animation, __, child) {
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          final scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing untuk web
    final isWeb = kIsWeb;
    final logoWidth = isWeb
        ? (screenWidth > 1200 ? 300.0 : screenWidth * 0.25) // Desktop web
        : screenWidth * 0.6; // Mobile

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            // Center content untuk tampilan web yang lebih baik
            constraints: isWeb ? const BoxConstraints(maxWidth: 800) : null,
            margin: isWeb
                ? const EdgeInsets.symmetric(horizontal: 20)
                : EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Logo container dengan batasan ukuran yang responsif untuk web
                Container(
                  constraints: BoxConstraints(
                    maxWidth: isWeb ? 400 : screenWidth * 0.7,
                    maxHeight: isWeb ? 250 : screenHeight * 0.3,
                  ),
                  child: Image.asset(
                    'assets/images/logofinal.jpg',
                    width: logoWidth,
                    fit: BoxFit.contain,
                    // Error handling untuk web jika gambar tidak ditemukan
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: logoWidth,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                // Loading indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF246AFD)),
                ),
                SizedBox(height: screenHeight * 0.02),
                // Loading text dengan sizing yang lebih baik untuk web
                Text(
                  'Memuat aplikasi...',
                  style: TextStyle(
                    fontSize: isWeb
                        ? (screenWidth > 1200 ? 18 : 16) // Desktop web
                        : (screenWidth > 360 ? 16 : 14), // Mobile
                    color: Colors.grey[600],
                    fontFamily: 'Roboto', // Font yang web-friendly
                  ),
                ),
                const Spacer(flex: 3),
                // Footer untuk web (opsional)
                if (isWeb) ...[
                  const SizedBox(height: 20),
                  Text(
                    '© 2025 Sistem Absensi Karyawan SDB',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
