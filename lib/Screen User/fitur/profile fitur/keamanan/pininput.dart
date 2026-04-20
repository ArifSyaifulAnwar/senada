// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/Screen%20User/home.dart';
import 'package:absensikaryawan/Screen%20admin/homeadmin.dart';
import 'package:absensikaryawan/Screen%20User/splashscreen/intro1.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PinInputScreen extends StatefulWidget {
  const PinInputScreen({super.key});

  @override
  State<PinInputScreen> createState() => _PinInputScreenState();
}

class _PinInputScreenState extends State<PinInputScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  int _wrongAttempts = 0;
  final int _maxAttempts = 3;

  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _animationController.forward();
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // Enhanced responsive breakpoints system
  Map<String, dynamic> _getResponsiveValues(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    // Define breakpoints
    final bool isVerySmallWidth = width < 320;
    final bool isSmallWidth = width < 360;
    final bool isMediumWidth = width < 400;
    final bool isVerySmallHeight = height < 600;
    final bool isSmallHeight = height < 700;

    return {
      'width': width,
      'height': height,
      'isVerySmallWidth': isVerySmallWidth,
      'isSmallWidth': isSmallWidth,
      'isMediumWidth': isMediumWidth,
      'isVerySmallHeight': isVerySmallHeight,
      'isSmallHeight': isSmallHeight,

      // Responsive values
      'iconSize': isVerySmallWidth
          ? 50.0
          : isSmallWidth
          ? 60.0
          : 80.0,
      'titleFontSize': isVerySmallWidth
          ? 18.0
          : isSmallWidth
          ? 20.0
          : 24.0,
      'subtitleFontSize': isVerySmallWidth
          ? 11.0
          : isSmallWidth
          ? 12.0
          : 14.0,
      'buttonFontSize': isVerySmallWidth
          ? 13.0
          : isSmallWidth
          ? 14.0
          : 16.0,
      'smallButtonFontSize': isVerySmallWidth
          ? 11.0
          : isSmallWidth
          ? 12.0
          : 14.0,
      'buttonHeight': isVerySmallHeight
          ? 40.0
          : isSmallHeight
          ? 44.0
          : 48.0,

      'horizontalPadding': isVerySmallWidth
          ? 12.0
          : isSmallWidth
          ? 16.0
          : 24.0,
      'verticalPadding': isVerySmallHeight
          ? 8.0
          : isSmallHeight
          ? 12.0
          : 16.0,

      // Spacing values
      'topSpacing': isVerySmallHeight ? 20.0 : 40.0,
      'iconBottomSpacing': isVerySmallHeight ? 16.0 : 24.0,
      'titleBottomSpacing': isVerySmallHeight ? 6.0 : 8.0,
      'subtitleBottomSpacing': isVerySmallHeight ? 24.0 : 32.0,
      'pinFieldsBottomSpacing': isVerySmallHeight ? 20.0 : 28.0,
      'buttonBottomSpacing': isVerySmallHeight ? 16.0 : 20.0,
      'clearButtonBottomSpacing': isVerySmallHeight ? 20.0 : 40.0,
      'logoutButtonBottomSpacing': isVerySmallHeight ? 10.0 : 20.0,

      // PIN field responsive values
      'pinFieldSize': _calculatePinFieldSize(
        width,
        isVerySmallWidth,
        isSmallWidth,
      ),
      'pinFieldSpacing': isVerySmallWidth
          ? 4.0
          : isSmallWidth
          ? 6.0
          : 12.0,
      'pinFontSize': isVerySmallWidth
          ? 12.0
          : isSmallWidth
          ? 14.0
          : 18.0,
    };
  }

  double _calculatePinFieldSize(
    double screenWidth,
    bool isVerySmall,
    bool isSmall,
  ) {
    // Calculate field size based on available width
    final availableWidth =
        screenWidth -
        (isVerySmall
            ? 24
            : isSmall
            ? 32
            : 48); // padding
    final spacing = isVerySmall
        ? 4.0
        : isSmall
        ? 6.0
        : 12.0;
    final totalSpacing = spacing * 5; // 5 spaces between 6 fields
    final fieldWidth = (availableWidth - totalSpacing) / 6;

    // Ensure minimum and maximum sizes
    return fieldWidth.clamp(32.0, 55.0);
  }

  void _onPinChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Check if all fields are filled
    if (index == 5 && value.isNotEmpty) {
      _verifyPin();
    }
  }

  String _getEnteredPin() {
    return _controllers.map((controller) => controller.text).join();
  }

  void _clearPin() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _verifyPin() async {
    final enteredPin = _getEnteredPin();

    if (enteredPin.length != 6) {
      _showErrorMessage('PIN harus 6 digit');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID');

      if (userId == null) {
        _showErrorMessage('User ID tidak ditemukan');
        _logout();
        return;
      }

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
          // Verify PIN
          final verifyResponse = await http.post(
            Uri.parse('$baseURL/api/pin/verify'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'UserId': userId, 'Pin': enteredPin}),
          );

          final verifyData = json.decode(verifyResponse.body);

          if (verifyResponse.statusCode == 200 &&
              verifyData['Success'] == true) {
            // PIN benar, navigate berdasarkan role
            _navigateByRole();
          } else {
            // PIN salah
            _wrongAttempts++;

            if (_wrongAttempts >= _maxAttempts) {
              _showErrorMessage(
                'Terlalu banyak percobaan salah. Silakan login ulang.',
              );
              _logout();
            } else {
              _showErrorMessage(
                'PIN salah. Sisa percobaan: ${_maxAttempts - _wrongAttempts}',
              );
              _clearPin();
              _shakeController.forward().then((_) {
                _shakeController.reverse();
              });
            }
          }
        } else {
          _showErrorMessage('Gagal mendapatkan akses');
        }
      } else {
        _showErrorMessage('Gagal terkoneksi ke server');
      }
    } catch (e) {
      _showErrorMessage('Terjadi kesalahan sistem');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk navigasi berdasarkan role
  Future<void> _navigateByRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('Role') ?? '';

      Widget destination;

      // Tentukan halaman tujuan berdasarkan role
      switch (role.toLowerCase()) {
        case 'admin':
          destination = const HomePageAdmin();
          break;
        // case 'hrd':
        //   destination = const HomePageHRD();
        //   break;
        case 'user':
        default:
          destination = const HomePage();
          break;
      }

      // Navigasi ke halaman yang sesuai
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, __, ___) => destination,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      // Jika terjadi error, default ke halaman user
      _showErrorMessage('Terjadi kesalahan saat menentukan halaman');
      _navigateToHome();
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Fungsi fallback untuk navigasi ke home (user)
  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => const IntroScreenOne(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildPinFields(Map<String, dynamic> responsive) {
    final fieldSize = responsive['pinFieldSize'];
    final spacing = responsive['pinFieldSpacing'];
    final fontSize = responsive['pinFontSize'];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: responsive['horizontalPadding'],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (index) {
          return Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: fieldSize, minWidth: 32),
              margin: EdgeInsets.only(
                right: index < 5 ? spacing : 0,
                left: index > 0 ? spacing / 2 : 0,
              ),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _focusNodes[index].hasFocus
                          ? const Color(0xFF246AFD)
                          : Colors.grey.withOpacity(0.3),
                      width: _focusNodes[index].hasFocus ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _controllers[index].text.isNotEmpty
                        ? const Color(0xFF246AFD).withOpacity(0.1)
                        : Colors.white,
                  ),
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    obscureText: true,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => _onPinChanged(value, index),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> responsive) {
    return Column(
      children: [
        // Logo/Icon
        Container(
          width: responsive['iconSize'],
          height: responsive['iconSize'],
          decoration: BoxDecoration(
            color: const Color(0xFF246AFD).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_outline,
            size: responsive['iconSize'] * 0.5,
            color: const Color(0xFF246AFD),
          ),
        ),

        SizedBox(height: responsive['iconBottomSpacing']),

        // Title
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive['horizontalPadding'],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Masukkan PIN Anda',
              style: TextStyle(
                fontSize: responsive['titleFontSize'],
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        SizedBox(height: responsive['titleBottomSpacing']),

        // Subtitle
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive['horizontalPadding'],
          ),
          child: Text(
            'Gunakan PIN 6 digit untuk mengakses aplikasi',
            style: TextStyle(
              fontSize: responsive['subtitleFontSize'],
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> responsive) {
    return Column(
      children: [
        // Main Button or Loading
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive['horizontalPadding'],
          ),
          child: _isLoading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF246AFD)),
                )
              : SizedBox(
                  width: double.infinity,
                  height: responsive['buttonHeight'],
                  child: ElevatedButton(
                    onPressed: _getEnteredPin().length == 6 ? _verifyPin : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF246AFD),
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: _getEnteredPin().length == 6 ? 2 : 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Verifikasi PIN',
                        style: TextStyle(
                          fontSize: responsive['buttonFontSize'],
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
        ),

        SizedBox(height: responsive['buttonBottomSpacing']),

        // Clear button
        TextButton(
          onPressed: _clearPin,
          child: Text(
            'Hapus',
            style: TextStyle(
              fontSize: responsive['smallButtonFontSize'],
              color: const Color(0xFF246AFD),
            ),
          ),
        ),

        SizedBox(height: responsive['clearButtonBottomSpacing']),

        // Logout button
        TextButton.icon(
          onPressed: _logout,
          icon: Icon(
            Icons.logout,
            color: Colors.grey[600],
            size: responsive['smallButtonFontSize'] + 2,
          ),
          label: Text(
            'Keluar dari Akun',
            style: TextStyle(
              fontSize: responsive['smallButtonFontSize'],
              color: Colors.grey[600],
            ),
          ),
        ),

        SizedBox(height: responsive['logoutButtonBottomSpacing']),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = _getResponsiveValues(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive['horizontalPadding'],
                            vertical: responsive['verticalPadding'],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Top spacer
                              SizedBox(height: responsive['topSpacing']),

                              // Header section
                              _buildHeader(responsive),

                              SizedBox(
                                height: responsive['subtitleBottomSpacing'],
                              ),

                              // PIN Input Fields with shake animation
                              AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_shakeAnimation.value, 0),
                                    child: _buildPinFields(responsive),
                                  );
                                },
                              ),

                              SizedBox(
                                height: responsive['pinFieldsBottomSpacing'],
                              ),

                              // Action buttons section
                              _buildActionButtons(responsive),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
