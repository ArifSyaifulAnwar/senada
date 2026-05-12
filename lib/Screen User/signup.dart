// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/Screen%20User/signin.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _showOtpField = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWeb = kIsWeb;

    final double maxWidth = isWeb ? 500 : double.infinity;
    final double horizontalPadding = isWeb ? 20.0 : screenWidth * 0.05;
    final double logoSize = isWeb ? 100.0 : screenWidth * 0.35;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: Container(
                      width: isWeb ? maxWidth : double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isWeb ? 20 : screenHeight * 0.05,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            // Logo
                            Hero(
                              tag: 'app-logo',
                              child: Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF246BFD,
                                      ).withOpacity(0.3),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Container(
                                    color: Colors.white,
                                    padding: EdgeInsets.all(logoSize * 0.15),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: Image.asset(
                                        'assets/images/logofinal.jpg',
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: logoSize,
                                                height: logoSize,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.business,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isWeb ? 20 : screenHeight * 0.04),

                            Text(
                              'SENADA',
                              style: TextStyle(
                                fontSize: isWeb ? 28 : screenWidth * 0.08,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isWeb ? 8 : screenHeight * 0.01),

                            Text(
                              _showOtpField
                                  ? 'Verifikasi OTP'
                                  : 'Buat Akun Baru',
                              style: TextStyle(
                                fontSize: isWeb ? 16 : screenWidth * 0.045,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    offset: const Offset(1, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isWeb ? 30 : screenHeight * 0.06),

                            // ── Form Fields ──
                            if (!_showOtpField) ...[
                              _buildTextField(
                                label: 'Nama Lengkap',
                                icon: Icons.person,
                                isPassword: false,
                                controller: _nameController,
                                maxLength: 50,
                              ),
                              SizedBox(
                                height: isWeb ? 16 : screenHeight * 0.02,
                              ),
                              _buildTextField(
                                label: 'Email',
                                icon: Icons.email,
                                isPassword: false,
                                controller: _emailController,
                                maxLength: 50,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              SizedBox(
                                height: isWeb ? 16 : screenHeight * 0.02,
                              ),
                              _buildTextField(
                                label: 'Nomor Telepon',
                                icon: Icons.phone,
                                isPassword: false,
                                controller: _phoneController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 13,
                              ),
                              SizedBox(
                                height: isWeb ? 16 : screenHeight * 0.02,
                              ),
                              _buildTextField(
                                label: 'Password',
                                icon: Icons.lock,
                                isPassword: true,
                                controller: _passwordController,
                                maxLength: 50,
                              ),
                              SizedBox(
                                height: isWeb ? 16 : screenHeight * 0.02,
                              ),
                              _buildTextField(
                                label: 'Konfirmasi Password',
                                icon: Icons.lock,
                                isPassword: true,
                                controller: _confirmPasswordController,
                                isConfirmPassword: true,
                                maxLength: 50,
                              ),
                            ] else ...[
                              // OTP Field
                              Text(
                                'Kode OTP telah dikirim ke email Anda. Silakan masukkan kode OTP untuk melanjutkan.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(
                                height: isWeb ? 16 : screenHeight * 0.02,
                              ),
                              _buildTextField(
                                label: 'Kode OTP',
                                icon: Icons.security,
                                isPassword: false,
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 6,
                              ),
                            ],

                            SizedBox(height: isWeb ? 24 : screenHeight * 0.04),

                            // Tombol Daftar / Verifikasi
                            SizedBox(
                              width: double.infinity,
                              height: isWeb ? 48 : 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _onSignUpPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF246BFD),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      )
                                    : Text(
                                        _showOtpField
                                            ? 'Verifikasi OTP'
                                            : 'Daftar',
                                        style: TextStyle(
                                          fontSize: isWeb ? 16 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),

                            SizedBox(height: isWeb ? 20 : screenHeight * 0.03),

                            // Link ke Sign In
                            if (!_showOtpField)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sudah memiliki akun? ',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: isWeb ? 14 : 16,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          transitionDuration: const Duration(
                                            milliseconds: 700,
                                          ),
                                          pageBuilder:
                                              (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                              ) => const SignInScreen(),
                                          transitionsBuilder:
                                              (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                                child,
                                              ) {
                                                const begin = Offset(0.0, -1.0);
                                                const end = Offset.zero;
                                                const curve = Curves.decelerate;
                                                var tween =
                                                    Tween(
                                                      begin: begin,
                                                      end: end,
                                                    ).chain(
                                                      CurveTween(curve: curve),
                                                    );
                                                var offsetAnimation = animation
                                                    .drive(tween);
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: SlideTransition(
                                                    position: offsetAnimation,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Masuk',
                                      style: TextStyle(
                                        color: const Color(0xFF246BFD),
                                        fontWeight: FontWeight.bold,
                                        fontSize: isWeb ? 14 : 16,
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(
                                          0xFF246BFD,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            if (isWeb) ...[
                              const SizedBox(height: 30),
                              Text(
                                '© 2025 Sistem Absensi Karyawan SDB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required bool isPassword,
    required TextEditingController controller,
    bool isConfirmPassword = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    final isWeb = kIsWeb;

    return TextFormField(
      controller: controller,
      obscureText: isPassword
          ? (isConfirmPassword
                ? !_isConfirmPasswordVisible
                : !_isPasswordVisible)
          : false,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: TextStyle(
        color: Colors.black,
        fontSize: isWeb ? 14 : 16,
        fontWeight: FontWeight.w500,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Silakan masukkan ${label.toLowerCase()}';
        }

        if (label == 'Nama Lengkap' && value.length > 50) {
          return 'Nama maksimal 50 karakter';
        }

        if (label == 'Email') {
          if (value.length > 50) return 'Email maksimal 50 karakter';
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
            return 'Masukkan format email yang valid';
          }
        }

        if (label == 'Nomor Telepon') {
          if (!RegExp(r'^\d+$').hasMatch(value)) {
            return 'Nomor telepon harus berupa angka';
          }
          if (value.length < 10 || value.length > 13) {
            return 'Nomor telepon harus antara 10 sampai 13 digit';
          }
        }

        if (label == 'Password') {
          if (value.length < 8) return 'Password minimal 8 karakter';
          if (value.length > 50) return 'Password maksimal 50 karakter';
          if (!RegExp(r'[A-Z]').hasMatch(value)) {
            return 'Password harus mengandung huruf besar';
          }
          if (!RegExp(r'[a-z]').hasMatch(value)) {
            return 'Password harus mengandung huruf kecil';
          }
          if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
            return 'Password harus mengandung simbol khusus';
          }
        }

        if (isConfirmPassword && value != _passwordController.text) {
          return 'Password tidak cocok';
        }

        if (label == 'Kode OTP') {
          if (value.length != 6) return 'Kode OTP harus 6 digit angka';
          if (!RegExp(r'^\d+$').hasMatch(value)) {
            return 'Kode OTP hanya boleh berupa angka';
          }
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
          fontSize: isWeb ? 14 : 16,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: const Color(0xFF246BFD)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isConfirmPassword
                      ? (_isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off)
                      : (_isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                  color: const Color(0xFF246BFD),
                ),
                onPressed: () {
                  setState(() {
                    if (isConfirmPassword) {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    } else {
                      _isPasswordVisible = !_isPasswordVisible;
                    }
                  });
                },
              )
            : null,
        contentPadding: EdgeInsets.symmetric(
          vertical: isWeb ? 12 : 16,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: Color(0xFF246BFD), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2.0),
        ),
        errorStyle: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w500,
          fontSize: isWeb ? 12 : 14,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _onSignUpPressed() async {
    if (_formKey.currentState == null) return;

    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final phone = _phoneController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      final otpCode = _otpController.text.trim();

      if (password != confirmPassword) {
        _showErrorDialog('Password dan Konfirmasi Password tidak cocok.');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final tokenResponse = await http.post(
          Uri.parse('$baseURL/api/auth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'grant_type': 'password', 'password': 'ASN_DBS'},
        );

        if (tokenResponse.statusCode == 200) {
          final tokenData = json.decode(tokenResponse.body);
          final accessToken = tokenData['access_token'];

          if (accessToken != null) {
            final signUpResponse = await http.post(
              Uri.parse('$baseURL/api/asn/Register'),
              headers: {
                'Authorization': 'bearer $accessToken',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                // ── User ID dikirim kosong, backend yang generate ──
                'UserId': '',
                'Name': name,
                'Password': password,
                'Email': email,
                'Phone': phone,
                'OtpCode': _showOtpField ? otpCode : '',
              }),
            );

            final responseData = json.decode(signUpResponse.body);

            if (signUpResponse.statusCode == 200) {
              if (responseData['requireOTP'] == true) {
                setState(() {
                  _showOtpField = true;
                  _isLoading = false;
                });
                _showSuccessDialog(
                  responseData['message'] ??
                      'Kode OTP telah dikirimkan ke email Anda.',
                );
              } else {
                setState(() => _isLoading = false);
                _showSuccessDialog(
                  responseData['message'] ?? 'Pendaftaran berhasil!',
                  onOkPressed: () {
                    Navigator.of(context).pop();
                    Future.delayed(const Duration(milliseconds: 500), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const SignInScreen(),
                        ),
                      );
                    });
                  },
                );
              }
            } else {
              setState(() => _isLoading = false);
              _handleErrorResponse(signUpResponse.statusCode, responseData);
            }
          } else {
            setState(() => _isLoading = false);
            _showErrorDialog(
              'Gagal mendapatkan token akses. Silakan coba lagi.',
            );
          }
        } else {
          setState(() => _isLoading = false);
          _showErrorDialog('Gagal terhubung ke server. Silakan coba lagi.');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorDialog(
          'Terjadi kesalahan koneksi. Periksa internet Anda dan coba lagi.',
        );
      }
    }
  }

  void _handleErrorResponse(int statusCode, Map<String, dynamic> responseData) {
    String apiMessage =
        responseData['message'] ??
        responseData['Message'] ??
        responseData['error'] ??
        '';

    String errorMessage;
    switch (statusCode) {
      case 400:
        if (apiMessage.toLowerCase().contains('email') &&
            (apiMessage.toLowerCase().contains('sudah') ||
                apiMessage.toLowerCase().contains('exist'))) {
          errorMessage = 'Email sudah terdaftar';
        } else if (apiMessage.toLowerCase().contains('otp')) {
          errorMessage = 'Kode OTP tidak valid atau sudah kadaluarsa';
        } else {
          errorMessage = apiMessage.isNotEmpty
              ? apiMessage
              : 'Data tidak valid';
        }
        break;
      case 409:
        errorMessage = apiMessage.isNotEmpty
            ? apiMessage
            : 'Data sudah terdaftar';
        break;
      case 500:
        errorMessage = 'Terjadi kesalahan pada server. Silakan coba lagi.';
        break;
      default:
        errorMessage = apiMessage.isNotEmpty
            ? apiMessage
            : 'Terjadi kesalahan yang tidak diketahui';
    }

    _showErrorDialog(errorMessage);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 50,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message, {VoidCallback? onOkPressed}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade400,
                size: 50,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Berhasil!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOkPressed ?? () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
