// ignore_for_file: deprecated_member_use

import 'package:absensikaryawan/Screen%20User/signin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class IntroScreenThree extends StatefulWidget {
  const IntroScreenThree({super.key});

  @override
  State<IntroScreenThree> createState() => _IntroScreenThreeState();
}

class _IntroScreenThreeState extends State<IntroScreenThree>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = kIsWeb;

    final paddingHorizontal = isWeb
        ? (size.width > 1200 ? 80.0 : size.width * 0.1)
        : size.width * 0.06;

    final fontSizeTitle = isWeb
        ? (size.width > 1200 ? 28.0 : 24.0)
        : size.width * 0.05;

    final fontSizeDesc = isWeb
        ? (size.width > 1200 ? 16.0 : 14.0)
        : size.width * 0.035;

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/images/04_onboarding.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF6C63FF), Color(0xFF246BFD)],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.people_outline,
                      size: isWeb ? 120 : 80,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                );
              },
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  constraints: isWeb
                      ? const BoxConstraints(maxWidth: 800)
                      : null,
                  margin: isWeb
                      ? const EdgeInsets.symmetric(horizontal: 20)
                      : EdgeInsets.zero,
                  padding: EdgeInsets.symmetric(
                    horizontal: paddingHorizontal,
                    vertical: isWeb ? 40.0 : size.height * 0.04,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(isWeb ? 20 : 30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: isWeb ? 20 : 10,
                        offset: Offset(0, isWeb ? -5 : -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── TEKS DIUBAH ──
                      Text(
                        "Tersedia untuk siapa saja, di mana saja",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSizeTitle,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.3,
                          fontFamily: isWeb ? 'Roboto' : null,
                        ),
                      ),
                      SizedBox(height: isWeb ? 16 : 12),
                      Text(
                        "SENADA dapat digunakan oleh perusahaan, UKM, komunitas, maupun tim freelance. Siapapun bisa mendaftar secara mandiri dan langsung menggunakan semua fitur.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSizeDesc,
                          color: Colors.black54,
                          height: 1.5,
                          fontFamily: isWeb ? 'Roboto' : null,
                        ),
                      ),
                      SizedBox(height: isWeb ? 32 : 24),
                      SizedBox(
                        width: double.infinity,
                        height: isWeb ? 56 : 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignInScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF246BFD),
                            foregroundColor: Colors.white,
                            elevation: isWeb ? 4 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            "Mulai Sekarang",
                            style: TextStyle(
                              fontSize: isWeb ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: isWeb ? 'Roboto' : null,
                            ),
                          ),
                        ),
                      ),
                      if (isWeb) const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
