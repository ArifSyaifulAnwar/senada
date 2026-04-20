// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use, unused_field

import 'package:absensikaryawan/Screen%20HRD/homehrd.dart';
import 'package:absensikaryawan/Screen%20User/home.dart';
import 'package:absensikaryawan/Screen%20User/signup.dart';
import 'package:absensikaryawan/Screen%20admin/homeadmin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  bool _isLoading = false;
  bool _isOtpMode = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _currentEmail;
  bool _isAccountLocked = false;

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _controller.forward();
  }

  Future<void> _onSignInPressed() async {
    if (_formKey.currentState == null) return;

    if (_formKey.currentState!.validate()) {
      final emailOrUserId = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final otpCode = _isOtpMode ? _otpController.text.trim() : null;

      if (emailOrUserId.isEmpty || password.isEmpty) {
        _showDialog('Silakan masukkan Email/UserID dan Password');
        return;
      }

      if (_isOtpMode && (otpCode == null || otpCode.isEmpty)) {
        _showDialog('Silakan masukkan kode OTP');
        return;
      }

      setState(() {
        _isLoading = true;
      });

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
            final loginRequestBody = {
              'Email': emailOrUserId,
              'Password': password,
              'OtpCode': otpCode,
            };

            final loginResponse = await http.post(
              Uri.parse('$baseURL/api/asn/login'),
              headers: {
                'Authorization': 'bearer $accessToken',
                'Content-Type': 'application/json',
              },
              body: json.encode(loginRequestBody),
            );

            final responseData = json.decode(loginResponse.body);

            if (loginResponse.statusCode == 200) {
              if (responseData['requireOTP'] == true) {
                setState(() {
                  _isOtpMode = true;
                  _currentEmail = emailOrUserId;
                  _isAccountLocked = responseData['lockedAccount'] ?? false;
                });
                _showDialog(
                  responseData['message'] ??
                      'Silakan masukkan kode OTP yang dikirimkan ke email Anda.',
                );
              } else {
                final prefs = await SharedPreferences.getInstance();

                String email = responseData['Email'] ?? '';
                String role = responseData['Role'] ?? '';

                // Menyimpan data user ke SharedPreferences
                await prefs.setString('Name', responseData['Name'] ?? '');
                await prefs.setString('Email', email);
                await prefs.setString('UserID', responseData['UserId'] ?? '');
                await prefs.setString(
                  'FotoProfil',
                  responseData['FotoProfil'] ?? '',
                );
                await prefs.setString('Role', role);

                // Navigasi berdasarkan role
                _navigateByRole(role);
              }
            } else if (loginResponse.statusCode == 400 ||
                loginResponse.statusCode == 401) {
              if (responseData['requireOTP'] == true) {
                setState(() {
                  _isOtpMode = true;
                  _currentEmail = emailOrUserId;
                  _isAccountLocked = responseData['lockedAccount'] ?? false;
                });
                _showDialog(
                  responseData['message'] ??
                      'Silakan masukkan kode OTP yang dikirimkan ke email Anda.',
                );
              } else {
                _showDialog(
                  responseData['message'] ??
                      'Password atau email/userID yang anda masukkan salah.',
                );
              }
            } else if (loginResponse.statusCode == 403) {
              _showDialog(
                'Akun anda terkunci. Silakan segera menghubungi admin.',
              );
            } else {
              _showDialog(
                responseData['message'] ??
                    'Terjadi kesalahan yang tidak diketahui.',
              );
            }
          } else {
            _showDialog('Token tidak valid.');
          }
        } else {
          _showDialog('Gagal mendapatkan token.');
        }
      } catch (e) {
        _showDialog('Terjadi kesalahan: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      _showDialog('Silakan periksa kembali input Anda.');
    }
  }

  void _navigateByRole(String role) {
    Widget destination;

    switch (role.toLowerCase()) {
      case 'admin':
        destination = const HomePageAdmin();
        break;
      case 'hrd':
        destination = const HomePageHRD(); // Buat halaman ini
        break;
      case 'user':
      default:
        destination = const HomePage();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  // Fungsi untuk mengecek apakah input adalah email yang valid
  // bool _isValidEmail(String email) {
  //   final emailRegex = RegExp(
  //     r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  //   );
  //   return emailRegex.hasMatch(email);
  // }

  void _resetOtpMode() {
    setState(() {
      _isOtpMode = false;
      _otpController.clear();
      _currentEmail = null;
      _isAccountLocked = false;
    });
  }

  // void _showDialog(String message) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         backgroundColor: const Color(0xFF1f4262),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(15.0),
  //         ),
  //         title: const Text('Informasi', style: TextStyle(color: Colors.white)),
  //         content: Text(message, style: const TextStyle(color: Colors.white)),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text(
  //               'OK',
  //               style: TextStyle(color: Color(0xFFF4BE42)),
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1f4262),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Text('Informasi', style: TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (message.contains('kedaluwarsa')) {
                  _resetOtpMode();
                }
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFF4BE42)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1f4262),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lupa Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Masukkan email Anda untuk menerima kode verifikasi.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email atau User ID',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.email,
                      color: Color(0xFFF4BE42),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e3554),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4BE42),
                        ),
                        onPressed: () {
                          if (emailController.text.isNotEmpty) {
                            _resetPassword(emailController.text.trim());
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Email tidak boleh kosong"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text("Kirim OTP"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resetPassword(String email) async {
    try {
      // First get the token - similar to previous implementation
      final tokenResponse = await http.post(
        Uri.parse('$baseURL/api/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'password', 'password': 'ASN_DBS'},
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Gagal mendapatkan token akses');
      }

      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'];

      if (accessToken == null) {
        throw Exception('Token tidak valid');
      }

      // Make the reset password request
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/PermintaanResetPassword'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'Email': email}),
      );

      if (response.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kode verifikasi telah dikirim ke email Anda, silahkan cek email Anda.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          // Simulasikan jeda menunggu kode verifikasi (misalnya 2 detik)
          await Future.delayed(const Duration(seconds: 2));

          // Tutup loading indicator
          Navigator.pop(context);

          // Show verification code dialog after successful email sending
          _showVerificationDialog(email, accessToken);
        }
      } else {
        String message;
        switch (response.statusCode) {
          case 400:
            message = 'Email harus disertakan.';
            break;
          case 404:
            message = 'Email tidak terdaftar.';
            break;
          case 500:
            final responseBody = json.decode(response.body);
            message =
                responseBody['Message'] ?? 'Terjadi kesalahan internal server.';
            break;
          default:
            message = 'Terjadi kesalahan yang tidak diketahui.';
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyCodeAndResetPassword(
    String email,
    String verificationCode,
    String newPassword,
    String confirmPassword,
    String accessToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/VerifikasiResetPassword'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'Email': email,
          'VerificationCode': verificationCode,
          'NewPassword': newPassword, // Pastikan ini plain text
          'ConfirmPassword':
              confirmPassword, // Pastikan ini juga plain text dan sama dengan NewPassword
        }),
      );

      String message;
      bool isSuccess = false;

      switch (response.statusCode) {
        case 200:
          message =
              'Password berhasil direset. Silakan login dengan password baru Anda.';
          isSuccess = true;
          break;
        case 400:
          final errorData = json.decode(response.body);
          message =
              errorData['Message'] ??
              'Kode verifikasi atau password baru tidak valid.';
          break;
        case 404:
          message = 'Kode verifikasi tidak ditemukan atau sudah kadaluarsa.';
          break;
        case 500:
          final responseBody = json.decode(response.body);
          message =
              responseBody['Message'] ?? 'Terjadi kesalahan internal server.';
          break;
        default:
          message = 'Terjadi kesalahan yang tidak diketahui.';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isSuccess ? Colors.green : Colors.red,
          ),
        );

        if (isSuccess) {
          Navigator.pop(context); // Tutup dialog verifikasi
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showVerificationDialog(String email, String accessToken) {
    final codeController = TextEditingController();
    final passController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF1f4262),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Verifikasi OTP",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Kode OTP",
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(
                          Icons.security,
                          color: Color(0xFFF4BE42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Password Baru",
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.lock, color: Color(0xFFF4BE42)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Konfirmasi Password",
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Color(0xFFF4BE42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1e3554),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Batal"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF4BE42),
                            ),
                            onPressed: () {
                              if (codeController.text.isEmpty ||
                                  passController.text.isEmpty ||
                                  confirmPassController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Semua field wajib diisi"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (passController.text !=
                                  confirmPassController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Password tidak cocok"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              _verifyCodeAndResetPassword(
                                email,
                                codeController.text,
                                passController.text,
                                confirmPassController.text,
                                accessToken,
                              );
                            },
                            child: const Text("Reset Password"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive values
    final logoSize = isWeb ? 120.0 : size.width * 0.35;
    final titleFontSize = isWeb ? 36.0 : size.width * 0.08;
    final subtitleFontSize = isWeb ? 16.0 : size.width * 0.045;
    // Responsive sizing
    final double maxWidth = isWeb ? 500 : double.infinity;
    final double horizontalPadding = isWeb ? 20.0 : screenWidth * 0.05;

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
                                      color: Colors.black.withOpacity(
                                        isWeb ? 0.1 : 0.2,
                                      ),
                                      blurRadius: isWeb ? 30 : 20,
                                      offset: Offset(0, isWeb ? 15 : 10),
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF246BFD,
                                      ).withOpacity(isWeb ? 0.2 : 0.3),
                                      blurRadius: isWeb ? 50 : 40,
                                      offset: Offset(0, isWeb ? 25 : 20),
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
                                              return Icon(
                                                Icons.business,
                                                size: logoSize * 0.5,
                                                color: const Color(0xFF246BFD),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isWeb ? 32 : size.height * 0.04),

                            // App Title
                            Text(
                              'SENADA',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: isWeb ? 'Roboto' : null,
                                shadows: isWeb
                                    ? null
                                    : [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.2),
                                          offset: const Offset(2, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                              ),
                            ),

                            SizedBox(height: isWeb ? 12 : size.height * 0.01),

                            // Subtitle
                            Text(
                              _isOtpMode
                                  ? 'Verifikasi OTP'
                                  : 'Halo, login untuk melanjutkan',
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontFamily: isWeb ? 'Roboto' : null,
                                shadows: isWeb
                                    ? null
                                    : [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.4),
                                          offset: const Offset(1, 1),
                                          blurRadius: 3,
                                        ),
                                      ],
                              ),
                            ),

                            // Account locked warning
                            if (_isOtpMode && _isAccountLocked)
                              Padding(
                                padding: EdgeInsets.only(top: isWeb ? 16 : 12),
                                child: Container(
                                  padding: EdgeInsets.all(isWeb ? 12 : 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Akun anda terkunci. Silakan verifikasi dengan OTP untuk membuka.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: isWeb ? 14 : 12,
                                      fontFamily: isWeb ? 'Roboto' : null,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                            SizedBox(height: isWeb ? 48 : size.height * 0.06),

                            // Form Fields
                            // Form Fields
                            if (!_isOtpMode) ...[
                              _buildTextField(
                                label: 'Email atau userID',
                                icon: Icons.person,
                                isPassword: false,
                                controller: _emailController,
                                isWeb: isWeb,
                              ),
                              SizedBox(height: isWeb ? 16 : size.height * 0.02),

                              _buildTextField(
                                label: 'Password',
                                icon: Icons.lock,
                                isPassword: true,
                                controller: _passwordController,
                                isWeb: isWeb,
                              ),

                              // Lupa Password dekat field password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: const Text(
                                    "Lupa Password?",
                                    style: TextStyle(
                                      color: Color(0xFF246BFD),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(
                                height: isWeb ? 20 : size.height * 0.025,
                              ), // lebih kecil
                            ] else ...[
                              // OTP mode tetap
                              Text(
                                'Kode OTP telah dikirim ke email anda, Silakan masukkan kode OTP untuk melanjutkan.',
                                style: TextStyle(
                                  fontSize: isWeb ? 14 : 12,
                                  color: Colors.black54,
                                  fontFamily: isWeb ? 'Roboto' : null,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isWeb ? 16 : size.height * 0.02),
                              _buildTextField(
                                label: 'Kode OTP',
                                icon: Icons.security,
                                isPassword: false,
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                isWeb: isWeb,
                              ),
                            ],

                            // Tombol Login lebih dekat
                            SizedBox(
                              width: double.infinity,
                              height: isWeb ? 56 : 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _onSignInPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF246BFD),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  elevation: isWeb ? 6 : 8,
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
                                        _isOtpMode ? 'Verifikasi' : 'Login',
                                        style: TextStyle(
                                          fontSize: isWeb ? 18 : 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: isWeb ? 'Roboto' : null,
                                        ),
                                      ),
                              ),
                            ),

                            SizedBox(
                              height: isWeb ? 16 : size.height * 0.02,
                            ), // jarak kecil setelah tombol
                            // Register option
                            if (!_isOtpMode)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Belum memiliki akun? ',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: isWeb ? 16 : 14,
                                      fontFamily: isWeb ? 'Roboto' : null,
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
                                              ) => SignUpScreen(),
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
                                      'Daftar',
                                      style: TextStyle(
                                        color: const Color(0xFF246BFD),
                                        fontWeight: FontWeight.bold,
                                        fontSize: isWeb ? 16 : 14,
                                        fontFamily: isWeb ? 'Roboto' : null,
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(
                                          0xFF246BFD,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // Web footer (optional)
                            if (isWeb) ...[
                              const SizedBox(height: 40),
                              Text(
                                '© 2025 Sistem Absensi Karyawan SDB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  fontFamily: 'Roboto',
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
    required bool isWeb,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Colors.black,
        fontSize: isWeb ? 16 : 14,
        fontWeight: FontWeight.w500,
        fontFamily: isWeb ? 'Roboto' : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Silakan masukkan $label';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
          fontSize: isWeb ? 14 : 12,
          fontFamily: isWeb ? 'Roboto' : null,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF246BFD)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF246BFD),
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        contentPadding: EdgeInsets.symmetric(
          vertical: isWeb ? 18 : 16,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: BorderSide(
            color: const Color(0xFF246BFD).withOpacity(0.7),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: Color(0xFF246BFD)),
        ),
        filled: true,
        fillColor: Colors.white,
        errorStyle: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w500,
          fontSize: isWeb ? 12 : 11,
          fontFamily: isWeb ? 'Roboto' : null,
        ),
      ),
      inputFormatters: keyboardType == TextInputType.number
          ? [LengthLimitingTextInputFormatter(6)]
          : [],
    );
  }
}
