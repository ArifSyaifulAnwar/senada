// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? v) {
    if (v == null || v.isEmpty) return 'Masukkan password baru';
    if (v.length < 8) return 'Password minimal 8 karakter';

    // Regex cek komponen password
    final upperCase = RegExp(r'[A-Z]');
    final lowerCase = RegExp(r'[a-z]');
    final digit = RegExp(r'\d');
    final specialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

    if (!upperCase.hasMatch(v)) {
      return 'Password harus mengandung huruf besar';
    }
    if (!lowerCase.hasMatch(v)) {
      return 'Password harus mengandung huruf kecil';
    }
    if (!digit.hasMatch(v)) {
      return 'Password harus mengandung angka';
    }
    if (!specialChar.hasMatch(v)) {
      return 'Password harus mengandung karakter khusus';
    }

    return null;
  }

  Future<void> _submit() async {
    // Validasi form dengan null safety
    if (_formKey.currentState == null) {
      _showSnackBar('Form tidak valid', Colors.red);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Ambil data user dengan error handling
      final email = await _getUserEmail();
      final name = await _getName();

      final oldPass = _oldPasswordController.text.trim();
      final newPass = _newPasswordController.text.trim();

      // Validasi tambahan
      if (oldPass.isEmpty || newPass.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Password tidak boleh kosong', Colors.red);
        return;
      }

      // 1. Ambil token terlebih dahulu
      final tokenResponse = await http.post(
        Uri.parse('$baseURL/api/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'password', 'password': 'ASN_DBS'},
      );

      if (tokenResponse.statusCode != 200) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Gagal mendapatkan token akses', Colors.red);
        return;
      }

      final tokenData = jsonDecode(tokenResponse.body);
      if (tokenData['access_token'] == null) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Token akses tidak valid', Colors.red);
        return;
      }

      final String accessToken = tokenData['access_token'];

      // 2. Panggil API ubah password dengan token di header Authorization
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/changePassword'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "userEmail": email,
          "oldPassword": oldPass,
          "newPassword": newPass,
          "updatedBy": name,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showSnackBar(
          data['message'] ?? 'Password berhasil diubah',
          Colors.green,
        );

        // Clear form setelah berhasil
        _formKey.currentState?.reset();
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        // Tunggu sebentar untuk menampilkan snackbar kemudian kembali ke halaman sebelumnya
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        String errorMessage = 'Gagal mengubah password';

        try {
          final errorData = jsonDecode(response.body);

          // Handle specific error messages based on status code
          if (response.statusCode == 401) {
            // Unauthorized - Password lama salah
            errorMessage =
                errorData['message'] ??
                'Password lama yang Anda masukkan salah';
          } else if (response.statusCode == 400) {
            // Bad Request - Validation error or other client errors
            errorMessage =
                errorData['message'] ?? 'Data yang dimasukkan tidak valid';
          } else if (response.statusCode == 500) {
            // Internal Server Error
            errorMessage =
                errorData['message'] ?? 'Terjadi kesalahan pada server';
          } else {
            // Other error codes
            errorMessage =
                errorData['message'] ??
                errorData['Message'] ??
                'Terjadi kesalahan tidak dikenal';
          }
        } catch (e) {
          // Jika response body tidak bisa di-parse sebagai JSON
          if (response.statusCode == 401) {
            errorMessage = 'Password lama yang Anda masukkan salah';
          } else if (response.statusCode == 400) {
            errorMessage = 'Data yang dimasukkan tidak valid';
          } else if (response.statusCode == 500) {
            errorMessage = 'Terjadi kesalahan pada server';
          } else {
            errorMessage = 'Terjadi kesalahan: ${response.statusCode}';
          }
        }

        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Terjadi kesalahan: $e', Colors.red);
    }
  }

  // Fungsi mengambil email user dari storage/shared preferences dengan error handling
  Future<String> _getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('Email');
      if (email != null && email.isNotEmpty) {
        return email;
      } else {
        throw Exception('Email pengguna tidak ditemukan di storage');
      }
    } catch (e) {
      throw Exception('Gagal mengambil email pengguna: $e');
    }
  }

  Future<String> _getName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('Name');
      if (name != null && name.isNotEmpty) {
        return name;
      } else {
        throw Exception('Nama pengguna tidak ditemukan di storage');
      }
    } catch (e) {
      throw Exception('Gagal mengambil nama pengguna: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  InputDecoration _buildInputDecoration(
    String label,
    bool obscureText,
    VoidCallback toggleObscure,
  ) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      suffixIcon: GestureDetector(
        onTap: toggleObscure,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade500,
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Text(
          'Ubah Password',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      backgroundColor: Colors.grey.shade100,
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: ListView(
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(
                          255,
                          84,
                          137,
                          251,
                        ).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.password,
                        size: 80,
                        color: Color(0xFF246AFD),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ubah Kata Sandi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ganti password Anda untuk menjaga keamanan akun.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _buildPasswordField(
                controller: _oldPasswordController,
                label: 'Password Lama',
                obscureText: _obscureOld,
                toggleObscure: () => setState(() => _obscureOld = !_obscureOld),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Masukkan password lama' : null,
              ),
              const SizedBox(height: 24),
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'Password Baru',
                obscureText: _obscureNew,
                toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                validator: _validateNewPassword,
              ),
              const SizedBox(height: 24),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Ulangi Password Baru',
                obscureText: _obscureConfirm,
                toggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ulangi password baru';
                  if (v != _newPasswordController.text) {
                    return 'Password tidak sama';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return Colors.grey.shade400;
                      }
                      return const Color(0xFF246AFD);
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    elevation: WidgetStateProperty.all(6),
                    shadowColor: WidgetStateProperty.all(
                      const Color(0xFF246AFD),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          'Simpan',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback toggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: _buildInputDecoration(label, obscureText, toggleObscure),
      validator: validator,
      style: const TextStyle(fontSize: 16, height: 1.3, letterSpacing: 0.4),
      cursorColor: Colors.blue.shade600,
      cursorWidth: 2,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
